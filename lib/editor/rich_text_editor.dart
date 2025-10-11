import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class RichTextEditor extends StatefulWidget {
  const RichTextEditor({
    super.key,
    required this.initialDeltaJson,
    this.onChanged,
    this.onSave,
    this.uid,
  });

  final Object? initialDeltaJson; // List delta or String json; null => empty
  final ValueChanged<String>? onChanged; // serialized delta JSON
  final Future<void> Function(String deltaJson)? onSave;
  final String? uid; // for image uploads

  @override
  State<RichTextEditor> createState() => _RichTextEditorState();
}

class _RichTextEditorState extends State<RichTextEditor> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _deltaToPlainText(widget.initialDeltaJson),
    );
    _controller.addListener(() {
      widget.onChanged?.call(_toDeltaJson(_controller.text));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Convert a (subset of) Quill delta JSON to plain text for editing
  String _deltaToPlainText(Object? any) {
    try {
      if (any == null) return '';
      final ops = any is String ? (jsonDecode(any) as List?) : (any as List?);
      if (ops == null) return any.toString();
      final buffer = StringBuffer();
      for (final op in ops) {
        final m = (op as Map?)?.map((k, v) => MapEntry(k.toString(), v));
        final ins = m?['insert'];
        if (ins is String) buffer.write(ins);
      }
      return buffer.toString();
    } catch (_) {
      return '';
    }
  }

  String _toDeltaJson(String text) {
    final ins = text.endsWith('\n') ? text : '$text\n';
    return jsonEncode([
      {'insert': ins},
    ]);
  }

  void _wrapSelection(String left, [String right = '']) {
    final text = _controller.text;
    final sel = _controller.selection;
    if (!sel.isValid) return;
    final start = sel.start;
    final end = sel.end;
    final selected = text.substring(start, end);
    final replace = '$left$selected${right.isEmpty ? left : right}';
    _controller.value = _controller.value.copyWith(
      text: text.replaceRange(start, end, replace),
      selection: TextSelection.collapsed(
        offset: start + left.length + selected.length,
      ),
      composing: TextRange.empty,
    );
  }

  void _insertAtLineStart(String prefix) {
    final text = _controller.text;
    final sel = _controller.selection;
    final i = sel.isValid ? sel.baseOffset : text.length;
    final searchFrom = (i - 1) < 0 ? 0 : (i - 1);
    final prevNewline = text.isEmpty ? -1 : text.lastIndexOf('\n', searchFrom);
    final lineStart = (prevNewline < 0 ? -1 : prevNewline) + 1;
    _controller.value = _controller.value.copyWith(
      text: text.replaceRange(lineStart, lineStart, prefix),
      selection: TextSelection.collapsed(
        offset: (sel.baseOffset + prefix.length),
      ),
      composing: TextRange.empty,
    );
  }

  Future<void> _insertImage() async {
    if (widget.uid == null) return;
    final url = await StorageService.pickAndUploadImage(uid: widget.uid!);
    if (url == null) return;
    final insertText = '![]($url)';
    final sel = _controller.selection;
    final i = sel.isValid ? sel.baseOffset : _controller.text.length;
    final text = _controller.text;
    // Insert at cursor position
    _controller.value = _controller.value.copyWith(
      text: text.replaceRange(i, i, insertText),
      selection: TextSelection.collapsed(offset: i + insertText.length),
      composing: TextRange.empty,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: 'Negrita',
              onPressed: () => _wrapSelection('**', '**'),
              icon: const Icon(Icons.format_bold),
            ),
            IconButton(
              tooltip: 'Itálica',
              onPressed: () => _wrapSelection('*', '*'),
              icon: const Icon(Icons.format_italic),
            ),
            IconButton(
              tooltip: 'H1',
              onPressed: () => _insertAtLineStart('# '),
              icon: const Icon(Icons.title),
            ),
            IconButton(
              tooltip: 'H2',
              onPressed: () => _insertAtLineStart('## '),
              icon: const Icon(Icons.title_outlined),
            ),
            IconButton(
              tooltip: 'Lista',
              onPressed: () => _insertAtLineStart('- '),
              icon: const Icon(Icons.format_list_bulleted),
            ),
            IconButton(
              tooltip: 'Número',
              onPressed: () => _insertAtLineStart('1. '),
              icon: const Icon(Icons.format_list_numbered),
            ),
            IconButton(
              tooltip: 'Imagen',
              onPressed: _insertImage,
              icon: const Icon(Icons.image),
            ),
            const SizedBox(width: 8),
            if (widget.onSave != null)
              FilledButton.icon(
                onPressed: () async {
                  await widget.onSave!(_toDeltaJson(_controller.text));
                },
                icon: const Icon(Icons.save),
                label: const Text('Guardar'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white10),
            borderRadius: BorderRadius.circular(8),
          ),
          constraints: const BoxConstraints(minHeight: 240),
          child: TextField(
            controller: _controller,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              hintText: 'Escribe con formato enriquecido.',
              contentPadding: EdgeInsets.all(12),
              border: InputBorder.none,
            ),
            style: const TextStyle(height: 1.4),
          ),
        ),
      ],
    );
  }
}
