import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nootes/services/firestore_service.dart';
import 'package:nootes/services/auth_service.dart';

void main() {
  group('RestFirestoreService mocked - sharing', () {
    setUp(() {
      // install fake auth for these tests
      AuthService.testInstance = FakeAuth(uid: 'owner_uid');
    });

    tearDown(() {
      AuthService.testInstance = null;
      FirestoreService.restTestInstance(client: null);
    });

    test('create and delete shared_items uses correct REST shape', () async {
      final captured = <http.Request>[];

      final client = MockClient((request) async {
        captured.add(request);
        // Return a typical Firestore create response
        return http.Response(jsonEncode({'name': 'projects/project/databases/(default)/documents/shared_items/owner_uid_recipient_uid_note1'}), 200,
            headers: {'content-type': 'application/json'});
      });

  final svc = FirestoreService.restTestInstance(client: client);

  final shareId = await svc.createEdgeDoc(uid: 'owner_uid', data: {'ownerId': 'owner_uid', 'recipientId': 'recipient_uid', 'noteId': 'note1'});

  expect(shareId, isNotEmpty);

  // Delete using the generic edge delete API
  await svc.deleteEdgeDoc(uid: 'owner_uid', edgeId: shareId);

      // Validate that at least one request contained fields with ownerId, recipientId, noteId
      final createReq = captured.firstWhere((r) => r.method == 'POST');
      final body = jsonDecode(createReq.body) as Map<String, dynamic>;
      final fields = body['fields'] as Map<String, dynamic>;
      expect(fields['ownerId']['stringValue'], equals('owner_uid'));
      expect(fields['recipientId']['stringValue'], equals('recipient_uid'));
      expect(fields['noteId']['stringValue'], equals('note1'));
    });
  });
}

// Minimal fake AuthService for tests
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
  Future<AuthUser> createUserWithEmailAndPassword(String email, String password) async => AuthUser(uid: uid, email: email);

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<AuthUser> signInWithEmailAndPassword(String email, String password) async => AuthUser(uid: uid, email: email);

  @override
  Future<void> signOut() async {}

  @override
  Future<String?> getIdToken() async => 'fake-token';
}
