import 'package:flutter_test/flutter_test.dart';

void main() {
  test('smoke: environment sanity', () {
    // Basic test to ensure test harness runs in CI
    expect(1 + 1, equals(2));
  });
}
