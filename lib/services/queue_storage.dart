import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class QueueStorage {
  Future<void> saveQueue(List<Map<String, dynamic>> items);
  Future<List<Map<String, dynamic>>> loadQueue();
  Future<void> saveDeadLetter(List<Map<String, dynamic>> items);
  Future<List<Map<String, dynamic>>> loadDeadLetter();
}

/// In-memory queue storage (used on web / tests).
class InMemoryQueueStorage implements QueueStorage {
  List<Map<String, dynamic>> _data = [];
  List<Map<String, dynamic>> _dead = [];

  @override
  Future<List<Map<String, dynamic>>> loadQueue() async => List.from(_data);

  @override
  Future<void> saveQueue(List<Map<String, dynamic>> items) async {
    _data = List.from(items);
    // persisted in-memory for tests
  }

  @override
  Future<void> saveDeadLetter(List<Map<String, dynamic>> items) async {
    _dead = List.from(items);
  }

  @override
  Future<List<Map<String, dynamic>>> loadDeadLetter() async => List.from(_dead);
}

/// Secure storage wrapper for native platforms. For simplicity this uses
/// FlutterSecureStorage but it's acceptable to replace with a platform
/// specific implementation later.
class SecureQueueStorage implements QueueStorage {
  static const _key = 'sync_queue_v1';
  static const _deadKey = 'sync_dead_v1';
  // Abstraction so we can inject a fake implementation for tests.
  final SecureKeyValueStorage _secure;

  SecureQueueStorage({SecureKeyValueStorage? secure}) : _secure = secure ?? FlutterSecureKeyValueStorage();

  @override
  Future<List<Map<String, dynamic>>> loadQueue() async {
    try {
      final raw = await _secure.read(key: _key);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      // Support two formats: legacy stored as a List, or new format as {version: x, items: [...]}
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      if (decoded is Map && decoded['items'] is List) {
        return (decoded['items'] as List).cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      // If parsing fails or storage read fails, return empty queue to avoid
      // crashing the app; callers can recover or repopulate as needed.
      return [];
    }
  }

  @override
  Future<void> saveQueue(List<Map<String, dynamic>> items) async {
    try {
      // Persist with a version wrapper so future migrations are possible.
      final payload = {'version': 1, 'items': items};
      await _secure.write(key: _key, value: jsonEncode(payload));
    } catch (_) {
      // ignore write errors for now (best-effort persistence)
    }
  }

  @override
  Future<void> saveDeadLetter(List<Map<String, dynamic>> items) async {
    try {
      final payload = {'version': 1, 'items': items};
      await _secure.write(key: _deadKey, value: jsonEncode(payload));
    } catch (_) {}
  }

  @override
  Future<List<Map<String, dynamic>>> loadDeadLetter() async {
    try {
      final raw = await _secure.read(key: _deadKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.cast<Map<String, dynamic>>();
      if (decoded is Map && decoded['items'] is List) {
        return (decoded['items'] as List).cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Clear both queue and dead-letter storage (used when migration fails or
  /// user chooses to reset stored queue state).
  Future<void> clearStorage() async {
    try {
      await _secure.write(key: _key, value: jsonEncode({'version': 1, 'items': []}));
      await _secure.write(key: _deadKey, value: jsonEncode({'version': 1, 'items': []}));
    } catch (_) {}
  }
}

/// Minimal internal abstraction used by `SecureQueueStorage` so we can inject a
/// fake implementation in tests.
/// Abstraction used by `SecureQueueStorage` so we can inject a fake
/// implementation in tests.
abstract class SecureKeyValueStorage {
  Future<void> write({required String key, required String value});
  Future<String?> read({required String key});
}

/// Adapter that forwards calls to `flutter_secure_storage`.
class FlutterSecureKeyValueStorage implements SecureKeyValueStorage {
  final FlutterSecureStorage _impl;
  FlutterSecureKeyValueStorage([this._impl = const FlutterSecureStorage()]);

  @override
  Future<void> write({required String key, required String value}) => _impl.write(key: key, value: value);

  @override
  Future<String?> read({required String key}) => _impl.read(key: key);
}

/// In-memory fake for tests.
class InMemorySecureKV implements SecureKeyValueStorage {
  final Map<String, String> _store = {};

  InMemorySecureKV();

  @override
  Future<void> write({required String key, required String value}) async {
    _store[key] = value;
  }

  @override
  Future<String?> read({required String key}) async => _store[key];
}
