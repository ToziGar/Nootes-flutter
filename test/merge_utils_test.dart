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
}
