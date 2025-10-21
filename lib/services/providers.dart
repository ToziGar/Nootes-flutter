import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nootes/services/queue_storage.dart';
import 'package:nootes/services/sync_service.dart';
import 'package:nootes/data/note_repository.dart';
import 'package:nootes/services/firestore_service.dart';

final queueStorageProvider = Provider<QueueStorage>((ref) => InMemoryQueueStorage());

final noteRepositoryProvider = Provider<NoteRepository>((ref) => InMemoryNoteRepository());

final firestoreServiceProvider = Provider<FirestoreService>((ref) => throw UnimplementedError('Provide a FirestoreService in app setup'));

final syncServiceProvider = Provider<SyncService>((ref) {
  final storage = ref.watch(queueStorageProvider);
  final repo = ref.watch(noteRepositoryProvider);
  final fs = ref.watch(firestoreServiceProvider);
  return SyncService(localRepo: repo, firestore: fs, storage: storage);
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
