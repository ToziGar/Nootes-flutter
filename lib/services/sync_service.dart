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
  bool _processing = false;
  final _statusController = StreamController<Map<String, int>>.broadcast();

  Stream<Map<String, int>> get statusStream => _statusController.stream;

  SyncService({required this.localRepo, required this.firestore, required this.storage, this.maxRetries = 5});

  Future<void> enqueue(Note note) async {
    final item = {
      'note': note.toMap(),
      'retries': 0,
      'nextAttempt': DateTime.now().toUtc().toIso8601String(),
    };
    // Ensure we don't duplicate entries for the same note id.
    final noteId = note.id;
    _queue.removeWhere((e) => (e['note'] as Map)['id'] == noteId);
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
    if (index < 0 || index >= _deadLetter.length) return;
    final item = Map<String, dynamic>.from(_deadLetter.removeAt(index));
    final note = Map<String, dynamic>.from(item['note'] as Map);
    final newItem = {
      'note': note,
      'retries': 0,
      'nextAttempt': DateTime.now().toUtc().toIso8601String(),
    };
    _queue.add(newItem);
    await storage.saveDeadLetter(_deadLetter);
    await storage.saveQueue(_queue);
    _emitStatus();
  }

  Future<void> removeDeadLetter(int index) async {
    if (index < 0 || index >= _deadLetter.length) return;
    _deadLetter.removeAt(index);
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
    // Prevent concurrent processing which can lead to duplicate requeues if
    // _processNext is called again before the previous run completes.
    if (_processing) return;
    _processing = true;
    try {
      if (_queue.isEmpty) return;
      // (no-op) ready to process

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
    // processing: item removed and will be attempted below
    final noteMap = Map<String, dynamic>.from(item['note'] as Map);
    final retries = (item['retries'] as int?) ?? 0;
    final note = Note.fromMap(noteMap);

    try {
      // persist local copy first
      await localRepo.saveNote(note);
      // push to remote
      await firestore.updateNote(uid: 'local', noteId: note.id, data: note.toMap());
      await storage.saveQueue(_queue);
      // processed successfully
      _emitStatus();
  } catch (_) {
      final nextRetries = retries + 1;
      if (nextRetries > maxRetries) {
        final dead = {'note': note.toMap(), 'retries': nextRetries, 'failedAt': DateTime.now().toUtc().toIso8601String()};
        _deadLetter.add(dead);
        // Persist both dead-letter and the current queue state (item removed).
        await storage.saveDeadLetter(_deadLetter);
        await storage.saveQueue(_queue);
        // moved to dead-letter
        _emitStatus();
  } else {
        // exponential backoff (cap at shift by 5)
        final backoffSeconds = (1 << (nextRetries > 5 ? 5 : nextRetries));
        final nextAttempt = DateTime.now().toUtc().add(Duration(seconds: backoffSeconds));
  final newItem = {'note': note.toMap(), 'retries': nextRetries, 'nextAttempt': nextAttempt.toIso8601String()};
  // Avoid duplicate queued entries for the same note id by removing any
  // existing entries before re-adding. This makes the queue idempotent
  // in face of overlapping operations and simplifies testing.
  final nid = note.id;
  _queue.removeWhere((e) => (e['note'] as Map)['id'] == nid);
  _queue.add(newItem);
        await storage.saveQueue(_queue);
        // requeued for next attempt
        _emitStatus();
      }
    }
    } finally {
      _processing = false;
    }
  }

  /// Return a copy of the in-memory queue for UI rendering.
  Future<List<Map<String, dynamic>>> getQueue() async => List<Map<String, dynamic>>.from(_queue.map((m) => Map<String, dynamic>.from(m)));

  /// Return a copy of the in-memory dead-letter list for UI rendering.
  Future<List<Map<String, dynamic>>> getDeadLetterInMemory() async => List<Map<String, dynamic>>.from(_deadLetter.map((m) => Map<String, dynamic>.from(m)));

  /// Clear both in-memory and persisted queue/dead-letter storage.
  Future<void> clearAllStorage() async {
    _queue.clear();
    _deadLetter.clear();
    try {
      // Prefer storage's clear helper when available. Use dynamic call and
      // fall back to saving empty lists if the helper is not present.
      try {
        await (storage as dynamic).clearStorage();
      } catch (_) {
        await storage.saveQueue([]);
        await storage.saveDeadLetter([]);
      }
    } catch (_) {}
    _emitStatus();
  }

  /// Move a queued item to the front and process it immediately.
  /// This is a convenience for the UI: it persists the new queue order and
  /// triggers a single processing attempt (ignoring schedule).
  Future<void> processItemNow(int index) async {
    if (index < 0 || index >= _queue.length) return;
    final item = _queue.removeAt(index);
    _queue.insert(0, item);
    try {
      await storage.saveQueue(_queue);
    } catch (_) {}
    await processOnce(ignoreSchedule: true);
  }

  void _emitStatus() {
    try {
      _statusController.add({'queue': _queue.length, 'dead': _deadLetter.length});
    } catch (_) {}
  }

  /// Public testing hook: process a single queued item immediately.
  Future<void> processOnce({bool ignoreSchedule = false}) async => _processNext(ignoreSchedule: ignoreSchedule);
}

