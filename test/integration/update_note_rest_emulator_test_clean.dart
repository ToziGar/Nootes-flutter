import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nootes/services/firestore_service.dart';

/// REST-only integration test that talks to the Firestore emulator.
///
/// This test doesn't initialize firebase_core and runs in plain Dart VM,
/// so it's suitable for environments where platform channels aren't available.
void main() {
  final emulator = Platform.environment['FIRESTORE_EMULATOR_HOST'];

  group('Firestore REST emulator integration', () {
    test('patchNoteFields injects per-field companion timestamps', () async {
      if (emulator == null) {
        print('Skipping REST emulator test: set FIRESTORE_EMULATOR_HOST to run');
        return;
      }

      final uid = 'rest_integration_user';
      final noteId = 'rest-note-1';
      final service = FirestoreService.instance; // will be _RestFirestoreService in non-plugin env

      // Clean up (best-effort)
      try {
        await service.purgeNote(uid: uid, noteId: noteId);
      } catch (_) {}

      // Create initial note using REST path
      await service.createNote(uid: uid, data: {
        'title': 'Initial REST',
        'tags': ['x', 'y'],
        'count': 1,
      });

      // Patch fields (this uses REST _patchNoteFields internally and should
      // cause the per-field companion timestamps to be created)
      await service.updateNote(uid: uid, noteId: noteId, data: {
        'title': 'Updated REST',
        'tags': ['y', 'z'],
      });

      final fetched = await service.getNote(uid: uid, noteId: noteId);
      expect(fetched, isNotNull);
      expect(fetched!['title'], 'Updated REST');

      // The REST service decodes companion timestamps into ISO strings under keys
      // like 'title_lastClientUpdateAt'. Ensure one exists and looks like a timestamp.
      final companionKey = 'title_lastClientUpdateAt';
      expect(fetched.containsKey(companionKey), isTrue);
      final companion = fetched[companionKey];
      expect(companion, isNotNull);
      expect(companion is String, isTrue);
    });
  });
}
