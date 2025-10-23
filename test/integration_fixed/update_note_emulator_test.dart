import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nootes/services/merge_utils.dart';
import 'package:nootes/firebase_options.dart';
import 'package:nootes/test/test_utils/emulator_probe.dart';

/// Minimal integration test that runs against the Firestore emulator.
/// Skips when FIRESTORE_EMULATOR_HOST is not set.
void main() {
  final emulator = Platform.environment['FIRESTORE_EMULATOR_HOST'];

  group('Firestore emulator integration', () {
    var firebaseAvailable = true;

    setUpAll(() async {
      if (emulator == null) return;
      TestWidgetsFlutterBinding.ensureInitialized();
      try {
        final reachable = await isEmulatorReachable(emulator);
        if (!reachable) {
          firebaseAvailable = false;
          debugPrint('Emulator advertised but unreachable: $emulator');
          return;
        }

        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );

        final parts = emulator.split(':');
        final host = parts[0];
        final port = int.tryParse(parts.length > 1 ? parts[1] : '8080') ?? 8080;
        FirebaseFirestore.instance.useFirestoreEmulator(host, port);
      } catch (e) {
        firebaseAvailable = false;
        debugPrint('Firebase platform unavailable in test environment: $e');
      }
    });

    test('transactional merge via mergeNoteMaps', () async {
      if (emulator == null) {
        debugPrint(
          'Skipping emulator integration test: set FIRESTORE_EMULATOR_HOST to run',
        );
        return;
      }
      if (!firebaseAvailable) {
        debugPrint(
          'Skipping SDK-based emulator test because Firebase platform channels are unavailable in this environment.',
        );
        return;
      }

      final db = FirebaseFirestore.instance;
      final uid = 'integration_test_user';
      final noteId = 'test-note-1';
      final ref = db
          .collection('users')
          .doc(uid)
          .collection('notes')
          .doc(noteId);

      // Clean up any previous doc
      await ref.delete().catchError((_) {});

      // Create initial document
      await ref.set({
        'title': 'Initial',
        'tags': ['a', 'b'],
        'count': 1,
      });

      // Simulate a client update that should merge tags and overwrite title
      final incoming = {
        'tags': ['b', 'c'],
        'title': 'Updated',
      };

      await db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final current = snap.exists
            ? Map<String, dynamic>.from(snap.data()!)
            : <String, dynamic>{};
        final merged = mergeNoteMaps(current, incoming);
        merged['updatedAt'] = FieldValue.serverTimestamp();
        tx.set(ref, merged, SetOptions(merge: true));
      });

      final finalSnap = await ref.get();
      final data = finalSnap.data()!;
      expect(data['title'], 'Updated');
      expect(
        Set.from(data['tags'] as List).containsAll({'a', 'b', 'c'}),
        isTrue,
      );
    });
  });
}
