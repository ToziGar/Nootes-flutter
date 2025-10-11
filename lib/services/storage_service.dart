import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart' as fs;
import 'package:file_picker/file_picker.dart';

class StorageService {
  static Future<String> uploadBytes({
    required String uid,
    required Uint8List bytes,
    required String filename,
    String contentType = 'application/octet-stream',
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final safeName = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = 'users/$uid/assets/$ts-$safeName';
    final ref = fs.FirebaseStorage.instance.ref().child(path);
    final meta = fs.SettableMetadata(contentType: contentType);
    await ref.putData(bytes, meta);
    return ref.getDownloadURL();
  }

  static Future<String?> pickAndUploadImage({required String uid}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.single;
    if (file == null || file.bytes == null) return null;
    final ct = file.extension != null && file.extension!.toLowerCase() == 'png'
        ? 'image/png'
        : 'image/jpeg';
    return uploadBytes(
      uid: uid,
      bytes: file.bytes!,
      filename: file.name,
      contentType: ct,
    );
  }

  static Future<String?> pickAndUploadFile({required String uid}) async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    final file = result?.files.single;
    if (file == null || file.bytes == null) return null;
    final ct = 'application/octet-stream';
    return uploadBytes(
      uid: uid,
      bytes: file.bytes!,
      filename: file.name,
      contentType: ct,
    );
  }
}
