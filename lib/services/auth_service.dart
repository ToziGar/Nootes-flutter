import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb; // Used on mobile/web

import '../firebase_options.dart';

class AuthUser {
  final String uid;
  final String? email;
  const AuthUser({required this.uid, this.email});
}

abstract class AuthService {
  static AuthService? _instance;
  static AuthService get instance => _instance ??= _resolve();

  static AuthService _resolve() {
    final isMobileOrWeb = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    if (isMobileOrWeb) return _FirebaseAuthService();
    return _RestAuthService();
  }

  bool get usesRest;
  Stream<AuthUser?> authStateChanges();
  Future<void> init();
  Future<void> signOut();
  Future<AuthUser> signInWithEmailAndPassword(String email, String password);
  Future<AuthUser> createUserWithEmailAndPassword(String email, String password);
  Future<void> sendPasswordResetEmail(String email);
}

class _FirebaseAuthService implements AuthService {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  @override
  bool get usesRest => false;

  @override
  Stream<AuthUser?> authStateChanges() => _auth
      .authStateChanges()
      .map((u) => u == null ? null : AuthUser(uid: u.uid, email: u.email));

  @override
  Future<void> init() async {}

  @override
  Future<AuthUser> createUserWithEmailAndPassword(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    final u = cred.user!;
    return AuthUser(uid: u.uid, email: u.email);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) => _auth.sendPasswordResetEmail(email: email);

  @override
  Future<AuthUser> signInWithEmailAndPassword(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    final u = cred.user!;
    return AuthUser(uid: u.uid, email: u.email);
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

class _RestAuthService implements AuthService {
  // Identity Toolkit endpoints
  static const _identityBase = 'https://identitytoolkit.googleapis.com/v1';
  static const _secureToken = 'https://securetoken.googleapis.com/v1';

  final _controller = StreamController<AuthUser?>.broadcast();
  final _storage = const FlutterSecureStorage();

  String? _idToken;
  String? _refreshToken;
  String? _uid;
  String? _email;
  DateTime? _expiry;

  String get _apiKey => DefaultFirebaseOptions.web.apiKey; // reuse Web API key

  @override
  bool get usesRest => true;

  @override
  Stream<AuthUser?> authStateChanges() => _controller.stream;

  @override
  Future<void> init() async {
    // Try restore from secure storage
    _refreshToken = await _storage.read(key: 'refreshToken');
    _email = await _storage.read(key: 'email');
    _uid = await _storage.read(key: 'uid');
    if (_refreshToken != null) {
      try {
        await _refreshIdToken();
        _emitUser();
      } catch (_) {
        await signOut();
      }
    } else {
      _controller.add(null);
    }
  }

  @override
  Future<AuthUser> createUserWithEmailAndPassword(String email, String password) async {
    final uri = Uri.parse('$_identityBase/accounts:signUp?key=$_apiKey');
    final resp = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode({
      'email': email,
      'password': password,
      'returnSecureToken': true,
    }));
    _handleError(resp);
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    _applyAuth(data);
    await _persist();
    _emitUser();
    return AuthUser(uid: _uid!, email: _email);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    final uri = Uri.parse('$_identityBase/accounts:sendOobCode?key=$_apiKey');
    final resp = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode({
      'requestType': 'PASSWORD_RESET',
      'email': email,
    }));
    _handleError(resp);
  }

  @override
  Future<AuthUser> signInWithEmailAndPassword(String email, String password) async {
    final uri = Uri.parse('$_identityBase/accounts:signInWithPassword?key=$_apiKey');
    final resp = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode({
      'email': email,
      'password': password,
      'returnSecureToken': true,
    }));
    _handleError(resp);
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    _applyAuth(data);
    await _persist();
    _emitUser();
    return AuthUser(uid: _uid!, email: _email);
  }

  @override
  Future<void> signOut() async {
    _idToken = null;
    _refreshToken = null;
    _uid = null;
    _email = null;
    _expiry = null;
    await _storage.delete(key: 'refreshToken');
    await _storage.delete(key: 'uid');
    await _storage.delete(key: 'email');
    _controller.add(null);
  }

  Future<void> _refreshIdToken() async {
    if (_refreshToken == null) return;
    final uri = Uri.parse('$_secureToken/token?key=$_apiKey');
    final resp = await http.post(uri, headers: {'Content-Type': 'application/x-www-form-urlencoded'}, body: {
      'grant_type': 'refresh_token',
      'refresh_token': _refreshToken!,
    });
    _handleError(resp);
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    _idToken = data['id_token'] as String?;
    _refreshToken = data['refresh_token'] as String? ?? _refreshToken;
    _uid = data['user_id'] as String? ?? _uid;
    _email = data['email'] as String? ?? _email;
    final expiresIn = int.tryParse(data['expires_in']?.toString() ?? '3600') ?? 3600;
    _expiry = DateTime.now().add(Duration(seconds: expiresIn - 30));
    await _persist();
  }

  void _applyAuth(Map<String, dynamic> data) {
    _idToken = data['idToken'] as String?;
    _refreshToken = data['refreshToken'] as String?;
    _uid = data['localId'] as String?;
    _email = data['email'] as String?;
    final expiresIn = int.tryParse(data['expiresIn']?.toString() ?? '3600') ?? 3600;
    _expiry = DateTime.now().add(Duration(seconds: expiresIn - 30));
  }

  void _emitUser() {
    if (_uid != null) {
      _controller.add(AuthUser(uid: _uid!, email: _email));
    } else {
      _controller.add(null);
    }
  }

  Future<void> _persist() async {
    if (_refreshToken != null) await _storage.write(key: 'refreshToken', value: _refreshToken);
    if (_uid != null) await _storage.write(key: 'uid', value: _uid);
    if (_email != null) await _storage.write(key: 'email', value: _email);
  }

  void _handleError(http.Response resp) {
    if (resp.statusCode >= 200 && resp.statusCode < 300) return;
    try {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final code = body['error']?['message']?.toString() ?? 'REQUEST_FAILED';
      throw Exception(code);
    } catch (_) {
      throw Exception('REQUEST_FAILED_${resp.statusCode}');
    }
  }
}

