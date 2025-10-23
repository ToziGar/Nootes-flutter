import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:firebase_auth/firebase_auth.dart';

/// VersioningService manages immutable versions (snapshots) of notes.
/// Versions are stored under users/{uid}/notes/{noteId}/versions/{versionId}.
/// Each version contains title, content, createdAt, and optional metadata.
class VersioningService {
  static final VersioningService _instance = VersioningService._internal();
  static VersioningService? _testInstance;
  
  factory VersioningService() => _testInstance ?? _instance;
  VersioningService._internal();

  static set testInstance(VersioningService? instance) {
    _testInstance = instance;
  }

  final _db = fs.FirebaseFirestore.instance;

  /// Save a new version snapshot.
  Future<String> saveVersion({
    required String noteId,
    required Map<String, dynamic> snapshot,
    Map<String, dynamic>? metadata,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('not-authenticated');

    final data = <String, dynamic>{
      ...snapshot,
      if (metadata != null) 'metadata': metadata,
      'createdAt': fs.FieldValue.serverTimestamp(),
    };

    final ref = await _db
        .collection('users')
        .doc(uid)
        .collection('notes')
        .doc(noteId)
        .collection('versions')
        .add(data);
    return ref.id;
  }

  /// List versions (most recent first).
  Future<List<Map<String, dynamic>>> listVersions({
    required String noteId,
    int limit = 50,
    DateTime? startAfter,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('not-authenticated');

    var query = _db
        .collection('users')
        .doc(uid)
        .collection('notes')
        .doc(noteId)
        .collection('versions')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfter([fs.Timestamp.fromDate(startAfter)]);
    }

    final q = await query.get();
    return q.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  /// Restore a previous version by patching current note document.
  /// Returns the restored snapshot data for further use.
  Future<Map<String, dynamic>?> restoreVersion({
    required String noteId,
    required String versionId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('not-authenticated');

    final versionRef = _db
        .collection('users')
        .doc(uid)
        .collection('notes')
        .doc(noteId)
        .collection('versions')
        .doc(versionId);
    final snap = await versionRef.get();
    if (!snap.exists) return null;

    final data = Map<String, dynamic>.from(snap.data()!);
    data.remove('createdAt');
    data.remove('metadata');
    data['userId'] = uid; // Include for caller's convenience

    final noteRef = _db
        .collection('users')
        .doc(uid)
        .collection('notes')
        .doc(noteId);
    await noteRef.set({
      ...data,
      'updatedAt': fs.FieldValue.serverTimestamp(),
    }, fs.SetOptions(merge: true));

    return data;
  }
}
