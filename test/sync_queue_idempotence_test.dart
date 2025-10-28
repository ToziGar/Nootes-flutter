import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nootes/services/providers.dart';
import 'package:nootes/services/queue_storage.dart';
import 'package:nootes/services/firestore_dev.dart';
import 'package:nootes/domain/note.dart';

void main() {
  test('SyncService enqueue is idempotent for same note id', () async {
    final storage = InMemoryQueueStorage();
    final devFs = DevFirestoreService();
    final container = ProviderContainer(overrides: [
      queueStorageProvider.overrideWithValue(storage),
      firestoreServiceProvider.overrideWithValue(devFs),
    ]);
    addTearDown(container.dispose);

    final sync = container.read(syncServiceProvider) as dynamic;
    // stop background worker to make queue deterministic for the test
    sync.stop();

    final note = Note(id: 'idempotent', title: 't', content: 'c');

    // enqueue the same note multiple times
    await sync.enqueue(note);
    await sync.enqueue(note);
    await sync.enqueue(note);

    final q = await sync.getQueue();
    expect(q.length, equals(1));
    final storedId = (q.first['note'] as Map)['id'];
    expect(storedId, equals('idempotent'));
  });
}
