import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:nootes/services/queue_storage.dart';
import 'package:nootes/services/sync_service.dart';
import 'package:nootes/data/note_repository.dart';
import 'package:nootes/services/firestore_service.dart';

final queueStorageProvider = Provider<QueueStorage>((ref) {
  // Use secure storage on native platforms, fall back to in-memory on web.
  if (kIsWeb) return InMemoryQueueStorage();
  return SecureQueueStorage();
});

final noteRepositoryProvider = Provider<NoteRepository>((ref) => InMemoryNoteRepository());

final firestoreServiceProvider = Provider<FirestoreService>((ref) => throw UnimplementedError('Provide a FirestoreService in app setup'));

final syncServiceProvider = Provider<SyncService>((ref) {
  final storage = ref.watch(queueStorageProvider);
  final repo = ref.watch(noteRepositoryProvider);
  final fs = ref.watch(firestoreServiceProvider);
  final sync = SyncService(localRepo: repo, firestore: fs, storage: storage);

  // Initialize persisted queue and start the worker in a microtask so provider
  // construction stays synchronous. Errors are caught and printed so they
  // don't crash the provider initialization.
  Future.microtask(() async {
    try {
      await sync.loadFromStorage();
      sync.start();
    } catch (e, st) {
      // Use debugPrint instead of print to avoid analyzer lint and to keep
      // logs readable in debug builds without pulling in a logging package.
      debugPrint('SyncService init error: $e\n$st');
    }
  });

  // Stop the background worker when the provider is disposed (useful in tests
  // and when an app is torn down).
  ref.onDispose(() {
    sync.stop();
  });

  return sync;
});

class SyncStatus {
  final int queueLength;
  final int deadLetterCount;
  const SyncStatus(this.queueLength, this.deadLetterCount);
}

final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final sync = ref.watch(syncServiceProvider);
  return sync.statusStream.map((m) => SyncStatus(m['queue'] ?? 0, m['dead'] ?? 0));
});
