import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/sharing_service.dart';
import '../services/auth_service.dart';
import '../services/toast_service.dart';
import '../theme/app_theme.dart';

/// Página profesional de gestión de notas compartidas
class SharedNoteManagementPage extends StatefulWidget {
  final String noteId;
  final SharedItem sharingInfo;

  const SharedNoteManagementPage({
    super.key,
    required this.noteId,
    required this.sharingInfo,
  });

  @override
  State<SharedNoteManagementPage> createState() => _SharedNoteManagementPageState();
}

class _SharedNoteManagementPageState extends State<SharedNoteManagementPage> with SingleTickerProviderStateMixin {
  final _authService = AuthService.instance;
  final _sharingService = SharingService();
  final _firestore = FirebaseFirestore.instance;
  
  late TabController _tabController;
  Map<String, dynamic>? _noteData;
  List<SharedItem> _allShares = [];
  List<Map<String, dynamic>> _comments = [];
  List<Map<String, dynamic>> _activityLogs = [];
  bool _isLoading = true;
  bool _isOwner = false;
  
  final TextEditingController _commentController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _isOwner = widget.sharingInfo.ownerId == _authService.currentUser?.uid;
    _loadData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Cargar datos de la nota
      final noteDoc = await _firestore
          .collection('users')
          .doc(widget.sharingInfo.ownerId)
          .collection('notes')
          .doc(widget.noteId)
          .get();
      
      if (!noteDoc.exists) {
        if (mounted) {
          ToastService.error('La nota no existe');
          Navigator.pop(context);
        }
        return;
      }
      
      _noteData = noteDoc.data();
      
      // Cargar todas las comparticiones
      if (_isOwner) {
        final sharesSnapshot = await _firestore
            .collection('shared_items')
            .where('itemId', isEqualTo: widget.noteId)
            .where('ownerId', isEqualTo: _authService.currentUser!.uid)
            .get();
        
        _allShares = sharesSnapshot.docs
            .map((doc) => SharedItem.fromMap(doc.id, doc.data()))
            .toList();
      }
      
      // Cargar comentarios
      final commentsSnapshot = await _firestore
          .collection('shared_items')
          .doc(widget.sharingInfo.id)
          .collection('comments')
          .orderBy('timestamp', descending: false)
          .get();
      
      _comments = commentsSnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
      
      // Cargar actividad (si el usuario es propietario)
      if (_isOwner) {
        final activitySnapshot = await _firestore
            .collection('activity_logs')
            .where('noteId', isEqualTo: widget.noteId)
            .orderBy('timestamp', descending: true)
            .limit(50)
            .get();
        
        _activityLogs = activitySnapshot.docs
            .map((doc) => doc.data())
            .toList();
      }
      
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error cargando datos: $e');
      ToastService.error('Error al cargar datos');
      setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _noteData?['title'] ?? 'Nota Compartida',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.info_outline), text: 'Detalles'),
            Tab(icon: Icon(Icons.people_outline), text: 'Usuarios'),
            Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Chat'),
          ],
        ),
        actions: [
          if (_isOwner)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadData,
              tooltip: 'Recargar',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDetailsTab(),
                _buildUsersTab(),
                _buildChatTab(),
              ],
            ),
    );
  }
  
  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Información de la nota
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primary.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.note_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _noteData?['title'] ?? 'Sin título',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Creada el ${_formatDate(_noteData?['createdAt'])}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildInfoRow(
                    Icons.person_outline,
                    'Propietario',
                    _isOwner ? 'Tú' : 'Otro usuario',
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.security_rounded,
                    'Tu permiso',
                    _getPermissionText(widget.sharingInfo.permission),
                    color: _getPermissionColor(widget.sharingInfo.permission),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.share_rounded,
                    'Compartido el',
                    _formatDate(widget.sharingInfo.createdAt),
                  ),
                  if (_noteData?['tags'] != null && (_noteData!['tags'] as List).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      Icons.label_outline,
                      'Etiquetas',
                      (_noteData!['tags'] as List).join(', '),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Contenido de la nota (solo lectura)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vista previa',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(height: 16),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: SingleChildScrollView(
                      child: Text(
                        _getPlainText(_noteData?['content']),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Actividad (solo para propietarios)
          if (_isOwner && _activityLogs.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Actividad reciente',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(height: 16),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _activityLogs.length > 5 ? 5 : _activityLogs.length,
                      separatorBuilder: (_, __) => const Divider(height: 16),
                      itemBuilder: (context, index) {
                        final log = _activityLogs[index];
                        return _buildActivityItem(log);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildUsersTab() {
    if (!_isOwner) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Solo el propietario puede ver esta información',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    
    if (_allShares.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No hay usuarios con acceso',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _allShares.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final share = _allShares[index];
        return _buildUserCard(share);
      },
    );
  }
  
  Widget _buildChatTab() {
    return Column(
      children: [
        // Lista de comentarios
        Expanded(
          child: _comments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Sin comentarios aún',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sé el primero en comentar',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _comments.length,
                  itemBuilder: (context, index) {
                    final comment = _comments[index];
                    final isMyComment = comment['userId'] == _authService.currentUser?.uid;
                    return _buildChatBubble(comment, isMyComment);
                  },
                ),
        ),
        
        // Campo de entrada de comentario
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Escribe un comentario...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.7),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                    onPressed: _sendComment,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildUserCard(SharedItem share) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    share.recipientEmail.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        share.recipientEmail,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildStatusBadge(share.status),
                          const SizedBox(width: 8),
                          _buildPermissionBadge(share.permission),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (share.message != null && share.message!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.message_outlined, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        share.message!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Compartido el ${_formatDate(share.createdAt)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            if (share.status == SharingStatus.accepted) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _changePermission(share),
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Cambiar permiso'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _revokeAccess(share),
                      icon: const Icon(Icons.block_rounded, size: 16),
                      label: const Text('Revocar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
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
  
  Widget _buildChatBubble(Map<String, dynamic> comment, bool isMyComment) {
    return Align(
      alignment: isMyComment ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: isMyComment ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMyComment)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Text(
                  comment['userName'] ?? 'Usuario',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isMyComment
                    ? LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withOpacity(0.8),
                        ],
                      )
                    : null,
                color: isMyComment ? null : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isMyComment ? const Radius.circular(16) : Radius.zero,
                  bottomRight: isMyComment ? Radius.zero : const Radius.circular(16),
                ),
              ),
              child: Text(
                comment['text'] ?? '',
                style: TextStyle(
                  color: isMyComment ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 12, right: 12),
              child: Text(
                _formatTimestamp(comment['timestamp']),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(IconData icon, String label, String value, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color ?? Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildActivityItem(Map<String, dynamic> log) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          _getActivityIcon(log['type']),
          size: 16,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                log['description'] ?? '',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                _formatTimestamp(log['timestamp']),
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatusBadge(SharingStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(status),
            size: 12,
            color: _getStatusColor(status),
          ),
          const SizedBox(width: 4),
          Text(
            _getStatusText(status),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _getStatusColor(status),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPermissionBadge(PermissionLevel permission) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getPermissionColor(permission).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getPermissionIcon(permission),
            size: 12,
            color: _getPermissionColor(permission),
          ),
          const SizedBox(width: 4),
          Text(
            _getPermissionText(permission),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _getPermissionColor(permission),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _sendComment() async {
    if (_commentController.text.trim().isEmpty) return;
    
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return;
      
      // Obtener el nombre del usuario
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      final userName = userDoc.data()?['displayName'] ?? currentUser.email ?? 'Usuario';
      
      await _firestore
          .collection('shared_items')
          .doc(widget.sharingInfo.id)
          .collection('comments')
          .add({
        'userId': currentUser.uid,
        'userName': userName,
        'text': _commentController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      _commentController.clear();
      ToastService.success('Comentario enviado');
      _loadData();
    } catch (e) {
      debugPrint('Error enviando comentario: $e');
      ToastService.error('Error al enviar comentario');
    }
  }
  
  Future<void> _changePermission(SharedItem share) async {
    final newPermission = await showDialog<PermissionLevel>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambiar permiso'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Usuario: ${share.recipientEmail}'),
            const SizedBox(height: 16),
            const Text('Selecciona el nuevo permiso:'),
            const SizedBox(height: 12),
            ...PermissionLevel.values.map((permission) {
              return RadioListTile<PermissionLevel>(
                title: Text(_getPermissionText(permission)),
                subtitle: Text(_getPermissionDescription(permission)),
                value: permission,
                groupValue: share.permission,
                onChanged: (value) => Navigator.pop(context, value),
              );
            }).toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    
    if (newPermission != null && newPermission != share.permission) {
      try {
        await _sharingService.updatePermission(share.id, newPermission);
        ToastService.success('Permiso actualizado');
        _loadData();
      } catch (e) {
        debugPrint('Error actualizando permiso: $e');
        ToastService.error('Error al actualizar permiso');
      }
    }
  }
  
  Future<void> _revokeAccess(SharedItem share) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revocar acceso'),
        content: Text(
          '¿Estás seguro de que quieres revocar el acceso de ${share.recipientEmail}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Revocar'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await _sharingService.revokeSharing(share.id);
        ToastService.success('Acceso revocado');
        _loadData();
      } catch (e) {
        debugPrint('Error revocando acceso: $e');
        ToastService.error('Error al revocar acceso');
      }
    }
  }
  
  // Helper methods
  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Fecha desconocida';
    
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return 'Fecha inválida';
    }
    
    return DateFormat('d MMM y', 'es').format(date);
  }
  
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return '';
    }
    
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) {
      return DateFormat('HH:mm').format(date);
    } else if (diff.inDays == 1) {
      return 'Ayer ${DateFormat('HH:mm').format(date)}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d';
    } else {
      return DateFormat('d MMM').format(date);
    }
  }
  
  String _getPlainText(dynamic content) {
    if (content == null || content.toString().isEmpty) {
      return 'Sin contenido';
    }
    
    // Intentar obtener texto plano del contenido Quill
    try {
      // Esto es una simplificación - en producción podrías usar un parser más sofisticado
      return content.toString().substring(0, content.toString().length > 500 ? 500 : content.toString().length);
    } catch (e) {
      return 'Error al mostrar contenido';
    }
  }
  
  Color _getPermissionColor(PermissionLevel permission) {
    switch (permission) {
      case PermissionLevel.read:
        return Colors.blue;
      case PermissionLevel.comment:
        return Colors.orange;
      case PermissionLevel.edit:
        return Colors.green;
    }
  }
  
  IconData _getPermissionIcon(PermissionLevel permission) {
    switch (permission) {
      case PermissionLevel.read:
        return Icons.visibility_rounded;
      case PermissionLevel.comment:
        return Icons.comment_rounded;
      case PermissionLevel.edit:
        return Icons.edit_rounded;
    }
  }
  
  String _getPermissionText(PermissionLevel permission) {
    switch (permission) {
      case PermissionLevel.read:
        return 'Lectura';
      case PermissionLevel.comment:
        return 'Comentar';
      case PermissionLevel.edit:
        return 'Editar';
    }
  }
  
  String _getPermissionDescription(PermissionLevel permission) {
    switch (permission) {
      case PermissionLevel.read:
        return 'Solo puede ver el contenido';
      case PermissionLevel.comment:
        return 'Puede ver y comentar';
      case PermissionLevel.edit:
        return 'Puede ver, comentar y editar';
    }
  }
  
  Color _getStatusColor(SharingStatus status) {
    switch (status) {
      case SharingStatus.pending:
        return Colors.orange;
      case SharingStatus.accepted:
        return Colors.green;
      case SharingStatus.rejected:
        return Colors.red;
      case SharingStatus.revoked:
        return Colors.grey;
      case SharingStatus.left:
        return Colors.grey;
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
        return Icons.exit_to_app_rounded;
    }
  }
  
  String _getStatusText(SharingStatus status) {
    switch (status) {
      case SharingStatus.pending:
        return 'Pendiente';
      case SharingStatus.accepted:
        return 'Activo';
      case SharingStatus.rejected:
        return 'Rechazado';
      case SharingStatus.revoked:
        return 'Revocado';
      case SharingStatus.left:
        return 'Abandonado';
    }
  }
  
  IconData _getActivityIcon(String? type) {
    switch (type) {
      case 'accessed':
        return Icons.visibility_rounded;
      case 'edited':
        return Icons.edit_rounded;
      case 'commented':
        return Icons.comment_rounded;
      case 'shared':
        return Icons.share_rounded;
      default:
        return Icons.info_outline;
    }
  }
}
