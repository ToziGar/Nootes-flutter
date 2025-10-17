import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
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

  // Testing helper: allow tests to inject a fake implementation.
  static set testInstance(AuthService? v) => _instance = v;

  // Helper to obtain a valid ID token for REST calls
  static Future<String> instanceToken() async {
    final t = await instance.getIdToken();
    if (t == null) {
      throw Exception('auth/no-id-token');
    }
    return t;
  }

  static AuthService _resolve() {
    // Workaround: Firebase native auth plugin has produced platform-channel
    // threading warnings on Windows in this project. To avoid those runtime
    // issues we prefer the REST-based implementation on Windows desktop,
    // while keeping the native plugin for mobile and web.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return _RestAuthService();
    }

    final isMobileOrWeb =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    if (isMobileOrWeb) return _FirebaseAuthService();
    return _RestAuthService();
  }

  bool get usesRest;
  AuthUser? get currentUser;
  Stream<AuthUser?> authStateChanges();
  Future<void> init();
  Future<void> signOut();
  Future<AuthUser> signInWithEmailAndPassword(String email, String password);
  Future<AuthUser> createUserWithEmailAndPassword(
    String email,
    String password,
  );
  Future<void> sendPasswordResetEmail(String email);
  Future<String?> getIdToken();
}

class _FirebaseAuthService implements AuthService {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  @override
  bool get usesRest => false;

  @override
  AuthUser? get currentUser {
    final u = _auth.currentUser;
    return u == null ? null : AuthUser(uid: u.uid, email: u.email);
  }

  @override
  Stream<AuthUser?> authStateChanges() => _auth.authStateChanges().map(
    (u) => u == null ? null : AuthUser(uid: u.uid, email: u.email),
  );

  @override
  Future<void> init() async {
    // Localize outgoing auth emails to the device locale when possible
    try {
      final tag = ui.PlatformDispatcher.instance.locale.toLanguageTag();
      if (tag.isNotEmpty) {
        await _auth.setLanguageCode(tag);
      }
    } catch (_) {
      // ignore
    }
  }

  @override
  Future<AuthUser> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final u = cred.user!;
    return AuthUser(uid: u.uid, email: u.email);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) {
    final authDomain = DefaultFirebaseOptions.web.authDomain;
    final continueUrl = (authDomain != null && authDomain.isNotEmpty)
        ? 'https://$authDomain'
        : null;
    fb.ActionCodeSettings? acs;
    if (continueUrl != null) {
      acs = fb.ActionCodeSettings(url: continueUrl, handleCodeInApp: false);
    }
    return _auth.sendPasswordResetEmail(email: email, actionCodeSettings: acs);
  }

  @override
  Future<AuthUser> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final u = cred.user!;
    return AuthUser(uid: u.uid, email: u.email);
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<String?> getIdToken() async => (await _auth.currentUser?.getIdToken());
}

class _RestAuthService implements AuthService {
  // Identity Toolkit endpoints
  static const _identityBase = 'https://identitytoolkit.googleapis.com/v1';
  static const _secureToken = 'https://securetoken.googleapis.com/v1';

  final _controller = StreamController<AuthUser?>.broadcast();
  final _storage = const FlutterSecureStorage();

  // ignore: unused_field
  String? _idToken; // Cached token
  String? _refreshToken;
  String? _uid;
  String? _email;
  DateTime? _expiry;

  String get _apiKey => DefaultFirebaseOptions.web.apiKey; // reuse Web API key

  @override
  bool get usesRest => true;

  @override
  AuthUser? get currentUser =>
      _uid == null ? null : AuthUser(uid: _uid!, email: _email);

  bool get _isExpired => _expiry == null || DateTime.now().isAfter(_expiry!);

  @override
  Future<String?> getIdToken() async {
    if (_idToken == null || _isExpired) {
      await _refreshIdToken();
    }
    return _idToken;
  }

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
  Future<AuthUser> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final uri = Uri.parse('$_identityBase/accounts:signUp?key=$_apiKey');
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'returnSecureToken': true,
      }),
    );
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
    // Best-effort continue URL to the app's auth domain so users land back in app after reset
    final authDomain = DefaultFirebaseOptions.web.authDomain;
    final continueUrl = (authDomain != null && authDomain.isNotEmpty)
        ? 'https://$authDomain'
        : null;
    final payload = <String, dynamic>{
      'requestType': 'PASSWORD_RESET',
      'email': email,
    };
    if (continueUrl != null) {
      payload['continueUrl'] = continueUrl;
      // Desktop/web flows will open the browser; we don't handle the code in-app
      payload['canHandleCodeInApp'] = false;
    }
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    _handleError(resp);
  }

  @override
  Future<AuthUser> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final uri = Uri.parse(
      '$_identityBase/accounts:signInWithPassword?key=$_apiKey',
    );
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'returnSecureToken': true,
      }),
    );
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
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'grant_type': 'refresh_token', 'refresh_token': _refreshToken!},
    );
    _handleError(resp);
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    _idToken = data['id_token'] as String?;
    _refreshToken = data['refresh_token'] as String? ?? _refreshToken;
    _uid = data['user_id'] as String? ?? _uid;
    _email = data['email'] as String? ?? _email;
    final expiresIn =
        int.tryParse(data['expires_in']?.toString() ?? '3600') ?? 3600;
    _expiry = DateTime.now().add(Duration(seconds: expiresIn - 30));
    await _persist();
  }

  void _applyAuth(Map<String, dynamic> data) {
    _idToken = data['idToken'] as String?;
    _refreshToken = data['refreshToken'] as String?;
    _uid = data['localId'] as String?;
    _email = data['email'] as String?;
    final expiresIn =
        int.tryParse(data['expiresIn']?.toString() ?? '3600') ?? 3600;
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
    if (_refreshToken != null) {
      await _storage.write(key: 'refreshToken', value: _refreshToken);
    }
    if (_uid != null) {
      await _storage.write(key: 'uid', value: _uid);
    }
    if (_email != null) {
      await _storage.write(key: 'email', value: _email);
    }
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
