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

  // Advanced Notes: Collections
  Future<List<Map<String, dynamic>>> listCollections({required String uid});
  Future<Map<String, dynamic>?> getCollection({required String uid, required String collectionId});
  Future<String> createCollection({required String uid, required Map<String, dynamic> data});
  Future<void> updateCollection({required String uid, required String collectionId, required Map<String, dynamic> data});
  Future<void> deleteCollection({required String uid, required String collectionId});
  Future<void> moveNoteToCollection({required String uid, required String noteId, String? collectionId});

  // Advanced Notes: Tags
  Future<List<String>> listTags({required String uid});
  Future<List<Map<String, dynamic>>> listNotesByTag({required String uid, required String tag});
  Future<void> addTagToNote({required String uid, required String noteId, required String tag});
  Future<void> removeTagFromNote({required String uid, required String noteId, required String tag});

  // Advanced Notes: Graph links between notes
  Future<void> addLink({required String uid, required String fromNoteId, required String toNoteId});
  Future<void> removeLink({required String uid, required String fromNoteId, required String toNoteId});
  Future<List<String>> listOutgoingLinks({required String uid, required String noteId});
  Future<List<String>> listIncomingLinks({required String uid, required String noteId});
  Future<List<Map<String, String>>> listEdges({required String uid});
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

  // Collections (users/{uid}/collections)

  @override
  Future<List<Map<String, dynamic>>> listCollections({required String uid}) async {
    final q = await _db
        .collection('users').doc(uid).collection('collections')
        .orderBy('createdAt', descending: true)
        .get();
    return q.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  @override
  Future<Map<String, dynamic>?> getCollection({required String uid, required String collectionId}) async {
    final d = await _db.collection('users').doc(uid).collection('collections').doc(collectionId).get();
    if (!d.exists) return null;
    return {'id': d.id, ...d.data()!};
  }

  @override
  Future<String> createCollection({required String uid, required Map<String, dynamic> data}) async {
    final col = _db.collection('users').doc(uid).collection('collections');
    final now = fs.FieldValue.serverTimestamp();
    final ref = await col.add({
      ...data,
      'createdAt': now,
      'updatedAt': now,
    });
    return ref.id;
  }

  @override
  Future<void> updateCollection({required String uid, required String collectionId, required Map<String, dynamic> data}) async {
    await _db.collection('users').doc(uid).collection('collections').doc(collectionId).set({
      ...data,
      'updatedAt': fs.FieldValue.serverTimestamp(),
    }, fs.SetOptions(merge: true));
  }

  @override
  Future<void> deleteCollection({required String uid, required String collectionId}) async {
    await _db.collection('users').doc(uid).collection('collections').doc(collectionId).delete();
  }

  @override
  Future<void> moveNoteToCollection({required String uid, required String noteId, String? collectionId}) async {
    final data = collectionId == null || collectionId.isEmpty
        ? {'collectionId': fs.FieldValue.delete()}
        : {'collectionId': collectionId};
    await _db.collection('users').doc(uid).collection('notes').doc(noteId).set({
      ...data,
      'updatedAt': fs.FieldValue.serverTimestamp(),
    }, fs.SetOptions(merge: true));
  }

  // Tags (stored in notes[].tags array)

  @override
  Future<List<String>> listTags({required String uid}) async {
    final q = await _db.collection('users').doc(uid).collection('notes').get();
    final set = <String>{};
    for (final d in q.docs) {
      final tags = (d.data()['tags'] as List?)?.whereType<String>() ?? const [];
      set.addAll(tags);
    }
    return set.toList()..sort((a, b) => a.compareTo(b));
  }

  @override
  Future<List<Map<String, dynamic>>> listNotesByTag({required String uid, required String tag}) async {
    final base = _db
        .collection('users').doc(uid).collection('notes')
        .where('tags', arrayContains: tag);
    try {
      final q = await base.orderBy('updatedAt', descending: true).get();
      return q.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (_) {
      final q = await base.get();
      return q.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    }
  }

  @override
  Future<void> addTagToNote({required String uid, required String noteId, required String tag}) async {
    final t = tag.trim();
    if (t.isEmpty) return;
    await _db.collection('users').doc(uid).collection('notes').doc(noteId).set({
      'tags': fs.FieldValue.arrayUnion([t]),
      'updatedAt': fs.FieldValue.serverTimestamp(),
    }, fs.SetOptions(merge: true));
  }

  @override
  Future<void> removeTagFromNote({required String uid, required String noteId, required String tag}) async {
    final t = tag.trim();
    if (t.isEmpty) return;
    await _db.collection('users').doc(uid).collection('notes').doc(noteId).set({
      'tags': fs.FieldValue.arrayRemove([t]),
      'updatedAt': fs.FieldValue.serverTimestamp(),
    }, fs.SetOptions(merge: true));
  }

  // Graph links (store as notes[].links: [noteId])

  @override
  Future<void> addLink({required String uid, required String fromNoteId, required String toNoteId}) async {
    if (fromNoteId == toNoteId) return;
    await _db.collection('users').doc(uid).collection('notes').doc(fromNoteId).set({
      'links': fs.FieldValue.arrayUnion([toNoteId]),
      'updatedAt': fs.FieldValue.serverTimestamp(),
    }, fs.SetOptions(merge: true));
  }

  @override
  Future<void> removeLink({required String uid, required String fromNoteId, required String toNoteId}) async {
    await _db.collection('users').doc(uid).collection('notes').doc(fromNoteId).set({
      'links': fs.FieldValue.arrayRemove([toNoteId]),
      'updatedAt': fs.FieldValue.serverTimestamp(),
    }, fs.SetOptions(merge: true));
  }

  @override
  Future<List<String>> listOutgoingLinks({required String uid, required String noteId}) async {
    final d = await _db.collection('users').doc(uid).collection('notes').doc(noteId).get();
    if (!d.exists) return const [];
    final links = (d.data()?['links'] as List?)?.whereType<String>().toList() ?? const [];
    return List<String>.from(links);
  }

  @override
  Future<List<String>> listIncomingLinks({required String uid, required String noteId}) async {
    final q = await _db
        .collection('users').doc(uid).collection('notes')
        .where('links', arrayContains: noteId)
        .get();
    return q.docs.map((d) => d.id).toList();
  }

  @override
  Future<List<Map<String, String>>> listEdges({required String uid}) async {
    final q = await _db.collection('users').doc(uid).collection('notes').get();
    final edges = <Map<String, String>>[];
    for (final d in q.docs) {
      final from = d.id;
      final links = (d.data()['links'] as List?)?.whereType<String>() ?? const [];
      for (final to in links) {
        edges.add({'from': from, 'to': to});
      }
    }
    return edges;
  }
}

class _RestFirestoreService implements FirestoreService {
  String get _projectId => DefaultFirebaseOptions.web.projectId;
  String get _base => 'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents';
  String _parentForUser(String uid) => 'projects/$_projectId/databases/(default)/documents/users/$uid';

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

  // Collections (users/{uid}/collections)

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
  Future<Map<String, dynamic>?> getCollection({required String uid, required String collectionId}) async {
    final uri = Uri.parse('$_base/users/$uid/collections/$collectionId');
    final resp = await http.get(uri, headers: await _authHeader());
    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final fields = _decodeFields(data['fields'] as Map<String, dynamic>?);
    return {'id': collectionId, ...fields};
  }

  @override
  Future<String> createCollection({required String uid, required Map<String, dynamic> data}) async {
    final uri = Uri.parse('$_base/users/$uid/collections');
    final fields = <String, dynamic>{};
    data.forEach((k, v) => fields[k] = _encodeValue(v));
    fields['createdAt'] = {'timestampValue': DateTime.now().toUtc().toIso8601String()};
    fields['updatedAt'] = {'timestampValue': DateTime.now().toUtc().toIso8601String()};
    final body = jsonEncode({'fields': fields});
    final resp = await http.post(uri, headers: await _authHeader(), body: body);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('firestore-create-collection-${resp.statusCode}');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final name = json['name']?.toString() ?? '';
    return name.split('/').last;
  }

  @override
  Future<void> updateCollection({required String uid, required String collectionId, required Map<String, dynamic> data}) async {
    final uri = Uri.parse('$_base/users/$uid/collections/$collectionId');
    final fields = <String, dynamic>{};
    final updateMask = <String>[];
    data.forEach((k, v) {
      fields[k] = _encodeValue(v);
      updateMask.add(k);
    });
    fields['updatedAt'] = {'timestampValue': DateTime.now().toUtc().toIso8601String()};
    updateMask.add('updatedAt');
    final qs = updateMask.map((f) => 'updateMask.fieldPaths=${Uri.encodeQueryComponent(f)}').join('&');
    final patchUri = Uri.parse('$uri?$qs');
    final body = jsonEncode({'fields': fields});
    final resp = await http.patch(patchUri, headers: await _authHeader(), body: body);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('firestore-update-collection-${resp.statusCode}');
    }
  }

  @override
  Future<void> deleteCollection({required String uid, required String collectionId}) async {
    final uri = Uri.parse('$_base/users/$uid/collections/$collectionId');
    final resp = await http.delete(uri, headers: await _authHeader());
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('firestore-delete-collection-${resp.statusCode}');
    }
  }

  @override
  Future<void> moveNoteToCollection({required String uid, required String noteId, String? collectionId}) async {
    final uri = Uri.parse('$_base/users/$uid/notes/$noteId');
    final fields = <String, dynamic>{};
    final updateMask = <String>[];
    if (collectionId == null || collectionId.isEmpty) {
      // Represent removal as empty string (simpler than using transforms)
      fields['collectionId'] = _encodeValue('');
    } else {
      fields['collectionId'] = _encodeValue(collectionId);
    }
    updateMask.add('collectionId');
    fields['updatedAt'] = {'timestampValue': DateTime.now().toUtc().toIso8601String()};
    updateMask.add('updatedAt');
    final qs = updateMask.map((f) => 'updateMask.fieldPaths=${Uri.encodeQueryComponent(f)}').join('&');
    final patchUri = Uri.parse('$uri?$qs');
    final body = jsonEncode({'fields': fields});
    final resp = await http.patch(patchUri, headers: await _authHeader(), body: body);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('firestore-move-note-collection-${resp.statusCode}');
    }
  }

  // Tags (client-side filtering for REST)

  @override
  Future<List<String>> listTags({required String uid}) async {
    final notes = await listNotes(uid: uid);
    final set = <String>{};
    for (final n in notes) {
      final tags = (n['tags'] as List?)?.whereType<String>() ?? const [];
      set.addAll(tags);
    }
    return set.toList()..sort((a, b) => a.compareTo(b));
  }

  @override
  Future<List<Map<String, dynamic>>> listNotesByTag({required String uid, required String tag}) async {
    // Try runQuery with array-contains filter; if index required, retry without orderBy.
    Future<List<Map<String, dynamic>>> run({required bool withOrder}) async {
      final body = {
        'parent': _parentForUser(uid),
        'structuredQuery': {
          'from': [
            {'collectionId': 'notes'}
          ],
          'where': {
            'fieldFilter': {
              'field': {'fieldPath': 'tags'},
              'op': 'ARRAY_CONTAINS',
              'value': {'stringValue': tag},
            }
          },
          if (withOrder)
            'orderBy': [
              {
                'field': {'fieldPath': 'updatedAt'},
                'direction': 'DESCENDING',
              }
            ],
        },
      };
      return _runQueryAndDecode(body);
    }

    try {
      return await run(withOrder: true);
    } catch (_) {
      return await run(withOrder: false);
    }
  }

  @override
  Future<void> addTagToNote({required String uid, required String noteId, required String tag}) async {
    final t = tag.trim();
    if (t.isEmpty) return;
    // Fetch, modify, patch back with updateMask
    final note = await getNote(uid: uid, noteId: noteId);
    final tags = <String>{...((note?['tags'] as List?)?.whereType<String>() ?? const [])};
    tags.add(t);
    final uri = Uri.parse('$_base/users/$uid/notes/$noteId?updateMask.fieldPaths=tags&updateMask.fieldPaths=updatedAt');
    final body = jsonEncode({
      'fields': {
        'tags': {
          'arrayValue': {
            'values': tags.map((e) => _encodeValue(e)).toList(),
          }
        },
        'updatedAt': {'timestampValue': DateTime.now().toUtc().toIso8601String()},
      }
    });
    final resp = await http.patch(uri, headers: await _authHeader(), body: body);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('firestore-update-tags-${resp.statusCode}');
    }
  }

  @override
  Future<void> removeTagFromNote({required String uid, required String noteId, required String tag}) async {
    final t = tag.trim();
    if (t.isEmpty) return;
    final note = await getNote(uid: uid, noteId: noteId);
    final tags = <String>{...((note?['tags'] as List?)?.whereType<String>() ?? const [])};
    tags.remove(t);
    final uri = Uri.parse('$_base/users/$uid/notes/$noteId?updateMask.fieldPaths=tags&updateMask.fieldPaths=updatedAt');
    final body = jsonEncode({
      'fields': {
        'tags': {
          'arrayValue': {
            'values': tags.map((e) => _encodeValue(e)).toList(),
          }
        },
        'updatedAt': {'timestampValue': DateTime.now().toUtc().toIso8601String()},
      }
    });
    final resp = await http.patch(uri, headers: await _authHeader(), body: body);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('firestore-update-tags-${resp.statusCode}');
    }
  }

  // Graph links

  @override
  Future<void> addLink({required String uid, required String fromNoteId, required String toNoteId}) async {
    if (fromNoteId == toNoteId) return;
    final note = await getNote(uid: uid, noteId: fromNoteId);
    final links = <String>{...((note?['links'] as List?)?.whereType<String>() ?? const [])};
    links.add(toNoteId);
    final uri = Uri.parse('$_base/users/$uid/notes/$fromNoteId?updateMask.fieldPaths=links&updateMask.fieldPaths=updatedAt');
    final body = jsonEncode({
      'fields': {
        'links': {
          'arrayValue': {
            'values': links.map((e) => _encodeValue(e)).toList(),
          }
        },
        'updatedAt': {'timestampValue': DateTime.now().toUtc().toIso8601String()},
      }
    });
    final resp = await http.patch(uri, headers: await _authHeader(), body: body);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('firestore-update-links-${resp.statusCode}');
    }
  }

  @override
  Future<void> removeLink({required String uid, required String fromNoteId, required String toNoteId}) async {
    final note = await getNote(uid: uid, noteId: fromNoteId);
    final links = <String>{...((note?['links'] as List?)?.whereType<String>() ?? const [])};
    links.remove(toNoteId);
    final uri = Uri.parse('$_base/users/$uid/notes/$fromNoteId?updateMask.fieldPaths=links&updateMask.fieldPaths=updatedAt');
    final body = jsonEncode({
      'fields': {
        'links': {
          'arrayValue': {
            'values': links.map((e) => _encodeValue(e)).toList(),
          }
        },
        'updatedAt': {'timestampValue': DateTime.now().toUtc().toIso8601String()},
      }
    });
    final resp = await http.patch(uri, headers: await _authHeader(), body: body);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('firestore-update-links-${resp.statusCode}');
    }
  }

  @override
  Future<List<String>> listOutgoingLinks({required String uid, required String noteId}) async {
    final note = await getNote(uid: uid, noteId: noteId);
    final links = (note?['links'] as List?)?.whereType<String>().toList() ?? const [];
    return List<String>.from(links);
  }

  @override
  Future<List<String>> listIncomingLinks({required String uid, required String noteId}) async {
    // Query notes where links array contains noteId
    final body = {
      'parent': _parentForUser(uid),
      'structuredQuery': {
        'from': [
          {'collectionId': 'notes'}
        ],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'links'},
            'op': 'ARRAY_CONTAINS',
            'value': {'stringValue': noteId},
          }
        },
      },
    };
    final docs = await _runQueryAndDecode(body);
    return docs.map((d) => d['id'].toString()).toList();
  }

  @override
  Future<List<Map<String, String>>> listEdges({required String uid}) async {
    final notes = await listNotes(uid: uid);
    final edges = <Map<String, String>>[];
    for (final n in notes) {
      final from = n['id']?.toString() ?? '';
      final links = (n['links'] as List?)?.whereType<String>() ?? const [];
      for (final to in links) {
        edges.add({'from': from, 'to': to});
      }
    }
    return edges;
  }

  dynamic _encodeValue(dynamic value) {
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
    fields.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        if (value.containsKey('stringValue')) result[key] = value['stringValue'];
        else if (value.containsKey('booleanValue')) result[key] = value['booleanValue'];
        else if (value.containsKey('doubleValue')) result[key] = value['doubleValue'];
        else if (value.containsKey('integerValue')) result[key] = int.tryParse(value['integerValue'].toString());
        else if (value.containsKey('timestampValue')) result[key] = value['timestampValue'];
        else if (value.containsKey('arrayValue')) {
          final arr = value['arrayValue'] as Map<String, dynamic>?;
          final vals = arr?['values'] as List? ?? [];
          result[key] = vals.map((e) => (e as Map<String, dynamic>)['stringValue'] ?? e.toString()).toList();
        } else {
          result[key] = value.toString();
        }
      }
    });
    return result;
  }

  Future<List<Map<String, dynamic>>> _runQueryAndDecode(Map<String, dynamic> body) async {
    final uri = Uri.parse('$_base:runQuery');
    final resp = await http.post(uri, headers: await _authHeader(), body: jsonEncode(body));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('firestore-runQuery-${resp.statusCode}');
    }
    final text = resp.body.trim();
    final List results = <dynamic>[];
    if (text.startsWith('[')) {
      results.addAll(jsonDecode(text) as List);
    } else {
      // Newline-delimited JSON fallback
      for (final line in text.split('\n')) {
        final l = line.trim();
        if (l.isEmpty) continue;
        results.add(jsonDecode(l));
      }
    }
    final docs = <Map<String, dynamic>>[];
    for (final item in results) {
      if (item is Map && item['document'] != null) {
        final d = item['document'] as Map<String, dynamic>;
        final name = d['name']?.toString() ?? '';
        final id = name.split('/').last;
        final fields = _decodeFields(d['fields'] as Map<String, dynamic>?);
        docs.add({'id': id, ...fields});
      }
    }
    return docs;
  }
}
