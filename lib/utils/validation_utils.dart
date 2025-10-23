// Utility class for input validation and sanitization
import 'package:nootes/services/exceptions/sharing_exceptions.dart';

/// Utilidades para validación de datos de entrada
class ValidationUtils {
  /// Valida que un email tenga formato correcto
  static String validateEmail(String email) {
    if (email.trim().isEmpty) {
      throw const ValidationException('email', 'Email no puede estar vacío');
    }
    final s = email.trim();
    if (!s.contains('@')) {
      throw const ValidationException('email', 'Formato de email inválido');
    }

    final parts = s.split('@');
    if (parts.length != 2) {
      throw const ValidationException('email', 'Formato de email inválido');
    }

    final local = parts[0];
    final domain = parts[1];

    if (local.isEmpty) {
      throw const ValidationException('email', 'Formato de email inválido');
    }
    if (local.startsWith('.') || local.endsWith('.')) {
      throw const ValidationException('email', 'Formato de email inválido');
    }
    if (local.contains('..')) {
      throw const ValidationException('email', 'Formato de email inválido');
    }

    final domainParts = domain.split('.');
    if (domainParts.length < 2) {
      throw const ValidationException('email', 'Formato de email inválido');
    }
    for (final part in domainParts) {
      if (part.isEmpty) {
        throw const ValidationException('email', 'Formato de email inválido');
      }
      if (part.startsWith('-') || part.endsWith('-')) {
        throw const ValidationException('email', 'Formato de email inválido');
      }
    }

    final tld = domainParts.last;
    if (tld.length < 2) {
      throw const ValidationException('email', 'Formato de email inválido');
    }

    return s.toLowerCase();
  }

  /// Valida que un username tenga formato correcto
  static String validateUsername(String username) {
    if (username.trim().isEmpty) {
      throw const ValidationException(
        'username',
        'Username no puede estar vacío',
      );
    }

    final trimmed = username.trim();
    // Allow a leading '@' (common handle style), but internal '@' is invalid
    final normalizedUsername = (trimmed.startsWith('@'))
        ? trimmed.substring(1).toLowerCase()
        : trimmed.toLowerCase();

    if (trimmed.contains('@') && !trimmed.startsWith('@')) {
      throw const ValidationException(
        'username',
        'Username contiene caracteres inválidos',
      );
    }

    if (normalizedUsername.length < 3) {
      throw const ValidationException(
        'username',
        'Username debe tener al menos 3 caracteres',
      );
    }

    if (normalizedUsername.length > 30) {
      throw const ValidationException(
        'username',
        'Username no puede tener más de 30 caracteres',
      );
    }

    final usernameRegex = RegExp(r'^[a-zA-Z0-9_.-]+$');
    if (!usernameRegex.hasMatch(normalizedUsername)) {
      throw const ValidationException(
        'username',
        'Username contiene caracteres inválidos',
      );
    }

    return normalizedUsername;
  }

  /// Valida que un ID no esté vacío
  static String validateId(String id, String fieldName) {
    if (id.trim().isEmpty) {
      throw ValidationException(fieldName, '$fieldName no puede estar vacío');
    }
    return id.trim();
  }

  /// Valida que un mensaje no exceda límites
  static String? validateMessage(String? message) {
    if (message == null || message.trim().isEmpty) {
      return null;
    }

    final trimmed = message.trim();
    if (trimmed.length > 500) {
      throw const ValidationException(
        'message',
        'Mensaje no puede exceder 500 caracteres',
      );
    }

    return trimmed;
  }

  /// Valida que una fecha de expiración sea válida
  static DateTime? validateExpirationDate(DateTime? expiresAt) {
    if (expiresAt == null) {
      return null;
    }

    if (expiresAt.isBefore(DateTime.now())) {
      throw const ValidationException(
        'expiresAt',
        'Fecha de expiración debe ser en el futuro',
      );
    }

    // Máximo 1 año en el futuro
    final maxExpiration = DateTime.now().add(const Duration(days: 365));
    if (expiresAt.isAfter(maxExpiration)) {
      throw const ValidationException(
        'expiresAt',
        'Fecha de expiración no puede ser más de 1 año en el futuro',
      );
    }

    return expiresAt;
  }

  /// Sanitiza texto para prevenir inyecciones
  static String sanitizeText(String text) {
    // Remove HTML tags and normalize whitespace. Keep punctuation intact.
    return text
        .trim()
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remover HTML tags
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Valida un identificador de usuario (email o username)
  static String validateUserIdentifier(String identifier) {
    final trimmed = identifier.trim();

    if (trimmed.isEmpty) {
      throw const ValidationException(
        'userIdentifier',
        'Identificador de usuario no puede estar vacío',
      );
    }

    // Si contiene @, validar como email, sino como username
    if (trimmed.contains('@')) {
      return validateEmail(trimmed);
    } else {
      return validateUsername(trimmed);
    }
  }

  /// Valida límites de compartición
  static void validateSharingLimits(int currentShares, int maxShares) {
    if (currentShares >= maxShares) {
      throw ValidationException(
        'sharingLimit',
        'Has alcanzado el límite máximo de $maxShares comparticiones para este elemento',
      );
    }
  }

  /// Valida que el contenido no esté vacío
  static String validateContent(String content, String fieldName) {
    if (content.trim().isEmpty) {
      throw ValidationException(fieldName, '$fieldName no puede estar vacío');
    }

    if (content.trim().length > 10000) {
      throw ValidationException(
        fieldName,
        '$fieldName no puede exceder 10,000 caracteres',
      );
    }

    return content.trim();
  }
}

/// Utilidades para saneamiento de datos
class SanitizationUtils {
  /// Sanitiza datos de metadata
  static Map<String, dynamic>? sanitizeMetadata(
    Map<String, dynamic>? metadata,
  ) {
    if (metadata == null) return null;

    final sanitized = <String, dynamic>{};

    for (final entry in metadata.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) continue;

      final value = entry.value;
      if (value is String) {
        final sanitizedValue = ValidationUtils.sanitizeText(value);
        if (sanitizedValue.isNotEmpty) {
          sanitized[key] = sanitizedValue;
        }
      } else if (value is num || value is bool) {
        sanitized[key] = value;
      } else if (value is List || value is Map) {
        // Para estructuras complejas, convertir a string y sanitizar
        sanitized[key] = ValidationUtils.sanitizeText(value.toString());
      }
    }

    return sanitized;
  }

  /// Sanitiza parámetros de búsqueda
  static String? sanitizeSearchQuery(String? query) {
    if (query == null || query.trim().isEmpty) {
      return null;
    }

    final sanitized = ValidationUtils.sanitizeText(query);
    return sanitized.isEmpty ? null : sanitized;
  }
}
