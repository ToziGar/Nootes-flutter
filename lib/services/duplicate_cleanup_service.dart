import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../utils/debug.dart';

/// 🧹 Sistema Avanzado de Limpieza de Duplicados
/// Características:
/// - 🔍 Detección inteligente de duplicados
/// - 🗑️ Eliminación automática segura
/// - 📊 Análisis y reportes detallados
/// - ⚡ Optimización de rendimiento
class DuplicateCleanupService {
  static const DuplicateCleanupService _instance =
      DuplicateCleanupService._internal();
  static const DuplicateCleanupService instance = _instance;
  const DuplicateCleanupService._internal();

  /// 🔍 Detecta y limpia duplicados de carpetas
  Future<DuplicateCleanupResult> cleanFolderDuplicates({
    bool dryRun = false,
  }) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) {
      return DuplicateCleanupResult(
        success: false,
        error: 'Usuario no autenticado',
        duplicatesFound: 0,
        duplicatesRemoved: 0,
      );
    }

    try {
  logDebug('🧹 Iniciando limpieza avanzada de duplicados...');

      // 1. Obtener todas las carpetas
      final allFolders = await FirestoreService.instance.listFolders(uid: uid);
  logDebug('📁 Total carpetas encontradas: ${allFolders.length}');

      // 2. Agrupar por folderId lógico
      final folderGroups = <String, List<Map<String, dynamic>>>{};
      for (var folder in allFolders) {
        final folderId =
            folder['folderId']?.toString() ?? folder['id']?.toString() ?? '';
        if (folderId.isNotEmpty) {
          folderGroups.putIfAbsent(folderId, () => []).add(folder);
        }
      }

      // 3. Identificar grupos con duplicados
      final duplicateGroups = folderGroups.entries
          .where((entry) => entry.value.length > 1)
          .toList();

  logDebug('⚠️ Grupos con duplicados: ${duplicateGroups.length}');

      int totalDuplicatesFound = 0;
      int totalDuplicatesRemoved = 0;
      final List<String> removedDocIds = [];
      final List<DuplicateGroup> detailedGroups = [];

      // 4. Procesar cada grupo de duplicados
      for (var group in duplicateGroups) {
        final folderId = group.key;
        final duplicates = group.value;
        totalDuplicatesFound +=
            duplicates.length - 1; // -1 porque uno se conserva

        logDebug('🔍 Procesando grupo $folderId con ${duplicates.length} duplicados');

        // Ordenar por fecha de actualización (más reciente primero)
        duplicates.sort((a, b) {
          final aTime = a['updatedAt'] ?? a['createdAt'];
          final bTime = b['updatedAt'] ?? b['createdAt'];

          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;

          try {
            final aDate = DateTime.parse(aTime.toString());
            final bDate = DateTime.parse(bTime.toString());
            return bDate.compareTo(aDate); // Más reciente primero
          } catch (e) {
            return 0;
          }
        });

        // Mantener el más reciente, eliminar el resto
        final toKeep = duplicates.first;
        final toRemove = duplicates.skip(1).toList();

        final duplicateGroup = DuplicateGroup(
          folderId: folderId,
          folderName: toKeep['name']?.toString() ?? 'Sin nombre',
          totalCount: duplicates.length,
          keptDocument: DuplicateDocument.fromMap(toKeep),
          removedDocuments: toRemove
              .map((d) => DuplicateDocument.fromMap(d))
              .toList(),
        );
        detailedGroups.add(duplicateGroup);

        if (!dryRun) {
          // Eliminar duplicados
          for (var duplicate in toRemove) {
            final docId = duplicate['id']?.toString();
            if (docId != null) {
              try {
                await FirestoreService.instance.deleteFolder(
                  uid: uid,
                  folderId: docId,
                );
                removedDocIds.add(docId);
                totalDuplicatesRemoved++;
                logDebug('🗑️ Eliminado duplicado: $docId');
              } catch (e) {
                logDebug('❌ Error eliminando $docId: $e');
              }
            }
          }
        }
      }

      // 5. Verificación final
      if (!dryRun && totalDuplicatesRemoved > 0) {
  logDebug('✅ Esperando sincronización...');
        await Future.delayed(const Duration(seconds: 2));

        // Verificar que se eliminaron correctamente
        final remainingFolders = await FirestoreService.instance.listFolders(
          uid: uid,
        );
        final remainingGroups = <String, List<Map<String, dynamic>>>{};

        for (var folder in remainingFolders) {
          final folderId =
              folder['folderId']?.toString() ?? folder['id']?.toString() ?? '';
          if (folderId.isNotEmpty) {
            remainingGroups.putIfAbsent(folderId, () => []).add(folder);
          }
        }

        final stillDuplicated = remainingGroups.entries
            .where((entry) => entry.value.length > 1)
            .length;

        logDebug('🔍 Verificación: $stillDuplicated grupos aún tienen duplicados');
      }

      final result = DuplicateCleanupResult(
        success: true,
        duplicatesFound: totalDuplicatesFound,
        duplicatesRemoved: totalDuplicatesRemoved,
        groups: detailedGroups,
        removedDocumentIds: removedDocIds,
        dryRun: dryRun,
      );

      _printCleanupReport(result);
      return result;
    } catch (e) {
      logDebug('❌ Error en limpieza de duplicados: $e');
      return DuplicateCleanupResult(
        success: false,
        error: e.toString(),
        duplicatesFound: 0,
        duplicatesRemoved: 0,
      );
    }
  }

  /// 🔍 Detecta duplicados de notas
  Future<DuplicateCleanupResult> cleanNoteDuplicates({
    bool dryRun = false,
  }) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) {
      return DuplicateCleanupResult(
        success: false,
        error: 'Usuario no autenticado',
        duplicatesFound: 0,
        duplicatesRemoved: 0,
      );
    }

    try {
      logDebug('🧹 Iniciando limpieza de duplicados de notas...');

      final allNotes = await FirestoreService.instance.listNotes(uid: uid);
  logDebug('📝 Total notas encontradas: ${allNotes.length}');

      // Agrupar por contenido similar (hash del título + primeras 100 chars)
      final noteGroups = <String, List<Map<String, dynamic>>>{};
      for (var note in allNotes) {
        final title = note['title']?.toString() ?? '';
        final content = note['content']?.toString() ?? '';
        final hash = _generateContentHash(title, content);
        noteGroups.putIfAbsent(hash, () => []).add(note);
      }

      final duplicateGroups = noteGroups.entries
          .where((entry) => entry.value.length > 1)
          .toList();

  logDebug('⚠️ Grupos de notas duplicadas: ${duplicateGroups.length}');

      int totalDuplicatesFound = 0;
      int totalDuplicatesRemoved = 0;

      for (var group in duplicateGroups) {
        final duplicates = group.value;
        totalDuplicatesFound += duplicates.length - 1;

        // Mantener la más reciente
        duplicates.sort((a, b) {
          final aTime = a['updatedAt'] ?? a['createdAt'];
          final bTime = b['updatedAt'] ?? b['createdAt'];

          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;

          try {
            final aDate = DateTime.parse(aTime.toString());
            final bDate = DateTime.parse(bTime.toString());
            return bDate.compareTo(aDate);
          } catch (e) {
            return 0;
          }
        });

        if (!dryRun) {
          final toRemove = duplicates.skip(1);
          for (var duplicate in toRemove) {
            final noteId = duplicate['id']?.toString();
            if (noteId != null) {
              try {
                await FirestoreService.instance.deleteNote(
                  uid: uid,
                  noteId: noteId,
                );
                totalDuplicatesRemoved++;
                logDebug('🗑️ Nota duplicada eliminada: $noteId');
              } catch (e) {
                logDebug('❌ Error eliminando nota $noteId: $e');
              }
            }
          }
        }
      }

      return DuplicateCleanupResult(
        success: true,
        duplicatesFound: totalDuplicatesFound,
        duplicatesRemoved: totalDuplicatesRemoved,
        dryRun: dryRun,
      );
    } catch (e) {
      logDebug('❌ Error en limpieza de duplicados de notas: $e');
      return DuplicateCleanupResult(
        success: false,
        error: e.toString(),
        duplicatesFound: 0,
        duplicatesRemoved: 0,
      );
    }
  }

  /// 🔧 Limpieza completa del sistema
  Future<ComprehensiveCleanupResult> performComprehensiveCleanup({
    bool dryRun = false,
  }) async {
  logDebug('🧹 🚀 Iniciando limpieza completa del sistema...');

    final folderResult = await cleanFolderDuplicates(dryRun: dryRun);
    await Future.delayed(const Duration(seconds: 1));

    final noteResult = await cleanNoteDuplicates(dryRun: dryRun);
    await Future.delayed(const Duration(seconds: 1));

    return ComprehensiveCleanupResult(
      folderCleanup: folderResult,
      noteCleanup: noteResult,
      totalDuplicatesFound:
          folderResult.duplicatesFound + noteResult.duplicatesFound,
      totalDuplicatesRemoved:
          folderResult.duplicatesRemoved + noteResult.duplicatesRemoved,
    );
  }

  /// 📊 Genera hash de contenido para detectar similitudes
  String _generateContentHash(String title, String content) {
    final combined =
        '$title${content.length > 100 ? content.substring(0, 100) : content}';
    return combined
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .hashCode
        .toString();
  }

  /// 📋 Imprime reporte detallado
  void _printCleanupReport(DuplicateCleanupResult result) {
    logDebug('\n📊 === REPORTE DE LIMPIEZA ===');
    logDebug('✅ Éxito: ${result.success}');
    logDebug('🔍 Duplicados encontrados: ${result.duplicatesFound}');
    logDebug('🗑️ Duplicados eliminados: ${result.duplicatesRemoved}');
    logDebug('🧪 Modo prueba: ${result.dryRun}');

    if (result.groups != null && result.groups!.isNotEmpty) {
      logDebug('\n📁 Grupos procesados:');
      for (var group in result.groups!) {
        logDebug('  📂 ${group.folderName} (${group.folderId})');
        logDebug('    Total: ${group.totalCount} documentos');
        logDebug('    Conservado: ${group.keptDocument.documentId}');
        logDebug('    Eliminados: ${group.removedDocuments.length}');
      }
    }

    if (result.error != null) {
      logDebug('❌ Error: ${result.error}');
    }
    logDebug('========================='
        '\n');
  }
}

/// 📊 Resultado de limpieza de duplicados
class DuplicateCleanupResult {
  final bool success;
  final String? error;
  final int duplicatesFound;
  final int duplicatesRemoved;
  final List<DuplicateGroup>? groups;
  final List<String>? removedDocumentIds;
  final bool dryRun;

  const DuplicateCleanupResult({
    required this.success,
    this.error,
    required this.duplicatesFound,
    required this.duplicatesRemoved,
    this.groups,
    this.removedDocumentIds,
    this.dryRun = false,
  });
}

/// 📊 Resultado de limpieza completa
class ComprehensiveCleanupResult {
  final DuplicateCleanupResult folderCleanup;
  final DuplicateCleanupResult noteCleanup;
  final int totalDuplicatesFound;
  final int totalDuplicatesRemoved;

  const ComprehensiveCleanupResult({
    required this.folderCleanup,
    required this.noteCleanup,
    required this.totalDuplicatesFound,
    required this.totalDuplicatesRemoved,
  });

  bool get success => folderCleanup.success && noteCleanup.success;
}

/// 🏷️ Grupo de duplicados
class DuplicateGroup {
  final String folderId;
  final String folderName;
  final int totalCount;
  final DuplicateDocument keptDocument;
  final List<DuplicateDocument> removedDocuments;

  const DuplicateGroup({
    required this.folderId,
    required this.folderName,
    required this.totalCount,
    required this.keptDocument,
    required this.removedDocuments,
  });
}

/// 📄 Documento duplicado
class DuplicateDocument {
  final String documentId;
  final String? name;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DuplicateDocument({
    required this.documentId,
    this.name,
    this.createdAt,
    this.updatedAt,
  });

  factory DuplicateDocument.fromMap(Map<String, dynamic> map) {
    return DuplicateDocument(
      documentId: map['id']?.toString() ?? '',
      name: map['name']?.toString(),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())
          : null,
    );
  }
}
