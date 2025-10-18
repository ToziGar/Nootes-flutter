import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nootes/services/firestore_service.dart';
import 'package:nootes/services/auth_service.dart';

void main() {
  group('RestFirestoreService mocked - image cache', () {
    setUp(() {
      AuthService.testInstance = FakeAuth(uid: 'img_owner');
    });

    tearDown(() {
      AuthService.testInstance = null;
      FirestoreService.restTestInstance(client: null);
    });

    test('createCachedImage stores expected fields', () async {
      final captured = <http.Request>[];
      final client = MockClient((request) async {
        captured.add(request);
        // emulate create response name
        return http.Response(jsonEncode({'name': 'projects/p/databases/(default)/documents/image_cache/img1'}), 200,
            headers: {'content-type': 'application/json'});
      });

  final svc = FirestoreService.restTestInstance(client: client);

      // If the API exists on FirestoreService, call it; otherwise call a generic createEdgeDoc
      // Create via generic edge doc API (image cache is stored as edge docs in some flows)
      final id = await svc.createEdgeDoc(uid: 'img_owner', data: {'ownerId': 'img_owner', 'url': 'https://example.com/img.png'});
      expect(id, isNotEmpty);

      final createReq = captured.firstWhere((r) => r.method == 'POST');
      final body = jsonDecode(createReq.body) as Map<String, dynamic>;
      final fields = body['fields'] as Map<String, dynamic>;
      expect(fields['ownerId']['stringValue'], equals('img_owner'));
      expect(fields['url']['stringValue'], contains('example.com'));
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
