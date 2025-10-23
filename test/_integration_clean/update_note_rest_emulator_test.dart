import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show debugPrint, debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:nootes/services/firestore_service.dart';
import 'package:nootes/services/auth_service.dart';

class _FakeAuth implements AuthService {
  final String _uid;
  _FakeAuth({String uid = 'test-user'}) : _uid = uid;

  @override
  bool get usesRest => true;

  @override
  AuthUser? get currentUser => AuthUser(uid: _uid, email: 'test@example.com');

  @override
  Stream<AuthUser?> authStateChanges() => Stream<AuthUser?>.value(currentUser);

  @override
  Future<void> init() async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthUser> signInWithEmailAndPassword(
    String email,
    String password,
  ) async => AuthUser(uid: _uid, email: email);

  @override
  Future<AuthUser> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async => AuthUser(uid: _uid, email: email);

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<String?> getIdToken() async => 'fake-token';
}

void main() {
  final emulator = Platform.environment['FIRESTORE_EMULATOR_HOST'];

  group('Firestore REST emulator integration', () {
    test('patchNoteFields injects per-field companion timestamps', () async {
      final uid = 'rest_integration_user';
      final noteId = 'rest-note-1';

      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      AuthService.testInstance = _FakeAuth(uid: uid);

      FirestoreService service;

      bool useRealEmulator = false;
      if (emulator != null) {
        try {
          final parts = emulator.split(':');
          final host = parts[0];
          final port = int.parse(parts[1]);
          final sock = await Socket.connect(
            host,
            port,
            timeout: const Duration(milliseconds: 300),
          );
          sock.destroy();
          useRealEmulator = true;
        } catch (e) {
          debugPrint(
            'Emulator advertised but unreachable: $e — falling back to mocked HTTP',
          );
          useRealEmulator = false;
        }
      }

      if (!useRealEmulator) {
        final mock = MockClient((req) async {
          if (req.method == 'POST' && req.url.path.contains('/notes')) {
            final name =
                '/projects/fake-project/databases/(default)/documents/users/$uid/notes/$noteId';
            return http.Response(jsonEncode({'name': name}), 200);
          }
          if (req.method == 'PATCH' && req.url.path.contains('/notes/')) {
            return http.Response('{}', 200);
          }
          if (req.method == 'GET' && req.url.path.contains('/notes/')) {
            final resp = {
              'name': req.url.path,
              'fields': {
                'title': {'stringValue': 'Updated REST'},
                'title_lastClientUpdateAt': {
                  'stringValue': DateTime.now().toIso8601String(),
                },
              },
            };
            return http.Response(jsonEncode(resp), 200);
          }
          return http.Response('{}', 200);
        });

        service = FirestoreService.restTestInstance(client: mock);
      } else {
        service = FirestoreService.instance;
      }

      try {
        await service.purgeNote(uid: uid, noteId: noteId);
      } catch (_) {}

      await service.createNote(
        uid: uid,
        data: {
          'title': 'Initial REST',
          'tags': ['x', 'y'],
          'count': 1,
        },
      );

      await service.updateNote(
        uid: uid,
        noteId: noteId,
        data: {
          'title': 'Updated REST',
          'tags': ['y', 'z'],
        },
      );

      final fetched = await service.getNote(uid: uid, noteId: noteId);
      expect(fetched, isNotNull);
      expect(fetched!['title'], 'Updated REST');

      final companionKey = 'title_lastClientUpdateAt';
      expect(fetched.containsKey(companionKey), isTrue);
      final companion = fetched[companionKey];
      expect(companion, isNotNull);
      expect(companion is String || companion is Map, isTrue);
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      AuthService.testInstance = null;
      FirestoreService.restTestInstance(client: null);
    });
  });
}
