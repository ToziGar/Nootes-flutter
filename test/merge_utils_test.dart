import 'package:flutter_test/flutter_test.dart';
import 'package:nootes/services/merge_utils.dart';

void main() {
  test('merges string lists by union', () {
    final current = {'tags': ['a', 'b'], 'title': 'Old'};
    final incoming = {'tags': ['b', 'c']};
    final merged = mergeNoteMaps(current, incoming);
    expect(merged['tags'], containsAll(['a', 'b', 'c']));
    expect(merged['tags'].length, 3);
  });

  test('overwrites non-list fields', () {
    final current = {'title': 'Old', 'content': '1'};
    final incoming = {'title': 'New'};
    final merged = mergeNoteMaps(current, incoming);
    expect(merged['title'], 'New');
    expect(merged['content'], '1');
  });

  test('incoming adds new keys', () {
    final current = {'title': 'Old'};
    final incoming = {'pinned': true};
    final merged = mergeNoteMaps(current, incoming);
    expect(merged['pinned'], true);
  });

  test('handles non-string lists by overwriting', () {
    final current = {'nums': [1, 2]};
    final incoming = {'nums': [3]};
    final merged = mergeNoteMaps(current, incoming);
    // Since lists aren't string lists, incoming should overwrite
    expect(merged['nums'], [3]);
  });

  test('preserves order when merging string lists', () {
    final current = {'tags': ['a', 'b']};
    final incoming = {'tags': ['b', 'c', 'd']};
    final merged = mergeNoteMaps(current, incoming);
    // Expect order: current items first, then new incoming items in incoming order
    expect(merged['tags'], ['a', 'b', 'c', 'd']);
  });

  test('incoming null overwrites existing value', () {
    final current = {'title': 'Old', 'pinned': true};
    final incoming = {'pinned': null};
    final merged = mergeNoteMaps(current, incoming);
    expect(merged.containsKey('pinned'), true);
    expect(merged['pinned'], null);
  });

  test('LWW: incoming with newer timestamp wins', () {
    final current = {
      'title': 'Old',
      'lastClientUpdateAt': '2025-10-01T12:00:00Z'
    };
    final incoming = {
      'title': 'New',
      'lastClientUpdateAt': '2025-10-02T12:00:00Z'
    };
    final merged = mergeNoteMaps(current, incoming);
    expect(merged['title'], 'New');
  });

  test('LWW: incoming with older timestamp does not overwrite', () {
    final current = {
      'title': 'Current',
      'lastClientUpdateAt': '2025-10-03T12:00:00Z'
    };
    final incoming = {
      'title': 'Older',
      'lastClientUpdateAt': '2025-10-02T12:00:00Z'
    };
    final merged = mergeNoteMaps(current, incoming);
    expect(merged['title'], 'Current');
  });

  test('Per-field LWW: field-level newer timestamp wins', () {
    final current = {
      'title': 'CurrentTitle',
      'title_lastClientUpdateAt': '2025-10-01T10:00:00Z'
    };
    final incoming = {
      'title': 'IncomingTitle',
      'title_lastClientUpdateAt': '2025-10-02T10:00:00Z'
    };
    final merged = mergeNoteMaps(current, incoming);
    expect(merged['title'], 'IncomingTitle');
  });

  test('Per-field LWW: field-level older timestamp does not overwrite', () {
    final current = {
      'title': 'CurrentTitle',
      'title_lastClientUpdateAt': '2025-10-03T10:00:00Z'
    };
    final incoming = {
      'title': 'IncomingOlder',
      'title_lastClientUpdateAt': '2025-10-02T10:00:00Z'
    };
    final merged = mergeNoteMaps(current, incoming);
    expect(merged['title'], 'CurrentTitle');
  });
}
