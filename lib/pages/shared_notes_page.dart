import 'package:flutter/material.dart';
import '../services/sharing_service.dart';
import '../services/toast_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glass.dart';

/// Página para gestionar notas compartidas
class SharedNotesPage extends StatefulWidget {
  const SharedNotesPage({super.key});

  @override
  State<SharedNotesPage> createState() => _SharedNotesPageState();
}

class _SharedNotesPageState extends State<SharedNotesPage> with TickerProviderStateMixin {
  late TabController _tabController;
  late Future<void> _initFuture;
  
  List<SharedItem> _sharedByMe = [];
  List<SharedItem> _sharedWithMe = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initFuture = _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final sharingService = SharingService();
      final results = await Future.wait([
        sharingService.getSharedByMe(),
        sharingService.getSharedWithMe(),
      ]);
      
      setState(() {
        _sharedByMe = results[0];
        _sharedWithMe = results[1];
      });
    } catch (e) {
      ToastService.error('Error cargando datos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptSharing(SharedItem item) async {
    try {
      await SharingService().acceptSharing(item.id);
      ToastService.success('Compartición aceptada');
      await _loadData();
    } catch (e) {
      ToastService.error('Error: $e');
    }
  }

  Future<void> _rejectSharing(SharedItem item) async {
    try {
      await SharingService().rejectSharing(item.id);
      ToastService.success('Compartición rechazada');
      await _loadData();
    } catch (e) {
      ToastService.error('Error: $e');
    }
  }

  Future<void> _revokeSharing(SharedItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revocar compartición'),
        content: Text(
          '¿Estás seguro de que quieres revocar el acceso a "${item.metadata?['noteTitle'] ?? item.metadata?['folderName'] ?? 'este elemento'}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Revocar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SharingService().revokeSharing(item.id);
        ToastService.success('Compartición revocada');
        await _loadData();
      } catch (e) {
        ToastService.error('Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notas Compartidas'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.share),
                  const SizedBox(width: 8),
                  Text('Compartidas por mí (${_sharedByMe.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.inbox),
                  const SizedBox(width: 8),
                  Text('Compartidas conmigo (${_sharedWithMe.length})'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: GlassBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : FutureBuilder(
                future: _initFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSharedByMeTab(),
                      _buildSharedWithMeTab(),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildSharedByMeTab() {
    if (_sharedByMe.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.share_outlined,
              size: 64,
              color: Color(0xFF636E72),
            ),
            SizedBox(height: 16),
            Text(
              'No has compartido nada aún',
              style: TextStyle(
                fontSize: 18,
                color: Color(0xFF636E72),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Comparte notas o carpetas desde el menú contextual',
              style: TextStyle(
                color: Color(0xFF636E72),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sharedByMe.length,
        itemBuilder: (context, index) {
          final item = _sharedByMe[index];
          return _buildSharedByMeCard(item);
        },
      ),
    );
  }

  Widget _buildSharedWithMeTab() {
    if (_sharedWithMe.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Color(0xFF636E72),
            ),
            SizedBox(height: 16),
            Text(
              'No tienes notas compartidas',
              style: TextStyle(
                fontSize: 18,
                color: Color(0xFF636E72),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Cuando alguien comparta contenido contigo aparecerá aquí',
              style: TextStyle(
                color: Color(0xFF636E72),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sharedWithMe.length,
        itemBuilder: (context, index) {
          final item = _sharedWithMe[index];
          return _buildSharedWithMeCard(item);
        },
      ),
    );
  }

  Widget _buildSharedByMeCard(SharedItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con tipo e información
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getStatusColor(item.status).withValues(alpha: 0.2),
                  radius: 20,
                  child: Icon(
                    item.type == SharedItemType.note ? Icons.note_alt : Icons.folder,
                    color: _getStatusColor(item.status),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.metadata?['noteTitle'] ?? item.metadata?['folderName'] ?? 'Sin título',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.recipientEmail,
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(item.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getStatusColor(item.status).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _getStatusText(item.status),
                    style: TextStyle(
                      color: _getStatusColor(item.status),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Información adicional
            Row(
              children: [
                Icon(
                  _getPermissionIcon(item.permission),
                  size: 16,
                  color: const Color(0xFF636E72),
                ),
                const SizedBox(width: 4),
                Text(
                  _getPermissionText(item.permission),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF636E72),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(item.createdAt),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF636E72),
                  ),
                ),
              ],
            ),
            
            // Mensaje si existe
            if (item.message != null && item.message!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE9ECEF)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.message,
                      size: 16,
                      color: Color(0xFF636E72),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.message!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF2D3436),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Acciones
            if (item.status != SharingStatus.revoked) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _revokeSharing(item),
                    icon: const Icon(Icons.cancel, size: 16),
                    label: const Text('Revocar'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSharedWithMeCard(SharedItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con tipo e información
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getStatusColor(item.status).withValues(alpha: 0.2),
                  radius: 20,
                  child: Icon(
                    item.type == SharedItemType.note ? Icons.note_alt : Icons.folder,
                    color: _getStatusColor(item.status),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.metadata?['noteTitle'] ?? item.metadata?['folderName'] ?? 'Sin título',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 14,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'De: ${item.metadata?['ownerName'] ?? item.ownerEmail}',
                              style: TextStyle(
                                color: AppColors.secondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(item.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getStatusColor(item.status).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _getStatusText(item.status),
                    style: TextStyle(
                      color: _getStatusColor(item.status),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Información adicional
            Row(
              children: [
                Icon(
                  _getPermissionIcon(item.permission),
                  size: 16,
                  color: const Color(0xFF636E72),
                ),
                const SizedBox(width: 4),
                Text(
                  _getPermissionText(item.permission),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF636E72),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(item.createdAt),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF636E72),
                  ),
                ),
              ],
            ),
            
            // Mensaje si existe
            if (item.message != null && item.message!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE9ECEF)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.message,
                      size: 16,
                      color: Color(0xFF636E72),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.message!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF2D3436),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Acciones para comparticiones pendientes
            if (item.status == SharingStatus.pending) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _rejectSharing(item),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Rechazar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _acceptSharing(item),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Aceptar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(SharingStatus status) {
    switch (status) {
      case SharingStatus.pending:
        return AppColors.warning;
      case SharingStatus.accepted:
        return AppColors.success;
      case SharingStatus.rejected:
        return AppColors.error;
      case SharingStatus.revoked:
        return const Color(0xFF636E72);
    }
  }

  String _getStatusText(SharingStatus status) {
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

  IconData _getPermissionIcon(PermissionLevel permission) {
    switch (permission) {
      case PermissionLevel.read:
        return Icons.visibility;
      case PermissionLevel.comment:
        return Icons.comment;
      case PermissionLevel.edit:
        return Icons.edit;
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

    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return 'Hace ${difference.inDays} día${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Hace ${difference.inHours} hora${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'Hace ${difference.inMinutes} minuto${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'Hace un momento';
    }
  }
}