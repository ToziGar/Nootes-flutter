import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

/// Tipos de actividad en notas compartidas
enum ActivityType {
  noteCreated,
  noteEdited,
  noteOpened,
  commentAdded,
  commentEdited,
  commentDeleted,
  userJoined,
  userLeft,
  permissionChanged,
}

/// Servicio para registrar y consultar historial de actividad
class ActivityLogService {
  static final ActivityLogService _instance = ActivityLogService._internal();
  factory ActivityLogService() => _instance;
  ActivityLogService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService.instance;

  /// Registra una actividad en una nota
  Future<void> logActivity({
    required String noteId,
    required String ownerId,
    required ActivityType type,
    Map<String, dynamic>? metadata,
  }) async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(ownerId)
          .collection('notes')
          .doc(noteId)
          .collection('activity')
          .add({
        'userId': user.uid,
        'userEmail': user.email ?? 'Desconocido',
        'type': type.name,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': metadata ?? {},
      });

      debugPrint('✅ Actividad registrada: ${type.name}');
    } catch (e) {
      debugPrint('❌ Error registrando actividad: $e');
    }
  }

  /// Obtiene un stream del historial de actividad de una nota
  Stream<List<ActivityLog>> getActivityStream(String noteId, String ownerId) {
    return _firestore
        .collection('users')
        .doc(ownerId)
        .collection('notes')
        .doc(noteId)
        .collection('activity')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ActivityLog.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  /// Obtiene el historial de actividad (snapshot único)
  Future<List<ActivityLog>> getActivityHistory(String noteId, String ownerId, {int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(ownerId)
          .collection('notes')
          .doc(noteId)
          .collection('activity')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        return ActivityLog.fromMap(doc.id, doc.data());
      }).toList();
    } catch (e) {
      debugPrint('❌ Error obteniendo historial: $e');
      return [];
    }
  }

  /// Limpia el historial antiguo (más de 30 días)
  Future<void> cleanOldActivity(String noteId, String ownerId) async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final snapshot = await _firestore
          .collection('users')
          .doc(ownerId)
          .collection('notes')
          .doc(noteId)
          .collection('activity')
          .where('timestamp', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      debugPrint('✅ Limpiado historial antiguo: ${snapshot.docs.length} entradas');
    } catch (e) {
      debugPrint('❌ Error limpiando historial: $e');
    }
  }
}

/// Modelo de entrada de actividad
class ActivityLog {
  final String id;
  final String userId;
  final String userEmail;
  final ActivityType type;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  const ActivityLog({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.type,
    required this.timestamp,
    required this.metadata,
  });

  factory ActivityLog.fromMap(String id, Map<String, dynamic> data) {
    final typeString = data['type'] as String? ?? 'noteEdited';
    final type = ActivityType.values.firstWhere(
      (e) => e.name == typeString,
      orElse: () => ActivityType.noteEdited,
    );

    return ActivityLog(
      id: id,
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? 'Desconocido',
      type: type,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: data['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Obtiene el icono según el tipo de actividad
  IconData get icon {
    switch (type) {
      case ActivityType.noteCreated:
        return Icons.add_circle_rounded;
      case ActivityType.noteEdited:
        return Icons.edit_rounded;
      case ActivityType.noteOpened:
        return Icons.visibility_rounded;
      case ActivityType.commentAdded:
        return Icons.comment_rounded;
      case ActivityType.commentEdited:
        return Icons.edit_note_rounded;
      case ActivityType.commentDeleted:
        return Icons.delete_rounded;
      case ActivityType.userJoined:
        return Icons.person_add_rounded;
      case ActivityType.userLeft:
        return Icons.person_remove_rounded;
      case ActivityType.permissionChanged:
        return Icons.security_rounded;
    }
  }

  /// Obtiene el color según el tipo de actividad
  Color get color {
    switch (type) {
      case ActivityType.noteCreated:
        return Colors.green;
      case ActivityType.noteEdited:
        return Colors.blue;
      case ActivityType.noteOpened:
        return Colors.purple;
      case ActivityType.commentAdded:
        return Colors.indigo;
      case ActivityType.commentEdited:
        return Colors.orange;
      case ActivityType.commentDeleted:
        return Colors.red;
      case ActivityType.userJoined:
        return Colors.teal;
      case ActivityType.userLeft:
        return Colors.grey;
      case ActivityType.permissionChanged:
        return Colors.amber;
    }
  }

  /// Obtiene el título de la actividad
  String get title {
    switch (type) {
      case ActivityType.noteCreated:
        return 'Nota creada';
      case ActivityType.noteEdited:
        return 'Nota editada';
      case ActivityType.noteOpened:
        return 'Nota abierta';
      case ActivityType.commentAdded:
        return 'Comentario añadido';
      case ActivityType.commentEdited:
        return 'Comentario editado';
      case ActivityType.commentDeleted:
        return 'Comentario eliminado';
      case ActivityType.userJoined:
        return 'Usuario unido';
      case ActivityType.userLeft:
        return 'Usuario salió';
      case ActivityType.permissionChanged:
        return 'Permisos modificados';
    }
  }

  /// Obtiene la descripción de la actividad
  String get description {
    final email = userEmail;
    
    switch (type) {
      case ActivityType.noteCreated:
        return '$email creó esta nota';
      case ActivityType.noteEdited:
        final changes = metadata['changes'] as int? ?? 0;
        return '$email realizó $changes cambio${changes != 1 ? 's' : ''}';
      case ActivityType.noteOpened:
        return '$email abrió la nota';
      case ActivityType.commentAdded:
        return '$email añadió un comentario';
      case ActivityType.commentEdited:
        return '$email editó un comentario';
      case ActivityType.commentDeleted:
        return '$email eliminó un comentario';
      case ActivityType.userJoined:
        return '$email se unió a la colaboración';
      case ActivityType.userLeft:
        return '$email dejó de colaborar';
      case ActivityType.permissionChanged:
        final newPermission = metadata['newPermission'] as String? ?? 'read';
        return '$email cambió permisos a "$newPermission"';
    }
  }

  /// Obtiene texto de tiempo relativo
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Hace un momento';
    } else if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays}d';
    } else if (difference.inDays < 30) {
      return 'Hace ${(difference.inDays / 7).floor()} semana${(difference.inDays / 7).floor() > 1 ? 's' : ''}';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}
