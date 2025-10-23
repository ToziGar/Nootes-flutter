import 'dart:async';

import 'package:nootes/domain/note.dart';
import 'package:nootes/data/note_repository.dart';
import 'package:nootes/services/firestore_service.dart';
import 'package:nootes/services/queue_storage.dart';

/// Minimal SyncService stub to ensure the file parses cleanly.
class SyncService {
  final NoteRepository localRepo;
  final FirestoreService firestore;
  final QueueStorage storage;

  SyncService({required this.localRepo, required this.firestore, required this.storage});

  Future<void> enqueue(Note note) async {}
  Future<void> loadFromStorage() async {}
  Future<List<Map<String, dynamic>>> getDeadLetter() async => [];
  Future<void> retryDeadLetter(int index) async {}
  Future<void> removeDeadLetter(int index) async {}
  void start() {}
  void stop() {}
  Future<void> processOnce() async {}
}
