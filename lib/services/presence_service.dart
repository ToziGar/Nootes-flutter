import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

/// Servicio para gestionar la presencia en línea de usuarios en tiempo real
class PresenceService {
  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;
  PresenceService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService.instance;
  
  Timer? _heartbeatTimer;
  bool _isInitialized = false;

  /// Inicializa el servicio de presencia
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    final user = _authService.currentUser;
    if (user == null) return;

    // Marcar como en línea al iniciar
    await _setOnlineStatus(true);

    // Iniciar heartbeat cada 30 segundos
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateHeartbeat();
    });

    _isInitialized = true;
    debugPrint('✅ PresenceService: Inicializado para usuario ${user.uid}');
  }

  /// Actualiza el heartbeat del usuario
  Future<void> _updateHeartbeat() async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({
        'lastSeen': FieldValue.serverTimestamp(),
        'isOnline': true,
      });
    } catch (e) {
      debugPrint('❌ PresenceService: Error actualizando heartbeat - $e');
    }
  }

  /// Establece el estado en línea del usuario
  Future<void> _setOnlineStatus(bool isOnline) async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('✅ PresenceService: Estado en línea actualizado a $isOnline');
    } catch (e) {
      debugPrint('❌ PresenceService: Error estableciendo estado en línea - $e');
    }
  }

  /// Obtiene un stream del estado de presencia de un usuario
  Stream<UserPresence> getUserPresenceStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        return UserPresence(
          userId: userId,
          isOnline: false,
          lastSeen: DateTime.now(),
        );
      }

      final data = doc.data()!;
      final lastSeenTimestamp = data['lastSeen'] as Timestamp?;
      final lastSeen = lastSeenTimestamp?.toDate() ?? DateTime.now();
      final isOnline = data['isOnline'] as bool? ?? false;

      // Considerar offline si no hay heartbeat en los últimos 60 segundos
      final now = DateTime.now();
      final isActuallyOnline = isOnline && 
          now.difference(lastSeen).inSeconds < 60;

      return UserPresence(
        userId: userId,
        isOnline: isActuallyOnline,
        lastSeen: lastSeen,
      );
    });
  }

  /// Obtiene el estado de presencia de un usuario (snapshot único)
  Future<UserPresence> getUserPresence(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (!doc.exists) {
        return UserPresence(
          userId: userId,
          isOnline: false,
          lastSeen: DateTime.now(),
        );
      }

      final data = doc.data()!;
      final lastSeenTimestamp = data['lastSeen'] as Timestamp?;
      final lastSeen = lastSeenTimestamp?.toDate() ?? DateTime.now();
      final isOnline = data['isOnline'] as bool? ?? false;

      // Considerar offline si no hay heartbeat en los últimos 60 segundos
      final now = DateTime.now();
      final isActuallyOnline = isOnline && 
          now.difference(lastSeen).inSeconds < 60;

      return UserPresence(
        userId: userId,
        isOnline: isActuallyOnline,
        lastSeen: lastSeen,
      );
    } catch (e) {
      debugPrint('❌ PresenceService: Error obteniendo presencia - $e');
      return UserPresence(
        userId: userId,
        isOnline: false,
        lastSeen: DateTime.now(),
      );
    }
  }

  /// Obtiene el estado de presencia de múltiples usuarios
  Future<Map<String, UserPresence>> getMultipleUserPresence(List<String> userIds) async {
    final Map<String, UserPresence> presenceMap = {};
    
    try {
      // Firestore tiene límite de 10 para "in" queries, así que dividimos
      for (int i = 0; i < userIds.length; i += 10) {
        final batch = userIds.skip(i).take(10).toList();
        
        final querySnapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (final doc in querySnapshot.docs) {
          final data = doc.data();
          final lastSeenTimestamp = data['lastSeen'] as Timestamp?;
          final lastSeen = lastSeenTimestamp?.toDate() ?? DateTime.now();
          final isOnline = data['isOnline'] as bool? ?? false;

          final now = DateTime.now();
          final isActuallyOnline = isOnline && 
              now.difference(lastSeen).inSeconds < 60;

          presenceMap[doc.id] = UserPresence(
            userId: doc.id,
            isOnline: isActuallyOnline,
            lastSeen: lastSeen,
          );
        }
      }

      // Llenar usuarios que no se encontraron
      for (final userId in userIds) {
        if (!presenceMap.containsKey(userId)) {
          presenceMap[userId] = UserPresence(
            userId: userId,
            isOnline: false,
            lastSeen: DateTime.now(),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ PresenceService: Error obteniendo presencias múltiples - $e');
    }

    return presenceMap;
  }

  /// Marca al usuario como offline (llamar al cerrar sesión o salir de la app)
  Future<void> goOffline() async {
    await _setOnlineStatus(false);
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _isInitialized = false;
    debugPrint('✅ PresenceService: Usuario marcado como offline');
  }

  /// Marca al usuario como online (llamar al iniciar sesión o volver a la app)
  Future<void> goOnline() async {
    if (!_isInitialized) {
      await initialize();
    } else {
      await _setOnlineStatus(true);
    }
  }

  /// Limpia el servicio
  void dispose() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _isInitialized = false;
  }
}

/// Modelo para el estado de presencia de un usuario
class UserPresence {
  final String userId;
  final bool isOnline;
  final DateTime lastSeen;

  const UserPresence({
    required this.userId,
    required this.isOnline,
    required this.lastSeen,
  });

  /// Obtiene texto legible del estado de presencia
  String get statusText {
    if (isOnline) {
      return 'En línea';
    }

    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return 'Visto hace un momento';
    } else if (difference.inMinutes < 60) {
      return 'Visto hace ${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return 'Visto hace ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Visto hace ${difference.inDays}d';
    } else {
      return 'Visto hace mucho tiempo';
    }
  }

  /// Color del indicador de presencia
  Color get indicatorColor {
    return isOnline ? Colors.green : Colors.grey;
  }

  /// Icono del indicador de presencia
  IconData get indicatorIcon {
    return isOnline ? Icons.circle : Icons.circle_outlined;
  }
}

/// Widget para mostrar el indicador de presencia
class PresenceIndicator extends StatelessWidget {
  final String userId;
  final double size;
  final bool showText;

  const PresenceIndicator({
    super.key,
    required this.userId,
    this.size = 12,
    this.showText = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserPresence>(
      stream: PresenceService().getUserPresenceStream(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        final presence = snapshot.data!;

        if (showText) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: presence.indicatorColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: size * 0.15,
                  ),
                  boxShadow: presence.isOnline ? [
                    BoxShadow(
                      color: presence.indicatorColor.withOpacity(0.4),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ] : [],
                ),
              ),
              SizedBox(width: 8),
              Text(
                presence.statusText,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          );
        }

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: presence.indicatorColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: size * 0.15,
            ),
            boxShadow: presence.isOnline ? [
              BoxShadow(
                color: presence.indicatorColor.withOpacity(0.4),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ] : [],
          ),
        );
      },
    );
  }
}
