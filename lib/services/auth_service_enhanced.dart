import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../firebase_options.dart';
import 'logging_service.dart';
import 'exceptions/auth_exceptions.dart';

class AuthUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoURL;
  final bool emailVerified;
  final DateTime? lastSignInTime;
  final DateTime? creationTime;
  
  const AuthUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
    this.emailVerified = false,
    this.lastSignInTime,
    this.creationTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'emailVerified': emailVerified,
      'lastSignInTime': lastSignInTime?.toIso8601String(),
      'creationTime': creationTime?.toIso8601String(),
    };
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      uid: json['uid'],
      email: json['email'],
      displayName: json['displayName'],
      photoURL: json['photoURL'],
      emailVerified: json['emailVerified'] ?? false,
      lastSignInTime: json['lastSignInTime'] != null
          ? DateTime.parse(json['lastSignInTime'])
          : null,
      creationTime: json['creationTime'] != null
          ? DateTime.parse(json['creationTime'])
          : null,
    );
  }

  AuthUser copyWith({
    String? displayName,
    String? photoURL,
    bool? emailVerified,
  }) {
    return AuthUser(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      emailVerified: emailVerified ?? this.emailVerified,
      lastSignInTime: lastSignInTime,
      creationTime: creationTime,
    );
  }
}

/// Configuration for authentication behavior
class AuthConfig {
  const AuthConfig({
    this.enablePersistence = true,
    this.sessionTimeout = const Duration(hours: 24),
    this.enableTokenRefresh = true,
    this.enableBiometric = false,
    this.requireEmailVerification = false,
    this.enableLogging = true,
  });

  final bool enablePersistence;
  final Duration sessionTimeout;
  final bool enableTokenRefresh;
  final bool enableBiometric;
  final bool requireEmailVerification;
  final bool enableLogging;
}

/// Enhanced authentication service with improved error handling and features
abstract class AuthService {
  static AuthService? _instance;
  static AuthService get instance => _instance ??= _resolve();

  // Configuration
  AuthConfig get config;
  void updateConfig(AuthConfig newConfig);

  // Helper to obtain a valid ID token for REST calls
  static Future<String> instanceToken() async {
    final t = await instance.getIdToken();
    if (t == null) {
  throw const GenericAuthException('No hay token de autenticación disponible');
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
  
  // Core authentication methods
  Future<void> init();
  Future<void> signOut();
  Future<AuthUser> signInWithEmailAndPassword(String email, String password);
  Future<AuthUser> createUserWithEmailAndPassword(String email, String password);
  Future<void> sendPasswordResetEmail(String email);
  Future<String?> getIdToken();
  
  // Enhanced authentication methods
  Future<AuthUser> signInAnonymously();
  Future<void> linkEmailPassword(String email, String password);
  Future<void> sendEmailVerification();
  Future<void> reloadUser();
  Future<void> deleteUser();
  
  // Profile management
  Future<void> updateProfile({String? displayName, String? photoURL});
  Future<void> updateEmail(String newEmail);
  Future<void> updatePassword(String newPassword);
  
  // Session management
  Future<bool> isSessionValid();
  Future<void> refreshToken();
  Future<Map<String, dynamic>> getSessionInfo();
  
  // Security features
  Future<void> enableMFA();
  Future<void> disableMFA();
  Future<List<String>> getLinkedProviders();
  
  // Cleanup and monitoring
  void dispose();
  Stream<AuthSessionEvent> get sessionEvents;
}

/// Events for session monitoring
enum AuthSessionEventType {
  signIn,
  signOut,
  tokenRefresh,
  sessionExpired,
  error,
}

class AuthSessionEvent {
  final AuthSessionEventType type;
  final DateTime timestamp;
  final AuthUser? user;
  final String? error;
  final Map<String, dynamic>? metadata;

  const AuthSessionEvent({
    required this.type,
    required this.timestamp,
    this.user,
    this.error,
    this.metadata,
  });
}

/// Enhanced Firebase authentication service implementation
class _FirebaseAuthService implements AuthService {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final _sessionController = StreamController<AuthSessionEvent>.broadcast();
  
  AuthConfig _config = const AuthConfig();
  Timer? _sessionTimer;

  @override
  AuthConfig get config => _config;

  @override
  void updateConfig(AuthConfig newConfig) {
    _config = newConfig;
    if (_config.enableLogging) {
      LoggingService.info('AuthService configuración actualizada', 
          data: {'newConfig': _config.toString()});
    }
  }

  @override
  bool get usesRest => false;

  @override
  AuthUser? get currentUser {
    final user = _auth.currentUser;
    if (user == null) return null;

    return AuthUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoURL: user.photoURL,
      emailVerified: user.emailVerified,
      lastSignInTime: user.metadata.lastSignInTime,
      creationTime: user.metadata.creationTime,
    );
  }

  @override
  Stream<AuthUser?> authStateChanges() {
    return _auth.authStateChanges().map((user) {
      final authUser = user != null ? AuthUser(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
        photoURL: user.photoURL,
        emailVerified: user.emailVerified,
        lastSignInTime: user.metadata.lastSignInTime,
        creationTime: user.metadata.creationTime,
      ) : null;

      // Emit session event
      if (authUser != null) {
        _sessionController.add(AuthSessionEvent(
          type: AuthSessionEventType.signIn,
          timestamp: DateTime.now(),
          user: authUser,
        ));
      } else {
        _sessionController.add(AuthSessionEvent(
          type: AuthSessionEventType.signOut,
          timestamp: DateTime.now(),
        ));
      }

      return authUser;
    });
  }

  @override
  Stream<AuthSessionEvent> get sessionEvents => _sessionController.stream;

  @override
  Future<void> init() async {
    try {
      // Set up persistence if enabled
      if (_config.enablePersistence) {
        await _auth.setPersistence(fb.Persistence.LOCAL);
      }

      // Start session monitoring
      if (_config.enableTokenRefresh) {
        _startSessionMonitoring();
      }
    } catch (e) {
      throw GenericAuthException('Error al inicializar el servicio de autenticación');
    }
  }

  @override
  Future<AuthUser> createUserWithEmailAndPassword(String email, String password) async {
    try {
      _validateEmailAndPassword(email, password);
      
      if (_config.enableLogging) {
        LoggingService.info('Creando usuario', tag: 'Auth', data: {'email': email});
      }

      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user!;
      
      // Send verification email if required
      if (_config.requireEmailVerification && !user.emailVerified) {
        await user.sendEmailVerification();
      }

      final authUser = AuthUser(
        uid: user.uid,
        email: user.email,
        emailVerified: user.emailVerified,
        creationTime: user.metadata.creationTime,
      );

      if (_config.enableLogging) {
        LoggingService.info('Usuario creado exitosamente', tag: 'Auth', data: {'uid': user.uid});
      }

      return authUser;
    } catch (e) {
      LoggingService.error('Error creando usuario', tag: 'Auth', error: e);
      throw _mapFirebaseException(e);
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      _validateEmail(email);
      
      final authDomain = DefaultFirebaseOptions.web.authDomain;
      final continueUrl = (authDomain != null && authDomain.isNotEmpty)
          ? 'https://$authDomain'
          : null;
      
      fb.ActionCodeSettings? acs;
      if (continueUrl != null) {
        acs = fb.ActionCodeSettings(url: continueUrl, handleCodeInApp: false);
      }
      
      await _auth.sendPasswordResetEmail(email: email, actionCodeSettings: acs);
      
      if (_config.enableLogging) {
        LoggingService.info('Email de recuperación enviado', tag: 'Auth', data: {'email': email});
      }
    } catch (e) {
      LoggingService.error('Error enviando email de recuperación', tag: 'Auth', error: e);
      throw _mapFirebaseException(e);
    }
  }

  @override
  Future<AuthUser> signInWithEmailAndPassword(String email, String password) async {
    try {
      _validateEmailAndPassword(email, password);
      
      if (_config.enableLogging) {
        LoggingService.info('Iniciando sesión', tag: 'Auth', data: {'email': email});
      }

      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user!;
      
      // Check email verification if required
      if (_config.requireEmailVerification && !user.emailVerified) {
        await signOut();
        throw EmailNotVerifiedException();
      }

      final authUser = AuthUser(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
        photoURL: user.photoURL,
        emailVerified: user.emailVerified,
        lastSignInTime: user.metadata.lastSignInTime,
        creationTime: user.metadata.creationTime,
      );

      if (_config.enableLogging) {
        LoggingService.info('Sesión iniciada exitosamente', tag: 'Auth', data: {'uid': user.uid});
      }

      return authUser;
    } catch (e) {
      LoggingService.error('Error iniciando sesión', tag: 'Auth', error: e);
      throw _mapFirebaseException(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      if (_config.enableLogging) {
        LoggingService.info('Cerrando sesión', tag: 'Auth');
      }
      
      await _auth.signOut();
      _sessionTimer?.cancel();
      
      if (_config.enableLogging) {
        LoggingService.info('Sesión cerrada exitosamente', tag: 'Auth');
      }
    } catch (e) {
      LoggingService.error('Error cerrando sesión', tag: 'Auth', error: e);
      throw GenericAuthException('Error al cerrar sesión');
    }
  }

  @override
  Future<String?> getIdToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      
      return await user.getIdToken(_config.enableTokenRefresh);
    } catch (e) {
      LoggingService.error('Error obteniendo token', tag: 'Auth', error: e);
      throw GenericAuthException('Error al obtener token de autenticación');
    }
  }

  @override
  Future<AuthUser> signInAnonymously() async {
    try {
      if (_config.enableLogging) {
        LoggingService.info('Iniciando sesión anónima', tag: 'Auth');
      }

      final cred = await _auth.signInAnonymously();
      final user = cred.user!;

      return AuthUser(
        uid: user.uid,
        email: user.email,
        emailVerified: user.emailVerified,
        creationTime: user.metadata.creationTime,
      );
    } catch (e) {
      LoggingService.error('Error en autenticación anónima', tag: 'Auth', error: e);
      throw _mapFirebaseException(e);
    }
  }

  @override
  Future<void> linkEmailPassword(String email, String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw const NotAuthenticatedException();

      _validateEmailAndPassword(email, password);

      final credential = fb.EmailAuthProvider.credential(email: email, password: password);
      await user.linkWithCredential(credential);

      if (_config.enableLogging) {
        LoggingService.info('Cuenta enlazada exitosamente', tag: 'Auth', data: {'email': email});
      }
    } catch (e) {
      LoggingService.error('Error enlazando cuenta', tag: 'Auth', error: e);
      throw _mapFirebaseException(e);
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
  if (user == null) throw const NotAuthenticatedException();

      await user.sendEmailVerification();
      
      if (_config.enableLogging) {
        LoggingService.info('Email de verificación enviado', tag: 'Auth');
      }
    } catch (e) {
      LoggingService.error('Error enviando verificación', tag: 'Auth', error: e);
      throw _mapFirebaseException(e);
    }
  }

  @override
  Future<void> reloadUser() async {
    try {
      final user = _auth.currentUser;
  if (user == null) throw const NotAuthenticatedException();

      await user.reload();
    } catch (e) {
      LoggingService.error('Error recargando usuario', tag: 'Auth', error: e);
      throw _mapFirebaseException(e);
    }
  }

  @override
  Future<void> deleteUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw const NotAuthenticatedException();

      if (_config.enableLogging) {
        LoggingService.info('Eliminando cuenta de usuario', tag: 'Auth', data: {'uid': user.uid});
      }

      await user.delete();
      
      if (_config.enableLogging) {
        LoggingService.info('Cuenta eliminada exitosamente', tag: 'Auth');
      }
    } catch (e) {
      LoggingService.error('Error eliminando usuario', tag: 'Auth', error: e);
      throw _mapFirebaseException(e);
    }
  }

  @override
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw const NotAuthenticatedException();

      await user.updateDisplayName(displayName);
      if (photoURL != null) {
        await user.updatePhotoURL(photoURL);
      }

      if (_config.enableLogging) {
        LoggingService.info('Perfil actualizado', tag: 'Auth', data: {
          'displayName': displayName,
          'photoURL': photoURL,
        });
      }
    } catch (e) {
      LoggingService.error('Error actualizando perfil', tag: 'Auth', error: e);
      throw _mapFirebaseException(e);
    }
  }

  @override
  Future<void> updateEmail(String newEmail) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw const NotAuthenticatedException();
      _validateEmail(newEmail);
      try {
        // ignore: deprecated_member_use
  // API updateEmail no disponible en esta versión de Firebase Auth
  // ignore: deprecated_member_use
  await (user as dynamic).updateEmail?.call(newEmail);
      } catch (_) {
        final dynamic dynUser = user;
        try {
          await dynUser.verifyBeforeUpdateEmail(newEmail);
        } catch (_) {
          rethrow;
        }
      }
      if (_config.enableLogging) {
        LoggingService.info('Email actualizado', tag: 'Auth', data: {'newEmail': newEmail});
      }
    } catch (e) {
      LoggingService.error('Error actualizando email', tag: 'Auth', error: e);
      throw _mapFirebaseException(e);
    }
  }
  @override
  Future<void> updatePassword(String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw const NotAuthenticatedException();

      _validatePassword(newPassword);
      await user.updatePassword(newPassword);

      if (_config.enableLogging) {
        LoggingService.info('Contraseña actualizada', tag: 'Auth');
      }
    } catch (e) {
      LoggingService.error('Error actualizando contraseña', tag: 'Auth', error: e);
      throw _mapFirebaseException(e);
    }
  }

  @override
  Future<bool> isSessionValid() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      await user.getIdToken(true); // force refresh
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> refreshToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw const NotAuthenticatedException();

      await user.getIdToken(true);
      
      _sessionController.add(AuthSessionEvent(
        type: AuthSessionEventType.tokenRefresh,
        timestamp: DateTime.now(),
        user: currentUser,
      ));

      if (_config.enableLogging) {
        LoggingService.info('Token actualizado', tag: 'Auth');
      }
    } catch (e) {
      LoggingService.error('Error actualizando token', tag: 'Auth', error: e);
      throw GenericAuthException('Error al actualizar token');
    }
  }

  @override
  Future<Map<String, dynamic>> getSessionInfo() async {
    final user = currentUser;
    if (user == null) return {'authenticated': false};

    return {
      'authenticated': true,
      'uid': user.uid,
      'email': user.email,
      'emailVerified': user.emailVerified,
      'lastSignInTime': user.lastSignInTime?.toIso8601String(),
      'creationTime': user.creationTime?.toIso8601String(),
      'sessionValid': await isSessionValid(),
    };
  }

  @override
  Future<void> enableMFA() async {
    // Firebase MFA implementation would go here
    throw UnimplementedError('MFA no implementado en esta versión');
  }

  @override
  Future<void> disableMFA() async {
    // Firebase MFA implementation would go here
    throw UnimplementedError('MFA no implementado en esta versión');
  }

  @override
  Future<List<String>> getLinkedProviders() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      return user.providerData.map((info) => info.providerId).toList();
    } catch (e) {
      LoggingService.error('Error obteniendo proveedores', tag: 'Auth', error: e);
      return [];
    }
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _sessionController.close();
  }

  // Private helper methods
  void _startSessionMonitoring() {
    _sessionTimer = Timer.periodic(Duration(minutes: 30), (timer) async {
      if (!(await isSessionValid())) {
        _sessionController.add(AuthSessionEvent(
          type: AuthSessionEventType.sessionExpired,
          timestamp: DateTime.now(),
        ));
        await signOut();
      }
    });
  }

  void _validateEmail(String email) {
    if (email.isEmpty || !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      throw InvalidEmailException();
    }
  }

  void _validatePassword(String password) {
    if (password.length < 6) {
      throw WeakPasswordException();
    }
  }

  void _validateEmailAndPassword(String email, String password) {
    _validateEmail(email);
    _validatePassword(password);
  }

  AuthenticationException _mapFirebaseException(dynamic e) {
    if (e is fb.FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return UserNotFoundException();
        case 'wrong-password':
          return WrongPasswordException();
        case 'email-already-in-use':
          return EmailAlreadyInUseException();
        case 'weak-password':
          return WeakPasswordException();
        case 'invalid-email':
          return InvalidEmailException();
        case 'user-disabled':
          return UserDisabledException();
        case 'too-many-requests':
          return TooManyRequestsException();
        default:
          return GenericAuthException(e.message ?? 'Error de autenticación');
      }
    }
  return GenericAuthException(e.toString());
  }
}

/// Enhanced REST authentication service (for Windows desktop)
class _RestAuthService implements AuthService {
  static const _identityBase = 'https://identitytoolkit.googleapis.com/v1';
  static const _secureToken = 'https://securetoken.googleapis.com/v1';

  final _controller = StreamController<AuthUser?>.broadcast();
  final _sessionController = StreamController<AuthSessionEvent>.broadcast();
  final _storage = const FlutterSecureStorage();
  // Usamos LoggingService de forma estática; mantener instancia no es necesario

  AuthConfig _config = const AuthConfig();
  String? _idToken;
  String? _refreshToken;
  String? _uid;
  String? _email;
  DateTime? _expiry;
  Timer? _sessionTimer;

  String get _apiKey => DefaultFirebaseOptions.web.apiKey;

  @override
  AuthConfig get config => _config;

  @override
  void updateConfig(AuthConfig newConfig) {
    _config = newConfig;
  }

  @override
  bool get usesRest => true;

  @override
  AuthUser? get currentUser =>
      _uid == null ? null : AuthUser(uid: _uid!, email: _email);

  bool get _isExpired => _expiry == null || DateTime.now().isAfter(_expiry!);

  @override
  Stream<AuthUser?> authStateChanges() => _controller.stream;

  @override
  Stream<AuthSessionEvent> get sessionEvents => _sessionController.stream;

  @override
  Future<String?> getIdToken() async {
    if (_idToken == null || _isExpired) {
      await _refreshIdToken();
    }
    return _idToken;
  }

  @override
  Future<void> init() async {
    try {
      if (_config.enablePersistence) {
        await _loadFromStorage();
      }
      
      if (_config.enableTokenRefresh) {
        _startSessionMonitoring();
      }

      if (_config.enableLogging) {
        LoggingService.info('REST AuthService inicializado', tag: 'AuthREST');
      }
    } catch (e) {
      LoggingService.error('Error inicializando REST AuthService', tag: 'AuthREST', error: e);
    }
  }

  @override
  Future<AuthUser> createUserWithEmailAndPassword(String email, String password) async {
    try {
      _validateEmailAndPassword(email, password);

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

      if (resp.statusCode != 200) {
        throw Exception('Failed to create user: ${resp.body}');
      }

      final data = jsonDecode(resp.body);
      await _setUserData(data);

      final user = AuthUser(uid: _uid!, email: _email);
      
      if (_config.enableLogging) {
        LoggingService.info('Usuario creado con REST API', tag: 'AuthREST', data: {'uid': _uid});
      }

      return user;
    } catch (e) {
      LoggingService.error('Error creando usuario (REST)', tag: 'AuthREST', error: e);
      throw _mapRestException(e);
    }
  }

  @override
  Future<AuthUser> signInWithEmailAndPassword(String email, String password) async {
    try {
      _validateEmailAndPassword(email, password);

      final uri = Uri.parse('$_identityBase/accounts:signInWithPassword?key=$_apiKey');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'returnSecureToken': true,
        }),
      );

      if (resp.statusCode != 200) {
        throw Exception('Failed to sign in: ${resp.body}');
      }

      final data = jsonDecode(resp.body);
      await _setUserData(data);

      final user = AuthUser(uid: _uid!, email: _email);
      _controller.add(user);

      _sessionController.add(AuthSessionEvent(
        type: AuthSessionEventType.signIn,
        timestamp: DateTime.now(),
        user: user,
      ));

      if (_config.enableLogging) {
        LoggingService.info('Sesión iniciada con REST API', tag: 'AuthREST', data: {'uid': _uid});
      }

      return user;
    } catch (e) {
      LoggingService.error('Error iniciando sesión (REST)', tag: 'AuthREST', error: e);
      throw _mapRestException(e);
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      _validateEmail(email);

      final uri = Uri.parse('$_identityBase/accounts:sendOobCode?key=$_apiKey');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requestType': 'PASSWORD_RESET',
          'email': email,
        }),
      );

      if (resp.statusCode != 200) {
        throw Exception('Failed to send reset email: ${resp.body}');
      }

      if (_config.enableLogging) {
        LoggingService.info('Email de recuperación enviado (REST)', tag: 'AuthREST', data: {'email': email});
      }
    } catch (e) {
      LoggingService.error('Error enviando email de recuperación (REST)', tag: 'AuthREST', error: e);
      throw _mapRestException(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      if (_config.enablePersistence) {
        await _clearStorage();
      }
      
      _idToken = null;
      _refreshToken = null;
      _uid = null;
      _email = null;
      _expiry = null;
      
      _controller.add(null);
      _sessionTimer?.cancel();

      _sessionController.add(AuthSessionEvent(
        type: AuthSessionEventType.signOut,
        timestamp: DateTime.now(),
      ));

      if (_config.enableLogging) {
        LoggingService.info('Sesión cerrada (REST)', tag: 'AuthREST');
      }
    } catch (e) {
      LoggingService.error('Error cerrando sesión (REST)', tag: 'AuthREST', error: e);
    }
  }

  // Implementation of other required methods...
  @override
  Future<AuthUser> signInAnonymously() async {
    throw UnimplementedError('Autenticación anónima no implementada en REST');
  }

  @override
  Future<void> linkEmailPassword(String email, String password) async {
    throw UnimplementedError('Enlace de cuenta no implementado en REST');
  }

  @override
  Future<void> sendEmailVerification() async {
    throw UnimplementedError('Verificación de email no implementada en REST');
  }

  @override
  Future<void> reloadUser() async {
    // No-op for REST implementation
  }

  @override
  Future<void> deleteUser() async {
    throw UnimplementedError('Eliminación de usuario no implementada en REST');
  }

  @override
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    throw UnimplementedError('Actualización de perfil no implementada en REST');
  }

  @override
  Future<void> updateEmail(String newEmail) async {
    throw UnimplementedError('Actualización de email no implementada en REST');
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    throw UnimplementedError('Actualización de contraseña no implementada en REST');
  }

  @override
  Future<bool> isSessionValid() async {
    return _uid != null && !_isExpired;
  }

  @override
  Future<void> refreshToken() async {
    await _refreshIdToken();
  }

  @override
  Future<Map<String, dynamic>> getSessionInfo() async {
    return {
      'authenticated': _uid != null,
      'uid': _uid,
      'email': _email,
      'sessionValid': await isSessionValid(),
      'expiresAt': _expiry?.toIso8601String(),
    };
  }

  @override
  Future<void> enableMFA() async {
    throw UnimplementedError('MFA no implementado en REST');
  }

  @override
  Future<void> disableMFA() async {
    throw UnimplementedError('MFA no implementado en REST');
  }

  @override
  Future<List<String>> getLinkedProviders() async {
    return ['password']; // REST implementation only supports email/password
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _controller.close();
    _sessionController.close();
  }

  // Private helper methods for REST implementation
  Future<void> _refreshIdToken() async {
    if (_refreshToken == null) return;

    try {
      final uri = Uri.parse('$_secureToken/token?key=$_apiKey');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'grant_type': 'refresh_token',
          'refresh_token': _refreshToken,
        }),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        _idToken = data['id_token'];
        _refreshToken = data['refresh_token'];
        _expiry = DateTime.now().add(Duration(seconds: int.parse(data['expires_in'])));
        
        if (_config.enablePersistence) {
          await _persist();
        }

        _sessionController.add(AuthSessionEvent(
          type: AuthSessionEventType.tokenRefresh,
          timestamp: DateTime.now(),
          user: currentUser,
        ));
      }
    } catch (e) {
      LoggingService.error('Error actualizando token (REST)', tag: 'AuthREST', error: e);
    }
  }

  Future<void> _setUserData(Map<String, dynamic> data) async {
    _idToken = data['idToken'];
    _refreshToken = data['refreshToken'];
    _uid = data['localId'];
    _email = data['email'];
    _expiry = DateTime.now().add(Duration(seconds: int.parse(data['expiresIn'])));
    
    if (_config.enablePersistence) {
      await _persist();
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

  Future<void> _loadFromStorage() async {
    try {
      _refreshToken = await _storage.read(key: 'refreshToken');
      _uid = await _storage.read(key: 'uid');
      _email = await _storage.read(key: 'email');
      
      if (_refreshToken != null) {
        await _refreshIdToken();
        _controller.add(currentUser);
      }
    } catch (e) {
      LoggingService.error('Error cargando desde storage', tag: 'AuthREST', error: e);
    }
  }

  Future<void> _clearStorage() async {
    await _storage.delete(key: 'refreshToken');
    await _storage.delete(key: 'uid');
    await _storage.delete(key: 'email');
  }

  void _startSessionMonitoring() {
    _sessionTimer = Timer.periodic(Duration(minutes: 30), (timer) async {
      if (!(await isSessionValid())) {
        _sessionController.add(AuthSessionEvent(
          type: AuthSessionEventType.sessionExpired,
          timestamp: DateTime.now(),
        ));
        await signOut();
      }
    });
  }

  void _validateEmail(String email) {
    if (email.isEmpty || !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      throw InvalidEmailException();
    }
  }

  void _validatePassword(String password) {
    if (password.length < 6) {
      throw WeakPasswordException();
    }
  }

  void _validateEmailAndPassword(String email, String password) {
    _validateEmail(email);
    _validatePassword(password);
  }

  AuthenticationException _mapRestException(dynamic e) {
    final errorStr = e.toString().toLowerCase();
    
    if (errorStr.contains('email_not_found')) {
      return UserNotFoundException();
    } else if (errorStr.contains('invalid_password')) {
      return WrongPasswordException();
    } else if (errorStr.contains('email_exists')) {
      return EmailAlreadyInUseException();
    } else if (errorStr.contains('weak_password')) {
      return WeakPasswordException();
    } else if (errorStr.contains('invalid_email')) {
      return InvalidEmailException();
    } else if (errorStr.contains('too_many_attempts')) {
      return TooManyRequestsException();
    }
    
    return GenericAuthException(e.toString());
  }
}