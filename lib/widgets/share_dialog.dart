import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/sharing_service.dart';
import '../services/toast_service.dart';
import '../theme/app_theme.dart';

/// Dialog para compartir una nota o carpeta con diseño moderno
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

class _ShareDialogState extends State<ShareDialog> with TickerProviderStateMixin {
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
  
  // Autocomplete
  List<Map<String, dynamic>> _suggestions = [];
  bool _showSuggestions = false;
  String? _errorMessage;

  // Animaciones
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadExistingSharings();
    
    // Inicializar animaciones
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    // Iniciar animaciones
    _slideController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _messageController.dispose();
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingSharings() async {
    try {
      // Simulación de carga de comparticiones existentes
      // Aquí iría la llamada real al servicio
      await Future.delayed(const Duration(milliseconds: 800));
      
      setState(() {
        _sharedByMe = []; // Lista vacía por ahora
        _loadingExisting = false;
      });
    } catch (e) {
      setState(() => _loadingExisting = false);
    }

    if (widget.itemType == SharedItemType.note) {
      try {
        final token = await SharingService().getPublicLinkToken(noteId: widget.itemId);
        setState(() => _publicToken = token);
      } catch (e) {
        // Ignorar errores de enlace público
      }
    }
  }

  Future<void> _searchSuggestions(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
        _errorMessage = null;
      });
      return;
    }

    if (query.length < 2) {
      setState(() {
        _showSuggestions = false;
        _suggestions = [];
        _errorMessage = null;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final suggestions = <Map<String, dynamic>>[];
      
      if (query.contains('@') && !query.startsWith('@')) {
        final user = await SharingService().findUserByEmail(query);
        if (user != null) {
          suggestions.add(user);
        }
      } else {
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
        _errorMessage = suggestions.isEmpty ? 'No se encontraron usuarios que coincidan' : null;
      });
    } catch (e) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
        _errorMessage = 'Error al buscar: ${e.toString()}';
      });
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
      final errorMsg = e.toString().toLowerCase();
      String userFriendlyMsg = 'Error al compartir';
      
      if (errorMsg.contains('permission') || errorMsg.contains('permisos')) {
        userFriendlyMsg = 'Permisos insuficientes. Verifica que tengas acceso a este elemento.';
      } else if (errorMsg.contains('not found') || errorMsg.contains('no encontr')) {
        userFriendlyMsg = 'El elemento no fue encontrado o ya no existe.';
      } else if (errorMsg.contains('network') || errorMsg.contains('connection')) {
        userFriendlyMsg = 'Error de conexión. Verifica tu internet.';
      } else if (errorMsg.contains('already shared') || errorMsg.contains('ya está compartida')) {
        userFriendlyMsg = 'Este elemento ya está compartido con este usuario.';
      }
      
      ToastService.error(userFriendlyMsg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 650,
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.borderColor,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                Expanded(
                  child: _buildContent(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primaryLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          Hero(
            tag: 'share_icon_${widget.itemId}',
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.textPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.2), width: 2),
              ),
              child: Icon(
                widget.itemType == SharedItemType.note
                    ? Icons.share_rounded
                    : Icons.folder_shared_rounded,
                color: AppColors.textPrimary,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Compartir ${widget.itemType == SharedItemType.note ? 'Nota' : 'Carpeta'}',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.itemTitle,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.textPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.close_rounded, color: AppColors.textPrimary, size: 24),
              padding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loadingExisting) _buildLoadingIndicator(),
            if (!_loadingExisting && _sharedByMe.isNotEmpty) _buildExistingShares(),
            if (!_loadingExisting && _sharedByMe.isEmpty) _buildNoSharesHint(),
            if (widget.itemType == SharedItemType.note) _buildPublicLinkCard(),
            _buildNewShareForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 28),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.primary.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          LinearProgressIndicator(
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 4,
          ),
          const SizedBox(height: 16),
          Text(
            'Cargando comparticiones existentes...',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingShares() {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.success.withValues(alpha: 0.1),
            AppColors.success.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.people_alt_rounded, size: 24, color: AppColors.success),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_sharedByMe.length} persona${_sharedByMe.length != 1 ? 's' : ''} con acceso',
                        style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'Gestiona los permisos existentes',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ...(_sharedByMe.map((s) => _buildExistingSharingTile(s)).toList()),
        ],
      ),
    );
  }

  Widget _buildExistingSharingTile(SharedItem item) {
    return Container(
      margin: const EdgeInsets.only(left: 24, right: 24, bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              item.recipientEmail.substring(0, 1).toUpperCase(),
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.recipientEmail,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${item.permission.name} • ${item.status.name}',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _revokeSharing(item.id),
            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSharesHint() {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight3,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.share_outlined, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            'Aún no has compartido este elemento',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublicLinkCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.secondary.withValues(alpha: 0.1),
            AppColors.secondary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.link_rounded, color: AppColors.secondary, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enlace público',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Cualquiera con el enlace puede ver',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _publicToken != null,
                onChanged: _publicBusy ? null : (value) => _togglePublicLink(),
                activeThumbColor: AppColors.secondary,
              ),
            ],
          ),
          if (_publicToken != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'https://nootes.app/public/$_publicToken',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _copyPublicLink(),
                    icon: const Icon(Icons.copy_rounded),
                    tooltip: 'Copiar enlace',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _togglePublicLink() async {
    setState(() => _publicBusy = true);
    try {
      if (_publicToken != null) {
        await SharingService().revokePublicLink(noteId: widget.itemId);
        setState(() => _publicToken = null);
        ToastService.success('Enlace público deshabilitado');
      } else {
        final token = await SharingService().generatePublicLink(noteId: widget.itemId);
        setState(() => _publicToken = token);
        ToastService.success('Enlace público generado');
      }
    } catch (e) {
      ToastService.error('Error: $e');
    } finally {
      setState(() => _publicBusy = false);
    }
  }

  Future<void> _copyPublicLink() async {
    if (_publicToken != null) {
      await Clipboard.setData(ClipboardData(text: 'https://nootes.app/public/$_publicToken'));
      ToastService.success('Enlace copiado');
    }
  }

  Widget _buildNewShareForm() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surface,
            AppColors.surfaceLight,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildFormHeader(),
          _buildSearchField(),
          if (_showSuggestions) _buildSuggestions(),
          if (_errorMessage != null) _buildErrorMessage(),
          if (_foundUser != null) _buildFoundUser(),
          _buildPermissionSelector(),
          _buildMessageField(),
          _buildShareButton(),
        ],
      ),
    );
  }

  Widget _buildFormHeader() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.person_add_rounded, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invitar nueva persona',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontSize: 20,
                  ),
                ),
                Text(
                  'Busca por email o nombre de usuario',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _foundUser != null 
                ? AppColors.success
                : _errorMessage != null
                    ? AppColors.danger
                    : AppColors.borderColor.withValues(alpha: 0.4),
            width: _foundUser != null || _errorMessage != null ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _foundUser != null 
                  ? AppColors.success.withValues(alpha: 0.2)
                  : _errorMessage != null
                      ? AppColors.danger.withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _foundUser != null 
                      ? AppColors.success.withValues(alpha: 0.15)
                      : _errorMessage != null
                          ? AppColors.danger.withValues(alpha: 0.15)
                          : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _foundUser != null 
                      ? Icons.check_circle_rounded 
                      : _errorMessage != null
                          ? Icons.error_outline_rounded
                          : Icons.search_rounded,
                  color: _foundUser != null 
                      ? AppColors.success 
                      : _errorMessage != null
                          ? AppColors.danger
                          : AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: TextFormField(
                  controller: _recipientController,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                    hintText: 'usuario@email.com o @usuario',
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
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
              if (_isLoading)
                Container(
                  margin: const EdgeInsets.only(left: 16),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                )
              else if (_recipientController.text.trim().isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(left: 16),
                  child: IconButton(
                    onPressed: () {
                      setState(() {
                        _recipientController.clear();
                        _foundUser = null;
                        _showSuggestions = false;
                        _suggestions = [];
                        _errorMessage = null;
                      });
                    },
                    icon: Icon(
                      Icons.clear_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.textSecondary.withValues(alpha: 0.1),
                      padding: const EdgeInsets.all(8),
                      minimumSize: const Size(36, 36),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: _suggestions.map((suggestion) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Icon(Icons.person, color: AppColors.primary, size: 18),
            ),
            title: Text(
              suggestion['fullName'] ?? suggestion['username'] ?? 'Usuario',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(suggestion['email'] ?? ''),
            onTap: () {
              setState(() {
                _recipientController.text = suggestion['email'] ?? suggestion['username'] ?? '';
                _foundUser = suggestion;
                _showSuggestions = false;
                _suggestions = [];
                _errorMessage = null;
              });
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.only(left: 28, right: 28, bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.danger, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: AppColors.danger, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoundUser() {
    return Container(
      margin: const EdgeInsets.only(left: 28, right: 28, bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.success,
            child: Icon(Icons.person, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _foundUser!['fullName'] ?? _foundUser!['username'] ?? 'Usuario',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  _foundUser!['email'] ?? '',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: AppColors.success),
        ],
      ),
    );
  }

  Widget _buildPermissionSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nivel de permisos',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...PermissionLevel.values.map((level) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Radio<PermissionLevel>(
                  value: level,
                  groupValue: _selectedPermission,
                  onChanged: (value) => setState(() => _selectedPermission = value!),
                ),
                title: Text(_getPermissionTitle(level)),
                subtitle: Text(_getPermissionDescription(level)),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMessageField() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mensaje (opcional)',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _messageController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Añade un mensaje personalizado...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareButton() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isLoading || _foundUser == null ? null : _share,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
          ),
          child: _isLoading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.textPrimary),
                  ),
                )
              : const Text(
                  'Compartir',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
        ),
      ),
    );
  }

  String _getPermissionTitle(PermissionLevel level) {
    switch (level) {
      case PermissionLevel.read:
        return 'Solo lectura';
      case PermissionLevel.comment:
        return 'Comentar';
      case PermissionLevel.edit:
        return 'Editar';
    }
  }

  String _getPermissionDescription(PermissionLevel level) {
    switch (level) {
      case PermissionLevel.read:
        return 'Puede ver el contenido';
      case PermissionLevel.comment:
        return 'Puede ver y comentar';
      case PermissionLevel.edit:
        return 'Puede ver, comentar y editar';
    }
  }

  Future<void> _revokeSharing(String shareId) async {
    try {
      await SharingService().revokeSharing(shareId);
      ToastService.success('Acceso revocado');
      _loadExistingSharings();
    } catch (e) {
      ToastService.error('Error al revocar: $e');
    }
  }
}
