import 'package:flutter_test/flutter_test.dart';
import 'package:nootes/services/sync_service.dart';
import 'package:nootes/services/firestore_service.dart';
import 'package:nootes/data/note_repository.dart';
import 'package:nootes/domain/note.dart';
import 'package:nootes/services/queue_storage.dart';

class AlwaysFailFirestore implements FirestoreService {
  @override
  Future<void> updateNote({required String uid, required String noteId, required Map<String, dynamic> data}) async {
    throw Exception('always fail');
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class NeverCalledFirestore implements FirestoreService {
  bool called = false;

  @override
  Future<void> updateNote({required String uid, required String noteId, required Map<String, dynamic> data}) async {
    called = true;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('SyncService additional', () {
    test('retryDeadLetter moves item back to queue and persists', () async {
      final repo = InMemoryNoteRepository();
      final storage = InMemoryQueueStorage();
      final firestore = AlwaysFailFirestore();
      final svc = SyncService(localRepo: repo, firestore: firestore, storage: storage, maxRetries: 1);

      final note = Note(id: 'r1', title: 'retry', content: 'c');
      await svc.enqueue(note);

      // Process until it moves to dead-letter
      for (var i = 0; i < 10; i++) {
        await svc.processOnce(ignoreSchedule: true);
        final dead = await storage.loadDeadLetter();
        if (dead.isNotEmpty) break;
      }

      var dead = await storage.loadDeadLetter();
      expect(dead.length, 1);

      // Retry the dead-letter (move it back to queue)
      await svc.retryDeadLetter(0);

      dead = await storage.loadDeadLetter();
      expect(dead, isEmpty);

      final q = await storage.loadQueue();
      expect(q.length, 1);
      // The queued item should have retries reset to 0
      expect(q.first['retries'] as int, 0);
    });

    test('process respects schedule when ignoreSchedule is false', () async {
      final repo = InMemoryNoteRepository();
      final storage = InMemoryQueueStorage();
      final firestore = NeverCalledFirestore();
      final svc = SyncService(localRepo: repo, firestore: firestore, storage: storage, maxRetries: 2);

      final note = Note(id: 's1', title: 'scheduled', content: 'c');
      final futureAttempt = DateTime.now().toUtc().add(const Duration(minutes: 10));
      final item = {
        'note': note.toMap(),
        'retries': 0,
        'nextAttempt': futureAttempt.toIso8601String(),
      };

      // Persist a queue item that is scheduled in the future
      await storage.saveQueue([item]);

      // Load into service and try to process without ignoring the schedule
      await svc.loadFromStorage();
      await svc.processOnce(ignoreSchedule: false);

      // The item should remain in the queue and firestore should not be called
      final q = await storage.loadQueue();
      expect(q.length, 1);
      expect(firestore.called, false);
    });
  });
}
