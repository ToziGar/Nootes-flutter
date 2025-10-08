/// Implementación IO de export/import para desktop/mobile
class PlatformExportImport {
  static void downloadFile(dynamic content, String filename, String mimeType) {
    // En desktop/mobile necesitarías usar file_picker o similar
    throw UnimplementedError('Usar file_picker para guardar archivos en desktop/mobile');
  }
  
  static Future<String?> pickAndReadFile() async {
    // En desktop/mobile necesitarías usar file_picker
    throw UnimplementedError('Usar file_picker para leer archivos en desktop/mobile');
  }
}
