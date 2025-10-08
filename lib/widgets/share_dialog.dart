import 'package:flutter/material.dart';
import '../services/sharing_service.dart';
import '../services/toast_service.dart';
import '../theme/app_colors.dart';

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
}