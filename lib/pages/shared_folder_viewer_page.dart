import 'package:flutter/material.dart';
import '../services/sharing_service.dart';
import '../services/toast_service.dart';
import '../services/firestore_service.dart';
import '../widgets/share_dialog.dart';
import '../theme/app_theme.dart';

/// Vista simple para gestionar una carpeta compartida
class SharedFolderViewerPage extends StatefulWidget {
  final SharedItem folderShare;
  const SharedFolderViewerPage({super.key, required this.folderShare});

  @override
  State<SharedFolderViewerPage> createState() => _SharedFolderViewerPageState();
}

class _SharedFolderViewerPageState extends State<SharedFolderViewerPage> {
  bool _loadingMembers = true;
  List<SharedItem> _members = [];
  bool get _isOwner =>
      widget.folderShare.ownerId == SharingService().currentUserId;
  bool _loadingNotes = true;
  List<Map<String, dynamic>> _notes = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _loadNotes();
  }

  Future<void> _loadMembers() async {
    setState(() => _loadingMembers = true);
    try {
      if (_isOwner) {
        _members = await SharingService().getFolderMembers(
          folderId: widget.folderShare.itemId,
        );
      } else {
        // Como receptor, solo mostramos tu propia entrada
        _members = [widget.folderShare];
      }
    } catch (e) {
      ToastService.error('No se pudieron cargar miembros: $e');
    } finally {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  Future<void> _loadNotes() async {
    setState(() => _loadingNotes = true);
    try {
      final notes = await FirestoreService.instance.listNotes(
        uid: widget.folderShare.ownerId,
      );
      final folderId = widget.folderShare.itemId;
      _notes = notes
          .where((n) => (n['folderId']?.toString() ?? '') == folderId)
          .toList();
    } catch (e) {
      ToastService.error('No se pudieron cargar notas: $e');
    } finally {
      if (mounted) setState(() => _loadingNotes = false);
    }
  }

  Future<void> _changePermission(SharedItem item) async {
    if (!_isOwner) return;
    final selected = await showModalBottomSheet<PermissionLevel>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        Widget tile(PermissionLevel level, String label, IconData icon) =>
            ListTile(
              leading: Icon(icon),
              title: Text(label),
              trailing: item.permission == level
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () => Navigator.pop(context, level),
            );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                height: 4,
                width: 44,
                decoration: BoxDecoration(
                  color: AppColors.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              const ListTile(
                title: Text(
                  'Permisos de la carpeta',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              tile(
                PermissionLevel.read,
                'Solo lectura',
                Icons.visibility_rounded,
              ),
              tile(
                PermissionLevel.comment,
                'Comentarios',
                Icons.mode_comment_rounded,
              ),
              tile(PermissionLevel.edit, 'Edición', Icons.edit_rounded),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );

    if (selected != null && selected != item.permission) {
      try {
        await SharingService().updateSharingPermission(item.id, selected);
        ToastService.success('Permisos actualizados');
        await _loadMembers();
      } catch (e) {
        ToastService.error('No se pudo actualizar: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final folderName = widget.folderShare.metadata?['folderName'] ?? 'Carpeta';
    return Scaffold(
      appBar: AppBar(
        title: Text('Carpeta: $folderName'),
        actions: [
          if (_isOwner)
            IconButton(
              tooltip: 'Invitar a alguien',
              icon: const Icon(Icons.person_add_alt_1_rounded),
              onPressed: () async {
                await showDialog(
                  context: context,
                  builder: (_) => ShareDialog(
                    itemId: widget.folderShare.itemId,
                    itemType: SharedItemType.folder,
                    itemTitle: folderName,
                  ),
                );
                _loadMembers();
              },
            ),
        ],
      ),
      body: _loadingMembers
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.folder_shared_rounded),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            folderName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (_isOwner)
                          FilledButton.icon(
                            onPressed: () =>
                                _changePermission(widget.folderShare),
                            icon: const Icon(Icons.lock_open_rounded, size: 18),
                            label: const Text('Permisos'),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text(
                    _isOwner ? 'Miembros con acceso' : 'Tu acceso',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _members.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final m = _members[i];
                        final isSelf =
                            m.recipientId == SharingService().currentUserId;
                        return ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person_rounded),
                          ),
                          title: Text(
                            _isOwner ? m.recipientEmail : m.ownerEmail,
                          ),
                          subtitle: Text(_permissionLabel(m.permission)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isOwner)
                                IconButton(
                                  tooltip: 'Cambiar permisos',
                                  onPressed: () => _changePermission(m),
                                  icon: const Icon(Icons.lock_open_rounded),
                                ),
                              if (_isOwner) ...[
                                IconButton(
                                  tooltip: 'Revocar',
                                  onPressed: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        backgroundColor: AppColors.surface,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        title: const Text('Revocar acceso'),
                                        content: Text(
                                          '¿Revocar el acceso de ${m.recipientEmail}?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(
                                              context,
                                            ).pop(false),
                                            child: const Text('Cancelar'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: AppColors.danger,
                                            ),
                                            child: const Text('Revocar'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      try {
                                        await SharingService().revokeSharing(
                                          m.id,
                                        );
                                        ToastService.success('Acceso revocado');
                                        await _loadMembers();
                                      } catch (e) {
                                        ToastService.error(
                                          'No se pudo revocar: $e',
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.block_rounded,
                                    color: AppColors.danger,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Revocar y eliminar',
                                  onPressed: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        backgroundColor: AppColors.surface,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        title: const Text('Revocar y eliminar'),
                                        content: Text(
                                          'Esto revocará el acceso y eliminará la entrada. ¿Continuar con ${m.recipientEmail}?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(
                                              context,
                                            ).pop(false),
                                            child: const Text('Cancelar'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: AppColors.danger,
                                            ),
                                            child: const Text(
                                              'Revocar y eliminar',
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      try {
                                        await SharingService()
                                            .safeDeleteSharing(m.id);
                                        ToastService.success(
                                          'Acceso revocado y entrada eliminada',
                                        );
                                        await _loadMembers();
                                      } catch (e) {
                                        ToastService.error(
                                          'No se pudo completar: $e',
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.delete_forever_rounded,
                                    color: AppColors.danger,
                                  ),
                                ),
                              ],
                              if (!_isOwner && isSelf)
                                IconButton(
                                  tooltip: 'Salir',
                                  onPressed: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        backgroundColor: AppColors.surface,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        title: const Text('Salir y eliminar'),
                                        content: const Text(
                                          'Esto te sacará de la carpeta y eliminará la entrada de tu lista. ¿Continuar?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(
                                              context,
                                            ).pop(false),
                                            child: const Text('Cancelar'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.warning,
                                            ),
                                            child: const Text(
                                              'Salir y eliminar',
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      try {
                                        await SharingService().leaveAndDelete(
                                          m.id,
                                        );
                                        if (!context.mounted) return;
                                        Navigator.pop(context);
                                        ToastService.success(
                                          'Has salido y eliminado la entrada',
                                        );
                                      } catch (e) {
                                        ToastService.error(
                                          'No se pudo completar: $e',
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.logout_rounded),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'Notas en esta carpeta',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  _loadingNotes
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : _notes.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('No hay notas en esta carpeta'),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _notes.length,
                          itemBuilder: (_, i) {
                            final n = _notes[i];
                            return ListTile(
                              leading: const Icon(Icons.description_rounded),
                              title: Text(
                                n['title']?.toString() ?? 'Sin título',
                              ),
                              subtitle: Text(
                                (n['updatedAt']?.toString() ?? ''),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
    );
  }

  String _permissionLabel(PermissionLevel permission) {
    switch (permission) {
      case PermissionLevel.read:
        return 'Solo lectura';
      case PermissionLevel.comment:
        return 'Comentarios';
      case PermissionLevel.edit:
        return 'Edición';
    }
  }
}
