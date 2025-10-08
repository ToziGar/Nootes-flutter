import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

/// Estados de una nota/carpeta compartida
enum SharingStatus {
  pending,   // Pendiente de aceptación
  accepted,  // Aceptada por el receptor
  rejected,  // Rechazada por el receptor
  revoked,   // Revocada por el propietario
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
    this.message,
    this.metadata,
  });

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

  /// Verifica si un usuario existe por email
  Future<Map<String, dynamic>?> findUserByEmail(String email) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      return {
        'uid': doc.id,
        'email': doc.data()['email'],
        'fullName': doc.data()['fullName'],
        'username': doc.data()['username'],
      };
    } catch (e) {
      throw Exception('Error buscando usuario: $e');
    }
  }

  /// Verifica si un usuario existe por username
  Future<Map<String, dynamic>?> findUserByUsername(String username) async {
    try {
      final handle = await FirestoreService.instance.getHandle(username: username.trim().toLowerCase());
      if (handle == null) return null;

      final uid = handle['uid'];
      final userProfile = await FirestoreService.instance.getUserProfile(uid: uid);
      
      return userProfile != null ? {
        'uid': uid,
        'email': userProfile['email'],
        'fullName': userProfile['fullName'],
        'username': userProfile['username'],
      } : null;
    } catch (e) {
      throw Exception('Error buscando usuario: $e');
    }
  }

  /// Comparte una nota con otro usuario
  Future<String> shareNote({
    required String noteId,
    required String recipientIdentifier, // email o username
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

    // Verificar que la nota existe y pertenece al usuario actual
    final note = await FirestoreService.instance.getNote(
      uid: currentUser.uid,
      noteId: noteId,
    );

    if (note == null) {
      throw Exception('Nota no encontrada');
    }

    // Verificar si ya existe una compartición pendiente o activa
    final existing = await _firestore
        .collection('shared_items')
        .where('itemId', isEqualTo: noteId)
        .where('ownerId', isEqualTo: currentUser.uid)
        .where('recipientId', isEqualTo: recipient['uid'])
        .where('status', whereIn: ['pending', 'accepted'])
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('Esta nota ya está compartida con este usuario');
    }

    // Obtener perfil del propietario
    final ownerProfile = await FirestoreService.instance.getUserProfile(uid: currentUser.uid);

    // Crear compartición
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
      message: message,
      metadata: {
        'noteTitle': note['title'] ?? 'Sin título',
        'ownerName': ownerProfile?['fullName'] ?? 'Usuario',
      },
    );

    final docRef = await _firestore
        .collection('shared_items')
        .add(sharedItem.toMap());

    return docRef.id;
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

    // Verificar si ya existe una compartición
    final existing = await _firestore
        .collection('shared_items')
        .where('itemId', isEqualTo: folderId)
        .where('ownerId', isEqualTo: currentUser.uid)
        .where('recipientId', isEqualTo: recipient['uid'])
        .where('status', whereIn: ['pending', 'accepted'])
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('Esta carpeta ya está compartida con este usuario');
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

    final docRef = await _firestore
        .collection('shared_items')
        .add(sharedItem.toMap());

    return docRef.id;
  }

  /// Obtiene las comparticiones enviadas por el usuario actual
  Future<List<SharedItem>> getSharedByMe() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return [];

    final snapshot = await _firestore
        .collection('shared_items')
        .where('ownerId', isEqualTo: currentUser.uid)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => SharedItem.fromMap(doc.id, doc.data()))
        .toList();
  }

  /// Obtiene las comparticiones recibidas por el usuario actual
  Future<List<SharedItem>> getSharedWithMe() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return [];

    final snapshot = await _firestore
        .collection('shared_items')
        .where('recipientId', isEqualTo: currentUser.uid)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => SharedItem.fromMap(doc.id, doc.data()))
        .toList();
  }

  /// Acepta una compartición
  Future<void> acceptSharing(String sharingId) async {
    await _firestore.collection('shared_items').doc(sharingId).update({
      'status': SharingStatus.accepted.name,
      'updatedAt': fs.FieldValue.serverTimestamp(),
    });
  }

  /// Rechaza una compartición
  Future<void> rejectSharing(String sharingId) async {
    await _firestore.collection('shared_items').doc(sharingId).update({
      'status': SharingStatus.rejected.name,
      'updatedAt': fs.FieldValue.serverTimestamp(),
    });
  }

  /// Revoca una compartición (por el propietario)
  Future<void> revokeSharing(String sharingId) async {
    await _firestore.collection('shared_items').doc(sharingId).update({
      'status': SharingStatus.revoked.name,
      'updatedAt': fs.FieldValue.serverTimestamp(),
    });
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
          'permission': sharing.permission.name,
          'sharedAt': sharing.createdAt,
        });
      }
    }

    return notes;
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