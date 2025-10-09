import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/sharing_service.dart';
import '../services/toast_service.dart';
import '../theme/app_theme.dart';

/// Dialog para compartir una nota o carpeta
class ShareDialog extends StatefulWidget {
  final String itemId;
  final SharedItemType itemType;
  final String itemTitle;

  const ShareDialog({
    super.key,
    required this.itemId,
    required this.itemType,
    required this.itemTitle,
  });

  @override
  State<ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<ShareDialog> {
  final _formKey = GlobalKey<FormState>();
  final _recipientController = TextEditingController();
  final _messageController = TextEditingController();
  
  PermissionLevel _selectedPermission = PermissionLevel.read;
  bool _isLoading = false;
  Map<String, dynamic>? _foundUser;
  List<SharedItem> _sharedByMe = [];
  bool _loadingExisting = true;
  String? _publicToken;
  bool _publicBusy = false;

  @override
  void initState() {
    super.initState();
    _loadExistingSharings();
  }

  Future<void> _loadExistingSharings() async {
    setState(() { _loadingExisting = true; });
    try {
      final list = await SharingService().getSharedByMe();
      setState(() {
        _sharedByMe = list.where((s) => s.itemId == widget.itemId && s.type == widget.itemType).toList();
      });
      // Public token (solo para notas por ahora)
      if (widget.itemType == SharedItemType.note) {
        _publicToken = await SharingService().getPublicLinkToken(noteId: widget.itemId);
      }
    } catch (e) {
      // silencioso
    } finally {
      if (mounted) setState(() { _loadingExisting = false; });
    }
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _searchUser() async {
    final identifier = _recipientController.text.trim();
    if (identifier.isEmpty) return;

    setState(() => _isLoading = true);
    
    try {
      Map<String, dynamic>? user;
      if (identifier.contains('@')) {
        user = await SharingService().findUserByEmail(identifier);
      } else {
        user = await SharingService().findUserByUsername(identifier);
      }

      setState(() => _foundUser = user);
      
      if (user == null) {
        ToastService.error('Usuario no encontrado');
      } else {
        ToastService.success('Usuario encontrado: ${user['fullName'] ?? user['username']}');
      }
    } catch (e) {
      ToastService.error('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _share() async {
    if (!_formKey.currentState!.validate()) return;
    if (_foundUser == null) {
      ToastService.warning('Primero busca y verifica el usuario');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final sharingService = SharingService();
      final recipientIdentifier = _recipientController.text.trim();
      final message = _messageController.text.trim().isEmpty 
          ? null 
          : _messageController.text.trim();

      if (widget.itemType == SharedItemType.note) {
        await sharingService.shareNote(
          noteId: widget.itemId,
          recipientIdentifier: recipientIdentifier,
          permission: _selectedPermission,
          message: message,
        );
      } else {
        await sharingService.shareFolder(
          folderId: widget.itemId,
          recipientIdentifier: recipientIdentifier,
          permission: _selectedPermission,
          message: message,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ToastService.success('${widget.itemType == SharedItemType.note ? 'Nota' : 'Carpeta'} compartida exitosamente');
      }
    } catch (e) {
      ToastService.error('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            widget.itemType == SharedItemType.note 
                ? Icons.share 
                : Icons.folder_shared,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Compartir ${widget.itemType == SharedItemType.note ? 'Nota' : 'Carpeta'}',
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_loadingExisting)
                  const LinearProgressIndicator(minHeight: 2),
                if (!_loadingExisting && _sharedByMe.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.people_alt_rounded, size: 18, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text('Accesos existentes', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ..._sharedByMe.map((s) => _buildExistingSharingTile(s)).toList(),
                      ],
                    ),
                  ),
                ],
                if (widget.itemType == SharedItemType.note) _buildPublicLinkCard(),
                // Información del elemento a compartir
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.itemType == SharedItemType.note 
                            ? Icons.note_alt_outlined 
                            : Icons.folder_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.itemTitle,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Campo para buscar usuario
                Text(
                  'Usuario destinatario',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2D3436),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _recipientController,
                        decoration: InputDecoration(
                          hintText: 'Email o username',
                          prefixIcon: const Icon(Icons.person_search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          suffixIcon: _foundUser != null
                              ? Icon(Icons.check_circle, color: AppColors.success)
                              : null,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ingresa email o username';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          if (_foundUser != null) {
                            setState(() => _foundUser = null);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _searchUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.search),
                    ),
                  ],
                ),
                
                // Mostrar usuario encontrado
                if (_foundUser != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.success,
                          radius: 16,
                          child: Text(
                            (_foundUser!['fullName']?.toString().isNotEmpty == true
                                ? _foundUser!['fullName'][0]
                                : _foundUser!['username']?[0] ?? '?').toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _foundUser!['fullName'] ?? _foundUser!['username'] ?? 'Usuario',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                _foundUser!['email'] ?? '',
                                style: const TextStyle(
                                  color: Color(0xFF636E72),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.verified_user,
                          color: AppColors.success,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 20),
                
                // Selector de permisos
                Text(
                  'Nivel de permisos',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2D3436),
                  ),
                ),
                const SizedBox(height: 8),
                Column(
                  children: PermissionLevel.values.map((permission) {
                    return RadioListTile<PermissionLevel>(
                      value: permission,
                      groupValue: _selectedPermission,
                      onChanged: (value) {
                        setState(() => _selectedPermission = value!);
                      },
                      title: Text(_getPermissionTitle(permission)),
                      subtitle: Text(
                        _getPermissionDescription(permission),
                        style: const TextStyle(
                          color: Color(0xFF636E72),
                          fontSize: 12,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                    );
                  }).toList(),
                ),
                
                const SizedBox(height: 16),
                
                // Mensaje opcional
                Text(
                  'Mensaje (opcional)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2D3436),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Agregar un mensaje personal...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLines: 3,
                  maxLength: 500,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _loadingExisting ? null : _loadExistingSharings,
          child: const Text('Refrescar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _share,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Compartir'),
        ),
      ],
    );
  }

  String _getPermissionTitle(PermissionLevel permission) {
    switch (permission) {
      case PermissionLevel.read:
        return 'Solo lectura';
      case PermissionLevel.comment:
        return 'Lectura y comentarios';
      case PermissionLevel.edit:
        return 'Lectura y edición';
    }
  }

  String _getPermissionDescription(PermissionLevel permission) {
    switch (permission) {
      case PermissionLevel.read:
        return 'Puede ver el contenido únicamente';
      case PermissionLevel.comment:
        return 'Puede ver y agregar comentarios';
      case PermissionLevel.edit:
        return 'Puede ver, comentar y modificar el contenido';
    }
  }
  // === Public Link Section ===
  Widget _buildPublicLinkCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.public, color: _publicToken != null ? AppColors.success : AppColors.textSecondary, size: 18),
              const SizedBox(width: 6),
              const Text('Enlace público', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              if (_publicBusy) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              if (!_publicBusy && _publicToken == null)
                TextButton(
                  onPressed: _createPublicLink,
                  child: const Text('Generar'),
                ),
              if (!_publicBusy && _publicToken != null)
                TextButton(
                  onPressed: _revokePublicLink,
                  child: const Text('Revocar'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (_publicToken == null)
            const Text('Permite compartir la nota con cualquiera que tenga el enlace (solo lectura).', style: TextStyle(fontSize: 12))
          else
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    _composePublicUrl(_publicToken!),
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
                IconButton(
                  tooltip: 'Copiar',
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: _composePublicUrl(_publicToken!)));
                    ToastService.success('Copiado');
                  },
                ),
                IconButton(
                  tooltip: 'Abrir',
                  icon: const Icon(Icons.open_in_new, size: 18),
                  onPressed: () => Navigator.of(context).pushNamed('/p/${_publicToken!}'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _composePublicUrl(String token) => '/p/$token';

  Future<void> _createPublicLink() async {
    if (_publicBusy) return;
    setState(() => _publicBusy = true);
    try {
      final token = await SharingService().generatePublicLink(noteId: widget.itemId);
      setState(() => _publicToken = token);
      ToastService.success('Enlace generado');
    } catch (e) {
      ToastService.error('Error: $e');
    } finally { if (mounted) setState(() => _publicBusy = false); }
  }

  Future<void> _revokePublicLink() async {
    if (_publicBusy) return;
    setState(() => _publicBusy = true);
    try {
      await SharingService().revokePublicLink(noteId: widget.itemId);
      setState(() => _publicToken = null);
      ToastService.success('Enlace revocado');
    } catch (e) {
      ToastService.error('Error: $e');
    } finally { if (mounted) setState(() => _publicBusy = false); }
  }

  Widget _buildExistingSharingTile(SharedItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.person, size: 20, color: Colors.blueGrey.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.recipientEmail,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _statusChip(item.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Permiso: ${item.permission.name}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                if (item.message != null && item.message!.isNotEmpty)
                  Text('“${item.message}”', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black54)),
                if (item.metadata?['noteTitle'] != null)
                  Text('Nota: ${item.metadata?['noteTitle']}', style: const TextStyle(fontSize: 11, color: Colors.black45)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              IconButton(
                tooltip: 'Revocar',
                icon: const Icon(Icons.block, size: 18),
                onPressed: item.status == SharingStatus.revoked ? null : () async {
                  try {
                    await SharingService().revokeSharing(item.id);
                    ToastService.success('Acceso revocado');
                    _loadExistingSharings();
                  } catch (e) {
                    ToastService.error('Error revocando: $e');
                  }
                },
              ),
              IconButton(
                tooltip: 'Eliminar',
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: () async {
                  try {
                    await SharingService().deleteSharing(item.id);
                    ToastService.success('Eliminado');
                    _loadExistingSharings();
                  } catch (e) {
                    ToastService.error('Error eliminando: $e');
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _statusChip(SharingStatus status) {
  Color bg;
  Color fg;
  switch (status) {
    case SharingStatus.pending:
      bg = Colors.orange.withValues(alpha: 0.12); fg = Colors.orange; break;
    case SharingStatus.accepted:
      bg = Colors.green.withValues(alpha: 0.12); fg = Colors.green; break;
    case SharingStatus.rejected:
      bg = Colors.red.withValues(alpha: 0.12); fg = Colors.red; break;
    case SharingStatus.revoked:
      bg = Colors.grey.withValues(alpha: 0.12); fg = Colors.grey; break;
  }
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(status.name, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}
