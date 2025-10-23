import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nootes/services/firestore_service.dart';
import 'package:nootes/services/auth_service.dart';

void main() {
  group('RestFirestoreService mocked - array remove', () {
    setUp(() {
      AuthService.testInstance = FakeAuth(uid: 'user_1');
    });

    tearDown(() {
      AuthService.testInstance = null;
      FirestoreService.restTestInstance(client: null);
    });

    test('removeTagFromNote sends arrayRemove transform', () async {
      final captured = <http.Request>[];
      final client = MockClient((request) async {
        captured.add(request);
        return http.Response(
          '{}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final svc = FirestoreService.restTestInstance(client: client);

      await svc.removeTagFromNote(
        uid: 'user_1',
        noteId: 'note-123',
        tag: 'old-tag',
      );

      // We expect a PATCH with a 'fields' object containing tags (arrayValue)
      final patchReq = captured.firstWhere((r) => r.method == 'PATCH');
      final body = jsonDecode(patchReq.body) as Map<String, dynamic>;
      expect(body.containsKey('fields'), isTrue);
      final fields = body['fields'] as Map<String, dynamic>;
      expect(fields.containsKey('tags'), isTrue);
      expect(fields.containsKey('tags_lastClientUpdateAt'), isFalse);
      expect(fields.containsKey('updatedAt'), isTrue);
    });
  });
}

class FakeAuth implements AuthService {
  final String uid;
  FakeAuth({required this.uid});
  @override
  bool get usesRest => true;

  @override
  AuthUser? get currentUser => AuthUser(uid: uid, email: null);

  @override
  Stream<AuthUser?> authStateChanges() => Stream.value(currentUser);

  @override
  Future<void> init() async {}

  @override
  Future<AuthUser> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async => AuthUser(uid: uid, email: email);

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<AuthUser> signInWithEmailAndPassword(
    String email,
    String password,
  ) async => AuthUser(uid: uid, email: email);

  @override
  Future<void> signOut() async {}

  @override
  Future<String?> getIdToken() async => 'fake-token';
}
