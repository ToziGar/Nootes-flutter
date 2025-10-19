import 'package:flutter_test/flutter_test.dart';
import 'package:nootes/utils/performance_utils.dart';

void main() {
  group('PerformanceUtils Tests', () {
    setUp(() {
      // Clear any existing stats before each test
      PerformanceMonitor.clearStats();
    });

    group('PerformanceMonitor', () {
      test('start and end track operation duration', () {
        // Arrange
        const operationName = 'test_operation';

        // Act
        PerformanceMonitor.start(operationName);
        // Simulate some work
        final duration = PerformanceMonitor.end(operationName);

        // Assert
        expect(duration, isA<Duration>());
        expect(duration.inMicroseconds, greaterThan(0));
      });

      test('end returns zero duration when no start time found', () {
        // Act
        final duration = PerformanceMonitor.end('nonexistent_operation');

        // Assert
        expect(duration, equals(Duration.zero));
      });

      test('monitor executes operation and returns result', () async {
        // Arrange
        const expectedResult = 'test_result';

        // Act
        final result = await PerformanceMonitor.monitor(
          'test_async_operation',
          () async {
            await Future.delayed(const Duration(milliseconds: 10));
            return expectedResult;
          },
        );

        // Assert
        expect(result, equals(expectedResult));

        final stats = PerformanceMonitor.getStats();
        expect(stats.containsKey('test_async_operation'), isTrue);
        expect(stats['test_async_operation']?['count'], equals(1));
      });

      test('monitor re-throws exceptions', () async {
        // Arrange
        final expectedException = Exception('Test exception');

        // Act & Assert
        await expectLater(
          PerformanceMonitor.monitor(
            'failing_operation',
            () async => throw expectedException,
          ),
          throwsA(equals(expectedException)),
        );

        // Verify stats were still recorded
        final stats = PerformanceMonitor.getStats();
        expect(stats.containsKey('failing_operation'), isTrue);
      });

      test('getStats returns correct statistics', () {
        // Arrange
        const operationName = 'stats_test';

        // Act - perform operation multiple times
        for (int i = 0; i < 3; i++) {
          PerformanceMonitor.start(operationName);
          PerformanceMonitor.end(operationName);
        }

        final stats = PerformanceMonitor.getStats();

        // Assert
        expect(stats.containsKey(operationName), isTrue);
        final operationStats = stats[operationName]!;
        expect(operationStats['count'], equals(3));
        expect(operationStats['avgMs'], isA<int>());
        expect(operationStats['minMs'], isA<int>());
        expect(operationStats['maxMs'], isA<int>());
        expect(operationStats['totalMs'], isA<int>());
      });

      test('clearStats removes all statistics', () {
        // Arrange
        PerformanceMonitor.start('test');
        PerformanceMonitor.end('test');

        // Act
        PerformanceMonitor.clearStats();

        // Assert
        final stats = PerformanceMonitor.getStats();
        expect(stats, isEmpty);
      });
    });

    group('BatchOperationUtils', () {
      test('executeBatch processes operations in batches', () async {
        // Arrange
        final operations = List.generate(
          25,
          (i) =>
              () async => i,
        );

        // Act
        final results = await BatchOperationUtils.executeBatch(
          operations,
          batchSize: 10,
          delayBetweenBatches: const Duration(milliseconds: 1),
        );

        // Assert
        expect(results.length, equals(25));
        expect(results, equals(List.generate(25, (i) => i)));
      });

      test('processBatch handles list of items', () async {
        // Arrange
        final items = List.generate(15, (i) => 'item_$i');

        // Act
        final results = await BatchOperationUtils.processBatch(
          items,
          (item) async => item.toUpperCase(),
          batchSize: 5,
          delayBetweenBatches: const Duration(milliseconds: 1),
        );

        // Assert
        expect(results.length, equals(15));
        expect(results.first, equals('ITEM_0'));
        expect(results.last, equals('ITEM_14'));
      });

      test('executeBatch handles empty operations list', () async {
        // Act
        final results = await BatchOperationUtils.executeBatch(
          <Future<int> Function()>[],
        );

        // Assert
        expect(results, isEmpty);
      });

      test('executeBatch propagates exceptions', () async {
        // Arrange
        final operations = [
          () async => 'success',
          () async => throw Exception('test error'),
        ];

        // Act & Assert
        await expectLater(
          BatchOperationUtils.executeBatch(operations),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('FirestoreQueryOptimizer', () {
      test('executeChunkedQuery splits values correctly', () async {
        // Arrange
        final values = List.generate(25, (i) => 'value_$i');
        final processedChunks = <List<String>>[];

        // Act
        final results = await FirestoreQueryOptimizer.executeChunkedQuery(
          values,
          (chunk) async {
            processedChunks.add(chunk);
            return chunk.map((v) => v.toUpperCase()).toList();
          },
          chunkSize: 10,
        );

        // Assert
        expect(results.length, equals(25));
        expect(processedChunks.length, equals(3)); // 10, 10, 5
        expect(processedChunks[0].length, equals(10));
        expect(processedChunks[1].length, equals(10));
        expect(processedChunks[2].length, equals(5));
      });

      test('executeChunkedQuery handles empty values', () async {
        // Act
        final results = await FirestoreQueryOptimizer.executeChunkedQuery(
          <String>[],
          (chunk) async => chunk,
        );

        // Assert
        expect(results, isEmpty);
      });

      test('paginatedQuery streams pages correctly', () async {
        // Arrange
        final allData = List.generate(50, (i) => MockDocument('doc_$i'));
        int currentOffset = 0;

        // Act
        final pages = <List<MockDocument>>[];
        await for (final page in FirestoreQueryOptimizer.paginatedQuery((
          limit,
          startAfter,
        ) async {
          final end = (currentOffset + limit > allData.length)
              ? allData.length
              : currentOffset + limit;
          final result = allData.sublist(currentOffset, end);
          currentOffset = end;
          return result;
        }, pageSize: 20)) {
          pages.add(page);
        }

        // Assert
        expect(pages.length, equals(3)); // 20, 20, 10
        expect(pages[0].length, equals(20));
        expect(pages[1].length, equals(20));
        expect(pages[2].length, equals(10));
      });
    });

    group('DebounceUtils', () {
      test('debounce delays execution', () async {
        // Arrange
        var executed = false;

        // Act
        DebounceUtils.debounce(
          'test_key',
          const Duration(milliseconds: 50),
          () => executed = true,
        );

        // Check immediately - should not be executed yet
        expect(executed, isFalse);

        // Wait for debounce delay
        await Future.delayed(const Duration(milliseconds: 60));

        // Assert
        expect(executed, isTrue);
      });

      test('debounce cancels previous calls', () async {
        // Arrange
        var executionCount = 0;

        // Act - call debounce multiple times quickly
        for (int i = 0; i < 5; i++) {
          DebounceUtils.debounce(
            'test_key',
            const Duration(milliseconds: 50),
            () => executionCount++,
          );
          await Future.delayed(const Duration(milliseconds: 10));
        }

        // Wait for debounce delay
        await Future.delayed(const Duration(milliseconds: 60));

        // Assert - should only execute once (the last call)
        expect(executionCount, equals(1));
      });

      test('cancelDebounce prevents execution', () async {
        // Arrange
        var executed = false;

        // Act
        DebounceUtils.debounce(
          'test_key',
          const Duration(milliseconds: 50),
          () => executed = true,
        );

        DebounceUtils.cancelDebounce('test_key');

        // Wait longer than debounce delay
        await Future.delayed(const Duration(milliseconds: 60));

        // Assert
        expect(executed, isFalse);
      });

      test('cancelAllDebounces cancels all pending operations', () async {
        // Arrange
        var executionCount = 0;

        // Act
        DebounceUtils.debounce(
          'key1',
          const Duration(milliseconds: 50),
          () => executionCount++,
        );
        DebounceUtils.debounce(
          'key2',
          const Duration(milliseconds: 50),
          () => executionCount++,
        );
        DebounceUtils.debounce(
          'key3',
          const Duration(milliseconds: 50),
          () => executionCount++,
        );

        DebounceUtils.cancelAllDebounces();

        // Wait longer than debounce delay
        await Future.delayed(const Duration(milliseconds: 60));

        // Assert
        expect(executionCount, equals(0));
      });
    });

    group('ResourceManager', () {
      test('registerResource and releaseResource work correctly', () {
        // Arrange
        final resource = MockDisposableResource();

        // Act
        ResourceManager.registerResource('test_resource', resource);
        expect(resource.disposed, isFalse);

        ResourceManager.releaseResource('test_resource');

        // Assert
        expect(resource.disposed, isTrue);
      });

      test('releaseAllResources disposes all resources', () {
        // Arrange
        final resource1 = MockDisposableResource();
        final resource2 = MockDisposableResource();

        ResourceManager.registerResource('resource1', resource1);
        ResourceManager.registerResource('resource2', resource2);

        // Act
        ResourceManager.releaseAllResources();

        // Assert
        expect(resource1.disposed, isTrue);
        expect(resource2.disposed, isTrue);
      });

      test('getResourceStats returns correct counts', () {
        // Arrange
        ResourceManager.releaseAllResources(); // Clear any existing resources

        ResourceManager.registerResource('string1', 'test');
        ResourceManager.registerResource('string2', 'test2');
        ResourceManager.registerResource('int1', 42);

        // Act
        final stats = ResourceManager.getResourceStats();

        // Assert
        expect(stats['String'], equals(2));
        expect(stats['int'], equals(1));
      });

      test('releaseResource handles non-existent resource gracefully', () {
        // Act & Assert - should not throw
        expect(
          () => ResourceManager.releaseResource('non_existent'),
          returnsNormally,
        );
      });
    });
  });
}

/// Mock class for testing paginated queries
class MockDocument {
  final String id;
  const MockDocument(this.id);
}

/// Mock class for testing resource disposal
class MockDisposableResource implements Disposable {
  bool disposed = false;

  @override
  void dispose() {
    disposed = true;
  }
}
