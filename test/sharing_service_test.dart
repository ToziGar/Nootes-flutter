import 'package:flutter_test/flutter_test.dart';

// Test for SharingService public token resolution.
// This provides basic validation for resolvePublicToken logic
// by using a fake implementation that simulates the Firestore behavior.

class FakeSharingService {
  // Simulate the public_links collection with predefined test data
  final Map<String, Map<String, dynamic>> _publicLinks = {
    'valid_token_123': {
      'enabled': true,
      'ownerId': 'user123',
      'noteId': 'note456',
    },
    'disabled_token_456': {
      'enabled': false,
      'ownerId': 'user789',
      'noteId': 'note012',
    },
    'incomplete_token_789': {
      'enabled': true,
      'ownerId': '', // Empty ownerId should make this invalid
      'noteId': 'note345',
    },
    'missing_fields_token': {
      'enabled': true,
      // Missing ownerId and noteId fields
    },
  };

  /// Simulates the resolvePublicToken method behavior
  Future<Map<String, String>?> resolvePublicToken(String token) async {
    // Simulate document lookup
    final data = _publicLinks[token];
    if (data == null) return null; // Document doesn't exist

    if (data['enabled'] != true) return null; // Not enabled

    final ownerId = data['ownerId']?.toString() ?? '';
    final noteId = data['noteId']?.toString() ?? '';

    if (ownerId.isEmpty || noteId.isEmpty) return null; // Invalid data

    return {'ownerId': ownerId, 'noteId': noteId, 'token': token};
  }
}

void main() {
  group('SharingService resolvePublicToken', () {
    late FakeSharingService service;

    setUp(() {
      service = FakeSharingService();
    });

    test('returns correct data for valid enabled token', () async {
      final result = await service.resolvePublicToken('valid_token_123');

      expect(result, isNotNull);
      expect(result!['ownerId'], 'user123');
      expect(result['noteId'], 'note456');
      expect(result['token'], 'valid_token_123');
    });

    test('returns null for non-existent token', () async {
      final result = await service.resolvePublicToken('nonexistent_token');

      expect(result, isNull);
    });

    test('returns null for disabled token', () async {
      final result = await service.resolvePublicToken('disabled_token_456');

      expect(result, isNull);
    });

    test('returns null for token with empty ownerId', () async {
      final result = await service.resolvePublicToken('incomplete_token_789');

      expect(result, isNull);
    });

    test('returns null for token with missing fields', () async {
      final result = await service.resolvePublicToken('missing_fields_token');

      expect(result, isNull);
    });

    test('handles multiple valid resolutions', () async {
      // Add another valid token to test consistency
      service._publicLinks['another_valid_token'] = {
        'enabled': true,
        'ownerId': 'user999',
        'noteId': 'note888',
      };

      final result1 = await service.resolvePublicToken('valid_token_123');
      final result2 = await service.resolvePublicToken('another_valid_token');

      expect(result1!['ownerId'], 'user123');
      expect(result2!['ownerId'], 'user999');
    });

    test('validates return structure for valid tokens', () async {
      final result = await service.resolvePublicToken('valid_token_123');

      expect(result, isA<Map<String, String>>());
      expect(result!.keys, containsAll(['ownerId', 'noteId', 'token']));
      expect(result.keys, hasLength(3));
    });
  });
}
