import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_math_fork/flutter_math.dart';
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
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final int minLines;
  final Future<String?> Function(BuildContext context)? onPickImage;

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

  KeyEventResult _handleShortcuts(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isCtrl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyB) {
      _wrapSelection('**', '**');
      return KeyEventResult.handled;
    }
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyI) {
      _wrapSelection('*', '*');
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final editor = RawKeyboardListener(
      focusNode: _focus,
      onKey: (e) => _handleShortcuts(_focus, e),
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
          isSplit: _split,
          onPickImage: widget.onPickImage,
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, c) {
            if (!_split || c.maxWidth < 720) {
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
  RegExp get pattern => RegExp(r'^\$\$(.+)\$\$\s*$', multiLine: true);
  @override
  bool canEndBlock(md.BlockParser parser) => true;
  @override
  bool parse(md.BlockParser parser) {
    final match = pattern.firstMatch(parser.current);
    if (match == null) return false;
    final content = match.group(1) ?? '';
    final el = md.Element.text('tex', content);
    el.attributes['mode'] = 'block';
    parser.addNode(el);
    parser.advance();
    return true;
  }
}

class TexElementBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final tex = element.textContent;
    final mode = element.attributes['mode'] ?? 'inline';
    if (mode == 'block') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Math.tex(tex, textStyle: const TextStyle(fontSize: 15)),
      );
    }
    return Math.tex(tex, textStyle: const TextStyle(fontSize: 14));
  }
}
