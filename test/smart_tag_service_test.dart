import 'package:flutter_test/flutter_test.dart';
import 'package:nootes/services/smart_tag_service.dart';

void main() {
  group('SmartTagService', () {
    final svc = SmartTagService();

    test('extracts hashtags', () {
      final tags = svc.suggestTags(title: '#Proyecto X', content: 'Nada');
      expect(tags, contains('proyecto'));
    });

    test('detects URLs', () {
      final tags = svc.suggestTags(
        title: 'Leer después',
        content: 'https://example.com guía',
      );
      expect(tags, contains('web'));
    });

    test('detects emails', () {
      final tags = svc.suggestTags(
        title: 'Contacto',
        content: 'Escríbeme a user@example.com',
      );
      expect(tags, contains('contact'));
    });

    test('detects dates', () {
      final tags = svc.suggestTags(
        title: 'Reunión',
        content: 'Cita 2025-10-19 a las 10:00',
      );
      expect(tags, contains('schedule'));
    });

    test('detects code', () {
      final tags = svc.suggestTags(
        title: 'Snippet',
        content: '```dart\nvoid main() {}\n```',
      );
      expect(tags, contains('code'));
    });

    test('limits to maxTags', () {
      final tags = svc.suggestTags(
        title: 'a b c d e f g h i j',
        content: 'k l m n o p q r s t',
        maxTags: 3,
      );
      expect(tags.length, lessThanOrEqualTo(3));
    });
  });
}
