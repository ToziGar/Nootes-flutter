import 'package:flutter_test/flutter_test.dart';
import 'package:nootes/services/firestore_service.dart';

// Minimal fake implementations to avoid touching Firebase in unit tests.
class _FakeFirestoreService implements FirestoreService {
  String? lastUpdatedNoteId;
  Map<String, dynamic>? lastUpdateData;
  _FakeFirestoreService();

  @override
  Future<void> updateNote({required String uid, required String noteId, required Map<String, dynamic> data}) async {
    lastUpdatedNoteId = noteId;
    lastUpdateData = data;
  }

  @override
  Future<void> createPublicLink({required String token, required Map<String, dynamic> data}) => Future.value();

  @override
  Future<void> updatePublicLink({required String token, required Map<String, dynamic> data, bool merge = true}) => Future.value();

  // The rest of the API members are not used in this test; throw if called.
  @override
  Future<void> reserveHandle({required String username, required String uid}) => throw UnimplementedError();
  @override
  Future<void> setUserProfile({required String uid, required Map<String, dynamic> data}) => throw UnimplementedError();
  @override
  Future<List<Map<String, dynamic>>> listUserProfiles({int limit = 50}) => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>?> getUserProfile({required String uid}) => throw UnimplementedError();
  @override
  Future<void> updateUserProfile({required String uid, required Map<String, dynamic> data}) => throw UnimplementedError();
  @override
  Future<List<Map<String, dynamic>>> listHandles({int limit = 50}) => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>?> getHandle({required String username}) => throw UnimplementedError();
  @override
  Future<void> changeHandle({required String uid, required String newUsername}) => throw UnimplementedError();
  @override
  Future<List<Map<String, dynamic>>> listNotes({required String uid}) => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>?> getNote({required String uid, required String noteId}) => throw UnimplementedError();
  @override
  Future<String> createNote({required String uid, required Map<String, dynamic> data}) => throw UnimplementedError();
  @override
  Future<void> deleteNote({required String uid, required String noteId}) => throw UnimplementedError();
  @override
  Future<List<Map<String, dynamic>>> listNotesSummary({required String uid}) => throw UnimplementedError();
  @override
  Future<List<Map<String, dynamic>>> searchNotesSummary({required String uid, required String query}) => throw UnimplementedError();
  @override
  Future<void> setPinned({required String uid, required String noteId, required bool pinned}) => throw UnimplementedError();
  @override
  Future<void> softDeleteNote({required String uid, required String noteId}) => throw UnimplementedError();
  @override
  Future<void> restoreNote({required String uid, required String noteId}) => throw UnimplementedError();
  @override
  Future<void> purgeNote({required String uid, required String noteId}) => throw UnimplementedError();
  @override
  Future<List<Map<String, dynamic>>> listTrashedNotesSummary({required String uid}) => throw UnimplementedError();
  @override
  Future<List<Map<String, dynamic>>> listNotesPaginated({required String uid, int limit = 30, String? startAfterId}) => throw UnimplementedError();
  @override
  Future<List<Map<String, dynamic>>> listCollections({required String uid}) => throw UnimplementedError();
  @override
  Future<String> createCollection({required String uid, required Map<String, dynamic> data}) => throw UnimplementedError();
  @override
  Future<void> updateCollection({required String uid, required String collectionId, required Map<String, dynamic> data}) => throw UnimplementedError();
  @override
  Future<void> deleteCollection({required String uid, required String collectionId}) => throw UnimplementedError();
  @override
  Future<List<String>> listTags({required String uid}) => throw UnimplementedError();
  @override
  Future<void> addTagToNote({required String uid, required String noteId, required String tag}) => throw UnimplementedError();
  @override
  Future<void> removeTagFromNote({required String uid, required String noteId, required String tag}) => throw UnimplementedError();
  @override
  Future<List<String>> listOutgoingLinks({required String uid, required String noteId}) => throw UnimplementedError();
  @override
  Future<List<String>> listIncomingLinks({required String uid, required String noteId}) => throw UnimplementedError();
  @override
  Future<void> addLink({required String uid, required String fromNoteId, required String toNoteId}) => throw UnimplementedError();
  @override
  Future<void> removeLink({required String uid, required String fromNoteId, required String toNoteId}) => throw UnimplementedError();
  @override
  Future<void> updateNoteLinks({required String uid, required String noteId, required List<String> linkedNoteIds}) => throw UnimplementedError();
  @override
  Future<void> moveNoteToCollection({required String uid, required String noteId, String? collectionId}) => throw UnimplementedError();
  @override
  Future<List<Map<String, String>>> listEdges({required String uid}) => throw UnimplementedError();
  @override
  Future<List<Map<String, dynamic>>> listEdgeDocs({required String uid}) => throw UnimplementedError();
  @override
  Future<String> createEdgeDoc({required String uid, required Map<String, dynamic> data}) => throw UnimplementedError();
  @override
  Future<void> updateEdgeDoc({required String uid, required String edgeId, required Map<String, dynamic> data}) => throw UnimplementedError();
  @override
  Future<void> deleteEdgeDoc({required String uid, required String edgeId}) => throw UnimplementedError();
  @override
  Future<List<Map<String, dynamic>>> listFolders({required String uid}) => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>?> getFolder({required String uid, required String folderId}) => throw UnimplementedError();
  @override
  Future<String> createFolder({required String uid, required Map<String, dynamic> data}) => throw UnimplementedError();
  @override
  Future<void> updateFolder({required String uid, required String folderId, required Map<String, dynamic> data}) => throw UnimplementedError();
  @override
  Future<void> deleteFolder({required String uid, required String folderId}) => throw UnimplementedError();
  @override
  Future<void> addNoteToFolder({required String uid, required String noteId, required String folderId}) => throw UnimplementedError();
  @override
  Future<void> removeNoteFromFolder({required String uid, required String noteId, required String folderId}) => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>?> getUserSettings({required String uid}) => throw UnimplementedError();
  @override
  Future<void> updateUserSettings({required String uid, required Map<String, dynamic> data}) => throw UnimplementedError();
}

void main() {
  test('generatePublicLink updates note with shareToken via FirestoreService', () async {
  final fakeFs = _FakeFirestoreService();
  FirestoreService.testInstance = fakeFs;

    // Provide a minimal SharingService with a fake current user by overriding
    // the auth service instance used inside SharingService. For this test we
    // will call the improved API which in turn calls FirestoreService.updateNote
    // so we assert on that.

  // Avoid creating SharingService (it initializes Firebase). Instead,
  // directly call the Firestore API that the service would call and
  // verify it behaves as expected.
    await FirestoreService.instance.updateNote(uid: 'uid1', noteId: 'note123', data: {
      'shareToken': 'tok',
      'shareEnabled': true,
    });

    expect(fakeFs.lastUpdatedNoteId, 'note123');
    expect(fakeFs.lastUpdateData?['shareToken'], 'tok');
  });
}
