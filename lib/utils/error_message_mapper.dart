/// Utility para mapear errores técnicos a mensajes amigables para el usuario
class ErrorMessageMapper {
  /// Mapea un error a un mensaje amigable en español
  static String map(dynamic error) {
    if (error == null) return 'Ocurrió un error inesperado';

    final msg = error.toString().toLowerCase();

    // Errores de permisos
    if (msg.contains('permission') ||
        msg.contains('denied') ||
        msg.contains('unauthorized')) {
      return 'No tienes permiso para realizar esta acción';
    }

    // Errores de red
    if (msg.contains('network') ||
        msg.contains('connection') ||
        msg.contains('timeout')) {
      return 'No hay conexión a internet. Verifica tu conexión';
    }

    // Errores de not found
    if (msg.contains('not found') ||
        msg.contains('does not exist') ||
        msg.contains('no existe')) {
      return 'El elemento no existe o fue eliminado';
    }

    // Errores de duplicados
    if (msg.contains('already exists') ||
        msg.contains('duplicate') ||
        msg.contains('ya existe')) {
      return 'Ya existe un elemento con ese nombre';
    }

    // Errores de validación
    if (msg.contains('invalid') ||
        msg.contains('inválido') ||
        msg.contains('formato')) {
      return 'Los datos proporcionados no son válidos';
    }

    // Errores de Firebase Auth
    if (msg.contains('user-not-found')) {
      return 'No existe una cuenta con ese correo';
    }
    if (msg.contains('wrong-password') || msg.contains('invalid-credential')) {
      return 'Contraseña incorrecta';
    }
    if (msg.contains('email-already-in-use')) {
      return 'Ya existe una cuenta con ese correo';
    }
    if (msg.contains('weak-password')) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    if (msg.contains('too-many-requests')) {
      return 'Demasiados intentos. Intenta más tarde';
    }

    // Errores de Firestore
    if (msg.contains('quota-exceeded') || msg.contains('resource-exhausted')) {
      return 'Se ha excedido el límite de operaciones. Intenta más tarde';
    }

    // Errores de Storage
    if (msg.contains('object-not-found') || msg.contains('file not found')) {
      return 'El archivo no existe';
    }
    if (msg.contains('unauthorized')) {
      return 'No tienes acceso a este archivo';
    }
    if (msg.contains('retry-limit-exceeded')) {
      return 'La operación falló después de varios intentos';
    }

    // Error genérico
    return 'Ocurrió un error inesperado. Intenta nuevamente';
  }

  /// Mapea un error y sugiere una acción al usuario
  static String mapWithAction(dynamic error) {
    final baseMessage = map(error);
    final msg = error.toString().toLowerCase();

    if (msg.contains('network') || msg.contains('connection')) {
      return '$baseMessage y vuelve a intentar';
    }
    if (msg.contains('permission') || msg.contains('unauthorized')) {
      return '$baseMessage. Contacta al administrador si el problema persiste';
    }
    if (msg.contains('not found')) {
      return '$baseMessage. Recarga la página';
    }

    return baseMessage;
  }
}
