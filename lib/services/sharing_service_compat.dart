import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:nootes/services/sharing_service_improved.dart';
import 'package:nootes/services/firestore_service.dart';
import 'package:nootes/services/auth_service.dart';
import 'package:nootes/services/notification_service.dart';
import 'package:nootes/services/exceptions/sharing_exceptions.dart';

/// Compatibility layer that exposes legacy method names expected by the
/// rest of the codebase. These functions replicate the previous behavior
/// using Firestore and the current Auth/Notification services.

extension SharingServiceCompat on SharingService {
  Future<List<SharedItem>> getSharedByMe({
    SharingStatus? status,
    SharedItemType? type,
    String? searchQuery,
    int? limit,
  }) async {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) return [];
    fs.Query query = fs.FirebaseFirestore.instance
        .collection('shared_items')
        .where('ownerId', isEqualTo: currentUser.uid);

    if (status != null) query = query.where('status', isEqualTo: status.name);
    if (type != null) query = query.where('type', isEqualTo: type.name);
    query = query.orderBy('createdAt', descending: true);
    if (limit != null) query = query.limit(limit);

    final snap = await query.get();
  var items = snap.docs
    .map((d) => SharedItem.fromMap(d.id, Map<String, dynamic>.from(d.data() as Map)))
        .toList();

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      items = items.where((item) {
        final title = (item.metadata?['noteTitle'] ?? item.metadata?['folderName'] ?? '')
            .toString()
            .toLowerCase();
        final email = item.recipientEmail.toLowerCase();
        return title.contains(q) || email.contains(q);
      }).toList();
    }

    return items;
  }

  Future<List<SharedItem>> getSharedWithMe({
    SharingStatus? status,
    SharedItemType? type,
    String? searchQuery,
    int? limit,
  }) async {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) return [];

  fs.Query query = fs.FirebaseFirestore.instance
    .collection('shared_items')
        .where('recipientId', isEqualTo: currentUser.uid);

    if (status != null) query = query.where('status', isEqualTo: status.name);
    if (type != null) query = query.where('type', isEqualTo: type.name);
    query = query.orderBy('createdAt', descending: true);
    if (limit != null) query = query.limit(limit);

    final snap = await query.get();
  var items = snap.docs
    .map((d) => SharedItem.fromMap(d.id, Map<String, dynamic>.from(d.data() as Map)))
        .toList();

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      items = items.where((item) {
        final title = (item.metadata?['noteTitle'] ?? item.metadata?['folderName'] ?? '')
            .toString()
            .toLowerCase();
        final email = item.ownerEmail.toLowerCase();
        return title.contains(q) || email.contains(q);
      }).toList();
    }

    return items;
  }

  Future<List<Map<String, dynamic>>> getSharedNotes() async {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) return [];

  final sharedItems = await fs.FirebaseFirestore.instance
    .collection('shared_items')
        .where('recipientId', isEqualTo: currentUser.uid)
        .where('type', isEqualTo: SharedItemType.note.name)
        .where('status', isEqualTo: SharingStatus.accepted.name)
        .get();

    final List<Map<String, dynamic>> notes = [];

  for (final doc in sharedItems.docs) {
  final sharing = SharedItem.fromMap(doc.id, Map<String, dynamic>.from(doc.data() as Map));
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

  Future<List<SharedItem>> getFolderMembers({required String folderId}) async {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) return [];

  final snap = await fs.FirebaseFirestore.instance
    .collection('shared_items')
        .where('type', isEqualTo: SharedItemType.folder.name)
        .where('itemId', isEqualTo: folderId)
        .where('ownerId', isEqualTo: currentUser.uid)
        .orderBy('createdAt', descending: false)
        .get();

    final items = snap.docs
       .map((d) => SharedItem.fromMap(d.id, d.data()))
        .where((s) => s.status != SharingStatus.revoked && s.status != SharingStatus.left)
        .toList();
    return items;
  }

  Future<void> updateSharingPermission(String sharingId, PermissionLevel permission) async {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) throw const AuthenticationException();

  final doc = await fs.FirebaseFirestore.instance.collection('shared_items').doc(sharingId).get();
    if (!doc.exists) throw Exception('Compartición no encontrada');
    final data = doc.data() as Map<String, dynamic>;
    if (data['ownerId'] != currentUser.uid) throw Exception('Solo el propietario puede cambiar los permisos');

    await fs.FirebaseFirestore.instance.collection('shared_items').doc(sharingId).update({
      'permission': permission.name,
      'updatedAt': fs.FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, int>> getSharingStats() async {
    final sentPending = await getSharedByMe(status: SharingStatus.pending);
    final sentAccepted = await getSharedByMe(status: SharingStatus.accepted);
    final sentRejected = await getSharedByMe(status: SharingStatus.rejected);
    final receivedPending = await getSharedWithMe(status: SharingStatus.pending);
    final receivedAccepted = await getSharedWithMe(status: SharingStatus.accepted);
    final receivedRejected = await getSharedWithMe(status: SharingStatus.rejected);

    return {
      'sentPending': sentPending.length,
      'sentAccepted': sentAccepted.length,
      'sentRejected': sentRejected.length,
      'receivedPending': receivedPending.length,
      'receivedAccepted': receivedAccepted.length,
      'receivedRejected': receivedRejected.length,
    };
  }

  Future<void> acceptSharing(String sharingId) async {
  final shareDoc = await fs.FirebaseFirestore.instance.collection('shared_items').doc(sharingId).get();
    if (!shareDoc.exists) return;
    final data = shareDoc.data() as Map<String, dynamic>;
    final ownerId = data['ownerId'] as String;
    final itemTitle = data['metadata']?['noteTitle'] ?? data['metadata']?['folderName'] ?? 'Sin título';

    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) return;

    await fs.FirebaseFirestore.instance.collection('shared_items').doc(sharingId).update({
      'status': SharingStatus.accepted.name,
      'updatedAt': fs.FieldValue.serverTimestamp(),
    });

    final notificationService = NotificationService();
    await notificationService.notifyShareAccepted(
      ownerId: ownerId,
      recipientName: currentUser.email?.split('@').first ?? 'Usuario',
      recipientEmail: currentUser.email ?? '',
      itemTitle: itemTitle,
      shareId: sharingId,
    );
  }

  Future<void> rejectSharing(String sharingId) async {
  final shareDoc = await fs.FirebaseFirestore.instance.collection('shared_items').doc(sharingId).get();
    if (!shareDoc.exists) return;
    final data = shareDoc.data() as Map<String, dynamic>;
    final ownerId = data['ownerId'] as String;
    final itemTitle = data['metadata']?['noteTitle'] ?? data['metadata']?['folderName'] ?? 'Sin título';

    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) return;

    await fs.FirebaseFirestore.instance.collection('shared_items').doc(sharingId).update({
      'status': SharingStatus.rejected.name,
      'updatedAt': fs.FieldValue.serverTimestamp(),
    });

    final notificationService = NotificationService();
    await notificationService.notifyShareRejected(
      ownerId: ownerId,
      recipientName: currentUser.email?.split('@').first ?? 'Usuario',
      recipientEmail: currentUser.email ?? '',
      itemTitle: itemTitle,
      shareId: sharingId,
    );
  }

  Future<Map<String, dynamic>?> checkNoteAccess(String noteId, String noteOwnerId) async {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) return null;
    if (currentUser.uid == noteOwnerId) return {'hasAccess': true, 'permission': 'owner', 'isOwner': true};

  final snapshot = await fs.FirebaseFirestore.instance
    .collection('shared_items')
        .where('itemId', isEqualTo: noteId)
        .where('ownerId', isEqualTo: noteOwnerId)
        .where('recipientId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: SharingStatus.accepted.name)
        .get();

    if (snapshot.docs.isEmpty) return {'hasAccess': false, 'isOwner': false};

    final sharing = SharedItem.fromMap(snapshot.docs.first.id, snapshot.docs.first.data());

    return {
      'hasAccess': true,
      'permission': sharing.permission.name,
      'isOwner': false,
      'sharingId': sharing.id,
      'sharedBy': sharing.ownerEmail,
    };
  }

  /// Simple helper to create a sharing for a folder (legacy API used in UI).
  /// Create a sharing for a folder. Backwards-compatible: callers can pass
  /// either a `recipient` map (new code) or a `recipientIdentifier` string
  /// (email or @username) used by older UI code.
  Future<String> shareFolder({Map<String, dynamic>? recipient, String? recipientIdentifier, required String folderId, required PermissionLevel permission, String? message}) async {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) throw const AuthenticationException();

    Map<String, dynamic>? finalRecipient = recipient;
    if (finalRecipient == null && recipientIdentifier != null) {
      finalRecipient = await findUserByEmail(recipientIdentifier) ?? await findUserByUsername(recipientIdentifier.replaceAll('@', ''));
    }

    if (finalRecipient == null) throw Exception('Recipient missing or not found');

    final folder = await FirestoreService.instance.getFolder(uid: currentUser.uid, folderId: folderId);
    if (folder == null) throw Exception('Carpeta no encontrada');

    final shareId = '${finalRecipient['uid']}_${currentUser.uid}_$folderId';
    final docRef = fs.FirebaseFirestore.instance.collection('shared_items').doc(shareId);
    final existing = await docRef.get();
    if (existing.exists) {
      final data = existing.data() as Map<String, dynamic>;
      final existingStatus = (data['status'] as String?) ?? 'pending';
      if (existingStatus == SharingStatus.pending.name || existingStatus == SharingStatus.accepted.name) {
        throw Exception('Esta carpeta ya está compartida con este usuario');
      }
    }

    final ownerProfile = await FirestoreService.instance.getUserProfile(uid: currentUser.uid);

    final sharedItem = SharedItem(
      id: shareId,
      itemId: folderId,
      type: SharedItemType.folder,
      ownerId: currentUser.uid,
      ownerEmail: ownerProfile?['email'] ?? currentUser.email ?? '',
      recipientId: finalRecipient['uid'],
      recipientEmail: finalRecipient['email'],
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

    await docRef.set(sharedItem.toMap());

    try {
      final notificationService = NotificationService();
      await notificationService.notifyNewShare(
        recipientId: finalRecipient['uid'],
        senderName: ownerProfile?['fullName'] ?? currentUser.email?.split('@').first ?? 'Usuario',
        senderEmail: currentUser.email ?? '',
        itemTitle: folder['name'] ?? 'Sin nombre',
        shareId: docRef.id,
        itemType: SharedItemType.folder,
      );
    } catch (e) {
      // ignore notification errors
    }

    return docRef.id;
  }
}
