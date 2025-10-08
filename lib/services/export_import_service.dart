import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Servicio para exportar e importar notas
class ExportImportService {
  /// Exportar todas las notas a JSON
  static Future<void> exportToJson(List<Map<String, dynamic>> notes, {String filename = 'notas_backup'}) async {
    try {
      final jsonString = JsonEncoder.withIndent('  ').convert({
        'exportDate': DateTime.now().toIso8601String(),
        'version': '1.0',
        'notesCount': notes.length,
        'notes': notes,
      });

      if (kIsWeb) {
        _downloadFileWeb(jsonString, '$filename.json', 'application/json');
      } else {
        // TODO: Implementar para plataformas móviles/desktop
        throw UnimplementedError('Exportar en plataformas nativas aún no implementado');
      }
    } catch (e) {
      throw Exception('Error al exportar notas: $e');
    }
  }

  /// Exportar notas a Markdown (un archivo por nota)
  static Future<void> exportToMarkdown(List<Map<String, dynamic>> notes) async {
    try {
      for (final note in notes) {
        final title = note['title']?.toString() ?? 'sin_titulo';
        final content = note['content']?.toString() ?? '';
        final tags = (note['tags'] as List?)?.join(', ') ?? '';
        final createdAt = note['createdAt']?.toString() ?? '';

        final markdown = '''
# $title

**Fecha:** $createdAt
${tags.isNotEmpty ? '**Etiquetas:** $tags' : ''}

---

$content
''';

        final safeTitle = _sanitizeFilename(title);
        if (kIsWeb) {
          _downloadFileWeb(markdown, '$safeTitle.md', 'text/markdown');
        } else {
          // TODO: Implementar para plataformas móviles/desktop
          throw UnimplementedError('Exportar Markdown en plataformas nativas aún no implementado');
        }
      }
    } catch (e) {
      throw Exception('Error al exportar a Markdown: $e');
    }
  }

  /// Exportar una sola nota a Markdown
  static Future<void> exportSingleNoteToMarkdown(Map<String, dynamic> note) async {
    try {
      final title = note['title']?.toString() ?? 'sin_titulo';
      final content = note['content']?.toString() ?? '';
      final tags = (note['tags'] as List?)?.join(', ') ?? '';
      final createdAt = note['createdAt']?.toString() ?? '';

      final markdown = '''
# $title

**Fecha:** $createdAt
${tags.isNotEmpty ? '**Etiquetas:** $tags' : ''}

---

$content
''';

      final safeTitle = _sanitizeFilename(title);
      if (kIsWeb) {
        _downloadFileWeb(markdown, '$safeTitle.md', 'text/markdown');
      } else {
        throw UnimplementedError('Exportar Markdown en plataformas nativas aún no implementado');
      }
    } catch (e) {
      throw Exception('Error al exportar nota: $e');
    }
  }

  /// Importar notas desde JSON
  static Future<List<Map<String, dynamic>>> importFromJson(String jsonString) async {
    try {
      final decoded = jsonDecode(jsonString);
      
      if (decoded is Map && decoded.containsKey('notes')) {
        final notes = decoded['notes'] as List;
        return notes.cast<Map<String, dynamic>>();
      } else if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Formato de archivo JSON no válido');
      }
    } catch (e) {
      throw Exception('Error al importar notas: $e');
    }
  }

  /// Descargar archivo en web
  static void _downloadFileWeb(String content, String filename, String mimeType) {
    final bytes = utf8.encode(content);
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  /// Sanitizar nombre de archivo
  static String _sanitizeFilename(String filename) {
    return filename
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .substring(0, filename.length > 50 ? 50 : filename.length);
  }

  /// Crear backup automático de todas las notas
  static Future<void> createAutoBackup(List<Map<String, dynamic>> notes) async {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
    await exportToJson(notes, filename: 'notas_backup_$timestamp');
  }

  /// Obtener estadísticas de las notas
  static Map<String, dynamic> getNotesStatistics(List<Map<String, dynamic>> notes) {
    final totalNotes = notes.length;
    final totalTags = <String>{};
    var totalWords = 0;
    var totalCharacters = 0;
    final pinnedNotes = notes.where((n) => n['pinned'] == true).length;

    for (final note in notes) {
      final content = note['content']?.toString() ?? '';
      final tags = note['tags'] as List?;
      
      if (tags != null) {
        totalTags.addAll(tags.cast<String>());
      }
      
      totalWords += content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      totalCharacters += content.length;
    }

    return {
      'totalNotes': totalNotes,
      'totalTags': totalTags.length,
      'uniqueTags': totalTags.toList(),
      'totalWords': totalWords,
      'totalCharacters': totalCharacters,
      'pinnedNotes': pinnedNotes,
      'averageWordsPerNote': totalNotes > 0 ? (totalWords / totalNotes).round() : 0,
    };
  }
}
