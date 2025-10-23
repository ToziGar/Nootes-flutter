import 'package:flutter_test/flutter_test.dart';
import 'package:nootes/domain/note.dart';
import 'package:nootes/data/note_repository.dart';
import 'package:nootes/services/sync_service.dart';
import 'package:nootes/services/queue_storage.dart';
import 'package:nootes/services/firestore_service.dart';

class _FakeFs implements FirestoreService {
  final List<Map<String, dynamic>> calls = [];

  @override
  Future<void> updateNote({required String uid, required String noteId, required Map<String, dynamic> data}) async {
    calls.add({'uid': uid, 'noteId': noteId, 'data': data});
  }

  // Unused methods below are left unimplemented for brevity in the fake.
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('SyncService processes queued note and calls FirestoreService', () async {
    final repo = InMemoryNoteRepository();
    await repo.init();

      final fs = _FakeFs();
      final inMemStorage = InMemoryQueueStorage();
      final sync = SyncService(localRepo: repo, firestore: fs, storage: inMemStorage);

    final note = Note(id: 'n1', title: 't', content: 'c');

    await sync.enqueue(note);
  // run a single processing step
  await sync.processOnce();

  expect(await repo.getNote('n1'), isNotNull);
    expect(fs.calls.length, 1);
    expect(fs.calls.first['noteId'], 'n1');
  // storage should be empty after successful process
  expect(await inMemStorage.loadQueue(), isEmpty);
  });
}
