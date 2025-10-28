import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nootes/services/providers.dart';
import 'package:nootes/services/firestore_dev.dart';
import 'package:nootes/services/queue_storage.dart';
import 'package:nootes/domain/note.dart';

/// Fake Firestore that fails the first [failCount] calls, then succeeds.
class FlakyFirestore extends DevFirestoreService {
  final int failCount;
  int _calls = 0;

  FlakyFirestore(this.failCount);

  @override
  Future<void> updateNote({required String uid, required String noteId, required Map<String, dynamic> data}) async {
    _calls++;
    if (_calls <= failCount) {
      throw Exception('simulated transient failure');
    }
    // succeed by delegating to DevFirestoreService's in-memory store
    await super.updateNote(uid: uid, noteId: noteId, data: data);
  }
}

/// Always failing Firestore to force dead-lettering.
class AlwaysFailFirestore extends DevFirestoreService {
  @override
  Future<void> updateNote({required String uid, required String noteId, required Map<String, dynamic> data}) async {
    throw Exception('permanent failure');
  }
}

void main() {
  test('SyncService retries transient failures and eventually succeeds', () async {
    final flaky = FlakyFirestore(2); // fail twice, then succeed
    final storage = InMemoryQueueStorage();
    final container = ProviderContainer(overrides: [
      firestoreServiceProvider.overrideWithValue(flaky),
      queueStorageProvider.overrideWithValue(storage),
    ]);
    addTearDown(container.dispose);

    final sync = container.read(syncServiceProvider) as dynamic;

  // ensure the background worker is stopped so we control processing timing
  sync.stop();
  // shorten intervals by calling processOnce manually
    final note = Note(id: 'n1', title: 't', content: 'c');
    await sync.enqueue(note);

    // First attempt -> fail
    await sync.processOnce(ignoreSchedule: true);
    // queue should not be empty
    var q = await sync.getQueue();
    expect(q.length, equals(1));

    // Second attempt -> fail
    await sync.processOnce(ignoreSchedule: true);
    q = await sync.getQueue();
    expect(q.length, equals(1));

    // Third attempt -> succeed (flaky configured to succeed now)
    await sync.processOnce(ignoreSchedule: true);
    q = await sync.getQueue();
    expect(q.length, equals(0));

    // Check remote store has the note
    final remote = flaky.store['local']?['n1'];
    expect(remote, isNotNull);
  });

  test('SyncService moves permanently failing items to dead-letter', () async {
    final failing = AlwaysFailFirestore();
    final storage = InMemoryQueueStorage();
    final container = ProviderContainer(overrides: [
      firestoreServiceProvider.overrideWithValue(failing),
      queueStorageProvider.overrideWithValue(storage),
    ]);
    addTearDown(container.dispose);

    final sync = container.read(syncServiceProvider) as dynamic;
    final note = Note(id: 'n2', title: 't2', content: 'c2');
    await sync.enqueue(note);

    // Stop background worker and attempt processing more times than maxRetries
    // (default 5). Call processOnce repeatedly to simulate worker ticks.
    sync.stop();
    for (var i = 0; i < 7; i++) {
      await sync.processOnce(ignoreSchedule: true);
    }

    final q = await sync.getQueue();
    final dead = await sync.getDeadLetterInMemory();
    expect(q.length, equals(0));
    expect(dead.length, greaterThanOrEqualTo(1));
  });
}
