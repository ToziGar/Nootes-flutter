import 'package:flutter/material.dart';

class TagInput extends StatefulWidget {
  const TagInput({
    super.key,
    required this.initialTags,
    required this.onAdd,
    required this.onRemove,
    this.hintText = 'Añadir etiqueta...'
  });

  final List<String> initialTags;
  final Future<void> Function(String tag) onAdd;
  final Future<void> Function(String tag) onRemove;
  final String hintText;

  @override
  State<TagInput> createState() => _TagInputState();
}

class _TagInputState extends State<TagInput> {
  late List<String> _tags;
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tags = [...widget.initialTags];
  }

  @override
  void didUpdateWidget(covariant TagInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTags != widget.initialTags) {
      _tags = [...widget.initialTags];
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add(String v) async {
    final tag = v.trim();
    if (tag.isEmpty) return;
    if (_tags.contains(tag)) {
      _controller.clear();
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onAdd(tag);
      setState(() {
        _tags.add(tag);
        _controller.clear();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(String tag) async {
    setState(() => _busy = true);
    try {
      await widget.onRemove(tag);
      setState(() => _tags.remove(tag));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: -6,
          children: [
            for (final t in _tags)
              Chip(
                label: Text(t),
                onDeleted: _busy ? null : () => _remove(t),
              ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260, minWidth: 120),
              child: TextField(
                controller: _controller,
                enabled: !_busy,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  prefixIcon: const Icon(Icons.add_rounded),
                ),
                onSubmitted: (v) => _busy ? null : _add(v),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

