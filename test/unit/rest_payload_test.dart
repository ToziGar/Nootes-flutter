import 'package:flutter_test/flutter_test.dart';
import 'package:nootes/services/firestore_service.dart';
import 'package:nootes/services/field_timestamp_helper.dart';

class _FakeFs implements FirestoreService {
  Map<String, dynamic>? lastCreateData;
  Map<String, dynamic>? lastUpdateData;

  @override
  Future<String> createNote({required String uid, required Map<String, dynamic> data}) async {
    lastCreateData = Map<String, dynamic>.from(data);
    return 'fake-id';
  }

  @override
  Future<void> updateNote({required String uid, required String noteId, required Map<String, dynamic> data}) async {
    lastUpdateData = Map<String, dynamic>.from(data);
  }

  // The rest of the API is not used by this test and can throw if called.
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('REST payload wiring', () {
    test('attachFieldTimestamps produces companion keys for createNote', () async {
      final fake = _FakeFs();
      FirestoreService.testInstance = fake;

      final data = {'title': 'Hello', 'tags': <String>['a']};
      final stamped = attachFieldTimestamps(Map<String, dynamic>.from(data));

      await FirestoreService.instance.createNote(uid: 'u', data: stamped);

      expect(fake.lastCreateData, isNotNull);
      final companion = fake.lastCreateData!['title_lastClientUpdateAt'];
      expect(companion, isNotNull);
      expect(companion, isA<String>());
    });

    test('attachFieldTimestamps produces companion keys for updateNote', () async {
      final fake = _FakeFs();
      FirestoreService.testInstance = fake;

      final data = {'content': 'Updated'};
      final stamped = attachFieldTimestamps(Map<String, dynamic>.from(data));

      await FirestoreService.instance.updateNote(uid: 'u', noteId: 'n', data: stamped);

      expect(fake.lastUpdateData, isNotNull);
      final companion = fake.lastUpdateData!['content_lastClientUpdateAt'];
      expect(companion, isNotNull);
      expect(companion, isA<String>());
    });
  });
}
