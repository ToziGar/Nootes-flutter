import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart' as fs;

import 'auth_service.dart';
import '../firebase_options.dart';

abstract class FirestoreService {
  static FirestoreService? _instance;
  static FirestoreService get instance => _instance ??= _resolve();

  static FirestoreService _resolve() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return _RestFirestoreService();
    }
    return _FirebaseFirestoreService();
  }

  Future<void> reserveHandle({required String username, required String uid});
  Future<void> setUserProfile({
    required String uid,
    required Map<String, dynamic> data,
  });
  
  // Profiles (collection users)
  Future<List<Map<String, dynamic>>> listUserProfiles({int limit});
  Future<Map<String, dynamic>?> getUserProfile({required String uid});
  Future<void> updateUserProfile({required String uid, required Map<String, dynamic> data});

  // Handles (collection handles)
  Future<List<Map<String, dynamic>>> listHandles({int limit});
  Future<Map<String, dynamic>?> getHandle({required String username});
  Future<void> changeHandle({required String uid, required String newUsername});

  // Notes APIs (subcollection users/{uid}/notes)
  Future<List<Map<String, dynamic>>> listNotes({required String uid});
  Future<Map<String, dynamic>?> getNote({required String uid, required String noteId});
  Future<String> createNote({required String uid, required Map<String, dynamic> data});
  Future<void> updateNote({required String uid, required String noteId, required Map<String, dynamic> data});
  Future<void> deleteNote({required String uid, required String noteId});
  
  // Additional notes helpers used by the UI
  Future<List<Map<String, dynamic>>> listNotesSummary({required String uid});
  Future<List<Map<String, dynamic>>> searchNotesSummary({required String uid, required String query});
  Future<void> setPinned({required String uid, required String noteId, required bool pinned});

  // Soft-delete / trash
  Future<void> softDeleteNote({required String uid, required String noteId});
  Future<void> restoreNote({required String uid, required String noteId});
  Future<void> purgeNote({required String uid, required String noteId});
  Future<List<Map<String, dynamic>>> listTrashedNotesSummary({required String uid});

  // Collections (users/{uid}/collections)
  Future<List<Map<String, dynamic>>> listCollections({required String uid});
  Future<String> createCollection({required String uid, required Map<String, dynamic> data});
  Future<void> updateCollection({required String uid, required String collectionId, required Map<String, dynamic> data});
  Future<void> deleteCollection({required String uid, required String collectionId});

  // Tags
  Future<List<String>> listTags({required String uid});
  Future<void> addTagToNote({required String uid, required String noteId, required String tag});
  Future<void> removeTagFromNote({required String uid, required String noteId, required String tag});

  // Links / graph
  Future<List<String>> listOutgoingLinks({required String uid, required String noteId});
  Future<List<String>> listIncomingLinks({required String uid, required String noteId});
  Future<void> addLink({required String uid, required String fromNoteId, required String toNoteId});
  Future<void> removeLink({required String uid, required String fromNoteId, required String toNoteId});
  Future<void> updateNoteLinks({required String uid, required String noteId, required List<String> linkedNoteIds});
  Future<void> moveNoteToCollection({required String uid, required String noteId, String? collectionId});
  Future<List<Map<String, String>>> listEdges({required String uid});
  // Edge documents with metadata (new): stored under users/{uid}/edges
  Future<List<Map<String, dynamic>>> listEdgeDocs({required String uid});
  Future<String> createEdgeDoc({required String uid, required Map<String, dynamic> data});
  Future<void> updateEdgeDoc({required String uid, required String edgeId, required Map<String, dynamic> data});
  Future<void> deleteEdgeDoc({required String uid, required String edgeId});
  
  // Folders (users/{uid}/folders)
  Future<List<Map<String, dynamic>>> listFolders({required String uid});
  Future<Map<String, dynamic>?> getFolder({required String uid, required String folderId});
  Future<String> createFolder({required String uid, required Map<String, dynamic> data});
  Future<void> updateFolder({required String uid, required String folderId, required Map<String, dynamic> data});
  Future<void> deleteFolder({required String uid, required String folderId});
  Future<void> addNoteToFolder({required String uid, required String noteId, required String folderId});
  Future<void> removeNoteFromFolder({required String uid, required String noteId, required String folderId});
}

class _FirebaseFirestoreService implements FirestoreService {
  final _db = fs.FirebaseFirestore.instance;

  @override
  Future<void> reserveHandle({required String username, required String uid}) async {
    final ref = _db.collection('handles').doc(username);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        throw Exception('handle-already-exists');
      }
      tx.set(ref, {
        'uid': uid,
        'createdAt': fs.FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> setUserProfile({required String uid, required Map<String, dynamic> data}) async {
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
  Future<void> updateUserProfile({required String uid, required Map<String, dynamic> data}) async {
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
  Future<void> changeHandle({required String uid, required String newUsername}) async {
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
      final currentUsername = (userSnap.data()?['username'] as String?)?.trim().toLowerCase();
      if (currentUsername == null || currentUsername.isEmpty) {
        throw Exception('user-has-no-username');
      }
      if (currentUsername == newUser) return; // no-op

      // Ensure current handle doc matches uid
      final oldRef = handles.doc(currentUsername);
      final oldSnap = await tx.get(oldRef);
      if (!oldSnap.exists) throw Exception('old-handle-not-found');
      if (oldSnap.data()?['uid'] != uid) throw Exception('old-handle-does-not-belong-to-user');

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
    final q = await _db.collection('users').doc(uid).collection('notes').orderBy('updatedAt', descending: true).get();
    return q.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> listNotesSummary({required String uid}) async {
    final q = await _db.collection('users').doc(uid).collection('notes').orderBy('updatedAt', descending: true).get();
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
  Future<List<Map<String, dynamic>>> searchNotesSummary({required String uid, required String query}) async {
    // Simple search by title contains (client-side fallback)
    final all = await listNotesSummary(uid: uid);
    final q = query.trim().toLowerCase();
    return all.where((n) => (n['title']?.toString() ?? '').toLowerCase().contains(q)).toList();
  }

  @override
  Future<void> setPinned({required String uid, required String noteId, required bool pinned}) async {
    await _db.collection('users').doc(uid).collection('notes').doc(noteId).set({'pinned': pinned, 'updatedAt': fs.FieldValue.serverTimestamp()}, fs.SetOptions(merge: true));
  }

  @override
  Future<void> softDeleteNote({required String uid, required String noteId}) async {
    await _db.collection('users').doc(uid).collection('notes').doc(noteId).set({'trashed': true, 'trashedAt': fs.FieldValue.serverTimestamp(), 'updatedAt': fs.FieldValue.serverTimestamp()}, fs.SetOptions(merge: true));
  }

  @override
  Future<void> restoreNote({required String uid, required String noteId}) async {
    await _db.collection('users').doc(uid).collection('notes').doc(noteId).set({'trashed': false, 'trashedAt': null, 'updatedAt': fs.FieldValue.serverTimestamp()}, fs.SetOptions(merge: true));
  }

  @override
  Future<void> purgeNote({required String uid, required String noteId}) async {
    await _db.collection('users').doc(uid).collection('notes').doc(noteId).delete();
  }

  @override
  Future<List<Map<String, dynamic>>> listTrashedNotesSummary({required String uid}) async {
    final q = await _db.collection('users').doc(uid).collection('notes').where('trashed', isEqualTo: true).orderBy('trashedAt', descending: true).get();
    return q.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> listCollections({required String uid}) async {
    final q = await _db.collection('users').doc(uid).collection('collections').orderBy('createdAt', descending: false).get();
    return q.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  @override
  Future<String> createCollection({required String uid, required Map<String, dynamic> data}) async {
    final col = _db.collection('users').doc(uid).collection('collections');
    final ref = await col.add({...data, 'createdAt': fs.FieldValue.serverTimestamp()});
    return ref.id;
  }

  @override
  Future<void> updateCollection({required String uid, required String collectionId, required Map<String, dynamic> data}) async {
    await _db.collection('users').doc(uid).collection('collections').doc(collectionId).set({...data, 'updatedAt': fs.FieldValue.serverTimestamp()}, fs.SetOptions(merge: true));
  }

  @override
  Future<void> deleteCollection({required String uid, required String collectionId}) async {
    await _db.collection('users').doc(uid).collection('collections').doc(collectionId).delete();
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
  Future<void> addTagToNote({required String uid, required String noteId, required String tag}) async {
    final ref = _db.collection('users').doc(uid).collection('notes').doc(noteId);
    await ref.set({'tags': fs.FieldValue.arrayUnion([tag]), 'updatedAt': fs.FieldValue.serverTimestamp()}, fs.SetOptions(merge: true));
  }

  @override
  Future<void> removeTagFromNote({required String uid, required String noteId, required String tag}) async {
    final ref = _db.collection('users').doc(uid).collection('notes').doc(noteId);
    await ref.set({'tags': fs.FieldValue.arrayRemove([tag]), 'updatedAt': fs.FieldValue.serverTimestamp()}, fs.SetOptions(merge: true));
  }

  @override
  Future<List<String>> listOutgoingLinks({required String uid, required String noteId}) async {
    final d = await getNote(uid: uid, noteId: noteId);
    return List<String>.from((d?['links'] as List?)?.whereType<String>() ?? const []);
  }

  @override
  Future<List<String>> listIncomingLinks({required String uid, required String noteId}) async {
    final notes = await listNotes(uid: uid);
    final incoming = <String>[];
    for (final n in notes) {
      final links = (n['links'] as List?)?.whereType<String>() ?? const [];
      if (links.contains(noteId)) incoming.add(n['id'].toString());
    }
    return incoming;
  }

  @override
  Future<void> addLink({required String uid, required String fromNoteId, required String toNoteId}) async {
    final ref = _db.collection('users').doc(uid).collection('notes').doc(fromNoteId);
    await ref.set({'links': fs.FieldValue.arrayUnion([toNoteId]), 'updatedAt': fs.FieldValue.serverTimestamp()}, fs.SetOptions(merge: true));
  }

  @override
  Future<void> removeLink({required String uid, required String fromNoteId, required String toNoteId}) async {
    final ref = _db.collection('users').doc(uid).collection('notes').doc(fromNoteId);
    await ref.set({'links': fs.FieldValue.arrayRemove([toNoteId]), 'updatedAt': fs.FieldValue.serverTimestamp()}, fs.SetOptions(merge: true));
  }

  @override
  Future<void> updateNoteLinks({required String uid, required String noteId, required List<String> linkedNoteIds}) async {
    final ref = _db.collection('users').doc(uid).collection('notes').doc(noteId);
    await ref.set({'links': linkedNoteIds, 'updatedAt': fs.FieldValue.serverTimestamp()}, fs.SetOptions(merge: true));
  }

  @override
  Future<void> moveNoteToCollection({required String uid, required String noteId, String? collectionId}) async {
    final ref = _db.collection('users').doc(uid).collection('notes').doc(noteId);
    await ref.set({'collectionId': collectionId, 'updatedAt': fs.FieldValue.serverTimestamp()}, fs.SetOptions(merge: true));
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
    final q = await _db.collection('users').doc(uid).collection('edges').orderBy('createdAt', descending: true).get();
    return q.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  @override
  Future<String> createEdgeDoc({required String uid, required Map<String, dynamic> data}) async {
    final col = _db.collection('users').doc(uid).collection('edges');
    final now = fs.FieldValue.serverTimestamp();
    final ref = await col.add({...data, 'createdAt': now, 'updatedAt': now});
    return ref.id;
  }

  @override
  Future<void> updateEdgeDoc({required String uid, required String edgeId, required Map<String, dynamic> data}) async {
    await _db.collection('users').doc(uid).collection('edges').doc(edgeId).set({...data, 'updatedAt': fs.FieldValue.serverTimestamp()}, fs.SetOptions(merge: true));
  }

  @override
  Future<void> deleteEdgeDoc({required String uid, required String edgeId}) async {
    await _db.collection('users').doc(uid).collection('edges').doc(edgeId).delete();
  }

  @override
  Future<Map<String, dynamic>?> getNote({required String uid, required String noteId}) async {
    final d = await _db.collection('users').doc(uid).collection('notes').doc(noteId).get();
    if (!d.exists) return null;
    return {'id': d.id, ...d.data()!};
  }

  @override
  Future<String> createNote({required String uid, required Map<String, dynamic> data}) async {
    final col = _db.collection('users').doc(uid).collection('notes');
    final now = fs.FieldValue.serverTimestamp();
    final ref = await col.add({
      ...data,
      'createdAt': now,
      'updatedAt': now,
    });
    return ref.id;
  }

  @override
  Future<void> updateNote({required String uid, required String noteId, required Map<String, dynamic> data}) async {
    await _db.collection('users').doc(uid).collection('notes').doc(noteId).set({
      ...data,
      'updatedAt': fs.FieldValue.serverTimestamp(),
    }, fs.SetOptions(merge: true));
  }

  @override
  Future<void> deleteNote({required String uid, required String noteId}) async {
    await _db.collection('users').doc(uid).collection('notes').doc(noteId).delete();
  }
  
  // Folders
  @override
  Future<List<Map<String, dynamic>>> listFolders({required String uid}) async {
    final snap = await _db.collection('users').doc(uid).collection('folders').orderBy('order').get();
    return snap.docs.map((d) {
      final data = d.data();
      return {
        ...data,
        'logicalId': data['id'], // conservar si existe
        'id': d.id,              // Forzar id = docId para operaciones
        'docId': d.id,
        'folderId': d.id,
      };
    }).toList();
  }
  
  @override
  Future<Map<String, dynamic>?> getFolder({required String uid, required String folderId}) async {
    final d = await _db.collection('users').doc(uid).collection('folders').doc(folderId).get();
    if (!d.exists) return null;
    return {'id': d.id, ...d.data()!};
  }
  
  @override
  Future<String> createFolder({required String uid, required Map<String, dynamic> data}) async {
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
  Future<void> updateFolder({required String uid, required String folderId, required Map<String, dynamic> data}) async {
    await _db.collection('users').doc(uid).collection('folders').doc(folderId).set({
      ...data,
      'updatedAt': fs.FieldValue.serverTimestamp(),
    }, fs.SetOptions(merge: true));
  }
  
  @override
  Future<void> deleteFolder({required String uid, required String folderId}) async {
    await _db.collection('users').doc(uid).collection('folders').doc(folderId).delete();
  }
  
  @override
  Future<void> addNoteToFolder({required String uid, required String noteId, required String folderId}) async {
    final ref = _db.collection('users').doc(uid).collection('folders').doc(folderId);
    await ref.update({
      'noteIds': fs.FieldValue.arrayUnion([noteId]),
      'updatedAt': fs.FieldValue.serverTimestamp(),
    });
  }
  
  @override
  Future<void> removeNoteFromFolder({required String uid, required String noteId, required String folderId}) async {
    final ref = _db.collection('users').doc(uid).collection('folders').doc(folderId);
    await ref.update({
      'noteIds': fs.FieldValue.arrayRemove([noteId]),
      'updatedAt': fs.FieldValue.serverTimestamp(),
    });
  }
}

class _RestFirestoreService implements FirestoreService {
  String get _projectId => DefaultFirebaseOptions.web.projectId;
  String get _base => 'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents';

  Future<Map<String, String>> _authHeader() async {
    final token = await AuthService.instanceToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  @override
  Future<void> reserveHandle({required String username, required String uid}) async {
    final uri = Uri.parse('$_base/handles?documentId=$username');
    final body = jsonEncode({
      'fields': {
        'uid': {'stringValue': uid},
        'createdAt': {'timestampValue': DateTime.now().toUtc().toIso8601String()},
      }
    });
    final resp = await http.post(uri, headers: await _authHeader(), body: body);
    if (resp.statusCode == 409) {
      throw Exception('handle-already-exists');
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('firestore-handle-failed-${resp.statusCode}');
    }
  }

  @override
  Future<void> setUserProfile({required String uid, required Map<String, dynamic> data}) async {
    final uri = Uri.parse('$_base/users?documentId=$uid');
    final fields = <String, dynamic>{};
    data.forEach((key, value) {
      fields[key] = _encodeValue(value);
    });
    fields['createdAt'] = {'timestampValue': DateTime.now().toUtc().toIso8601String()};
    fields['updatedAt'] = {'timestampValue': DateTime.now().toUtc().toIso8601String()};
    final body = jsonEncode({'fields': fields});
    final resp = await http.post(uri, headers: await _authHeader(), body: body);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('firestore-user-failed-${resp.statusCode}');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listUserProfiles({int limit = 50}) async {
    final uri = Uri.parse('$_base/users');
    final resp = await http.get(uri, headers: await _authHeader());
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
    final resp = await http.get(uri, headers: await _authHeader());
    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final fields = _decodeFields(data['fields'] as Map<String, dynamic>?);
    return {'id': uid, ...fields};
  }

  @override
  Future<void> updateUserProfile({required String uid, required Map<String, dynamic> data}) async {
    final fields = <String, dynamic>{};
    final updateMask = <String>[];
    data.forEach((k, v) {
      if (k == 'username') return; // forbid here; use changeHandle
      fields[k] = _encodeValue(v);
      updateMask.add(k);
    });
    // Always bump updatedAt
    fields['updatedAt'] = {'timestampValue': DateTime.now().toUtc().toIso8601String()};
    updateMask.add('updatedAt');
    final qs = updateMask.map((f) => 'updateMask.fieldPaths=${Uri.encodeQueryComponent(f)}').join('&');
    final uri = Uri.parse('$_base/users/$uid?$qs');
    final body = jsonEncode({'fields': fields});
    final resp = await http.patch(uri, headers: await _authHeader(), body: body);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('firestore-update-user-${resp.statusCode}');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listHandles({int limit = 50}) async {
    final uri = Uri.parse('$_base/handles');
    final resp = await http.get(uri, headers: await _authHeader());
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
    final resp = await http.get(uri, headers: await _authHeader());
    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final fields = _decodeFields(data['fields'] as Map<String, dynamic>?);
    return {'username': username, ...fields};
  }

  @override
  Future<void> changeHandle({required String uid, required String newUsername}) async {
    final newUser = newUsername.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9._]{3,20}$').hasMatch(newUser)) {
      throw Exception('invalid-username');
    }
    // 1) Check new handle doesn't exist
    final exists = await getHandle(username: newUser);
    if (exists != null) throw Exception('handle-already-exists');

    // 2) Get current username from user profile
    final profile = await getUserProfile(uid: uid);
    final currentUsername = (profile?['username'] as String?)?.trim().toLowerCase();
    if (currentUsername == null || currentUsername.isEmpty) {
      throw Exception('user-has-no-username');
    }
    if (currentUsername == newUser) return;

    // 3) Create new handle
    final createUri = Uri.parse('$_base/handles?documentId=$newUser');
    final createBody = jsonEncode({
      'fields': {
        'uid': {'stringValue': uid},
        'createdAt': {'timestampValue': DateTime.now().toUtc().toIso8601String()},
      }
    });
    final createResp = await http.post(createUri, headers: await _authHeader(), body: createBody);
    if (createResp.statusCode < 200 || createResp.statusCode >= 300) {
      if (createResp.statusCode == 409) throw Exception('handle-already-exists');
      throw Exception('firestore-create-handle-${createResp.statusCode}');
    }

    try {
      // 4) Update user document's username (explicit mask)
      final qs = 'updateMask.fieldPaths=username&updateMask.fieldPaths=updatedAt';
      final uri = Uri.parse('$_base/users/$uid?$qs');
      final body = jsonEncode({
        'fields': {
          'username': {'stringValue': newUser},
          'updatedAt': {'timestampValue': DateTime.now().toUtc().toIso8601String()},
        }
      });
      final patchResp = await http.patch(uri, headers: await _authHeader(), body: body);
      if (patchResp.statusCode < 200 || patchResp.statusCode >= 300) {
        throw Exception('firestore-update-username-${patchResp.statusCode}');
      }

      // 5) Delete old handle
      final delUri = Uri.parse('$_base/handles/$currentUsername');
      final delResp = await http.delete(delUri, headers: await _authHeader());
      if (delResp.statusCode < 200 || delResp.statusCode >= 300) {
        throw Exception('firestore-delete-old-handle-${delResp.statusCode}');
      }
    } catch (e) {
      // Rollback: try delete new handle if something failed
      try {
        final delUri = Uri.parse('$_base/handles/$newUser');
        await http.delete(delUri, headers: await _authHeader());
      } catch (_) {}
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listNotes({required String uid}) async {
    final uri = Uri.parse('$_base/users/$uid/notes');
    final resp = await http.get(uri, headers: await _authHeader());
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
  Future<Map<String, dynamic>?> getNote({required String uid, required String noteId}) async {
    final uri = Uri.parse('$_base/users/$uid/notes/$noteId');
    final resp = await http.get(uri, headers: await _authHeader());
    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final fields = _decodeFields(data['fields'] as Map<String, dynamic>?);
    return {'id': noteId, ...fields};
  }

  @override
  Future<String> createNote({required String uid, required Map<String, dynamic> data}) async {
    final uri = Uri.parse('$_base/users/$uid/notes');
    final fields = <String, dynamic>{};
    data.forEach((k, v) => fields[k] = _encodeValue(v));
    final body = jsonEncode({'fields': fields});
    final resp = await http.post(uri, headers: await _authHeader(), body: body);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('firestore-create-note-${resp.statusCode}');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final name = json['name']?.toString() ?? '';
    return name.split('/').last;
  }

  @override
  Future<List<Map<String, dynamic>>> listNotesSummary({required String uid}) async {
    final list = await listNotes(uid: uid);
    return list.map((d) => {
      'id': d['id'],
      'title': d['title'] ?? '',
      'pinned': d['pinned'] ?? false,
      'icon': d['icon'],
      'iconColor': d['iconColor'],
      'collectionId': d['collectionId'],
      'tags': d['tags'] ?? <String>[],
      'updatedAt': d['updatedAt'],
    }).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> searchNotesSummary({required String uid, required String query}) async {
    final all = await listNotesSummary(uid: uid);
    final q = query.trim().toLowerCase();
    return all.where((n) => (n['title']?.toString() ?? '').toLowerCase().contains(q)).toList();
  }

  Future<void> _patchNoteFields(String uid, String noteId, Map<String, dynamic> fields) async {
    final uri = Uri.parse('$_base/users/$uid/notes/$noteId');
    final body = jsonEncode({'fields': fields});
    final resp = await http.patch(uri, headers: await _authHeader(), body: body);
    if (resp.statusCode < 200 || resp.statusCode >= 300) throw Exception('firestore-patch-note-${resp.statusCode}');
  }

  @override
  Future<void> setPinned({required String uid, required String noteId, required bool pinned}) async {
    await _patchNoteFields(uid, noteId, {'pinned': _encodeValue(pinned), 'updatedAt': _encodeValue(DateTime.now().toUtc())});
  }

  @override
  Future<void> softDeleteNote({required String uid, required String noteId}) async {
    await _patchNoteFields(uid, noteId, {'trashed': _encodeValue(true), 'trashedAt': _encodeValue(DateTime.now().toUtc()), 'updatedAt': _encodeValue(DateTime.now().toUtc())});
  }

  @override
  Future<void> restoreNote({required String uid, required String noteId}) async {
    await _patchNoteFields(uid, noteId, {'trashed': _encodeValue(false), 'trashedAt': _encodeValue(null), 'updatedAt': _encodeValue(DateTime.now().toUtc())});
  }

  @override
  Future<void> purgeNote({required String uid, required String noteId}) async {
    final uri = Uri.parse('$_base/users/$uid/notes/$noteId');
    final resp = await http.delete(uri, headers: await _authHeader());
    if (resp.statusCode < 200 || resp.statusCode >= 300) throw Exception('firestore-delete-note-${resp.statusCode}');
  }

  @override
  Future<List<Map<String, dynamic>>> listTrashedNotesSummary({required String uid}) async {
    final all = await listNotes(uid: uid);
    return all.where((d) => d['trashed'] == true).map((d) => {'id': d['id'], ...d}).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> listCollections({required String uid}) async {
    final uri = Uri.parse('$_base/users/$uid/collections');
    final resp = await http.get(uri, headers: await _authHeader());
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
  Future<String> createCollection({required String uid, required Map<String, dynamic> data}) async {
    final uri = Uri.parse('$_base/users/$uid/collections');
    final fields = <String, dynamic>{};
    data.forEach((k, v) => fields[k] = _encodeValue(v));
    fields['createdAt'] = _encodeValue(DateTime.now().toUtc());
    final body = jsonEncode({'fields': fields});
    final resp = await http.post(uri, headers: await _authHeader(), body: body);
    if (resp.statusCode < 200 || resp.statusCode >= 300) throw Exception('firestore-create-collection-${resp.statusCode}');
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final name = json['name']?.toString() ?? '';
    return name.split('/').last;
  }

  @override
  Future<void> updateCollection({required String uid, required String collectionId, required Map<String, dynamic> data}) async {
    final qs = data.keys.map((k) => 'updateMask.fieldPaths=${Uri.encodeQueryComponent(k)}').join('&');
    final uri = Uri.parse('$_base/users/$uid/collections/$collectionId?$qs');
    final fields = <String, dynamic>{};
    data.forEach((k, v) => fields[k] = _encodeValue(v));
    fields['updatedAt'] = _encodeValue(DateTime.now().toUtc());
    final body = jsonEncode({'fields': fields});
    final resp = await http.patch(uri, headers: await _authHeader(), body: body);
    if (resp.statusCode < 200 || resp.statusCode >= 300) throw Exception('firestore-update-collection-${resp.statusCode}');
  }

  @override
  Future<void> deleteCollection({required String uid, required String collectionId}) async {
    final uri = Uri.parse('$_base/users/$uid/collections/$collectionId');
    final resp = await http.delete(uri, headers: await _authHeader());
    if (resp.statusCode < 200 || resp.statusCode >= 300) throw Exception('firestore-delete-collection-${resp.statusCode}');
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

  Future<void> _arrayOp(String uid, String noteId, String field, List<String> values, {required bool add}) async {
    // Firestore REST doesn't have arrayUnion/arrayRemove via simple patch; use get, modify, patch
    final current = await getNote(uid: uid, noteId: noteId);
    final arr = List<String>.from((current?[field] as List?)?.whereType<String>() ?? []);
    if (add) {
      for (final v in values) {
        if (!arr.contains(v)) arr.add(v);
      }
    } else {
      arr.removeWhere((e) => values.contains(e));
    }
    final fields = {field: _encodeValue(arr), 'updatedAt': _encodeValue(DateTime.now().toUtc())};
    await _patchNoteFields(uid, noteId, fields);
  }

  @override
  Future<void> addTagToNote({required String uid, required String noteId, required String tag}) async {
    await _arrayOp(uid, noteId, 'tags', [tag], add: true);
  }

  @override
  Future<void> removeTagFromNote({required String uid, required String noteId, required String tag}) async {
    await _arrayOp(uid, noteId, 'tags', [tag], add: false);
  }

  @override
  Future<List<String>> listOutgoingLinks({required String uid, required String noteId}) async {
    final n = await getNote(uid: uid, noteId: noteId);
    return List<String>.from((n?['links'] as List?)?.whereType<String>() ?? const []);
  }

  @override
  Future<List<String>> listIncomingLinks({required String uid, required String noteId}) async {
    final notes = await listNotes(uid: uid);
    final incoming = <String>[];
    for (final n in notes) {
      final links = (n['links'] as List?)?.whereType<String>() ?? const [];
      if (links.contains(noteId)) incoming.add(n['id'].toString());
    }
    return incoming;
  }

  @override
  Future<void> addLink({required String uid, required String fromNoteId, required String toNoteId}) async {
    await _arrayOp(uid, fromNoteId, 'links', [toNoteId], add: true);
  }

  @override
  Future<void> removeLink({required String uid, required String fromNoteId, required String toNoteId}) async {
    await _arrayOp(uid, fromNoteId, 'links', [toNoteId], add: false);
  }

  @override
  Future<void> updateNoteLinks({required String uid, required String noteId, required List<String> linkedNoteIds}) async {
    final fields = <String, dynamic>{'links': _encodeValue(linkedNoteIds)};
    fields['updatedAt'] = _encodeValue(DateTime.now().toUtc());
    await _patchNoteFields(uid, noteId, fields);
  }

  @override
  Future<void> moveNoteToCollection({required String uid, required String noteId, String? collectionId}) async {
    final fields = <String, dynamic>{'collectionId': _encodeValue(collectionId)};
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
  Future<void> updateNote({required String uid, required String noteId, required Map<String, dynamic> data}) async {
    final uri = Uri.parse('$_base/users/$uid/notes/$noteId');
    final fields = <String, dynamic>{};
    data.forEach((k, v) => fields[k] = _encodeValue(v));
    final body = jsonEncode({'fields': fields});
    final resp = await http.patch(uri, headers: await _authHeader(), body: body);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('firestore-update-note-${resp.statusCode}');
    }
  }

  @override
  Future<void> deleteNote({required String uid, required String noteId}) async {
    final uri = Uri.parse('$_base/users/$uid/notes/$noteId');
    final resp = await http.delete(uri, headers: await _authHeader());
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('firestore-delete-note-${resp.statusCode}');
    }
  }

  dynamic _encodeValue(dynamic value) {
    if (value == null) return {'nullValue': null};
    if (value is String) return {'stringValue': value};
    if (value is bool) return {'booleanValue': value};
    if (value is num) return {'doubleValue': value};
    if (value is DateTime) return {'timestampValue': value.toUtc().toIso8601String()};
    if (value is List) {
      return {
        'arrayValue': {
          'values': value.map((e) => _encodeValue(e)).toList(),
        }
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
          result[key] = vals.map((e) => (e as Map<String, dynamic>)['stringValue'] ?? e.toString()).toList();
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
    final resp = await http.get(Uri.parse(url), headers: headers);
    if (resp.statusCode != 200) return [];
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final docs = (data['documents'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return docs.map((d) {
      final id = (d['name'] as String).split('/').last;
      final fields = _decodeFields(d['fields'] as Map<String, dynamic>?);
      return {
        ...fields,
        'logicalId': fields['id'],
        'id': id,
        'docId': id,   // Firestore document ID (needed for delete operations)
        'folderId': id, // Usar SIEMPRE el ID de documento
      };
    }).toList();
  }
  
  @override
  Future<Map<String, dynamic>?> getFolder({required String uid, required String folderId}) async {
    final headers = await _authHeader();
    final url = '$_base/users/$uid/folders/$folderId';
    final resp = await http.get(Uri.parse(url), headers: headers);
    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final id = (data['name'] as String).split('/').last;
    final fields = _decodeFields(data['fields'] as Map<String, dynamic>?);
    return {'id': id, ...fields};
  }
  
  @override
  Future<String> createFolder({required String uid, required Map<String, dynamic> data}) async {
    final headers = await _authHeader();
    final url = '$_base/users/$uid/folders';
    final now = DateTime.now().toUtc();
    final fields = <String, dynamic>{};
    data.forEach((k, v) => fields[k] = _encodeValue(v));
    fields['noteIds'] = _encodeValue(data['noteIds'] ?? []);
    fields['createdAt'] = _encodeValue(now);
    fields['updatedAt'] = _encodeValue(now);
    final payload = {'fields': fields};
    final resp = await http.post(Uri.parse(url), headers: headers, body: jsonEncode(payload));
    if (resp.statusCode != 200) throw Exception('Failed to create folder');
    final respData = jsonDecode(resp.body) as Map<String, dynamic>;
    final id = (respData['name'] as String).split('/').last;
    return id;
  }
  
  @override
  Future<void> updateFolder({required String uid, required String folderId, required Map<String, dynamic> data}) async {
    final headers = await _authHeader();
    final url = '$_base/users/$uid/folders/$folderId';
    final now = DateTime.now().toUtc();
    final fields = <String, dynamic>{};
    for (final entry in data.entries) {
      fields[entry.key] = _encodeValue(entry.value);
    }
    fields['updatedAt'] = _encodeValue(now);
    
    final updateMask = [...data.keys, 'updatedAt'];
    final qs = updateMask.map((f) => 'updateMask.fieldPaths=${Uri.encodeQueryComponent(f)}').join('&');
    final urlWithMask = '$url?$qs';
    
    final payload = {'fields': fields};
    final resp = await http.patch(Uri.parse(urlWithMask), headers: headers, body: jsonEncode(payload));
    if (resp.statusCode != 200) throw Exception('Failed to update folder');
  }
  
  @override
  Future<void> deleteFolder({required String uid, required String folderId}) async {
    final headers = await _authHeader();
    final url = '$_base/users/$uid/folders/$folderId';
    final resp = await http.delete(Uri.parse(url), headers: headers);
    if (resp.statusCode != 200) throw Exception('Failed to delete folder');
  }
  
  @override
  Future<void> addNoteToFolder({required String uid, required String noteId, required String folderId}) async {
    final folder = await getFolder(uid: uid, folderId: folderId);
    if (folder == null) throw Exception('Folder not found');
    final noteIds = List<String>.from((folder['noteIds'] as List?)?.cast<String>() ?? []);
    if (!noteIds.contains(noteId)) {
      noteIds.add(noteId);
      await updateFolder(uid: uid, folderId: folderId, data: {'noteIds': noteIds});
    }
  }
  
  @override
  Future<void> removeNoteFromFolder({required String uid, required String noteId, required String folderId}) async {
    final folder = await getFolder(uid: uid, folderId: folderId);
    if (folder == null) throw Exception('Folder not found');
    final noteIds = List<String>.from((folder['noteIds'] as List?)?.cast<String>() ?? []);
    noteIds.remove(noteId);
    await updateFolder(uid: uid, folderId: folderId, data: {'noteIds': noteIds});
  }
  
  // Edge documents - REST API implementation
  @override
  Future<List<Map<String, dynamic>>> listEdgeDocs({required String uid}) async {
    final headers = await _authHeader();
    final url = '$_base/users/$uid/edges?orderBy=createdAt';
    final resp = await http.get(Uri.parse(url), headers: headers);
    if (resp.statusCode != 200) return [];
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final docs = (data['documents'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return docs.map((d) {
      final id = (d['name'] as String).split('/').last;
      final fields = _decodeFields(d['fields'] as Map<String, dynamic>?);
      return {'id': id, ...fields};
    }).toList();
  }

  @override
  Future<String> createEdgeDoc({required String uid, required Map<String, dynamic> data}) async {
    final headers = await _authHeader();
    final url = '$_base/users/$uid/edges';
    final now = DateTime.now().toUtc();
    final fields = <String, dynamic>{};
    data.forEach((k, v) => fields[k] = _encodeValue(v));
    fields['createdAt'] = _encodeValue(now);
    fields['updatedAt'] = _encodeValue(now);
    final payload = {'fields': fields};
    final resp = await http.post(Uri.parse(url), headers: headers, body: jsonEncode(payload));
    if (resp.statusCode != 200) throw Exception('Failed to create edge doc');
    final respData = jsonDecode(resp.body) as Map<String, dynamic>;
    final id = (respData['name'] as String).split('/').last;
    return id;
  }

  @override
  Future<void> updateEdgeDoc({required String uid, required String edgeId, required Map<String, dynamic> data}) async {
    final headers = await _authHeader();
    final url = '$_base/users/$uid/edges/$edgeId';
    final now = DateTime.now().toUtc();
    final fields = <String, dynamic>{};
    for (final entry in data.entries) {
      fields[entry.key] = _encodeValue(entry.value);
    }
    fields['updatedAt'] = _encodeValue(now);
    
    final updateMask = [...data.keys, 'updatedAt'];
    final qs = updateMask.map((f) => 'updateMask.fieldPaths=${Uri.encodeQueryComponent(f)}').join('&');
    final urlWithMask = '$url?$qs';
    
    final payload = {'fields': fields};
    final resp = await http.patch(Uri.parse(urlWithMask), headers: headers, body: jsonEncode(payload));
    if (resp.statusCode != 200) throw Exception('Failed to update edge doc');
  }

  @override
  Future<void> deleteEdgeDoc({required String uid, required String edgeId}) async {
    final headers = await _authHeader();
    final url = '$_base/users/$uid/edges/$edgeId';
    final resp = await http.delete(Uri.parse(url), headers: headers);
    if (resp.statusCode != 200) throw Exception('Failed to delete edge doc');
  }
}
