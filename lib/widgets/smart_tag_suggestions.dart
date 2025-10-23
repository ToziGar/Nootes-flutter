import 'dart:async';
import 'package:flutter/material.dart';
import '../services/smart_tag_service.dart';
import '../services/logging_service.dart';

/// Widget que muestra sugerencias de etiquetas inteligentes
class SmartTagSuggestions extends StatefulWidget {
  final String title;
  final String content;
  final List<String> currentTags;
  final Function(String) onTagSelected;
  final int maxSuggestions;
  final Duration debounce;

  const SmartTagSuggestions({
    super.key,
    required this.title,
    required this.content,
    required this.currentTags,
    required this.onTagSelected,
    this.maxSuggestions = 8,
    this.debounce = const Duration(milliseconds: 300),
  });

  @override
  State<SmartTagSuggestions> createState() => _SmartTagSuggestionsState();
}

class _SmartTagSuggestionsState extends State<SmartTagSuggestions> {
  Timer? _debounceTimer;
  List<String> _suggestions = const [];
  bool _hidden = false;
  bool _isComputing = false;
  DateTime? _computeStart;

  @override
  void initState() {
    super.initState();
    _recomputeSuggestions();
  }

  @override
  void didUpdateWidget(covariant SmartTagSuggestions oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If inputs changed, debounce recompute
    if (oldWidget.title != widget.title ||
        oldWidget.content != widget.content ||
        !_listEquals(oldWidget.currentTags, widget.currentTags) ||
        oldWidget.maxSuggestions != widget.maxSuggestions) {
      _debounceTimer?.cancel();
      setState(() {
        _isComputing = true;
      });
      _computeStart = DateTime.now();
      _debounceTimer = Timer(widget.debounce, _recomputeSuggestions);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _recomputeSuggestions() {
    final all = SmartTagService().suggestTags(
      title: widget.title,
      content: widget.content,
      maxTags: widget.maxSuggestions + widget.currentTags.length,
    );
    final filtered = all
        .where((t) => !widget.currentTags.contains(t))
        .take(widget.maxSuggestions)
        .toList();
    if (!mounted) return;
    setState(() {
      _suggestions = filtered;
      _isComputing = false;
    });

    if (_computeStart != null) {
      final duration = DateTime.now().difference(_computeStart!);
      LoggingService.logPerformance(
        'SmartTagSuggestions.recompute',
        duration,
        metadata: {
          'title_len': widget.title.length,
          'content_len': widget.content.length,
          'current_tags': widget.currentTags.length,
          'suggestions': _suggestions.length,
        },
      );
      _computeStart = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) {
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Mostrar etiquetas sugeridas'),
          onPressed: () => setState(() => _hidden = false),
        ),
      );
    }

    if (_suggestions.isEmpty) {
      if (_isComputing) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: const [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Buscando etiquetas…'),
              ],
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Etiquetas sugeridas',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const Spacer(),
                if (_isComputing) ...[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                ],
                if (_suggestions.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.playlist_add),
                    label: const Text('Agregar todas'),
                    onPressed: () {
                      LoggingService.logUserAction(
                        'smart_tags_add_all',
                        parameters: {
                          'count': _suggestions.length,
                        },
                      );
                      for (final tag in _suggestions) {
                        widget.onTagSelected(tag);
                      }
                    },
                  ),
                IconButton(
                  tooltip: 'Ocultar sugerencias',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    LoggingService.logUserAction('smart_tags_hide');
                    setState(() => _hidden = true);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _suggestions.map((tag) {
                return ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: Text(tag),
                    onPressed: () {
                      LoggingService.logUserAction(
                        'smart_tags_add_one',
                        parameters: {'tag': tag},
                      );
                      widget.onTagSelected(tag);
                    },
                  tooltip: 'Agregar etiqueta "$tag"',
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
