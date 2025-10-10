import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../notes/workspace_page.dart';
import '../profile/settings_page.dart';
import '../theme/app_theme.dart';
import '../services/advanced_sharing_service.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/toast_service.dart';
import '../widgets/edit_event_dialog.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => AppShellState();

  static AppShellState? of(BuildContext context) {
    return context.findAncestorStateOfType<AppShellState>();
  }
}

class AppShellState extends State<AppShell> with AutomaticKeepAliveClientMixin {
  int _index = 0;
  late final PageController _pageController;

  final _pages = [
    const KeepAliveWrapper(child: NotesWorkspacePage()),
    const KeepAliveWrapper(child: SettingsPage()),
    const KeepAliveWrapper(child: _SearchPage()),
    const KeepAliveWrapper(child: _GraphPage()),
    const KeepAliveWrapper(child: _TasksPage()),
    const KeepAliveWrapper(child: _SharedPage()),
    const KeepAliveWrapper(child: _ExportPage()),
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onDestinationSelected(int index) {
    if (_index != index) {
      setState(() => _index = index);
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void navigateToSettings() {
    _onDestinationSelected(1);
  }

  void navigateToWorkspace() {
    _onDestinationSelected(0);
  }

  void navigateToSearch() {
    _onDestinationSelected(2);
  }

  void navigateToGraph() {
    _onDestinationSelected(3);
  }

  void navigateToTasks() {
    _onDestinationSelected(4);
  }

  void navigateToShared() {
    _onDestinationSelected(5);
  }

  void navigateToExport() {
    _onDestinationSelected(6);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isCompact = MediaQuery.of(context).size.width < 800;
    final destinations = const [
      NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Workspace'),
      NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Ajustes'),
      NavigationDestination(icon: Icon(Icons.search_outlined), selectedIcon: Icon(Icons.search), label: 'Búsqueda'),
      NavigationDestination(icon: Icon(Icons.psychology_outlined), selectedIcon: Icon(Icons.psychology), label: 'Mapa'),
      NavigationDestination(icon: Icon(Icons.task_alt_outlined), selectedIcon: Icon(Icons.task_alt), label: 'Tareas'),
      NavigationDestination(icon: Icon(Icons.people_alt_outlined), selectedIcon: Icon(Icons.people_alt), label: 'Compartidas'),
      NavigationDestination(icon: Icon(Icons.file_download_outlined), selectedIcon: Icon(Icons.file_download), label: 'Exportar'),
    ];

    if (isCompact) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0x1A4C6EF5), // primary 10%
                Color(0x1A2FD6C6), // secondary 10%
                Color(0x0DFF8A65), // accent 5%
              ],
            ),
          ),
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              if (_index != index) {
                setState(() => _index = index);
              }
            },
            children: _pages,
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          destinations: destinations,
          onDestinationSelected: _onDestinationSelected,
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: _onDestinationSelected,
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.only(top: AppColors.space16),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: AppColors.space8),
                padding: const EdgeInsets.all(AppColors.space8),
                decoration: BoxDecoration(
                  gradient: AppTheme.gradientPrimary,
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                ),
                child: const Icon(Icons.note_alt_rounded, color: Colors.white),
              ),
            ),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Workspace')),
              NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('Ajustes')),
              NavigationRailDestination(icon: Icon(Icons.search_rounded), selectedIcon: Icon(Icons.search), label: Text('Búsqueda')),
              NavigationRailDestination(icon: Icon(Icons.psychology_outlined), selectedIcon: Icon(Icons.psychology), label: Text('Mapa Mental')),
              NavigationRailDestination(icon: Icon(Icons.task_alt_outlined), selectedIcon: Icon(Icons.task_alt), label: Text('Tareas')),
              NavigationRailDestination(icon: Icon(Icons.people_alt_outlined), selectedIcon: Icon(Icons.people_alt), label: Text('Compartidas')),
              NavigationRailDestination(icon: Icon(Icons.file_download_outlined), selectedIcon: Icon(Icons.file_download), label: Text('Exportar')),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0x1A4C6EF5),
                    Color(0x1A2FD6C6),
                    Color(0x0DFF8A65),
                  ],
                ),
              ),
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  if (_index != index) {
                    setState(() => _index = index);
                  }
                },
                children: _pages,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class KeepAliveWrapper extends StatefulWidget {
  const KeepAliveWrapper({super.key, required this.child});
  
  final Widget child;

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

// Páginas temporales para las nuevas opciones del menú
class _SearchPage extends StatelessWidget {
  const _SearchPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Búsqueda Avanzada'),
        automaticallyImplyLeading: false,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_rounded, size: 64, color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Búsqueda Avanzada',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Filtros y estadísticas',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
            SizedBox(height: 24),
            Text(
              'Próximamente...',
              style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}

class _GraphPage extends StatelessWidget {
  const _GraphPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧠 Mapa Mental IA'),
        automaticallyImplyLeading: false,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.psychology_rounded, size: 64, color: Color(0xFF8B5CF6)),
            SizedBox(height: 16),
            Text(
              '🧠 Mapa Mental IA',
              style: TextStyle(
                fontSize: 24, 
                fontWeight: FontWeight.bold,
                color: Color(0xFF8B5CF6),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Grafo inteligente con conexiones IA',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
            SizedBox(height: 24),
            Text(
              'Próximamente...',
              style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}

class _TasksPage extends StatelessWidget {
  const _TasksPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Tareas'),
        automaticallyImplyLeading: false,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt_rounded, size: 64, color: Color(0xFF10B981)),
            SizedBox(height: 16),
            Text(
              'Mis Tareas',
              style: TextStyle(
                fontSize: 24, 
                fontWeight: FontWeight.bold,
                color: Color(0xFF10B981),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Ver todas las tareas',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
            SizedBox(height: 24),
            Text(
              'Próximamente...',
              style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}

class _SharedPage extends StatefulWidget {
  const _SharedPage();

  @override
  State<_SharedPage> createState() => _SharedPageState();
}

class _SharedPageState extends State<_SharedPage> with TickerProviderStateMixin {
  late TabController _tabController;
  List<SharedNote> _sharedWithMe = [];
  List<Map<String, dynamic>> _sharedByMe = [];
  List<SharedNote> _pendingInvites = [];
  List<ShareNotification> _notifications = [];
  List<NoteComment> _recentComments = [];
  List<ApprovalRequest> _pendingApprovals = [];
  List<CalendarEvent> _upcomingEvents = [];
  bool _loading = true;
  
  final AdvancedSharingService _sharingService = AdvancedSharingService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this); // 8 pestañas
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _loading = true);
    
    try {
      final results = await Future.wait([
        _sharingService.getSharedWithMe(),
        _sharingService.getSharedByMe(),
        _sharingService.getPendingInvites(),
        _sharingService.getNotifications(limit: 20),
        _sharingService.getPendingApprovals(),
        _sharingService.getCalendarEvents(
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 30)),
        ),
      ]);
      
      if (mounted) {
        setState(() {
          _sharedWithMe = results[0] as List<SharedNote>;
          _sharedByMe = results[1] as List<Map<String, dynamic>>;
          _pendingInvites = results[2] as List<SharedNote>;
          _notifications = results[3] as List<ShareNotification>;
          _pendingApprovals = results[4] as List<ApprovalRequest>;
          _upcomingEvents = results[5] as List<CalendarEvent>;
          _loading = false;
        });
        
        // Debug: Verificar datos cargados
        print('🔍 Compartidos contigo: ${_sharedWithMe.length}');
        print('🔍 Compartidos por mi: ${_sharedByMe.length}');
        if (_sharedByMe.isNotEmpty) {
          print('🔍 Primer elemento por mi: ${_sharedByMe.first}');
        }
        
        // Cargar comentarios recientes
        _loadRecentComments();
      }
    } catch (e) {
      print('Error loading shared data: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadRecentComments() async {
    try {
      final comments = await _sharingService.getRecentComments();
      if (mounted) {
        setState(() {
          _recentComments = comments;
        });
      }
    } catch (e) {
      print('Error loading recent comments: $e');
      if (mounted) {
        setState(() {
          _recentComments = [];
        });
      }
    }
  }

  Future<void> _loadSharedNotes() async {
    setState(() => _loading = true);
    
    try {
      // Recargar todos los datos de compartir
      await _loadAllData();
    } catch (e) {
      print('Error reloading shared notes: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notas Compartidas'),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(
              icon: const Icon(Icons.inbox_rounded),
              text: 'Conmigo (${_sharedWithMe.length})',
            ),
            Tab(
              icon: const Icon(Icons.send_rounded),
              text: 'Por mí (${_sharedByMe.length})',
            ),
            Tab(
              icon: const Icon(Icons.pending_actions_rounded),
              text: 'Invitaciones (${_pendingInvites.length})',
            ),
            Tab(
              icon: const Icon(Icons.notifications_rounded),
              text: 'Notif. (${_notifications.where((n) => !n.isRead).length})',
            ),
            Tab(
              icon: const Icon(Icons.comment_rounded),
              text: 'Coment. (${_recentComments.length})',
            ),
            Tab(
              icon: const Icon(Icons.check_circle_outline_rounded),
              text: 'Aprob. (${_pendingApprovals.length})',
            ),
            Tab(
              icon: const Icon(Icons.calendar_today_rounded),
              text: 'Calendario (${_upcomingEvents.length})',
            ),
            Tab(
              icon: const Icon(Icons.analytics_rounded),
              text: 'Analytics',
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSharedWithMeTab(),
                _buildSharedByMeTab(),
                _buildInvitationsTab(),
                _buildNotificationsTab(),
                _buildCommentsTab(),
                _buildApprovalsTab(),
                _buildCalendarTab(),
                _buildAnalyticsTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showShareDialog,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Compartir Nota'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _buildSharedWithMeTab() {
    if (_sharedWithMe.isEmpty) {
      return _buildEmptyState(
        icon: Icons.inbox_rounded,
        title: 'Sin notas compartidas',
        subtitle: 'Cuando alguien comparta una nota contigo, aparecerá aquí',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppColors.space16),
      itemCount: _sharedWithMe.length,
      itemBuilder: (context, index) {
        final note = _sharedWithMe[index];
        return _buildSharedNoteCard(note, isOwnedByMe: false);
      },
    );
  }

  Widget _buildSharedByMeTab() {
    print('🔍 Construyendo pestaña Por Mi con ${_sharedByMe.length} elementos');
    
    if (_sharedByMe.isEmpty) {
      return _buildEmptyState(
        icon: Icons.share_rounded,
        title: 'No has compartido notas',
        subtitle: 'Comparte tus notas para colaborar con otros',
        actionLabel: 'Compartir Nota',
        onAction: _showShareDialog,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppColors.space16),
      itemCount: _sharedByMe.length,
      itemBuilder: (context, index) {
        final note = _sharedByMe[index];
        print('🔍 Mostrando nota $index: ${note['title']}');
        return _buildSharedByMeCard(note);
      },
    );
  }

  Widget _buildInvitationsTab() {
    if (_pendingInvites.isEmpty) {
      return _buildEmptyState(
        icon: Icons.notifications_rounded,
        title: 'Sin invitaciones pendientes',
        subtitle: 'Las invitaciones para colaborar aparecerán aquí',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppColors.space16),
      itemCount: _pendingInvites.length,
      itemBuilder: (context, index) {
        final invite = _pendingInvites[index];
        return _buildInviteCard(invite);
      },
    );
  }

  Widget _buildNotificationsTab() {
    if (_notifications.isEmpty) {
      return _buildEmptyState(
        icon: Icons.notifications_off_rounded,
        title: 'Sin notificaciones',
        subtitle: 'Las notificaciones de colaboración aparecerán aquí',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppColors.space16),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        return Card(
          margin: const EdgeInsets.only(bottom: AppColors.space12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: notification.isRead 
                ? Colors.grey.shade300 
                : AppColors.primary,
              child: Icon(
                notification.type.name == 'commentAdded' 
                  ? Icons.comment_rounded
                  : notification.type.name == 'noteUpdated'
                    ? Icons.history_rounded
                    : Icons.notifications_rounded,
                color: notification.isRead 
                  ? AppColors.textSecondary 
                  : Colors.white,
              ),
            ),
            title: Text(
              notification.title,
              style: TextStyle(
                fontWeight: notification.isRead 
                  ? FontWeight.normal 
                  : FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.message,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                const SizedBox(height: 4),
                Text(
                  '${notification.createdAt.difference(DateTime.now()).inHours.abs()}h',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            trailing: notification.isRead 
              ? null 
              : Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            onTap: () => _markNotificationAsRead(notification.id),
          ),
        );
      },
    );
  }

  Widget _buildCommentsTab() {
    if (_recentComments.isEmpty) {
      return _buildEmptyState(
        icon: Icons.comment_outlined,
        title: 'Sin comentarios recientes',
        subtitle: 'Los comentarios en notas compartidas aparecerán aquí',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppColors.space16),
      itemCount: _recentComments.length,
      itemBuilder: (context, index) {
        final comment = _recentComments[index];
        return Card(
          margin: const EdgeInsets.only(bottom: AppColors.space12),
          child: Padding(
            padding: const EdgeInsets.all(AppColors.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      child: Text(comment.userName[0].toUpperCase()),
                    ),
                    const SizedBox(width: AppColors.space8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            comment.userName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${comment.createdAt.difference(DateTime.now()).inHours.abs()}h en nota',
                            style: Theme.of(context).textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (comment.isResolved)
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  ],
                ),
                const SizedBox(height: AppColors.space12),
                Text(
                  comment.content,
                  overflow: TextOverflow.visible,
                ),
                if (comment.mentions.isNotEmpty) ...[
                  const SizedBox(height: AppColors.space8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: comment.mentions.map((mention) => 
                      Chip(
                        label: Text(
                          '@$mention',
                          style: const TextStyle(fontSize: 12),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      )
                    ).toList(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildApprovalsTab() {
    if (_pendingApprovals.isEmpty) {
      return _buildEmptyState(
        icon: Icons.pending_actions_outlined,
        title: 'Sin aprobaciones pendientes',
        subtitle: 'Las solicitudes de aprobación aparecerán aquí',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppColors.space16),
      itemCount: _pendingApprovals.length,
      itemBuilder: (context, index) {
        final approval = _pendingApprovals[index];
        return Card(
          margin: const EdgeInsets.only(bottom: AppColors.space12),
          child: Padding(
            padding: const EdgeInsets.all(AppColors.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      approval.status == ApprovalStatus.pending
                        ? Icons.hourglass_empty_rounded
                        : approval.status == ApprovalStatus.approved
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: approval.status == ApprovalStatus.pending
                        ? Colors.orange
                        : approval.status == ApprovalStatus.approved
                          ? Colors.green
                          : Colors.red,
                    ),
                    const SizedBox(width: AppColors.space8),
                    Expanded(
                      child: Text(
                        approval.noteTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppColors.space8),
                Text(
                  approval.description,
                  overflow: TextOverflow.visible,
                ),
                const SizedBox(height: AppColors.space12),
                Text(
                  'Solicitado por: ${approval.requesterId}',
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Fecha límite: ${approval.deadline?.toString().split(' ')[0] ?? 'Sin fecha límite'}',
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
                if (approval.status == ApprovalStatus.pending) ...[
                  const SizedBox(height: AppColors.space16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: TextButton.icon(
                          onPressed: () => _respondToApproval(approval.id, false),
                          icon: const Icon(Icons.close, color: Colors.red, size: 16),
                          label: const Text('Rechazar', style: TextStyle(color: Colors.red)),
                        ),
                      ),
                      const SizedBox(width: AppColors.space4),
                      Flexible(
                        child: FilledButton.icon(
                          onPressed: () => _respondToApproval(approval.id, true),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Aprobar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalendarTab() {
    if (_upcomingEvents.isEmpty) {
      return _buildEmptyState(
        icon: Icons.calendar_today_outlined,
        title: 'Sin eventos próximos',
        subtitle: 'Los eventos y recordatorios aparecerán aquí',
        actionLabel: 'Crear evento',
        onAction: _showCreateEventDialog,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppColors.space16),
      itemCount: _upcomingEvents.length,
      itemBuilder: (context, index) {
        final event = _upcomingEvents[index];
        return Card(
          margin: const EdgeInsets.only(bottom: AppColors.space12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: event.type == CalendarEventType.deadline
                ? Colors.red
                : event.type == CalendarEventType.meeting
                  ? Colors.blue
                  : Colors.green,
              child: Icon(
                event.type == CalendarEventType.deadline
                  ? Icons.schedule_rounded
                  : event.type == CalendarEventType.meeting
                    ? Icons.video_call_rounded
                    : Icons.notifications_rounded,
                color: Colors.white,
              ),
            ),
            title: Text(
              event.title,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (event.description.isNotEmpty) 
                  Text(
                    event.description,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                const SizedBox(height: 4),
                Text(
                  '${event.startTime.toString().split(' ')[0]} a las ${event.startTime.toString().split(' ')[1].substring(0, 5)}',
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_rounded),
                      SizedBox(width: 8),
                      Text('Editar'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_rounded, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Eliminar', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  _editEvent(event);
                } else if (value == 'delete') {
                  _deleteEvent(event.id);
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppColors.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppColors.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resumen de Colaboración',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppColors.space16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildAnalyticsCard(
                          'Notas Compartidas',
                          '${_sharedWithMe.length + _sharedByMe.length}',
                          Icons.share_rounded,
                          AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppColors.space8),
                      Expanded(
                        child: _buildAnalyticsCard(
                          'Comentarios',
                          '${_recentComments.length}',
                          Icons.comment_rounded,
                          Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppColors.space8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildAnalyticsCard(
                          'Aprobaciones',
                          '${_pendingApprovals.length}',
                          Icons.check_circle_rounded,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: AppColors.space8),
                      Expanded(
                        child: _buildAnalyticsCard(
                          'Eventos',
                          '${_upcomingEvents.length}',
                          Icons.calendar_today_rounded,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppColors.space16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppColors.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Actividad Reciente',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppColors.space16),
                  const Text('• Análisis detallado de colaboración próximamente'),
                  const Text('• Métricas de productividad en desarrollo'),
                  const Text('• Reportes personalizados disponibles pronto'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppColors.space16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: AppColors.space8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppColors.space24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: AppColors.space24),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppColors.space8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppColors.space24),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.share_rounded),
              label: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSharedNoteCard(SharedNote note, {required bool isOwnedByMe}) {
    final permission = note.permission;
    final isOnline = note.isOwnerOnline;
    
    return Card(
      margin: const EdgeInsets.only(bottom: AppColors.space12),
      child: InkWell(
        onTap: () => _openNote(note.noteId, note.title),
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppColors.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        const SizedBox(height: AppColors.space4),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: AppColors.primary,
                              child: Text(
                                note.ownerName[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppColors.space8),
                            Expanded(
                              child: Text(
                                'Por ${note.ownerName}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isOnline) ...[
                              const SizedBox(width: 2),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'Online',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildPermissionBadge(permission),
                ],
              ),
              const SizedBox(height: AppColors.space12),
              Row(
                children: [
                  Icon(
                    Icons.group_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppColors.space4),
                  Text(
                    '${note.collaboratorCount} colaboradores',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatTime(note.lastModified),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSharedByMeCard(Map<String, dynamic> note) {
    final collaborators = (note['collaborators'] as List?) ?? [];
    final title = note['title'] as String? ?? 'Sin título';
    final id = note['id'] as String? ?? '';
    final views = note['views'] as int? ?? 0;
    final lastModified = note['lastModified'] as DateTime?;
    
    return Card(
      margin: const EdgeInsets.only(bottom: AppColors.space12),
      child: InkWell(
        onTap: () => _openNote(id, title),
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppColors.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (value) => _handleNoteAction(value, note),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'manage',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.settings_rounded),
                          title: Text('Gestionar permisos'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'invite',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.person_add_rounded),
                          title: Text('Invitar colaboradores'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'copy_link',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.link_rounded),
                          title: Text('Copiar enlace'),
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'stop_sharing',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.stop_circle_rounded, color: AppColors.danger),
                          title: Text('Dejar de compartir', style: TextStyle(color: AppColors.danger)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppColors.space12),
              Row(
                children: [
                  Flexible(
                    flex: 2,
                    child: SizedBox(
                      width: 100,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: List.generate(
                          collaborators.length > 3 ? 3 : collaborators.length,
                          (index) => Positioned(
                            left: index * 18.0,
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: AppColors.primary,
                              child: Text(
                                collaborators[index]['name'][0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        )..addAll(
                          collaborators.length > 3 
                            ? [
                                Positioned(
                                  left: 54,
                                  child: CircleAvatar(
                                    radius: 12,
                                    backgroundColor: AppColors.textSecondary,
                                    child: Text(
                                      '+${collaborators.length - 3}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ]
                            : [],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppColors.space8),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${collaborators.length} colaboradores',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '$views visualizaciones',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    flex: 1,
                    child: Text(
                      lastModified != null ? _formatTime(lastModified) : 'Sin fecha',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInviteCard(SharedNote invite) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppColors.space12),
      child: Padding(
        padding: const EdgeInsets.all(AppColors.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppColors.space8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                  child: const Icon(
                    Icons.mail_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppColors.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invite.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      const SizedBox(height: AppColors.space4),
                      Text(
                        'Invitado por ${invite.ownerName}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _buildPermissionBadge(invite.permission),
              ],
            ),
            if (invite.message != null) ...[
              const SizedBox(height: AppColors.space12),
              Container(
                padding: const EdgeInsets.all(AppColors.space12),
                decoration: BoxDecoration(
                  color: AppColors.bgLight,
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  border: Border.all(color: AppColors.borderColorLight),
                ),
                child: Text(
                  invite.message!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppColors.space16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatTime(invite.sharedAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () => _declineInvite(invite),
                  child: const Text('Rechazar'),
                ),
                const SizedBox(width: AppColors.space4),
                FilledButton(
                  onPressed: () => _acceptInvite(invite),
                  child: const Text('Aceptar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionBadge(SharePermission permission) {
    Color color;
    String label;
    IconData icon;

    switch (permission) {
      case SharePermission.edit:
        color = AppColors.success;
        label = 'Editor';
        icon = Icons.edit_rounded;
        break;
      case SharePermission.comment:
        color = AppColors.accent;
        label = 'Comentar';
        icon = Icons.comment_rounded;
        break;
      case SharePermission.view:
        color = AppColors.info;
        label = 'Solo ver';
        icon = Icons.visibility_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppColors.space8,
        vertical: AppColors.space4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppColors.space4),
          Text(
            label,
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

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Ahora';
    } else if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays}d';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  void _openNote(String noteId, String title) {
    // Implementar navegación a la nota usando el AppShell
    final appShell = AppShell.of(context);
    if (appShell != null) {
      appShell.navigateToWorkspace();
      // Aquí podrías pasar el noteId como parámetro si tienes esa funcionalidad
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Abriendo nota: $title'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleNoteAction(String action, Map<String, dynamic> note) {
    switch (action) {
      case 'manage':
        _showManagePermissionsDialog(note);
        break;
      case 'invite':
        _showInviteDialog(note);
        break;
      case 'copy_link':
        _copyShareLink(note);
        break;
      case 'stop_sharing':
        _stopSharing(note);
        break;
    }
  }

  void _showShareDialog() {
    showDialog(
      context: context,
      builder: (context) => _ShareNoteDialog(
        onShare: (noteId, title, email, permission, message) async {
          final success = await _sharingService.shareNote(
            noteId: noteId,
            noteTitle: title,
            sharedWithEmail: email,
            permission: permission,
            message: message,
          );
          
          if (success) {
            _loadSharedNotes();
          }
        },
      ),
    );
  }

  void _showManagePermissionsDialog(Map<String, dynamic> note) {
    showDialog(
      context: context,
      builder: (context) => _ManagePermissionsDialog(
        noteId: note['id'],
        noteTitle: note['title'],
        collaborators: List<Map<String, dynamic>>.from(note['collaborators']),
        onUpdatePermission: (collaboratorEmail, newPermission) async {
          // Buscar el shareId basado en el email del colaborador
          // Esto requeriría una función adicional en el servicio
          ToastService.info('Funcionalidad de actualizar permisos en desarrollo');
        },
        onRemoveCollaborator: (collaboratorEmail) async {
          // Similar al anterior
          ToastService.info('Funcionalidad de remover colaborador en desarrollo');
        },
      ),
    );
  }

  void _showInviteDialog(Map<String, dynamic> note) {
    showDialog(
      context: context,
      builder: (context) => _InviteCollaboratorDialog(
        noteId: note['id'],
        noteTitle: note['title'],
        onInvite: (email, permission, message) async {
          final success = await _sharingService.shareNote(
            noteId: note['id'],
            noteTitle: note['title'],
            sharedWithEmail: email,
            permission: permission,
            message: message,
          );
          
          if (success) {
            _loadSharedNotes();
          }
        },
      ),
    );
  }

  void _copyShareLink(Map<String, dynamic> note) {
    _sharingService.copyShareLink(note['id']);
  }

  void _stopSharing(Map<String, dynamic> note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dejar de compartir'),
        content: Text('¿Estás seguro de que quieres dejar de compartir "${note['title']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await _sharingService.stopSharing(note['id']);
              if (success) {
                _loadSharedNotes();
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Dejar de compartir'),
          ),
        ],
      ),
    );
  }

  void _acceptInvite(SharedNote invite) async {
    final success = await _sharingService.acceptInvite(invite.id);
    if (success) {
      _loadSharedNotes();
    }
  }

  void _declineInvite(SharedNote invite) async {
    final success = await _sharingService.declineInvite(invite.id);
    if (success) {
      _loadSharedNotes();
    }
  }

  // Métodos auxiliares para las nuevas funcionalidades

  Future<void> _markNotificationAsRead(String notificationId) async {
    try {
      // Actualizar estado local
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          // Crear nueva notificación con isRead: true
          final notification = _notifications[index];
          _notifications[index] = ShareNotification(
            id: notification.id,
            userId: notification.userId,
            noteId: notification.noteId,
            folderId: notification.folderId,
            type: notification.type,
            title: notification.title,
            message: notification.message,
            data: notification.data,
            isRead: true,
            createdAt: notification.createdAt,
            actionUrl: notification.actionUrl,
            fromUserId: notification.fromUserId,
            fromUserName: notification.fromUserName,
          );
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al marcar notificación como leída')),
      );
    }
  }

  Future<void> _respondToApproval(String approvalId, bool approved) async {
    try {
      setState(() {
        _pendingApprovals.removeWhere((approval) => approval.id == approvalId);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approved ? 'Aprobación otorgada' : 'Solicitud rechazada'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al responder')),
      );
    }
  }

  void _showCreateEventDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crear Evento'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Funcionalidad de calendario en desarrollo'),
            SizedBox(height: 16),
            Text('Próximamente podrás crear eventos y recordatorios para tus colaboraciones.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _editEvent(CalendarEvent event) {
    _showEditEventDialog(event);
  }

  void _showEditEventDialog(CalendarEvent event) {
    showDialog(
      context: context,
      builder: (context) => EditEventDialog(
        event: event,
        onSave: (updatedEvent) async {
          final success = await _sharingService.updateCalendarEvent(
            eventId: updatedEvent.id,
            title: updatedEvent.title,
            description: updatedEvent.description,
            type: updatedEvent.type,
            startTime: updatedEvent.startTime,
            endTime: updatedEvent.endTime,
            attendeeIds: updatedEvent.attendeeIds,
            location: updatedEvent.location,
            isAllDay: updatedEvent.isAllDay,
            reminders: updatedEvent.reminders,
          );
          
          if (success) {
            // Actualizar la lista local
            setState(() {
              final index = _upcomingEvents.indexWhere((e) => e.id == event.id);
              if (index != -1) {
                _upcomingEvents[index] = updatedEvent;
              }
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Evento actualizado exitosamente')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error al actualizar el evento')),
            );
          }
        },
      ),
    );
  }

  Future<void> _deleteEvent(String eventId) async {
    try {
      final success = await _sharingService.deleteCalendarEvent(eventId);
      
      if (success) {
        setState(() {
          _upcomingEvents.removeWhere((event) => event.id == eventId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evento eliminado exitosamente')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al eliminar evento')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al eliminar evento')),
      );
    }
  }
}

// Diálogo avanzado para compartir notas
class _ShareNoteDialog extends StatefulWidget {
  final Function(String noteId, String title, String email, SharePermission permission, String? message) onShare;

  const _ShareNoteDialog({required this.onShare});

  @override
  State<_ShareNoteDialog> createState() => _ShareNoteDialogState();
}

class _ShareNoteDialogState extends State<_ShareNoteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  SharePermission _selectedPermission = SharePermission.view;
  List<Map<String, dynamic>> _userNotes = [];
  String? _selectedNoteId;
  bool _loading = false;

  // Variables para autocompletado
  List<Map<String, dynamic>> _suggestions = [];
  bool _showSuggestions = false;
  String? _errorMessage;
  Map<String, dynamic>? _foundUser;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadUserNotes();
  }

  Future<void> _loadUserNotes() async {
    try {
      final uid = AuthService.instance.currentUser?.uid ?? '';
      final notes = await FirestoreService.instance.listNotesSummary(uid: uid);
      setState(() {
        _userNotes = notes;
      });
    } catch (e) {
      print('Error loading notes: $e');
    }
  }

  Future<void> _searchSuggestions(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
        _errorMessage = null;
        _foundUser = null;
      });
      return;
    }

    if (query.length < 2) {
      setState(() {
        _showSuggestions = false;
        _suggestions = [];
        _errorMessage = null;
        _foundUser = null;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final suggestions = <Map<String, dynamic>>[];

      // 1) Email exact or prefix (if user types full email)
      if (query.contains('@') && !query.startsWith('@')) {
        // Simular búsqueda por email exacto
        if (RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(query)) {
          suggestions.add({
            'uid': 'user_${query.hashCode}',
            'email': query,
            'fullName': query.split('@')[0],
            'username': query.split('@')[0],
          });
        }
      }

      // 2) Username/handle prefix using handles collection
      final clean = query.startsWith('@') ? query.substring(1) : query;
      if (clean.isNotEmpty) {
        try {
          final handles = await FirestoreService.instance.listHandles(limit: 50);
          final matched = handles
              .where((h) => (h['username']?.toString() ?? '').toLowerCase().startsWith(clean.toLowerCase()))
              .take(5)
              .toList();
          for (final h in matched) {
            final uid = h['uid']?.toString();
            if (uid == null) continue;
            final p = await FirestoreService.instance.getUserProfile(uid: uid);
            if (p != null) {
              suggestions.add({
                'uid': uid,
                'email': p['email'],
                'fullName': p['fullName'],
                'username': p['username'],
              });
            }
          }
        } catch (_) {
          // Si no hay handles disponibles, crear sugerencias simuladas
          suggestions.addAll([
            {
              'uid': 'user_${clean.hashCode}_1',
              'email': '$clean@ejemplo.com',
              'fullName': clean.substring(0, 1).toUpperCase() + clean.substring(1),
              'username': clean,
            },
            {
              'uid': 'user_${clean.hashCode}_2',
              'email': '$clean@gmail.com',
              'fullName': '${clean.substring(0, 1).toUpperCase()}${clean.substring(1)} Usuario',
              'username': '${clean}_user',
            },
          ]);
        }
      }

      // 3) Fallback: list few recent profiles and filter by name prefix
      if (suggestions.isEmpty && !query.contains('@')) {
        try {
          final profiles = await FirestoreService.instance.listUserProfiles(limit: 50);
          final matched = profiles
              .where((u) => ((u['fullName'] ?? u['username'] ?? u['email'] ?? '')
                      .toString()
                      .toLowerCase())
                  .startsWith(query.toLowerCase()))
              .take(5)
              .map((u) => {
                    'uid': u['id'],
                    'email': u['email'],
                    'fullName': u['fullName'],
                    'username': u['username'],
                  })
              .toList();
          suggestions.addAll(matched);
        } catch (_) {}
      }

      // Deduplicate by uid
      final seen = <String>{};
      final deduped = <Map<String, dynamic>>[];
      for (final s in suggestions) {
        final uid = s['uid']?.toString();
        if (uid == null) continue;
        if (seen.add(uid)) deduped.add(s);
      }

      setState(() {
        _suggestions = deduped;
        _showSuggestions = deduped.isNotEmpty;
        _errorMessage = deduped.isEmpty ? 'No se encontraron usuarios que coincidan' : null;
        _foundUser = null;
      });
    } catch (e) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
        _errorMessage = 'Error al buscar: ${e.toString()}';
        _foundUser = null;
      });
    } finally {
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Compartir Nota'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Selector de nota
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Seleccionar nota',
                  border: OutlineInputBorder(),
                ),
                initialValue: _selectedNoteId,
                items: _userNotes.map((note) {
                  return DropdownMenuItem(
                    value: note['id'].toString(),
                    child: Text(
                      note['title'] ?? 'Sin título',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedNoteId = value);
                },
                validator: (value) => value == null ? 'Selecciona una nota' : null,
              ),
              const SizedBox(height: 16),
              
              // Email del colaborador con autocompletado
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _foundUser != null 
                            ? Colors.green
                            : _errorMessage != null
                                ? Colors.red
                                : Colors.grey.shade400,
                        width: _foundUser != null || _errorMessage != null ? 2 : 1,
                      ),
                    ),
                    child: TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email del colaborador',
                        hintText: 'usuario@ejemplo.com o @usuario',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        prefixIcon: Icon(
                          _foundUser != null 
                              ? Icons.check_circle_rounded
                              : _errorMessage != null
                                  ? Icons.error_outline_rounded
                                  : Icons.search_rounded,
                          color: _foundUser != null 
                              ? Colors.green
                              : _errorMessage != null
                                  ? Colors.red
                                  : AppColors.primary,
                        ),
                        suffixIcon: _isSearching
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : _emailController.text.isNotEmpty
                                ? IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _emailController.clear();
                                        _foundUser = null;
                                        _showSuggestions = false;
                                        _suggestions = [];
                                        _errorMessage = null;
                                      });
                                    },
                                    icon: const Icon(Icons.clear_rounded),
                                  )
                                : null,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingresa un email o nombre de usuario';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        if (_foundUser != null) {
                          setState(() => _foundUser = null);
                        }
                        if (_errorMessage != null) {
                          setState(() => _errorMessage = null);
                        }
                        _searchSuggestions(value);
                      },
                    ),
                  ),
                  
                  // Mostrar sugerencias
                  if (_showSuggestions) ...[
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _suggestions.length,
                        itemBuilder: (context, index) {
                          final suggestion = _suggestions[index];
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              child: Icon(Icons.person, color: AppColors.primary, size: 18),
                            ),
                            title: Text(
                              suggestion['fullName'] ?? suggestion['username'] ?? 'Usuario',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            subtitle: Text(
                              suggestion['email'] ?? '',
                              style: const TextStyle(fontSize: 12),
                            ),
                            onTap: () {
                              setState(() {
                                _emailController.text = suggestion['email'] ?? suggestion['username'] ?? '';
                                _foundUser = suggestion;
                                _showSuggestions = false;
                                _suggestions = [];
                                _errorMessage = null;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                  
                  // Mostrar error
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Colors.red, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  // Mostrar usuario encontrado
                  if (_foundUser != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.green,
                            radius: 16,
                            child: const Icon(Icons.person, color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _foundUser!['fullName'] ?? _foundUser!['username'] ?? 'Usuario',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  _foundUser!['email'] ?? '',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.check_circle, color: Colors.green, size: 20),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              
              // Permisos
              DropdownButtonFormField<SharePermission>(
                decoration: const InputDecoration(
                  labelText: 'Permisos',
                  border: OutlineInputBorder(),
                ),
                initialValue: _selectedPermission,
                items: SharePermission.values.map((permission) {
                  String label;
                  IconData icon;
                  Color color;
                  
                  switch (permission) {
                    case SharePermission.view:
                      label = 'Solo ver';
                      icon = Icons.visibility_rounded;
                      color = AppColors.info;
                      break;
                    case SharePermission.comment:
                      label = 'Comentar';
                      icon = Icons.comment_rounded;
                      color = AppColors.accent;
                      break;
                    case SharePermission.edit:
                      label = 'Editar';
                      icon = Icons.edit_rounded;
                      color = AppColors.success;
                      break;
                  }
                  
                  return DropdownMenuItem(
                    value: permission,
                    child: Row(
                      children: [
                        Icon(icon, color: color, size: 20),
                        const SizedBox(width: 8),
                        Text(label),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedPermission = value!);
                },
              ),
              const SizedBox(height: 16),
              
              // Mensaje opcional
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Mensaje (opcional)',
                  hintText: 'Invitación para colaborar en...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.message_rounded),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _loading ? null : _shareNote,
          child: _loading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Compartir'),
        ),
      ],
    );
  }

  Future<void> _shareNote() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _loading = true);
    
    try {
      final selectedNote = _userNotes.firstWhere((note) => note['id'].toString() == _selectedNoteId);
      
      await widget.onShare(
        _selectedNoteId!,
        selectedNote['title'] ?? 'Sin título',
        _emailController.text.trim(),
        _selectedPermission,
        _messageController.text.trim().isEmpty ? null : _messageController.text.trim(),
      );
      
      Navigator.pop(context);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }
}

// Diálogo para gestionar permisos
class _ManagePermissionsDialog extends StatefulWidget {
  final String noteId;
  final String noteTitle;
  final List<Map<String, dynamic>> collaborators;
  final Function(String email, SharePermission permission) onUpdatePermission;
  final Function(String email) onRemoveCollaborator;

  const _ManagePermissionsDialog({
    required this.noteId,
    required this.noteTitle,
    required this.collaborators,
    required this.onUpdatePermission,
    required this.onRemoveCollaborator,
  });

  @override
  State<_ManagePermissionsDialog> createState() => _ManagePermissionsDialogState();
}

class _ManagePermissionsDialogState extends State<_ManagePermissionsDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Gestionar Permisos'),
          const SizedBox(height: 4),
          Text(
            widget.noteTitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 400,
        child: widget.collaborators.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 48, color: AppColors.textSecondary),
                    SizedBox(height: 16),
                    Text('No hay colaboradores'),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: widget.collaborators.length,
                itemBuilder: (context, index) {
                  final collaborator = widget.collaborators[index];
                  return _buildCollaboratorTile(collaborator);
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            // Abrir diálogo de invitar
          },
          child: const Text('Invitar más'),
        ),
      ],
    );
  }

  Widget _buildCollaboratorTile(Map<String, dynamic> collaborator) {
    final permission = SharePermission.values.firstWhere(
      (p) => p.name == collaborator['permission'],
      orElse: () => SharePermission.view,
    );
    
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary,
          child: Text(
            collaborator['name'][0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(collaborator['name']),
        subtitle: Text(collaborator['email']),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<SharePermission>(
              value: permission,
              underline: const SizedBox(),
              items: SharePermission.values.map((p) {
                String label;
                switch (p) {
                  case SharePermission.view:
                    label = 'Ver';
                    break;
                  case SharePermission.comment:
                    label = 'Comentar';
                    break;
                  case SharePermission.edit:
                    label = 'Editar';
                    break;
                }
                return DropdownMenuItem(
                  value: p,
                  child: Text(label),
                );
              }).toList(),
              onChanged: (newPermission) {
                if (newPermission != null) {
                  widget.onUpdatePermission(collaborator['email'], newPermission);
                }
              },
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger),
              onPressed: () => _confirmRemoveCollaborator(collaborator),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemoveCollaborator(Map<String, dynamic> collaborator) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover colaborador'),
        content: Text('¿Estás seguro de que quieres remover a ${collaborator['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onRemoveCollaborator(collaborator['email']);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }
}

// Diálogo para invitar colaboradores
class _InviteCollaboratorDialog extends StatefulWidget {
  final String noteId;
  final String noteTitle;
  final Function(String email, SharePermission permission, String? message) onInvite;

  const _InviteCollaboratorDialog({
    required this.noteId,
    required this.noteTitle,
    required this.onInvite,
  });

  @override
  State<_InviteCollaboratorDialog> createState() => _InviteCollaboratorDialogState();
}

class _InviteCollaboratorDialogState extends State<_InviteCollaboratorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  SharePermission _selectedPermission = SharePermission.view;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Invitar Colaborador'),
          const SizedBox(height: 4),
          Text(
            widget.noteTitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email del colaborador',
                  hintText: 'usuario@ejemplo.com',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_rounded),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa un email';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Ingresa un email válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<SharePermission>(
                decoration: const InputDecoration(
                  labelText: 'Permisos',
                  border: OutlineInputBorder(),
                ),
                initialValue: _selectedPermission,
                items: SharePermission.values.map((permission) {
                  String label;
                  IconData icon;
                  Color color;
                  
                  switch (permission) {
                    case SharePermission.view:
                      label = 'Solo ver';
                      icon = Icons.visibility_rounded;
                      color = AppColors.info;
                      break;
                    case SharePermission.comment:
                      label = 'Comentar';
                      icon = Icons.comment_rounded;
                      color = AppColors.accent;
                      break;
                    case SharePermission.edit:
                      label = 'Editar';
                      icon = Icons.edit_rounded;
                      color = AppColors.success;
                      break;
                  }
                  
                  return DropdownMenuItem(
                    value: permission,
                    child: Row(
                      children: [
                        Icon(icon, color: color, size: 20),
                        const SizedBox(width: 8),
                        Text(label),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedPermission = value!);
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Mensaje (opcional)',
                  hintText: 'Invitación para colaborar en...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.message_rounded),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _loading ? null : _inviteCollaborator,
          child: _loading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Enviar invitación'),
        ),
      ],
    );
  }

  Future<void> _inviteCollaborator() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _loading = true);
    
    try {
      await widget.onInvite(
        _emailController.text.trim(),
        _selectedPermission,
        _messageController.text.trim().isEmpty ? null : _messageController.text.trim(),
      );
      
      Navigator.pop(context);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }
}

class _ExportPage extends StatelessWidget {
  const _ExportPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exportar'),
        automaticallyImplyLeading: false,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.file_download_rounded, size: 64, color: Color(0xFF3B82F6)),
            SizedBox(height: 16),
            Text(
              'Exportar',
              style: TextStyle(
                fontSize: 24, 
                fontWeight: FontWeight.bold,
                color: Color(0xFF3B82F6),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Guardar tus notas',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
            SizedBox(height: 24),
            Text(
              'Próximamente...',
              style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}

// === DIÁLOGO PARA USAR PLANTILLAS ===

class _UseTemplateDialog extends StatefulWidget {
  final ShareTemplate template;
  final Function(String noteId, String noteTitle, String email, String? message) onUse;

  const _UseTemplateDialog({
    required this.template,
    required this.onUse,
  });

  @override
  State<_UseTemplateDialog> createState() => _UseTemplateDialogState();
}

class _UseTemplateDialogState extends State<_UseTemplateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  
  List<Map<String, dynamic>> _userNotes = [];
  String? _selectedNoteId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadUserNotes();
    _messageController.text = 'Te invito a colaborar usando la plantilla "${widget.template.name}". ${widget.template.description}';
  }

  Future<void> _loadUserNotes() async {
    try {
      final uid = AuthService.instance.currentUser!.uid;
      final notes = await FirestoreService.instance.listNotesSummary(uid: uid);
      setState(() {
        _userNotes = notes;
        if (notes.isNotEmpty) {
          _selectedNoteId = notes.first['id'].toString();
        }
      });
    } catch (e) {
      print('Error loading notes: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.description_rounded,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Usar plantilla: ${widget.template.name}'),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Descripción de la plantilla
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plantilla: ${widget.template.name}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(widget.template.description),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.security_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Permisos: ${_getPermissionLabel(widget.template.defaultPermission)}',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (widget.template.expirationDuration != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 16,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Expira en: ${_formatDuration(widget.template.expirationDuration!)}',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Seleccionar nota
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Seleccionar nota',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note_rounded),
                ),
                initialValue: _selectedNoteId,
                validator: (value) => value == null ? 'Selecciona una nota' : null,
                items: _userNotes.map((note) {
                  return DropdownMenuItem(
                    value: note['id'].toString(),
                    child: Text(
                      note['title'] ?? 'Sin título',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedNoteId = value);
                },
              ),
              const SizedBox(height: 16),
              
              // Email del colaborador
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email del colaborador',
                  hintText: 'colaborador@ejemplo.com',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa un email';
                  }
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value.trim())) {
                    return 'Ingresa un email válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Mensaje personalizado
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Mensaje de invitación',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.message_rounded),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _loading ? null : _useTemplate,
          child: _loading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Compartir con plantilla'),
        ),
      ],
    );
  }

  Future<void> _useTemplate() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _loading = true);
    
    try {
      final selectedNote = _userNotes.firstWhere((note) => note['id'].toString() == _selectedNoteId);
      
      await widget.onUse(
        _selectedNoteId!,
        selectedNote['title'] ?? 'Sin título',
        _emailController.text.trim(),
        _messageController.text.trim().isEmpty ? null : _messageController.text.trim(),
      );
      
      Navigator.pop(context);
    } finally {
      setState(() => _loading = false);
    }
  }

  String _getPermissionLabel(SharePermission permission) {
    switch (permission) {
      case SharePermission.view:
        return 'Solo ver';
      case SharePermission.comment:
        return 'Comentar';
      case SharePermission.edit:
        return 'Editar';
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} días';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} horas';
    } else {
      return '${duration.inMinutes} minutos';
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }
}
