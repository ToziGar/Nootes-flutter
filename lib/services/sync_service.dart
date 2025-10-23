import 'dart:async';

import 'package:nootes/domain/note.dart';
import 'package:nootes/data/note_repository.dart';
import 'package:nootes/services/firestore_service.dart';
import 'package:nootes/services/queue_storage.dart';

/// Simple in-memory sync queue and worker.
///
/// This service accepts local changes (notes) and attempts to push them to
/// Firestore via [FirestoreService]. It is intentionally simple: sequential
/// processing, exponential backoff on failure, and in-memory queue. Later we
/// can persist the queue to disk and add concurrency.
class SyncService {
  final NoteRepository localRepo;
  final FirestoreService firestore;

  final List<Map<String, dynamic>> _queue = [];
  final QueueStorage storage;
  final List<Map<String, dynamic>> _deadLetter = [];
  final int maxRetries;

  Timer? _workerTimer;
  bool _running = false;
  // Broadcast stream to notify listeners about queue/dead-letter state.
  final _statusController = StreamController<Map<String, int>>.broadcast();

  Stream<Map<String, int>> get statusStream => _statusController.stream;

  SyncService({required this.localRepo, required this.firestore, required this.storage, this.maxRetries = 5});

  Future<void> enqueue(Note note) async {
    final item = {
      'note': note.toMap(),
      'retries': 0,
      'nextAttempt': DateTime.now().toIso8601String(),
    };
    _queue.add(item);
    await storage.saveQueue(_queue);
    _emitStatus();
  }

  /// Load persisted queue and dead-letter into memory. Call this at startup
  /// if you want SyncService to pick up previous state.
  Future<void> loadFromStorage() async {
    final q = await storage.loadQueue();
    _queue.clear();
    _queue.addAll(q);
    final d = await storage.loadDeadLetter();
    _deadLetter.clear();
    _deadLetter.addAll(d);
    _emitStatus();
  }

  /// Return a snapshot of the dead-letter queue.
  Future<List<Map<String, dynamic>>> getDeadLetter() async {
    return await storage.loadDeadLetter();
  }

  /// Retry an item from dead-letter by moving it back to the main queue with
  /// retries reset and nextAttempt set to now.
  Future<void> retryDeadLetter(int index) async {
    final dead = await storage.loadDeadLetter();
    if (index < 0 || index >= dead.length) return;
    final item = Map<String, dynamic>.from(dead.removeAt(index));
    // reset retries and schedule immediate attempt
    final note = Map<String, dynamic>.from(item['note'] as Map);
    final newItem = {
      'note': note,
      'retries': 0,
      'nextAttempt': DateTime.now().toIso8601String(),
    };
    _queue.add(newItem);
    _deadLetter.removeAt(index);
    await storage.saveQueue(_queue);
    await storage.saveDeadLetter(_deadLetter);
    _emitStatus();
  }

  /// Remove an item from dead-letter (discard).
  Future<void> removeDeadLetter(int index) async {
    final dead = await storage.loadDeadLetter();
    if (index < 0 || index >= dead.length) return;
    dead.removeAt(index);
    _deadLetter.clear();
    _deadLetter.addAll(dead);
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

    // Find next available item whose nextAttempt <= now
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
      await localRepo.saveNote(note);
      await firestore.updateNote(uid: 'local', noteId: note.id, data: note.toMap());
      await storage.saveQueue(_queue);
      _emitStatus();
    } catch (e) {
      final nextRetries = retries + 1;
      if (nextRetries > maxRetries) {
        // move to dead-letter
        final dead = {'note': note.toMap(), 'retries': nextRetries, 'failedAt': DateTime.now().toIso8601String()};
        _deadLetter.add(dead);
        await storage.saveDeadLetter(_deadLetter);
        _emitStatus();
      } else {
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
  /// Public testing hook: process a single queued item immediately.
  Future<void> processOnce({bool ignoreSchedule = false}) async => _processNext(ignoreSchedule: ignoreSchedule);
}
