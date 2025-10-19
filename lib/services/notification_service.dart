import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/sharing_service.dart';
import '../services/toast_service.dart';
import '../utils/debug.dart';

enum NotificationType {
  reminder,
  newShare,
  shareAccepted,
  shareRejected,
  shareRevoked,
  shareReminder,
  shareExpiring,
  shareLeft,
}

/// Servicio para manejar notificaciones y recordatorios de notas
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService.instance;

  Timer? _reminderTimer;
  List<NotificationItem> _pendingNotifications = [];

  /// Inicializa el servicio de notificaciones
  Future<void> initialize() async {
    await _loadPendingNotifications();
    _startReminderTimer();
  }

  /// Programa un recordatorio para una nota
  Future<void> scheduleReminder({
    required String noteId,
    required String noteTitle,
    required DateTime reminderTime,
    String? message,
  }) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    final notification = {
      'noteId': noteId,
      'noteTitle': noteTitle,
      'message': message ?? 'Recordatorio: $noteTitle',
      'reminderTime': Timestamp.fromDate(reminderTime),
      'type': 'reminder',
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .add(notification);

    await _loadPendingNotifications();
  }

  /// Programa una notificación de seguimiento
  Future<void> scheduleFollowUp({
    required String noteId,
    required String noteTitle,
    required Duration delay,
    String? message,
  }) async {
    final reminderTime = DateTime.now().add(delay);
    await scheduleReminder(
      noteId: noteId,
      noteTitle: noteTitle,
      reminderTime: reminderTime,
      message: message ?? 'Seguimiento: $noteTitle',
    );
  }

  /// Cancela un recordatorio
  Future<void> cancelReminder(String notificationId) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'isActive': false});

    await _loadPendingNotifications();
  }

  /// Obtiene todas las notificaciones del usuario
  Future<List<NotificationItem>> getNotifications() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('isActive', isEqualTo: true)
        .orderBy('reminderTime', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return NotificationItem(
        id: doc.id,
        noteId: data['noteId'] ?? '',
        noteTitle: data['noteTitle'] ?? '',
        message: data['message'] ?? '',
        reminderTime: (data['reminderTime'] as Timestamp).toDate(),
        type: data['type'] ?? 'reminder',
        isActive: data['isActive'] ?? true,
        metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
        shareId: data['shareId'],
        isRead: data['isRead'] ?? false,
      );
    }).toList();
  }

  /// Carga notificaciones pendientes
  Future<void> _loadPendingNotifications() async {
    _pendingNotifications = await getNotifications();
    _pendingNotifications = _pendingNotifications
        .where(
          (notification) => notification.reminderTime.isAfter(DateTime.now()),
        )
        .toList();
  }

  /// Inicia el timer para verificar recordatorios
  void _startReminderTimer() {
    _reminderTimer?.cancel();
    _reminderTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkReminders();
    });
  }

  /// Verifica si hay recordatorios listos para mostrar
  void _checkReminders() {
    final now = DateTime.now();
    final readyNotifications = _pendingNotifications
        .where(
          (notification) =>
              notification.reminderTime.isBefore(now) ||
              notification.reminderTime.isAtSameMomentAs(now),
        )
        .toList();

    for (final notification in readyNotifications) {
      _showNotification(notification);
      _pendingNotifications.remove(notification);
    }
  }

  /// Muestra una notificación
  void _showNotification(NotificationItem notification) {
    // En una app web, podríamos usar la API de notificaciones del navegador
    // Por ahora, mostraremos un SnackBar
    logDebug('🔔 Notificación: ${notification.message}');

    // TODO: Implementar notificaciones nativas del navegador
    // if (kIsWeb) {
    //   _showBrowserNotification(notification);
    // }
  }

  /// Obtiene estadísticas de notificaciones
  Future<Map<String, int>> getNotificationStats() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return {};

    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .get();

    int total = snapshot.docs.length;
    int active = snapshot.docs
        .where((doc) => doc.data()['isActive'] == true)
        .length;
    int completed = total - active;

    return {'total': total, 'active': active, 'completed': completed};
  }

  /// Limpia notificaciones antiguas (más de 30 días)
  Future<void> cleanupOldNotifications() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('reminderTime', isLessThan: Timestamp.fromDate(cutoffDate))
        .where('isActive', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Detiene el servicio
  void dispose() {
    _reminderTimer?.cancel();
  }

  // ============================================================================
  // MÉTODOS PARA NOTIFICACIONES DE COMPARTICIÓN
  // ============================================================================

  /// Crear notificación de compartición
  Future<void> createShareNotification({
    required String userId,
    required NotificationType type,
    required String title,
    required String message,
    Map<String, dynamic>? metadata,
    String? shareId,
  }) async {
    final notification = {
      'noteId': shareId ?? '',
      'noteTitle': title,
      'message': message,
      'reminderTime': Timestamp.fromDate(DateTime.now()),
      'type': type.name,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'metadata': metadata ?? {},
      'shareId': shareId,
      'isRead': false,
    };

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .add(notification);

    // Si es para el usuario actual, mostrar toast
    if (userId == _authService.currentUser?.uid) {
      _showShareNotificationToast(type, title, message);
    }
  }

  /// Nueva compartición recibida
  Future<void> notifyNewShare({
    required String recipientId,
    required String senderName,
    required String senderEmail,
    required String itemTitle,
    required String shareId,
    required SharedItemType itemType,
  }) async {
    final itemTypeText = itemType == SharedItemType.note ? 'nota' : 'carpeta';

    await createShareNotification(
      userId: recipientId,
      type: NotificationType.newShare,
      title: '📝 Nueva $itemTypeText compartida',
      message: '$senderName ($senderEmail) te ha compartido "$itemTitle"',
      metadata: {
        'senderName': senderName,
        'senderEmail': senderEmail,
        'itemTitle': itemTitle,
        'itemType': itemType.name,
      },
      shareId: shareId,
    );
  }

  /// Compartición aceptada
  Future<void> notifyShareAccepted({
    required String ownerId,
    required String recipientName,
    required String recipientEmail,
    required String itemTitle,
    required String shareId,
  }) async {
    await createShareNotification(
      userId: ownerId,
      type: NotificationType.shareAccepted,
      title: '✅ Compartición aceptada',
      message:
          '$recipientName ($recipientEmail) ha aceptado tu compartición de "$itemTitle"',
      metadata: {
        'recipientName': recipientName,
        'recipientEmail': recipientEmail,
        'itemTitle': itemTitle,
      },
      shareId: shareId,
    );
  }

  /// Compartición rechazada
  Future<void> notifyShareRejected({
    required String ownerId,
    required String recipientName,
    required String recipientEmail,
    required String itemTitle,
    required String shareId,
  }) async {
    await createShareNotification(
      userId: ownerId,
      type: NotificationType.shareRejected,
      title: '❌ Compartición rechazada',
      message:
          '$recipientName ($recipientEmail) ha rechazado tu compartición de "$itemTitle"',
      metadata: {
        'recipientName': recipientName,
        'recipientEmail': recipientEmail,
        'itemTitle': itemTitle,
      },
      shareId: shareId,
    );
  }

  /// Compartición revocada
  Future<void> notifyShareRevoked({
    required String recipientId,
    required String ownerName,
    required String itemTitle,
    required String shareId,
  }) async {
    await createShareNotification(
      userId: recipientId,
      type: NotificationType.shareRevoked,
      title: '🚫 Acceso revocado',
      message: '$ownerName ha revocado tu acceso a "$itemTitle"',
      metadata: {'ownerName': ownerName, 'itemTitle': itemTitle},
      shareId: shareId,
    );
  }

  /// Receptor salió de la compartición
  Future<void> notifyShareLeft({
    required String ownerId,
    required String recipientName,
    required String recipientEmail,
    required String itemTitle,
    required String shareId,
  }) async {
    await createShareNotification(
      userId: ownerId,
      type: NotificationType.shareLeft,
      title: '👋 Acceso abandonado',
      message:
          '$recipientName ($recipientEmail) se salió de la compartición de "$itemTitle"',
      metadata: {
        'recipientName': recipientName,
        'recipientEmail': recipientEmail,
        'itemTitle': itemTitle,
      },
      shareId: shareId,
    );
  }

  /// Recordatorio de comparticiones pendientes
  Future<void> notifyPendingReminder({
    required String recipientId,
    required String itemTitle,
    required String shareId,
    required int daysPending,
  }) async {
    await createShareNotification(
      userId: recipientId,
      type: NotificationType.shareReminder,
      title: '⏰ Recordatorio',
      message:
          'Tienes una compartición pendiente de "$itemTitle" desde hace $daysPending días',
      metadata: {'itemTitle': itemTitle, 'daysPending': daysPending},
      shareId: shareId,
    );
  }

  /// Enlace próximo a expirar
  Future<void> notifyShareExpiring({
    required String ownerId,
    required String itemTitle,
    required String shareId,
    required int daysUntilExpiration,
  }) async {
    await createShareNotification(
      userId: ownerId,
      type: NotificationType.shareExpiring,
      title: '⚠️ Enlace próximo a expirar',
      message:
          'Tu compartición de "$itemTitle" expirará en $daysUntilExpiration días',
      metadata: {
        'itemTitle': itemTitle,
        'daysUntilExpiration': daysUntilExpiration,
      },
      shareId: shareId,
    );
  }

  /// Marcar notificación como leída
  Future<void> markAsRead(String notificationId) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  /// Marcar todas las notificaciones como leídas
  Future<void> markAllAsRead() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    try {
      final unreadNotifications = await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .where('isActive', isEqualTo: true)
          .get();

      final batch = _firestore.batch();
      for (final doc in unreadNotifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      logDebug('Error marking all notifications as read: $e');
    }
  }

  /// Contar notificaciones no leídas
  Stream<int> getUnreadCount() {
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      return Stream.value(0);
    }

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Mostrar toast para notificaciones de compartición
  void _showShareNotificationToast(
    NotificationType type,
    String title,
    String message,
  ) {
    switch (type) {
      case NotificationType.newShare:
        ToastService.info('$title\n$message');
        break;
      case NotificationType.shareAccepted:
        ToastService.success('$title\n$message');
        break;
      case NotificationType.shareRejected:
        ToastService.warning('$title\n$message');
        break;
      case NotificationType.shareRevoked:
        ToastService.warning('$title\n$message');
        break;
      case NotificationType.shareReminder:
        ToastService.info('$title\n$message');
        break;
      case NotificationType.shareExpiring:
        ToastService.warning('$title\n$message');
        break;
      case NotificationType.shareLeft:
        ToastService.info('$title\n$message');
        break;
      case NotificationType.reminder:
        // Para recordatorios normales
        break;
    }
  }
}

/// Clase para representar una notificación
class NotificationItem {
  final String id;
  final String noteId;
  final String noteTitle;
  final String message;
  final DateTime reminderTime;
  final String type;
  final bool isActive;
  final Map<String, dynamic> metadata;
  final String? shareId;
  final bool isRead;

  const NotificationItem({
    required this.id,
    required this.noteId,
    required this.noteTitle,
    required this.message,
    required this.reminderTime,
    required this.type,
    required this.isActive,
    this.metadata = const {},
    this.shareId,
    this.isRead = false,
  });

  NotificationType get notificationType {
    return NotificationType.values.firstWhere(
      (e) => e.name == type,
      orElse: () => NotificationType.reminder,
    );
  }

  IconData get icon {
    switch (notificationType) {
      case NotificationType.reminder:
        return Icons.alarm;
      case NotificationType.newShare:
        return Icons.share_rounded;
      case NotificationType.shareAccepted:
        return Icons.check_circle_rounded;
      case NotificationType.shareRejected:
        return Icons.cancel_rounded;
      case NotificationType.shareRevoked:
        return Icons.block_rounded;
      case NotificationType.shareReminder:
        return Icons.schedule_rounded;
      case NotificationType.shareExpiring:
        return Icons.warning_rounded;
      case NotificationType.shareLeft:
        return Icons.logout_rounded;
    }
  }

  Color get color {
    switch (notificationType) {
      case NotificationType.reminder:
        return Colors.blue;
      case NotificationType.newShare:
        return Colors.blue;
      case NotificationType.shareAccepted:
        return Colors.green;
      case NotificationType.shareRejected:
        return Colors.red;
      case NotificationType.shareRevoked:
        return Colors.orange;
      case NotificationType.shareReminder:
        return Colors.amber;
      case NotificationType.shareExpiring:
        return Colors.deepOrange;
      case NotificationType.shareLeft:
        return Colors.grey;
    }
  }
}

/// Widget para mostrar notificaciones
class NotificationsList extends StatefulWidget {
  const NotificationsList({super.key});

  @override
  State<NotificationsList> createState() => _NotificationsListState();
}

class _NotificationsListState extends State<NotificationsList> {
  final NotificationService _notificationService = NotificationService();
  List<NotificationItem> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final notifications = await _notificationService.getNotifications();
    if (mounted) {
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_notifications.isEmpty) {
      return const Center(
        child: Text(
          'No tienes notificaciones pendientes',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        final isShare =
            notification.notificationType != NotificationType.reminder;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: notification.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                notification.icon,
                color: notification.color,
                size: 24,
              ),
            ),
            title: Text(
              notification.noteTitle,
              style: TextStyle(
                fontWeight: notification.isRead
                    ? FontWeight.normal
                    : FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notification.message),
                const SizedBox(height: 4),
                Text(
                  isShare
                      ? _formatShareDate(notification.reminderTime)
                      : 'Programado para: ${notification.reminderTime.toString().substring(0, 16)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!notification.isRead)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: notification.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                const SizedBox(width: 8),
                if (isShare && notification.shareId != null)
                  IconButton(
                    icon: const Icon(Icons.open_in_new),
                    onPressed: () {
                      // Navegar a la nota compartida
                      Navigator.of(context).pushNamed('/shared-notes');
                      // Marcar como leída
                      _notificationService.markAsRead(notification.id);
                      _loadNotifications();
                    },
                    tooltip: 'Abrir notas compartidas',
                  ),
                IconButton(
                  icon: const Icon(Icons.cancel),
                  onPressed: () async {
                    await _notificationService.cancelReminder(notification.id);
                    _loadNotifications();
                  },
                  tooltip: 'Eliminar notificación',
                ),
              ],
            ),
            onTap: () async {
              if (!notification.isRead) {
                await _notificationService.markAsRead(notification.id);
                _loadNotifications();
              }
            },
          ),
        );
      },
    );
  }

  String _formatShareDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Hoy';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} días atrás';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
