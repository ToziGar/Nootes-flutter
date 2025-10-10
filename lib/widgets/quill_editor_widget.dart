import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart' as math;
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import './note_autocomplete_overlay.dart';

class QuillEditorWidget extends StatefulWidget {
  final String uid;
  final String? initialDeltaJson;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onPlainTextChanged;
  final Future<void> Function(String) onSave;
  final Future<void> Function(List<String>)? onLinksChanged;
  final Future<void> Function(String)? onNoteOpen;
  final bool splitEnabled;
  final Future<List<NoteSuggestion>> Function(String query)? fetchNoteSuggestions;

  const QuillEditorWidget({
    super.key,
    required this.uid,
    this.initialDeltaJson,
    required this.onChanged,
    this.onPlainTextChanged,
    required this.onSave,
    this.onLinksChanged,
    this.onNoteOpen,
    this.splitEnabled = false,
    this.fetchNoteSuggestions,
  });

  @override
  State<QuillEditorWidget> createState() => _QuillEditorWidgetState();
}

class _QuillEditorWidgetState extends State<QuillEditorWidget> {
  late QuillController _controller;
  bool _darkTheme = false;
  StreamSubscription? _changesSub;
  bool _applyingShortcuts = false;

  // Wikilinks state
  List<NoteSuggestion> _wikiSuggestions = const [];
  String _wikiQuery = '';
  bool _showWiki = false;

  // Math preview state
  String _mathPreview = '';
  bool _mathIsBlock = false;
  bool _showMathPreview = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.initialDeltaJson != null
        ? QuillController(
            document: Document.fromJson(
              List<Map<String, dynamic>>.from(
                jsonDecode(widget.initialDeltaJson!),
              ),
            ),
            selection: const TextSelection.collapsed(offset: 0),
          )
        : QuillController.basic();

    _controller.addListener(_onDocumentChanged);
    _changesSub = _controller.changes.listen((_) {
      if (!_applyingShortcuts) {
        _applyMarkdownShortcuts();
      }
    });
  }

  @override
  void dispose() {
    _changesSub?.cancel();
    super.dispose();
  }

  void _onDocumentChanged() {
    final deltaJson = jsonEncode(_controller.document.toDelta().toJson());
    widget.onChanged(deltaJson);
    widget.onPlainTextChanged?.call(_controller.document.toPlainText());
    _updateMathPreview();
  }

  void _applyMarkdownShortcuts() {
    final sel = _controller.selection;
    if (!sel.isValid) return;
    final caret = sel.baseOffset;
    if (caret < 0) return;
    final plain = _controller.document.toPlainText();
    if (caret > plain.length) return;

    final lineStart = plain.lastIndexOf('\n', caret - 1) + 1;
    final upToCursorInLine = plain.substring(lineStart, caret);

    // Headings #-### 
    final h = RegExp(r'^(#{1,6})\s$').firstMatch(upToCursorInLine);
    if (h != null) {
      final level = h.group(1)!.length;
      _applyLinePrefix(lineStart, h.group(0)!.length, caret, () {
        switch (level) {
          case 1:
            _controller.formatSelection(Attribute.h1);
            break;
          case 2:
            _controller.formatSelection(Attribute.h2);
            break;
          case 3:
            _controller.formatSelection(Attribute.h3);
            break;
          default:
            _controller.formatSelection(Attribute.h3);
        }
      });
      return;
    }

    // UL - * 
    if (RegExp(r'^(?:- |\* )$').hasMatch(upToCursorInLine)) {
      _applyLinePrefix(lineStart, 2, caret, () => _controller.formatSelection(Attribute.ul));
      return;
    }

    // OL 1. 
    if (RegExp(r'^\d+\. $').hasMatch(upToCursorInLine)) {
      _applyLinePrefix(lineStart, upToCursorInLine.length, caret, () => _controller.formatSelection(Attribute.ol));
      return;
    }

    // Blockquote > 
    if (upToCursorInLine == '> ') {
      _applyLinePrefix(lineStart, 2, caret, () => _controller.formatSelection(Attribute.blockQuote));
      return;
    }

    // Code block ```
    if (upToCursorInLine.endsWith('```')) {
      _applyLinePrefix(lineStart + upToCursorInLine.length - 3, 3, caret, () => _controller.formatSelection(Attribute.codeBlock));
      return;
    }

    // Horizontal rule ---
    if (upToCursorInLine == '---') {
      _applyHorizontalRule(lineStart);
      return;
    }

    // LaTeX block $$ 
    if (RegExp(r'^\$\$\s$').hasMatch(upToCursorInLine)) {
      _expandMathBlockSkeleton(lineStart, upToCursorInLine.length, caret);
      return;
    }

    // LaTeX inline $ 
    if (RegExp(r'^\$\s$').hasMatch(upToCursorInLine)) {
      _expandInlineMathSkeleton(lineStart, upToCursorInLine.length, caret);
      return;
    }

    // Wikilinks [[
    final wikiMatch = RegExp(r'\[\[([^\]]*)$').firstMatch(upToCursorInLine);
    if (wikiMatch != null && widget.fetchNoteSuggestions != null) {
      _wikiQuery = wikiMatch.group(1) ?? '';
      _showWikilinkOverlay();
      return;
    } else {
      _hideWikilinkOverlay();
    }

    _updateMathPreview();
  }

  void _applyLinePrefix(int start, int length, int originalCaret, VoidCallback formatLine) {
    _applyingShortcuts = true;
    try {
      final newCaret = (originalCaret - length).clamp(0, _controller.document.length);
      _controller.replaceText(start, length, '', TextSelection.collapsed(offset: newCaret));
      _controller.updateSelection(TextSelection.collapsed(offset: newCaret), ChangeSource.local);
      formatLine();
    } finally {
      _applyingShortcuts = false;
    }
  }

  void _applyHorizontalRule(int lineStart) {
    _applyingShortcuts = true;
    try {
      _controller.replaceText(lineStart, 3, '', TextSelection.collapsed(offset: lineStart));
      _controller.replaceText(lineStart, 0, '————————————\n', TextSelection.collapsed(offset: lineStart + 1));
    } finally {
      _applyingShortcuts = false;
    }
  }

  Future<void> _showWikilinkOverlay() async {
    if (widget.fetchNoteSuggestions == null) return;
    try {
      final list = await widget.fetchNoteSuggestions!.call(_wikiQuery);
      if (!mounted) return;
      setState(() {
        _wikiSuggestions = list;
        _showWiki = true;
      });
    } catch (_) {}
  }

  void _hideWikilinkOverlay() {
    if (!mounted) return;
    setState(() {
      _showWiki = false;
      _wikiSuggestions = const [];
    });
  }

  void _insertWikiLink(NoteSuggestion s) {
    final sel = _controller.selection;
    final caret = sel.baseOffset;
    final plain = _controller.document.toPlainText();
    final lineStart = plain.lastIndexOf('\n', caret - 1) + 1;
    final upToCursorInLine = plain.substring(lineStart, caret);
    final match = RegExp(r'\[\[([^\]]*)$').firstMatch(upToCursorInLine);
    if (match == null) return;
    final removeLen = match.group(0)!.length;
    final start = caret - removeLen;
    final display = s.title.isEmpty ? s.id : s.title;
    final insertion = '[[$display]]';
    _applyingShortcuts = true;
    try {
      _controller.replaceText(start, removeLen, insertion, TextSelection.collapsed(offset: start + insertion.length));
      widget.onLinksChanged?.call([s.id]);
    } finally {
      _applyingShortcuts = false;
    }
  }

  void _tryOpenWikilink() {
    if (widget.onNoteOpen == null) return;
    final sel = _controller.selection;
    final caret = sel.baseOffset;
    final plain = _controller.document.toPlainText();
    if (caret < 0 || caret > plain.length) return;
    final lineStart = plain.lastIndexOf('\n', caret - 1) + 1;
    final lineEnd = plain.indexOf('\n', caret);
    final segment = plain.substring(lineStart, lineEnd == -1 ? plain.length : lineEnd);
    final linkMatch = RegExp(r'\[\[(.+?)\]\]').firstMatch(segment);
    if (linkMatch != null) {
      final label = linkMatch.group(1)!.trim();
      widget.onNoteOpen!.call(label);
    }
  }

  void _handleBackspaceFormatExit() {
    final sel = _controller.selection;
    if (!sel.isCollapsed || sel.baseOffset <= 0) return;
    final caret = sel.baseOffset;
    final plain = _controller.document.toPlainText();
    final lineStart = plain.lastIndexOf('\n', caret - 1) + 1;
    if (caret != lineStart) return;
    final attrs = _controller.getSelectionStyle().attributes;
    if (attrs.containsKey(Attribute.ul.key) ||
        attrs.containsKey(Attribute.ol.key) ||
        attrs.containsKey(Attribute.blockQuote.key)) {
      _controller.formatSelection(Attribute.clone(Attribute.blockQuote, null));
      _controller.formatSelection(Attribute.clone(Attribute.ul, null));
      _controller.formatSelection(Attribute.clone(Attribute.ol, null));
    } else if (attrs.containsKey(Attribute.codeBlock.key)) {
      _controller.formatSelection(Attribute.clone(Attribute.codeBlock, null));
    }
  }

  void _expandMathBlockSkeleton(int start, int typedLen, int caret) {
    _applyingShortcuts = true;
    try {
      const template = '\n\$\$\n\n\$\$\n';
      _controller.replaceText(start, typedLen, '', TextSelection.collapsed(offset: start));
      _controller.replaceText(start, 0, template, TextSelection.collapsed(offset: start + 4));
    } finally {
      _applyingShortcuts = false;
    }
  }

  void _expandInlineMathSkeleton(int start, int typedLen, int caret) {
    _applyingShortcuts = true;
    try {
      _controller.replaceText(start, typedLen, '\$\$', TextSelection.collapsed(offset: start + 1));
    } finally {
      _applyingShortcuts = false;
    }
  }

  void _updateMathPreview() {
    final sel = _controller.selection;
    if (!sel.isValid) return;
    final caret = sel.baseOffset;
    if (caret < 0) return;
    final plain = _controller.document.toPlainText();
    if (caret > plain.length) return;

    // Check for block math $$...$$
    final lb = plain.lastIndexOf('\$\$', caret - 1);
    final rb = plain.indexOf('\$\$', caret);
    if (lb != -1 && rb != -1 && lb < caret && caret < rb) {
      final expr = plain.substring(lb + 2, rb).trim();
      if (expr.isNotEmpty) {
        if (!_showMathPreview || _mathPreview != expr || !_mathIsBlock) {
          setState(() {
            _mathPreview = expr;
            _mathIsBlock = true;
            _showMathPreview = true;
          });
        }
        return;
      }
    }

    // Check for inline math $...$
    final lineStart = plain.lastIndexOf('\n', caret - 1) + 1;
    final nextNl = plain.indexOf('\n', caret);
    final lineEnd = nextNl == -1 ? plain.length : nextNl;
    final line = plain.substring(lineStart, lineEnd);
    final relCaret = caret - lineStart;
    final singleDollar = RegExp(r'(?<!\$)\$(?!\$)');
    final matches = singleDollar.allMatches(line).toList();
    for (int i = 0; i + 1 < matches.length; i += 2) {
      final m1 = matches[i];
      final m2 = matches[i + 1];
      if (m1.start < relCaret && relCaret <= m2.start) {
        final expr = line.substring(m1.end, m2.start).trim();
        if (expr.isNotEmpty) {
          if (!_showMathPreview || _mathPreview != expr || _mathIsBlock) {
            setState(() {
              _mathPreview = expr;
              _mathIsBlock = false;
              _showMathPreview = true;
            });
          }
          return;
        }
      }
    }

    // No math found, hide preview
    if (_showMathPreview) {
      setState(() {
        _showMathPreview = false;
        _mathPreview = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toolbar
        Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Wrap(
            spacing: 4.0,
            runSpacing: 4.0,
            children: [
              _buildToolbarButton(Icons.format_bold, () => _controller.formatSelection(Attribute.bold), 'Negrita'),
              _buildToolbarButton(Icons.format_italic, () => _controller.formatSelection(Attribute.italic), 'Cursiva'),
              _buildToolbarButton(Icons.format_underline, () => _controller.formatSelection(Attribute.underline), 'Subrayado'),
              _buildToolbarButton(Icons.strikethrough_s, () => _controller.formatSelection(Attribute.strikeThrough), 'Tachado'),
              const VerticalDivider(width: 16),
              _buildToolbarButton(Icons.format_align_left, () => _controller.formatSelection(Attribute.leftAlignment), 'Izquierda'),
              _buildToolbarButton(Icons.format_align_center, () => _controller.formatSelection(Attribute.centerAlignment), 'Centro'),
              _buildToolbarButton(Icons.format_align_right, () => _controller.formatSelection(Attribute.rightAlignment), 'Derecha'),
              _buildToolbarButton(Icons.format_align_justify, () => _controller.formatSelection(Attribute.justifyAlignment), 'Justificar'),
              const VerticalDivider(width: 16),
              _buildToolbarButton(Icons.format_list_bulleted, () => _controller.formatSelection(Attribute.ul), 'Lista'),
              _buildToolbarButton(Icons.format_list_numbered, () => _controller.formatSelection(Attribute.ol), 'Numerada'),
              _buildToolbarButton(Icons.format_quote, () => _controller.formatSelection(Attribute.blockQuote), 'Cita'),
              _buildToolbarButton(Icons.code, () => _controller.formatSelection(Attribute.codeBlock), 'Código'),
              const VerticalDivider(width: 16),
              _buildToolbarButton(Icons.undo, () => _controller.undo(), 'Deshacer'),
              _buildToolbarButton(Icons.redo, () => _controller.redo(), 'Rehacer'),
              const VerticalDivider(width: 16),
              _buildToolbarButton(Icons.search, () => _showSearchDialog(context), 'Buscar'),
              _buildToolbarButton(Icons.image, () => _insertImage(context), 'Imagen'),
              _buildToolbarButton(Icons.link, () => _insertLink(context), 'Enlace'),
              const VerticalDivider(width: 16),
              _buildToolbarButton(Icons.functions, _insertMathBlock, 'Bloque LaTeX'),
              _buildToolbarButton(Icons.exposure, _insertMathInline, 'LaTeX inline'),
              const VerticalDivider(width: 16),
              _buildToolbarButton(Icons.color_lens, () => _showColorPicker(context), 'Color'),
              _buildToolbarButton(_darkTheme ? Icons.light_mode : Icons.dark_mode, () => _toggleTheme(), 'Tema'),
              _buildToolbarButton(Icons.fullscreen, () => _toggleFullscreen(context), 'Pantalla completa'),
            ],
          ),
        ),
        // Editor area
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _darkTheme ? Colors.grey[900] : Theme.of(context).colorScheme.surface,
            ),
            padding: const EdgeInsets.all(16.0),
            child: Stack(
              children: [
                // Main editor
                Positioned.fill(
                  child: KeyboardListener(
                    focusNode: FocusNode(),
                    onKeyEvent: (event) {
                      if (event is KeyDownEvent) {
                        final isCtrl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
                        if (isCtrl && event.logicalKey == LogicalKeyboardKey.enter) {
                          _tryOpenWikilink();
                        }
                        if (event.logicalKey == LogicalKeyboardKey.backspace) {
                          _handleBackspaceFormatExit();
                        }
                      }
                    },
                    child: QuillEditor.basic(
                      controller: _controller,
                    ),
                  ),
                ),
                // Wikilink overlay (top-left)
                if (_showWiki && _wikiSuggestions.isNotEmpty)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Material(
                      color: Colors.transparent,
                      child: NoteAutocompleteOverlay(
                        query: _wikiQuery,
                        suggestions: _wikiSuggestions,
                        onSelect: (s) {
                          _insertWikiLink(s);
                          _hideWikilinkOverlay();
                        },
                        onDismiss: _hideWikilinkOverlay,
                      ),
                    ),
                  ),
                // Math preview overlay (bottom-right)
                if (_showMathPreview && _mathPreview.isNotEmpty)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(8),
                      color: Theme.of(context).colorScheme.surface,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 300, maxHeight: 200),
                        padding: const EdgeInsets.all(12),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _mathIsBlock ? Icons.functions : Icons.exposure,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _mathIsBlock ? 'Bloque LaTeX' : 'LaTeX inline',
                                    style: Theme.of(context).textTheme.labelSmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              math.Math.tex(
                                _mathPreview,
                                textStyle: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontSize: _mathIsBlock ? 16 : 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Bottom bar with save button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                'Palabras: ${_getWordCount()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () async {
                  final json = jsonEncode(_controller.document.toDelta().toJson());
                  widget.onChanged(json);
                  final messenger = ScaffoldMessenger.of(context);
                  await widget.onSave(json);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Nota guardada correctamente'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.save, size: 16),
                label: const Text('Guardar'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolbarButton(IconData icon, VoidCallback onPressed, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  int _getWordCount() {
    final text = _controller.document.toPlainText();
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  void _toggleTheme() {
    setState(() {
      _darkTheme = !_darkTheme;
    });
  }

  void _showSearchDialog(BuildContext context) {
    String query = '';
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Buscar en nota'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Texto a buscar',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => query = v,
            onSubmitted: (v) {
              _performSearch(v);
              Navigator.of(ctx).pop();
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                _performSearch(query);
                Navigator.of(ctx).pop();
              },
              child: const Text('Buscar'),
            ),
          ],
        );
      },
    );
  }

  void _performSearch(String query) {
    if (query.isEmpty) return;
    final text = _controller.document.toPlainText();
    final index = text.toLowerCase().indexOf(query.toLowerCase());
    if (index != -1) {
      _controller.updateSelection(
        TextSelection(baseOffset: index, extentOffset: index + query.length),
        ChangeSource.local,
      );
    }
  }

  void _insertImage(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        String imageUrl = '';
        return AlertDialog(
          title: const Text('Insertar imagen'),
          content: TextField(
            decoration: const InputDecoration(
              hintText: 'URL de la imagen',
              prefixIcon: Icon(Icons.link),
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => imageUrl = v,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (imageUrl.isNotEmpty) {
                  final delta = Delta()..insert({'image': imageUrl});
                  _controller.compose(delta, TextSelection.collapsed(offset: _controller.selection.baseOffset), ChangeSource.local);
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Insertar'),
            ),
          ],
        );
      },
    );
  }

  void _insertLink(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        String linkUrl = '';
        String linkText = '';
        return AlertDialog(
          title: const Text('Insertar enlace'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Texto del enlace',
                  prefixIcon: Icon(Icons.text_fields),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => linkText = v,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'URL del enlace',
                  prefixIcon: Icon(Icons.link),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => linkUrl = v,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (linkUrl.isNotEmpty && linkText.isNotEmpty) {
                  _controller.formatText(_controller.selection.baseOffset, linkText.length, LinkAttribute(linkUrl));
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Insertar'),
            ),
          ],
        );
      },
    );
  }

  void _showColorPicker(BuildContext context) {
    final colors = [
      Colors.black,
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.brown,
      Colors.grey,
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Seleccionar color'),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: colors.map((color) {
              return InkWell(
                onTap: () {
                  _controller.formatSelection(ColorAttribute('#${color.toARGB32().toRadixString(16).padLeft(8, '0')}'));
                  Navigator.of(ctx).pop();
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey),
                  ),
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  void _toggleFullscreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Editor en pantalla completa'),
            actions: [
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: () async {
                  final json = jsonEncode(_controller.document.toDelta().toJson());
                  widget.onChanged(json);
                  final navigator = Navigator.of(context);
                  await widget.onSave(json);
                  navigator.pop();
                },
              ),
            ],
          ),
          body: QuillEditor.basic(controller: _controller),
        ),
      ),
    );
  }

  void _insertMathBlock() {
    final sel = _controller.selection;
    final caret = sel.baseOffset;
    _applyingShortcuts = true;
    try {
      const text = '\n\$\$\n\n\$\$\n';
      _controller.replaceText(caret, 0, text, TextSelection.collapsed(offset: caret + 4));
    } finally {
      _applyingShortcuts = false;
    }
  }

  void _insertMathInline() {
    final sel = _controller.selection;
    final caret = sel.baseOffset;
    _applyingShortcuts = true;
    try {
      _controller.replaceText(caret, 0, '\$\$', TextSelection.collapsed(offset: caret + 1));
    } finally {
      _applyingShortcuts = false;
    }
  }
}
