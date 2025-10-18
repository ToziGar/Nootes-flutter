import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/debug.dart';
import '../services/auth_service.dart';
import '../services/exceptions/sharing_exceptions.dart';

/// Servicio mejorado para la gestión de notificaciones
class NotificationServiceEnhanced {
  static final NotificationServiceEnhanced _instance =
      NotificationServiceEnhanced._internal();
  factory NotificationServiceEnhanced() => _instance;
  NotificationServiceEnhanced._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService.instance;

  // Cache de notificaciones para mejor rendimiento
  final Map<String, List<NotificationItem>> _notificationCache = {};
  DateTime? _lastCacheUpdate;
  static const _cacheTimeout = Duration(minutes: 5);

  /// Inicializa el servicio de notificaciones mejorado
  Future<void> initialize() async {
    try {
      await _loadNotificationsFromCache();
      await _schedulePeriodicCleanup();
    } catch (e) {
      logDebug('Error inicializando NotificationServiceEnhanced: $e');
    }
  }

  /// Crea una notificación optimizada con validación mejorada
  Future<String> createNotification({
    required String title,
    required String message,
    required NotificationType type,
    String? noteId,
    String? targetUserId,
    DateTime? scheduledFor,
    Map<String, dynamic>? metadata,
    NotificationPriority priority = NotificationPriority.normal,
  }) async {
    final uid = targetUserId ?? _authService.currentUser?.uid;
    if (uid == null) {
      throw AuthenticationException('Usuario no autenticado');
    }

    // Validar datos de entrada
    _validateNotificationData(title, message, type);

    final notificationData = {
      'title': title.trim(),
      'message': message.trim(),
      'type': type.name,
      'noteId': noteId,
      'targetUserId': uid,
      'createdBy': _authService.currentUser?.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'scheduledFor': scheduledFor != null
          ? Timestamp.fromDate(scheduledFor)
          : null,
      'metadata': metadata ?? {},
      'priority': priority.name,
      'isRead': false,
      'isActive': true,
      'readAt': null,
      'expiresAt': _calculateExpirationDate(type, scheduledFor),
    };

    try {
      final docRef = await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .add(notificationData);

      // Invalidar cache para este usuario
      _invalidateCache(uid);

      // Programar notificación si es necesaria
      if (scheduledFor != null && scheduledFor.isAfter(DateTime.now())) {
        await _scheduleNotification(docRef.id, scheduledFor);
      }

      logDebug('✅ Notificación creada: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      logDebug('❌ Error creando notificación: $e');
      throw NetworkException();
    }
  }

  /// Obtiene notificaciones con cache inteligente
  Future<List<NotificationItem>> getNotifications({
    bool? unreadOnly,
    int limit = 50,
    NotificationPriority? priorityFilter,
    NotificationType? typeFilter,
    bool forceRefresh = false,
  }) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return [];

    // Verificar cache
    if (!forceRefresh && _isCacheValid(uid)) {
      final cached = _notificationCache[uid] ?? [];
      return _filterNotifications(
        cached,
        unreadOnly,
        priorityFilter,
        typeFilter,
        limit,
      );
    }

    try {
      Query query = _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true);

      if (typeFilter != null) {
        query = query.where('type', isEqualTo: typeFilter.name);
      }

      if (priorityFilter != null) {
        query = query.where('priority', isEqualTo: priorityFilter.name);
      }

      final snapshot = await query
          .limit(limit * 2)
          .get(); // Obtener más para filtrar

      final notifications = snapshot.docs
          .map((doc) {
            try {
              return NotificationItem.fromFirestore(doc);
            } catch (e) {
              logDebug('Error parseando notificación ${doc.id}: $e');
              return null;
            }
          })
          .where((notification) => notification != null)
          .cast<NotificationItem>()
          .toList();

      // Actualizar cache
      _notificationCache[uid] = notifications;
      _lastCacheUpdate = DateTime.now();

      return _filterNotifications(
        notifications,
        unreadOnly,
        priorityFilter,
        typeFilter,
        limit,
      );
    } catch (e) {
      logDebug('❌ Error obteniendo notificaciones: $e');
      return [];
    }
  }

  /// Marca notificaciones como leídas con operación batch optimizada
  Future<void> markAsRead(List<String> notificationIds) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null || notificationIds.isEmpty) return;

    try {
      final batch = _firestore.batch();
      final readTimestamp = FieldValue.serverTimestamp();

      for (final id in notificationIds) {
        final docRef = _firestore
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .doc(id);

        batch.update(docRef, {'isRead': true, 'readAt': readTimestamp});
      }

      await batch.commit();

      // Actualizar cache local
      _updateCacheReadStatus(uid, notificationIds, true);

      logDebug('✅ ${notificationIds.length} notificaciones marcadas como leídas');
    } catch (e) {
      logDebug('❌ Error marcando notificaciones como leídas: $e');
      throw NetworkException();
    }
  }

  /// Elimina notificaciones de forma segura
  Future<void> deleteNotifications(List<String> notificationIds) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null || notificationIds.isEmpty) return;

    try {
      final batch = _firestore.batch();

      for (final id in notificationIds) {
        final docRef = _firestore
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .doc(id);

        // Marcar como inactiva en lugar de eliminar físicamente
        batch.update(docRef, {
          'isActive': false,
          'deletedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      // Invalidar cache
      _invalidateCache(uid);

  logDebug('✅ ${notificationIds.length} notificaciones eliminadas');
    } catch (e) {
  logDebug('❌ Error eliminando notificaciones: $e');
      throw NetworkException();
    }
  }

  /// Obtiene estadísticas detalladas de notificaciones
  Future<NotificationStats> getNotificationStats() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      return NotificationStats(
        total: 0,
        unread: 0,
        byType: {},
        byPriority: {},
        thisWeek: 0,
        thisMonth: 0,
      );
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('isActive', isEqualTo: true)
          .get();

      final notifications = snapshot.docs;
      final now = DateTime.now();
      final weekAgo = now.subtract(Duration(days: 7));
      final monthAgo = now.subtract(Duration(days: 30));

      final Map<String, int> byType = {};
      final Map<String, int> byPriority = {};
      int thisWeek = 0;
      int thisMonth = 0;

      for (final doc in notifications) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

        // Contar por tipo
        final type = data['type'] as String? ?? 'unknown';
        byType[type] = (byType[type] ?? 0) + 1;

        // Contar por prioridad
        final priority = data['priority'] as String? ?? 'normal';
        byPriority[priority] = (byPriority[priority] ?? 0) + 1;

        // Contar por tiempo
        if (createdAt != null) {
          if (createdAt.isAfter(weekAgo)) thisWeek++;
          if (createdAt.isAfter(monthAgo)) thisMonth++;
        }
      }

      return NotificationStats(
        total: notifications.length,
        unread: notifications
            .where((doc) => doc.data()['isRead'] == false)
            .length,
        byType: byType,
        byPriority: byPriority,
        thisWeek: thisWeek,
        thisMonth: thisMonth,
      );
    } catch (e) {
      logDebug('❌ Error obteniendo estadísticas: $e');
      return NotificationStats(
        total: 0,
        unread: 0,
        byType: {},
        byPriority: {},
        thisWeek: 0,
        thisMonth: 0,
      );
    }
  }

  /// Limpia notificaciones antiguas automáticamente
  Future<void> cleanupOldNotifications({int daysOld = 90}) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('createdAt', isLessThan: Timestamp.fromDate(cutoffDate))
          .where('isActive', isEqualTo: false)
          .limit(100) // Procesar en lotes
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      logDebug('✅ ${snapshot.docs.length} notificaciones antiguas eliminadas');
    } catch (e) {
      logDebug('❌ Error limpiando notificaciones: $e');
    }
  }

  // Métodos privados de ayuda
  void _validateNotificationData(
    String title,
    String message,
    NotificationType type,
  ) {
    if (title.trim().isEmpty) {
      throw ValidationException('El título no puede estar vacío');
    }
    if (message.trim().isEmpty) {
      throw ValidationException('El mensaje no puede estar vacío');
    }
    if (title.length > 100) {
      throw ValidationException('El título no puede exceder 100 caracteres');
    }
    if (message.length > 500) {
      throw ValidationException('El mensaje no puede exceder 500 caracteres');
    }
  }

  bool _isCacheValid(String uid) {
    if (_lastCacheUpdate == null || !_notificationCache.containsKey(uid)) {
      return false;
    }
    return DateTime.now().difference(_lastCacheUpdate!) < _cacheTimeout;
  }

  void _invalidateCache(String uid) {
    _notificationCache.remove(uid);
    _lastCacheUpdate = null;
  }

  void _updateCacheReadStatus(
    String uid,
    List<String> notificationIds,
    bool isRead,
  ) {
    final cached = _notificationCache[uid];
    if (cached == null) return;

    for (final notification in cached) {
      if (notificationIds.contains(notification.id)) {
        // Crear nueva instancia con estado actualizado
        final index = cached.indexOf(notification);
        cached[index] = notification.copyWith(
          isRead: isRead,
          readAt: DateTime.now(),
        );
      }
    }
  }

  List<NotificationItem> _filterNotifications(
    List<NotificationItem> notifications,
    bool? unreadOnly,
    NotificationPriority? priorityFilter,
    NotificationType? typeFilter,
    int limit,
  ) {
    var filtered = notifications.where((notification) {
      if (unreadOnly == true && notification.isRead) return false;
      if (priorityFilter != null && notification.priority != priorityFilter) {
        return false;
      }
      if (typeFilter != null && notification.type != typeFilter) return false;
      return true;
    }).toList();

    return filtered.take(limit).toList();
  }

  Timestamp? _calculateExpirationDate(
    NotificationType type,
    DateTime? scheduledFor,
  ) {
    DateTime expiration;

    switch (type) {
      case NotificationType.reminder:
        expiration = (scheduledFor ?? DateTime.now()).add(Duration(days: 7));
        break;
      case NotificationType.shareExpiring:
        expiration = DateTime.now().add(Duration(days: 3));
        break;
      default:
        expiration = DateTime.now().add(Duration(days: 30));
    }

    return Timestamp.fromDate(expiration);
  }

  Future<void> _loadNotificationsFromCache() async {
    // Implementar carga desde cache persistente si es necesario
  }

  Future<void> _schedulePeriodicCleanup() async {
    // Programar limpieza automática
    await cleanupOldNotifications();
  }

  Future<void> _scheduleNotification(
    String notificationId,
    DateTime scheduledFor,
  ) async {
    // Implementar programación de notificaciones push
  logDebug('📅 Notificación programada para: $scheduledFor');
  }

  /// Limpia recursos del servicio
  void dispose() {
    _notificationCache.clear();
  }
}

/// Prioridades de notificaciones
enum NotificationPriority { low, normal, high, urgent }

/// Tipos mejorados de notificaciones
enum NotificationType {
  reminder,
  newShare,
  shareAccepted,
  shareRejected,
  shareRevoked,
  shareExpiring,
  shareLeft,
  commentAdded,
  noteUpdated,
  systemAlert,
  featureUpdate,
}

/// Modelo mejorado para elementos de notificación
class NotificationItem {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final NotificationPriority priority;
  final String? noteId;
  final String? targetUserId;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? scheduledFor;
  final DateTime? readAt;
  final DateTime? expiresAt;
  final bool isRead;
  final bool isActive;
  final Map<String, dynamic> metadata;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.priority,
    this.noteId,
    this.targetUserId,
    this.createdBy,
    required this.createdAt,
    this.scheduledFor,
    this.readAt,
    this.expiresAt,
    required this.isRead,
    required this.isActive,
    this.metadata = const {},
  });

  factory NotificationItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return NotificationItem(
      id: doc.id,
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: _parseNotificationType(data['type']),
      priority: _parseNotificationPriority(data['priority']),
      noteId: data['noteId'],
      targetUserId: data['targetUserId'],
      createdBy: data['createdBy'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      scheduledFor: (data['scheduledFor'] as Timestamp?)?.toDate(),
      readAt: (data['readAt'] as Timestamp?)?.toDate(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      isRead: data['isRead'] ?? false,
      isActive: data['isActive'] ?? true,
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  static NotificationType _parseNotificationType(String? type) {
    try {
      return NotificationType.values.firstWhere((e) => e.name == type);
    } catch (e) {
      return NotificationType.systemAlert;
    }
  }

  static NotificationPriority _parseNotificationPriority(String? priority) {
    try {
      return NotificationPriority.values.firstWhere((e) => e.name == priority);
    } catch (e) {
      return NotificationPriority.normal;
    }
  }

  NotificationItem copyWith({
    String? title,
    String? message,
    NotificationType? type,
    NotificationPriority? priority,
    String? noteId,
    DateTime? readAt,
    bool? isRead,
    bool? isActive,
    Map<String, dynamic>? metadata,
  }) {
    return NotificationItem(
      id: id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      noteId: noteId ?? this.noteId,
      targetUserId: targetUserId,
      createdBy: createdBy,
      createdAt: createdAt,
      scheduledFor: scheduledFor,
      readAt: readAt ?? this.readAt,
      expiresAt: expiresAt,
      isRead: isRead ?? this.isRead,
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type.name,
      'priority': priority.name,
      'noteId': noteId,
      'targetUserId': targetUserId,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'scheduledFor': scheduledFor?.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'isRead': isRead,
      'isActive': isActive,
      'metadata': metadata,
    };
  }
}

/// Estadísticas de notificaciones
class NotificationStats {
  final int total;
  final int unread;
  final Map<String, int> byType;
  final Map<String, int> byPriority;
  final int thisWeek;
  final int thisMonth;

  const NotificationStats({
    required this.total,
    required this.unread,
    required this.byType,
    required this.byPriority,
    required this.thisWeek,
    required this.thisMonth,
  });

  double get readPercentage => total > 0 ? ((total - unread) / total) * 100 : 0;

  Map<String, dynamic> toJson() {
    return {
      'total': total,
      'unread': unread,
      'byType': byType,
      'byPriority': byPriority,
      'thisWeek': thisWeek,
      'thisMonth': thisMonth,
      'readPercentage': readPercentage,
    };
  }
}
