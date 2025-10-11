import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/sharing_service.dart';
import '../services/toast_service.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/share_dialog.dart';
import 'shared_note_viewer_page.dart';

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
  
  // Estado
  List<SharedItem> _sharedByMe = [];
  List<SharedItem> _sharedWithMe = [];
  final List<Map<String, dynamic>> _notifications = [];
  int _unreadNotifications = 0;
  bool _isLoading = false;
  
  // Streams para tiempo real
  Stream<QuerySnapshot>? _notificationsStream;
  String _searchQuery = '';
  SharingStatus? _selectedStatus;
  SharedItemType? _selectedType;
  String _userFilterQuery = '';
  DateTime? _dateFrom;
  DateTime? _dateTo;
  Map<String, int> _stats = {};
  // Agrupación en la pestaña "Recibidas"
  bool _groupByOwner = false;
  bool _groupByOwnerFolder = false;

  // Selección múltiple
  bool _isMultiSelectMode = false;
  final Set<String> _selectedItems = {};

  // Controladores
  final _searchController = TextEditingController();
  final _userFilterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // 3 tabs ahora
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
    
    _initializeStreams();
    _loadData();
    _animationController.forward();
  }
  
  void _initializeStreams() {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    
    // Stream de notificaciones en tiempo real
    _notificationsStream = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    _searchController.dispose();
    _userFilterController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    
    try {
  debugPrint('📊 SharedNotesPage: Iniciando carga de datos...');
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
      
  debugPrint('📊 SharedNotesPage: Cargadas ${sharedByMe.length} enviadas, ${sharedWithMe.length} recibidas');
      
      if (mounted) {
        setState(() {
          _sharedByMe = sharedByMe;
          _sharedWithMe = sharedWithMe;
          _stats = stats;
        });
      }
    } catch (e) {
  debugPrint('❌ SharedNotesPage: Error cargando datos - $e');
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
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Enviadas'),
                              if (_sharedByMe.isNotEmpty)
                                Text(
                                  '(${_sharedByMe.length})',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Icon(Icons.inbox_rounded, size: 18),
                              // Badge para invitaciones pendientes
                              if (_sharedWithMe.where((item) => item.status == SharingStatus.pending).isNotEmpty)
                                Positioned(
                                  right: -6,
                                  top: -6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.white, width: 1.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.2),
                                          blurRadius: 3,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 18,
                                      minHeight: 16,
                                    ),
                                    child: Text(
                                      '${_sharedWithMe.where((item) => item.status == SharingStatus.pending).length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Recibidas'),
                              if (_sharedWithMe.isNotEmpty)
                                Text(
                                  '(${_sharedWithMe.length})',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Icon(Icons.notifications_rounded, size: 18),
                              if (_unreadNotifications > 0)
                                Positioned(
                                  right: -4,
                                  top: -4,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    child: Text(
                                      _unreadNotifications > 9 ? '9+' : '$_unreadNotifications',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          Text('Notificaciones'),
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
      // Botón de marcar todas las notificaciones como leídas (solo en tab de notificaciones)
      if (_tabController.index == 2 && _unreadNotifications > 0)
        IconButton(
          icon: const Icon(Icons.done_all_rounded),
          tooltip: 'Marcar todas como leídas',
          onPressed: _markAllAsRead,
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
              const PopupMenuItem(
                value: 'salir',
                child: ListTile(
                  leading: Icon(Icons.logout_rounded, color: Colors.orange),
                  title: Text('Salir'),
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
        _buildNotificationsTab(),
      ],
    );
  }

  Widget _buildSharedByMeTab() {
    if (_sharedByMe.isEmpty) {
      return _buildEmptyState(
        icon: Icons.send_outlined,
        title: 'No has compartido notas aún',
        subtitle: 'Comparte una nota con otros usuarios desde el menú contextual (clic derecho) o desde el editor de notas',
        action: ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            ToastService.info('Ve a una nota y usa el menú contextual para compartir');
          },
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Ir a mis notas'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
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
        title: 'No tienes invitaciones',
        subtitle: 'Cuando alguien comparta una nota contigo, aparecerá aquí para que puedas aceptarla o rechazarla',
        action: null,
      );
    }

    // Separar invitaciones pendientes y aceptadas
    final pendingItems = _sharedWithMe.where((item) => item.status == SharingStatus.pending).toList();
    final acceptedItems = _sharedWithMe.where((item) => item.status == SharingStatus.accepted).toList();
    final otherItems = _sharedWithMe.where((item) => 
        item.status != SharingStatus.pending && item.status != SharingStatus.accepted).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Sección de invitaciones pendientes (prioritaria)
          if (pendingItems.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.notification_important_rounded, color: AppColors.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invitaciones Pendientes (${pendingItems.length})',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.warning,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Tienes invitaciones esperando tu respuesta',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...pendingItems.map((item) => _buildSharedItemCard(item, false)),
            if (acceptedItems.isNotEmpty || otherItems.isNotEmpty) ...[
              const Divider(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Notas Compartidas Activas',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ],
          
          // Controles de agrupación solo si hay elementos aceptados
          if (acceptedItems.isNotEmpty || otherItems.isNotEmpty) ...[
            _buildGroupingControls(),
            const SizedBox(height: 12),
          ],
          
          // Elementos aceptados y otros
          if (!_groupByOwner && !_groupByOwnerFolder) ...[
            ...acceptedItems.map((item) => _buildSharedItemCard(item, false)),
            ...otherItems.map((item) => _buildSharedItemCard(item, false)),
          ] else if (_groupByOwnerFolder) ...[
            ..._buildGroupedByOwnerSections([...acceptedItems, ...otherItems], byFolder: true),
          ] else ...[
            ..._buildGroupedByOwnerSections([...acceptedItems, ...otherItems]),
          ],
        ],
      ),
    );
  }

  /// Controles para agrupar la lista de "Recibidas"
  Widget _buildGroupingControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Icon(Icons.group_rounded, color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 8),
          Text('Agrupar', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const Spacer(),
          ChoiceChip(
            label: const Text('Todos'),
            selected: !_groupByOwner && !_groupByOwnerFolder,
            onSelected: (v) {
              if (v && (_groupByOwner || _groupByOwnerFolder)) {
                setState(() {
                  _groupByOwner = false;
                  _groupByOwnerFolder = false;
                });
              }
            },
            selectedColor: AppColors.primary.withValues(alpha: 0.15),
            labelStyle: TextStyle(color: (!_groupByOwner && !_groupByOwnerFolder) ? AppColors.primary : AppColors.textSecondary),
            shape: StadiumBorder(side: BorderSide(color: (!_groupByOwner && !_groupByOwnerFolder) ? AppColors.primary : AppColors.borderColor)),
            backgroundColor: AppColors.surfaceLight,
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Por propietario'),
            selected: _groupByOwner,
            onSelected: (v) {
              if (v) {
                setState(() {
                  _groupByOwner = true;
                  _groupByOwnerFolder = false;
                });
              }
            },
            selectedColor: AppColors.primary.withValues(alpha: 0.15),
            labelStyle: TextStyle(color: _groupByOwner ? AppColors.primary : AppColors.textSecondary),
            shape: StadiumBorder(side: BorderSide(color: _groupByOwner ? AppColors.primary : AppColors.borderColor)),
            backgroundColor: AppColors.surfaceLight,
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Propietario > Carpeta'),
            selected: _groupByOwnerFolder,
            onSelected: (v) {
              if (v) {
                setState(() {
                  _groupByOwner = false;
                  _groupByOwnerFolder = true;
                });
              }
            },
            selectedColor: AppColors.primary.withValues(alpha: 0.15),
            labelStyle: TextStyle(color: _groupByOwnerFolder ? AppColors.primary : AppColors.textSecondary),
            shape: StadiumBorder(side: BorderSide(color: _groupByOwnerFolder ? AppColors.primary : AppColors.borderColor)),
            backgroundColor: AppColors.surfaceLight,
          ),
        ],
      ),
    );
  }

  /// Crea secciones agrupadas por propietario
  List<Widget> _buildGroupedByOwnerSections(List<SharedItem> items, {bool byFolder = false}) {
    final Map<String, List<SharedItem>> byOwner = {};
    for (final it in items) {
      final key = it.ownerEmail.isNotEmpty ? it.ownerEmail : it.ownerId;
      byOwner.putIfAbsent(key, () => []).add(it);
    }

    final owners = byOwner.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final List<Widget> sections = [];

    for (final owner in owners) {
      final list = byOwner[owner]!;
      sections.add(_buildOwnerHeader(owner, list.length));
      sections.add(const SizedBox(height: 8));
      if (!byFolder) {
        sections.addAll(list.map((item) => _buildSharedItemCard(item, false)));
      } else {
        // Agrupar por carpeta del propietario (usamos metadata['folderName'] si existe)
        final Map<String, List<SharedItem>> byFolderMap = {};
        for (final it in list) {
          final folder = (it.metadata?['folderName'] as String?)?.trim();
          final key = (folder == null || folder.isEmpty) ? 'Sin carpeta' : folder;
          byFolderMap.putIfAbsent(key, () => []).add(it);
        }
        final folders = byFolderMap.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        for (final folder in folders) {
          final flist = byFolderMap[folder]!;
          sections.add(_buildFolderHeader(folder, flist.length));
          sections.add(const SizedBox(height: 6));
          sections.addAll(flist.map((item) => _buildSharedItemCard(item, false)));
          sections.add(const SizedBox(height: 12));
        }
      }
      sections.add(const SizedBox(height: 16));
    }

    return sections;
  }

  Widget _buildFolderHeader(String folder, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Icon(Icons.folder_rounded, color: AppColors.secondary, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              folder,
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Text('$count', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerHeader(String owner, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
            child: Text(
              owner.substring(0, 1).toUpperCase(),
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              owner,
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Text(
              '$count',
              style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== TAB DE NOTIFICACIONES ====================
  
  Widget _buildNotificationsTab() {
    if (_notificationsStream == null) {
      return _buildEmptyState(
        icon: Icons.notifications_off_rounded,
        title: 'Sin notificaciones',
        subtitle: 'Las notificaciones de compartición aparecerán aquí',
        action: null,
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _notificationsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _initializeStreams();
                    });
                  },
                  icon: Icon(Icons.refresh),
                  label: Text('Reintentar'),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Cargando notificaciones...'),
              ],
            ),
          );
        }

        final notifications = snapshot.data?.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            ...data,
          };
        }).toList() ?? [];

        // Actualizar contador de no leídas
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final unread = notifications.where((n) => n['isRead'] == false).length;
          if (_unreadNotifications != unread && mounted) {
            setState(() {
              _unreadNotifications = unread;
            });
          }
        });

        if (notifications.isEmpty) {
          return _buildEmptyState(
            icon: Icons.notifications_off_rounded,
            title: 'Sin notificaciones',
            subtitle: 'Las notificaciones de compartición aparecerán aquí',
            action: null,
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            // El stream se actualiza automáticamente, solo mostramos feedback
            await Future.delayed(Duration(milliseconds: 500));
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _buildNotificationCard(notification);
            },
          ),
        );
      },
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final isRead = notification['isRead'] == true;
    final type = notification['type'] as String? ?? 'shareInvite';
    final title = notification['title'] as String? ?? 'Notificación';
    final message = notification['message'] as String? ?? '';
    final createdAt = (notification['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final timeAgo = _getTimeAgo(createdAt);

    IconData icon;
    Color iconColor;

    switch (type) {
      case 'shareInvite':
        icon = Icons.share_rounded;
        iconColor = Colors.blue;
        break;
      case 'shareAccepted':
        icon = Icons.check_circle_rounded;
        iconColor = Colors.green;
        break;
      case 'shareRejected':
        icon = Icons.cancel_rounded;
        iconColor = Colors.red;
        break;
      case 'shareRevoked':
        icon = Icons.block_rounded;
        iconColor = Colors.orange;
        break;
      case 'permissionChanged':
        icon = Icons.edit_rounded;
        iconColor = Colors.purple;
        break;
      case 'noteUpdated':
        icon = Icons.update_rounded;
        iconColor = Colors.teal;
        break;
      case 'commentAdded':
        icon = Icons.comment_rounded;
        iconColor = Colors.indigo;
        break;
      default:
        icon = Icons.notifications_rounded;
        iconColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isRead 
            ? AppColors.surface 
            : AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead 
              ? AppColors.borderColor 
              : AppColors.primary.withValues(alpha: 0.3),
          width: isRead ? 1 : 2,
        ),
        boxShadow: isRead ? [] : [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _markNotificationAsRead(notification['id']),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ícono
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 16),
                // Contenido
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            timeAgo,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      
                      // Acciones rápidas para invitaciones
                      if (type == 'shareInvite' && !isRead)
                        _buildQuickActions(notification),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildQuickActions(Map<String, dynamic> notification) {
    final shareId = notification['metadata']?['shareId'] as String?;
    
    if (shareId == null) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Botón Rechazar
          TextButton.icon(
            onPressed: _isLoading 
                ? null 
                : () => _rejectFromNotification(shareId, notification['id']),
            icon: Icon(Icons.close, size: 18),
            label: Text('Rechazar'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
          const SizedBox(width: 8),
          // Botón Aceptar
          ElevatedButton.icon(
            onPressed: _isLoading 
                ? null 
                : () => _acceptFromNotification(shareId, notification['id']),
            icon: Icon(Icons.check, size: 18),
            label: Text('Aceptar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 2,
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _acceptFromNotification(String shareId, String notificationId) async {
    setState(() => _isLoading = true);
    
    try {
      final sharingService = SharingService();
      await sharingService.acceptSharing(shareId);
      await _markNotificationAsRead(notificationId);
      
      ToastService.success('✅ Compartición aceptada');
      
      // Recargar datos
      await _loadData();
    } catch (e) {
      debugPrint('❌ Error aceptando compartición: $e');
      ToastService.error('Error al aceptar: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _rejectFromNotification(String shareId, String notificationId) async {
    setState(() => _isLoading = true);
    
    try {
      final sharingService = SharingService();
      await sharingService.rejectSharing(shareId);
      await _markNotificationAsRead(notificationId);
      
      ToastService.info('❌ Compartición rechazada');
      
      // Recargar datos
      await _loadData();
    } catch (e) {
      debugPrint('❌ Error rechazando compartición: $e');
      ToastService.error('Error al rechazar: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      return 'Hace ${(difference.inDays / 365).floor()} año${(difference.inDays / 365).floor() > 1 ? 's' : ''}';
    } else if (difference.inDays > 30) {
      return 'Hace ${(difference.inDays / 30).floor()} mes${(difference.inDays / 30).floor() > 1 ? 'es' : ''}';
    } else if (difference.inDays > 0) {
      return 'Hace ${difference.inDays} día${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Hace ${difference.inHours} hora${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'Hace ${difference.inMinutes} minuto${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'Ahora mismo';
    }
  }

  Future<void> _markNotificationAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});

      // Actualizar localmente
      setState(() {
        final index = _notifications.indexWhere((n) => n['id'] == notificationId);
        if (index != -1) {
          _notifications[index]['isRead'] = true;
          _unreadNotifications = _notifications.where((n) => n['isRead'] == false).length;
        }
      });

      ToastService.success('Notificación marcada como leída');
    } catch (e) {
      debugPrint('Error marcando notificación: $e');
      ToastService.error('Error al marcar notificación');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return;

      // Obtener todas las notificaciones no leídas
      final unreadNotifications = _notifications.where((n) => n['isRead'] == false).toList();
      
      if (unreadNotifications.isEmpty) {
        ToastService.info('No hay notificaciones sin leer');
        return;
      }

      // Actualizar en Firestore en lote
      final batch = FirebaseFirestore.instance.batch();
      for (final notification in unreadNotifications) {
        final docRef = FirebaseFirestore.instance
            .collection('notifications')
            .doc(notification['id'] as String);
        batch.update(docRef, {'isRead': true});
      }
      await batch.commit();

      // Actualizar localmente
      setState(() {
        for (final notification in _notifications) {
          notification['isRead'] = true;
        }
        _unreadNotifications = 0;
      });

      ToastService.success('Todas las notificaciones marcadas como leídas');
    } catch (e) {
      debugPrint('Error marcando todas las notificaciones: $e');
      ToastService.error('Error al marcar todas las notificaciones');
    }
  }

  Widget _buildSharedItemCard(SharedItem item, bool isSentByMe) {
    final isSelected = _selectedItems.contains(item.id);
    final statusColor = _getStatusColor(item.status);
    final isPending = item.status == SharingStatus.pending && !isSentByMe;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: isPending ? 6 : 4,
        shadowColor: isPending 
            ? AppColors.warning.withValues(alpha: 0.2)
            : Colors.black.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected 
                ? AppColors.primary 
                : isPending 
                    ? AppColors.warning.withValues(alpha: 0.4)
                    : AppColors.borderColor,
            width: isSelected ? 2 : (isPending ? 2 : 1),
          ),
        ),
        color: isPending 
            ? AppColors.warning.withValues(alpha: 0.02)
            : AppColors.surface,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
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
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Indicador de invitación pendiente
                if (isPending) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.warning.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.priority_high_rounded,
                          size: 16,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Invitación pendiente - Requiere tu respuesta',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                
                // Header con selección y estado
                Row(
                  children: [
                    if (_isMultiSelectMode)
                      Container(
                        margin: const EdgeInsets.only(right: 16),
                        child: Transform.scale(
                          scale: 1.2,
                          child: Checkbox(
                            value: isSelected,
                            onChanged: (_) => _toggleItemSelection(item.id),
                            activeColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    
                    // Tipo de elemento
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: item.type == SharedItemType.note 
                            ? AppColors.info.withValues(alpha: 0.1)
                            : AppColors.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.type == SharedItemType.note 
                                ? Icons.description_rounded
                                : Icons.folder_rounded,
                            size: 16,
                            color: item.type == SharedItemType.note 
                                ? AppColors.info
                                : AppColors.secondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.type == SharedItemType.note ? 'Nota' : 'Carpeta',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: item.type == SharedItemType.note 
                                  ? AppColors.info
                                  : AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Estado
                    _buildStatusChip(item.status, statusColor),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Título y contenido
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          
                          if (item.metadata?['noteContent']?.isNotEmpty == true) ...[
                            const SizedBox(height: 8),
                            Text(
                              item.metadata!['noteContent']!,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Avatar del usuario
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                      child: Text(
                        (isSentByMe ? item.recipientEmail : item.ownerEmail)
                            .substring(0, 1)
                            .toUpperCase(),
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Información del usuario
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSentByMe ? Icons.send_rounded : Icons.person_rounded,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isSentByMe 
                              ? 'Para: ${item.recipientEmail}'
                              : 'De: ${item.ownerEmail}',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Información adicional
                _buildItemInfo(item),
                
                // Mensaje si existe
                if (item.message?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  _buildMessageBox(item.message!),
                ],
                
                // Botones de acción
                if (_shouldShowActions(item, isSentByMe)) ...[
                  const SizedBox(height: 16),
                  _buildActionButtons(item, isSentByMe),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(SharingStatus status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getStatusIcon(status), size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            _getStatusDisplayText(status),
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
                fontWeight: FontWeight.w700,
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

  // Placeholder methods - implement based on your services
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
      // Para receptores, mostrar acciones cuando esté pendiente (aceptar/rechazar)
      // o aceptada (permitir "Salir").
      return item.status == SharingStatus.pending || item.status == SharingStatus.accepted;
    }
  }

  Widget _buildActionButtons(SharedItem item, bool isSentByMe) {
    if (isSentByMe) {
      // El propietario puede revocar tanto si está pendiente como aceptada
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
    }

    // Receptor
    if (item.status == SharingStatus.pending) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.help_outline_rounded,
                  size: 16,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 8),
                Text(
                  '¿Qué quieres hacer con esta invitación?',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _rejectSharing(item),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Rechazar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: BorderSide(color: AppColors.danger, width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _acceptSharing(item),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Aceptar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (item.status == SharingStatus.accepted) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: () async {
              try {
                await SharingService().leaveSharing(item.id);
                ToastService.info('Has salido de la compartición');
                _loadData();
              } catch (e) {
                ToastService.error('No se pudo salir: $e');
              }
            },
            icon: const Icon(Icons.logout_rounded, size: 16),
            label: const Text('Salir'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: BorderSide(color: AppColors.borderColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      );
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
      case SharingStatus.left:
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
      case SharingStatus.left:
        return 'Abandonada';
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
      case SharingStatus.left:
        return Icons.logout_rounded;
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
      if (item.itemId.isEmpty) {
        ToastService.error('❌ ID de nota no válido');
        return;
      }
      
      try {
        // Navegar a SharedNoteViewerPage para ver/editar según permisos
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SharedNoteViewerPage(
              noteId: item.itemId,
              sharingInfo: item,
            ),
          ),
        ).then((_) {
          _loadData();
        });
      } catch (e) {
        ToastService.error('❌ Error al abrir la nota: $e');
      }
    } else {
      ToastService.info('📁 Abriendo carpeta: ${item.metadata?['folderName'] ?? 'Sin nombre'}');
    }
  }

  Future<void> _performBulkAction(String action) async {
    if (_selectedItems.isEmpty) return;

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
            case 'salir':
              await sharingService.leaveSharing(itemId);
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Revocar compartición',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          '¿Estás seguro de que quieres revocar el acceso a "${item.metadata?['noteTitle'] ?? item.metadata?['folderName'] ?? 'este elemento'}"?',
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
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.textPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Revocar'),
          ),
        ],
      ),
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

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        // Copias locales para edición sin aplicar inmediatamente
        SharingStatus? tempStatus = _selectedStatus;
        SharedItemType? tempType = _selectedType;
        DateTime? tempFrom = _dateFrom;
        DateTime? tempTo = _dateTo;
        final TextEditingController tempUserCtrl = TextEditingController(text: _userFilterQuery);

        Future<void> pickDate({required bool isFrom}) async {
          final now = DateTime.now();
          final initial = (isFrom ? tempFrom : tempTo) ?? now;
          final picked = await showDatePicker(
            context: context,
            initialDate: initial.isBefore(DateTime(2000)) ? now : initial,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
            helpText: isFrom ? 'Desde' : 'Hasta',
          );
          if (picked != null) {
            setState(() {
              if (isFrom) {
                tempFrom = DateTime(picked.year, picked.month, picked.day);
                if (tempTo != null && tempFrom!.isAfter(tempTo!)) {
                  tempTo = tempFrom;
                }
              } else {
                tempTo = DateTime(picked.year, picked.month, picked.day);
                if (tempFrom != null && tempTo!.isBefore(tempFrom!)) {
                  tempFrom = tempTo;
                }
              }
            });
          }
        }

        Widget chip<T>({required String label, required T? value, required T? groupValue, required void Function(T?) onSelected}) {
          final bool selected = value == groupValue;
          return Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) => onSelected(value),
              selectedColor: AppColors.primary.withValues(alpha: 0.15),
              labelStyle: TextStyle(color: selected ? AppColors.primary : AppColors.textSecondary),
              shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.primary : AppColors.borderColor)),
              backgroundColor: AppColors.surfaceLight,
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.tune_rounded, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Text('Filtros', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                tempStatus = null;
                                tempType = null;
                                tempUserCtrl.text = '';
                                tempFrom = null;
                                tempTo = null;
                              });
                            },
                            child: Text('Limpiar', style: TextStyle(color: AppColors.textSecondary)),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      Text('Estado', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      const SizedBox(height: 8),
                      Wrap(
                        children: [
                          chip<SharingStatus?>(label: 'Todos', value: null, groupValue: tempStatus, onSelected: (v) { setModalState(() { tempStatus = v; }); }),
                          chip<SharingStatus?>(label: 'Pendiente', value: SharingStatus.pending, groupValue: tempStatus, onSelected: (v) { setModalState(() { tempStatus = v; }); }),
                          chip<SharingStatus?>(label: 'Aceptada', value: SharingStatus.accepted, groupValue: tempStatus, onSelected: (v) { setModalState(() { tempStatus = v; }); }),
                          chip<SharingStatus?>(label: 'Rechazada', value: SharingStatus.rejected, groupValue: tempStatus, onSelected: (v) { setModalState(() { tempStatus = v; }); }),
                          chip<SharingStatus?>(label: 'Revocada', value: SharingStatus.revoked, groupValue: tempStatus, onSelected: (v) { setModalState(() { tempStatus = v; }); }),
                          chip<SharingStatus?>(label: 'Abandonada', value: SharingStatus.left, groupValue: tempStatus, onSelected: (v) { setModalState(() { tempStatus = v; }); }),
                        ],
                      ),

                      const SizedBox(height: 12),
                      Text('Tipo', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      const SizedBox(height: 8),
                      Wrap(
                        children: [
                          chip<SharedItemType?>(label: 'Todos', value: null, groupValue: tempType, onSelected: (v) { setModalState(() { tempType = v; }); }),
                          chip<SharedItemType?>(label: 'Notas', value: SharedItemType.note, groupValue: tempType, onSelected: (v) { setModalState(() { tempType = v; }); }),
                          chip<SharedItemType?>(label: 'Carpetas', value: SharedItemType.folder, groupValue: tempType, onSelected: (v) { setModalState(() { tempType = v; }); }),
                        ],
                      ),

                      const SizedBox(height: 12),
                      Text('Usuario', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: tempUserCtrl,
                        decoration: InputDecoration(
                          hintText: 'Correo del usuario',
                          filled: true,
                          fillColor: AppColors.surfaceLight,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.borderColor),
                          ),
                          prefixIcon: Icon(Icons.alternate_email_rounded, color: AppColors.textSecondary),
                        ),
                        onChanged: (_) => setModalState(() {}),
                      ),

                      const SizedBox(height: 12),
                      Text('Fecha', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async { await pickDate(isFrom: true); setModalState(() {}); },
                              icon: const Icon(Icons.calendar_today_rounded, size: 16),
                              label: Text(tempFrom != null ? _formatDate(tempFrom!) : 'Desde'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                side: BorderSide(color: AppColors.borderColor),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async { await pickDate(isFrom: false); setModalState(() {}); },
                              icon: const Icon(Icons.event_rounded, size: 16),
                              label: Text(tempTo != null ? _formatDate(tempTo!) : 'Hasta'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                side: BorderSide(color: AppColors.borderColor),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _selectedStatus = null;
                                  _selectedType = null;
                                  _userFilterQuery = '';
                                  _userFilterController.clear();
                                  _dateFrom = null;
                                  _dateTo = null;
                                });
                                Navigator.of(context).pop();
                                _loadData();
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                side: BorderSide(color: AppColors.borderColor),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Limpiar todo'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _selectedStatus = tempStatus;
                                  _selectedType = tempType;
                                  _userFilterQuery = tempUserCtrl.text.trim().toLowerCase();
                                  _userFilterController.text = _userFilterQuery;
                                  _dateFrom = tempFrom;
                                  _dateTo = tempTo;
                                });
                                Navigator.of(context).pop();
                                _loadData();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.textPrimary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Aplicar filtros'),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildQuickShareFAB() {
    return FloatingActionButton.extended(
      onPressed: _openQuickShare,
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textPrimary,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: const Icon(Icons.share_rounded, size: 24),
      label: const Text(
        'Compartir',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    );
  }

  Future<void> _openQuickShare() async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) {
        ToastService.error('Debes iniciar sesión para compartir');
        return;
      }

      // Load minimal lists for picker
      final notesFuture = FirestoreService.instance.listNotesSummary(uid: user.uid);
      final foldersFuture = FirestoreService.instance.listFolders(uid: user.uid);

      final results = await Future.wait([notesFuture, foldersFuture]);
  final notes = results[0];
  final folders = results[1];

      if (!mounted) return;

      String search = '';
      bool showNotes = true;

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              List<Map<String, dynamic>> filteredNotes = notes;
              List<Map<String, dynamic>> filteredFolders = folders;
              if (search.isNotEmpty) {
                final q = search.toLowerCase();
                filteredNotes = notes.where((n) => (n['title']?.toString() ?? '').toLowerCase().contains(q)).toList();
                filteredFolders = folders.where((f) => (f['name']?.toString() ?? '').toLowerCase().contains(q)).toList();
              }

              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Row(
                          children: [
                            Icon(Icons.bolt_rounded, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Text('Compartir rápido', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            const Spacer(),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.borderColor),
                              ),
                              child: Row(
                                children: [
                                  _segmentedButton(
                                    selected: showNotes,
                                    icon: Icons.description_rounded,
                                    label: 'Notas',
                                    onTap: () => setModalState(() => showNotes = true),
                                  ),
                                  _segmentedButton(
                                    selected: !showNotes,
                                    icon: Icons.folder_rounded,
                                    label: 'Carpetas',
                                    onTap: () => setModalState(() => showNotes = false),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Search
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Buscar por título...',
                            filled: true,
                            fillColor: AppColors.surfaceLight,
                            prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.borderColor),
                            ),
                          ),
                          onChanged: (v) => setModalState(() => search = v.trim()),
                        ),
                      ),

                      // List
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: showNotes ? filteredNotes.length : filteredFolders.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            if (showNotes) {
                              final n = filteredNotes[index];
                              final title = (n['title']?.toString() ?? '').trim().isEmpty ? 'Sin título' : n['title'].toString();
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.info.withValues(alpha: 0.15),
                                  child: Icon(Icons.description_rounded, color: AppColors.info),
                                ),
                                title: Text(title, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                                subtitle: (n['collectionName'] != null && (n['collectionName'].toString()).isNotEmpty)
                                    ? Text(n['collectionName'].toString(), style: TextStyle(color: AppColors.textSecondary))
                                    : null,
                                onTap: () async {
                                  Navigator.of(context).pop();
                                  await showDialog(
                                    context: this.context,
                                    builder: (_) => ShareDialog(
                                      itemId: n['id'].toString(),
                                      itemType: SharedItemType.note,
                                      itemTitle: title,
                                    ),
                                  );
                                  if (mounted) _loadData();
                                },
                              );
                            } else {
                              final f = filteredFolders[index];
                              final name = (f['name']?.toString() ?? '').trim().isEmpty ? 'Sin nombre' : f['name'].toString();
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.secondary.withValues(alpha: 0.15),
                                  child: Icon(Icons.folder_rounded, color: AppColors.secondary),
                                ),
                                title: Text(name, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                                onTap: () async {
                                  Navigator.of(context).pop();
                                  await showDialog(
                                    context: this.context,
                                    builder: (_) => ShareDialog(
                                      itemId: f['id'].toString(),
                                      itemType: SharedItemType.folder,
                                      itemTitle: name,
                                    ),
                                  );
                                  if (mounted) _loadData();
                                },
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      ToastService.error('No se pudo iniciar compartir: $e');
    }
  }

  Widget _segmentedButton({required bool selected, required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: selected ? AppColors.primary : AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}