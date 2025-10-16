// ignore_for_file: use_super_parameters

/// Base authentication exception
abstract class AuthenticationException implements Exception {
  const AuthenticationException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() =>
      'AuthenticationException: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Exception thrown when user is not found
class UserNotFoundException extends AuthenticationException {
  const UserNotFoundException()
    : super('Usuario no encontrado', code: 'auth/user-not-found');
}

/// Exception thrown when password is incorrect
class WrongPasswordException extends AuthenticationException {
  const WrongPasswordException()
    : super('Contraseña incorrecta', code: 'auth/wrong-password');
}

/// Exception thrown when email is already in use
class EmailAlreadyInUseException extends AuthenticationException {
  const EmailAlreadyInUseException()
    : super('El email ya está en uso', code: 'auth/email-already-in-use');
}

/// Exception thrown when password is too weak
class WeakPasswordException extends AuthenticationException {
  const WeakPasswordException()
    : super(
        'La contraseña debe tener al menos 6 caracteres',
        code: 'auth/weak-password',
      );
}

/// Exception thrown when email format is invalid
class InvalidEmailException extends AuthenticationException {
  const InvalidEmailException()
    : super('Formato de email inválido', code: 'auth/invalid-email');
}

/// Exception thrown when user account is disabled
class UserDisabledException extends AuthenticationException {
  const UserDisabledException()
    : super('Cuenta de usuario deshabilitada', code: 'auth/user-disabled');
}

/// Exception thrown when too many requests are made
class TooManyRequestsException extends AuthenticationException {
  const TooManyRequestsException()
    : super(
        'Demasiados intentos. Intenta más tarde',
        code: 'auth/too-many-requests',
      );
}

/// Exception thrown when email is not verified
class EmailNotVerifiedException extends AuthenticationException {
  const EmailNotVerifiedException()
    : super(
        'Email no verificado. Revisa tu bandeja de entrada',
        code: 'auth/email-not-verified',
      );
}

/// Exception thrown when session expires
class SessionExpiredException extends AuthenticationException {
  const SessionExpiredException()
    : super(
        'Sesión expirada. Inicia sesión nuevamente',
        code: 'auth/session-expired',
      );
}

/// Exception thrown when network connection fails
class NetworkException extends AuthenticationException {
  const NetworkException()
    : super(
        'Error de conexión. Verifica tu internet',
        code: 'auth/network-error',
      );
}

/// Exception thrown when operation requires recent authentication
class RequiresRecentLoginException extends AuthenticationException {
  const RequiresRecentLoginException()
    : super(
        'Esta operación requiere autenticación reciente',
        code: 'auth/requires-recent-login',
      );
}

/// Exception thrown when credential is invalid
class InvalidCredentialException extends AuthenticationException {
  const InvalidCredentialException()
    : super('Credenciales inválidas', code: 'auth/invalid-credential');
}

/// Exception thrown when operation is not allowed
class OperationNotAllowedException extends AuthenticationException {
  const OperationNotAllowedException()
    : super('Operación no permitida', code: 'auth/operation-not-allowed');
}

/// Exception thrown when account exists with different credential
class AccountExistsWithDifferentCredentialException
    extends AuthenticationException {
  const AccountExistsWithDifferentCredentialException()
    : super(
        'Ya existe una cuenta con este email usando un proveedor diferente',
        code: 'auth/account-exists-with-different-credential',
      );
}

/// Exception thrown when credential is already in use
class CredentialAlreadyInUseException extends AuthenticationException {
  const CredentialAlreadyInUseException()
    : super(
        'Esta credencial ya está en uso por otra cuenta',
        code: 'auth/credential-already-in-use',
      );
}

/// Exception thrown when email change needs verification
class EmailChangeNeedsVerificationException extends AuthenticationException {
  const EmailChangeNeedsVerificationException()
    : super(
        'El cambio de email requiere verificación',
        code: 'auth/email-change-needs-verification',
      );
}

/// Exception thrown when internal error occurs
class InternalErrorException extends AuthenticationException {
  const InternalErrorException()
    : super('Error interno del servidor', code: 'auth/internal-error');
}

/// Exception thrown when invalid API key is used
class InvalidApiKeyException extends AuthenticationException {
  const InvalidApiKeyException()
    : super('Clave de API inválida', code: 'auth/invalid-api-key');
}

/// Exception thrown when invalid user token is used
class InvalidUserTokenException extends AuthenticationException {
  const InvalidUserTokenException()
    : super('Token de usuario inválido', code: 'auth/invalid-user-token');
}

/// Exception thrown when user token has expired
class UserTokenExpiredException extends AuthenticationException {
  const UserTokenExpiredException()
    : super('Token de usuario expirado', code: 'auth/user-token-expired');
}

/// Generic authentication error wrapper for unexpected cases
class GenericAuthException extends AuthenticationException {
  const GenericAuthException(String message, {String? code})
    : super(message, code: code ?? 'auth/generic');
}

/// Thrown when an operation requires a logged in user but none present
class NotAuthenticatedException extends AuthenticationException {
  const NotAuthenticatedException()
    : super('Usuario no autenticado', code: 'auth/not-authenticated');
}
