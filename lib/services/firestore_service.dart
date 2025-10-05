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
}
