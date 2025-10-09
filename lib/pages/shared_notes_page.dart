import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/sharing_service.dart';
import '../services/toast_service.dart';
import '../services/notification_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

/// Tipos de actividad en el log
enum ActivityType {
  shareCreated,
  shareAccepted,
  shareRejected,
  shareRevoked,
  shareModified,
  shareAccessed,
}

/// Plantillas predefinidas de permisos
enum PermissionTemplate {
  viewer,
  collaborator,
  editor,
}

extension PermissionTemplateExtension on PermissionTemplate {
  String get name {
    switch (this) {
      case PermissionTemplate.viewer:
        return 'Solo Lectura';
      case PermissionTemplate.collaborator:
        return 'Colaborador';
      case PermissionTemplate.editor:
        return 'Editor Completo';
    }
  }

  String get description {
    switch (this) {
      case PermissionTemplate.viewer:
        return 'Puede ver y comentar el contenido, pero no editarlo';
      case PermissionTemplate.collaborator:
        return 'Puede ver, comentar y sugerir cambios';
      case PermissionTemplate.editor:
        return 'Puede ver, comentar y editar libremente';
    }
  }

  PermissionLevel get permissionLevel {
    switch (this) {
      case PermissionTemplate.viewer:
        return PermissionLevel.read;
      case PermissionTemplate.collaborator:
        return PermissionLevel.comment;
      case PermissionTemplate.editor:
        return PermissionLevel.edit;
    }
  }

  IconData get icon {
    switch (this) {
      case PermissionTemplate.viewer:
        return Icons.visibility_rounded;
      case PermissionTemplate.collaborator:
        return Icons.comment_rounded;
      case PermissionTemplate.editor:
        return Icons.edit_rounded;
    }
  }

  Color get color {
    switch (this) {
      case PermissionTemplate.viewer:
        return Colors.blue;
      case PermissionTemplate.collaborator:
        return Colors.orange;
      case PermissionTemplate.editor:
        return Colors.green;
    }
  }
}

/// Entrada del log de actividad
class ActivityLogEntry {
  final String id;
  final ActivityType type;
  final String title;
  final String description;
  final String itemTitle;
  final String userEmail;
  final DateTime timestamp;

  const ActivityLogEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.itemTitle,
    required this.userEmail,
    required this.timestamp,
  });

  IconData get icon {
    switch (type) {
      case ActivityType.shareCreated:
        return Icons.share_rounded;
      case ActivityType.shareAccepted:
        return Icons.check_circle_rounded;
      case ActivityType.shareRejected:
        return Icons.cancel_rounded;
      case ActivityType.shareRevoked:
        return Icons.block_rounded;
      case ActivityType.shareModified:
        return Icons.edit_rounded;
      case ActivityType.shareAccessed:
        return Icons.visibility_rounded;
    }
  }

  Color get color {
    switch (type) {
      case ActivityType.shareCreated:
        return Colors.blue;
      case ActivityType.shareAccepted:
        return Colors.green;
      case ActivityType.shareRejected:
        return Colors.red;
      case ActivityType.shareRevoked:
        return Colors.orange;
      case ActivityType.shareModified:
        return Colors.purple;
      case ActivityType.shareAccessed:
        return Colors.teal;
    }
  }
}

/// Página moderna para gestionar notas compartidas con diseño avanzado
class SharedNotesPage extends StatefulWidget {
  const SharedNotesPage({super.key});

  @override
  State<SharedNotesPage> createState() => _SharedNotesPageState();
}

class _SharedNotesPageState extends State<SharedNotesPage> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Servicios
  final _sharingService = SharingService();
  // final _notificationService = NotificationService(); // Commented out until used
  
  // Estado
  List<SharedItem> _sharedByMe = [];
  List<SharedItem> _sharedWithMe = [];
  bool _isLoading = false;
  String _searchQuery = '';
  SharingStatus? _selectedStatus;
  SharedItemType? _selectedType;
  String _userFilterQuery = '';
  DateTime? _dateFrom;
  DateTime? _dateTo;
  Map<String, int> _stats = {};

  // Selección múltiple
  bool _isMultiSelectMode = false;
  Set<String> _selectedItems = {};

  // Controladores
  final _searchController = TextEditingController();
  final _userFilterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _loadData();
    _animationController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    
    try {
      print('📊 SharedNotesPage: Iniciando carga de datos...');
      final sharingService = SharingService();
      
      final results = await Future.wait([
        sharingService.getSharedByMe(
          status: _selectedStatus,
          type: _selectedType,
          searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        ),
        sharingService.getSharedWithMe(
          status: _selectedStatus,
          type: _selectedType,
          searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        ),
        sharingService.getSharingStats(),
      ]);
      
      var sharedByMe = results[0] as List<SharedItem>;
      var sharedWithMe = results[1] as List<SharedItem>;
      final stats = results[2] as Map<String, int>;

      // Aplicar filtros adicionales
      sharedByMe = _applyAdvancedFilters(sharedByMe, true);
      sharedWithMe = _applyAdvancedFilters(sharedWithMe, false);
      
      print('📊 SharedNotesPage: Cargadas ${sharedByMe.length} enviadas, ${sharedWithMe.length} recibidas');
      
      if (mounted) {
        setState(() {
          _sharedByMe = sharedByMe;
          _sharedWithMe = sharedWithMe;
          _stats = stats;
        });
      }
    } catch (e) {
      print('❌ SharedNotesPage: Error cargando datos - $e');
      if (mounted) {
        ToastService.error('Error cargando datos: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Aplica filtros avanzados de fecha y usuario
  List<SharedItem> _applyAdvancedFilters(List<SharedItem> items, bool isSentByMe) {
    var filteredItems = items;

    // Filtro por usuario
    if (_userFilterQuery.isNotEmpty) {
      filteredItems = filteredItems.where((item) {
        final targetEmail = isSentByMe ? item.recipientEmail : item.ownerEmail;
        return targetEmail.toLowerCase().contains(_userFilterQuery);
      }).toList();
    }

    // Filtro por fecha
    if (_dateFrom != null || _dateTo != null) {
      filteredItems = filteredItems.where((item) {
        final itemDate = item.createdAt;
        
        if (_dateFrom != null && itemDate.isBefore(_dateFrom!)) {
          return false;
        }
        
        if (_dateTo != null && itemDate.isAfter(_dateTo!.add(const Duration(days: 1)))) {
          return false;
        }
        
        return true;
      }).toList();
    }

    return filteredItems;
  }

  // Métodos de selección múltiple
  void _toggleMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = !_isMultiSelectMode;
      if (!_isMultiSelectMode) {
        _selectedItems.clear();
      }
    });
  }

  void _toggleItemSelection(String itemId) {
    setState(() {
      if (_selectedItems.contains(itemId)) {
        _selectedItems.remove(itemId);
      } else {
        _selectedItems.add(itemId);
      }
      
      // Si no hay elementos seleccionados, salir del modo de selección
      if (_selectedItems.isEmpty) {
        _isMultiSelectMode = false;
      }
    });
  }

  void _selectAllItems() {
    setState(() {
      final currentTabItems = _tabController.index == 0 ? _sharedByMe : _sharedWithMe;
      _selectedItems.addAll(currentTabItems.map((item) => item.id));
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedItems.clear();
      _isMultiSelectMode = false;
    });
  }

  Future<void> _performBulkAction(String action) async {
    if (_selectedItems.isEmpty) return;

    final confirmed = await _showConfirmationDialog(
      title: 'Confirmar acción masiva',
      content: '¿Aplicar "$action" a ${_selectedItems.length} elementos seleccionados?',
      confirmText: 'Aplicar',
      isDestructive: action == 'revocar' || action == 'rechazar',
    );

    if (confirmed != true) return;

    try {
      final sharingService = SharingService();
      int successful = 0;
      int failed = 0;

      for (final itemId in _selectedItems) {
        try {
          switch (action) {
            case 'revocar':
              await sharingService.revokeSharing(itemId);
              break;
            case 'aceptar':
              await sharingService.acceptSharing(itemId);
              break;
            case 'rechazar':
              await sharingService.rejectSharing(itemId);
              break;
          }
          successful++;
        } catch (e) {
          failed++;
          debugPrint('Error en acción masiva para $itemId: $e');
        }
      }

      _clearSelection();
      await _loadData();

      if (successful > 0) {
        ToastService.success('✅ Aplicado a $successful elementos');
      }
      if (failed > 0) {
        ToastService.warning('⚠️ Falló en $failed elementos');
      }
    } catch (e) {
      ToastService.error('❌ Error en acción masiva: $e');
    }
  }

  Future<void> _acceptSharing(SharedItem item) async {
    try {
      await SharingService().acceptSharing(item.id);
      ToastService.success('✅ Compartición aceptada');
      await _loadData();
    } catch (e) {
      ToastService.error('❌ Error: $e');
    }
  }

  Future<void> _rejectSharing(SharedItem item) async {
    try {
      await SharingService().rejectSharing(item.id);
      ToastService.success('✅ Compartición rechazada');
      await _loadData();
    } catch (e) {
      ToastService.error('❌ Error: $e');
    }
  }

  Future<void> _revokeSharing(SharedItem item) async {
    final confirmed = await _showConfirmationDialog(
      title: 'Revocar compartición',
      content: '¿Estás seguro de que quieres revocar el acceso a "${item.metadata?['noteTitle'] ?? item.metadata?['folderName'] ?? 'este elemento'}"?',
      confirmText: 'Revocar',
      isDestructive: true,
    );

    if (confirmed == true) {
      try {
        await SharingService().revokeSharing(item.id);
        ToastService.success('✅ Compartición revocada');
        await _loadData();
      } catch (e) {
        ToastService.error('❌ Error: $e');
      }
    }
  }

  Future<bool?> _showConfirmationDialog({
    required String title,
    required String content,
    required String confirmText,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          content,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? AppColors.danger : AppColors.primary,
              foregroundColor: AppColors.textPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildFilterBottomSheet(),
    );
  }

  Widget _buildFilterBottomSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.1),
                  AppColors.primary.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.filter_list_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filtros avanzados',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Personaliza tu vista',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Filtros
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilterSection(
                    'Estado',
                    Icons.flag_rounded,
                    _buildStatusFilter(),
                  ),
                  const SizedBox(height: 24),
                  _buildFilterSection(
                    'Tipo',
                    Icons.category_rounded,
                    _buildTypeFilter(),
                  ),
                  const SizedBox(height: 24),
                  _buildFilterSection(
                    'Usuario',
                    Icons.person_rounded,
                    _buildUserFilter(),
                  ),
                  const SizedBox(height: 24),
                  _buildFilterSection(
                    'Fecha',
                    Icons.date_range_rounded,
                    _buildDateFilter(),
                  ),
                  const Spacer(),
                  
                  // Botones de acción
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _selectedStatus = null;
                              _selectedType = null;
                              _searchQuery = '';
                              _searchController.clear();
                              _userFilterQuery = '';
                              _userFilterController.clear();
                              _dateFrom = null;
                              _dateTo = null;
                            });
                            Navigator.of(context).pop();
                            _loadData();
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: AppColors.borderColor),
                          ),
                          child: Text(
                            'Limpiar',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _loadData();
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.textPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Aplicar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(String title, IconData icon, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        content,
      ],
    );
  }

  Widget _buildStatusFilter() {
    return Wrap(
      spacing: 8,
      children: [null, ...SharingStatus.values].map((status) {
        final isSelected = _selectedStatus == status;
        return FilterChip(
          label: Text(_getStatusText(status)),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              _selectedStatus = selected ? status : null;
            });
          },
          backgroundColor: AppColors.surfaceLight,
          selectedColor: AppColors.primary.withValues(alpha: 0.2),
          checkmarkColor: AppColors.primary,
          labelStyle: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
          side: BorderSide(
            color: isSelected ? AppColors.primary : AppColors.borderColor,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTypeFilter() {
    return Wrap(
      spacing: 8,
      children: [null, ...SharedItemType.values].map((type) {
        final isSelected = _selectedType == type;
        return FilterChip(
          label: Text(_getTypeText(type)),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              _selectedType = selected ? type : null;
            });
          },
          backgroundColor: AppColors.surfaceLight,
          selectedColor: AppColors.secondary.withValues(alpha: 0.2),
          checkmarkColor: AppColors.secondary,
          labelStyle: TextStyle(
            color: isSelected ? AppColors.secondary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
          side: BorderSide(
            color: isSelected ? AppColors.secondary : AppColors.borderColor,
          ),
        );
      }).toList(),
    );
  }

  String _getStatusText(SharingStatus? status) {
    switch (status) {
      case null: return 'Todos';
      case SharingStatus.pending: return 'Pendientes';
      case SharingStatus.accepted: return 'Aceptadas';
      case SharingStatus.rejected: return 'Rechazadas';
      case SharingStatus.revoked: return 'Revocadas';
    }
  }

  String _getTypeText(SharedItemType? type) {
    switch (type) {
      case null: return 'Todos';
      case SharedItemType.note: return 'Notas';
      case SharedItemType.folder: return 'Carpetas';
      case SharedItemType.collection: return 'Colecciones';
    }
  }

  Widget _buildUserFilter() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: TextField(
        controller: _userFilterController,
        decoration: InputDecoration(
          hintText: 'Buscar por email de usuario...',
          hintStyle: TextStyle(color: AppColors.textSecondary),
          prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
          suffixIcon: _userFilterQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: AppColors.textSecondary),
                  onPressed: () {
                    setState(() {
                      _userFilterQuery = '';
                      _userFilterController.clear();
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        style: TextStyle(color: AppColors.textPrimary),
        onChanged: (value) {
          setState(() {
            _userFilterQuery = value.trim().toLowerCase();
          });
        },
      ),
    );
  }

  Widget _buildDateFilter() {
    return Column(
      children: [
        // Filtros rápidos de fecha
        Wrap(
          spacing: 8,
          children: [
            _buildDatePreset('Hoy', () {
              final today = DateTime.now();
              setState(() {
                _dateFrom = DateTime(today.year, today.month, today.day);
                _dateTo = DateTime(today.year, today.month, today.day, 23, 59, 59);
              });
            }),
            _buildDatePreset('Esta semana', () {
              final now = DateTime.now();
              final weekStart = now.subtract(Duration(days: now.weekday - 1));
              setState(() {
                _dateFrom = DateTime(weekStart.year, weekStart.month, weekStart.day);
                _dateTo = now;
              });
            }),
            _buildDatePreset('Este mes', () {
              final now = DateTime.now();
              setState(() {
                _dateFrom = DateTime(now.year, now.month, 1);
                _dateTo = now;
              });
            }),
            _buildDatePreset('Limpiar', () {
              setState(() {
                _dateFrom = null;
                _dateTo = null;
              });
            }),
          ],
        ),
        const SizedBox(height: 16),
        
        // Selección de rango personalizado
        Row(
          children: [
            Expanded(
              child: _buildDatePicker(
                label: 'Desde',
                date: _dateFrom,
                onDateSelected: (date) => setState(() => _dateFrom = date),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDatePicker(
                label: 'Hasta',
                date: _dateTo,
                onDateSelected: (date) => setState(() => _dateTo = date),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDatePreset(String label, VoidCallback onTap) {
    final isSelected = (label == 'Hoy' && _isToday()) ||
                      (label == 'Esta semana' && _isThisWeek()) ||
                      (label == 'Este mes' && _isThisMonth()) ||
                      (label == 'Limpiar' && _dateFrom == null && _dateTo == null);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? date,
    required ValueChanged<DateTime?> onDateSelected,
  }) {
    return GestureDetector(
      onTap: () async {
        final selectedDate = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: AppColors.primary,
                  brightness: Brightness.dark,
                ),
              ),
              child: child!,
            );
          },
        );
        onDateSelected(selectedDate);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    date != null 
                        ? '${date.day}/${date.month}/${date.year}'
                        : 'Seleccionar fecha',
                    style: TextStyle(
                      color: date != null ? AppColors.textPrimary : AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _isToday() {
    if (_dateFrom == null) return false;
    final today = DateTime.now();
    return _dateFrom!.year == today.year &&
           _dateFrom!.month == today.month &&
           _dateFrom!.day == today.day;
  }

  bool _isThisWeek() {
    if (_dateFrom == null) return false;
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return _dateFrom!.year == weekStart.year &&
           _dateFrom!.month == weekStart.month &&
           _dateFrom!.day == weekStart.day;
  }

  bool _isThisMonth() {
    if (_dateFrom == null) return false;
    final now = DateTime.now();
    return _dateFrom!.year == now.year &&
           _dateFrom!.month == now.month &&
           _dateFrom!.day == 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            _buildSliverAppBar(),
          ],
          body: _buildBody(),
        ),
      ),
      floatingActionButton: _buildQuickShareFAB(),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 280,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.textPrimary,
      actions: _isMultiSelectMode ? _buildMultiSelectActions() : _buildNormalActions(),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primaryLight,
                AppColors.secondary,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header con estadísticas
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.textPrimary.withValues(alpha: 0.2),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.share_rounded,
                          color: AppColors.textPrimary,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notas Compartidas',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Gestiona tu contenido colaborativo',
                              style: TextStyle(
                                color: AppColors.textPrimary.withValues(alpha: 0.8),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Estadísticas
                  if (_stats.isNotEmpty) _buildStatsCards(),
                ],
              ),
            ),
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(120),
        child: Container(
          color: AppColors.bg,
          child: Column(
            children: [
              // Barra de búsqueda
              _buildSearchBar(),
              
              // Tabs
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.primary.withValues(alpha: 0.1),
                  ),
                  indicatorPadding: const EdgeInsets.all(4),
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.send_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text('Enviadas (${_sharedByMe.length})'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.inbox_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text('Recibidas (${_sharedWithMe.length})'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildNormalActions() {
    return [
      // Botón de notificaciones con badge
      StreamBuilder<int>(
        stream: NotificationService().getUnreadCount(),
        builder: (context, snapshot) {
          final unreadCount = snapshot.data ?? 0;
          return Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_rounded),
                tooltip: 'Notificaciones',
                onPressed: _showNotificationsDialog,
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      IconButton(
        icon: const Icon(Icons.admin_panel_settings_rounded),
        tooltip: 'Plantillas de permisos',
        onPressed: _showPermissionTemplates,
      ),
      IconButton(
        icon: const Icon(Icons.history_rounded),
        tooltip: 'Historial de actividad',
        onPressed: _showActivityHistory,
      ),
      IconButton(
        icon: const Icon(Icons.checklist_rounded),
        tooltip: 'Selección múltiple',
        onPressed: _toggleMultiSelectMode,
      ),
      IconButton(
        icon: const Icon(Icons.tune_rounded),
        tooltip: 'Filtros',
        onPressed: _showFilterDialog,
      ),
      IconButton(
        icon: const Icon(Icons.refresh_rounded),
        tooltip: 'Actualizar',
        onPressed: _loadData,
      ),
    ];
  }

  List<Widget> _buildMultiSelectActions() {
    return [
      if (_selectedItems.isNotEmpty) ...[
        IconButton(
          icon: const Icon(Icons.select_all_rounded),
          tooltip: 'Seleccionar todo',
          onPressed: _selectAllItems,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          tooltip: 'Acciones masivas',
          onSelected: _performBulkAction,
          itemBuilder: (context) => [
            if (_tabController.index == 0) ...[
              const PopupMenuItem(
                value: 'revocar',
                child: ListTile(
                  leading: Icon(Icons.block_rounded, color: Colors.red),
                  title: Text('Revocar acceso'),
                  dense: true,
                ),
              ),
            ] else ...[
              const PopupMenuItem(
                value: 'aceptar',
                child: ListTile(
                  leading: Icon(Icons.check_rounded, color: Colors.green),
                  title: Text('Aceptar'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'rechazar',
                child: ListTile(
                  leading: Icon(Icons.close_rounded, color: Colors.red),
                  title: Text('Rechazar'),
                  dense: true,
                ),
              ),
            ],
          ],
        ),
      ],
      IconButton(
        icon: const Icon(Icons.close_rounded),
        tooltip: 'Cancelar selección',
        onPressed: _clearSelection,
      ),
    ];
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Pendientes',
            (_stats['sentPending'] ?? 0) + (_stats['receivedPending'] ?? 0),
            Icons.schedule_rounded,
            AppColors.warning,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Activas',
            (_stats['sentAccepted'] ?? 0) + (_stats['receivedAccepted'] ?? 0),
            Icons.check_circle_rounded,
            AppColors.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Total',
            _sharedByMe.length + _sharedWithMe.length,
            Icons.analytics_rounded,
            AppColors.info,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textPrimary.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Buscar notas o usuarios...',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                  // Debounce la búsqueda
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (_searchQuery == value) {
                      _loadData();
                    }
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: IconButton(
              onPressed: _showFilterDialog,
              icon: Icon(
                Icons.tune_rounded,
                color: (_selectedStatus != null || _selectedType != null || 
                       _userFilterQuery.isNotEmpty || _dateFrom != null || _dateTo != null)
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
              tooltip: 'Filtros',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Cargando comparticiones...',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildSharedByMeTab(),
        _buildSharedWithMeTab(),
      ],
    );
  }

  Widget _buildSharedByMeTab() {
    if (_sharedByMe.isEmpty) {
      return _buildEmptyState(
        icon: Icons.send_outlined,
        title: 'No has enviado comparticiones',
        subtitle: 'Comparte notas desde el menú contextual',
        action: null,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _sharedByMe.length,
        itemBuilder: (context, index) {
          final item = _sharedByMe[index];
          return _buildSharedItemCard(item, true);
        },
      ),
    );
  }

  Widget _buildSharedWithMeTab() {
    if (_sharedWithMe.isEmpty) {
      return _buildEmptyState(
        icon: Icons.inbox_outlined,
        title: 'No tienes comparticiones recibidas',
        subtitle: 'Cuando alguien comparta contigo aparecerá aquí',
        action: null,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _sharedWithMe.length,
        itemBuilder: (context, index) {
          final item = _sharedWithMe[index];
          return _buildSharedItemCard(item, false);
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Icon(
                icon,
                size: 48,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 24),
              action,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSharedItemCard(SharedItem item, bool isSentByMe) {
    final isSelected = _selectedItems.contains(item.id);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? AppColors.primary : AppColors.borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (_isMultiSelectMode) {
              _toggleItemSelection(item.id);
            } else {
              _openSharedItem(item);
            }
          },
          onLongPress: () {
            if (!_isMultiSelectMode) {
              _toggleMultiSelectMode();
            }
            _toggleItemSelection(item.id);
          },
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        _buildItemIcon(item),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.metadata?['noteTitle'] ?? 
                                item.metadata?['folderName'] ?? 
                                'Sin título',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    isSentByMe ? Icons.send_rounded : Icons.person_rounded,
                                    size: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      isSentByMe 
                                          ? 'Para: ${item.recipientEmail}'
                                          : 'De: ${item.ownerEmail}',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _buildStatusBadge(item.status),
                      ],
                    ),

                    // Información adicional
                    const SizedBox(height: 16),
                    _buildItemInfo(item),

                    // Mensaje si existe
                    if (item.message != null && item.message!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildMessageBox(item.message!),
                    ],

                    // Acciones
                    if (_shouldShowActions(item, isSentByMe)) ...[
                      const SizedBox(height: 16),
                      _buildActionButtons(item, isSentByMe),
                    ],
                  ],
                ),
              ),
              // Checkbox de selección en modo multi-selección
              if (_isMultiSelectMode)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.textSecondary.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (value) => _toggleItemSelection(item.id),
                      activeColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemIcon(SharedItem item) {
    Color statusColor = _getStatusColor(item.status);
    IconData icon = item.type == SharedItemType.note 
        ? Icons.note_alt_rounded 
        : Icons.folder_rounded;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Icon(
        icon,
        color: statusColor,
        size: 24,
      ),
    );
  }

  Widget _buildStatusBadge(SharingStatus status) {
    Color color = _getStatusColor(status);
    String text = _getStatusDisplayText(status);
    IconData icon = _getStatusIcon(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemInfo(SharedItem item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.security_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getPermissionText(item.permission),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(item.createdAt),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (item.type == SharedItemType.note)
            IconButton(
              onPressed: () => _copyShareLink(item),
              icon: Icon(
                Icons.link_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              tooltip: 'Copiar enlace',
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBox(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.info.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.message_rounded,
            size: 18,
            color: AppColors.info,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowActions(SharedItem item, bool isSentByMe) {
    if (isSentByMe) {
      return item.status == SharingStatus.pending || item.status == SharingStatus.accepted;
    } else {
      return item.status == SharingStatus.pending;
    }
  }

  Widget _buildActionButtons(SharedItem item, bool isSentByMe) {
    if (isSentByMe) {
      // Acciones para enviadas
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: () => _revokeSharing(item),
            icon: const Icon(Icons.block_rounded, size: 16),
            label: const Text('Revocar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: BorderSide(color: AppColors.danger),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      );
    } else {
      // Acciones para recibidas (solo pendientes)
      if (item.status == SharingStatus.pending) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: () => _rejectSharing(item),
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text('Rechazar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: BorderSide(color: AppColors.danger),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _acceptSharing(item),
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Aceptar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: AppColors.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        );
      }
    }
    return const SizedBox.shrink();
  }

  Color _getStatusColor(SharingStatus status) {
    switch (status) {
      case SharingStatus.pending:
        return AppColors.warning;
      case SharingStatus.accepted:
        return AppColors.success;
      case SharingStatus.rejected:
        return AppColors.danger;
      case SharingStatus.revoked:
        return AppColors.textSecondary;
    }
  }

  String _getStatusDisplayText(SharingStatus status) {
    switch (status) {
      case SharingStatus.pending:
        return 'Pendiente';
      case SharingStatus.accepted:
        return 'Aceptada';
      case SharingStatus.rejected:
        return 'Rechazada';
      case SharingStatus.revoked:
        return 'Revocada';
    }
  }

  IconData _getStatusIcon(SharingStatus status) {
    switch (status) {
      case SharingStatus.pending:
        return Icons.schedule_rounded;
      case SharingStatus.accepted:
        return Icons.check_circle_rounded;
      case SharingStatus.rejected:
        return Icons.cancel_rounded;
      case SharingStatus.revoked:
        return Icons.block_rounded;
    }
  }

  String _getPermissionText(PermissionLevel permission) {
    switch (permission) {
      case PermissionLevel.read:
        return 'Solo lectura';
      case PermissionLevel.comment:
        return 'Comentarios';
      case PermissionLevel.edit:
        return 'Edición';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Hoy';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} días';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _openSharedItem(SharedItem item) {
    if (item.type == SharedItemType.note) {
      // Verificar que tenemos los datos necesarios
      if (item.itemId.isEmpty) {
        ToastService.error('❌ ID de nota no válido');
        return;
      }
      
      try {
        // Navegar a la nota compartida
        Navigator.of(context).pushNamed(
          '/note',
          arguments: {
            'noteId': item.itemId,
            'ownerId': item.ownerId,
            'isShared': true,
            'permission': item.permission.name,
          },
        ).then((_) {
          // Refrescar la lista cuando se regrese
          _loadData();
        });
      } catch (e) {
        ToastService.error('❌ Error al abrir la nota: $e');
      }
    } else {
      // Para carpetas, mostrar contenido
      ToastService.info('📁 Abriendo carpeta: ${item.metadata?['folderName'] ?? 'Sin nombre'}');
    }
  }

  void _copyShareLink(SharedItem item) {
    // Generar enlace directo a la compartición
    final shareUrl = 'https://nootes.app/shared/${item.id}';
    Clipboard.setData(ClipboardData(text: shareUrl));
    ToastService.success('🔗 Enlace copiado al portapapeles');
  }

  /// Muestra el diálogo de notificaciones
  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SizedBox(
          width: 500,
          height: 600,
          child: Column(
            children: [
              // Header del diálogo
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Notificaciones',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    StreamBuilder<int>(
                      stream: NotificationService().getUnreadCount(),
                      builder: (context, snapshot) {
                        final unreadCount = snapshot.data ?? 0;
                        if (unreadCount > 0) {
                          return TextButton.icon(
                            onPressed: () async {
                              await NotificationService().markAllAsRead();
                            },
                            icon: const Icon(Icons.done_all_rounded, size: 18),
                            label: const Text('Marcar todas como leídas'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Cerrar',
                    ),
                  ],
                ),
              ),
              
              // Lista de notificaciones
              Expanded(
                child: const NotificationsList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Muestra el diálogo de plantillas de permisos
  void _showPermissionTemplates() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SizedBox(
          width: 500,
          height: 550,
          child: Column(
            children: [
              // Header del diálogo
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.admin_panel_settings_rounded,
                      color: AppColors.info,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Plantillas de Permisos',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Configura permisos predefinidos para compartir',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Cerrar',
                    ),
                  ],
                ),
              ),
              
              // Lista de plantillas
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Plantillas Disponibles',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Lista de plantillas
                      Expanded(
                        child: ListView(
                          children: PermissionTemplate.values.map((template) {
                            return _buildPermissionTemplateCard(template);
                          }).toList(),
                        ),
                      ),
                      
                      // Botón para crear nueva plantilla personalizada
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _showCreateCustomTemplate,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Crear Plantilla Personalizada'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: AppColors.borderColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Construye una tarjeta de plantilla de permisos
  Widget _buildPermissionTemplateCard(PermissionTemplate template) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.borderColor),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _applyPermissionTemplate(template),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Icono de la plantilla
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: template.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    template.icon,
                    color: template.color,
                    size: 24,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Información de la plantilla
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.name,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        template.description,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Botón de usar plantilla
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: template.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: template.color),
                  ),
                  child: Text(
                    'Usar',
                    style: TextStyle(
                      color: template.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Aplica una plantilla de permisos (simula la acción)
  void _applyPermissionTemplate(PermissionTemplate template) {
    Navigator.of(context).pop();
    ToastService.success(
      '✅ Plantilla "${template.name}" configurada\n'
      'Se usará para nuevas comparticiones'
    );
  }

  /// Muestra el diálogo para crear una plantilla personalizada
  void _showCreateCustomTemplate() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SizedBox(
          width: 450,
          height: 600,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.create_rounded,
                      color: AppColors.success,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Crear Plantilla Personalizada',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              
              // Formulario
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre de la plantilla
                      Text(
                        'Nombre de la Plantilla',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Ej: Editor de Marketing',
                          filled: true,
                          fillColor: AppColors.surfaceLight,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.borderColor),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Descripción
                      Text(
                        'Descripción',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Describe qué puede hacer con esta plantilla...',
                          filled: true,
                          fillColor: AppColors.surfaceLight,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.borderColor),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Nivel de permisos
                      Text(
                        'Nivel de Permisos',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Opciones de permisos
                      ...PermissionLevel.values.map((level) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Radio<PermissionLevel>(
                              value: level,
                              groupValue: PermissionLevel.edit, // Default
                              onChanged: (value) {
                                // Manejar cambio
                              },
                            ),
                            title: Text(
                              _getPermissionLevelName(level),
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              _getPermissionLevelDescription(level),
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                      
                      const Spacer(),
                      
                      // Botones
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                Navigator.of(context).pop();
                                ToastService.success('✅ Plantilla personalizada creada');
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: AppColors.success,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Crear'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getPermissionLevelName(PermissionLevel level) {
    switch (level) {
      case PermissionLevel.read:
        return 'Solo Lectura';
      case PermissionLevel.comment:
        return 'Comentarios';
      case PermissionLevel.edit:
        return 'Edición Completa';
    }
  }

  String _getPermissionLevelDescription(PermissionLevel level) {
    switch (level) {
      case PermissionLevel.read:
        return 'Puede ver el contenido pero no modificarlo';
      case PermissionLevel.comment:
        return 'Puede ver y agregar comentarios';
      case PermissionLevel.edit:
        return 'Puede ver, comentar y editar';
    }
  }
  void _showActivityHistory() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SizedBox(
          width: 600,
          height: 700,
          child: Column(
            children: [
              // Header del diálogo
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      color: AppColors.secondary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Historial de Actividad',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Cerrar',
                    ),
                  ],
                ),
              ),
              
              // Lista de actividades
              Expanded(
                child: _buildActivityList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Construye la lista de actividades
  Widget _buildActivityList() {
    return FutureBuilder<List<ActivityLogEntry>>(
      future: _getActivityHistory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 64,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error cargando actividad',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${snapshot.error}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final activities = snapshot.data ?? [];
        
        if (activities.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.timeline_rounded,
                  size: 64,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No hay actividad reciente',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Las actividades aparecerán aquí cuando haya\nacciones en tus notas compartidas',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: activities.length,
          itemBuilder: (context, index) {
            final activity = activities[index];
            return _buildActivityItem(activity, index == 0);
          },
        );
      },
    );
  }

  /// Construye un elemento de actividad
  Widget _buildActivityItem(ActivityLogEntry activity, bool isFirst) {
    return Container(
      margin: EdgeInsets.only(bottom: isFirst ? 16 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline visual
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: activity.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: activity.color,
                    width: 2,
                  ),
                ),
                child: Icon(
                  activity.icon,
                  color: activity.color,
                  size: 20,
                ),
              ),
              if (!isFirst)
                Container(
                  width: 2,
                  height: 20,
                  color: AppColors.borderColor,
                ),
            ],
          ),
          
          const SizedBox(width: 16),
          
          // Contenido de la actividad
          Expanded(
            child: Card(
              color: AppColors.surfaceLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.borderColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            activity.title,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          _formatActivityDate(activity.timestamp),
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      activity.description,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    if (activity.itemTitle.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: activity.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          activity.itemTitle,
                          style: TextStyle(
                            color: activity.color,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Obtiene el historial de actividad
  Future<List<ActivityLogEntry>> _getActivityHistory() async {
    // Simulamos datos de actividad - en una implementación real esto vendría de Firestore
    await Future.delayed(const Duration(milliseconds: 800));
    
    final now = DateTime.now();
    return [
      ActivityLogEntry(
        id: '1',
        type: ActivityType.shareAccepted,
        title: 'Compartición aceptada',
        description: 'usuario@ejemplo.com aceptó tu compartición',
        itemTitle: 'Mi Nota Importante',
        userEmail: 'usuario@ejemplo.com',
        timestamp: now.subtract(const Duration(hours: 2)),
      ),
      ActivityLogEntry(
        id: '2',
        type: ActivityType.shareCreated,
        title: 'Nueva compartición',
        description: 'Compartiste una nota con colaborador@empresa.com',
        itemTitle: 'Documentación del Proyecto',
        userEmail: 'colaborador@empresa.com',
        timestamp: now.subtract(const Duration(hours: 5)),
      ),
      ActivityLogEntry(
        id: '3',
        type: ActivityType.shareModified,
        title: 'Nota modificada',
        description: 'editor@equipo.com realizó cambios en una nota compartida',
        itemTitle: 'Plan de Marketing',
        userEmail: 'editor@equipo.com',
        timestamp: now.subtract(const Duration(days: 1)),
      ),
      ActivityLogEntry(
        id: '4',
        type: ActivityType.shareAccessed,
        title: 'Nota accedida',
        description: 'lector@cliente.com accedió a una nota compartida',
        itemTitle: 'Propuesta Comercial',
        userEmail: 'lector@cliente.com',
        timestamp: now.subtract(const Duration(days: 2)),
      ),
      ActivityLogEntry(
        id: '5',
        type: ActivityType.shareRevoked,
        title: 'Acceso revocado',
        description: 'Revocaste el acceso de antiguo@empleado.com',
        itemTitle: 'Datos Confidenciales',
        userEmail: 'antiguo@empleado.com',
        timestamp: now.subtract(const Duration(days: 3)),
      ),
    ];
  }

  String _formatActivityDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays}d';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _buildQuickShareFAB() {
    return FloatingActionButton.extended(
      onPressed: _showQuickShareDialog,
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textPrimary,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: Icon(Icons.share_rounded, size: 24),
      label: Text(
        'Compartir',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    );
  }

  Future<void> _showQuickShareDialog() async {
    final emailController = TextEditingController();
    String? selectedNoteId;
    String? selectedPermission = 'read';
    DateTime? expirationDate;
    String message = '';

    // Cargar notas disponibles usando FirestoreService
    final currentUid = 'current_user'; // TODO: Obtener del AuthService
    final notes = await FirestoreService.instance.listNotesSummary(uid: currentUid);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.share_rounded, color: AppColors.primary, size: 24),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Compartir Nota',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selector de nota
                  Text(
                    'Seleccionar Nota',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedNoteId,
                        isExpanded: true,
                        hint: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Text(
                            'Selecciona una nota...',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                        items: notes.map<DropdownMenuItem<String>>((note) => DropdownMenuItem<String>(
                          value: note['id'] as String,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  note['title']?.isNotEmpty == true ? note['title'] : 'Sin título',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (note['content']?.isNotEmpty == true) ...[
                                  SizedBox(height: 4),
                                  Text(
                                    note['content'],
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedNoteId = value;
                          });
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 20),

                  // Email del destinatario
                  Text(
                    'Email del Destinatario',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'usuario@ejemplo.com',
                      hintStyle: TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.primary),
                      ),
                      prefixIcon: Icon(Icons.email_outlined, color: AppColors.textSecondary),
                    ),
                  ),
                  SizedBox(height: 20),

                  // Nivel de permisos
                  Text(
                    'Permisos',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedPermission,
                        isExpanded: true,
                        items: [
                          DropdownMenuItem(
                            value: 'read',
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  Icon(Icons.visibility, color: AppColors.info, size: 20),
                                  SizedBox(width: 12),
                                  Text('Solo lectura', style: TextStyle(color: AppColors.textPrimary)),
                                ],
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'edit',
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  Icon(Icons.edit, color: AppColors.warning, size: 20),
                                  SizedBox(width: 12),
                                  Text('Editar', style: TextStyle(color: AppColors.textPrimary)),
                                ],
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'admin',
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  Icon(Icons.admin_panel_settings, color: AppColors.danger, size: 20),
                                  SizedBox(width: 12),
                                  Text('Administrador', style: TextStyle(color: AppColors.textPrimary)),
                                ],
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            selectedPermission = value;
                          });
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 20),

                  // Fecha de expiración
                  Text(
                    'Fecha de Expiración (Opcional)',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(Duration(days: 30)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(Duration(days: 365)),
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: ColorScheme.dark(
                                primary: AppColors.primary,
                                surface: AppColors.surface,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setDialogState(() {
                          expirationDate = picked;
                        });
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.bg,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: AppColors.textSecondary, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              expirationDate != null 
                                  ? '${expirationDate!.day}/${expirationDate!.month}/${expirationDate!.year}'
                                  : 'Sin fecha de expiración',
                              style: TextStyle(
                                color: expirationDate != null 
                                    ? AppColors.textPrimary 
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                          if (expirationDate != null)
                            IconButton(
                              onPressed: () {
                                setDialogState(() {
                                  expirationDate = null;
                                });
                              },
                              icon: Icon(Icons.clear, color: AppColors.textSecondary, size: 20),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),

                  // Mensaje opcional
                  Text(
                    'Mensaje (Opcional)',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    maxLines: 3,
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Añade un mensaje para el destinatario...',
                      hintStyle: TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.primary),
                      ),
                    ),
                    onChanged: (value) {
                      message = value;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancelar',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: selectedNoteId != null && emailController.text.isNotEmpty
                  ? () async {
                      try {
                        await _sharingService.shareNote(
                          noteId: selectedNoteId!,
                          recipientIdentifier: emailController.text.trim(),
                          permission: PermissionLevel.values.firstWhere(
                            (e) => e.name == selectedPermission,
                            orElse: () => PermissionLevel.read,
                          ),
                          message: message.isNotEmpty ? message : null,
                          expiresAt: expirationDate,
                        );
                        
                        Navigator.of(context).pop();
                        ToastService.success('✅ Nota compartida exitosamente');
                        await _loadData();
                      } catch (e) {
                        ToastService.error('❌ Error al compartir: $e');
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Compartir'),
            ),
          ],
        ),
      ),
    );
  }
}
