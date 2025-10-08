import 'package:flutter/material.dart';
import '../theme/color_utils.dart';
import '../theme/app_theme.dart';

/// Overlay que muestra sugerencias de notas cuando el usuario escribe [[
class NoteAutocompleteOverlay extends StatelessWidget {
  final String query;
  final List<NoteSuggestion> suggestions;
  final Function(NoteSuggestion) onSelect;
  final VoidCallback onDismiss;

  const NoteAutocompleteOverlay({
    super.key,
    required this.query,
    required this.suggestions,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return _buildNoResults(context);
    }

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      color: AppColors.surface,
      child: Container(
        constraints: const BoxConstraints(
          maxHeight: 300,
          maxWidth: 400,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppColors.space12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.borderColor),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.link_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: AppColors.space8),
                  Text(
                    'Enlazar nota',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    query.isNotEmpty ? '"$query"' : 'Todas',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ],
              ),
            ),
            // Lista de sugerencias
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = suggestions[index];
                  return _buildSuggestionItem(context, suggestion);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionItem(BuildContext context, NoteSuggestion suggestion) {
    return InkWell(
      onTap: () => onSelect(suggestion),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppColors.space16,
          vertical: AppColors.space12,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.borderColor.withOpacityCompat(0.3),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.note_outlined,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: AppColors.space8),
                Expanded(
                  child: Text(
                    suggestion.title.isEmpty ? 'Sin título' : suggestion.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (suggestion.tags.isNotEmpty) ...[
              const SizedBox(height: AppColors.space4),
              Wrap(
                spacing: AppColors.space4,
                children: suggestion.tags.take(3).map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppColors.space4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacityCompat(0.1),
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    ),
                    child: Text(
                      tag,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.primary,
                            fontSize: 10,
                          ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      color: AppColors.surface,
      child: Container(
        padding: const EdgeInsets.all(AppColors.space16),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 32,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppColors.space8),
            Text(
              'No hay notas que coincidan',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
            ),
            if (query.isNotEmpty) ...[
              const SizedBox(height: AppColors.space4),
              Text(
                'Busca: "$query"',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Representa una sugerencia de nota para autocompletar
class NoteSuggestion {
  final String id;
  final String title;
  final List<String> tags;

  NoteSuggestion({
    required this.id,
    required this.title,
    this.tags = const [],
  });

  factory NoteSuggestion.fromMap(Map<String, dynamic> data) {
    return NoteSuggestion(
      id: data['id'] as String,
      title: (data['title'] as String?) ?? '',
      tags: (data['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}
