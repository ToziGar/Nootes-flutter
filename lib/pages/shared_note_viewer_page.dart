import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'dart:convert';
import '../services/sharing_service.dart';
import '../services/toast_service.dart';
import '../services/activity_log_service.dart';
import '../services/comment_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/visual_improvements.dart';

/// Página para ver y editar notas compartidas según permisos
class SharedNoteViewerPage extends StatefulWidget {
  final String noteId;
  final SharedItem sharingInfo;

  const SharedNoteViewerPage({
    super.key,
    required this.noteId,
    required this.sharingInfo,
  });

  @override
  State<SharedNoteViewerPage> createState() => _SharedNoteViewerPageState();
}

class _SharedNoteViewerPageState extends State<SharedNoteViewerPage> {
  quill.QuillController? _controller;
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = true;
  bool _showComments = false;
  bool _showActivity = false;
  Map<String, dynamic>? _noteData;
  List<String> _collaboratorIds = [];
  
  // Estado de comentarios
  final TextEditingController _commentController = TextEditingController();
  bool _isSendingComment = false;
  String? _editingCommentId;
  String? _replyingToCommentId;
  
  @override
  void initState() {
    super.initState();
    _loadNote();
    _loadCollaborators();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _focusNode.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadNote() async {
    setState(() => _isLoading = true);
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.sharingInfo.ownerId)
          .collection('notes')
          .doc(widget.noteId)
          .get();

      if (!doc.exists) {
        if (mounted) {
          ToastService.error('La nota no existe o fue eliminada');
          Navigator.pop(context);
        }
        return;
      }

      final data = doc.data()!;
      final content = data['content'] as String? ?? '';
      
      quill.Document document;
      if (content.isEmpty) {
        document = quill.Document()..insert(0, '');
      } else {
        try {
          final jsonData = jsonDecode(content);
          document = quill.Document.fromJson(jsonData);
        } catch (e) {
          document = quill.Document()..insert(0, content);
        }
      }

      setState(() {
        _noteData = data;
        _controller = quill.QuillController(
          document: document,
          selection: const TextSelection.collapsed(offset: 0),
        );
        _isLoading = false;
      });

      // Registrar actividad: nota abierta
      await ActivityLogService().logActivity(
        noteId: widget.noteId,
        ownerId: widget.sharingInfo.ownerId,
        type: ActivityType.noteOpened,
      );

      // Configurar listener para auto-guardar si tiene permisos de edición
      if (_hasEditPermission && _controller != null) {
        _controller!.document.changes.listen((event) {
          _autoSaveNote();
        });
      }
    } catch (e) {
      debugPrint('❌ Error cargando nota: $e');
      if (mounted) {
        ToastService.error('Error cargando la nota: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadCollaborators() async {
    try {
      final sharingService = SharingService();
      final shares = await sharingService.getSharedByMe();
      
      final noteShares = shares.where((share) => 
        share.itemId == widget.noteId &&
        share.status == SharingStatus.accepted
      ).toList();

      final collaboratorIds = noteShares.map((share) => share.recipientId).toList();
      
      // Añadir al propietario
      if (!collaboratorIds.contains(widget.sharingInfo.ownerId)) {
        collaboratorIds.insert(0, widget.sharingInfo.ownerId);
      }

      setState(() {
        _collaboratorIds = collaboratorIds;
      });
    } catch (e) {
      debugPrint('❌ Error cargando colaboradores: $e');
    }
  }

  Future<void> _autoSaveNote() async {
    if (_controller == null || !_hasEditPermission) return;

    try {
      final json = jsonEncode(_controller!.document.toDelta().toJson());
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.sharingInfo.ownerId)
          .collection('notes')
          .doc(widget.noteId)
          .update({
        'content': json,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Registrar actividad: nota editada
      await ActivityLogService().logActivity(
        noteId: widget.noteId,
        ownerId: widget.sharingInfo.ownerId,
        type: ActivityType.noteEdited,
        metadata: {'changes': 1},
      );
    } catch (e) {
      debugPrint('❌ Error guardando nota: $e');
    }
  }

  bool get _hasEditPermission {
    return widget.sharingInfo.permission == PermissionLevel.edit;
  }

  bool get _hasCommentPermission {
    return widget.sharingInfo.permission == PermissionLevel.comment ||
           widget.sharingInfo.permission == PermissionLevel.edit;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: _noteData == null 
            ? Text('Cargando...')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _noteData!['title'] ?? 'Sin título',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _getPermissionText(),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
        actions: [
          // Colaboradores en línea
          if (_collaboratorIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildCollaboratorsWidget(),
            ),
          
          // Botón de comentarios
          if (_hasCommentPermission)
            IconButton(
              icon: Stack(
                children: [
                  Icon(
                    Icons.comment_rounded,
                    color: _showComments ? AppColors.primary : AppColors.textSecondary,
                  ),
                  // Badge de comentarios sin leer (TODO: implementar)
                ],
              ),
              onPressed: () {
                setState(() {
                  _showComments = !_showComments;
                  if (_showComments) _showActivity = false;
                });
              },
              tooltip: 'Comentarios',
            ),
          
          // Botón de actividad
          IconButton(
            icon: Icon(
              Icons.history_rounded,
              color: _showActivity ? AppColors.primary : AppColors.textSecondary,
            ),
            onPressed: () {
              setState(() {
                _showActivity = !_showActivity;
                if (_showActivity) _showComments = false;
              });
            },
            tooltip: 'Historial de actividad',
          ),
          
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // Editor principal
                Expanded(
                  flex: _showComments || _showActivity ? 2 : 3,
                  child: _buildEditor(),
                ),
                
                // Panel lateral de comentarios
                if (_showComments)
                  Container(
                    width: 350,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border(
                        left: BorderSide(color: AppColors.borderColor),
                      ),
                    ),
                    child: _buildCommentsPanel(),
                  ),
                
                // Panel lateral de actividad
                if (_showActivity)
                  Container(
                    width: 350,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border(
                        left: BorderSide(color: AppColors.borderColor),
                      ),
                    ),
                    child: _buildActivityPanel(),
                  ),
              ],
            ),
      
      // FAB para comentarios en móvil
      floatingActionButton: _hasCommentPermission && !_showComments
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  _showComments = true;
                  _showActivity = false;
                });
              },
              backgroundColor: AppColors.primary,
              child: Icon(Icons.comment_rounded),
            )
          : null,
    );
  }

  Widget _buildEditor() {
    if (_controller == null) {
      return Center(child: CircularProgressIndicator());
    }

    return Container(
      color: AppColors.bg,
      child: Column(
        children: [
          // Toolbar si tiene permisos de edición  
          if (_hasEditPermission)
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  bottom: BorderSide(color: AppColors.borderColor),
                ),
              ),
              padding: const EdgeInsets.all(8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.format_bold),
                      onPressed: () {
                        _controller!.formatSelection(quill.Attribute.bold);
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.format_italic),
                      onPressed: () {
                        _controller!.formatSelection(quill.Attribute.italic);
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.format_underline),
                      onPressed: () {
                        _controller!.formatSelection(quill.Attribute.underline);
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.format_list_bulleted),
                      onPressed: () {
                        _controller!.formatSelection(quill.Attribute.ul);
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.format_list_numbered),
                      onPressed: () {
                        _controller!.formatSelection(quill.Attribute.ol);
                      },
                    ),
                  ],
                ),
              ),
            ),
          
          // Editor
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.bg,
              child: quill.QuillEditor.basic(
                controller: _controller!,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollaboratorsWidget() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        itemCount: _collaboratorIds.length > 3 ? 3 : _collaboratorIds.length,
        itemBuilder: (context, index) {
          final userId = _collaboratorIds[index];
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _buildCollaboratorAvatar(userId),
          );
        },
      ),
    );
  }

  Widget _buildCollaboratorAvatar(String userId) {
    return UserAvatar(
      userId: userId,
      size: 32,
      showPresence: true,
    );
  }

  Widget _buildCommentsPanel() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.borderColor),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.comment_rounded, color: AppColors.primary),
              const SizedBox(width: 12),
              Text(
                'Comentarios',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Spacer(),
              IconButton(
                icon: Icon(Icons.close, size: 20),
                onPressed: () {
                  setState(() => _showComments = false);
                },
              ),
            ],
          ),
        ),
        
        // Lista de comentarios
        Expanded(
          child: StreamBuilder<List<Comment>>(
            stream: CommentService().getCommentsStream(widget.noteId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: ${snapshot.error}'),
                    ],
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              final comments = snapshot.data ?? [];

              if (comments.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.comment_outlined,
                        size: 48,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Sin comentarios',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _hasCommentPermission
                            ? 'Sé el primero en comentar'
                            : 'Los comentarios aparecerán aquí',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  return _buildCommentCard(comments[index]);
                },
              );
            },
          ),
        ),
        
        // Input de comentario (solo si tiene permisos)
        if (_hasCommentPermission)
          _buildCommentInput(),
      ],
    );
  }

  Widget _buildActivityPanel() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.borderColor),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.history_rounded, color: AppColors.primary),
              const SizedBox(width: 12),
              Text(
                'Actividad',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Spacer(),
              IconButton(
                icon: Icon(Icons.close, size: 20),
                onPressed: () {
                  setState(() => _showActivity = false);
                },
              ),
            ],
          ),
        ),
        
        // Timeline de actividad
        Expanded(
          child: StreamBuilder<List<ActivityLog>>(
            stream: ActivityLogService().getActivityStream(
              widget.noteId,
              widget.sharingInfo.ownerId,
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: ${snapshot.error}'),
                    ],
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              final activities = snapshot.data ?? [];

              if (activities.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.timeline, size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'Sin actividad',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Las actividades aparecerán aquí',
                        style: TextStyle(fontSize: 14, color: Colors.grey[400]),
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
                  final isLast = index == activities.length - 1;
                  
                  return _buildActivityItem(activity, isLast);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(ActivityLog activity, bool isLast) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline line
        Column(
          children: [
            // Circle icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: activity.color.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: activity.color,
                  width: 2,
                ),
              ),
              child: Icon(
                activity.icon,
                size: 20,
                color: activity.color,
              ),
            ),
            // Vertical line
            if (!isLast)
              Container(
                width: 2,
                height: 60,
                color: Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 16),
        // Content
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        activity.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      activity.timeAgo,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  activity.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getPermissionText() {
    switch (widget.sharingInfo.permission) {
      case PermissionLevel.read:
        return 'Solo lectura';
      case PermissionLevel.comment:
        return 'Puede comentar';
      case PermissionLevel.edit:
        return 'Puede editar';
    }
  }

  // ============ COMENTARIOS ============

  Widget _buildCommentCard(Comment comment) {
    final currentUserId = AuthService.instance.currentUser?.uid;
    final isMyComment = comment.authorId == currentUserId;
    final isEditing = _editingCommentId == comment.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: comment.isDeleted ? Colors.red.shade200 : AppColors.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar + Email + Timestamp
          Row(
            children: [
              UserAvatar(
                userId: comment.authorId,
                email: comment.authorEmail,
                size: 32,
                showPresence: false,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.authorEmail,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      comment.timeAgo,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              if (isMyComment && !comment.isDeleted)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, size: 18),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          const SizedBox(width: 8),
                          Text('Editar'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          const SizedBox(width: 8),
                          Text('Eliminar', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      _startEditingComment(comment);
                    } else if (value == 'delete') {
                      _deleteComment(comment.id);
                    }
                  },
                ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Content (editable o no)
          if (isEditing)
            Column(
              children: [
                TextField(
                  controller: _commentController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Editar comentario...',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _editingCommentId = null;
                          _commentController.clear();
                        });
                      },
                      child: Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSendingComment ? null : () => _updateComment(comment.id),
                      child: _isSendingComment
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text('Guardar'),
                    ),
                  ],
                ),
              ],
            )
          else
            Text(
              comment.isDeleted ? '[Comentario eliminado]' : comment.content,
              style: TextStyle(
                fontSize: 14,
                color: comment.isDeleted ? Colors.grey : AppColors.textPrimary,
                fontStyle: comment.isDeleted ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          
          // Actions (solo si no está eliminado)
          if (!comment.isDeleted && !isEditing)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  TextButton.icon(
                    icon: Icon(Icons.reply, size: 16),
                    label: Text('Responder'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _startReplyingToComment(comment),
                  ),
                ],
              ),
            ),
          
          // Indicador de respuesta
          if (comment.parentCommentId != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.subdirectory_arrow_right, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'En respuesta a un comentario',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.borderColor),
        ),
        color: AppColors.bg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Indicador de respuesta
          if (_replyingToCommentId != null)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.reply, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Respondiendo a un comentario',
                      style: TextStyle(fontSize: 13, color: Colors.blue),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    onPressed: () {
                      setState(() => _replyingToCommentId = null);
                    },
                  ),
                ],
              ),
            ),
          
          // Input field
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              UserAvatar(
                userId: AuthService.instance.currentUser?.uid ?? '',
                email: AuthService.instance.currentUser?.email ?? '',
                size: 32,
                showPresence: false,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _commentController,
                  maxLines: null,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: _replyingToCommentId != null
                        ? 'Escribe tu respuesta...'
                        : 'Escribe un comentario...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.send_rounded,
                  color: _isSendingComment ? Colors.grey : AppColors.primary,
                ),
                onPressed: _isSendingComment ? null : _sendComment,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _startEditingComment(Comment comment) {
    setState(() {
      _editingCommentId = comment.id;
      _commentController.text = comment.content;
    });
  }

  void _startReplyingToComment(Comment comment) {
    setState(() {
      _replyingToCommentId = comment.id;
      _commentController.clear();
    });
    // Foco en el input
    Future.delayed(Duration(milliseconds: 100), () {
      FocusScope.of(context).requestFocus(FocusNode());
    });
  }

  Future<void> _sendComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) {
      ToastService.error('Escribe un comentario');
      return;
    }

    setState(() => _isSendingComment = true);

    try {
      await CommentService().createComment(
        noteId: widget.noteId,
        ownerId: widget.sharingInfo.ownerId,
        content: content,
        parentCommentId: _replyingToCommentId,
      );

      _commentController.clear();
      setState(() {
        _replyingToCommentId = null;
      });
      
      ToastService.success('Comentario publicado');
    } catch (e) {
      ToastService.error('Error al publicar: $e');
    } finally {
      setState(() => _isSendingComment = false);
    }
  }

  Future<void> _updateComment(String commentId) async {
    final content = _commentController.text.trim();
    if (content.isEmpty) {
      ToastService.error('El comentario no puede estar vacío');
      return;
    }

    setState(() => _isSendingComment = true);

    try {
      await CommentService().updateComment(commentId, content);
      
      _commentController.clear();
      setState(() {
        _editingCommentId = null;
      });
      
      ToastService.success('Comentario actualizado');
    } catch (e) {
      ToastService.error('Error al actualizar: $e');
    } finally {
      setState(() => _isSendingComment = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar comentario'),
        content: Text('¿Estás seguro de que deseas eliminar este comentario?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await CommentService().deleteComment(commentId);
      ToastService.success('Comentario eliminado');
    } catch (e) {
      ToastService.error('Error al eliminar: $e');
    }
  }
}
