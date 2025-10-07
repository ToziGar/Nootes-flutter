import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'markdown_toolbar.dart';

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
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final int minLines;
  final Future<String?> Function(BuildContext context)? onPickImage;
  final Future<String?> Function(BuildContext context)? onPickWiki;
  final Map<String, String>? wikiIndex; // title -> id
  final void Function(String noteId)? onOpenNote;
  final bool splitEnabled;

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
    widget.controller.value = widget.controller.value.copyWith(
      text: text.replaceRange(i, i, insert),
      selection: TextSelection.collapsed(offset: i + prefix.length),
      composing: TextRange.empty,
    );
  }

  void _onKey(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return;
    final keys = RawKeyboard.instance.keysPressed;
    final isCtrl = keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight) ||
        keys.contains(LogicalKeyboardKey.metaLeft) ||
        keys.contains(LogicalKeyboardKey.metaRight);
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyB) {
      _wrapSelection('**', '**');
      return;
    }
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyI) {
      _wrapSelection('*', '*');
      return;
    }
  }@override
  Widget build(BuildContext context) {
    final editor = RawKeyboardListener(
      focusNode: _focus,
      onKey: _onKey,
      child: TextField(
        controller: widget.controller,
        maxLines: null,
        minLines: widget.minLines,
        keyboardType: TextInputType.multiline,
        style: const TextStyle(fontFamily: 'monospace', height: 1.35),
        decoration: const InputDecoration(
          hintText: '# Escribe en Markdown…',
          alignLabelWithHint: true,
          border: OutlineInputBorder(),
        ),
      ),
    );

    final preview = Markdown(
      data: _rendered,
      shrinkWrap: true,
      selectable: true,
      builders: {
        'code': CodeElementBuilder(),
        'tex': TexElementBuilder(),
        'wikilink': WikiLinkBuilder(index: widget.wikiIndex, onOpen: widget.onOpenNote),
      },
      inlineSyntaxes: [InlineMathSyntax()],
      blockSyntaxes: [BlockMathSyntax()],
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        codeblockDecoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MarkdownToolbar(
          onWrapSelection: _wrapSelection,
          onInsertAtLineStart: _insertAtLineStart,
          onInsertBlock: _insertBlock,
          onToggleSplit: () => setState(() => _split = !_split),
          isSplit: widget.splitEnabled && _split,
          onPickImage: widget.onPickImage,
          onPickWiki: widget.onPickWiki,
          showSplitToggle: widget.splitEnabled,
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, c) {
            final useSplit = widget.splitEnabled && _split && c.maxWidth >= 720;
            if (!useSplit) {
              return editor;
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: editor),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: preview,
                  ),
                ),
              ],
            );
          },
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(8),
      ),
      child: HighlightView(
        text,
        language: lang.isEmpty ? 'plaintext' : lang,
        theme: githubTheme,
        padding: EdgeInsets.zero,
        textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.35),
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
