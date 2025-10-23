import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import '../utils/debug.dart';
import '../services/auth_service.dart';
import '../services/exceptions/storage_exceptions.dart' as storage_ex;
import '../services/exceptions/auth_exceptions.dart';
import 'package:crypto/crypto.dart';

/// Servicio mejorado de almacenamiento con capacidades avanzadas
class StorageServiceEnhanced {
  static final StorageServiceEnhanced _instance =
      StorageServiceEnhanced._internal();
  factory StorageServiceEnhanced() => _instance;
  StorageServiceEnhanced._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AuthService _authService = AuthService.instance;

  // Cache de metadatos
  final Map<String, FileMetadata> _metadataCache = {};
  final Map<String, FirebaseUploadTask> _activeUploads = {};
  final Map<String, FirebaseDownloadTask> _activeDownloads = {};
  final Map<String, DateTime> _transferStartTimes = {};

  static const int _maxFileSize = 50 * 1024 * 1024; // 50MB
  // URL expiration (no usada actualmente) – si se implementa firma temporal, reintroducir

  // Tipos de archivos permitidos
  static const List<String> _allowedImageTypes = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
  ];
  static const List<String> _allowedDocumentTypes = [
    'pdf',
    'doc',
    'docx',
    'txt',
    'rtf',
    'odt',
  ];
  static const List<String> _allowedAudioTypes = [
    'mp3',
    'wav',
    'aac',
    'ogg',
    'm4a',
  ];
  static const List<String> _allowedVideoTypes = [
    'mp4',
    'avi',
    'mov',
    'wmv',
    'flv',
    'webm',
  ];

  /// Sube un archivo con progreso y metadatos
  Future<UploadResult> uploadFile({
    required File file,
    required String noteId,
    String? fileName,
    Map<String, String>? customMetadata,
    void Function(double progress)? onProgress,
    String? folder,
  }) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      throw const NotAuthenticatedException();
    }

    // Validar archivo
    final validation = await _validateFile(file, fileName);
    if (!validation.isValid) {
      throw storage_ex.FileValidationException(validation.error!);
    }

    try {
      final fileExtension = path.extension(file.path).toLowerCase();
      final finalFileName =
          fileName ?? '${DateTime.now().millisecondsSinceEpoch}$fileExtension';
      final storagePath = _buildStoragePath(uid, noteId, finalFileName, folder);

      // Crear metadatos
      final metadata = await _createFileMetadata(file, customMetadata);

      // Iniciar subida
      final ref = _storage.ref(storagePath);
      final uploadTask = ref.putFile(
        file,
        SettableMetadata(
          contentType: metadata.mimeType,
          customMetadata: Map<String, String>.from(metadata.toMap()),
        ),
      );

      // Guardar tarea activa y momento de inicio
      final taskId = _generateTaskId();
      _activeUploads[taskId] = uploadTask;
      _transferStartTimes[taskId] = DateTime.now();

      // Monitorear progreso
      uploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress?.call(progress);
        },
        onError: (error) {
          _activeUploads.remove(taskId);
          _transferStartTimes.remove(taskId);
          logDebug('Error en subida: $error');
        },
      );

      // Esperar completado
      final snapshot = await uploadTask;
      _activeUploads.remove(taskId);
      _transferStartTimes.remove(taskId);

      // Obtener URL de descarga
      final downloadUrl = await ref.getDownloadURL();

      // Actualizar cache de metadatos
      final finalMetadata = FileMetadata(
        id: taskId,
        fileName: finalFileName,
        originalName: path.basename(file.path),
        size: snapshot.totalBytes,
        mimeType: metadata.mimeType,
        downloadUrl: downloadUrl,
        storagePath: storagePath,
        uploadedAt: DateTime.now(),
        checksum: metadata.checksum,
        customMetadata: customMetadata ?? {},
      );

      _metadataCache[storagePath] = finalMetadata;

      return UploadResult(
        success: true,
        fileId: taskId,
        downloadUrl: downloadUrl,
        storagePath: storagePath,
        metadata: finalMetadata,
      );
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    } catch (e) {
      logDebug('Error subiendo archivo: $e');
      throw storage_ex.FileUploadException('Error inesperado al subir archivo');
    }
  }

  /// Sube múltiples archivos en lote
  Future<BatchUploadResult> uploadFiles({
    required List<File> files,
    required String noteId,
    Map<String, String>? customMetadata,
    void Function(int completed, int total)? onProgress,
    String? folder,
  }) async {
    final results = <UploadResult>[];
    final errors = <String, String>{};

    for (int i = 0; i < files.length; i++) {
      try {
        final result = await uploadFile(
          file: files[i],
          noteId: noteId,
          customMetadata: customMetadata,
          folder: folder,
        );
        results.add(result);
      } catch (e) {
        final fileName = path.basename(files[i].path);
        errors[fileName] = e.toString();
      }

      onProgress?.call(i + 1, files.length);
    }

    return BatchUploadResult(
      successfulUploads: results,
      errors: errors,
      totalFiles: files.length,
      successCount: results.length,
    );
  }

  /// Descarga un archivo
  Future<DownloadResult> downloadFile({
    required String storagePath,
    required String localPath,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final ref = _storage.ref(storagePath);
      final file = File(localPath);

      // Crear directorio si no existe
      await file.parent.create(recursive: true);

      final downloadTask = ref.writeToFile(file);
      final taskId = _generateTaskId();
      _activeDownloads[taskId] = downloadTask;
      _transferStartTimes[taskId] = DateTime.now();

      // Monitorear progreso
      downloadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress?.call(progress);
        },
        onError: (error) {
          _activeDownloads.remove(taskId);
          _transferStartTimes.remove(taskId);
          logDebug('Error en descarga: $error');
        },
      );

      await downloadTask;
      _activeDownloads.remove(taskId);
      _transferStartTimes.remove(taskId);

      return DownloadResult(
        success: true,
        localPath: localPath,
        fileSize: await file.length(),
      );
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    } catch (e) {
      logDebug('Error descargando archivo: $e');
      throw storage_ex.FileDownloadException('Error al descargar archivo');
    }
  }

  /// Obtiene los metadatos de un archivo
  Future<FileMetadata?> getFileMetadata(String storagePath) async {
    // Verificar cache
    if (_metadataCache.containsKey(storagePath)) {
      return _metadataCache[storagePath];
    }

    try {
      final ref = _storage.ref(storagePath);
      final metadata = await ref.getMetadata();

      final fileMetadata = FileMetadata(
        id: _generateTaskId(),
        fileName: path.basename(storagePath),
        originalName: metadata.customMetadata?['originalName'] ?? '',
        size: metadata.size ?? 0,
        mimeType: metadata.contentType ?? 'application/octet-stream',
        downloadUrl: await ref.getDownloadURL(),
        storagePath: storagePath,
        uploadedAt: metadata.timeCreated ?? DateTime.now(),
        checksum: metadata.customMetadata?['checksum'] ?? '',
        customMetadata: metadata.customMetadata ?? {},
      );

      _metadataCache[storagePath] = fileMetadata;
      return fileMetadata;
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') {
        return null;
      }
      throw _mapFirebaseException(e);
    } catch (e) {
      logDebug('Error obteniendo metadatos: $e');
      return null;
    }
  }

  /// Lista archivos de una nota
  Future<List<FileMetadata>> listNoteFiles(String noteId) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      throw const NotAuthenticatedException();
    }

    try {
      final notePath = 'users/$uid/notes/$noteId/attachments/';
      final listResult = await _storage.ref(notePath).listAll();

      final files = <FileMetadata>[];

      for (final item in listResult.items) {
        final metadata = await getFileMetadata(item.fullPath);
        if (metadata != null) {
          files.add(metadata);
        }
      }

      return files;
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    } catch (e) {
      logDebug('Error listando archivos: $e');
      return [];
    }
  }

  /// Elimina un archivo
  Future<void> deleteFile(String storagePath) async {
    try {
      final ref = _storage.ref(storagePath);
      await ref.delete();

      // Limpiar cache
      _metadataCache.remove(storagePath);
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') {
        throw _mapFirebaseException(e);
      }
    } catch (e) {
      logDebug('Error eliminando archivo: $e');
      throw storage_ex.FileDeletionException('Error al eliminar archivo');
    }
  }

  /// Elimina múltiples archivos
  Future<BatchDeleteResult> deleteFiles(List<String> storagePaths) async {
    final deletedFiles = <String>[];
    final errors = <String, String>{};

    for (final storagePath in storagePaths) {
      try {
        await deleteFile(storagePath);
        deletedFiles.add(storagePath);
      } catch (e) {
        errors[storagePath] = e.toString();
      }
    }

    return BatchDeleteResult(
      deletedFiles: deletedFiles,
      errors: errors,
      totalFiles: storagePaths.length,
      successCount: deletedFiles.length,
    );
  }

  /// Obtiene una URL temporal de descarga
  ///
  /// NOTA: Firebase Storage no soporta URLs con expiración personalizada directamente.
  /// Las URLs obtenidas con getDownloadURL() son permanentes hasta que se elimine el archivo.
  /// Para URLs con expiración, se necesitaría implementar Firebase Admin SDK en el backend
  /// o usar Cloud Functions para generar signed URLs con expiración personalizada.
  Future<String> getTemporaryDownloadUrl({
    required String storagePath,
    Duration? expiration,
  }) async {
    try {
      final ref = _storage.ref(storagePath);
      final url = await ref.getDownloadURL();

      // Las URLs de Firebase Storage no expiran por defecto
      // Para implementar expiración personalizada se requiere:
      // 1. Firebase Admin SDK en el backend
      // 2. Cloud Functions que generen signed URLs
      // 3. O un servicio intermedio que gestione la validez de los enlaces

      return url;
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    } catch (e) {
      logDebug('Error obteniendo URL temporal: $e');
      throw storage_ex.FileAccessException('Error al generar URL de descarga');
    }
  }

  /// Copia un archivo a otra ubicación
  Future<String> copyFile({
    required String sourceStoragePath,
    required String destinationNoteId,
    String? newFileName,
  }) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      throw const NotAuthenticatedException();
    }

    try {
      // Obtener metadatos del archivo origen
      final sourceMetadata = await getFileMetadata(sourceStoragePath);
      if (sourceMetadata == null) {
        throw storage_ex.FileNotFoundException('Archivo origen no encontrado');
      }

      // Generar nueva ruta
      final fileName = newFileName ?? sourceMetadata.fileName;
      final destPath = _buildStoragePath(uid, destinationNoteId, fileName);

      // Descargar y resubir (Firebase Storage no tiene copy nativo)
      final sourceRef = _storage.ref(sourceStoragePath);
      final destRef = _storage.ref(destPath);

      final data = await sourceRef.getData();
      if (data == null) {
        throw storage_ex.FileDownloadException(
          'No se pudo obtener datos del archivo',
        );
      }

      await destRef.putData(
        data,
        SettableMetadata(
          contentType: sourceMetadata.mimeType,
          customMetadata: sourceMetadata.customMetadata,
        ),
      );

      return destPath;
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    } catch (e) {
      logDebug('Error copiando archivo: $e');
      throw storage_ex.FileCopyException('Error al copiar archivo');
    }
  }

  /// Mueve un archivo a otra ubicación
  Future<String> moveFile({
    required String sourceStoragePath,
    required String destinationNoteId,
    String? newFileName,
  }) async {
    try {
      // Copiar archivo
      final newPath = await copyFile(
        sourceStoragePath: sourceStoragePath,
        destinationNoteId: destinationNoteId,
        newFileName: newFileName,
      );

      // Eliminar archivo original
      await deleteFile(sourceStoragePath);

      return newPath;
    } catch (e) {
      logDebug('Error moviendo archivo: $e');
      throw storage_ex.FileMoveException('Error al mover archivo');
    }
  }

  /// Obtiene estadísticas de uso de almacenamiento
  Future<StorageStats> getStorageStats() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      throw const NotAuthenticatedException();
    }

    try {
      final userPath = 'users/$uid/';
      final listResult = await _storage.ref(userPath).listAll();

      int totalFiles = 0;
      int totalSize = 0;
      final fileTypeCount = <String, int>{};
      final sizeByType = <String, int>{};

      // Función recursiva para contar archivos
      Future<void> countFiles(List<Reference> items) async {
        for (final item in items) {
          try {
            final metadata = await item.getMetadata();
            totalFiles++;
            totalSize += metadata.size ?? 0;

            final extension = path
                .extension(item.name)
                .toLowerCase()
                .replaceFirst('.', '');
            fileTypeCount[extension] = (fileTypeCount[extension] ?? 0) + 1;
            sizeByType[extension] =
                (sizeByType[extension] ?? 0) + (metadata.size ?? 0);
          } catch (e) {
            logDebug('Error obteniendo metadatos de ${item.fullPath}: $e');
          }
        }
      }

      await countFiles(listResult.items);

      // Procesar subdirectorios recursivamente
      for (final prefix in listResult.prefixes) {
        final subResult = await prefix.listAll();
        await countFiles(subResult.items);
      }

      return StorageStats(
        totalFiles: totalFiles,
        totalSizeBytes: totalSize,
        fileTypeCount: fileTypeCount,
        sizeByType: sizeByType,
        lastUpdated: DateTime.now(),
      );
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    } catch (e) {
      logDebug('Error obteniendo estadísticas: $e');
      throw storage_ex.StorageStatsException(
        'Error al obtener estadísticas de almacenamiento',
      );
    }
  }

  /// Cancela una subida activa
  Future<void> cancelUpload(String taskId) async {
    final uploadTask = _activeUploads[taskId];
    if (uploadTask != null) {
      await uploadTask.cancel();
      _activeUploads.remove(taskId);
    }
  }

  /// Cancela una descarga activa
  Future<void> cancelDownload(String taskId) async {
    final downloadTask = _activeDownloads[taskId];
    if (downloadTask != null) {
      await downloadTask.cancel();
      _activeDownloads.remove(taskId);
    }
  }

  /// Obtiene tareas activas
  Map<String, TransferProgress> getActiveTransfers() {
    final transfers = <String, TransferProgress>{};

    for (final entry in _activeUploads.entries) {
      final snapshot = entry.value.snapshot;
      transfers[entry.key] = TransferProgress(
        type: TransferType.upload,
        bytesTransferred: snapshot.bytesTransferred,
        totalBytes: snapshot.totalBytes,
        progress: snapshot.bytesTransferred / snapshot.totalBytes,
        state: _mapTaskState(snapshot.state),
        startTime: _transferStartTimes[entry.key],
      );
    }

    for (final entry in _activeDownloads.entries) {
      final snapshot = entry.value.snapshot;
      transfers[entry.key] = TransferProgress(
        type: TransferType.download,
        bytesTransferred: snapshot.bytesTransferred,
        totalBytes: snapshot.totalBytes,
        progress: snapshot.bytesTransferred / snapshot.totalBytes,
        state: _mapTaskState(snapshot.state),
        startTime: _transferStartTimes[entry.key],
      );
    }

    return transfers;
  }

  /// Limpia cache y recursos
  void clearCache() {
    _metadataCache.clear();
  }

  void dispose() {
    clearCache();
    _activeUploads.clear();
    _activeDownloads.clear();
  }

  // Métodos privados de utilidad

  Future<FileValidation> _validateFile(File file, String? fileName) async {
    try {
      // Verificar existencia
      if (!await file.exists()) {
        return FileValidation(false, 'El archivo no existe');
      }

      // Verificar tamaño
      final size = await file.length();
      if (size > _maxFileSize) {
        return FileValidation(
          false,
          'Archivo demasiado grande (máximo ${_maxFileSize ~/ (1024 * 1024)}MB)',
        );
      }

      if (size == 0) {
        return FileValidation(false, 'El archivo está vacío');
      }

      // Verificar tipo de archivo
      final extension = path
          .extension(fileName ?? file.path)
          .toLowerCase()
          .replaceFirst('.', '');
      if (!_isAllowedFileType(extension)) {
        return FileValidation(
          false,
          'Tipo de archivo no permitido: $extension',
        );
      }

      return FileValidation(true, null);
    } catch (e) {
      return FileValidation(false, 'Error validando archivo: $e');
    }
  }

  bool _isAllowedFileType(String extension) {
    return _allowedImageTypes.contains(extension) ||
        _allowedDocumentTypes.contains(extension) ||
        _allowedAudioTypes.contains(extension) ||
        _allowedVideoTypes.contains(extension);
  }

  Future<FileMetadata> _createFileMetadata(
    File file,
    Map<String, String>? customMetadata,
  ) async {
    final size = await file.length();
    final bytes = await file.readAsBytes();
    final checksum = sha256.convert(bytes).toString();
    final extension = path.extension(file.path).toLowerCase();

    return FileMetadata(
      id: _generateTaskId(),
      fileName: path.basename(file.path),
      originalName: path.basename(file.path),
      size: size,
      mimeType: _getMimeType(extension),
      downloadUrl: '',
      storagePath: '',
      uploadedAt: DateTime.now(),
      checksum: checksum,
      customMetadata: customMetadata ?? {},
    );
  }

  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.pdf':
        return 'application/pdf';
      case '.txt':
        return 'text/plain';
      case '.mp3':
        return 'audio/mpeg';
      case '.mp4':
        return 'video/mp4';
      default:
        return 'application/octet-stream';
    }
  }

  String _buildStoragePath(
    String uid,
    String noteId,
    String fileName, [
    String? folder,
  ]) {
    final basePath = 'users/$uid/notes/$noteId/attachments';
    return folder != null
        ? '$basePath/$folder/$fileName'
        : '$basePath/$fileName';
  }

  String _generateTaskId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  TransferState _mapTaskState(TaskState state) {
    switch (state) {
      case TaskState.running:
        return TransferState.running;
      case TaskState.paused:
        return TransferState.paused;
      case TaskState.success:
        return TransferState.completed;
      case TaskState.canceled:
        return TransferState.canceled;
      case TaskState.error:
        return TransferState.error;
    }
  }

  storage_ex.StorageException _mapFirebaseException(FirebaseException e) {
    switch (e.code) {
      case 'object-not-found':
        return storage_ex.FileNotFoundException(
          e.message ?? 'Archivo no encontrado',
        );
      case 'unauthorized':
        return storage_ex.FileAccessException(
          'Sin permisos para acceder al archivo',
        );
      case 'canceled':
        return storage_ex.FileOperationCancelledException(
          'Operación cancelada',
        );
      case 'invalid-checksum':
        return storage_ex.FileCorruptionException('Archivo corrupto');
      case 'retry-limit-exceeded':
        return storage_ex.NetworkException('Límite de reintentos excedido');
      default:
        return storage_ex.StorageException(
          e.message ?? 'Error de almacenamiento',
        );
    }
  }
}

// Clases de resultado

class UploadResult {
  final bool success;
  final String fileId;
  final String downloadUrl;
  final String storagePath;
  final FileMetadata metadata;

  const UploadResult({
    required this.success,
    required this.fileId,
    required this.downloadUrl,
    required this.storagePath,
    required this.metadata,
  });
}

class BatchUploadResult {
  final List<UploadResult> successfulUploads;
  final Map<String, String> errors;
  final int totalFiles;
  final int successCount;

  const BatchUploadResult({
    required this.successfulUploads,
    required this.errors,
    required this.totalFiles,
    required this.successCount,
  });

  int get failureCount => totalFiles - successCount;
  bool get hasErrors => errors.isNotEmpty;
  double get successRate => totalFiles > 0 ? successCount / totalFiles : 0.0;
}

class DownloadResult {
  final bool success;
  final String localPath;
  final int fileSize;

  const DownloadResult({
    required this.success,
    required this.localPath,
    required this.fileSize,
  });
}

class BatchDeleteResult {
  final List<String> deletedFiles;
  final Map<String, String> errors;
  final int totalFiles;
  final int successCount;

  const BatchDeleteResult({
    required this.deletedFiles,
    required this.errors,
    required this.totalFiles,
    required this.successCount,
  });

  int get failureCount => totalFiles - successCount;
  bool get hasErrors => errors.isNotEmpty;
  double get successRate => totalFiles > 0 ? successCount / totalFiles : 0.0;
}

class FileMetadata {
  final String id;
  final String fileName;
  final String originalName;
  final int size;
  final String mimeType;
  final String downloadUrl;
  final String storagePath;
  final DateTime uploadedAt;
  final String checksum;
  final Map<String, String> customMetadata;

  const FileMetadata({
    required this.id,
    required this.fileName,
    required this.originalName,
    required this.size,
    required this.mimeType,
    required this.downloadUrl,
    required this.storagePath,
    required this.uploadedAt,
    required this.checksum,
    required this.customMetadata,
  });

  String get sizeFormatted {
    if (size < 1024) return '${size}B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)}KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  String get fileType {
    final extension = path
        .extension(fileName)
        .toLowerCase()
        .replaceFirst('.', '');
    return extension.toUpperCase();
  }

  bool get isImage {
    final extension = path
        .extension(fileName)
        .toLowerCase()
        .replaceFirst('.', '');
    return StorageServiceEnhanced._allowedImageTypes.contains(extension);
  }

  bool get isDocument {
    final extension = path
        .extension(fileName)
        .toLowerCase()
        .replaceFirst('.', '');
    return StorageServiceEnhanced._allowedDocumentTypes.contains(extension);
  }

  bool get isAudio {
    final extension = path
        .extension(fileName)
        .toLowerCase()
        .replaceFirst('.', '');
    return StorageServiceEnhanced._allowedAudioTypes.contains(extension);
  }

  bool get isVideo {
    final extension = path
        .extension(fileName)
        .toLowerCase()
        .replaceFirst('.', '');
    return StorageServiceEnhanced._allowedVideoTypes.contains(extension);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileName': fileName,
      'originalName': originalName,
      'size': size.toString(),
      'mimeType': mimeType,
      'uploadedAt': uploadedAt.toIso8601String(),
      'checksum': checksum,
      ...customMetadata,
    };
  }
}

class StorageStats {
  final int totalFiles;
  final int totalSizeBytes;
  final Map<String, int> fileTypeCount;
  final Map<String, int> sizeByType;
  final DateTime lastUpdated;

  const StorageStats({
    required this.totalFiles,
    required this.totalSizeBytes,
    required this.fileTypeCount,
    required this.sizeByType,
    required this.lastUpdated,
  });

  String get totalSizeFormatted {
    if (totalSizeBytes < 1024) return '${totalSizeBytes}B';
    if (totalSizeBytes < 1024 * 1024) {
      return '${(totalSizeBytes / 1024).toStringAsFixed(1)}KB';
    }
    if (totalSizeBytes < 1024 * 1024 * 1024) {
      return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(totalSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  String get mostUsedFileType {
    if (fileTypeCount.isEmpty) return 'N/A';

    final sorted = fileTypeCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.first.key.toUpperCase();
  }

  double get averageFileSize {
    return totalFiles > 0 ? totalSizeBytes / totalFiles : 0.0;
  }
}

class TransferProgress {
  final TransferType type;
  final int bytesTransferred;
  final int totalBytes;
  final double progress;
  final TransferState state;
  final DateTime? startTime;

  const TransferProgress({
    required this.type,
    required this.bytesTransferred,
    required this.totalBytes,
    required this.progress,
    required this.state,
    this.startTime,
  });

  String get progressPercentage => '${(progress * 100).toStringAsFixed(1)}%';

  String get speedFormatted {
    if (startTime == null || bytesTransferred == 0) return 'N/A';

    final elapsed = DateTime.now().difference(startTime!);
    if (elapsed.inMilliseconds == 0) return 'N/A';

    final bytesPerSecond = (bytesTransferred / elapsed.inSeconds);

    if (bytesPerSecond < 1024) {
      return '${bytesPerSecond.toStringAsFixed(1)} B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
  }

  String get remainingTimeFormatted {
    if (startTime == null || bytesTransferred == 0 || progress >= 1.0) {
      return 'N/A';
    }

    final elapsed = DateTime.now().difference(startTime!);
    if (elapsed.inMilliseconds == 0) return 'N/A';

    final bytesPerSecond = bytesTransferred / elapsed.inSeconds;
    final remainingBytes = totalBytes - bytesTransferred;
    final remainingSeconds = (remainingBytes / bytesPerSecond).ceil();

    if (remainingSeconds < 60) {
      return '$remainingSeconds seg';
    } else if (remainingSeconds < 3600) {
      final minutes = (remainingSeconds / 60).floor();
      return '$minutes min';
    } else {
      final hours = (remainingSeconds / 3600).floor();
      final minutes = ((remainingSeconds % 3600) / 60).floor();
      return '${hours}h ${minutes}min';
    }
  }
}

class FileValidation {
  final bool isValid;
  final String? error;

  const FileValidation(this.isValid, this.error);
}

// Enums

enum TransferType { upload, download }

enum TransferState { running, paused, completed, canceled, error }

// Tipos de tasks para manejo interno
typedef FirebaseUploadTask = UploadTask;
typedef FirebaseDownloadTask = DownloadTask;
