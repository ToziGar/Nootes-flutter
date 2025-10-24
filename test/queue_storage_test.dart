import 'package:flutter_test/flutter_test.dart';
import 'package:nootes/services/queue_storage.dart';

void main() {
  group('InMemoryQueueStorage', () {
    test('save and load queue', () async {
      final storage = InMemoryQueueStorage();
      final items = [
        {'id': 1, 'value': 'a'},
        {'id': 2, 'value': 'b'},
      ];

      await storage.saveQueue(items);
      final loaded = await storage.loadQueue();

      expect(loaded, equals(items));
      // Ensure returned list is a copy
      expect(identical(loaded, items), isFalse);
    });

    test('save and load dead letter', () async {
      final storage = InMemoryQueueStorage();
      final items = [
        {'id': 'x', 'reason': 'err'},
      ];

      await storage.saveDeadLetter(items);
      final loaded = await storage.loadDeadLetter();

      expect(loaded, equals(items));
      expect(identical(loaded, items), isFalse);
    });

    test('mutating loaded list does not change internal stored list length', () async {
      final storage = InMemoryQueueStorage();
      final items = [
        {'id': 1},
      ];
      await storage.saveQueue(items);
      final loaded = await storage.loadQueue();
      loaded.add({'id': 2});

      final reloaded = await storage.loadQueue();
      expect(reloaded.length, equals(1));
    });
  });
}
