// Custom exceptions for the sharing system

/// Base exception for all sharing-related errors
abstract class SharingException implements Exception {
  const SharingException(this.message, {this.code, this.details});
  
  final String message;
  final String? code;
  final Map<String, dynamic>? details;
  
  @override
  String toString() => 'SharingException: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Exception thrown when user is not authenticated
class AuthenticationException extends SharingException {
  const AuthenticationException([String? message]) 
    : super(message ?? 'Usuario no autenticado', code: 'auth/not-authenticated');
}

/// Exception thrown when user lacks permissions
class PermissionDeniedException extends SharingException {
  const PermissionDeniedException([String? message]) 
    : super(message ?? 'Permisos insuficientes', code: 'auth/permission-denied');
}

/// Exception thrown when requested resource is not found
class ResourceNotFoundException extends SharingException {
  const ResourceNotFoundException(String resourceType, [String? message]) 
    : super(message ?? '$resourceType no encontrado', code: 'resource/not-found');
}

/// Exception thrown when trying to share with oneself
class SelfSharingException extends SharingException {
  const SelfSharingException() 
    : super('No puedes compartir contigo mismo', code: 'sharing/self-sharing');
}

/// Exception thrown when sharing already exists
class DuplicateSharingException extends SharingException {
  const DuplicateSharingException([String? message]) 
    : super(message ?? 'Esta compartición ya existe', code: 'sharing/duplicate');
}

/// Exception thrown for network-related errors
class NetworkException extends SharingException {
  const NetworkException([String? message]) 
    : super(message ?? 'Error de conexión. Verifica tu internet', code: 'network/error');
}

/// Exception thrown for Firestore-related errors
class FirestoreException extends SharingException {
  const FirestoreException([String? message]) 
    : super(message ?? 'Error en la base de datos', code: 'firestore/error');
}

/// Exception thrown for validation errors
class ValidationException extends SharingException {
  const ValidationException(String field, [String? message]) 
    : super(message ?? 'Valor inválido para $field', code: 'validation/invalid');
}

/// Exception thrown when user is not found
class UserNotFoundException extends SharingException {
  const UserNotFoundException([String? message]) 
    : super(message ?? 'Usuario no encontrado', code: 'user/not-found');
}

/// Exception thrown when sharing has expired
class SharingExpiredException extends SharingException {
  const SharingExpiredException() 
    : super('Esta compartición ha expirado', code: 'sharing/expired');
}

/// Exception thrown when sharing status is invalid for operation
class InvalidSharingStatusException extends SharingException {
  const InvalidSharingStatusException(String operation, String currentStatus) 
    : super('No se puede $operation una compartición con estado $currentStatus', 
            code: 'sharing/invalid-status');
}