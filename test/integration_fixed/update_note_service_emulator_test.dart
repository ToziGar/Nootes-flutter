import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nootes/services/firestore_service.dart';
import 'package:nootes/firebase_options.dart';
import 'package:nootes/test/test_utils/emulator_probe.dart';

void main() {
  final emulator = Platform.environment['FIRESTORE_EMULATOR_HOST'];

  group('FirestoreService.updateNote emulator integration', () {
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

    test('updateNote uses mergeNoteMaps and merges fields', () async {
      if (emulator == null) {
        debugPrint('Skipping emulator integration test: set FIRESTORE_EMULATOR_HOST to run');
        return;
      }
      if (!firebaseAvailable) {
        debugPrint('Skipping SDK-based emulator test because Firebase platform channels are unavailable in this environment.');
        return;
      }

      final uid = 'integration_user_service';
      final noteId = 'svc-note-1';
      final service = FirestoreService.instance;

      // Clean up
      try {
        await service.deleteNote(uid: uid, noteId: noteId);
      } catch (_) {}

      // Create initial note
      await service.createNote(uid: uid, data: {
        'title': 'Initial',
        'tags': ['a', 'b'],
        'count': 1,
      });

      // Call updateNote which uses mergeNoteMaps internally
      await service.updateNote(uid: uid, noteId: noteId, data: {
        'title': 'Updated via service',
        'tags': ['b', 'c']
      });

      final fetched = await service.getNote(uid: uid, noteId: noteId);
      expect(fetched, isNotNull);
      expect(fetched!['title'], 'Updated via service');
      final tags = (fetched['tags'] as List).cast<String>();
      expect(Set.from(tags).containsAll({'a', 'b', 'c'}), isTrue);
    });
  });
}

