import 'package:nootes/services/firestore_service.dart';

/// Simple in-memory dev FirestoreService used for demos.
class DevFirestoreService implements FirestoreService {
  final Map<String, Map<String, Map<String, dynamic>>> _store = {};

  @override
  Future<void> updateNote({required String uid, required String noteId, required Map<String, dynamic> data}) async {
    final user = _store.putIfAbsent(uid, () => {});
    user[noteId] = data;
    // simulate small network delay
    await Future.delayed(const Duration(milliseconds: 50));
  }

  // Use noSuchMethod to satisfy the large abstract interface in a lightweight way.
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
