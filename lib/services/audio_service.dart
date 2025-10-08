import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';
import 'storage_service.dart';

class AudioService {
  static final _rec = AudioRecorder(); // Usar AudioRecorder en vez de Record

  /// Starts recording to a temporary file and returns the path when started.
  static Future<String?> startRecording() async {
    final has = await _rec.hasPermission();
    if (!has) return null;
    final tmp = Directory.systemTemp;
    final filename = 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final path = p.join(tmp.path, filename);
    
    // Nueva API de record 5.x
    await _rec.start(
      RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
      ),
      path: path,
    );
    return path;
  }

  /// Stops recording and uploads to storage, returns download URL or null
  static Future<String?> stopAndUpload({required String uid}) async {
    try {
      final path = await _rec.stop();
      if (path == null) return null;
      final file = File(path);
      final bytes = await file.readAsBytes();
      final url = await StorageService.uploadBytes(uid: uid, bytes: bytes, filename: p.basename(path), contentType: 'audio/m4a');
      return url;
    } catch (e) {
      return null;
    }
  }

  /// Stops recording and discards the file if possible.
  static Future<void> stopRecordingAndDiscard() async {
    try {
      final path = await _rec.stop();
      if (path == null) return;
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // ignore
    }
  }

  /// Whether the service can discard recordings (true on platforms with file access)
  static bool get supportsDiscard => true;
}
