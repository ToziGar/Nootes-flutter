import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'
  show kIsWeb, defaultTargetPlatform, TargetPlatform, kDebugMode, debugPrint;
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'auth_service.dart';
import '../firebase_options.dart';
import 'merge_utils.dart';
import 'field_timestamp_helper.dart';

abstract class FirestoreService {
  static FirestoreService? _instance;
  static FirestoreService get instance => _instance ??= _resolve();

  // Testing helper: allow injecting a fake implementation in tests.
  static set testInstance(FirestoreService? v) => _instance = v;

  static FirestoreService _resolve() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return _RestFirestoreService();
    }
    return _FirebaseFirestoreService();
  }

  /// Test helper: create a REST-backed instance and optionally inject a
  /// mock `http.Client` to intercept outgoing requests. This lets tests
  /// validate REST payloads without relying on the emulator or platform.
  static FirestoreService restTestInstance({http.Client? client}) {
    _RestFirestoreService.testClient = client;
    return _RestFirestoreService();
  }

  Future<void> reserveHandle({required String username, required String uid});
  Future<void> setUserProfile({
    required String uid,
    required Map<String, dynamic> data,
  });

  // Profiles (collection users)
  Future<List<Map<String, dynamic>>> listUserProfiles({int limit});
  Future<Map<String, dynamic>?> getUserProfile({required String uid});
  Future<void> updateUserProfile({
    required String uid,
    required Map<String, dynamic> data,
  });

  // Handles (collection handles)
  Future<List<Map<String, dynamic>>> listHandles({int limit});
  Future<Map<String, dynamic>?> getHandle({required String username});
  Future<void> changeHandle({required String uid, required String newUsername});

  // Notes APIs (subcollection users/{uid}/notes)
  Future<List<Map<String, dynamic>>> listNotes({required String uid});
  Future<Map<String, dynamic>?> getNote({
    required String uid,
    required String noteId,
  });
  Future<String> createNote({
    required String uid,
    required Map<String, dynamic> data,
  });
  Future<void> updateNote({
    required String uid,
    required String noteId,
    required Map<String, dynamic> data,
  });
  Future<void> deleteNote({required String uid, required String noteId});

  // Additional notes helpers used by the UI
  Future<List<Map<String, dynamic>>> listNotesSummary({required String uid});
  Future<List<Map<String, dynamic>>> searchNotesSummary({
    required String uid,
    required String query,
  });
  Future<void> setPinned({
    required String uid,
    required String noteId,
    required bool pinned,
  });
  Future<void> softDeleteNote({required String uid, required String noteId});
  Future<void> restoreNote({required String uid, required String noteId});
  Future<void> purgeNote({required String uid, required String noteId});
  Future<List<Map<String, dynamic>>> listTrashedNotesSummary({
    required String uid,
  });
  Future<List<Map<String, dynamic>>> listNotesPaginated({
    required String uid,
    int limit,
    String? startAfterId,
  });
  // ...existing code...

  // Collections (users/{uid}/collections)
  Future<List<Map<String, dynamic>>> listCollections({required String uid});
  Future<String> createCollection({
    required String uid,
    required Map<String, dynamic> data,
  });
  Future<void> updateCollection({
    required String uid,
    required String collectionId,
    required Map<String, dynamic> data,
  });
  Future<void> deleteCollection({
    required String uid,
    required String collectionId,
  });

  // Tags
  Future<List<String>> listTags({required String uid});
  Future<void> addTagToNote({
    required String uid,
    required String noteId,
    required String tag,
  });
  Future<void> removeTagFromNote({
    required String uid,
    required String noteId,
    required String tag,
  });

  // Links / graph
  Future<List<String>> listOutgoingLinks({
    required String uid,
    required String noteId,
  });
  Future<List<String>> listIncomingLinks({
    required String uid,
    required String noteId,
  });
  Future<void> addLink({
    required String uid,
    required String fromNoteId,
    required String toNoteId,
  });
  Future<void> removeLink({
    required String uid,
    required String fromNoteId,
    required String toNoteId,
  });
  Future<void> updateNoteLinks({
    required String uid,
    required String noteId,
    required List<String> linkedNoteIds,
  });
  Future<void> moveNoteToCollection({
    required String uid,
    required String noteId,
    String? collectionId,
  });
  Future<List<Map<String, String>>> listEdges({required String uid});
  // Edge documents with metadata (new): stored under users/{uid}/edges
  Future<List<Map<String, dynamic>>> listEdgeDocs({required String uid});
  Future<String> createEdgeDoc({
    required String uid,
    required Map<String, dynamic> data,
  });
  Future<void> updateEdgeDoc({
    required String uid,
    required String edgeId,
    required Map<String, dynamic> data,
  });
  Future<void> deleteEdgeDoc({required String uid, required String edgeId});

  // Folders (users/{uid}/folders)
  Future<List<Map<String, dynamic>>> listFolders({required String uid});
  Future<Map<String, dynamic>?> getFolder({
    required String uid,
    required String folderId,
  });
  Future<String> createFolder({
    required String uid,
    required Map<String, dynamic> data,
  });
  Future<void> updateFolder({
    required String uid,
    required String folderId,
    required Map<String, dynamic> data,
  });
  Future<void> deleteFolder({required String uid, required String folderId});
  Future<void> addNoteToFolder({
    required String uid,
    required String noteId,
    required String folderId,
  });
  Future<void> removeNoteFromFolder({
    required String uid,
    required String noteId,
    required String folderId,
  });

  // User settings (users/{uid}/settings)
  Future<Map<String, dynamic>?> getUserSettings({required String uid});
  Future<void> updateUserSettings({
    required String uid,
    required Map<String, dynamic> data,
  });
}

class _FirebaseFirestoreService implements FirestoreService {
  final _db = fs.FirebaseFirestore.instance;

  @override
  Future<List<Map<String, dynamic>>> listNotesPaginated({
    required String uid,
    int limit = 30,
    String? startAfterId,
  }) async {
    var query = _db
        .collection('users')
        .doc(uid)
        .collection('notes')
        .orderBy('updatedAt', descending: true);

    if (startAfterId != null && startAfterId.isNotEmpty) {
      final startDoc = await _db
          .collection('users')
          .doc(uid)
          .collection('notes')
          .doc(startAfterId)
          .get();
      if (startDoc.exists) {
        query = query.startAfterDocument(startDoc);
      }
    }

    final q = await query.limit(limit).get();
    return q.docs.map((d) {
      final data = d.data();
      return {
        'id': d.id,
        'title': data['title'] ?? '',
        'pinned': data['pinned'] ?? false,
        'icon': data['icon'],
        'iconColor': data['iconColor'],
        'collectionId': data['collectionId'],
        'tags':
            (data['tags'] as List?)?.whereType<String>().toList() ?? <String>[],
        'updatedAt': data['updatedAt'],
      };
    }).toList();
  }

  @override
  Future<void> reserveHandle({
    required String username,
    required String uid,
  }) async {
    final ref = _db.collection('handles').doc(username);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        throw Exception('handle-already-exists');
      }
      tx.set(ref, {'uid': uid, 'createdAt': fs.FieldValue.serverTimestamp()});
    });
  }

  @override
  Future<void> setUserProfile({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    final ref = _db.collection('users').doc(uid);
    await ref.set({
      ...data,
      'createdAt': fs.FieldValue.serverTimestamp(),
      'updatedAt': fs.FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<List<Map<String, dynamic>>> listUserProfiles({int limit = 50}) async {
    final q = await _db
        .collection('users')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return q.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  @override
  Future<Map<String, dynamic>?> getUserProfile({required String uid}) async {
    final d = await _db.collection('users').doc(uid).get();
    if (!d.exists) return null;
    return {'id': d.id, ...d.data()!};
  }

  @override
  Future<void> updateUserProfile({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    // Disallow username changes here; use changeHandle instead.
    final sanitized = Map<String, dynamic>.from(data)..remove('username');
    await _db.collection('users').doc(uid).set({
      ...sanitized,
      'updatedAt': fs.FieldValue.serverTimestamp(),
    }, fs.SetOptions(merge: true));
  }

  @override
  Future<List<Map<String, dynamic>>> listHandles({int limit = 50}) async {
    final q = await _db
        .collection('handles')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return q.docs.map((d) => {'username': d.id, ...d.data()}).toList();
  }

  @override
  Future<Map<String, dynamic>?> getHandle({required String username}) async {
    final d = await _db.collection('handles').doc(username).get();
    if (!d.exists) return null;
    return {'username': d.id, ...d.data()!};
  }

  @override
  Future<void> changeHandle({
    required String uid,
    required String newUsername,
  }) async {
    final newUser = newUsername.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9._]{3,20}$').hasMatch(newUser)) {
      throw Exception('invalid-username');
    }
    final handles = _db.collection('handles');
    final users = _db.collection('users');
    await _db.runTransaction((tx) async {
      // Ensure new handle doesn't exist
      final newRef = handles.doc(newUser);
      final newSnap = await tx.get(newRef);
      if (newSnap.exists) throw Exception('handle-already-exists');

      // Get current username from user profile
      final userRef = users.doc(uid);
      final userSnap = await tx.get(userRef);
      if (!userSnap.exists) throw Exception('user-not-found');
      final currentUsername = (userSnap.data()?['username'] as String?)
          ?.trim()
          .toLowerCase();
      if (currentUsername == null || currentUsername.isEmpty) {
        throw Exception('user-has-no-username');
      }
      if (currentUsername == newUser) return; // no-op

      // Ensure current handle doc matches uid
      final oldRef = handles.doc(currentUsername);
      final oldSnap = await tx.get(oldRef);
      if (!oldSnap.exists) {
        throw Exception('old-handle-not-found');
      }
      if (oldSnap.data()?['uid'] != uid) {
        throw Exception('old-handle-does-not-belong-to-user');
      }

      // Create new handle, update user, delete old handle
      tx.set(newRef, {
        'uid': uid,
        'createdAt': fs.FieldValue.serverTimestamp(),
      });
      tx.set(userRef, {
        'username': newUser,
        'updatedAt': fs.FieldValue.serverTimestamp(),
      }, fs.SetOptions(merge: true));
      tx.delete(oldRef);
    });
  }

  @override
  Future<List<Map<String, dynamic>>> listNotes({required String uid}) async {
    final q = await _db
        .collection('users')
        .doc(uid)
        .collection('notes')
        .orderBy('updatedAt', descending: true)
        .get();
    return q.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> listNotesSummary({
    required String uid,
  }) async {
    final q = await _db
        .collection('users')
        .doc(uid)
        .collection('notes')
        .orderBy('updatedAt', descending: true)
        .get();
    return q.docs.map((d) {
      final data = d.data();
      return {
        'id': d.id,
        'title': data['title'] ?? '',
        'pinned': data['pinned'] ?? false,
        'icon': data['icon'],
        'iconColor': data['iconColor'],
        'collectionId': data['collectionId'],
        'tags': data['tags'] ?? <String>[],
        'updatedAt': data['updatedAt'],
      };
    }).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> searchNotesSummary({
    required String uid,
    required String query,
  }) async {
    // Simple search by title contains (client-side fallback)
    final all = await listNotesSummary(uid: uid);
    final q = query.trim().toLowerCase();
    return all
        .where((n) => (n['title']?.toString() ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  Future<void> setPinned({
    required String uid,
    required String noteId,
    required bool pinned,
  }) async {
    await _db.collection('users').doc(uid).collection('notes').doc(noteId).set({
      'pinned': pinned,
      'updatedAt': fs.FieldValue.serverTimestamp(),
    }, fs.SetOptions(merge: true));
  }

  @override
  Future<void> softDeleteNote({
    required String uid,
    required String noteId,
  }) async {
    await _db.collection('users').doc(uid).collection('notes').doc(noteId).set({
      'trashed': true,
      'trashedAt': fs.FieldValue.serverTimestamp(),
      'updatedAt': fs.FieldValue.serverTimestamp(),
    }, fs.SetOptions(merge: true));
  }

  @override
  Future<void> restoreNote({
    required String uid,
    required String noteId,
  }) async {
    await _db.collection('users').doc(uid).collection('notes').doc(noteId).set({
      'trashed': false,
      'trashedAt': null,
      'updatedAt': fs.FieldValue.serverTimestamp(),
    }, fs.SetOptions(merge: true));
  }

  @override
  Future<void> purgeNote({required String uid, required String noteId}) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('notes')
        .doc(noteId)
        .delete();
  }

  @override
  Future<List<Map<String, dynamic>>> listTrashedNotesSummary({
    required String uid,
  }) async {
    final q = await _db
        .collection('users')
        .doc(uid)
        .collection('notes')
        .where('trashed', isEqualTo: true)
        .orderBy('trashedAt', descending: true)
        .get();
    return q.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> listCollections({
    required String uid,
  }) async {
    final q = await _db
        .collection('users')
        .doc(uid)
        .collection('collections')
        .orderBy('createdAt', descending: false)
        .get();
    return q.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  @override
  Future<String> createCollection({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    final col = _db.collection('users').doc(uid).collection('collections');
    final ref = await col.add({
      ...data,
      'createdAt': fs.FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  @override
  Future<void> updateCollection({
    required String uid,
    required String collectionId,
    required Map<String, dynamic> data,
  }) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('collections')
        .doc(collectionId)
        .set({
          ...data,
          'updatedAt': fs.FieldValue.serverTimestamp(),
        }, fs.SetOptions(merge: true));
  }

  @override
  Future<void> deleteCollection({
    required String uid,
    required String collectionId,
  }) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('collections')
        .doc(collectionId)
        .delete();
  }

  @override
  Future<List<String>> listTags({required String uid}) async {
    // Aggregate tags by scanning notes (could be optimized with a tags collection)
    final notes = await listNotes(uid: uid);
    final s = <String>{};
    for (final n in notes) {
      final tags = (n['tags'] as List?)?.whereType<String>() ?? const [];
      s.addAll(tags);
    }
    final list = s.toList()..sort();
    return list;
  }

  @override
  Future<void> addTagToNote({
    required String uid,
    required String noteId,
    required String tag,
  }) async {
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('notes')
        .doc(noteId);
    await ref.set({
      'tags': fs.FieldValue.arrayUnion([tag]),
      'updatedAt': fs.FieldValue.serverTimestamp(),
    }, fs.SetOptions(merge: true));
  }

  @override
  Future<void> removeTagFromNote({
    required String uid,
    required String noteId,
    required String tag,
  }) async {
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('notes')
        .doc(noteId);
    await ref.set({
      'tags': fs.FieldValue.arrayRemove([tag]),
      'updatedAt': fs.FieldValue.serverTimestamp(),
    }, fs.SetOptions(merge: true));
  }

  @override
  Future<List<String>> listOutgoingLinks({
    required String uid,
    required String noteId,
  }) async {
    final d = await getNote(uid: uid, noteId: noteId);
    return List<String>.from(
      (d?['links'] as List?)?.whereType<String>() ?? const [],
    );
  }

  @override
  Future<List<String>> listIncomingLinks({
    required String uid,
    required String noteId,
  }) async {
    final notes = await listNotes(uid: uid);
    final incoming = <String>[];
    for (final n in notes) {
      final links = (n['links'] as List?)?.whereType<String>() ?? const [];
      if (links.contains(noteId)) incoming.add(n['id'].toString());
    }
    return incoming;
  }

  @override
  Future<void> addLink({
    required String uid,
    required String fromNoteId,
    required String toNoteId,
  }) async {
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('notes')
        .doc(fromNoteId);
    await ref.set({
      'links': fs.FieldValue.arrayUnion([toNoteId]),
      'updatedAt': fs.FieldValue.serverTimestamp(),
    }, fs.SetOptions(merge: true));
  }

  @override
  Future<void> removeLink({
    required String uid,
    required String fromNoteId,
    required String toNoteId,
  }) async {
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('notes')
        .doc(fromNoteId);
    await ref.set({
      'links': fs.FieldValue.arrayRemove([toNoteId]),
      'updatedAt': fs.FieldValue.serverTimestamp(),
    }, fs.SetOptions(merge: true));
  }

  @override
  Future<void> updateNoteLinks({
    required String uid,
    required String noteId,
    required List<String> linkedNoteIds,
  }) async {
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('notes')
        .doc(noteId);
    await ref.set({
      'links': linkedNoteIds,
      'updatedAt': fs.FieldValue.serverTimestamp(),
    }, fs.SetOptions(merge: true));
  }

  @override
  Future<void> moveNoteToCollection({
    required String uid,
    required String noteId,
    String? collectionId,
  }) async {
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('notes')
        .doc(noteId);
    await ref.set({
      'collectionId': collectionId,
      'updatedAt': fs.FieldValue.serverTimestamp(),
    }, fs.SetOptions(merge: true));
  }

  @override
  Future<List<Map<String, String>>> listEdges({required String uid}) async {
    final notes = await listNotes(uid: uid);
    final edges = <Map<String, String>>[];
    for (final n in notes) {
      final from = n['id'].toString();
      final links = (n['links'] as List?)?.whereType<String>() ?? const [];
      for (final to in links) {
        edges.add({'from': from, 'to': to});
      }
    }
    return edges;
  }

  @override
  Future<List<Map<String, dynamic>>> listEdgeDocs({required String uid}) async {
    final q = await _db
        .collection('users')
        .doc(uid)
        .collection('edges')
        .orderBy('createdAt', descending: true)
        .get();
    return q.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  @override
  Future<String> createEdgeDoc({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    final col = _db.collection('users').doc(uid).collection('edges');
    final now = fs.FieldValue.serverTimestamp();
    final ref = await col.add({...data, 'createdAt': now, 'updatedAt': now});
    return ref.id;
  }

  @override
  Future<void> updateEdgeDoc({
    required String uid,
    required String edgeId,
    required Map<String, dynamic> data,
  }) async {
    await _db.collection('users').doc(uid).collection('edges').doc(edgeId).set({
      ...data,
      'updatedAt': fs.FieldValue.serverTimestamp(),
    }, fs.SetOptions(merge: true));
  }

  @override
  Future<void> deleteEdgeDoc({
    required String uid,
    required String edgeId,
  }) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('edges')
        .doc(edgeId)
        .delete();
  }

  @override
  Future<Map<String, dynamic>?> getNote({
    required String uid,
    required String noteId,
  }) async {
    final d = await _db
        .collection('users')
        .doc(uid)
        .collection('notes')
        .doc(noteId)
        .get();
    if (!d.exists) return null;
    return {'id': d.id, ...d.data()!};
  }

  @override
  Future<String> createNote({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    final col = _db.collection('users').doc(uid).collection('notes');
    final now = fs.FieldValue.serverTimestamp();
    final ref = await col.add({...data, 'createdAt': now, 'updatedAt': now});
    return ref.id;
  }

  @override
  Future<void> updateNote({
    required String uid,
    required String noteId,
    required Map<String, dynamic> data,
  }) async {
    final ref = _db.collection('users').doc(uid).collection('notes').doc(noteId);

    // Try to perform an atomic transaction-based merge to reduce race
    // conditions when multiple clients update the same document.
    // When offline, transactions may fail; in that case we fallback to a
    // merge set so the write is applied locally and will sync later.
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final current = snap.exists ? Map<String, dynamic>.from(snap.data()!) : <String, dynamic>{};

        // Use the smart merge utility to handle list unions and conservative
        // overwrites for other fields.
  var merged = mergeNoteMaps(current, data);

  // Attach per-field companion timestamps for scalar fields so the
  // merge utility's per-field LWW can operate deterministically.
  merged = attachFieldTimestamps(merged);

        // Annotate with server timestamp for canonical ordering and a
        // client-side timestamp to help offline reconciliation/debugging.
        merged['updatedAt'] = fs.FieldValue.serverTimestamp();
        merged['lastClientUpdateAt'] = DateTime.now().toUtc();

        tx.set(ref, merged, fs.SetOptions(merge: true));
      });
    } catch (e) {
      // Fallback for offline or transaction failures: merge locally and
      // set so the write takes effect and will sync later.
      var merged = mergeNoteMaps(<String, dynamic>{}, data);
      merged = attachFieldTimestamps(merged);
      merged['updatedAt'] = fs.FieldValue.serverTimestamp();
      merged['lastClientUpdateAt'] = DateTime.now().toUtc();
      await ref.set(merged, fs.SetOptions(merge: true));
    }
  }

  @override
  Future<void> deleteNote({required String uid, required String noteId}) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('notes')
        .doc(noteId)
        .delete();
  }

  // Folders
  @override
  Future<List<Map<String, dynamic>>> listFolders({required String uid}) async {
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('folders')
        .orderBy('order')
        .get();
    return snap.docs.map((d) {
      final data = d.data();
      return {
        ...data,
        'logicalId': data['id'], // conservar si existe
        'id': d.id, // Forzar id = docId para operaciones
        'docId': d.id,
        'folderId': d.id,
      };
    }).toList();
  }

  @override
  Future<Map<String, dynamic>?> getFolder({
    required String uid,
    required String folderId,
  }) async {
    final d = await _db
        .collection('users')
        .doc(uid)
        .collection('folders')
        .doc(folderId)
        .get();
    if (!d.exists) return null;
    return {'id': d.id, ...d.data()!};
  }

  @override
  Future<String> createFolder({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    final col = _db.collection('users').doc(uid).collection('folders');
    final now = fs.FieldValue.serverTimestamp();
    final ref = await col.add({
      ...data,
      'createdAt': now,
      'updatedAt': now,
      'noteIds': data['noteIds'] ?? [],
    });
    return ref.id;
  }

  @override
  Future<void> updateFolder({
    required String uid,
    required String folderId,
    required Map<String, dynamic> data,
  }) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('folders')
        .doc(folderId)
        .set({
          ...data,
          'updatedAt': fs.FieldValue.serverTimestamp(),
        }, fs.SetOptions(merge: true));
  }

  @override
  Future<void> deleteFolder({
    required String uid,
    required String folderId,
  }) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('folders')
        .doc(folderId)
        .delete();
  }

  @override
  Future<void> addNoteToFolder({
    required String uid,
    required String noteId,
    required String folderId,
  }) async {
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('folders')
        .doc(folderId);
    await ref.update({
      'noteIds': fs.FieldValue.arrayUnion([noteId]),
      'updatedAt': fs.FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> removeNoteFromFolder({
    required String uid,
    required String noteId,
    required String folderId,
  }) async {
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('folders')
        .doc(folderId);
    await ref.update({
      'noteIds': fs.FieldValue.arrayRemove([noteId]),
      'updatedAt': fs.FieldValue.serverTimestamp(),
    });
  }

  // ==================== USER SETTINGS ====================
  @override
  Future<Map<String, dynamic>?> getUserSettings({required String uid}) async {
    final d = await _db.collection('users').doc(uid).get();
    if (!d.exists) return null;
    final data = d.data();
    if (data == null) return null;
    final current = {
      if (data.containsKey('themeMode')) 'themeMode': data['themeMode'],
      if (data.containsKey('language')) 'language': data['language'],
      if (data.containsKey('notifications'))
        'notifications': data['notifications'],
      if (data.containsKey('autoSave')) 'autoSave': data['autoSave'],
      if (data.containsKey('backupEnabled'))
        'backupEnabled': data['backupEnabled'],
      if (data.containsKey('defaultView')) 'defaultView': data['defaultView'],
      if (data.containsKey('updatedAt')) 'updatedAt': data['updatedAt'],
    };
    if (current.isNotEmpty) return current;
    // Fallback: legacy location users/{uid}/meta/settings
    final legacy = await _db
        .collection('users')
        .doc(uid)
        .collection('meta')
        .doc('settings')
        .get();
    if (!legacy.exists) return null;
    return legacy.data();
  }

  @override
  Future<void> updateUserSettings({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    final ref = _db.collection('users').doc(uid);
    await ref.set({
      ...data,
      'updatedAt': fs.FieldValue.serverTimestamp(),
    }, fs.SetOptions(merge: true));
  }
}

class _RestFirestoreService implements FirestoreService {
  // Test hook: allow injecting a mock http.Client for tests that assert
  // outgoing REST payloads without requiring a running emulator.
  static http.Client? testClient;

  // Internal client used when no testClient is provided.
  final http.Client _internalClient = http.Client();

  http.Client get _client => testClient ?? _internalClient;
  String get _projectId => DefaultFirebaseOptions.web.projectId;
  String get _base {
    final emulator = Platform.environment['FIRESTORE_EMULATOR_HOST'];
    if (emulator != null && emulator.isNotEmpty) {
      return 'http://$emulator/v1/projects/$_projectId/databases/(default)/documents';
    }
    return 'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents';
  }

  Future<Map<String, String>> _authHeader() async {
    // When running against the local Firestore emulator the emulator does
    // not require (and may reject) real Authorization headers. Allow tests
    // and local runs to set FIRESTORE_EMULATOR_HOST so we avoid fetching a
    // real ID token and omit the Authorization header in that case. However
    // for local integration tests we may want the emulator to see an
    // authenticated request so security rules that require request.auth.uid
    // continue to work. If a test `AuthService` has been injected, include
    // a light-weight Authorization header containing the test user's uid
    // (the emulator accepts simple bearer values for testing).
    final emulator = Platform.environment['FIRESTORE_EMULATOR_HOST'];
    if (emulator != null && emulator.isNotEmpty) {
      final headers = <String, String>{'Content-Type': 'application/json'};
      try {
        // If tests installed a fake AuthService via AuthService.testInstance
        // then AuthService.instance will return that and we can embed the
        // uid in a minimal three-part JWT so the emulator accepts it and
        // populates request.auth.uid. The emulator expects a token with
        // three dot-separated parts; the signature can be empty for tests.
        final uid = AuthService.instance.currentUser?.uid;
        if (uid != null && uid.isNotEmpty) {
          headers['Authorization'] = 'Bearer ${_emulatorFakeJwt(uid)}';
        }
      } catch (_) {
        // If resolving AuthService triggers platform code, ignore and
        // continue without Authorization header.
      }
      return headers;
    }

    final token = await AuthService.instanceToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // ==================== USER SETTINGS (REST) ====================
  @override
  Future<Map<String, dynamic>?> getUserSettings({required String uid}) async {
    final headers = await _authHeader();
    final url = '$_base/users/$uid';
  final resp = await _client.get(Uri.parse(url), headers: headers);
    if (resp.statusCode == 404) return null;
    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final fields = _decodeFields(data['fields'] as Map<String, dynamic>?);
    final current = {
      if (fields.containsKey('themeMode')) 'themeMode': fields['themeMode'],
      if (fields.containsKey('language')) 'language': fields['language'],
      if (fields.containsKey('notifications'))
        'notifications': fields['notifications'],
      if (fields.containsKey('autoSave')) 'autoSave': fields['autoSave'],
      if (fields.containsKey('backupEnabled'))
        'backupEnabled': fields['backupEnabled'],
      if (fields.containsKey('defaultView'))
        'defaultView': fields['defaultView'],
      if (fields.containsKey('updatedAt')) 'updatedAt': fields['updatedAt'],
    };
    if (current.isNotEmpty) return current;
    // Fallback: legacy location users/{uid}/meta/settings
    final legacyUrl = '$_base/users/$uid/meta/settings';
  final legacyResp = await _client.get(Uri.parse(legacyUrl), headers: headers);
    if (legacyResp.statusCode != 200) return null;
    final legacyData = jsonDecode(legacyResp.body) as Map<String, dynamic>;
    return _decodeFields(legacyData['fields'] as Map<String, dynamic>?);
  }

  @override
  Future<void> updateUserSettings({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    final headers = await _authHeader();
    final fields = <String, dynamic>{};
    data.forEach((k, v) => fields[k] = _encodeValue(v));
    fields['updatedAt'] = _encodeValue(DateTime.now().toUtc());
    // Non-destructive patch to users/{uid}
    final updateMask = fields.keys
        .map((k) => 'updateMask.fieldPaths=${Uri.encodeQueryComponent(k)}')
        .join('&');
    final url = '$_base/users/$uid?$updateMask';
    final payload = jsonEncode({'fields': fields});
    final resp = await _client.patch(
      Uri.parse(url),
      headers: headers,
      body: payload,
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('firestore-update-user-${resp.statusCode}');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listNotesPaginated({
    required String uid,
    int limit = 30,
    String? startAfterId,
  }) async {
    // Fallback simple: utilizar listNotesSummary y paginar en cliente
    final all = await listNotesSummary(uid: uid);
    if (startAfterId != null && startAfterId.isNotEmpty) {
      final startIndex = all.indexWhere((e) => e['id'] == startAfterId);
      final sliceStart = startIndex >= 0 ? startIndex + 1 : 0;
      return all.skip(sliceStart).take(limit).toList();
    }
    return all.take(limit).toList();
  }

  @override
  Future<void> reserveHandle({
    required String username,
    required String uid,
  }) async {
    final uri = Uri.parse('$_base/handles?documentId=$username');
    final body = jsonEncode({
      'fields': {
        'uid': {'stringValue': uid},
        'createdAt': {
          'timestampValue': DateTime.now().toUtc().toIso8601String(),
        },
      },
    });
  final resp = await _client.post(uri, headers: await _authHeader(), body: body);
    if (resp.statusCode == 409) {
      throw Exception('handle-already-exists');
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('firestore-handle-failed-${resp.statusCode}');
    }
  }

  @override
  Future<void> setUserProfile({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    final uri = Uri.parse('$_base/users?documentId=$uid');
    final fields = <String, dynamic>{};
    data.forEach((key, value) {
      fields[key] = _encodeValue(value);
    });
    fields['createdAt'] = {
      'timestampValue': DateTime.now().toUtc().toIso8601String(),
    };
    fields['updatedAt'] = {
      'timestampValue': DateTime.now().toUtc().toIso8601String(),
    };
    final body = jsonEncode({'fields': fields});
  final resp = await _client.post(uri, headers: await _authHeader(), body: body);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('firestore-user-failed-${resp.statusCode}');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listUserProfiles({int limit = 50}) async {
    final uri = Uri.parse('$_base/users');
  final resp = await _client.get(uri, headers: await _authHeader());
    if (resp.statusCode != 200) return [];
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final docs = (data['documents'] as List?) ?? [];
    final list = docs.map<Map<String, dynamic>>((d) {
      final name = d['name']?.toString() ?? '';
      final id = name.split('/').last;
      final fields = _decodeFields(d['fields'] as Map<String, dynamic>?);
      return {'id': id, ...fields};
    }).toList();
    if (list.length > limit) return list.sublist(0, limit);
    return list;
  }

  @override
  Future<Map<String, dynamic>?> getUserProfile({required String uid}) async {
    final uri = Uri.parse('$_base/users/$uid');
  final resp = await _client.get(uri, headers: await _authHeader());
    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final fields = _decodeFields(data['fields'] as Map<String, dynamic>?);
    return {'id': uid, ...fields};
  }

  @override
  Future<void> updateUserProfile({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    final fields = <String, dynamic>{};
    final updateMask = <String>[];
    data.forEach((k, v) {
      if (k == 'username') return; // forbid here; use changeHandle
      fields[k] = _encodeValue(v);
      updateMask.add(k);
    });
    // Always bump updatedAt
    fields['updatedAt'] = {
      'timestampValue': DateTime.now().toUtc().toIso8601String(),
    };
    updateMask.add('updatedAt');
    final qs = updateMask
        .map((f) => 'updateMask.fieldPaths=${Uri.encodeQueryComponent(f)}')
        .join('&');
    final uri = Uri.parse('$_base/users/$uid?$qs');
    final body = jsonEncode({'fields': fields});
    final resp = await _client.patch(
      uri,
      headers: await _authHeader(),
      body: body,
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('firestore-update-user-${resp.statusCode}');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listHandles({int limit = 50}) async {
    final uri = Uri.parse('$_base/handles');
  final resp = await _client.get(uri, headers: await _authHeader());
    if (resp.statusCode != 200) return [];
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final docs = (data['documents'] as List?) ?? [];
    final list = docs.map<Map<String, dynamic>>((d) {
      final name = d['name']?.toString() ?? '';
      final username = name.split('/').last;
      final fields = _decodeFields(d['fields'] as Map<String, dynamic>?);
      return {'username': username, ...fields};
    }).toList();
    if (list.length > limit) return list.sublist(0, limit);
    return list;
  }

  @override
  Future<Map<String, dynamic>?> getHandle({required String username}) async {
    final uri = Uri.parse('$_base/handles/$username');
  final resp = await _client.get(uri, headers: await _authHeader());
    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final fields = _decodeFields(data['fields'] as Map<String, dynamic>?);
    return {'username': username, ...fields};
  }

  @override
  Future<void> changeHandle({
    required String uid,
    required String newUsername,
  }) async {
    final newUser = newUsername.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9._]{3,20}$').hasMatch(newUser)) {
      throw Exception('invalid-username');
    }
    // 1) Check new handle doesn't exist
    final exists = await getHandle(username: newUser);
    if (exists != null) throw Exception('handle-already-exists');

    // 2) Get current username from user profile
    final profile = await getUserProfile(uid: uid);
    final currentUsername = (profile?['username'] as String?)
        ?.trim()
        .toLowerCase();
    if (currentUsername == null || currentUsername.isEmpty) {
      throw Exception('user-has-no-username');
    }
    if (currentUsername == newUser) return;

    // 3) Create new handle
    final createUri = Uri.parse('$_base/handles?documentId=$newUser');
    final createBody = jsonEncode({
      'fields': {
        'uid': {'stringValue': uid},
        'createdAt': {
          'timestampValue': DateTime.now().toUtc().toIso8601String(),
        },
      },
    });
    final createResp = await _client.post(
      createUri,
      headers: await _authHeader(),
      body: createBody,
    );
    if (createResp.statusCode < 200 || createResp.statusCode >= 300) {
      if (createResp.statusCode == 409) {
        throw Exception('handle-already-exists');
      }
      throw Exception('firestore-create-handle-${createResp.statusCode}');
    }

    try {
      // 4) Update user document's username (explicit mask)
      final qs =
          'updateMask.fieldPaths=username&updateMask.fieldPaths=updatedAt';
      final uri = Uri.parse('$_base/users/$uid?$qs');
      final body = jsonEncode({
        'fields': {
          'username': {'stringValue': newUser},
          'updatedAt': {
            'timestampValue': DateTime.now().toUtc().toIso8601String(),
          },
        },
      });
      final patchResp = await _client.patch(
        uri,
        headers: await _authHeader(),
        body: body,
      );
      if (patchResp.statusCode < 200 || patchResp.statusCode >= 300) {
        throw Exception('firestore-update-username-${patchResp.statusCode}');
      }

      // 5) Delete old handle
      final delUri = Uri.parse('$_base/handles/$currentUsername');
  final delResp = await _client.delete(delUri, headers: await _authHeader());
      if (delResp.statusCode < 200 || delResp.statusCode >= 300) {
        throw Exception('firestore-delete-old-handle-${delResp.statusCode}');
      }
    } catch (e) {
      // Rollback: try delete new handle if something failed
      try {
        final delUri = Uri.parse('$_base/handles/$newUser');
  await _client.delete(delUri, headers: await _authHeader());
      } catch (_) {}
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listNotes({required String uid}) async {
    final uri = Uri.parse('$_base/users/$uid/notes');
  final resp = await _client.get(uri, headers: await _authHeader());
    if (resp.statusCode != 200) return [];
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final docs = (data['documents'] as List?) ?? [];
    return docs.map<Map<String, dynamic>>((d) {
      final name = d['name']?.toString() ?? '';
      final id = name.split('/').last;
      final fields = _decodeFields(d['fields'] as Map<String, dynamic>?);
      return {'id': id, ...fields};
    }).toList();
  }

  @override
  Future<Map<String, dynamic>?> getNote({
    required String uid,
    required String noteId,
  }) async {
    final uri = Uri.parse('$_base/users/$uid/notes/$noteId');
  final resp = await _client.get(uri, headers: await _authHeader());
    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final fields = _decodeFields(data['fields'] as Map<String, dynamic>?);
    return {'id': noteId, ...fields};
  }

  @override
  Future<String> createNote({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    final uri = Uri.parse('$_base/users/$uid/notes');
    final fields = <String, dynamic>{};
    data.forEach((k, v) => fields[k] = _encodeValue(v));
    final body = jsonEncode({'fields': fields});
    final headers = await _authHeader();
  final resp = await _client.post(uri, headers: headers, body: body);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      // Debug: emit request/response details to help diagnose emulator errors
      if (kDebugMode) {
        try {
          debugPrint('DEBUG firestore.createNote failed: url=${uri.toString()}');
          debugPrint('DEBUG request.headers=${headers}');
          debugPrint('DEBUG request.body=${body}');
          debugPrint('DEBUG response.status=${resp.statusCode}');
          debugPrint('DEBUG response.body=${resp.body}');
        } catch (_) {}
      }
      throw Exception('firestore-create-note-${resp.statusCode}');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final name = json['name']?.toString() ?? '';
    return name.split('/').last;
  }

  @override
  Future<List<Map<String, dynamic>>> listNotesSummary({
    required String uid,
  }) async {
    final list = await listNotes(uid: uid);
    return list
        .map(
          (d) => {
            'id': d['id'],
            'title': d['title'] ?? '',
            'pinned': d['pinned'] ?? false,
            'icon': d['icon'],
            'iconColor': d['iconColor'],
            'collectionId': d['collectionId'],
            'tags': d['tags'] ?? <String>[],
            'updatedAt': d['updatedAt'],
          },
        )
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> searchNotesSummary({
    required String uid,
    required String query,
  }) async {
    final all = await listNotesSummary(uid: uid);
    final q = query.trim().toLowerCase();
    return all
        .where((n) => (n['title']?.toString() ?? '').toLowerCase().contains(q))
        .toList();
  }

  Future<void> _patchNoteFields(
    String uid,
    String noteId,
    Map<String, dynamic> fields,
  ) async {
    // Ensure updatedAt is always bumped
    final patched = Map<String, dynamic>.from(fields);

    // Attach per-field companion timestamps for scalar fields so clients
    // using per-field LWW have the metadata they need. We only add for
    // scalar encoded values (stringValue, integerValue, doubleValue,
    // booleanValue, nullValue, timestampValue). Skip keys that already
    // look like companion timestamps or metadata.
    for (final key in fields.keys.toList()) {
      if (key.endsWith('_lastClientUpdateAt') || key.endsWith('_updatedAt')) continue;
      final v = fields[key];
      bool isScalarEncoded = false;
      if (v is Map<String, dynamic>) {
        if (v.containsKey('stringValue') ||
            v.containsKey('integerValue') ||
            v.containsKey('doubleValue') ||
            v.containsKey('booleanValue') ||
            v.containsKey('nullValue') ||
            v.containsKey('timestampValue')) {
          isScalarEncoded = true;
        }
      }
      if (isScalarEncoded) {
        // Use the same encoding helper so Firestore REST accepts the value
        patched['${key}_lastClientUpdateAt'] = _encodeValue(DateTime.now().toUtc());
      }
    }

    // Always bump map-level updatedAt
    patched['updatedAt'] = _encodeValue(DateTime.now().toUtc());
    // Build update mask so only provided fields are modified (non-destructive)
    final qs = patched.keys
        .map((k) => 'updateMask.fieldPaths=${Uri.encodeQueryComponent(k)}')
        .join('&');
    final uri = Uri.parse('$_base/users/$uid/notes/$noteId?$qs');
    final body = jsonEncode({'fields': patched});
    final resp = await _client.patch(
      uri,
      headers: await _authHeader(),
      body: body,
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('firestore-patch-note-${resp.statusCode}');
    }
  }

  @override
  Future<void> setPinned({
    required String uid,
    required String noteId,
    required bool pinned,
  }) async {
    await _patchNoteFields(uid, noteId, {
      'pinned': _encodeValue(pinned),
      'updatedAt': _encodeValue(DateTime.now().toUtc()),
    });
  }

  @override
  Future<void> softDeleteNote({
    required String uid,
    required String noteId,
  }) async {
    await _patchNoteFields(uid, noteId, {
      'trashed': _encodeValue(true),
      'trashedAt': _encodeValue(DateTime.now().toUtc()),
      'updatedAt': _encodeValue(DateTime.now().toUtc()),
    });
  }

  @override
  Future<void> restoreNote({
    required String uid,
    required String noteId,
  }) async {
    await _patchNoteFields(uid, noteId, {
      'trashed': _encodeValue(false),
      'trashedAt': _encodeValue(null),
      'updatedAt': _encodeValue(DateTime.now().toUtc()),
    });
  }

  @override
  Future<void> purgeNote({required String uid, required String noteId}) async {
    final uri = Uri.parse('$_base/users/$uid/notes/$noteId');
  final resp = await _client.delete(uri, headers: await _authHeader());
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('firestore-delete-note-${resp.statusCode}');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listTrashedNotesSummary({
    required String uid,
  }) async {
    final all = await listNotes(uid: uid);
    return all
        .where((d) => d['trashed'] == true)
        .map((d) => {'id': d['id'], ...d})
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> listCollections({
    required String uid,
  }) async {
    final uri = Uri.parse('$_base/users/$uid/collections');
  final resp = await _client.get(uri, headers: await _authHeader());
    if (resp.statusCode != 200) return [];
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final docs = (data['documents'] as List?) ?? [];
    return docs.map<Map<String, dynamic>>((d) {
      final name = d['name']?.toString() ?? '';
      final id = name.split('/').last;
      final fields = _decodeFields(d['fields'] as Map<String, dynamic>?);
      return {'id': id, ...fields};
    }).toList();
  }

  @override
  Future<String> createCollection({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    final uri = Uri.parse('$_base/users/$uid/collections');
    final fields = <String, dynamic>{};
    data.forEach((k, v) => fields[k] = _encodeValue(v));
    fields['createdAt'] = _encodeValue(DateTime.now().toUtc());
    final body = jsonEncode({'fields': fields});
  final resp = await _client.post(uri, headers: await _authHeader(), body: body);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('firestore-create-collection-${resp.statusCode}');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final name = json['name']?.toString() ?? '';
    return name.split('/').last;
  }

  @override
  Future<void> updateCollection({
    required String uid,
    required String collectionId,
    required Map<String, dynamic> data,
  }) async {
    final qs = data.keys
        .map((k) => 'updateMask.fieldPaths=${Uri.encodeQueryComponent(k)}')
        .join('&');
    final uri = Uri.parse('$_base/users/$uid/collections/$collectionId?$qs');
    final fields = <String, dynamic>{};
    data.forEach((k, v) => fields[k] = _encodeValue(v));
    fields['updatedAt'] = _encodeValue(DateTime.now().toUtc());
    final body = jsonEncode({'fields': fields});
    final resp = await _client.patch(
      uri,
      headers: await _authHeader(),
      body: body,
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('firestore-update-collection-${resp.statusCode}');
    }
  }

  @override
  Future<void> deleteCollection({
    required String uid,
    required String collectionId,
  }) async {
    final uri = Uri.parse('$_base/users/$uid/collections/$collectionId');
  final resp = await _client.delete(uri, headers: await _authHeader());
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('firestore-delete-collection-${resp.statusCode}');
    }
  }

  @override
  Future<List<String>> listTags({required String uid}) async {
    final notes = await listNotes(uid: uid);
    final s = <String>{};
    for (final n in notes) {
      final tags = (n['tags'] as List?)?.whereType<String>() ?? const [];
      s.addAll(tags);
    }
    final list = s.toList()..sort();
    return list;
  }

  Future<void> _arrayOp(
    String uid,
    String noteId,
    String field,
    List<String> values, {
    required bool add,
  }) async {
    // Firestore REST doesn't have arrayUnion/arrayRemove via simple patch; use get, modify, patch
    final current = await getNote(uid: uid, noteId: noteId);
    final arr = List<String>.from(
      (current?[field] as List?)?.whereType<String>() ?? [],
    );
    if (add) {
      for (final v in values) {
        if (!arr.contains(v)) arr.add(v);
      }
    } else {
      arr.removeWhere((e) => values.contains(e));
    }
    final fields = {
      field: _encodeValue(arr),
      'updatedAt': _encodeValue(DateTime.now().toUtc()),
    };
    await _patchNoteFields(uid, noteId, fields);
  }

  @override
  Future<void> addTagToNote({
    required String uid,
    required String noteId,
    required String tag,
  }) async {
    await _arrayOp(uid, noteId, 'tags', [tag], add: true);
  }

  @override
  Future<void> removeTagFromNote({
    required String uid,
    required String noteId,
    required String tag,
  }) async {
    await _arrayOp(uid, noteId, 'tags', [tag], add: false);
  }

  @override
  Future<List<String>> listOutgoingLinks({
    required String uid,
    required String noteId,
  }) async {
    final n = await getNote(uid: uid, noteId: noteId);
    return List<String>.from(
      (n?['links'] as List?)?.whereType<String>() ?? const [],
    );
  }

  @override
  Future<List<String>> listIncomingLinks({
    required String uid,
    required String noteId,
  }) async {
    final notes = await listNotes(uid: uid);
    final incoming = <String>[];
    for (final n in notes) {
      final links = (n['links'] as List?)?.whereType<String>() ?? const [];
      if (links.contains(noteId)) incoming.add(n['id'].toString());
    }
    return incoming;
  }

  @override
  Future<void> addLink({
    required String uid,
    required String fromNoteId,
    required String toNoteId,
  }) async {
    await _arrayOp(uid, fromNoteId, 'links', [toNoteId], add: true);
  }

  @override
  Future<void> removeLink({
    required String uid,
    required String fromNoteId,
    required String toNoteId,
  }) async {
    await _arrayOp(uid, fromNoteId, 'links', [toNoteId], add: false);
  }

  @override
  Future<void> updateNoteLinks({
    required String uid,
    required String noteId,
    required List<String> linkedNoteIds,
  }) async {
    final fields = <String, dynamic>{'links': _encodeValue(linkedNoteIds)};
    fields['updatedAt'] = _encodeValue(DateTime.now().toUtc());
    await _patchNoteFields(uid, noteId, fields);
  }

  @override
  Future<void> moveNoteToCollection({
    required String uid,
    required String noteId,
    String? collectionId,
  }) async {
    final fields = <String, dynamic>{
      'collectionId': _encodeValue(collectionId),
    };
    fields['updatedAt'] = _encodeValue(DateTime.now().toUtc());
    await _patchNoteFields(uid, noteId, fields);
  }

  @override
  Future<List<Map<String, String>>> listEdges({required String uid}) async {
    final notes = await listNotes(uid: uid);
    final edges = <Map<String, String>>[];
    for (final n in notes) {
      final from = n['id'].toString();
      final links = (n['links'] as List?)?.whereType<String>() ?? const [];
      for (final to in links) {
        edges.add({'from': from, 'to': to});
      }
    }
    return edges;
  }

  @override
  Future<void> updateNote({
    required String uid,
    required String noteId,
    required Map<String, dynamic> data,
  }) async {
    // Use the shared _patchNoteFields helper which attaches per-field
    // companion timestamps for scalar values and constructs the proper
    // updateMask. This keeps REST behavior consistent with the SDK path.
    final fields = <String, dynamic>{};
    data.forEach((k, v) => fields[k] = _encodeValue(v));
    await _patchNoteFields(uid, noteId, fields);
  }

  @override
  Future<void> deleteNote({required String uid, required String noteId}) async {
    final uri = Uri.parse('$_base/users/$uid/notes/$noteId');
  final resp = await _client.delete(uri, headers: await _authHeader());
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('firestore-delete-note-${resp.statusCode}');
    }
  }

  dynamic _encodeValue(dynamic value) {
    if (value == null) return {'nullValue': null};
    if (value is String) return {'stringValue': value};
    if (value is bool) return {'booleanValue': value};
    // Use integerValue for ints and doubleValue for doubles
    if (value is int) return {'integerValue': value.toString()};
    if (value is double) return {'doubleValue': value};
    if (value is DateTime) {
      return {'timestampValue': value.toUtc().toIso8601String()};
    }
    // Map server timestamp markers from SDK to a timestamp
    if (value is fs.FieldValue) {
      return {'timestampValue': DateTime.now().toUtc().toIso8601String()};
    }
    if (value is List) {
      return {
        'arrayValue': {'values': value.map((e) => _encodeValue(e)).toList()},
      };
    }
    // Fallback to string
    return {'stringValue': value?.toString() ?? ''};
  }

  Map<String, dynamic> _decodeFields(Map<String, dynamic>? fields) {
    final result = <String, dynamic>{};
    if (fields == null) return result;
    for (final entry in fields.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        if (value.containsKey('stringValue')) {
          result[key] = value['stringValue'];
        } else if (value.containsKey('booleanValue')) {
          result[key] = value['booleanValue'];
        } else if (value.containsKey('doubleValue')) {
          result[key] = value['doubleValue'];
        } else if (value.containsKey('integerValue')) {
          result[key] = int.tryParse(value['integerValue'].toString());
        } else if (value.containsKey('timestampValue')) {
          result[key] = value['timestampValue'];
        } else if (value.containsKey('nullValue')) {
          result[key] = null;
        } else if (value.containsKey('arrayValue')) {
          final arr = value['arrayValue'] as Map<String, dynamic>?;
          final vals = arr?['values'] as List? ?? [];
          result[key] = vals
              .map(
                (e) =>
                    (e as Map<String, dynamic>)['stringValue'] ?? e.toString(),
              )
              .toList();
        } else {
          result[key] = value.toString();
        }
      }
    }
    return result;
  }

  // Folders - REST API implementation
  @override
  Future<List<Map<String, dynamic>>> listFolders({required String uid}) async {
    final headers = await _authHeader();
    final url = '$_base/users/$uid/folders?orderBy=order';
  final resp = await _client.get(Uri.parse(url), headers: headers);
    if (resp.statusCode != 200) return [];
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final docs =
        (data['documents'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return docs.map((d) {
      final id = (d['name'] as String).split('/').last;
      final fields = _decodeFields(d['fields'] as Map<String, dynamic>?);
      return {
        ...fields,
        'logicalId': fields['id'],
        'id': id,
        'docId': id, // Firestore document ID (needed for delete operations)
        'folderId': id, // Usar SIEMPRE el ID de documento
      };
    }).toList();
  }

  @override
  Future<Map<String, dynamic>?> getFolder({
    required String uid,
    required String folderId,
  }) async {
    final headers = await _authHeader();
    final url = '$_base/users/$uid/folders/$folderId';
  final resp = await _client.get(Uri.parse(url), headers: headers);
    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final id = (data['name'] as String).split('/').last;
    final fields = _decodeFields(data['fields'] as Map<String, dynamic>?);
    return {'id': id, ...fields};
  }

  @override
  Future<String> createFolder({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    final headers = await _authHeader();
    final url = '$_base/users/$uid/folders';
    final now = DateTime.now().toUtc();
    final fields = <String, dynamic>{};
    data.forEach((k, v) => fields[k] = _encodeValue(v));
    fields['noteIds'] = _encodeValue(data['noteIds'] ?? []);
    fields['createdAt'] = _encodeValue(now);
    fields['updatedAt'] = _encodeValue(now);
    final payload = {'fields': fields};
    final resp = await _client.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(payload),
    );
    if (resp.statusCode != 200) throw Exception('Failed to create folder');
    final respData = jsonDecode(resp.body) as Map<String, dynamic>;
    final id = (respData['name'] as String).split('/').last;
    return id;
  }

  @override
  Future<void> updateFolder({
    required String uid,
    required String folderId,
    required Map<String, dynamic> data,
  }) async {
    final headers = await _authHeader();
    final url = '$_base/users/$uid/folders/$folderId';
    final now = DateTime.now().toUtc();
    final fields = <String, dynamic>{};
    for (final entry in data.entries) {
      fields[entry.key] = _encodeValue(entry.value);
    }
    fields['updatedAt'] = _encodeValue(now);

    final updateMask = [...data.keys, 'updatedAt'];
    final qs = updateMask
        .map((f) => 'updateMask.fieldPaths=${Uri.encodeQueryComponent(f)}')
        .join('&');
    final urlWithMask = '$url?$qs';

    final payload = {'fields': fields};
    final resp = await _client.patch(
      Uri.parse(urlWithMask),
      headers: headers,
      body: jsonEncode(payload),
    );
    if (resp.statusCode != 200) throw Exception('Failed to update folder');
  }

  @override
  Future<void> deleteFolder({
    required String uid,
    required String folderId,
  }) async {
    final headers = await _authHeader();
    final url = '$_base/users/$uid/folders/$folderId';
  final resp = await _client.delete(Uri.parse(url), headers: headers);
    if (resp.statusCode != 200) throw Exception('Failed to delete folder');
  }

  @override
  Future<void> addNoteToFolder({
    required String uid,
    required String noteId,
    required String folderId,
  }) async {
    final folder = await getFolder(uid: uid, folderId: folderId);
    if (folder == null) throw Exception('Folder not found');
    final noteIds = List<String>.from(
      (folder['noteIds'] as List?)?.cast<String>() ?? [],
    );
    if (!noteIds.contains(noteId)) {
      noteIds.add(noteId);
      await updateFolder(
        uid: uid,
        folderId: folderId,
        data: {'noteIds': noteIds},
      );
    }
  }

  @override
  Future<void> removeNoteFromFolder({
    required String uid,
    required String noteId,
    required String folderId,
  }) async {
    final folder = await getFolder(uid: uid, folderId: folderId);
    if (folder == null) throw Exception('Folder not found');
    final noteIds = List<String>.from(
      (folder['noteIds'] as List?)?.cast<String>() ?? [],
    );
    noteIds.remove(noteId);
    await updateFolder(
      uid: uid,
      folderId: folderId,
      data: {'noteIds': noteIds},
    );
  }

  // Edge documents - REST API implementation
  @override
  Future<List<Map<String, dynamic>>> listEdgeDocs({required String uid}) async {
    final headers = await _authHeader();
    final url = '$_base/users/$uid/edges?orderBy=createdAt';
  final resp = await _client.get(Uri.parse(url), headers: headers);
    if (resp.statusCode != 200) return [];
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final docs =
        (data['documents'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return docs.map((d) {
      final id = (d['name'] as String).split('/').last;
      final fields = _decodeFields(d['fields'] as Map<String, dynamic>?);
      return {'id': id, ...fields};
    }).toList();
  }

  @override
  Future<String> createEdgeDoc({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    final headers = await _authHeader();
    final url = '$_base/users/$uid/edges';
    final now = DateTime.now().toUtc();
    final fields = <String, dynamic>{};
    data.forEach((k, v) => fields[k] = _encodeValue(v));
    fields['createdAt'] = _encodeValue(now);
    fields['updatedAt'] = _encodeValue(now);
    final payload = {'fields': fields};
    final resp = await _client.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(payload),
    );
    if (resp.statusCode != 200) throw Exception('Failed to create edge doc');
    final respData = jsonDecode(resp.body) as Map<String, dynamic>;
    final id = (respData['name'] as String).split('/').last;
    return id;
  }

  @override
  Future<void> updateEdgeDoc({
    required String uid,
    required String edgeId,
    required Map<String, dynamic> data,
  }) async {
    final headers = await _authHeader();
    final url = '$_base/users/$uid/edges/$edgeId';
    final now = DateTime.now().toUtc();
    final fields = <String, dynamic>{};
    for (final entry in data.entries) {
      fields[entry.key] = _encodeValue(entry.value);
    }
    fields['updatedAt'] = _encodeValue(now);

    final updateMask = [...data.keys, 'updatedAt'];
    final qs = updateMask
        .map((f) => 'updateMask.fieldPaths=${Uri.encodeQueryComponent(f)}')
        .join('&');
    final urlWithMask = '$url?$qs';

    final payload = {'fields': fields};
    final resp = await _client.patch(
      Uri.parse(urlWithMask),
      headers: headers,
      body: jsonEncode(payload),
    );
    if (resp.statusCode != 200) throw Exception('Failed to update edge doc');
  }

  @override
  Future<void> deleteEdgeDoc({
    required String uid,
    required String edgeId,
  }) async {
    final headers = await _authHeader();
    final url = '$_base/users/$uid/edges/$edgeId';
  final resp = await _client.delete(Uri.parse(url), headers: headers);
    if (resp.statusCode != 200) throw Exception('Failed to delete edge doc');
  }
}

  /// Build a minimal, non-signed JWT payload for the emulator which only
  /// needs to be well-formed (three parts separated by dots). The payload
  /// includes user identifying fields the emulator looks for (user_id/sub).
  String _emulatorFakeJwt(String uid) {
    final header = {'alg': 'none', 'typ': 'JWT'};
    final payload = {
      'user_id': uid,
      'sub': uid,
      'iat': (DateTime.now().millisecondsSinceEpoch ~/ 1000)
    };
    String b64(Map m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
    final h = b64(header);
    final p = b64(payload);
    // signature left empty (still produces three parts: header.payload.)
    return '$h.$p.';
  }
