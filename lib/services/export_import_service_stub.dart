/// Stub para soporte multiplataforma de export/import
class PlatformExportImport {
  static void downloadFile(dynamic content, String filename, String mimeType) {
    throw UnsupportedError('No se puede descargar archivos en esta plataforma');
  }
  
  static Future<String?> pickAndReadFile() async {
    throw UnsupportedError('No se puede seleccionar archivos en esta plataforma');
  }
}
