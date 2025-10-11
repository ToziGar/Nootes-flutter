import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

/// Servicio para gestionar comentarios en notas compartidas
class CommentService {
  static final CommentService _instance = CommentService._internal();
  factory CommentService() => _instance;
  CommentService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService.instance;

  /// Crea un nuevo comentario en una nota
  Future<String> createComment({
    required String noteId,
    required String ownerId,
    required String content,
    String? parentCommentId,
  }) async {
    final user = _authService.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    final commentData = {
      'noteId': noteId,
      'ownerId': ownerId,
      'authorId': user.uid,
      'authorEmail': user.email ?? 'Desconocido',
      'content': content,
      'parentCommentId': parentCommentId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isEdited': false,
      'isDeleted': false,
    };

    final docRef = await _firestore
        .collection('comments')
        .add(commentData);

    // Crear notificación para el propietario de la nota
    if (ownerId != user.uid) {
      try {
        await _firestore
            .collection('notifications')
            .add({
          'userId': ownerId,
          'type': 'commentAdded',
          'title': 'Nuevo comentario',
          'message': '${user.email} comentó en tu nota',
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
          'metadata': {
            'noteId': noteId,
            'commentId': docRef.id,
            'authorId': user.uid,
          },
        });
      } catch (e) {
        debugPrint('❌ Error creando notificación: $e');
      }
    }

    debugPrint('✅ Comentario creado: ${docRef.id}');
    return docRef.id;
  }

  /// Obtiene un stream de comentarios de una nota
  Stream<List<Comment>> getCommentsStream(String noteId) {
    return _firestore
        .collection('comments')
        .where('noteId', isEqualTo: noteId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Comment.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  /// Actualiza un comentario existente
  Future<void> updateComment(String commentId, String newContent) async {
    final user = _authService.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    await _firestore
        .collection('comments')
        .doc(commentId)
        .update({
      'content': newContent,
      'updatedAt': FieldValue.serverTimestamp(),
      'isEdited': true,
    });

    debugPrint('✅ Comentario actualizado: $commentId');
  }

  /// Elimina un comentario (soft delete)
  Future<void> deleteComment(String commentId) async {
    final user = _authService.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    await _firestore
        .collection('comments')
        .doc(commentId)
        .update({
      'isDeleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    debugPrint('✅ Comentario eliminado: $commentId');
  }

  /// Obtiene el número de comentarios de una nota
  Future<int> getCommentCount(String noteId) async {
    final snapshot = await _firestore
        .collection('comments')
        .where('noteId', isEqualTo: noteId)
        .where('isDeleted', isEqualTo: false)
        .count()
        .get();

    return snapshot.count ?? 0;
  }
}

/// Modelo de comentario
class Comment {
  final String id;
  final String noteId;
  final String ownerId;
  final String authorId;
  final String authorEmail;
  final String content;
  final String? parentCommentId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isEdited;
  final bool isDeleted;

  const Comment({
    required this.id,
    required this.noteId,
    required this.ownerId,
    required this.authorId,
    required this.authorEmail,
    required this.content,
    this.parentCommentId,
    required this.createdAt,
    required this.updatedAt,
    required this.isEdited,
    required this.isDeleted,
  });

  factory Comment.fromMap(String id, Map<String, dynamic> data) {
    return Comment(
      id: id,
      noteId: data['noteId'] ?? '',
      ownerId: data['ownerId'] ?? '',
      authorId: data['authorId'] ?? '',
      authorEmail: data['authorEmail'] ?? 'Desconocido',
      content: data['content'] ?? '',
      parentCommentId: data['parentCommentId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isEdited: data['isEdited'] ?? false,
      isDeleted: data['isDeleted'] ?? false,
    );
  }

  /// Obtiene texto de tiempo relativo
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      return 'Hace un momento';
    } else if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays}d';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }

  /// Verifica si el comentario es una respuesta
  bool get isReply => parentCommentId != null;
}
