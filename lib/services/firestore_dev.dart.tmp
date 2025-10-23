import 'package:nootes/services/firestore_service.dart';

/// Simple in-memory dev FirestoreService used for demos.
class DevFirestoreService implements FirestoreService {
  final Map<String, Map<String, Map<String, dynamic>>> _store = {};

  /// Read-only view of the in-memory store for tests and demos.
  Map<String, Map<String, Map<String, dynamic>>> get store => _store;

  @override
  Future<void> updateNote({required String uid, required String noteId, required Map<String, dynamic> data}) async {
    final user = _store.putIfAbsent(uid, () => {});
    user[noteId] = data;
    // simulate small network delay
    await Future.delayed(const Duration(milliseconds: 50));
  }

  // Provide a permissive noSuchMethod to avoid implementing the entire
  // FirestoreService surface in this lightweight dev implementation.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
