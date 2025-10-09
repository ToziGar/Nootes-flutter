import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'markdown_toolbar.dart';
import '../widgets/safe_network_image.dart';
// Simple Intents for editor shortcuts
class BoldIntent extends Intent {
  const BoldIntent();
}

class ItalicIntent extends Intent {
  const ItalicIntent();
}

class StrikeIntent extends Intent {
  const StrikeIntent();
}

class HeadingCycleIntent extends Intent {
  const HeadingCycleIntent();
}

class ToggleListIntent extends Intent {
  const ToggleListIntent();
}

class CodeBlockIntent extends Intent {
  const CodeBlockIntent();
}

class ToggleSplitIntent extends Intent {
  const ToggleSplitIntent();
}

class MarkdownEditor extends StatefulWidget {
  const MarkdownEditor({
    super.key,
    required this.controller,
    this.onChanged,
    this.minLines = 18,
    this.onPickImage,
    this.onPickWiki,
    this.wikiIndex,
    this.onOpenNote,
    this.splitEnabled = true,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final int minLines;
  final Future<String?> Function(BuildContext context)? onPickImage;
  final Future<String?> Function(BuildContext context)? onPickWiki;
  final Map<String, String>? wikiIndex; // title -> id
  final void Function(String noteId)? onOpenNote;
  final bool splitEnabled;
  final bool readOnly;

  @override
  State<MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  late final FocusNode _focus;
  bool _split = true;
  Timer? _debounce;
  String _rendered = '';

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
    _rendered = widget.controller.text;
    widget.controller.addListener(_scheduleRender);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_scheduleRender);
    _focus.dispose();
    super.dispose();
  }

  void _scheduleRender() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      setState(() => _rendered = widget.controller.text);
      widget.onChanged?.call(widget.controller.text);
    });
  }

  void _wrapSelection(String left, [String right = '']) {
    final text = widget.controller.text;
    final sel = widget.controller.selection;
    if (!sel.isValid) return;
    final start = sel.start;
    final end = sel.end;
    final selected = text.substring(start, end);
    final replace = '$left$selected${right.isEmpty ? left : right}';
    widget.controller.value = widget.controller.value.copyWith(
      text: text.replaceRange(start, end, replace),
      selection: TextSelection.collapsed(offset: start + left.length + selected.length),
      composing: TextRange.empty,
    );
  }

  void _insertAtLineStart(String prefix) {
    final text = widget.controller.text;
    final sel = widget.controller.selection;
    final i = sel.isValid ? sel.baseOffset : text.length;
    final lineStart = text.lastIndexOf('\n', i - 1) + 1;
    widget.controller.value = widget.controller.value.copyWith(
      text: text.replaceRange(lineStart, lineStart, prefix),
      selection: TextSelection.collapsed(offset: (sel.baseOffset + prefix.length)),
      composing: TextRange.empty,
    );
  }

  void _insertBlock(String prefix, [String suffix = '']) {
    final text = widget.controller.text;
    final sel = widget.controller.selection;
    final insert = suffix.isEmpty ? prefix : '$prefix$suffix';
    final i = sel.isValid ? sel.baseOffset : text.length;
    // Insert at current cursor position (cursor-aware)
    widget.controller.value = widget.controller.value.copyWith(
      text: text.replaceRange(i, i, insert),
      selection: TextSelection.collapsed(offset: i + prefix.length),
      composing: TextRange.empty,
    );
  }

  // Use Shortcuts+Actions to handle keyboard shortcuts (avoids deprecated RawKeyboard APIs)
  void _handleBoldIntent() => _wrapSelection('**', '**');
  void _handleItalicIntent() => _wrapSelection('*', '*');
  void _handleStrikeIntent() => _wrapSelection('~~', '~~');
  
  void _handleHeadingCycleIntent() {
    final text = widget.controller.text;
    final sel = widget.controller.selection;
    if (!sel.isValid) return;
    
    final lineStart = text.lastIndexOf('\n', sel.baseOffset - 1) + 1;
    final lineEnd = text.indexOf('\n', sel.baseOffset);
    final actualLineEnd = lineEnd == -1 ? text.length : lineEnd;
    final line = text.substring(lineStart, actualLineEnd);
    
    // Detect current heading level
    final headingMatch = RegExp(r'^(#{1,6})\s*').firstMatch(line);
    String newLine;
    
    if (headingMatch != null) {
      final currentLevel = headingMatch.group(1)!.length;
      final nextLevel = currentLevel >= 6 ? 0 : currentLevel + 1;
      final content = line.substring(headingMatch.end);
      newLine = nextLevel == 0 ? content : '${'#' * nextLevel} $content';
    } else {
      // Not a heading, make it H1
      newLine = '# $line';
    }
    
    widget.controller.value = widget.controller.value.copyWith(
      text: text.replaceRange(lineStart, actualLineEnd, newLine),
      selection: TextSelection.collapsed(offset: lineStart + newLine.length),
    );
  }
  
  void _handleToggleListIntent() {
    final text = widget.controller.text;
    final sel = widget.controller.selection;
    if (!sel.isValid) return;
    
    final lineStart = text.lastIndexOf('\n', sel.baseOffset - 1) + 1;
    final lineEnd = text.indexOf('\n', sel.baseOffset);
    final actualLineEnd = lineEnd == -1 ? text.length : lineEnd;
    final line = text.substring(lineStart, actualLineEnd);
    
    String newLine;
    if (line.startsWith('- ')) {
      // Remove bullet
      newLine = line.substring(2);
    } else if (line.startsWith('* ')) {
      // Remove bullet (alternative)
      newLine = line.substring(2);
    } else {
      // Add bullet
      newLine = '- $line';
    }
    
    widget.controller.value = widget.controller.value.copyWith(
      text: text.replaceRange(lineStart, actualLineEnd, newLine),
      selection: TextSelection.collapsed(offset: lineStart + newLine.length),
    );
  }
  
  void _handleCodeBlockIntent() => _insertBlock('```\n', '\n```');
  void _handleToggleSplitIntent() => setState(() => _split = !_split);

  @override
  Widget build(BuildContext context) {
    final editor = Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        // Ctrl/Cmd + B -> bold
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyB): const BoldIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyB): const BoldIntent(),
        // Ctrl/Cmd + I -> italic
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyI): const ItalicIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyI): const ItalicIntent(),
        // Ctrl/Cmd + Shift + X -> strike
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyX): const StrikeIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyX): const StrikeIntent(),
        // Ctrl/Cmd + Shift + H -> heading cycle
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyH): const HeadingCycleIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyH): const HeadingCycleIntent(),
        // Ctrl/Cmd + Shift + L -> toggle list
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyL): const ToggleListIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyL): const ToggleListIntent(),
        // Ctrl/Cmd + Alt + K -> code block
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.alt, LogicalKeyboardKey.keyK): const CodeBlockIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.alt, LogicalKeyboardKey.keyK): const CodeBlockIntent(),
        // Ctrl/Cmd + / -> toggle split
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.slash): const ToggleSplitIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.slash): const ToggleSplitIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          BoldIntent: CallbackAction<BoldIntent>(onInvoke: (intent) {
            _handleBoldIntent();
            return null;
          }),
          ItalicIntent: CallbackAction<ItalicIntent>(onInvoke: (intent) {
            _handleItalicIntent();
            return null;
          }),
          StrikeIntent: CallbackAction<StrikeIntent>(onInvoke: (intent) {
            _handleStrikeIntent();
            return null;
          }),
          HeadingCycleIntent: CallbackAction<HeadingCycleIntent>(onInvoke: (intent) {
            _handleHeadingCycleIntent();
            return null;
          }),
          ToggleListIntent: CallbackAction<ToggleListIntent>(onInvoke: (intent) {
            _handleToggleListIntent();
            return null;
          }),
          CodeBlockIntent: CallbackAction<CodeBlockIntent>(onInvoke: (intent) {
            _handleCodeBlockIntent();
            return null;
          }),
          ToggleSplitIntent: CallbackAction<ToggleSplitIntent>(onInvoke: (intent) {
            if (widget.splitEnabled) _handleToggleSplitIntent();
            return null;
          }),
        },
        child: Focus(
          focusNode: _focus,
          child: TextField(
            controller: widget.controller,
            readOnly: widget.readOnly,
            maxLines: null,
            minLines: widget.minLines,
            keyboardType: TextInputType.multiline,
            style: TextStyle(
              fontFamily: 'monospace', 
              height: 1.4,
              fontSize: 14,
              color: widget.readOnly 
                ? Theme.of(context).disabledColor
                : Theme.of(context).textTheme.bodyLarge?.color,
            ),
            decoration: InputDecoration(
              hintText: widget.readOnly ? 'Solo lectura' : '# Escribe en Markdown…',
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Theme.of(context).dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
              ),
              filled: true,
              fillColor: widget.readOnly 
                ? Theme.of(context).disabledColor.withValues(alpha: 0.1)
                : Theme.of(context).cardColor,
            ),
          ),
        ),
      ),
    );

    final preview = Markdown(
      data: _rendered,
      shrinkWrap: true,
      selectable: true,
      imageBuilder: (uri, title, alt) {
        return SafeNetworkImage(uri.toString(), fit: BoxFit.contain);
      },
      builders: {
        'code': CodeElementBuilder(),
        'tex': TexElementBuilder(),
        'wikilink': WikiLinkBuilder(index: widget.wikiIndex, onOpen: widget.onOpenNote),
      },
      inlineSyntaxes: [InlineMathSyntax(), WikiLinkSyntax()],
      blockSyntaxes: [BlockMathSyntax()],
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        codeblockDecoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark 
            ? Colors.grey[900] 
            : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
        ),
        code: TextStyle(
          backgroundColor: Theme.of(context).brightness == Brightness.dark 
            ? Colors.grey[800] 
            : Colors.grey[200],
          fontFamily: 'monospace',
          fontSize: 13,
        ),
        h1: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.headlineLarge?.color,
        ),
        h2: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.headlineMedium?.color,
        ),
        blockquote: TextStyle(
          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: Theme.of(context).primaryColor,
              width: 4,
            ),
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.readOnly)
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.visibility, color: Colors.orange, size: 16),
                const SizedBox(width: 6),
                Text('Solo lectura', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        MarkdownToolbar(
          onWrapSelection: widget.readOnly ? (_, [__='']) {} : _wrapSelection,
          onInsertAtLineStart: widget.readOnly ? (_) {} : _insertAtLineStart,
          onInsertBlock: widget.readOnly ? (_, [__='']) {} : _insertBlock,
          onToggleSplit: () => setState(() => _split = !_split),
          isSplit: widget.splitEnabled && _split,
          onPickImage: widget.readOnly ? null : widget.onPickImage,
          onPickWiki: widget.readOnly ? null : widget.onPickWiki,
          showSplitToggle: widget.splitEnabled,
          readOnly: widget.readOnly,
          controller: widget.controller,
        ),
        const SizedBox(height: 8),
        // Expanded must be a direct child of a Flex (Column). Place the
        // Expanded here so its child (LayoutBuilder) can return either the
        // editor (which will size to the available space) or a Row with two
        // Expanded children when in split mode.
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final useSplit = widget.splitEnabled && _split && c.maxWidth >= 720;
              if (!useSplit) {
                // In single-column mode just show the editor and let the
                // surrounding Expanded provide the vertical constraints.
                return editor;
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: editor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: preview,
                    ),
                  ),
                ],
              );
            },
          ),
        )
      ],
    );
  }
}

class CodeElementBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final text = element.textContent;
    final lang = element.attributes['class']?.replaceFirst('language-', '') ?? '';
    
    return Builder(
      builder: (context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark 
            ? Colors.grey[900] 
            : Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
        ),
        child: HighlightView(
          text,
          language: lang.isEmpty ? 'plaintext' : lang,
          theme: githubTheme, // Mantener tema claro por ahora
          padding: EdgeInsets.zero,
          textStyle: TextStyle(
            fontFamily: 'monospace', 
            fontSize: 13, 
            height: 1.4,
            color: Theme.of(context).brightness == Brightness.dark 
              ? Colors.grey[300] 
              : Colors.grey[800],
          ),
        ),
      ),
    );
  }
}

// Latex support: $inline$ and $$block$$
class InlineMathSyntax extends md.InlineSyntax {
  InlineMathSyntax() : super(r'(?<!\\)\$(.+?)\$');
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final el = md.Element.text('tex', match.group(1) ?? '');
    el.attributes['mode'] = 'inline';
    parser.addNode(el);
    return true;
  }
}

class BlockMathSyntax extends md.BlockSyntax {
  const BlockMathSyntax();
  @override
  RegExp get pattern => RegExp(r'^\$\$(.+)\$\$\s*$');
  @override
  bool canEndBlock(md.BlockParser parser) => true;
  @override
  bool canParse(md.BlockParser parser) => pattern.hasMatch(parser.current.content);
  @override
  md.Node? parse(md.BlockParser parser) {
    final line = parser.current.content;
    final match = pattern.firstMatch(line);
    if (match == null) return null;
    final content = match.group(1) ?? '';
    final el = md.Element.text('tex', content);
    el.attributes['mode'] = 'block';
    parser.advance();
    return el;
  }
}

class WikiLinkSyntax extends md.InlineSyntax {
  WikiLinkSyntax() : super(r'\[\[([^\]]+)\]\]');
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final title = match.group(1) ?? '';
    final el = md.Element.text('wikilink', title);
    parser.addNode(el);
    return true;
  }
}

class TexElementBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final tex = element.textContent;
    final mode = element.attributes['mode'] ?? 'inline';
    final style = TextStyle(
      fontFamily: 'monospace',
      fontSize: mode == 'block' ? 15 : 14,
      color: Colors.amberAccent,
    );
    return Padding(
      padding: mode == 'block' ? const EdgeInsets.symmetric(vertical: 6) : EdgeInsets.zero,
      child: Text('[TeX] $tex', style: style),
    );
  }
}

class WikiLinkBuilder extends MarkdownElementBuilder {
  WikiLinkBuilder({this.index, this.onOpen});
  final Map<String, String>? index;
  final void Function(String noteId)? onOpen;
  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final title = element.textContent;
    final id = index?[title] ?? '';
    final style = const TextStyle(color: Colors.lightBlueAccent, decoration: TextDecoration.underline);
    return GestureDetector(
      onTap: () {
        if (id.isNotEmpty && onOpen != null) onOpen!(id);
      },
      child: Text(title, style: style),
    );
  }
}
