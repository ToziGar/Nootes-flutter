import 'package:nootes/services/exceptions/sharing_exceptions.dart';

/// Utilidades de validación para el sistema general
class ValidationUtils {
  ValidationUtils._();

  /// Valida que un valor no sea nulo
  static T validateNotNull<T>(T? value, String fieldName) {
    if (value == null) {
      throw ValidationException('Campo $fieldName es requerido');
    }
    return value;
  }

  /// Valida que un string no esté vacío
  static String validateNotEmpty(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      throw ValidationException('Campo $fieldName no puede estar vacío');
    }
    return value.trim();
  }

  /// Valida un email
  static String validateEmail(String? email, [String fieldName = 'email']) {
    final trimmed = validateNotEmpty(email, fieldName);
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(trimmed)) {
      throw ValidationException('$fieldName debe ser un email válido');
    }

    return trimmed.toLowerCase();
  }

  /// Valida una URL
  static String validateUrl(String? url, [String fieldName = 'URL']) {
    final trimmed = validateNotEmpty(url, fieldName);

    try {
      final uri = Uri.parse(trimmed);
      if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        throw ValidationException('$fieldName debe ser una URL válida');
      }
      return trimmed;
    } catch (e) {
      throw ValidationException('$fieldName debe ser una URL válida');
    }
  }

  /// Valida que un número esté en un rango
  static int validateIntRange(int? value, int min, int max, String fieldName) {
    final validated = validateNotNull(value, fieldName);

    if (validated < min || validated > max) {
      throw ValidationException('$fieldName debe estar entre $min y $max');
    }

    return validated;
  }

  /// Valida que un string tenga una longitud específica
  static String validateStringLength(
    String? value,
    int minLength,
    int maxLength,
    String fieldName,
  ) {
    final trimmed = validateNotEmpty(value, fieldName);

    if (trimmed.length < minLength || trimmed.length > maxLength) {
      throw ValidationException(
        '$fieldName debe tener entre $minLength y $maxLength caracteres',
      );
    }

    return trimmed;
  }

  /// Valida que un valor esté en una lista de valores permitidos
  static T validateInList<T>(
    T? value,
    List<T> allowedValues,
    String fieldName,
  ) {
    final validated = validateNotNull(value, fieldName);

    if (!allowedValues.contains(validated)) {
      throw ValidationException(
        '$fieldName debe ser uno de: ${allowedValues.join(', ')}',
      );
    }

    return validated;
  }

  /// Valida un ID (formato UUID o similar)
  static String validateId(String? id, [String fieldName = 'ID']) {
    final trimmed = validateNotEmpty(id, fieldName);

    // Validar formato básico (letras, números, guiones, underscores)
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(trimmed)) {
      throw ValidationException('$fieldName contiene caracteres inválidos');
    }

    if (trimmed.length < 3 || trimmed.length > 50) {
      throw ValidationException(
        '$fieldName debe tener entre 3 y 50 caracteres',
      );
    }

    return trimmed;
  }

  /// Valida un username (sin @)
  static String validateUsername(
    String? username, [
    String fieldName = 'nombre de usuario',
  ]) {
    final trimmed = validateNotEmpty(username, fieldName);

    // Remover @ si está presente
    final cleanUsername = trimmed.startsWith('@')
        ? trimmed.substring(1)
        : trimmed;

    if (!RegExp(r'^[a-z0-9._]{3,20}$').hasMatch(cleanUsername)) {
      throw ValidationException(
        '$fieldName debe tener 3-20 caracteres y solo contener letras minúsculas, números, puntos y guiones bajos',
      );
    }

    return cleanUsername;
  }

  /// Valida una fecha
  static DateTime validateDate(DateTime? date, [String fieldName = 'fecha']) {
    return validateNotNull(date, fieldName);
  }

  /// Valida que una fecha sea futura
  static DateTime validateFutureDate(
    DateTime? date, [
    String fieldName = 'fecha',
  ]) {
    final validated = validateDate(date, fieldName);

    if (validated.isBefore(DateTime.now())) {
      throw ValidationException('$fieldName debe ser en el futuro');
    }

    return validated;
  }

  /// Valida que una fecha esté en un rango
  static DateTime validateDateRange(
    DateTime? date,
    DateTime minDate,
    DateTime maxDate,
    String fieldName,
  ) {
    final validated = validateDate(date, fieldName);

    if (validated.isBefore(minDate) || validated.isAfter(maxDate)) {
      throw ValidationException(
        '$fieldName debe estar entre ${minDate.toIso8601String()} y ${maxDate.toIso8601String()}',
      );
    }

    return validated;
  }

  /// Combina múltiples validaciones en una sola
  static T validateChain<T>(T? value, List<T Function(T?)> validators) {
    T? result = value;

    for (final validator in validators) {
      result = validator(result);
    }

    return result!;
  }

  /// Valida un mapa que contenga ciertos campos
  static Map<String, dynamic> validateMapFields(
    Map<String, dynamic>? data,
    List<String> requiredFields, [
    String fieldName = 'datos',
  ]) {
    final validated = validateNotNull(data, fieldName);

    for (final field in requiredFields) {
      if (!validated.containsKey(field)) {
        throw ValidationException('Campo requerido faltante: $field');
      }
    }

    return validated;
  }

  /// Sanitiza un string removiendo caracteres peligrosos
  static String sanitizeString(String? input, [String fieldName = 'texto']) {
    final trimmed = validateNotEmpty(input, fieldName);

    // Remover caracteres de control y algunos caracteres especiales peligrosos
    return trimmed
        .replaceAll('<', '')
        .replaceAll('>', '')
        .replaceAll('"', '')
        .replaceAll("'", '')
        .replaceAll('\\', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Valida y sanitiza HTML básico
  static String sanitizeHtml(
    String? html, [
    String fieldName = 'contenido HTML',
  ]) {
    final trimmed = validateNotEmpty(html, fieldName);

    // Remover scripts y contenido peligroso
    var sanitized = trimmed
        .replaceAll(
          RegExp(
            r'<script[^>]*>.*?</script>',
            caseSensitive: false,
            dotAll: true,
          ),
          '',
        )
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '');

    return sanitized;
  }
}
