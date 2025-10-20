import 'package:nootes/services/firestore_service.dart';
import 'package:nootes/services/advanced_sharing_service.dart';
import 'package:nootes/utils/debug.dart';

/// Test helper: update a user's note to the given version content.
Future<bool> restoreVersionDataForUid({
  required String uid,
  required String noteId,
  required NoteVersion version,
  String? restoredFromVersionId,
}) async {
  try {
    await FirestoreService.instance.updateNote(
      uid: uid,
      noteId: noteId,
      data: {
        'title': version.title,
        'content': version.content,
      },
    );
    return true;
  } catch (e) {
    logDebug('❌ Error in restoreVersionDataForUid helper: $e');
    return false;
  }
}
