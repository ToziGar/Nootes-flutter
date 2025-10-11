import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Opciones de ordenamiento para notas
enum SortOption {
  dateDesc('Más recientes primero', Icons.access_time_rounded),
  dateAsc('Más antiguas primero', Icons.history_rounded),
  titleAsc('Título A-Z', Icons.sort_by_alpha_rounded),
  titleDesc('Título Z-A', Icons.sort_rounded),
  updated('Última modificación', Icons.edit_rounded);

  const SortOption(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Diálogo de búsqueda y filtros avanzados
class AdvancedSearchDialog extends StatefulWidget {
  const AdvancedSearchDialog({
    super.key,
    this.initialSearchQuery,
    this.initialSelectedTags,
    this.initialDateRange,
    this.initialSortOption,
    required this.availableTags,
  });

  final String? initialSearchQuery;
  final List<String>? initialSelectedTags;
  final DateTimeRange? initialDateRange;
  final SortOption? initialSortOption;
  final List<String> availableTags;

  @override
  State<AdvancedSearchDialog> createState() => _AdvancedSearchDialogState();
}

class _AdvancedSearchDialogState extends State<AdvancedSearchDialog> {
  late TextEditingController _searchController;
  late Set<String> _selectedTags;
  DateTimeRange? _dateRange;
  SortOption _sortOption = SortOption.dateDesc;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.initialSearchQuery ?? '',
    );
    _selectedTags = Set.from(widget.initialSelectedTags ?? []);
    _dateRange = widget.initialDateRange;
    _sortOption = widget.initialSortOption ?? SortOption.dateDesc;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    Navigator.pop(context, {
      'query': _searchController.text,
      'tags': _selectedTags.toList(),
      'dateRange': _dateRange,
      'sortOption': _sortOption,
    });
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedTags.clear();
      _dateRange = null;
      _sortOption = SortOption.dateDesc;
    });
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        padding: const EdgeInsets.all(AppColors.space24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppColors.space12),
                  decoration: BoxDecoration(
                    gradient: AppTheme.gradientPrimary,
                    borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  ),
                  child: const Icon(
                    Icons.filter_list_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppColors.space16),
                const Expanded(
                  child: Text(
                    'Búsqueda Avanzada',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppColors.space24),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Search query
                    _buildSectionTitle('Buscar en notas', Icons.search_rounded),
                    const SizedBox(height: AppColors.space12),
                    TextField(
                      controller: _searchController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Buscar en título y contenido...',
                        hintStyle: const TextStyle(color: AppColors.textMuted),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.primary,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear_rounded,
                                  color: AppColors.textMuted,
                                ),
                                onPressed: () {
                                  setState(() => _searchController.clear());
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.surfaceLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppColors.radiusMd,
                          ),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppColors.radiusMd,
                          ),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppColors.space24),

                    // Tags filter
                    _buildSectionTitle(
                      'Filtrar por etiquetas',
                      Icons.label_rounded,
                    ),
                    const SizedBox(height: AppColors.space12),
                    if (widget.availableTags.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(AppColors.space16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(
                            AppColors.radiusMd,
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: AppColors.textMuted,
                              size: 20,
                            ),
                            SizedBox(width: AppColors.space12),
                            Expanded(
                              child: Text(
                                'No hay etiquetas disponibles',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(AppColors.space16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(
                            AppColors.radiusMd,
                          ),
                        ),
                        child: Wrap(
                          spacing: AppColors.space8,
                          runSpacing: AppColors.space8,
                          children: widget.availableTags.map((tag) {
                            final isSelected = _selectedTags.contains(tag);
                            return FilterChip(
                              label: Text(tag),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedTags.add(tag);
                                  } else {
                                    _selectedTags.remove(tag);
                                  }
                                });
                              },
                              backgroundColor: AppColors.surface,
                              selectedColor: AppColors.primary.withValues(
                                alpha: 0.2,
                              ),
                              checkmarkColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.borderColor,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: AppColors.space24),

                    // Date range
                    _buildSectionTitle(
                      'Filtrar por fecha',
                      Icons.calendar_today_rounded,
                    ),
                    const SizedBox(height: AppColors.space12),
                    InkWell(
                      onTap: _selectDateRange,
                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                      child: Container(
                        padding: const EdgeInsets.all(AppColors.space16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(
                            AppColors.radiusMd,
                          ),
                          border: Border.all(
                            color: _dateRange != null
                                ? AppColors.primary
                                : AppColors.borderColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.date_range_rounded,
                              color: _dateRange != null
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                            ),
                            const SizedBox(width: AppColors.space12),
                            Expanded(
                              child: Text(
                                _dateRange != null
                                    ? '${_formatDate(_dateRange!.start)} - ${_formatDate(_dateRange!.end)}'
                                    : 'Seleccionar rango de fechas',
                                style: TextStyle(
                                  color: _dateRange != null
                                      ? AppColors.textPrimary
                                      : AppColors.textMuted,
                                  fontWeight: _dateRange != null
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (_dateRange != null)
                              IconButton(
                                icon: const Icon(
                                  Icons.clear_rounded,
                                  color: AppColors.textMuted,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    setState(() => _dateRange = null),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppColors.space24),

                    // Sort option
                    _buildSectionTitle('Ordenar por', Icons.sort_rounded),
                    const SizedBox(height: AppColors.space12),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(AppColors.radiusMd),
                      ),
                      child: Column(
                        children: SortOption.values.map((option) {
                          final isSelected = _sortOption == option;
                          return InkWell(
                            onTap: () => setState(() => _sortOption = option),
                            child: Container(
                              padding: const EdgeInsets.all(AppColors.space16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withValues(alpha: 0.15)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(
                                  AppColors.radiusMd,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    option.icon,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: AppColors.space12),
                                  Expanded(
                                    child: Text(
                                      option.label,
                                      style: TextStyle(
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.textPrimary,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_rounded,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppColors.space24),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _clearFilters,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppColors.space16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppColors.radiusMd),
                      ),
                      side: const BorderSide(color: AppColors.borderColor),
                    ),
                    child: const Text('Limpiar'),
                  ),
                ),
                const SizedBox(width: AppColors.space12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _applyFilters,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppColors.space16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppColors.radiusMd),
                      ),
                    ),
                    child: const Text('Aplicar Filtros'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: AppColors.space8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
