import 'package:flutter_test/flutter_test.dart';
import 'package:nootes/services/sync_service.dart';
import 'package:nootes/services/firestore_service.dart';
import 'package:nootes/data/note_repository.dart';
import 'package:nootes/domain/note.dart';
import 'package:nootes/services/queue_storage.dart';

class FakeFirestoreService implements FirestoreService {
  final Map<String, int> _failures = {};
  final int failCount; // number of times to fail per note

  FakeFirestoreService({this.failCount = 0});

  void _maybeFail(String noteId) {
    final current = _failures[noteId] ?? 0;
    if (current < failCount) {
      _failures[noteId] = current + 1;
      throw Exception('simulated failure');
    }
  }

  @override
  Future<void> updateNote({required String uid, required String noteId, required Map<String, dynamic> data}) async {
    _maybeFail(noteId);
    return;
  }

  // The rest of methods are not used in the tests; provide basic stubs.
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('SyncService', () {
    test('moves failing items to dead-letter after exceeding retries', () async {
      final repo = InMemoryNoteRepository();
      final storage = InMemoryQueueStorage();
      final firestore = FakeFirestoreService(failCount: 10); // always fail
      final svc = SyncService(localRepo: repo, firestore: firestore, storage: storage, maxRetries: 2);

      final note = Note(id: 'n1', title: 't', content: 'c');
      await svc.enqueue(note);

      // Process until dead-letter should contain the item (give enough iterations)
      for (var i = 0; i < 20; i++) {
        await svc.processOnce(ignoreSchedule: true);
        final deadNow = await svc.getDeadLetter();
        if (deadNow.isNotEmpty) break;
      }

      final dead = await svc.getDeadLetter();
      expect(dead.length, 1);
      final q = await storage.loadQueue();
      expect(q, isEmpty);
    });

    test('succeeds after a transient failure', () async {
      final repo = InMemoryNoteRepository();
      final storage = InMemoryQueueStorage();
      final firestore = FakeFirestoreService(failCount: 1); // fail once then succeed
      final svc = SyncService(localRepo: repo, firestore: firestore, storage: storage, maxRetries: 3);

      final note = Note(id: 'n2', title: 't2', content: 'c2');
      await svc.enqueue(note);

      // First attempt will fail, second should succeed
      await svc.processOnce(ignoreSchedule: true);
      await svc.processOnce(ignoreSchedule: true);

      final dead = await storage.loadDeadLetter();
      expect(dead, isEmpty);

      // Ensure note was saved locally by the service
      final saved = await repo.getNote('n2');
      expect(saved, isNotNull);
      expect(saved!.title, 't2');
    });
  });
}
