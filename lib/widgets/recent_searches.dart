import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/preferences_service.dart';

/// Widget para mostrar búsquedas recientes con autocompletado
class RecentSearches extends StatefulWidget {
  const RecentSearches({
    super.key,
    required this.onSearchSelected,
    this.maxVisible = 5,
  });

  final Function(String) onSearchSelected;
  final int maxVisible;

  @override
  State<RecentSearches> createState() => _RecentSearchesState();
}

class _RecentSearchesState extends State<RecentSearches> {
  List<String> _recentSearches = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  Future<void> _loadRecentSearches() async {
    final searches = await PreferencesService.getRecentSearches();
    if (!mounted) return;
    setState(() {
      _recentSearches = searches;
      _loading = false;
    });
  }

  Future<void> _clearAll() async {
    await PreferencesService.clearRecentSearches();
    if (!mounted) return;
    setState(() => _recentSearches = []);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppColors.space16),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_recentSearches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppColors.space16),
        child: Text(
          'No hay búsquedas recientes',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
        ),
      );
    }

    final visible = _recentSearches.take(widget.maxVisible).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(AppColors.space12),
            child: Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppColors.space8),
                Text(
                  'Búsquedas recientes',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (_recentSearches.isNotEmpty)
                  TextButton(
                    onPressed: _clearAll,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppColors.space8,
                        vertical: AppColors.space4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Limpiar',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Lista de búsquedas
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final search = visible[index];
              return InkWell(
                onTap: () => widget.onSearchSelected(search),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppColors.space16,
                    vertical: AppColors.space12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: AppColors.space12),
                      Expanded(
                        child: Text(
                          search,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.north_west_rounded,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
