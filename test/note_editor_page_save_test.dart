import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:nootes/notes/note_editor_page.dart';
import 'package:nootes/services/firestore_service.dart';
import 'package:nootes/services/auth_service.dart';
import 'package:nootes/services/sharing_service_improved.dart';

class FakeFirestoreService implements FirestoreService {
  bool updateCalled = false;

  // Implement only the used methods for the test; others can throw.
  @override
  Future<void> updateNote({required String uid, required String noteId, required Map<String, dynamic> data}) async {
    updateCalled = true;
  }

  @override
  Future<Map<String, dynamic>?> getNote({required String uid, required String noteId}) async {
    return {'id': noteId, 'title': 'Test', 'content': ''};
  }

  @override
  Future<List<Map<String, dynamic>>> listCollections({required String uid}) async {
    return <Map<String, dynamic>>[];
  }

  @override
  Future<List<Map<String, dynamic>>> listNotes({required String uid}) async {
    return <Map<String, dynamic>>[];
  }

  @override
  Future<List<String>> listOutgoingLinks({required String uid, required String noteId}) async {
    return <String>[];
  }

  @override
  Future<List<String>> listIncomingLinks({required String uid, required String noteId}) async {
    return <String>[];
  }

  // The rest of the API can be left unimplemented for brevity.
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthService implements AuthService {
  @override
  bool get usesRest => true;

  @override
  AuthUser? get currentUser => AuthUser(uid: 'test-uid');

  @override
  Stream<AuthUser?> authStateChanges() => Stream.value(currentUser);

  @override
  Future<void> init() async {}

  @override
  Future<String?> getIdToken() async => 'token';

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthUser> signInWithEmailAndPassword(String email, String password) async => AuthUser(uid: 'test-uid');

  @override
  Future<AuthUser> createUserWithEmailAndPassword(String email, String password) async => AuthUser(uid: 'test-uid');

  @override
  Future<void> sendPasswordResetEmail(String email) async {}
}

void main() {
  testWidgets('NoteEditorPage save calls FirestoreService.updateNote', (tester) async {
    final fakeFs = FakeFirestoreService();
    FirestoreService.testInstance = fakeFs;
    AuthService.testInstance = FakeAuthService();
      // Provide a fake SharingService to avoid Firebase access during tests.
      SharingService.testInstance = _FakeSharingService();

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(1400, 900)),
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              height: 800,
              child: NoteEditorPage(noteId: 'n1'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap save button in AppBar
    final saveButton = find.byIcon(Icons.save_rounded);
    expect(saveButton, findsOneWidget);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(fakeFs.updateCalled, isTrue);
  });
}

class _FakeSharingService implements SharingService {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
