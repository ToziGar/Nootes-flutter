import 'dart:async';

import 'package:nootes/domain/note.dart';
import 'package:nootes/data/note_repository.dart';
import 'package:nootes/services/firestore_service.dart';
import 'package:nootes/services/queue_storage.dart';

/// Simple in-memory sync queue and worker used for demo/testing.
///
/// Accepts local changes (notes) and attempts to push them to Firestore via
/// [FirestoreService]. Behavior: sequential processing, exponential backoff on
/// failure, and optional persistence via [QueueStorage].
class SyncService {
  final NoteRepository localRepo;
  final FirestoreService firestore;
  final QueueStorage storage;
  final int maxRetries;

  final List<Map<String, dynamic>> _queue = [];
  final List<Map<String, dynamic>> _deadLetter = [];

  Timer? _workerTimer;
  bool _running = false;
  final _statusController = StreamController<Map<String, int>>.broadcast();

  Stream<Map<String, int>> get statusStream => _statusController.stream;

  SyncService({required this.localRepo, required this.firestore, required this.storage, this.maxRetries = 5});

  Future<void> enqueue(Note note) async {
    final item = {
      'note': note.toMap(),
      'retries': 0,
      'nextAttempt': DateTime.now().toUtc().toIso8601String(),
    };
    _queue.add(item);
    await storage.saveQueue(_queue);
    _emitStatus();
  }

  Future<void> loadFromStorage() async {
    final q = await storage.loadQueue();
    _queue
      ..clear()
      ..addAll(q);
    final d = await storage.loadDeadLetter();
    _deadLetter
      ..clear()
      ..addAll(d);
    _emitStatus();
  }

  Future<List<Map<String, dynamic>>> getDeadLetter() async => await storage.loadDeadLetter();

  Future<void> retryDeadLetter(int index) async {
    final dead = await storage.loadDeadLetter();
    if (index < 0 || index >= dead.length) return;
    final item = Map<String, dynamic>.from(dead.removeAt(index));
    final note = Map<String, dynamic>.from(item['note'] as Map);
    final newItem = {
      'note': note,
      'retries': 0,
      'nextAttempt': DateTime.now().toUtc().toIso8601String(),
    };
    _queue.add(newItem);
    _deadLetter.removeAt(index);
    await storage.saveQueue(_queue);
    await storage.saveDeadLetter(_deadLetter);
    _emitStatus();
  }

  Future<void> removeDeadLetter(int index) async {
    final dead = await storage.loadDeadLetter();
    if (index < 0 || index >= dead.length) return;
    dead.removeAt(index);
    _deadLetter
      ..clear()
      ..addAll(dead);
    await storage.saveDeadLetter(_deadLetter);
    _emitStatus();
  }

  void start({Duration interval = const Duration(seconds: 2)}) {
    if (_running) return;
    _running = true;
    _workerTimer = Timer.periodic(interval, (_) => _processNext());
  }

  void stop() {
    _workerTimer?.cancel();
    _workerTimer = null;
    _running = false;
  }

  Future<void> _processNext({bool ignoreSchedule = false}) async {
    if (_queue.isEmpty) return;

    final now = DateTime.now().toUtc();
    int index = -1;
    if (ignoreSchedule) {
      index = 0;
    } else {
      for (var i = 0; i < _queue.length; i++) {
        final item = _queue[i];
        final next = DateTime.parse(item['nextAttempt'] as String).toUtc();
        if (!next.isAfter(now)) {
          index = i;
          break;
        }
      }
    }
    if (index == -1) return;

    final item = _queue.removeAt(index);
    final noteMap = Map<String, dynamic>.from(item['note'] as Map);
    final retries = (item['retries'] as int?) ?? 0;
    final note = Note.fromMap(noteMap);

    try {
      // persist local copy first
      await localRepo.saveNote(note);
      // push to remote
      await firestore.updateNote(uid: 'local', noteId: note.id, data: note.toMap());
      await storage.saveQueue(_queue);
      _emitStatus();
    } catch (_) {
      final nextRetries = retries + 1;
      if (nextRetries > maxRetries) {
        final dead = {'note': note.toMap(), 'retries': nextRetries, 'failedAt': DateTime.now().toUtc().toIso8601String()};
        _deadLetter.add(dead);
        await storage.saveDeadLetter(_deadLetter);
        _emitStatus();
      } else {
        // exponential backoff (cap at shift by 5)
        final backoffSeconds = (1 << (nextRetries > 5 ? 5 : nextRetries));
        final nextAttempt = DateTime.now().toUtc().add(Duration(seconds: backoffSeconds));
        final newItem = {'note': note.toMap(), 'retries': nextRetries, 'nextAttempt': nextAttempt.toIso8601String()};
        _queue.add(newItem);
        await storage.saveQueue(_queue);
        _emitStatus();
      }
    }
  }

  void _emitStatus() {
    try {
      _statusController.add({'queue': _queue.length, 'dead': _deadLetter.length});
    } catch (_) {}
  }

  /// Public testing hook: process a single queued item immediately.
  Future<void> processOnce({bool ignoreSchedule = false}) async => _processNext(ignoreSchedule: ignoreSchedule);
}

