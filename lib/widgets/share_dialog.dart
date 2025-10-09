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
  String? _publicToken; // solo para notas
  bool _publicBusy = false;
  
  // Autocomplete
  List<Map<String, dynamic>> _suggestions = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _loadExistingSharings();
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingSharings() async {
    setState(() => _loadingExisting = true);
    try {
      final list = await SharingService().getSharedByMe();
      setState(() {
        _sharedByMe = list
            .where((s) => s.itemId == widget.itemId && s.type == widget.itemType)
            .toList();
      });
      if (widget.itemType == SharedItemType.note) {
        _publicToken = await SharingService().getPublicLinkToken(noteId: widget.itemId);
      }
    } catch (_) {
      // no-op
    } finally {
      if (mounted) setState(() => _loadingExisting = false);
    }
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _searchSuggestions(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    try {
      // Búsqueda básica por prefijo - podrías expandir esto con más lógica
      final suggestions = <Map<String, dynamic>>[];
      
      // Si contiene @, buscar por email
      if (query.contains('@')) {
        final user = await SharingService().findUserByEmail(query);
        if (user != null) {
          suggestions.add(user);
        }
      } else {
        // Si empieza con @, buscar por username
        final cleanQuery = query.startsWith('@') ? query.substring(1) : query;
        if (cleanQuery.isNotEmpty) {
          final user = await SharingService().findUserByUsername(cleanQuery);
          if (user != null) {
            suggestions.add(user);
          }
        }
      }
      
      setState(() {
        _suggestions = suggestions;
        _showSuggestions = suggestions.isNotEmpty;
      });
    } catch (e) {
      // Silenciar errores de búsqueda de sugerencias
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.85)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      widget.itemType == SharedItemType.note
                          ? Icons.share_rounded
                          : Icons.folder_shared_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Compartir ${widget.itemType == SharedItemType.note ? 'Nota' : 'Carpeta'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.itemTitle,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_loadingExisting)
                        const LinearProgressIndicator(minHeight: 2),

                      if (!_loadingExisting && _sharedByMe.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 12, bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.people_alt_rounded, size: 18, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Text('Accesos existentes (${_sharedByMe.length})',
                                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ..._sharedByMe.map((s) => _buildExistingSharingTile(s)),
                            ],
                          ),
                        ),

                      if (!_loadingExisting && _sharedByMe.isEmpty)
                        _buildNoSharesHint(),

                      if (widget.itemType == SharedItemType.note) _buildPublicLinkCard(),

                      // Formulario
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.person_add_rounded, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text('Compartir con nueva persona',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    )),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      TextFormField(
                                        controller: _recipientController,
                                        decoration: InputDecoration(
                                          labelText: 'Email o nombre de usuario',
                                          hintText: 'usuario@ejemplo.com o @usuario',
                                          helperText: 'Puedes usar correo o @usuario',
                                          prefixIcon: const Icon(Icons.search_rounded),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                        ),
                                        validator: (value) {
                                          if (value == null || value.trim().isEmpty) {
                                            return 'Ingresa un email o nombre de usuario';
                                          }
                                          return null;
                                        },
                                        onChanged: (value) {
                                          if (_foundUser != null) setState(() => _foundUser = null);
                                          _searchSuggestions(value);
                                        },
                                      ),
                                      
                                      // Sugerencias
                                      if (_showSuggestions) 
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppColors.borderColor),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.1),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                            physics: const NeverScrollableScrollPhysics(),
                                            itemCount: _suggestions.length,
                                            itemBuilder: (context, index) {
                                              final suggestion = _suggestions[index];
                                              return ListTile(
                                                dense: true,
                                                leading: CircleAvatar(
                                                  backgroundColor: AppColors.primary.withOpacity(0.1),
                                                  child: Icon(Icons.person, color: AppColors.primary, size: 18),
                                                ),
                                                title: Text(
                                                  suggestion['fullName'] ?? suggestion['username'] ?? 'Usuario',
                                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                                ),
                                                subtitle: Text(suggestion['email'] ?? ''),
                                                onTap: () {
                                                  setState(() {
                                                    _recipientController.text = suggestion['email'] ?? suggestion['username'] ?? '';
                                                    _foundUser = suggestion;
                                                    _showSuggestions = false;
                                                    _suggestions = [];
                                                  });
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _searchUser,
                                  icon: _isLoading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.search_rounded, size: 18),
                                  label: const Text('Buscar'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),

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
                                      child: const Icon(Icons.person, color: Colors.white),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _foundUser!['fullName'] ?? _foundUser!['username'] ?? 'Usuario',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            _foundUser!['email'] ?? '',
                                            style:
                                                TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.check_circle, color: AppColors.success),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 12),

                            Text('Nivel de permisos',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                )),
                            const SizedBox(height: 6),
                            ...PermissionLevel.values.map((permission) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                child: RadioListTile<PermissionLevel>(
                                  value: permission,
                                  groupValue: _selectedPermission,
                                  onChanged: (value) => setState(() => _selectedPermission = value!),
                                  title: Row(
                                    children: [
                                      Icon(_permissionIcon(permission), size: 18, color: AppColors.textSecondary),
                                      const SizedBox(width: 8),
                                      Text(
                                        _getPermissionTitle(permission),
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                  subtitle: Text(_getPermissionDescription(permission)),
                                  dense: true,
                                  activeColor: AppColors.primary,
                                ),
                              );
                            }).toList(),

                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _messageController,
                              decoration: InputDecoration(
                                labelText: 'Mensaje (opcional)',
                                hintText: 'Añade un mensaje personal...',
                                prefixIcon: const Icon(Icons.message_rounded),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              maxLines: 3,
                              maxLength: 200,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border(top: BorderSide(color: AppColors.borderColor)),
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _loadingExisting ? null : _loadExistingSharings,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Refrescar'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: (_isLoading || _recipientController.text.trim().isEmpty || _foundUser == null) ? null : _share,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(_isLoading ? 'Compartiendo...' : 'Compartir'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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

  // ===== Public Link (solo notas) =====
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
              Icon(
                Icons.public,
                color: _publicToken != null ? AppColors.success : AppColors.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 6),
              const Text('Enlace público', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              if (_publicBusy)
                const Row(
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('Procesando...', style: TextStyle(fontSize: 12)),
                  ],
                )
              else if (_publicToken == null)
                TextButton.icon(
                  onPressed: _createPublicLink,
                  icon: const Icon(Icons.add_link, size: 16),
                  label: const Text('Generar'),
                )
              else
                TextButton.icon(
                  onPressed: _revokePublicLink,
                  icon: const Icon(Icons.link_off, size: 16),
                  label: const Text('Revocar'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (_publicToken == null)
            const Text('Permite compartir la nota con cualquiera que tenga el enlace (solo lectura).',
                style: TextStyle(fontSize: 12))
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
                  tooltip: _publicBusy ? 'Procesando...' : 'Copiar enlace',
                  icon: Icon(
                    _publicBusy ? Icons.hourglass_empty : Icons.copy,
                    size: 18,
                    color: _publicBusy ? AppColors.textSecondary : null,
                  ),
                  onPressed: _publicBusy
                      ? null
                      : () async {
                          await Clipboard.setData(
                            ClipboardData(text: _composePublicUrl(_publicToken!)),
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Row(
                                children: [
                                  Icon(Icons.copy, color: Colors.white, size: 16),
                                  SizedBox(width: 8),
                                  Text('Enlace copiado al portapapeles'),
                                ],
                              ),
                              backgroundColor: AppColors.primary,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                ),
                IconButton(
                  tooltip: _publicBusy ? 'Procesando...' : 'Abrir',
                  icon: Icon(
                    _publicBusy ? Icons.hourglass_empty : Icons.open_in_new,
                    size: 18,
                    color: _publicBusy ? AppColors.textSecondary : null,
                  ),
                  onPressed: _publicBusy
                      ? null
                      : () => Navigator.of(context).pushNamed('/p/${_publicToken!}'),
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.link, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Enlace público generado'),
            ],
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Copiar',
            textColor: Colors.white,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _composePublicUrl(token)));
            },
          ),
        ),
      );
    } catch (e) {
      ToastService.error('Error: $e');
    } finally {
      if (mounted) setState(() => _publicBusy = false);
    }
  }

  Future<void> _revokePublicLink() async {
    if (_publicBusy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revocar enlace público'),
        content: const Text(
          '¿Estás seguro de revocar este enlace? Las personas que lo tengan ya no podrán acceder a la nota.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Revocar')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _publicBusy = true);
    try {
      await SharingService().revokePublicLink(noteId: widget.itemId);
      setState(() => _publicToken = null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Enlace revocado'),
            ],
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ToastService.error('Error: $e');
    } finally {
      if (mounted) setState(() => _publicBusy = false);
    }
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
                Text('Permiso: ${item.permission.name}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
                if (item.message != null && item.message!.isNotEmpty)
                  Text('“${item.message}”',
                      style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black54)),
                if (item.metadata?['noteTitle'] != null)
                  Text('Nota: ${item.metadata?['noteTitle']}',
                      style: const TextStyle(fontSize: 11, color: Colors.black45)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              IconButton(
                tooltip: 'Revocar',
                icon: const Icon(Icons.block, size: 18),
                onPressed: item.status == SharingStatus.revoked
                    ? null
                    : () async {
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
  bg = Colors.orange.withValues(alpha: 0.12);
      fg = Colors.orange;
      break;
    case SharingStatus.accepted:
  bg = Colors.green.withValues(alpha: 0.12);
      fg = Colors.green;
      break;
    case SharingStatus.rejected:
  bg = Colors.red.withValues(alpha: 0.12);
      fg = Colors.red;
      break;
    case SharingStatus.revoked:
  bg = Colors.grey.withValues(alpha: 0.12);
      fg = Colors.grey;
      break;
  }
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      status.name,
      style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );
}

IconData _permissionIcon(PermissionLevel permission) {
    switch (permission) {
      case PermissionLevel.read:
        return Icons.visibility_rounded;
      case PermissionLevel.comment:
        return Icons.mode_comment_rounded;
      case PermissionLevel.edit:
        return Icons.edit_rounded;
    }
  }

  Widget _buildNoSharesHint() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Aún no has compartido este elemento. Usa el buscador para invitar a alguien con permisos.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
