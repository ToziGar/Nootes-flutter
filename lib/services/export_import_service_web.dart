// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
// Implementación web de export/import usando dart:html (legacy). Migrar a package:web cuando sea necesario.
import 'dart:html' as html;

class PlatformExportImport {
  static void downloadFile(dynamic content, String filename, String mimeType) {
    final bytes = content is String ? content : content as List<int>;
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  static Future<String?> pickAndReadFile() async {
    final uploadInput = html.FileUploadInputElement()..accept = '.json';
    uploadInput.click();

    await uploadInput.onChange.first;
    final file = uploadInput.files?.first;
    if (file == null) return null;

    final reader = html.FileReader();
    reader.readAsText(file);
    await reader.onLoad.first;

    return reader.result as String?;
  }
}
