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
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  @override
  Future<List<Map<String, dynamic>>> loadQueue() async {
    final raw = await _secure.read(key: _key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }

  @override
  Future<void> saveQueue(List<Map<String, dynamic>> items) async {
    await _secure.write(key: _key, value: jsonEncode(items));
  }

  @override
  Future<void> saveDeadLetter(List<Map<String, dynamic>> items) async {
    await _secure.write(key: _deadKey, value: jsonEncode(items));
  }

  @override
  Future<List<Map<String, dynamic>>> loadDeadLetter() async {
    final raw = await _secure.read(key: _deadKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }
}
