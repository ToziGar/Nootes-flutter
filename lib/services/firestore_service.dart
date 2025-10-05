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

  // Notes APIs (subcollection users/{uid}/notes)
  Future<List<Map<String, dynamic>>> listNotes({required String uid});
  Future<Map<String, dynamic>?> getNote({required String uid, required String noteId});
  Future<String> createNote({required String uid, required Map<String, dynamic> data});
  Future<void> updateNote({required String uid, required String noteId, required Map<String, dynamic> data});
  Future<void> deleteNote({required String uid, required String noteId});
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
    final body = jsonEncode({'fields': fields});
    final resp = await http.post(uri, headers: await _authHeader(), body: body);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('firestore-user-failed-${resp.statusCode}');
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

  dynamic _encodeValue(dynamic value) {
    if (value is String) return {'stringValue': value};
    if (value is bool) return {'booleanValue': value};
    if (value is num) return {'doubleValue': value};
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
}
