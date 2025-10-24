import 'package:flutter_test/flutter_test.dart';
import 'package:nootes/services/queue_storage.dart';

void main() {
  group('SecureQueueStorage with InMemorySecureKV', () {
    test('save and load queue', () async {
      final kv = InMemorySecureKV();
      final storage = SecureQueueStorage(secure: kv);

      final items = [
        {'id': 1, 'value': 'a'},
        {'id': 2, 'value': 'b'},
      ];

      await storage.saveQueue(items);
      final loaded = await storage.loadQueue();

      expect(loaded, equals(items));
    });

    test('save and load dead letter', () async {
      final kv = InMemorySecureKV();
      final storage = SecureQueueStorage(secure: kv);

      final items = [
        {'id': 'x', 'reason': 'err'},
      ];

      await storage.saveDeadLetter(items);
      final loaded = await storage.loadDeadLetter();

      expect(loaded, equals(items));
    });

    test('malformed json in storage returns empty list', () async {
      final kv = InMemorySecureKV();
      // pre-populate with invalid JSON
      await kv.write(key: 'sync_queue_v1', value: 'not-json');
      final storage = SecureQueueStorage(secure: kv);

      final loaded = await storage.loadQueue();
      expect(loaded, isEmpty);
    });
  });
}
