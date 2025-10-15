/// Excepciones específicas para el servicio de almacenamiento
library;

/// Excepción base para errores de almacenamiento
class StorageException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const StorageException(this.message, {this.code, this.originalError});

  @override
  String toString() => 'StorageException: $message';
}

/// Excepción para errores de subida de archivos
class FileUploadException extends StorageException {
  const FileUploadException(super.message, {super.code, super.originalError});

  @override
  String toString() => 'FileUploadException: $message';
}

/// Excepción para errores de descarga de archivos
class FileDownloadException extends StorageException {
  const FileDownloadException(super.message, {super.code, super.originalError});

  @override
  String toString() => 'FileDownloadException: $message';
}

/// Excepción para archivos no encontrados
class FileNotFoundException extends StorageException {
  const FileNotFoundException(super.message, {super.code, super.originalError});

  @override
  String toString() => 'FileNotFoundException: $message';
}

/// Excepción para errores de validación de archivos
class FileValidationException extends StorageException {
  const FileValidationException(super.message, {super.code, super.originalError});

  @override
  String toString() => 'FileValidationException: $message';
}

/// Excepción para errores de eliminación de archivos
class FileDeletionException extends StorageException {
  const FileDeletionException(super.message, {super.code, super.originalError});

  @override
  String toString() => 'FileDeletionException: $message';
}

/// Excepción para errores de acceso a archivos
class FileAccessException extends StorageException {
  const FileAccessException(super.message, {super.code, super.originalError});

  @override
  String toString() => 'FileAccessException: $message';
}

/// Excepción para errores de copia de archivos
class FileCopyException extends StorageException {
  const FileCopyException(super.message, {super.code, super.originalError});

  @override
  String toString() => 'FileCopyException: $message';
}

/// Excepción para errores de movimiento de archivos
class FileMoveException extends StorageException {
  const FileMoveException(super.message, {super.code, super.originalError});

  @override
  String toString() => 'FileMoveException: $message';
}

/// Excepción para archivos corruptos
class FileCorruptionException extends StorageException {
  const FileCorruptionException(super.message, {super.code, super.originalError});

  @override
  String toString() => 'FileCorruptionException: $message';
}

/// Excepción para operaciones canceladas
class FileOperationCancelledException extends StorageException {
  const FileOperationCancelledException(super.message, {super.code, super.originalError});

  @override
  String toString() => 'FileOperationCancelledException: $message';
}

/// Excepción para errores de red relacionados con almacenamiento
class NetworkException extends StorageException {
  const NetworkException(super.message, {super.code, super.originalError});

  @override
  String toString() => 'NetworkException: $message';
}

/// Excepción para errores de estadísticas de almacenamiento
class StorageStatsException extends StorageException {
  const StorageStatsException(super.message, {super.code, super.originalError});

  @override
  String toString() => 'StorageStatsException: $message';
}

/// Excepción para cuando se excede la cuota de almacenamiento
class StorageQuotaExceededException extends StorageException {
  final int currentSize;
  final int maxSize;

  const StorageQuotaExceededException(
    super.message, 
    this.currentSize, 
    this.maxSize, {
    super.code, 
    super.originalError
  });

  @override
  String toString() => 'StorageQuotaExceededException: $message (${currentSize}B/${maxSize}B)';
}

/// Excepción para tipos de archivo no permitidos
class UnsupportedFileTypeException extends FileValidationException {
  final String fileExtension;
  final List<String> allowedTypes;

  const UnsupportedFileTypeException(
    super.message,
    this.fileExtension,
    this.allowedTypes, {
    super.code,
    super.originalError
  });

  @override
  String toString() => 'UnsupportedFileTypeException: $message (.$fileExtension no está en ${allowedTypes.join(', ')})';
}

/// Excepción para archivos demasiado grandes
class FileSizeExceededException extends FileValidationException {
  final int fileSize;
  final int maxSize;

  const FileSizeExceededException(
    super.message,
    this.fileSize,
    this.maxSize, {
    super.code,
    super.originalError
  });

  @override
  String toString() => 'FileSizeExceededException: $message (${fileSize}B > ${maxSize}B)';
}

/// Excepción para metadatos inválidos
class InvalidMetadataException extends StorageException {
  final Map<String, dynamic> metadata;

  const InvalidMetadataException(
    super.message,
    this.metadata, {
    super.code,
    super.originalError
  });

  @override
  String toString() => 'InvalidMetadataException: $message';
}

/// Excepción de autenticación para operaciones de almacenamiento
class AuthenticationException extends StorageException {
  const AuthenticationException(super.message, {super.code, super.originalError});

  @override
  String toString() => 'AuthenticationException: $message';
}