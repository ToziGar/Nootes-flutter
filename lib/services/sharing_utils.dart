import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:nootes/services/sharing_service_improved.dart';
import 'package:nootes/services/exceptions/sharing_exceptions.dart';

/// Utilidades para operaciones de compartición
class SharingUtils {
  SharingUtils._();

  /// Genera un token seguro para enlaces públicos
  static String generateSecureToken([int length = 32]) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(length, (index) => chars[random.nextInt(chars.length)]).join();
  }

  /// Valida un email
  static bool isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }

  /// Valida un nombre de usuario (@username)
  static bool isValidUsername(String username) {
    // Remueve el @ si está presente
    final cleanUsername = username.startsWith('@') ? username.substring(1) : username;
    return RegExp(r'^[a-z0-9._]{3,20}$').hasMatch(cleanUsername);
  }

  /// Convierte un string a SharingStatus
  static SharingStatus? parseStatus(String? status) {
    if (status == null) return null;
    try {
      return SharingStatus.values.firstWhere((e) => e.name == status);
    } catch (e) {
      return null;
    }
  }

  /// Convierte un string a SharedItemType
  static SharedItemType? parseItemType(String? type) {
    if (type == null) return null;
    try {
      return SharedItemType.values.firstWhere((e) => e.name == type);
    } catch (e) {
      return null;
    }
  }

  /// Convierte un string a PermissionLevel
  static PermissionLevel? parsePermission(String? permission) {
    if (permission == null) return null;
    try {
      return PermissionLevel.values.firstWhere((e) => e.name == permission);
    } catch (e) {
      return null;
    }
  }

  /// Valida que un mapa contenga los campos requeridos
  static void validateRequiredFields(Map<String, dynamic> data, List<String> requiredFields) {
    for (final field in requiredFields) {
      if (!data.containsKey(field) || data[field] == null) {
        throw ValidationException('Campo requerido faltante: $field');
      }
    }
  }

  /// Valida que un string no esté vacío
  static void validateNotEmpty(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      throw ValidationException('Campo $fieldName no puede estar vacío');
    }
  }

  /// Limpia y valida un identificador de usuario (email o @username)
  static String normalizeUserIdentifier(String identifier) {
    final cleaned = identifier.trim();
    if (cleaned.isEmpty) {
      throw ValidationException('Identificador de usuario no puede estar vacío');
    }

    if (cleaned.contains('@') && !cleaned.startsWith('@')) {
      // Es un email
      if (!isValidEmail(cleaned)) {
        throw ValidationException('Email inválido: $cleaned');
      }
      return cleaned.toLowerCase();
    } else if (cleaned.startsWith('@')) {
      // Es un username
      if (!isValidUsername(cleaned)) {
        throw ValidationException('Nombre de usuario inválido: $cleaned');
      }
      return cleaned.toLowerCase();
    } else {
      throw ValidationException('Identificador debe ser un email o @username: $cleaned');
    }
  }

  /// Convierte un Timestamp de Firestore a DateTime
  static DateTime? timestampToDateTime(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is fs.Timestamp) {
      return timestamp.toDate();
    }
    if (timestamp is DateTime) {
      return timestamp;
    }
    return null;
  }

  /// Calcula los días hasta la expiración
  static int calculateDaysUntilExpiration(DateTime? expiresAt) {
    if (expiresAt == null) return -1;
    final now = DateTime.now();
    if (expiresAt.isBefore(now)) return 0;
    final difference = expiresAt.difference(now);
    // Redondear hacia arriba para días parciales
    return (difference.inHours / 24).ceil();
  }

  /// Construye los metadatos para operaciones de compartición
  static Map<String, dynamic> buildSharingMetadata({
    String? operation,
    String? shareId,
    String? itemId,
    SharedItemType? itemType,
    String? userId,
    Map<String, dynamic>? additionalData,
  }) {
    final metadata = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (operation != null) metadata['operation'] = operation;
    if (shareId != null) metadata['shareId'] = shareId;
    if (itemId != null) metadata['itemId'] = itemId;
    if (itemType != null) metadata['itemType'] = itemType.name;
    if (userId != null) metadata['userId'] = userId;
    if (additionalData != null) metadata.addAll(additionalData);

    return metadata;
  }

  /// Genera un ID único para elementos compartidos
  static String generateShareId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999).toString().padLeft(6, '0');
    return 'share_${timestamp}_$random';
  }

  /// Construye una clave de caché para el servicio de compartición
  static String buildCacheKey(String prefix, String identifier) {
    return '${prefix}_${identifier.toLowerCase()}';
  }

  /// Valida permisos de operación
  static void validateOperationPermissions({
    required String currentUserId,
    required String? ownerId,
    required String? recipientId,
    required bool requireOwner,
    required bool requireRecipient,
  }) {
    if (requireOwner && ownerId != currentUserId) {
      throw PermissionDeniedException('Solo el propietario puede realizar esta operación');
    }

    if (requireRecipient && recipientId != currentUserId) {
      throw PermissionDeniedException('Solo el receptor puede realizar esta operación');
    }

    if (!requireOwner && !requireRecipient && 
        ownerId != currentUserId && recipientId != currentUserId) {
      throw PermissionDeniedException('No tienes permisos para realizar esta operación');
    }
  }

  /// Sanitiza datos para logging
  static Map<String, dynamic> sanitizeForLogging(Map<String, dynamic> data) {
    final sanitized = Map<String, dynamic>.from(data);
    
    // Remover información sensible
    sanitized.remove('password');
    sanitized.remove('token');
    sanitized.remove('secret');
    
    // Truncar emails para privacidad
    if (sanitized.containsKey('email')) {
      final email = sanitized['email'] as String?;
      if (email != null && email.contains('@')) {
        final parts = email.split('@');
        if (parts[0].length > 3) {
          sanitized['email'] = '${parts[0].substring(0, 3)}***@${parts[1]}';
        }
      }
    }

    // Truncar usernames
    if (sanitized.containsKey('username')) {
      final username = sanitized['username'] as String?;
      if (username != null && username.length > 3) {
        sanitized['username'] = '${username.substring(0, 3)}***';
      }
    }

    return sanitized;
  }
}

/// Utilidades para validación específica de datos de compartición
class SharingValidation {
  SharingValidation._();

  /// Valida los datos de un SharedItem antes de crear o actualizar
  static void validateSharedItemData(Map<String, dynamic> data) {
    // Campos requeridos
    SharingUtils.validateRequiredFields(data, [
      'itemId', 'type', 'ownerId', 'ownerEmail', 
      'recipientId', 'recipientEmail', 'permission', 'status'
    ]);

    // Validaciones específicas
    SharingUtils.validateNotEmpty(data['itemId'], 'itemId');
    SharingUtils.validateNotEmpty(data['ownerId'], 'ownerId');
    SharingUtils.validateNotEmpty(data['recipientId'], 'recipientId');

    // Validar email format
    if (!SharingUtils.isValidEmail(data['ownerEmail'])) {
      throw ValidationException('Email del propietario inválido: ${data['ownerEmail']}');
    }

    if (!SharingUtils.isValidEmail(data['recipientEmail'])) {
      throw ValidationException('Email del receptor inválido: ${data['recipientEmail']}');
    }

    // Validar enums
    if (SharingUtils.parseItemType(data['type']) == null) {
      throw ValidationException('Tipo de compartición inválido');
    }

    if (SharingUtils.parsePermission(data['permission']) == null) {
      throw ValidationException('Nivel de permisos inválido');
    }

    if (SharingUtils.parseStatus(data['status']) == null) {
      throw ValidationException('Estado de compartición inválido');
    }

    // Validar que owner y recipient sean diferentes
    if (data['ownerId'] == data['recipientId']) {
      throw ValidationException('El propietario y receptor no pueden ser la misma persona');
    }
  }

  /// Valida los datos para crear un enlace público
  static void validatePublicLinkData({
    required String noteId,
    required String ownerId,
    PermissionLevel? permission,
    DateTime? expiresAt,
  }) {
    SharingUtils.validateNotEmpty(noteId, 'noteId');
    SharingUtils.validateNotEmpty(ownerId, 'ownerId');

    if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
      throw ValidationException('La fecha de expiración no puede ser en el pasado');
    }

    if (permission == null) {
      throw ValidationException('Se debe especificar un nivel de permisos');
    }
  }

  /// Valida los parámetros para buscar comparticiones
  static void validateSearchParameters({
    String? itemId,
    String? userId,
    SharedItemType? itemType,
    SharingStatus? status,
    int? limit,
  }) {
    if (limit != null && limit <= 0) {
      throw ValidationException('El límite debe ser mayor a 0');
    }

    if (limit != null && limit > 100) {
      throw ValidationException('El límite no puede ser mayor a 100');
    }
  }
}