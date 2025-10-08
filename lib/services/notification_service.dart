import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

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
        .orderBy('reminderTime', descending: false)
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
      );
    }).toList();
  }
  
  /// Carga notificaciones pendientes
  Future<void> _loadPendingNotifications() async {
    _pendingNotifications = await getNotifications();
    _pendingNotifications = _pendingNotifications
        .where((notification) => notification.reminderTime.isAfter(DateTime.now()))
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
        .where((notification) => 
            notification.reminderTime.isBefore(now) || 
            notification.reminderTime.isAtSameMomentAs(now))
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
    print('🔔 Notificación: ${notification.message}');
    
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
    int active = snapshot.docs.where((doc) => doc.data()['isActive'] == true).length;
    int completed = total - active;
    
    return {
      'total': total,
      'active': active,
      'completed': completed,
    };
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
  
  const NotificationItem({
    required this.id,
    required this.noteId,
    required this.noteTitle,
    required this.message,
    required this.reminderTime,
    required this.type,
    required this.isActive,
  });
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
        return ListTile(
          leading: Icon(
            notification.type == 'reminder' 
                ? Icons.alarm 
                : Icons.notifications,
            color: Theme.of(context).primaryColor,
          ),
          title: Text(notification.noteTitle),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(notification.message),
              Text(
                'Programado para: ${notification.reminderTime.toString().substring(0, 16)}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.cancel),
            onPressed: () async {
              await _notificationService.cancelReminder(notification.id);
              _loadNotifications();
            },
          ),
        );
      },
    );
  }
}