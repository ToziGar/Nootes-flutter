import 'package:flutter_test/flutter_test.dart';
import 'package:nootes/services/firestore_dev.dart';
import 'package:nootes/services/queue_storage.dart';
import 'package:nootes/services/sync_service.dart';
import 'package:nootes/data/note_repository.dart';
import 'package:nootes/domain/note.dart';

void main() {
  test('enqueue -> DevFirestoreService receives note', () async {
    // Ensure Flutter bindings are initialized so flutter test runs without
    // attempting to start an actual device.
    TestWidgetsFlutterBinding.ensureInitialized();
    final devFs = DevFirestoreService();
    final storage = InMemoryQueueStorage();
    final repo = InMemoryNoteRepository();

    final sync = SyncService(localRepo: repo, firestore: devFs, storage: storage, maxRetries: 3);

    final note = Note(id: 'test-1', title: 't', content: 'c');

    await sync.enqueue(note);

    // Process until queue is empty (deterministic via processOnce)
    for (var i = 0; i < 10; i++) {
      await sync.processOnce(ignoreSchedule: true);
    }

  // Check dev service stored or processed the note; DevFirestoreService
  // exposes the in-memory store via `store` getter.
  // SyncService writes with uid 'local'. Check under that key.
  expect(devFs.store.containsKey('local'), isTrue);
  expect(devFs.store['local']!.containsKey('test-1'), isTrue);
  final stored = devFs.store['local']!['test-1']!;
  expect(stored['title'], equals('t'));
  expect(stored['content'], equals('c'));

    sync.stop();
  });
}
