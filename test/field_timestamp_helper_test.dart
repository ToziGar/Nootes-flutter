import 'package:flutter_test/flutter_test.dart';
import 'package:nootes/services/field_timestamp_helper.dart';

void main() {
  test('attaches timestamps for scalar fields', () {
    final now = DateTime.utc(2025, 10, 16, 12, 0, 0);
    final data = {'title': 'Hello', 'pinned': true, 'count': 3};
    final result = attachFieldTimestamps(data, now: now);
    expect(result['title_lastClientUpdateAt'], now.toIso8601String());
    expect(result['pinned_lastClientUpdateAt'], now.toIso8601String());
    expect(result['count_lastClientUpdateAt'], now.toIso8601String());
  });

  test('does not attach for lists or maps', () {
    final now = DateTime.utc(2025, 10, 16, 12, 0, 0);
    final data = {
      'tags': ['a', 'b'],
      'meta': {'k': 'v'},
    };
    final result = attachFieldTimestamps(data, now: now);
    expect(result.containsKey('tags_lastClientUpdateAt'), false);
    expect(result.containsKey('meta_lastClientUpdateAt'), false);
  });

  test('preserves existing companion timestamps', () {
    final now = DateTime.utc(2025, 10, 16, 12, 0, 0);
    final data = {
      'title': 'Hi',
      'title_lastClientUpdateAt': '2025-10-01T00:00:00Z',
    };
    final result = attachFieldTimestamps(data, now: now);
    expect(result['title_lastClientUpdateAt'], '2025-10-01T00:00:00Z');
  });
}
