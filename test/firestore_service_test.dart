import 'package:flutter_test/flutter_test.dart';

// Simple scaffold test for FirestoreService.
// This file provides an example of how to write unit tests for Firestore
// methods by using a lightweight fake. It doesn't touch real Firebase.

class FakeFirestoreService {
  Future<List<Map<String, dynamic>>> listNotesSummary({required String uid}) async {
    // return a deterministic small dataset for tests
    return [
      {'id': '1', 'title': 'Nota 1', 'pinned': false},
      {'id': '2', 'title': 'Nota 2', 'pinned': true},
    ];
  }
}

void main() {
  group('FirestoreService (fake) smoke', () {
    test('listNotesSummary returns expected shape', () async {
      final svc = FakeFirestoreService();
      final notes = await svc.listNotesSummary(uid: 'user123');
      expect(notes, isA<List<Map<String, dynamic>>>());
      expect(notes.length, 2);
      expect(notes[0]['id'], '1');
      expect(notes[1]['pinned'], true);
    });
  });
}
