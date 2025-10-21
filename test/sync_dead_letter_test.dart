import 'package:flutter_test/flutter_test.dart';
import 'package:nootes/domain/note.dart';
import 'package:nootes/data/note_repository.dart';
import 'package:nootes/services/sync_service.dart';
import 'package:nootes/services/queue_storage.dart';
import 'package:nootes/services/firestore_service.dart';

class _AlwaysFailFs implements FirestoreService {
  @override
  Future<void> updateNote({required String uid, required String noteId, required Map<String, dynamic> data}) async {
    throw Exception('simulated failure');
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('Item moves to dead-letter after exceeding maxRetries', () async {
    final repo = InMemoryNoteRepository();
    await repo.init();

    final fs = _AlwaysFailFs();
    final storage = InMemoryQueueStorage();
    final sync = SyncService(localRepo: repo, firestore: fs, storage: storage, maxRetries: 3);

    final note = Note(id: 'n2', title: 'fail', content: 'x');
    await sync.enqueue(note);

    // Process enough times to exceed retries
    for (var i = 0; i < 5; i++) {
      await sync.processOnce(ignoreSchedule: true);
    }

    final dead = await storage.loadDeadLetter();
    expect(dead, isNotEmpty);
    expect(dead.first['note']['id'], 'n2');
  });
}
