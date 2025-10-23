import 'package:flutter_test/flutter_test.dart';
import 'package:nootes/services/advanced_sharing_service.dart';
import 'package:nootes/test_helpers/restore_helpers.dart';
import 'package:nootes/services/firestore_service.dart';

class FakeFs implements FirestoreService {
  bool updateCalled = false;
  String? lastUid;
  String? lastNoteId;
  Map<String, dynamic>? lastData;

  // Implement only the methods used by the test
  @override
  Future<void> updateNote({required String uid, required String noteId, required Map<String, dynamic> data}) async {
    updateCalled = true;
    lastUid = uid;
    lastNoteId = noteId;
    lastData = data;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('restoreVersionData calls FirestoreService.updateNote with content', () async {
    final fake = FakeFs();
    FirestoreService.testInstance = fake;

    final now = DateTime.now();

    final version = NoteVersion(
      id: 'v1',
      noteId: 'n1',
      title: 'Restored',
      content: 'restored-content',
      authorId: 'a',
      authorName: 'A',
      createdAt: now,
      action: VersionAction.restored,
      changesSummary: 'summary',
    );

    final ok = await restoreVersionDataForUid(uid: 'test-uid', noteId: 'n1', version: version, restoredFromVersionId: 'v1');

    expect(ok, isTrue);
    expect(fake.updateCalled, isTrue);
    expect(fake.lastNoteId, 'n1');
    expect(fake.lastData?['content'], 'restored-content');
  });
}
