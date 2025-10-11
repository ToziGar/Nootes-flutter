import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import 'dart:math';
import 'dart:convert';

/// Estados de una nota/carpeta compartida
enum SharingStatus {
  pending,   // Pendiente de aceptación
  accepted,  // Aceptada por el receptor
  rejected,  // Rechazada por el receptor
  revoked,   // Revocada por el propietario
  left,      // El receptor se salió voluntariamente
}

/// Tipos de elementos que se pueden compartir
enum SharedItemType {
  note,      // Nota individual
  folder,    // Carpeta con sus notas
  collection // Colección con sus notas
}

/// Niveles de permisos para elementos compartidos
enum PermissionLevel {
  read,      // Solo lectura
  comment,   // Lectura y comentarios
  edit,      // Lectura y edición
}

/// Modelo para elementos compartidos
class SharedItem {
  final String id;
  final String itemId;
  final SharedItemType type;
  final String ownerId;
  final String ownerEmail;
  final String recipientId;
  final String recipientEmail;
  final PermissionLevel permission;
  final SharingStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? expiresAt;
  final String? message;
  final Map<String, dynamic>? metadata;

  SharedItem({
    required this.id,
    required this.itemId,
    required this.type,
    required this.ownerId,
    required this.ownerEmail,
    required this.recipientId,
    required this.recipientEmail,
    required this.permission,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.expiresAt,
    this.message,
    this.metadata,
  });

  /// Verifica si la compartición ha expirado
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Días restantes hasta la expiración
  int? get daysUntilExpiration {
    if (expiresAt == null) return null;
    final now = DateTime.now();
    if (now.isAfter(expiresAt!)) return 0;
    return expiresAt!.difference(now).inDays;
  }

  factory SharedItem.fromMap(String id, Map<String, dynamic> data) {
    return SharedItem(
      id: id,
      itemId: data['itemId'] ?? '',
      type: SharedItemType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => SharedItemType.note,
      ),
      ownerId: data['ownerId'] ?? '',
      ownerEmail: data['ownerEmail'] ?? '',
      recipientId: data['recipientId'] ?? '',
      recipientEmail: data['recipientEmail'] ?? '',
      permission: PermissionLevel.values.firstWhere(
        (e) => e.name == data['permission'],
        orElse: () => PermissionLevel.read,
      ),
      status: SharingStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => SharingStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      message: data['message'],
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'type': type.name,
      'ownerId': ownerId,
      'ownerEmail': ownerEmail,
      'recipientId': recipientId,
      'recipientEmail': recipientEmail,
      'permission': permission.name,
      'status': status.name,
      'createdAt': fs.FieldValue.serverTimestamp(),
      'updatedAt': fs.FieldValue.serverTimestamp(),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'message': message,
      'metadata': metadata,
    };
  }
}

/// Servicio para manejar el sistema de compartir notas y carpetas
class SharingService {
  static final SharingService _instance = SharingService._internal();
  factory SharingService() => _instance;
  SharingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService.instance;

  // === PUBLIC LINK (simple token-based) ===
  /// Genera (o regenera) un enlace público para una nota. Devuelve el token.
  Future<String> generatePublicLink({required String noteId}) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) throw Exception('Usuario no autenticado');

    final token = _randomToken(24);
    final fsInstance = _firestore;

    // Guardar en colección global para resolución rápida: public_links/{token}
    await fsInstance.collection('public_links').doc(token).set({
      'noteId': noteId,
      'ownerId': currentUser.uid,
      'createdAt': fs.FieldValue.serverTimestamp(),
      'enabled': true,
      'token': token,
    });

    // Actualizar nota (campos indicativos)
    await FirestoreService.instance.updateNote(
      uid: currentUser.uid,
      noteId: noteId,
      data: {
        'shareToken': token,
        'shareEnabled': true,
        'sharedAt': fs.FieldValue.serverTimestamp(),
      },
    );

    return token;
  }

  /// Revoca el enlace público si existe.
  Future<void> revokePublicLink({required String noteId}) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) throw Exception('Usuario no autenticado');

    // Leer nota para obtener token actual
    final note = await FirestoreService.instance.getNote(uid: currentUser.uid, noteId: noteId);
    final token = note?['shareToken']?.toString();
    if (token != null && token.isNotEmpty) {
      await _firestore.collection('public_links').doc(token).set({
        'enabled': false,
        'revokedAt': fs.FieldValue.serverTimestamp(),
      }, fs.SetOptions(merge: true));
    }

    await FirestoreService.instance.updateNote(
      uid: currentUser.uid,
      noteId: noteId,
      data: {
        'shareEnabled': false,
      },
    );
  }

  /// Devuelve el token de enlace público (si todavía habilitado) para una nota propia.
  Future<String?> getPublicLinkToken({required String noteId}) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return null;
    final note = await FirestoreService.instance.getNote(uid: currentUser.uid, noteId: noteId);
    if (note == null) return null;
    if (note['shareEnabled'] != true) return null;
    final token = note['shareToken']?.toString();
    if (token == null || token.isEmpty) return null;
    // double-check doc enabled
    final doc = await _firestore.collection('public_links').doc(token).get();
    if (!doc.exists || (doc.data()?['enabled'] != true)) return null;
    return token;
  }

  /// Resuelve un token público a (ownerId, noteId) si está habilitado.
  Future<Map<String, String>?> resolvePublicToken(String token) async {
    final d = await _firestore.collection('public_links').doc(token).get();
    if (!d.exists) return null;
    final data = d.data()!;
    if (data['enabled'] != true) return null;
    final ownerId = data['ownerId']?.toString() ?? '';
    final noteId = data['noteId']?.toString() ?? '';
    if (ownerId.isEmpty || noteId.isEmpty) return null;
    return {
      'ownerId': ownerId,
      'noteId': noteId,
      'token': token,
    };
  }

  String _randomToken(int length) {
    final rand = Random.secure();
    final bytes = List<int>.generate(length, (_) => rand.nextInt(256));
    // Base64 URL safe sin '='
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  /// Verifica si un usuario existe por email
  Future<Map<String, dynamic>?> findUserByEmail(String email) async {
    try {
      debugPrint('🔍 SharingService.findUserByEmail: Buscando $email');
      final snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get();

      debugPrint('📊 SharingService.findUserByEmail: ${snapshot.docs.length} resultados');
      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      final result = {
        'uid': doc.id,
        'email': doc.data()['email'],
        'fullName': doc.data()['fullName'],
        'username': doc.data()['username'],
      };
      debugPrint('✅ SharingService.findUserByEmail: Usuario encontrado - ${result['email']}');
      return result;
    } catch (e) {
      debugPrint('❌ SharingService.findUserByEmail: Error - $e');
      if (e.toString().contains('PERMISSION_DENIED') || e.toString().contains('permission-denied')) {
        throw Exception('Sin permisos para buscar usuarios. Verifica las reglas de Firestore.');
      }
      throw Exception('Error buscando usuario por email: $e');
    }
  }

  /// Verifica si un usuario existe por username
  Future<Map<String, dynamic>?> findUserByUsername(String username) async {
    try {
      debugPrint('🔍 SharingService.findUserByUsername: Buscando @$username');
      final handle = await FirestoreService.instance.getHandle(username: username.trim().toLowerCase());
      if (handle == null) {
        debugPrint('📊 SharingService.findUserByUsername: Handle no encontrado');
        return null;
      }

      final uid = handle['uid'];
      debugPrint('📊 SharingService.findUserByUsername: Handle encontrado, UID: $uid');
      final userProfile = await FirestoreService.instance.getUserProfile(uid: uid);
      
      final result = userProfile != null ? {
        'uid': uid,
        'email': userProfile['email'],
        'fullName': userProfile['fullName'],
        'username': userProfile['username'],
      } : null;
      
      if (result != null) {
        debugPrint('✅ SharingService.findUserByUsername: Usuario encontrado - @${result['username']}');
      } else {
        debugPrint('📊 SharingService.findUserByUsername: Perfil no encontrado');
      }
      
      return result;
    } catch (e) {
      debugPrint('❌ SharingService.findUserByUsername: Error - $e');
      if (e.toString().contains('PERMISSION_DENIED') || e.toString().contains('permission-denied')) {
        throw Exception('Sin permisos para buscar usuarios. Verifica las reglas de Firestore.');
      }
      throw Exception('Error buscando usuario por username: $e');
    }
  }

  /// Comparte una nota con otro usuario
  Future<String> shareNote({
    required String noteId,
    required String recipientIdentifier, // email o username
    required PermissionLevel permission,
    String? message,
    DateTime? expiresAt,
  }) async {
    debugPrint('🔄 SharingService.shareNote iniciado');
    debugPrint('📝 noteId: $noteId');
    debugPrint('👤 recipientIdentifier: $recipientIdentifier');
    
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      debugPrint('❌ Usuario no autenticado');
      throw Exception('No has iniciado sesión. Por favor, inicia sesión e intenta de nuevo.');
    }
    
    debugPrint('✅ Usuario actual: ${currentUser.uid}');

    // Verificar token de autenticación
    try {
      await _authService.getIdToken();
      debugPrint('✅ Token de autenticación válido');
    } catch (e) {
      debugPrint('❌ Error de autenticación: $e');
      throw Exception('Tu sesión ha expirado. Por favor, cierra sesión e inicia sesión nuevamente.');
    }

    // Buscar usuario destinatario
    debugPrint('🔍 Buscando destinatario...');
    Map<String, dynamic>? recipient;
    try {
      if (recipientIdentifier.contains('@')) {
        recipient = await findUserByEmail(recipientIdentifier);
      } else {
        recipient = await findUserByUsername(recipientIdentifier);
      }
    } catch (e) {
      debugPrint('❌ Error buscando destinatario: $e');
      throw Exception('Error buscando destinatario: $e');
    }

    if (recipient == null) {
      debugPrint('❌ Usuario destinatario no encontrado');
      throw Exception('Usuario no encontrado');
    }
    
    debugPrint('✅ Destinatario encontrado: ${recipient['uid']}');

    if (recipient['uid'] == currentUser.uid) {
      debugPrint('❌ Intento de compartir consigo mismo');
      throw Exception('No puedes compartir contigo mismo');
    }

    // Verificar que la nota existe y pertenece al usuario actual
    debugPrint('🔍 Verificando nota...');
    Map<String, dynamic>? note;
    try {
      // Primero intentar obtener la nota
      note = await FirestoreService.instance.getNote(
        uid: currentUser.uid,
        noteId: noteId,
      );
      
      if (note == null) {
        debugPrint('❌ Nota no encontrada');
        throw Exception('La nota no existe o ha sido eliminada');
      }
    } catch (e) {
      debugPrint('❌ Error accediendo a la nota: $e');
      
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('permission') || errorStr.contains('denied') || 
          errorStr.contains('unauthorized') || errorStr.contains('403')) {
        throw Exception('No tienes permisos para compartir esta nota. Verifica que seas el propietario.');
      } else if (errorStr.contains('not found') || errorStr.contains('404')) {
        throw Exception('La nota no existe o ha sido eliminada.');
      } else if (errorStr.contains('network') || errorStr.contains('connection')) {
        throw Exception('Error de conexión. Verifica tu internet e intenta de nuevo.');
      } else if (errorStr.contains('auth') || errorStr.contains('token')) {
        throw Exception('Sesión expirada. Cierra sesión e inicia sesión nuevamente.');
      } else {
        throw Exception('Error inesperado al verificar la nota: ${e.toString()}');
      }
    }
    
    debugPrint('✅ Nota verificada: ${note['title'] ?? 'Sin título'}');

    // Verificar si ya existe una compartición (usando ID determinístico)
    debugPrint('🔍 Verificando comparticiones existentes...');
    final shareId = '${recipient['uid']}_${currentUser.uid}_$noteId';
    try {
      final existingDoc = await _firestore.collection('shared_items').doc(shareId).get();
      if (existingDoc.exists) {
        final data = existingDoc.data() as Map<String, dynamic>;
        final existingStatus = (data['status'] as String?) ?? 'pending';
        // Si estaba revocada o rechazada, permitimos reactivar/actualizar
        if (existingStatus == SharingStatus.revoked.name || existingStatus == SharingStatus.rejected.name) {
          debugPrint('♻️ Reactivando compartición existente ($existingStatus)');
          await _firestore.collection('shared_items').doc(shareId).update({
            'permission': permission.name,
            'status': SharingStatus.pending.name,
            'updatedAt': fs.FieldValue.serverTimestamp(),
            if (message != null) 'message': message,
            if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt),
            'metadata': {
              'noteTitle': note['title'] ?? 'Sin título',
              'ownerName': currentUser.email?.split('@').first ?? 'Usuario',
            },
          });
          return shareId;
        }
        if (existingStatus == SharingStatus.pending.name || existingStatus == SharingStatus.accepted.name) {
          debugPrint('❌ Nota ya compartida con este usuario (estado: $existingStatus)');
          throw Exception('Esta nota ya está compartida con este usuario');
        }
      }
    } catch (e) {
      debugPrint('❌ Error verificando compartición existente: $e');
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('permission') || errorStr.contains('denied') || 
          errorStr.contains('unauthorized') || errorStr.contains('403')) {
        throw Exception('No tienes permisos para crear comparticiones.');
      } else if (errorStr.contains('network') || errorStr.contains('connection')) {
        throw Exception('Error de conexión al verificar comparticiones existentes.');
      } else if (e.toString().contains('Esta nota ya está compartida')) {
        rethrow;
      }
    }
    
    debugPrint('✅ No hay comparticiones duplicadas');

    // Obtener perfil del propietario
    debugPrint('🔍 Obteniendo perfil del propietario...');
    Map<String, dynamic>? ownerProfile;
    try {
      ownerProfile = await FirestoreService.instance.getUserProfile(uid: currentUser.uid);
    } catch (e) {
      debugPrint('❌ Error obteniendo perfil: $e');
      throw Exception('Error obteniendo perfil del usuario: $e');
    }
    
    debugPrint('✅ Perfil obtenido');

    // Crear compartición
    debugPrint('📝 Creando compartición...');
    try {
      final sharedItem = SharedItem(
        id: '',
        itemId: noteId,
        type: SharedItemType.note,
        ownerId: currentUser.uid,
        ownerEmail: ownerProfile?['email'] ?? currentUser.email ?? '',
        recipientId: recipient['uid'],
        recipientEmail: recipient['email'],
        permission: permission,
        status: SharingStatus.pending,
        createdAt: DateTime.now(),
        expiresAt: expiresAt,
        message: message,
        metadata: {
          'noteTitle': note['title'] ?? 'Sin título',
          'ownerName': ownerProfile?['fullName'] ?? 'Usuario',
        },
      );

  final docRef = _firestore.collection('shared_items').doc(shareId);
  await docRef.set(sharedItem.toMap());
  debugPrint('✅ Compartición creada exitosamente: ${docRef.id}');

      // Enviar notificación al destinatario (no bloquear si falla)
      try {
        final notificationService = NotificationService();
        await notificationService.notifyNewShare(
          recipientId: recipient['uid'],
          senderName: ownerProfile?['fullName'] ?? currentUser.email?.split('@').first ?? 'Usuario',
          senderEmail: currentUser.email ?? '',
          itemTitle: note['title'] ?? 'Sin título',
          shareId: docRef.id,
          itemType: SharedItemType.note,
        );
      } catch (e) {
        debugPrint('⚠️ No se pudo crear la notificación de compartición: $e');
      }
      
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error creando documento de compartición: $e');
      throw Exception('Error creando compartición: $e');
    }
  }

  /// Comparte una carpeta con otro usuario
  Future<String> shareFolder({
    required String folderId,
    required String recipientIdentifier,
    required PermissionLevel permission,
    String? message,
  }) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) throw Exception('Usuario no autenticado');

    // Buscar usuario destinatario
    Map<String, dynamic>? recipient;
    if (recipientIdentifier.contains('@')) {
      recipient = await findUserByEmail(recipientIdentifier);
    } else {
      recipient = await findUserByUsername(recipientIdentifier);
    }

    if (recipient == null) {
      throw Exception('Usuario no encontrado');
    }

    if (recipient['uid'] == currentUser.uid) {
      throw Exception('No puedes compartir contigo mismo');
    }

    // Verificar que la carpeta existe
    final folder = await FirestoreService.instance.getFolder(
      uid: currentUser.uid,
      folderId: folderId,
    );

    if (folder == null) {
      throw Exception('Carpeta no encontrada');
    }

    // Verificar si ya existe una compartición (ID determinístico)
    final shareId = '${recipient['uid']}_${currentUser.uid}_$folderId';
    final existingDoc = await _firestore.collection('shared_items').doc(shareId).get();
    if (existingDoc.exists) {
      final data = existingDoc.data() as Map<String, dynamic>;
      final existingStatus = (data['status'] as String?) ?? 'pending';
      if (existingStatus == SharingStatus.pending.name || existingStatus == SharingStatus.accepted.name) {
        throw Exception('Esta carpeta ya está compartida con este usuario');
      }
    }

    // Obtener perfil del propietario
    final ownerProfile = await FirestoreService.instance.getUserProfile(uid: currentUser.uid);

    // Crear compartición
    final sharedItem = SharedItem(
      id: '',
      itemId: folderId,
      type: SharedItemType.folder,
      ownerId: currentUser.uid,
      ownerEmail: ownerProfile?['email'] ?? currentUser.email ?? '',
      recipientId: recipient['uid'],
      recipientEmail: recipient['email'],
      permission: permission,
      status: SharingStatus.pending,
      createdAt: DateTime.now(),
      message: message,
      metadata: {
        'folderName': folder['name'] ?? 'Sin nombre',
        'ownerName': ownerProfile?['fullName'] ?? 'Usuario',
        'noteCount': (folder['noteIds'] as List?)?.length ?? 0,
      },
    );

  final docRef = _firestore.collection('shared_items').doc(shareId);
  await docRef.set(sharedItem.toMap());

    // Enviar notificación al destinatario (no bloquear si falla)
    try {
      final notificationService = NotificationService();
      await notificationService.notifyNewShare(
        recipientId: recipient['uid'],
        senderName: ownerProfile?['fullName'] ?? currentUser.email?.split('@').first ?? 'Usuario',
        senderEmail: currentUser.email ?? '',
        itemTitle: folder['name'] ?? 'Sin nombre',
        shareId: docRef.id,
        itemType: SharedItemType.folder,
      );
    } catch (e) {
      debugPrint('⚠️ No se pudo crear la notificación de compartición (carpeta): $e');
    }

    return docRef.id;
  }

  /// Obtiene las comparticiones enviadas por el usuario actual
  Future<List<SharedItem>> getSharedByMe({
    SharingStatus? status,
    SharedItemType? type,
    String? searchQuery,
    int? limit,
  }) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      debugPrint('⚠️ getSharedByMe: No hay usuario autenticado');
      return [];
    }

    debugPrint('📤 getSharedByMe: Consultando compartidas enviadas por ${currentUser.uid}');
    debugPrint('   Filtros: status=$status, type=$type, search=$searchQuery');

    Query query = _firestore
        .collection('shared_items')
        .where('ownerId', isEqualTo: currentUser.uid);

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    if (type != null) {
      query = query.where('type', isEqualTo: type.name);
    }

    query = query.orderBy('createdAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    final snapshot = await query.get();
    debugPrint('   Documentos encontrados en Firestore: ${snapshot.docs.length}');
    
    var items = snapshot.docs
        .map((doc) => SharedItem.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .toList();

    debugPrint('   Items parseados: ${items.length}');
    for (var item in items) {
      debugPrint('   - ${item.type.name}: ${item.metadata?['noteTitle'] ?? item.metadata?['folderName']} (${item.status.name})');
    }

    // Filtro por búsqueda en cliente (debido a limitaciones de Firestore)
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final search = searchQuery.toLowerCase();
      items = items.where((item) {
        final title = (item.metadata?['noteTitle'] ?? item.metadata?['folderName'] ?? '').toLowerCase();
        final email = item.recipientEmail.toLowerCase();
        return title.contains(search) || email.contains(search);
      }).toList();
      debugPrint('   Después de filtro de búsqueda: ${items.length}');
    }

    debugPrint('✅ getSharedByMe: Retornando ${items.length} items');
    return items;
  }

  /// Obtiene las comparticiones recibidas por el usuario actual
  Future<List<SharedItem>> getSharedWithMe({
    SharingStatus? status,
    SharedItemType? type,
    String? searchQuery,
    int? limit,
  }) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return [];

    Query query = _firestore
        .collection('shared_items')
        .where('recipientId', isEqualTo: currentUser.uid);

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    if (type != null) {
      query = query.where('type', isEqualTo: type.name);
    }

    query = query.orderBy('createdAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    final snapshot = await query.get();
    var items = snapshot.docs
        .map((doc) => SharedItem.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .toList();

    // Filtro por búsqueda en cliente
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final search = searchQuery.toLowerCase();
      items = items.where((item) {
        final title = (item.metadata?['noteTitle'] ?? item.metadata?['folderName'] ?? '').toLowerCase();
        final email = item.ownerEmail.toLowerCase();
        return title.contains(search) || email.contains(search);
      }).toList();
    }

    return items;
  }

  /// Obtiene estadísticas de compartición
  Future<Map<String, int>> getSharingStats() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return {};

    final futures = await Future.wait([
      // Enviadas
      getSharedByMe(status: SharingStatus.pending),
      getSharedByMe(status: SharingStatus.accepted),
      getSharedByMe(status: SharingStatus.rejected),
      // Recibidas
      getSharedWithMe(status: SharingStatus.pending),
      getSharedWithMe(status: SharingStatus.accepted),
      getSharedWithMe(status: SharingStatus.rejected),
    ]);

    return {
      'sentPending': futures[0].length,
      'sentAccepted': futures[1].length,
      'sentRejected': futures[2].length,
      'receivedPending': futures[3].length,
      'receivedAccepted': futures[4].length,
      'receivedRejected': futures[5].length,
    };
  }

  /// Acepta una compartición
  Future<void> acceptSharing(String sharingId) async {
    // Obtener información de la compartición antes de actualizarla
    final shareDoc = await _firestore.collection('shared_items').doc(sharingId).get();
    if (!shareDoc.exists) return;
    
    final shareData = shareDoc.data()!;
    final ownerId = shareData['ownerId'] as String;
    final itemId = shareData['itemId'] as String;
    final itemType = shareData['type'] as String;
    final itemTitle = shareData['metadata']?['noteTitle'] ?? shareData['metadata']?['folderName'] ?? 'Sin título';
    final permission = shareData['permission'] as String;
    
    // Obtener información del receptor (usuario actual)
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;
    
    // Actualizar el estado
    await _firestore.collection('shared_items').doc(sharingId).update({
      'status': SharingStatus.accepted.name,
      'updatedAt': fs.FieldValue.serverTimestamp(),
    });
    
    // Si es una carpeta, crear comparticiones para cada nota dentro
    if (itemType == SharedItemType.folder.name) {
      try {
        await _createNoteSharesForFolder(
          folderId: itemId,
          ownerId: ownerId,
          recipientId: currentUser.uid,
          recipientEmail: currentUser.email ?? '',
          permission: PermissionLevel.values.firstWhere((p) => p.name == permission),
        );
        debugPrint('✅ Comparticiones de notas creadas para carpeta $itemId');
      } catch (e) {
        debugPrint('⚠️ Error creando comparticiones de notas: $e');
        // No bloqueamos si falla, las notas se pueden compartir manualmente
      }
    }
    
    // Enviar notificación al propietario
    final notificationService = NotificationService();
    await notificationService.notifyShareAccepted(
      ownerId: ownerId,
      recipientName: currentUser.email?.split('@').first ?? 'Usuario',
      recipientEmail: currentUser.email ?? '',
      itemTitle: itemTitle,
      shareId: sharingId,
    );
  }
  
  /// Crea comparticiones automáticas para todas las notas dentro de una carpeta
  Future<void> _createNoteSharesForFolder({
    required String folderId,
    required String ownerId,
    required String recipientId,
    required String recipientEmail,
    required PermissionLevel permission,
  }) async {
    // Obtener la carpeta para saber qué notas contiene
    final folder = await FirestoreService.instance.getFolder(
      uid: ownerId,
      folderId: folderId,
    );

    if (folder == null || folder['noteIds'] == null) return;

    final noteIds = List<String>.from(folder['noteIds'] ?? []);
    debugPrint('📝 Creando comparticiones para ${noteIds.length} notas en carpeta $folderId');

    // Crear comparticiones en batch
    final batch = _firestore.batch();
    int created = 0;

    for (final noteId in noteIds) {
      final shareId = '${recipientId}_${ownerId}_$noteId';
      final docRef = _firestore.collection('shared_items').doc(shareId);
      
      // Verificar si ya existe
      final exists = await docRef.get();
      if (exists.exists) {
        debugPrint('   ⏭️ Compartición ya existe para nota $noteId');
        continue;
      }

      // Obtener metadata de la nota
      final note = await FirestoreService.instance.getNote(
        uid: ownerId,
        noteId: noteId,
      );

      batch.set(docRef, {
        'itemId': noteId,
        'type': SharedItemType.note.name,
        'ownerId': ownerId,
        'ownerEmail': folder['ownerEmail'] ?? '',
        'recipientId': recipientId,
        'recipientEmail': recipientEmail,
        'permission': permission.name,
        'status': SharingStatus.accepted.name, // Auto-aceptada porque la carpeta ya fue aceptada
        'createdAt': fs.FieldValue.serverTimestamp(),
        'updatedAt': fs.FieldValue.serverTimestamp(),
        'metadata': {
          'noteTitle': note?['title'] ?? 'Sin título',
          'fromFolder': folderId,
          'folderName': folder['name'] ?? 'Sin nombre',
        },
      });
      created++;
    }

    if (created > 0) {
      await batch.commit();
      debugPrint('✅ Creadas $created comparticiones automáticas de notas');
    }
  }

  /// Rechaza una compartición
  Future<void> rejectSharing(String sharingId) async {
    // Obtener información de la compartición antes de actualizarla
    final shareDoc = await _firestore.collection('shared_items').doc(sharingId).get();
    if (!shareDoc.exists) return;
    
    final shareData = shareDoc.data()!;
    final ownerId = shareData['ownerId'] as String;
    final itemTitle = shareData['metadata']?['noteTitle'] ?? shareData['metadata']?['folderName'] ?? 'Sin título';
    
    // Obtener información del receptor (usuario actual)
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;
    
    // Actualizar el estado
    await _firestore.collection('shared_items').doc(sharingId).update({
      'status': SharingStatus.rejected.name,
      'updatedAt': fs.FieldValue.serverTimestamp(),
    });
    
    // Enviar notificación al propietario
    final notificationService = NotificationService();
    await notificationService.notifyShareRejected(
      ownerId: ownerId,
      recipientName: currentUser.email?.split('@').first ?? 'Usuario',
      recipientEmail: currentUser.email ?? '',
      itemTitle: itemTitle,
      shareId: sharingId,
    );
  }

  /// El receptor se sale de una compartición (deja de verla)
  Future<void> leaveSharing(String sharingId) async {
    // Obtener información de la compartición antes de actualizarla
    final shareDoc = await _firestore.collection('shared_items').doc(sharingId).get();
    if (!shareDoc.exists) return;
    final data = shareDoc.data()!;
    final ownerId = data['ownerId'] as String;
    final recipientId = data['recipientId'] as String;

    final currentUser = _authService.currentUser;
    if (currentUser == null) return;
    if (currentUser.uid != recipientId) {
      throw Exception('Solo el receptor puede salir de la compartición');
    }

    await _firestore.collection('shared_items').doc(sharingId).update({
      'status': SharingStatus.left.name,
      'updatedAt': fs.FieldValue.serverTimestamp(),
    });

    // Notificar al propietario (no bloquear si falla)
    try {
      final notificationService = NotificationService();
      final itemTitle = data['metadata']?['noteTitle'] ?? data['metadata']?['folderName'] ?? 'Sin título';
      await notificationService.notifyShareLeft(
        ownerId: ownerId,
        recipientName: currentUser.email?.split('@').first ?? 'Usuario',
        recipientEmail: currentUser.email ?? '',
        itemTitle: itemTitle,
        shareId: sharingId,
      );
    } catch (e) {
      // Ignorar errores de notificación
    }
  }

  /// Revoca una compartición (por el propietario)
  /// Actualiza los permisos de una compartición existente
  Future<void> updatePermission(String sharingId, PermissionLevel newPermission) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) throw Exception('Usuario no autenticado');
    
    // Obtener información de la compartición
    final shareDoc = await _firestore.collection('shared_items').doc(sharingId).get();
    if (!shareDoc.exists) throw Exception('Compartición no encontrada');
    
    final shareData = shareDoc.data()!;
    
    // Verificar que el usuario actual es el propietario
    if (shareData['ownerId'] != currentUser.uid) {
      throw Exception('Solo el propietario puede cambiar permisos');
    }
    
    final recipientId = shareData['recipientId'] as String;
    final itemTitle = shareData['metadata']?['noteTitle'] ?? shareData['metadata']?['folderName'] ?? 'Sin título';
    
    // Actualizar el permiso
    await _firestore.collection('shared_items').doc(sharingId).update({
      'permission': newPermission.name,
      'updatedAt': fs.FieldValue.serverTimestamp(),
    });
    
    // Enviar notificación al receptor
    final notificationService = NotificationService();
    await notificationService.createShareNotification(
      userId: recipientId,
      type: NotificationType.newShare,
      title: 'Permisos actualizados',
      message: 'Tus permisos para "$itemTitle" han sido actualizados',
      shareId: sharingId,
      metadata: {
        'shareId': sharingId,
        'newPermission': newPermission.name,
        'itemTitle': itemTitle,
      },
    );
    
    debugPrint('✅ Permisos actualizados para compartición $sharingId');
  }

  Future<void> revokeSharing(String sharingId) async {
    // Obtener información de la compartición antes de actualizarla
    final shareDoc = await _firestore.collection('shared_items').doc(sharingId).get();
    if (!shareDoc.exists) return;
    
    final shareData = shareDoc.data()!;
    final recipientId = shareData['recipientId'] as String;
    final itemTitle = shareData['metadata']?['noteTitle'] ?? shareData['metadata']?['folderName'] ?? 'Sin título';
    
    // Obtener información del propietario (usuario actual)
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;
    
    // Actualizar el estado
    await _firestore.collection('shared_items').doc(sharingId).update({
      'status': SharingStatus.revoked.name,
      'updatedAt': fs.FieldValue.serverTimestamp(),
    });
    
    // Enviar notificación al receptor
    final notificationService = NotificationService();
    await notificationService.notifyShareRevoked(
      recipientId: recipientId,
      ownerName: currentUser.email?.split('@').first ?? 'Usuario',
      itemTitle: itemTitle,
      shareId: sharingId,
    );
  }

  /// Elimina una compartición completamente
  Future<void> deleteSharing(String sharingId) async {
    await _firestore.collection('shared_items').doc(sharingId).delete();
  }

  /// Obtiene notas compartidas conmigo que he aceptado
  Future<List<Map<String, dynamic>>> getSharedNotes() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return [];

    final sharedItems = await _firestore
        .collection('shared_items')
        .where('recipientId', isEqualTo: currentUser.uid)
        .where('type', isEqualTo: SharedItemType.note.name)
        .where('status', isEqualTo: SharingStatus.accepted.name)
        .get();

    final List<Map<String, dynamic>> notes = [];

    for (final doc in sharedItems.docs) {
      final sharing = SharedItem.fromMap(doc.id, doc.data());
      
      // Obtener la nota desde el propietario
      final note = await FirestoreService.instance.getNote(
        uid: sharing.ownerId,
        noteId: sharing.itemId,
      );

      if (note != null) {
        notes.add({
          ...note,
          'isShared': true,
          'sharingId': sharing.id,
          'sharedBy': sharing.ownerEmail,
          'ownerId': sharing.ownerId,
          'permission': sharing.permission.name,
          'sharedAt': sharing.createdAt,
        });
      }
    }

    return notes;
  }

  /// Obtiene carpetas compartidas conmigo que he aceptado
  Future<List<Map<String, dynamic>>> getSharedFolders() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return [];

    final sharedItems = await _firestore
        .collection('shared_items')
        .where('recipientId', isEqualTo: currentUser.uid)
        .where('type', isEqualTo: SharedItemType.folder.name)
        .where('status', isEqualTo: SharingStatus.accepted.name)
        .get();

    final List<Map<String, dynamic>> folders = [];

    for (final doc in sharedItems.docs) {
      final sharing = SharedItem.fromMap(doc.id, doc.data());
      
      // Obtener la carpeta desde el propietario
      final folder = await FirestoreService.instance.getFolder(
        uid: sharing.ownerId,
        folderId: sharing.itemId,
      );

      if (folder != null) {
        folders.add({
          ...folder,
          'isShared': true,
          'sharingId': sharing.id,
          'sharedBy': sharing.ownerEmail,
          'ownerId': sharing.ownerId,
          'permission': sharing.permission.name,
          'sharedAt': sharing.createdAt,
        });
      }
    }

    return folders;
  }

  /// Obtiene las notas dentro de una carpeta compartida
  Future<List<Map<String, dynamic>>> getNotesInSharedFolder({
    required String folderId,
    required String ownerId,
  }) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return [];

    try {
      // Verificar que tengo acceso a la carpeta
      final folderAccess = await _firestore
          .collection('shared_items')
          .where('itemId', isEqualTo: folderId)
          .where('ownerId', isEqualTo: ownerId)
          .where('recipientId', isEqualTo: currentUser.uid)
          .where('type', isEqualTo: SharedItemType.folder.name)
          .where('status', isEqualTo: SharingStatus.accepted.name)
          .get();

      if (folderAccess.docs.isEmpty) {
        debugPrint('⚠️ No access to folder $folderId');
        return [];
      }

      final sharing = SharedItem.fromMap(folderAccess.docs.first.id, folderAccess.docs.first.data());

      // Obtener la carpeta para saber qué notas contiene
      final folder = await FirestoreService.instance.getFolder(
        uid: ownerId,
        folderId: folderId,
      );

      if (folder == null || folder['noteIds'] == null) {
        debugPrint('⚠️ Folder $folderId has no notes');
        return [];
      }

      final noteIds = List<String>.from(folder['noteIds'] ?? []);
      final List<Map<String, dynamic>> notes = [];

      debugPrint('📂 Cargando ${noteIds.length} notas de carpeta compartida $folderId');

      // Obtener cada nota (ahora deberían tener permisos porque se crearon shared_items automáticamente)
      for (final noteId in noteIds) {
        try {
          final note = await FirestoreService.instance.getNote(
            uid: ownerId,
            noteId: noteId,
          );

          if (note != null) {
            notes.add({
              ...note,
              'isShared': true,
              'isInSharedFolder': true,
              'sharedFolderId': folderId,
              'sharedBy': sharing.ownerEmail,
              'ownerId': ownerId,
              'permission': sharing.permission.name,
              'sharedAt': sharing.createdAt,
            });
          } else {
            debugPrint('   ⚠️ Nota $noteId no encontrada');
          }
        } catch (e) {
          debugPrint('   ❌ Error cargando nota $noteId: $e');
          // Continuar con las demás notas
        }
      }

      debugPrint('✅ Cargadas ${notes.length}/${noteIds.length} notas de carpeta compartida');
      return notes;
    } catch (e) {
      debugPrint('❌ Error en getNotesInSharedFolder: $e');
      return [];
    }
  }

  /// Verifica si el usuario actual tiene acceso a una nota específica
  Future<Map<String, dynamic>?> checkNoteAccess(String noteId, String noteOwnerId) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return null;

    // Si es el propietario, tiene acceso completo
    if (currentUser.uid == noteOwnerId) {
      return {
        'hasAccess': true,
        'permission': 'owner',
        'isOwner': true,
      };
    }

    // Verificar si la nota está compartida conmigo
    final snapshot = await _firestore
        .collection('shared_items')
        .where('itemId', isEqualTo: noteId)
        .where('ownerId', isEqualTo: noteOwnerId)
        .where('recipientId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: SharingStatus.accepted.name)
        .get();

    if (snapshot.docs.isEmpty) {
      return {
        'hasAccess': false,
        'isOwner': false,
      };
    }

    final sharing = SharedItem.fromMap(snapshot.docs.first.id, snapshot.docs.first.data());
    
    return {
      'hasAccess': true,
      'permission': sharing.permission.name,
      'isOwner': false,
      'sharingId': sharing.id,
      'sharedBy': sharing.ownerEmail,
    };
  }
}