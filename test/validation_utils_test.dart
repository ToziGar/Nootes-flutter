import 'package:flutter_test/flutter_test.dart';
import 'package:nootes/utils/validation_utils.dart';
import 'package:nootes/services/exceptions/sharing_exceptions.dart';

void main() {
  group('ValidationUtils Tests', () {
    group('validateEmail', () {
      test('returns trimmed lowercase email for valid email', () {
        // Arrange
        const input = '  Test@Example.COM  ';
        
        // Act
        final result = ValidationUtils.validateEmail(input);
        
        // Assert
        expect(result, equals('test@example.com'));
      });

      test('throws ValidationException for empty email', () {
        // Act & Assert
        expect(() => ValidationUtils.validateEmail(''),
               throwsA(isA<ValidationException>()));
        expect(() => ValidationUtils.validateEmail('   '),
               throwsA(isA<ValidationException>()));
      });

      test('throws ValidationException for invalid email format', () {
        // Arrange
        const invalidEmails = [
          'invalid-email',
          '@example.com',
          'test@',
          'test..test@example.com',
          'test@.com',
          'test@example.',
        ];

        // Act & Assert
        for (final email in invalidEmails) {
          expect(() => ValidationUtils.validateEmail(email),
                 throwsA(isA<ValidationException>()),
                 reason: 'Email "$email" should be invalid');
        }
      });

      test('accepts valid email formats', () {
        // Arrange
        const validEmails = [
          'test@example.com',
          'user.name@domain.co.uk',
          'user+tag@example.org',
          'user123@test-domain.com',
          'a@b.co',
        ];

        // Act & Assert
        for (final email in validEmails) {
          expect(() => ValidationUtils.validateEmail(email),
                 returnsNormally,
                 reason: 'Email "$email" should be valid');
        }
      });
    });

    group('validateUsername', () {
      test('returns trimmed lowercase username without @', () {
        // Arrange
        const input = '  @TestUser123  ';
        
        // Act
        final result = ValidationUtils.validateUsername(input);
        
        // Assert
        expect(result, equals('testuser123'));
      });

      test('throws ValidationException for empty username', () {
        // Act & Assert
        expect(() => ValidationUtils.validateUsername(''),
               throwsA(isA<ValidationException>()));
        expect(() => ValidationUtils.validateUsername('   '),
               throwsA(isA<ValidationException>()));
      });

      test('throws ValidationException for username too short', () {
        // Act & Assert
        expect(() => ValidationUtils.validateUsername('ab'),
               throwsA(isA<ValidationException>()));
      });

      test('throws ValidationException for username too long', () {
        // Arrange
        final longUsername = 'a' * 31;
        
        // Act & Assert
        expect(() => ValidationUtils.validateUsername(longUsername),
               throwsA(isA<ValidationException>()));
      });

      test('throws ValidationException for invalid characters', () {
        // Arrange
        const invalidUsernames = [
          'user@domain',
          'user space',
          'user#tag',
          'user%percent',
          'user!exclaim',
        ];

        // Act & Assert
        for (final username in invalidUsernames) {
          expect(() => ValidationUtils.validateUsername(username),
                 throwsA(isA<ValidationException>()),
                 reason: 'Username "$username" should be invalid');
        }
      });

      test('accepts valid username formats', () {
        // Arrange
        const validUsernames = [
          'user123',
          'test_user',
          'user-name',
          'user.name',
          'TestUser',
        ];

        // Act & Assert
        for (final username in validUsernames) {
          expect(() => ValidationUtils.validateUsername(username),
                 returnsNormally,
                 reason: 'Username "$username" should be valid');
        }
      });
    });

    group('validateId', () {
      test('returns trimmed ID for valid input', () {
        // Arrange
        const input = '  test_id_123  ';
        
        // Act
        final result = ValidationUtils.validateId(input, 'testField');
        
        // Assert
        expect(result, equals('test_id_123'));
      });

      test('throws ValidationException for empty ID', () {
        // Act & Assert
        expect(() => ValidationUtils.validateId('', 'testField'),
               throwsA(isA<ValidationException>()));
        expect(() => ValidationUtils.validateId('   ', 'testField'),
               throwsA(isA<ValidationException>()));
      });
    });

    group('validateMessage', () {
      test('returns null for null or empty message', () {
        // Act & Assert
        expect(ValidationUtils.validateMessage(null), isNull);
        expect(ValidationUtils.validateMessage(''), isNull);
        expect(ValidationUtils.validateMessage('   '), isNull);
      });

      test('returns trimmed message for valid input', () {
        // Arrange
        const input = '  This is a test message  ';
        
        // Act
        final result = ValidationUtils.validateMessage(input);
        
        // Assert
        expect(result, equals('This is a test message'));
      });

      test('throws ValidationException for message too long', () {
        // Arrange
        final longMessage = 'a' * 501;
        
        // Act & Assert
        expect(() => ValidationUtils.validateMessage(longMessage),
               throwsA(isA<ValidationException>()));
      });

      test('accepts message at maximum length', () {
        // Arrange
        final maxMessage = 'a' * 500;
        
        // Act & Assert
        expect(() => ValidationUtils.validateMessage(maxMessage),
               returnsNormally);
      });
    });

    group('validateExpirationDate', () {
      test('returns null for null expiration date', () {
        // Act
        final result = ValidationUtils.validateExpirationDate(null);
        
        // Assert
        expect(result, isNull);
      });

      test('returns date for valid future date', () {
        // Arrange
        final futureDate = DateTime.now().add(const Duration(days: 30));
        
        // Act
        final result = ValidationUtils.validateExpirationDate(futureDate);
        
        // Assert
        expect(result, equals(futureDate));
      });

      test('throws ValidationException for past date', () {
        // Arrange
        final pastDate = DateTime.now().subtract(const Duration(days: 1));
        
        // Act & Assert
        expect(() => ValidationUtils.validateExpirationDate(pastDate),
               throwsA(isA<ValidationException>()));
      });

      test('throws ValidationException for date too far in future', () {
        // Arrange
        final farFutureDate = DateTime.now().add(const Duration(days: 400));
        
        // Act & Assert
        expect(() => ValidationUtils.validateExpirationDate(farFutureDate),
               throwsA(isA<ValidationException>()));
      });

      test('accepts date at maximum future limit', () {
        // Arrange
        final maxFutureDate = DateTime.now().add(const Duration(days: 365));
        
        // Act & Assert
        expect(() => ValidationUtils.validateExpirationDate(maxFutureDate),
               returnsNormally);
      });
    });

    group('sanitizeText', () {
      test('removes HTML tags', () {
        // Arrange
        const input = 'Hello <script>alert("hack")</script> World';
        
        // Act
        final result = ValidationUtils.sanitizeText(input);
        
        // Assert
        expect(result, equals('Hello alert("hack") World'));
      });

      test('removes unsafe characters', () {
        // Arrange
        const input = 'Hello & <dangerous> characters!';
        
        // Act
        final result = ValidationUtils.sanitizeText(input);
        
        // Assert
        expect(result, contains('Hello'));
        expect(result, isNot(contains('<')));
        expect(result, isNot(contains('>')));
      });

      test('preserves safe characters', () {
        // Arrange
        const input = 'user@example.com test-user_123';
        
        // Act
        final result = ValidationUtils.sanitizeText(input);
        
        // Assert
        expect(result, equals('user@example.com test-user_123'));
      });

      test('trims whitespace', () {
        // Arrange
        const input = '  sanitized text  ';
        
        // Act
        final result = ValidationUtils.sanitizeText(input);
        
        // Assert
        expect(result, equals('sanitized text'));
      });
    });

    group('validateUserIdentifier', () {
      test('validates as email when contains @', () {
        // Arrange
        const input = 'test@example.com';
        
        // Act
        final result = ValidationUtils.validateUserIdentifier(input);
        
        // Assert
        expect(result, equals('test@example.com'));
      });

      test('validates as username when no @', () {
        // Arrange
        const input = 'testuser';
        
        // Act
        final result = ValidationUtils.validateUserIdentifier(input);
        
        // Assert
        expect(result, equals('testuser'));
      });

      test('throws ValidationException for empty identifier', () {
        // Act & Assert
        expect(() => ValidationUtils.validateUserIdentifier(''),
               throwsA(isA<ValidationException>()));
      });
    });

    group('validateSharingLimits', () {
      test('does not throw when under limit', () {
        // Act & Assert
        expect(() => ValidationUtils.validateSharingLimits(5, 10),
               returnsNormally);
      });

      test('throws ValidationException when at limit', () {
        // Act & Assert
        expect(() => ValidationUtils.validateSharingLimits(10, 10),
               throwsA(isA<ValidationException>()));
      });

      test('throws ValidationException when over limit', () {
        // Act & Assert
        expect(() => ValidationUtils.validateSharingLimits(15, 10),
               throwsA(isA<ValidationException>()));
      });
    });

    group('validateContent', () {
      test('returns trimmed content for valid input', () {
        // Arrange
        const input = '  This is content  ';
        
        // Act
        final result = ValidationUtils.validateContent(input, 'content');
        
        // Assert
        expect(result, equals('This is content'));
      });

      test('throws ValidationException for empty content', () {
        // Act & Assert
        expect(() => ValidationUtils.validateContent('', 'content'),
               throwsA(isA<ValidationException>()));
        expect(() => ValidationUtils.validateContent('   ', 'content'),
               throwsA(isA<ValidationException>()));
      });

      test('throws ValidationException for content too long', () {
        // Arrange
        final longContent = 'a' * 10001;
        
        // Act & Assert
        expect(() => ValidationUtils.validateContent(longContent, 'content'),
               throwsA(isA<ValidationException>()));
      });

      test('accepts content at maximum length', () {
        // Arrange
        final maxContent = 'a' * 10000;
        
        // Act & Assert
        expect(() => ValidationUtils.validateContent(maxContent, 'content'),
               returnsNormally);
      });
    });
  });

  group('SanitizationUtils Tests', () {
    group('sanitizeMetadata', () {
      test('returns null for null input', () {
        // Act
        final result = SanitizationUtils.sanitizeMetadata(null);
        
        // Assert
        expect(result, isNull);
      });

      test('sanitizes string values', () {
        // Arrange
        final input = {
          'title': '  Test <script>Title</script>  ',
          'count': 5,
          'enabled': true,
        };
        
        // Act
        final result = SanitizationUtils.sanitizeMetadata(input);
        
        // Assert
        expect(result?['title'], equals('Test Title'));
        expect(result?['count'], equals(5));
        expect(result?['enabled'], equals(true));
      });

      test('removes empty keys and values', () {
        // Arrange
        final input = {
          '': 'empty_key',
          'empty_value': '',
          'valid': 'content',
        };
        
        // Act
        final result = SanitizationUtils.sanitizeMetadata(input);
        
        // Assert
        expect(result?.containsKey(''), isFalse);
        expect(result?.containsKey('empty_value'), isFalse);
        expect(result?['valid'], equals('content'));
      });

      test('handles complex data types', () {
        // Arrange
        final input = {
          'list': [1, 2, 3],
          'map': {'nested': 'value'},
          'string': 'simple',
        };
        
        // Act
        final result = SanitizationUtils.sanitizeMetadata(input);
        
        // Assert
        expect(result?['list'], isA<String>());
        expect(result?['map'], isA<String>());
        expect(result?['string'], equals('simple'));
      });
    });

    group('sanitizeSearchQuery', () {
      test('returns null for null or empty input', () {
        // Act & Assert
        expect(SanitizationUtils.sanitizeSearchQuery(null), isNull);
        expect(SanitizationUtils.sanitizeSearchQuery(''), isNull);
        expect(SanitizationUtils.sanitizeSearchQuery('   '), isNull);
      });

      test('sanitizes and returns valid query', () {
        // Arrange
        const input = '  search <script>query</script>  ';
        
        // Act
        final result = SanitizationUtils.sanitizeSearchQuery(input);
        
        // Assert
        expect(result, equals('search query'));
      });

      test('returns null for query that becomes empty after sanitization', () {
        // Arrange
        const input = '<script></script>';
        
        // Act
        final result = SanitizationUtils.sanitizeSearchQuery(input);
        
        // Assert
        expect(result, isNull);
      });
    });
  });
}