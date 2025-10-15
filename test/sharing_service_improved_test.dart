import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nootes/services/sharing_service_improved.dart';
import 'package:nootes/services/exceptions/sharing_exceptions.dart';

void main() {
  group('SharingService Improved Tests', () {
    group('SharedItem Model Tests', () {
      test('SharedItem.fromMap creates valid instance', () {
        // Arrange
        final data = {
          'itemId': 'note_123',
          'type': 'note',
          'ownerId': 'owner_123',
          'ownerEmail': 'owner@example.com',
          'recipientId': 'recipient_123',
          'recipientEmail': 'recipient@example.com',
          'permission': 'read',
          'status': 'pending',
          'createdAt': Timestamp.now(),
          'message': 'Test sharing',
          'metadata': {'noteTitle': 'Test Note'},
        };

        // Act
        final result = SharedItem.fromMap('share_123', data);

        // Assert
        expect(result.id, equals('share_123'));
        expect(result.itemId, equals('note_123'));
        expect(result.type, equals(SharedItemType.note));
        expect(result.ownerId, equals('owner_123'));
        expect(result.permission, equals(PermissionLevel.read));
        expect(result.status, equals(SharingStatus.pending));
        expect(result.message, equals('Test sharing'));
        expect(result.metadata?['noteTitle'], equals('Test Note'));
      });

      test('SharedItem.fromMap throws ValidationException for invalid type', () {
        // Arrange
        final data = {
          'itemId': 'note_123',
          'type': 'invalid_type',
          'ownerId': 'owner_123',
          'ownerEmail': 'owner@example.com',
          'recipientId': 'recipient_123',
          'recipientEmail': 'recipient@example.com',
          'permission': 'read',
          'status': 'pending',
          'createdAt': Timestamp.now(),
        };

        // Act & Assert
        expect(() => SharedItem.fromMap('share_123', data),
               throwsA(isA<ValidationException>()));
      });

      test('SharedItem.fromMap throws ValidationException for empty itemId', () {
        // Arrange
        final data = {
          'itemId': '',
          'type': 'note',
          'ownerId': 'owner_123',
          'ownerEmail': 'owner@example.com',
          'recipientId': 'recipient_123',
          'recipientEmail': 'recipient@example.com',
          'permission': 'read',
          'status': 'pending',
          'createdAt': Timestamp.now(),
        };

        // Act & Assert
        expect(() => SharedItem.fromMap('share_123', data),
               throwsA(isA<ValidationException>()));
      });

      test('SharedItem.isExpired returns true when expiresAt is in past', () {
        // Arrange
        final pastDate = DateTime.now().subtract(const Duration(days: 1));
        final item = SharedItem(
          id: 'test',
          itemId: 'note_123',
          type: SharedItemType.note,
          ownerId: 'owner',
          ownerEmail: 'owner@example.com',
          recipientId: 'recipient',
          recipientEmail: 'recipient@example.com',
          permission: PermissionLevel.read,
          status: SharingStatus.accepted,
          createdAt: DateTime.now(),
          expiresAt: pastDate,
        );

        // Act
        final result = item.isExpired;

        // Assert
        expect(result, isTrue);
      });

      test('SharedItem.isExpired returns false when expiresAt is null', () {
        // Arrange
        final item = SharedItem(
          id: 'test',
          itemId: 'note_123',
          type: SharedItemType.note,
          ownerId: 'owner',
          ownerEmail: 'owner@example.com',
          recipientId: 'recipient',
          recipientEmail: 'recipient@example.com',
          permission: PermissionLevel.read,
          status: SharingStatus.accepted,
          createdAt: DateTime.now(),
        );

        // Act
        final result = item.isExpired;

        // Assert
        expect(result, isFalse);
      });

      test('SharedItem.isActive returns true for accepted non-expired sharing', () {
        // Arrange
        final futureDate = DateTime.now().add(const Duration(days: 1));
        final item = SharedItem(
          id: 'test',
          itemId: 'note_123',
          type: SharedItemType.note,
          ownerId: 'owner',
          ownerEmail: 'owner@example.com',
          recipientId: 'recipient',
          recipientEmail: 'recipient@example.com',
          permission: PermissionLevel.read,
          status: SharingStatus.accepted,
          createdAt: DateTime.now(),
          expiresAt: futureDate,
        );

        // Act
        final result = item.isActive;

        // Assert
        expect(result, isTrue);
      });

      test('SharedItem.isActive returns false for expired sharing', () {
        // Arrange
        final pastDate = DateTime.now().subtract(const Duration(days: 1));
        final item = SharedItem(
          id: 'test',
          itemId: 'note_123',
          type: SharedItemType.note,
          ownerId: 'owner',
          ownerEmail: 'owner@example.com',
          recipientId: 'recipient',
          recipientEmail: 'recipient@example.com',
          permission: PermissionLevel.read,
          status: SharingStatus.accepted,
          createdAt: DateTime.now(),
          expiresAt: pastDate,
        );

        // Act
        final result = item.isActive;

        // Assert
        expect(result, isFalse);
      });

      test('SharedItem.isTerminal returns true for revoked status', () {
        // Arrange
        final item = SharedItem(
          id: 'test',
          itemId: 'note_123',
          type: SharedItemType.note,
          ownerId: 'owner',
          ownerEmail: 'owner@example.com',
          recipientId: 'recipient',
          recipientEmail: 'recipient@example.com',
          permission: PermissionLevel.read,
          status: SharingStatus.revoked,
          createdAt: DateTime.now(),
        );

        // Act
        final result = item.isTerminal;

        // Assert
        expect(result, isTrue);
      });

      test('SharedItem.isTerminal returns false for pending status', () {
        // Arrange
        final item = SharedItem(
          id: 'test',
          itemId: 'note_123',
          type: SharedItemType.note,
          ownerId: 'owner',
          ownerEmail: 'owner@example.com',
          recipientId: 'recipient',
          recipientEmail: 'recipient@example.com',
          permission: PermissionLevel.read,
          status: SharingStatus.pending,
          createdAt: DateTime.now(),
        );

        // Act
        final result = item.isTerminal;

        // Assert
        expect(result, isFalse);
      });

      test('SharedItem.daysUntilExpiration calculates correctly', () {
        // Arrange
        final futureDate = DateTime.now().add(const Duration(days: 5));
        final item = SharedItem(
          id: 'test',
          itemId: 'note_123',
          type: SharedItemType.note,
          ownerId: 'owner',
          ownerEmail: 'owner@example.com',
          recipientId: 'recipient',
          recipientEmail: 'recipient@example.com',
          permission: PermissionLevel.read,
          status: SharingStatus.accepted,
          createdAt: DateTime.now(),
          expiresAt: futureDate,
        );

        // Act
        final result = item.daysUntilExpiration;

        // Assert
        expect(result, equals(5));
      });

      test('SharedItem.daysUntilExpiration returns null when no expiration', () {
        // Arrange
        final item = SharedItem(
          id: 'test',
          itemId: 'note_123',
          type: SharedItemType.note,
          ownerId: 'owner',
          ownerEmail: 'owner@example.com',
          recipientId: 'recipient',
          recipientEmail: 'recipient@example.com',
          permission: PermissionLevel.read,
          status: SharingStatus.accepted,
          createdAt: DateTime.now(),
        );

        // Act
        final result = item.daysUntilExpiration;

        // Assert
        expect(result, isNull);
      });

      test('SharedItem.itemTitle returns correct title from metadata', () {
        // Arrange
        final item = SharedItem(
          id: 'test',
          itemId: 'note_123',
          type: SharedItemType.note,
          ownerId: 'owner',
          ownerEmail: 'owner@example.com',
          recipientId: 'recipient',
          recipientEmail: 'recipient@example.com',
          permission: PermissionLevel.read,
          status: SharingStatus.accepted,
          createdAt: DateTime.now(),
          metadata: {'noteTitle': 'My Test Note'},
        );

        // Act
        final result = item.itemTitle;

        // Assert
        expect(result, equals('My Test Note'));
      });

      test('SharedItem.itemTitle returns default when no metadata', () {
        // Arrange
        final item = SharedItem(
          id: 'test',
          itemId: 'note_123',
          type: SharedItemType.note,
          ownerId: 'owner',
          ownerEmail: 'owner@example.com',
          recipientId: 'recipient',
          recipientEmail: 'recipient@example.com',
          permission: PermissionLevel.read,
          status: SharingStatus.accepted,
          createdAt: DateTime.now(),
        );

        // Act
        final result = item.itemTitle;

        // Assert
        expect(result, equals('Sin título'));
      });

      test('SharedItem.copyWith creates modified copy', () {
        // Arrange
        final original = SharedItem(
          id: 'test',
          itemId: 'note_123',
          type: SharedItemType.note,
          ownerId: 'owner',
          ownerEmail: 'owner@example.com',
          recipientId: 'recipient',
          recipientEmail: 'recipient@example.com',
          permission: PermissionLevel.read,
          status: SharingStatus.pending,
          createdAt: DateTime.now(),
        );

        // Act
        final modified = original.copyWith(
          permission: PermissionLevel.edit,
          status: SharingStatus.accepted,
        );

        // Assert
        expect(modified.id, equals(original.id));
        expect(modified.permission, equals(PermissionLevel.edit));
        expect(modified.status, equals(SharingStatus.accepted));
        expect(modified.itemId, equals(original.itemId));
        expect(modified.ownerId, equals(original.ownerId));
      });

      test('SharedItem.toMap creates correct map representation', () {
        // Arrange
        final item = SharedItem(
          id: 'test',
          itemId: 'note_123',
          type: SharedItemType.note,
          ownerId: 'owner',
          ownerEmail: 'owner@example.com',
          recipientId: 'recipient',
          recipientEmail: 'recipient@example.com',
          permission: PermissionLevel.read,
          status: SharingStatus.pending,
          createdAt: DateTime.now(),
          message: 'Test message',
          metadata: {'noteTitle': 'Test Note'},
        );

        // Act
        final result = item.toMap();

        // Assert
        expect(result['itemId'], equals('note_123'));
        expect(result['type'], equals('note'));
        expect(result['ownerId'], equals('owner'));
        expect(result['ownerEmail'], equals('owner@example.com'));
        expect(result['recipientId'], equals('recipient'));
        expect(result['recipientEmail'], equals('recipient@example.com'));
        expect(result['permission'], equals('read'));
        expect(result['status'], equals('pending'));
        expect(result['message'], equals('Test message'));
        expect(result['metadata'], equals({'noteTitle': 'Test Note'}));
      });
    });

    group('SharingConfig Tests', () {
      test('SharingConfig default values are correct', () {
        // Arrange & Act
        const config = SharingConfig();

        // Assert
        expect(config.enableNotifications, isTrue);
        expect(config.enablePresenceTracking, isTrue);
        expect(config.defaultPermission, equals(PermissionLevel.read));
        expect(config.enableComments, isTrue);
        expect(config.maxSharesPerItem, equals(50));
        expect(config.defaultExpirationDays, isNull);
      });

      test('SharingConfig custom values work correctly', () {
        // Arrange & Act
        const config = SharingConfig(
          enableNotifications: false,
          enablePresenceTracking: false,
          defaultPermission: PermissionLevel.edit,
          enableComments: false,
          maxSharesPerItem: 25,
          defaultExpirationDays: 30,
        );

        // Assert
        expect(config.enableNotifications, isFalse);
        expect(config.enablePresenceTracking, isFalse);
        expect(config.defaultPermission, equals(PermissionLevel.edit));
        expect(config.enableComments, isFalse);
        expect(config.maxSharesPerItem, equals(25));
        expect(config.defaultExpirationDays, equals(30));
      });
    });

    group('SharingResult Tests', () {
      test('SharingResult.success creates successful result', () {
        // Arrange
        const data = 'test_data';
        const metadata = {'key': 'value'};

        // Act
        final result = SharingResult.success(data, metadata: metadata);

        // Assert
        expect(result.success, isTrue);
        expect(result.data, equals(data));
        expect(result.error, isNull);
        expect(result.metadata, equals(metadata));
      });

      test('SharingResult.error creates error result', () {
        // Arrange
        const error = 'Test error';
        const metadata = {'errorCode': '500'};

        // Act
        final result = SharingResult.error(error, metadata: metadata);

        // Assert
        expect(result.success, isFalse);
        expect(result.data, isNull);
        expect(result.error, equals(error));
        expect(result.metadata, equals(metadata));
      });
    });

    group('Enum Tests', () {
      test('SharingStatus enum values are correct', () {
        expect(SharingStatus.pending.name, equals('pending'));
        expect(SharingStatus.accepted.name, equals('accepted'));
        expect(SharingStatus.rejected.name, equals('rejected'));
        expect(SharingStatus.revoked.name, equals('revoked'));
        expect(SharingStatus.left.name, equals('left'));
      });

      test('SharedItemType enum values are correct', () {
        expect(SharedItemType.note.name, equals('note'));
        expect(SharedItemType.folder.name, equals('folder'));
        expect(SharedItemType.collection.name, equals('collection'));
      });

      test('PermissionLevel enum values are correct', () {
        expect(PermissionLevel.read.name, equals('read'));
        expect(PermissionLevel.comment.name, equals('comment'));
        expect(PermissionLevel.edit.name, equals('edit'));
      });
    });

    group('Exception Tests', () {
      test('ValidationException contains correct message and code', () {
        // Arrange & Act
        const exception = ValidationException('testField', 'Custom error message');

        // Assert
        expect(exception.message, equals('Custom error message'));
        expect(exception.code, equals('validation/invalid'));
        expect(exception.toString(), contains('Custom error message'));
        expect(exception.toString(), contains('validation/invalid'));
      });

      test('AuthenticationException has correct default message', () {
        // Arrange & Act
        const exception = AuthenticationException();

        // Assert
        expect(exception.message, equals('Usuario no autenticado'));
        expect(exception.code, equals('auth/not-authenticated'));
      });

      test('ResourceNotFoundException includes resource type', () {
        // Arrange & Act
        const exception = ResourceNotFoundException('Nota');

        // Assert
        expect(exception.message, equals('Nota no encontrado'));
        expect(exception.code, equals('resource/not-found'));
      });

      test('SelfSharingException has correct message', () {
        // Arrange & Act
        const exception = SelfSharingException();

        // Assert
        expect(exception.message, equals('No puedes compartir contigo mismo'));
        expect(exception.code, equals('sharing/self-sharing'));
      });

      test('DuplicateSharingException has correct default message', () {
        // Arrange & Act
        const exception = DuplicateSharingException();

        // Assert
        expect(exception.message, equals('Esta compartición ya existe'));
        expect(exception.code, equals('sharing/duplicate'));
      });
    });
  });
}