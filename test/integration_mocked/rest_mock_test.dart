import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nootes/services/firestore_service.dart';
import 'package:nootes/services/auth_service.dart';
import 'package:nootes/services/field_timestamp_helper.dart';

// Minimal fake AuthService implementation used only by these tests.
class _FakeAuthService implements AuthService {
  @override
  AuthUser? get currentUser => const AuthUser(uid: 'test-user', email: 'test@example.com');

  @override
  bool get usesRest => true;

  @override
  Stream<AuthUser?> authStateChanges() => Stream.value(currentUser);

  @override
  Future<void> init() async {}

  @override
  Future<AuthUser> createUserWithEmailAndPassword(String email, String password) async =>
      AuthUser(uid: 'u', email: email);

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<AuthUser> signInWithEmailAndPassword(String email, String password) async =>
      AuthUser(uid: 'u', email: email);

  @override
  Future<void> signOut() async {}

  @override
  Future<String?> getIdToken() async => 'fake-token';
}

void main() {
  group('REST mocked http payload', () {
    // Install a lightweight fake AuthService so tests don't attempt to
    // initialize the Firebase native plugin when exercising REST code.
    setUp(() {
      AuthService.testInstance = _FakeAuthService();
    });

    tearDown(() {
      // Clear the test instance and reset any restTestInstance client
      AuthService.testInstance = null;
      FirestoreService.restTestInstance(client: null);
    });

    test('createNote sends per-field companion timestamps', () async {
      // Intercept POST and capture body
      late Map<String, dynamic> capturedBody;
      final mock = MockClient((req) async {
        if (req.method == 'POST' && req.url.path.contains('/notes')) {
          capturedBody = jsonDecode(req.body) as Map<String, dynamic>;
          // Return a fake successful response
          return http.Response(jsonEncode({'name': '${req.url.path}/fake-id'}), 200);
        }
        return http.Response('{}', 200);
      });

      // Inject mock client
  final svc = FirestoreService.restTestInstance(client: mock);

      final data = {'title': 'Hi', 'tags': <String>['a']};
      final stamped = attachFieldTimestamps(Map<String, dynamic>.from(data));

      final id = await svc.createNote(uid: 'u', data: stamped);
      expect(id, isNotEmpty);

      // Validate payload structure
      expect(capturedBody, contains('fields'));
      final fields = capturedBody['fields'] as Map<String, dynamic>;
      expect(fields.containsKey('title_lastClientUpdateAt'), isTrue);
      // Companion may be encoded as timestampValue or stringValue depending
      // on whether the helper encoded a DateTime or a String. Accept either.
      expect(
        fields['title_lastClientUpdateAt']['timestampValue'] ??
            fields['title_lastClientUpdateAt']['stringValue'],
        isNotNull,
      );

  FirestoreService.restTestInstance(client: null);
    });

    test('updateNote sends per-field companion timestamps via patch', () async {
      late Map<String, dynamic> capturedBody;
      final mock = MockClient((req) async {
        if (req.method == 'PATCH' && req.url.path.contains('/notes/')) {
          capturedBody = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response('{}', 200);
        }
        return http.Response('{}', 200);
      });

  final svc = FirestoreService.restTestInstance(client: mock);

      final data = {'content': 'Updated'};
      final stamped = attachFieldTimestamps(Map<String, dynamic>.from(data));

      await svc.updateNote(uid: 'u', noteId: 'n', data: stamped);

      expect(capturedBody, contains('fields'));
      final fields = capturedBody['fields'] as Map<String, dynamic>;
      expect(fields.containsKey('content_lastClientUpdateAt'), isTrue);
      expect(
        fields['content_lastClientUpdateAt']['timestampValue'] ??
            fields['content_lastClientUpdateAt']['stringValue'],
        isNotNull,
      );

  FirestoreService.restTestInstance(client: null);
    });

    test('setPinned sends companion for pinned (patch)', () async {
      late Map<String, dynamic> capturedBody;
      final mock = MockClient((req) async {
        if (req.method == 'PATCH' && req.url.path.contains('/notes/')) {
          capturedBody = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response('{}', 200);
        }
        return http.Response('{}', 200);
      });

      final svc = FirestoreService.restTestInstance(client: mock);

      await svc.setPinned(uid: 'u', noteId: 'n', pinned: true);

      expect(capturedBody, contains('fields'));
      final fields = capturedBody['fields'] as Map<String, dynamic>;
      expect(fields.containsKey('pinned'), isTrue);
      expect(fields.containsKey('pinned_lastClientUpdateAt'), isTrue);
      expect(
        fields['pinned_lastClientUpdateAt']['timestampValue'] ??
            fields['pinned_lastClientUpdateAt']['stringValue'],
        isNotNull,
      );

      FirestoreService.restTestInstance(client: null);
    });

    test('addTagToNote does array-op: tags no companion, updatedAt present', () async {
      late Map<String, dynamic> capturedPatch;
      final mock = MockClient((req) async {
        // Simulate GET returning current note with tags ['x']
        if (req.method == 'GET' && req.url.path.contains('/notes/')) {
          final resp = {
            'name': req.url.path,
            'fields': {
              'tags': {
                'arrayValue': {
                  'values': [
                    {'stringValue': 'x'}
                  ]
                }
              }
            }
          };
          return http.Response(jsonEncode(resp), 200);
        }

        // Capture PATCH body
        if (req.method == 'PATCH' && req.url.path.contains('/notes/')) {
          capturedPatch = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response('{}', 200);
        }

        return http.Response('{}', 200);
      });

      final svc = FirestoreService.restTestInstance(client: mock);

      await svc.addTagToNote(uid: 'u', noteId: 'n', tag: 'y');

      expect(capturedPatch, contains('fields'));
      final fields = capturedPatch['fields'] as Map<String, dynamic>;
      // 'tags' should be present (arrayValue), but no companion 'tags_lastClientUpdateAt'
      expect(fields.containsKey('tags'), isTrue);
      expect(fields.containsKey('tags_lastClientUpdateAt'), isFalse);
      // updatedAt should be present
      expect(fields.containsKey('updatedAt'), isTrue);

      FirestoreService.restTestInstance(client: null);
    });
  });
}
