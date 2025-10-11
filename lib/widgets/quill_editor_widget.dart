import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  late FocusNode _editorFocusNode; // FocusNode persistente para el editor
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
  
  // Auto-save state
  Timer? _autoSaveTimer;
  bool _hasUnsavedChanges = false;
  DateTime? _lastSaveTime;
  
  // Editor state
  double _editorFontSize = 16.0;

  @override
  void initState() {
    super.initState();
    _editorFocusNode = FocusNode();
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
      // Marcar cambios no guardados y programar auto-guardado
      // NO hacer setState aquí - solo marcar flag
      _hasUnsavedChanges = true;
      _scheduleAutoSave();
      // Eliminado: _scheduleStatusUpdate() - causa pérdida de focus en web
    });
    
    // Dar foco inicial al editor
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _editorFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _mathPreviewTimer?.cancel();
    _editorFocusNode.dispose();
    _changesSub?.cancel();
    super.dispose();
  }
  
  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      if (_hasUnsavedChanges && mounted) {
        _performAutoSave();
      }
    });
  }
  
  Future<void> _performAutoSave() async {
    if (!mounted) return;
    
    // En web, guardar el estado de focus antes del guardado
    final hadFocus = kIsWeb ? _editorFocusNode.hasFocus : false;
    final selection = kIsWeb ? _controller.selection : const TextSelection.collapsed(offset: 0);
    
    final json = jsonEncode(_controller.document.toDelta().toJson());
    widget.onChanged(json);
    
    try {
      await widget.onSave(json);
      if (mounted) {
        setState(() {
          _hasUnsavedChanges = false;
          _lastSaveTime = DateTime.now();
        });
        
        // En web, restaurar focus SOLO si lo tenía antes (fix específico web)
        if (kIsWeb && hadFocus && !_editorFocusNode.hasFocus) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_editorFocusNode.hasFocus) {
              _editorFocusNode.requestFocus();
              // Restaurar selección solo si es válida
              if (selection.isValid) {
                _controller.updateSelection(selection, ChangeSource.local);
              }
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error auto-guardando: $e');
    }
  }

  Timer? _mathPreviewTimer;
  
  void _onDocumentChanged() {
    // Solo actualizar callbacks esenciales, el guardado lo maneja el auto-save
    widget.onPlainTextChanged?.call(_controller.document.toPlainText());
    
    // Debounce math preview para mejor rendimiento
    _mathPreviewTimer?.cancel();
    _mathPreviewTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _updateMathPreview();
      }
    });
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
    final lb = caret > 0 ? plain.lastIndexOf('\$\$', caret - 1) : -1;
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
    final lineStart = caret > 0 ? plain.lastIndexOf('\n', caret - 1) + 1 : 0;
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
        // Toolbar mejorada con agrupaciones visuales
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
            child: Row(
              children: [
                // Grupo: Formato de texto
                _buildToolbarGroup([
                  _buildToolbarButton(Icons.format_bold, () => _controller.formatSelection(Attribute.bold), 'Negrita (Ctrl+B)'),
                  _buildToolbarButton(Icons.format_italic, () => _controller.formatSelection(Attribute.italic), 'Cursiva (Ctrl+I)'),
                  _buildToolbarButton(Icons.format_underline, () => _controller.formatSelection(Attribute.underline), 'Subrayado (Ctrl+U)'),
                  _buildToolbarButton(Icons.strikethrough_s, () => _controller.formatSelection(Attribute.strikeThrough), 'Tachado'),
                ]),
                const SizedBox(width: 8),
                _buildToolbarDivider(),
                const SizedBox(width: 8),
                
                // Grupo: Alineación
                _buildToolbarGroup([
                  _buildToolbarButton(Icons.format_align_left, () => _controller.formatSelection(Attribute.leftAlignment), 'Alinear izquierda'),
                  _buildToolbarButton(Icons.format_align_center, () => _controller.formatSelection(Attribute.centerAlignment), 'Centrar'),
                  _buildToolbarButton(Icons.format_align_right, () => _controller.formatSelection(Attribute.rightAlignment), 'Alinear derecha'),
                  _buildToolbarButton(Icons.format_align_justify, () => _controller.formatSelection(Attribute.justifyAlignment), 'Justificar'),
                ]),
                const SizedBox(width: 8),
                _buildToolbarDivider(),
                const SizedBox(width: 8),
                
                // Grupo: Listas y bloques
                _buildToolbarGroup([
                  _buildToolbarButton(Icons.format_list_bulleted, () => _controller.formatSelection(Attribute.ul), 'Lista con viñetas'),
                  _buildToolbarButton(Icons.format_list_numbered, () => _controller.formatSelection(Attribute.ol), 'Lista numerada'),
                  _buildToolbarButton(Icons.format_quote, () => _controller.formatSelection(Attribute.blockQuote), 'Cita'),
                  _buildToolbarButton(Icons.code, () => _controller.formatSelection(Attribute.codeBlock), 'Bloque de código'),
                ]),
                const SizedBox(width: 8),
                _buildToolbarDivider(),
                const SizedBox(width: 8),
                
                // Grupo: Deshacer/Rehacer
                _buildToolbarGroup([
                  _buildToolbarButton(Icons.undo, () => _controller.undo(), 'Deshacer (Ctrl+Z)'),
                  _buildToolbarButton(Icons.redo, () => _controller.redo(), 'Rehacer (Ctrl+Y)'),
                ]),
                const SizedBox(width: 8),
                _buildToolbarDivider(),
                const SizedBox(width: 8),
                
                // Grupo: Insertar contenido
                _buildToolbarGroup([
                  _buildToolbarButton(Icons.image_outlined, () => _insertImage(context), 'Insertar imagen'),
                  _buildToolbarButton(Icons.link, () => _insertLink(context), 'Insertar enlace'),
                  _buildToolbarButton(Icons.functions, _insertMathBlock, 'Insertar ecuación LaTeX'),
                  _buildToolbarButton(Icons.exposure, _insertMathInline, 'Ecuación inline'),
                ]),
                const SizedBox(width: 8),
                _buildToolbarDivider(),
                const SizedBox(width: 8),
                
                // Grupo: Herramientas
                _buildToolbarGroup([
                  _buildToolbarButton(Icons.search, () => _showSearchDialog(context), 'Buscar (Ctrl+F)'),
                  _buildToolbarButton(Icons.color_lens_outlined, () => _showColorPicker(context), 'Color de texto'),
                  _buildToolbarButton(_darkTheme ? Icons.light_mode_outlined : Icons.dark_mode_outlined, () => _toggleTheme(), 'Cambiar tema'),
                  _buildToolbarButton(Icons.fullscreen, () => _toggleFullscreen(context), 'Pantalla completa'),
                ]),
                const SizedBox(width: 8),
                _buildToolbarDivider(),
                const SizedBox(width: 8),
                
                // Grupo: Tamaño de fuente
                _buildToolbarGroup([
                  _buildToolbarButton(Icons.text_decrease, _decreaseFontSize, 'Reducir texto (Ctrl+-)'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${_editorFontSize.toInt()}px',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  _buildToolbarButton(Icons.text_increase, _increaseFontSize, 'Aumentar texto (Ctrl++)'),
                ]),
              ],
            ),
          ),
        ),
        // Editor area con diseño mejorado
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _darkTheme ? const Color(0xFF1E1E1E) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: Stack(
              children: [
                // Main editor con padding mejorado
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                    child: KeyboardListener(
                      focusNode: _editorFocusNode,
                      onKeyEvent: (event) {
                        if (event is KeyDownEvent) {
                          final isCtrl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
                          if (isCtrl && event.logicalKey == LogicalKeyboardKey.enter) {
                            _tryOpenWikilink();
                          }
                          // Zoom con Ctrl + / Ctrl -
                          if (isCtrl && event.logicalKey == LogicalKeyboardKey.equal) {
                            _increaseFontSize();
                          }
                          if (isCtrl && event.logicalKey == LogicalKeyboardKey.minus) {
                            _decreaseFontSize();
                          }
                          if (event.logicalKey == LogicalKeyboardKey.backspace) {
                            _handleBackspaceFormatExit();
                          }
                        }
                      },
                      child: DefaultTextStyle(
                        style: TextStyle(
                          fontSize: _editorFontSize,
                          height: 1.6,
                          color: _darkTheme ? Colors.white : Colors.black,
                        ),
                        child: QuillEditor.basic(
                          controller: _controller,
                        ),
                      ),
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
                // Math preview overlay mejorado (bottom-right)
                if (_showMathPreview && _mathPreview.isNotEmpty)
                  Positioned(
                    right: 20,
                    bottom: 20,
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(12),
                      shadowColor: Colors.black.withValues(alpha: 0.2),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 350, maxHeight: 250),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _mathIsBlock ? Icons.functions : Icons.exposure,
                                    size: 18,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _mathIsBlock ? 'Bloque LaTeX' : 'LaTeX inline',
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Preview content
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                child: SingleChildScrollView(
                                  child: Center(
                                    child: math.Math.tex(
                                      _mathPreview,
                                      textStyle: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontSize: _mathIsBlock ? 18 : 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Bottom bar con estadísticas y auto-guardado
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Estadísticas del documento (flexible para pantallas pequeñas)
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.article_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_getWordCount()} palabras',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 1,
                          height: 14,
                          color: Theme.of(context).dividerColor,
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.text_fields,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_controller.document.toPlainText().length} caracteres',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 1,
                          height: 14,
                          color: Theme.of(context).dividerColor,
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_getReadingTime()} min lectura',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Indicador de estado de guardado
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _hasUnsavedChanges 
                    ? Colors.orange.withValues(alpha: 0.1)
                    : Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _hasUnsavedChanges
                      ? Colors.orange.withValues(alpha: 0.3)
                      : Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _hasUnsavedChanges ? Icons.edit_note : Icons.cloud_done,
                      size: 16,
                      color: _hasUnsavedChanges ? Colors.orange : Colors.green,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _hasUnsavedChanges ? 'Editando...' : 'Guardado',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _hasUnsavedChanges ? Colors.orange.shade700 : Colors.green.shade700,
                      ),
                    ),
                    if (_lastSaveTime != null && !_hasUnsavedChanges) ...[
                      const SizedBox(width: 6),
                      Text(
                        _getTimeSinceSave(),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              // Botón de ayuda con tutorial
              IconButton(
                onPressed: () => _showHelpDialog(context),
                icon: const Icon(Icons.help_outline),
                tooltip: 'Ayuda y tutorial completo',
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5),
                  foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
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
      waitDuration: const Duration(milliseconds: 500),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ),
            child: Icon(
              icon,
              size: 20,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbarGroup(List<Widget> buttons) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: buttons.map((btn) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: btn,
        )).toList(),
      ),
    );
  }

  Widget _buildToolbarDivider() {
    return Container(
      width: 1,
      height: 28,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
    );
  }

  int _getWordCount() {
    final text = _controller.document.toPlainText();
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }
  
  int _getReadingTime() {
    final words = _getWordCount();
    // Promedio de 200 palabras por minuto
    final minutes = (words / 200).ceil();
    return minutes < 1 ? 1 : minutes;
  }
  
  String _getTimeSinceSave() {
    if (_lastSaveTime == null) return '';
    final diff = DateTime.now().difference(_lastSaveTime!);
    if (diff.inSeconds < 60) return 'ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'hace ${diff.inHours}h';
    return 'hace ${diff.inDays}d';
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

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
          child: const EditorHelpDialog(),
        ),
      ),
    );
  }

  void _increaseFontSize() {
    setState(() {
      if (_editorFontSize < 32) {
        _editorFontSize += 2;
      }
    });
  }
  
  void _decreaseFontSize() {
    setState(() {
      if (_editorFontSize > 10) {
        _editorFontSize -= 2;
      }
    });
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

// Widget de diálogo de ayuda completo e interactivo
class EditorHelpDialog extends StatefulWidget {
  const EditorHelpDialog({super.key});

  @override
  State<EditorHelpDialog> createState() => _EditorHelpDialogState();
}

class _EditorHelpDialogState extends State<EditorHelpDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 10, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTab = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header del diálogo
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.school_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tutorial Completo del Editor',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Aprende a usar todas las funcionalidades',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                tooltip: 'Cerrar',
              ),
            ],
          ),
        ),
        // Tabs
        Container(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: const [
              Tab(icon: Icon(Icons.rocket_launch), text: 'Inicio'),
              Tab(icon: Icon(Icons.format_bold), text: 'Formato'),
              Tab(icon: Icon(Icons.keyboard), text: 'Atajos'),
              Tab(icon: Icon(Icons.functions), text: 'LaTeX'),
              Tab(icon: Icon(Icons.link), text: 'Wikilinks'),
              Tab(icon: Icon(Icons.article), text: 'Markdown'),
              Tab(icon: Icon(Icons.palette), text: 'Diseño'),
              Tab(icon: Icon(Icons.image), text: 'Multimedia'),
              Tab(icon: Icon(Icons.speed), text: 'Avanzado'),
              Tab(icon: Icon(Icons.tips_and_updates), text: 'Tips'),
            ],
          ),
        ),
        // Contenido
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildWelcomeTab(),
              _buildFormatTab(),
              _buildShortcutsTab(),
              _buildLatexTab(),
              _buildWikilinksTab(),
              _buildMarkdownTab(),
              _buildDesignTab(),
              _buildMultimediaTab(),
              _buildAdvancedTab(),
              _buildTipsTab(),
            ],
          ),
        ),
        // Footer con navegación
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _currentTab > 0
                    ? () => _tabController.animateTo(_currentTab - 1)
                    : null,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Anterior'),
              ),
              Text(
                'Sección ${_currentTab + 1} de 6',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              TextButton.icon(
                onPressed: _currentTab < 9
                    ? () => _tabController.animateTo(_currentTab + 1)
                    : null,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Siguiente'),
                iconAlignment: IconAlignment.end,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primaryContainer,
                  Theme.of(context).colorScheme.secondaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.celebration, size: 48, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¡Bienvenido al Editor Avanzado!',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Un editor potente con LaTeX, Markdown, Wikilinks y mucho más',
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          _buildSectionTitle('🚀 Características Principales'),
          const SizedBox(height: 16),
          
          _buildFeatureHighlight(
            Icons.functions,
            'Ecuaciones LaTeX',
            'Escribe fórmulas matemáticas profesionales con sintaxis LaTeX completa',
            Colors.blue,
          ),
          _buildFeatureHighlight(
            Icons.link,
            'Wikilinks Inteligentes',
            'Conecta tus notas con [[enlaces]] y navegación instantánea',
            Colors.purple,
          ),
          _buildFeatureHighlight(
            Icons.article,
            'Markdown Automático',
            'Shortcuts que convierten automáticamente markdown a formato visual',
            Colors.green,
          ),
          _buildFeatureHighlight(
            Icons.palette,
            'Formato Rico',
            'Negrita, cursiva, colores, alineación y mucho más',
            Colors.orange,
          ),
          _buildFeatureHighlight(
            Icons.bolt,
            'Auto-guardado',
            'Guarda automáticamente cada 2 segundos sin interrumpir tu escritura',
            Colors.red,
          ),
          _buildFeatureHighlight(
            Icons.zoom_in,
            'Zoom de Texto',
            'Ajusta el tamaño de fuente de 10px a 32px con Ctrl+/Ctrl-',
            Colors.indigo,
          ),
          
          const SizedBox(height: 32),
          _buildSectionTitle('📚 Navegación del Tutorial'),
          const SizedBox(height: 16),
          
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildQuickNavChip(Icons.format_bold, 'Formato', 1),
              _buildQuickNavChip(Icons.keyboard, 'Atajos', 2),
              _buildQuickNavChip(Icons.functions, 'LaTeX', 3),
              _buildQuickNavChip(Icons.link, 'Wikilinks', 4),
              _buildQuickNavChip(Icons.article, 'Markdown', 5),
              _buildQuickNavChip(Icons.palette, 'Diseño', 6),
              _buildQuickNavChip(Icons.image, 'Multimedia', 7),
              _buildQuickNavChip(Icons.speed, 'Avanzado', 8),
              _buildQuickNavChip(Icons.tips_and_updates, 'Tips', 9),
            ],
          ),
          
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tip: Usa las flechas de navegación abajo para ir entre secciones, o haz clic en los chips de arriba para saltar directamente.',
                    style: TextStyle(color: Colors.blue.shade700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureHighlight(IconData icon, String title, String description, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickNavChip(IconData icon, String label, int tabIndex) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: () => _tabController.animateTo(tabIndex),
      backgroundColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
    );
  }

  Widget _buildFormatTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('📝 Formato de Texto'),
          const SizedBox(height: 16),
          _buildFeatureCard(
            icon: Icons.format_bold,
            title: 'Negrita',
            description: 'Haz que tu texto destaque con negrita',
            example: '**texto en negrita**',
            shortcut: 'Ctrl + B',
          ),
          _buildFeatureCard(
            icon: Icons.format_italic,
            title: 'Cursiva',
            description: 'Dale énfasis a tu texto con cursiva',
            example: '*texto en cursiva*',
            shortcut: 'Ctrl + I',
          ),
          _buildFeatureCard(
            icon: Icons.format_underline,
            title: 'Subrayado',
            description: 'Subraya texto importante',
            example: 'Usa el botón de toolbar',
            shortcut: 'Ctrl + U',
          ),
          _buildFeatureCard(
            icon: Icons.strikethrough_s,
            title: 'Tachado',
            description: 'Marca texto que ya no es relevante',
            example: '~~texto tachado~~',
            shortcut: 'Toolbar',
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('📐 Alineación'),
          const SizedBox(height: 16),
          _buildFeatureCard(
            icon: Icons.format_align_left,
            title: 'Alinear Izquierda',
            description: 'Alineación predeterminada del texto',
            example: 'Usa los botones de toolbar',
          ),
          _buildFeatureCard(
            icon: Icons.format_align_center,
            title: 'Centrar',
            description: 'Centra tu texto o títulos',
            example: 'Selecciona texto y usa toolbar',
          ),
          _buildFeatureCard(
            icon: Icons.format_align_right,
            title: 'Alinear Derecha',
            description: 'Alinea texto a la derecha',
            example: 'Útil para fechas o firmas',
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('⌨️ Atajos de Teclado'),
          const SizedBox(height: 16),
          _buildShortcutItem('Ctrl + B', 'Negrita', Icons.format_bold),
          _buildShortcutItem('Ctrl + I', 'Cursiva', Icons.format_italic),
          _buildShortcutItem('Ctrl + U', 'Subrayado', Icons.format_underline),
          _buildShortcutItem('Ctrl + Z', 'Deshacer', Icons.undo),
          _buildShortcutItem('Ctrl + Y', 'Rehacer', Icons.redo),
          _buildShortcutItem('Ctrl + F', 'Buscar', Icons.search),
          _buildShortcutItem('Ctrl + Enter', 'Abrir Wikilink', Icons.open_in_new),
          const SizedBox(height: 24),
          _buildSectionTitle('📋 Listas y Bloques'),
          const SizedBox(height: 16),
          _buildFeatureCard(
            icon: Icons.format_list_bulleted,
            title: 'Lista con Viñetas',
            description: 'Crea listas no ordenadas',
            example: '- Elemento\n- Otro elemento',
            shortcut: 'Escribe: - + espacio',
          ),
          _buildFeatureCard(
            icon: Icons.format_list_numbered,
            title: 'Lista Numerada',
            description: 'Crea listas ordenadas',
            example: '1. Primero\n2. Segundo',
            shortcut: 'Escribe: 1. + espacio',
          ),
          _buildFeatureCard(
            icon: Icons.format_quote,
            title: 'Cita',
            description: 'Cita texto o referencias',
            example: '> Esto es una cita',
            shortcut: 'Escribe: > + espacio',
          ),
          _buildFeatureCard(
            icon: Icons.code,
            title: 'Bloque de Código',
            description: 'Formatea código con monospace',
            example: '``` código aquí ```',
            shortcut: 'Escribe: ``` + espacio',
          ),
        ],
      ),
    );
  }

  Widget _buildLatexTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('🧮 Ecuaciones LaTeX'),
          const SizedBox(height: 8),
          Text(
            'Escribe ecuaciones matemáticas profesionales con LaTeX',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          _buildFeatureCard(
            icon: Icons.functions,
            title: 'Bloque LaTeX',
            description: 'Ecuaciones grandes en su propia línea',
            example: '\$\$ x = \\frac{-b \\pm \\sqrt{b^2-4ac}}{2a} \$\$',
            shortcut: 'Escribe: \$\$ + espacio',
            color: Colors.blue,
          ),
          _buildFeatureCard(
            icon: Icons.exposure,
            title: 'LaTeX Inline',
            description: 'Ecuaciones pequeñas dentro del texto',
            example: 'La ecuación \$E=mc^2\$ es famosa',
            shortcut: 'Escribe: \$ + espacio',
            color: Colors.blue,
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('📚 Ejemplos Comunes'),
          const SizedBox(height: 16),
          _buildLatexExample('Fracción', '\\frac{a}{b}'),
          _buildLatexExample('Raíz cuadrada', '\\sqrt{x}'),
          _buildLatexExample('Exponente', 'x^2'),
          _buildLatexExample('Subíndice', 'a_i'),
          _buildLatexExample('Sumatoria', '\\sum_{i=1}^{n} x_i'),
          _buildLatexExample('Integral', '\\int_0^\\infty e^{-x} dx'),
          _buildLatexExample('Límite', '\\lim_{x \\to \\infty} f(x)'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'El preview aparece automáticamente cuando escribes dentro de los delimitadores \$...\$ o \$\$...\$\$',
                    style: TextStyle(color: Colors.blue.shade700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWikilinksTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('🔗 Wikilinks - Enlaces entre Notas'),
          const SizedBox(height: 8),
          Text(
            'Conecta tus notas creando una red de conocimiento',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          _buildFeatureCard(
            icon: Icons.link,
            title: 'Crear Wikilink',
            description: 'Enlaza a otra nota escribiendo [[',
            example: '[[Nombre de la nota]]',
            shortcut: 'Escribe: [[',
            color: Colors.purple,
          ),
          _buildFeatureCard(
            icon: Icons.search,
            title: 'Autocompletado',
            description: 'Al escribir [[ aparece un menú con sugerencias',
            example: 'Escribe [[ y busca la nota',
            color: Colors.purple,
          ),
          _buildFeatureCard(
            icon: Icons.open_in_new,
            title: 'Abrir Wikilink',
            description: 'Navega rápidamente entre notas',
            example: 'Coloca el cursor en un [[link]]',
            shortcut: 'Ctrl + Enter',
            color: Colors.purple,
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('💡 Casos de Uso'),
          const SizedBox(height: 16),
          _buildUseCaseCard(
            '📚 Base de Conocimiento',
            'Conecta conceptos relacionados:\n"En [[Física Cuántica]] se estudia el [[Principio de Incertidumbre]]"',
          ),
          _buildUseCaseCard(
            '📝 Diario Personal',
            'Referencia entradas pasadas:\n"Como mencioné en [[2024-10-01]], el proyecto avanza"',
          ),
          _buildUseCaseCard(
            '🎯 Gestión de Proyectos',
            'Enlaza tareas y documentos:\n"Ver detalles en [[Especificaciones del Proyecto]]"',
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdownTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('📄 Atajos Markdown'),
          const SizedBox(height: 8),
          Text(
            'Escribe más rápido con sintaxis Markdown',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          _buildMarkdownShortcut('# ', 'Título Grande (H1)', '# Mi Título'),
          _buildMarkdownShortcut('## ', 'Título Mediano (H2)', '## Subtítulo'),
          _buildMarkdownShortcut('### ', 'Título Pequeño (H3)', '### Sección'),
          _buildMarkdownShortcut('- ', 'Lista con Viñetas', '- Elemento de lista'),
          _buildMarkdownShortcut('* ', 'Lista con Viñetas (alt)', '* Otro elemento'),
          _buildMarkdownShortcut('1. ', 'Lista Numerada', '1. Primer paso'),
          _buildMarkdownShortcut('> ', 'Cita', '> Texto citado'),
          _buildMarkdownShortcut('``` ', 'Bloque de Código', '``` tu código aquí'),
          _buildMarkdownShortcut('--- ', 'Línea Horizontal', '--- (en línea nueva)'),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tips_and_updates, color: Colors.green),
                    const SizedBox(width: 12),
                    Text(
                      'Tip Pro',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Todos estos atajos se activan automáticamente cuando escribes el patrón seguido de ESPACIO.',
                  style: TextStyle(color: Colors.green.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('✨ Tips y Trucos'),
          const SizedBox(height: 24),
          _buildTipCard(
            Icons.save,
            'Guardado Automático',
            'La nota se guarda automáticamente sin perder el foco del cursor. Puedes seguir escribiendo sin interrupciones.',
            Colors.blue,
          ),
          _buildTipCard(
            Icons.preview,
            'Vista Previa LaTeX',
            'El preview de ecuaciones LaTeX aparece automáticamente en la esquina inferior derecha cuando tu cursor está dentro de los delimitadores.',
            Colors.purple,
          ),
          _buildTipCard(
            Icons.link_off,
            'Salir de Formatos',
            'Presiona BACKSPACE al inicio de una línea formateada (lista, cita, etc.) para salir del formato.',
            Colors.orange,
          ),
          _buildTipCard(
            Icons.search,
            'Búsqueda Rápida',
            'Usa Ctrl+F para buscar texto en tu nota. El editor resaltará y navegará a los resultados.',
            Colors.green,
          ),
          _buildTipCard(
            Icons.color_lens,
            'Colores Personalizados',
            'Selecciona texto y usa el selector de color en la toolbar para dar énfasis visual.',
            Colors.red,
          ),
          _buildTipCard(
            Icons.fullscreen,
            'Modo Pantalla Completa',
            'Haz clic en el botón de pantalla completa para una experiencia de escritura sin distracciones.',
            Colors.indigo,
          ),
          _buildTipCard(
            Icons.image,
            'Imágenes y Enlaces',
            'Inserta imágenes con URLs y crea enlaces clickeables usando los botones de la toolbar.',
            Colors.teal,
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('📊 Estadísticas'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildStatRow(Icons.article_outlined, 'Contador de palabras', 'En la barra inferior'),
                _buildStatRow(Icons.text_fields, 'Contador de caracteres', 'Junto al contador de palabras'),
                _buildStatRow(Icons.history, 'Historial infinito', 'Ctrl+Z y Ctrl+Y ilimitados'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required String example,
    String? shortcut,
    Color? color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color?.withValues(alpha: 0.3) ?? Theme.of(context).dividerColor,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (color ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color ?? Theme.of(context).colorScheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (shortcut != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          shortcut,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: color ?? Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    example,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutItem(String shortcut, String action, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              action,
              style: const TextStyle(fontSize: 15),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              shortcut,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Theme.of(context).colorScheme.primary,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLatexExample(String name, String latex) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                latex,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUseCaseCard(String title, String example) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Colors.purple.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            example,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdownShortcut(String shortcut, String result, String example) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              shortcut,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.arrow_forward, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  example,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard(IconData icon, String title, String description, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesignTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('🎨 Personalización Visual'),
          const SizedBox(height: 16),
          
          _buildFeatureCard(
            icon: Icons.text_increase,
            title: 'Zoom de Texto',
            description: 'Ajusta el tamaño de la fuente para mejor legibilidad',
            example: 'Usa los botones +/- en la toolbar\no Ctrl + + / Ctrl + -',
            shortcut: 'Ctrl + / Ctrl -',
            color: Colors.indigo,
          ),
          
          _buildFeatureCard(
            icon: Icons.color_lens,
            title: 'Colores de Texto',
            description: 'Aplica colores personalizados a tu texto',
            example: 'Selecciona texto → Botón de color → Elige color',
            color: Colors.pink,
          ),
          
          _buildFeatureCard(
            icon: Icons.format_align_left,
            title: 'Alineación',
            description: 'Alinea texto a la izquierda, centro, derecha o justificado',
            example: 'Usa los botones de alineación en la toolbar',
            color: Colors.teal,
          ),
          
          _buildFeatureCard(
            icon: Icons.dark_mode,
            title: 'Modo Claro/Oscuro',
            description: 'Alterna entre tema claro y oscuro',
            example: 'Botón de luna/sol en la toolbar',
            color: Colors.deepPurple,
          ),
          
          const SizedBox(height: 24),
          _buildSectionTitle('🎯 Ajustes de Espacio'),
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'El editor usa espaciado inteligente:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 12),
                _buildSpacingItem('Líneas', 'Altura 1.6x para mejor lectura'),
                _buildSpacingItem('Párrafos', 'Espaciado automático entre párrafos'),
                _buildSpacingItem('Títulos', 'Espacios mayores para jerarquía visual'),
                _buildSpacingItem('Listas', 'Indentación automática'),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          _buildSectionTitle('💡 Tips de Diseño'),
          const SizedBox(height: 16),
          
          _buildTipCard(
            Icons.palette,
            'Usa Colores con Propósito',
            'Los colores ayudan a destacar información importante. Usa rojo para urgente, verde para completado, azul para enlaces.',
            Colors.orange,
          ),
          
          _buildTipCard(
            Icons.format_size,
            'Jerarquía con Títulos',
            'Usa H1 para títulos principales, H2 para secciones, H3 para subsecciones. Crea estructura visual clara.',
            Colors.blue,
          ),
          
          _buildTipCard(
            Icons.space_bar,
            'Espacio en Blanco',
            'No temas al espacio vacío. Las notas con buen espaciado son más fáciles de leer y escanear.',
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildSpacingItem(String label, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, size: 20, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultimediaTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('🖼️ Imágenes'),
          const SizedBox(height: 16),
          
          _buildFeatureCard(
            icon: Icons.image,
            title: 'Insertar Imagen',
            description: 'Añade imágenes con URLs',
            example: 'Botón de imagen → Pega URL → Insertar',
            color: Colors.blue,
          ),
          
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Las imágenes deben estar alojadas en internet (URL pública) para poder insertarlas.',
                    style: TextStyle(color: Colors.amber.shade700),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          _buildSectionTitle('🔗 Enlaces'),
          const SizedBox(height: 16),
          
          _buildFeatureCard(
            icon: Icons.link,
            title: 'Crear Enlace',
            description: 'Convierte texto en enlaces clicables',
            example: 'Selecciona texto → Botón enlace → Pega URL',
            color: Colors.purple,
          ),
          
          _buildFeatureCard(
            icon: Icons.open_in_new,
            title: 'Enlaces Externos',
            description: 'Los enlaces se pueden abrir en navegador',
            example: 'Haz clic en cualquier enlace creado',
            color: Colors.indigo,
          ),
          
          const SizedBox(height: 24),
          _buildSectionTitle('📎 Mejores Prácticas'),
          const SizedBox(height: 16),
          
          _buildPracticeCard(
            '✅ Usa URLs descriptivas',
            'En lugar de "Haz clic aquí", usa texto descriptivo como "Ver documentación oficial"',
            Colors.green,
          ),
          
          _buildPracticeCard(
            '✅ Optimiza imágenes',
            'Usa imágenes comprimidas para mejor rendimiento. Servicios como Imgur o Cloudinary funcionan bien.',
            Colors.blue,
          ),
          
          _buildPracticeCard(
            '✅ Texto alternativo',
            'Siempre describe qué muestra la imagen para contexto futuro',
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildPracticeCard(String title, String description, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('⚡ Rendimiento'),
          const SizedBox(height: 16),
          
          _buildFeatureCard(
            icon: Icons.save,
            title: 'Auto-guardado Inteligente',
            description: 'Guarda automáticamente sin interrumpir tu escritura',
            example: 'Se guarda cada 2 segundos de inactividad\nCompletamente silencioso y transparente',
            color: Colors.green,
          ),
          
          _buildFeatureCard(
            icon: Icons.flash_on,
            title: 'Atajos Markdown Instantáneos',
            description: 'Los shortcuts se aplican sin delay',
            example: 'Escribe # + espacio → título inmediato',
            color: Colors.orange,
          ),
          
          const SizedBox(height: 24),
          _buildSectionTitle('🔍 Búsqueda y Navegación'),
          const SizedBox(height: 16),
          
          _buildFeatureCard(
            icon: Icons.search,
            title: 'Búsqueda en Nota',
            description: 'Encuentra texto rápidamente',
            example: 'Ctrl + F → Escribe búsqueda → Navega resultados',
            shortcut: 'Ctrl + F',
            color: Colors.blue,
          ),
          
          _buildFeatureCard(
            icon: Icons.link,
            title: 'Navegación con Wikilinks',
            description: 'Salta entre notas conectadas',
            example: 'Coloca cursor en [[nota]] → Ctrl + Enter → Abre nota',
            shortcut: 'Ctrl + Enter en wikilink',
            color: Colors.purple,
          ),
          
          const SizedBox(height: 24),
          _buildSectionTitle('🛠️ Funciones Avanzadas'),
          const SizedBox(height: 16),
          
          _buildAdvancedFeature(
            Icons.undo,
            'Historial Infinito',
            'Deshacer y rehacer ilimitado. Nunca pierdas cambios.',
            'Ctrl + Z / Ctrl + Y',
          ),
          
          _buildAdvancedFeature(
            Icons.code,
            'Bloques de Código',
            'Formatea código con fuente monospace. Ideal para snippets.',
            'Escribe ``` + espacio',
          ),
          
          _buildAdvancedFeature(
            Icons.format_quote,
            'Citas y Referencias',
            'Crea bloques de citas visuales para referencias.',
            'Escribe > + espacio',
          ),
          
          _buildAdvancedFeature(
            Icons.horizontal_rule,
            'Separadores',
            'Añade líneas horizontales para dividir secciones.',
            'Escribe --- + espacio',
          ),
          
          const SizedBox(height: 24),
          _buildSectionTitle('📊 Estadísticas en Tiempo Real'),
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.withValues(alpha: 0.1),
                  Colors.purple.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.analytics, color: Colors.blue),
                    const SizedBox(width: 12),
                    Text(
                      'El editor muestra en tiempo real:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildStatItem(Icons.article_outlined, 'Contador de palabras', 'Para medir extensión'),
                _buildStatItem(Icons.text_fields, 'Caracteres totales', 'Útil para límites'),
                _buildStatItem(Icons.timer_outlined, 'Tiempo de lectura', 'Basado en 200 palabras/min'),
                _buildStatItem(Icons.edit_note, 'Estado de guardado', 'Editando... o Guardado'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedFeature(IconData icon, String title, String description, String howTo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    howTo,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
