import 'package:nootes/domain/note.dart';
import 'package:nootes/data/note_repository.dart';

// Lightweight scaffold for an Isar-backed NoteRepository.
// This avoids requiring Isar codegen in this iteration: it will try to use
// a real Isar instance when available; otherwise it will fall back to the
// existing InMemoryNoteRepository. Later we can replace the fallback with
// a full Isar implementation and generated collections.
class IsarNoteRepository implements NoteRepository {
  final InMemoryNoteRepository _fallback = InMemoryNoteRepository();

  @override
  Future<void> init() async {
    // TODO: initialize Isar here (requires codegen). For now, we just
    // initialize the in-memory fallback so tests and the app can proceed.
    await _fallback.init();
  }

  @override
  Future<void> deleteNote(String id) async {
    // TODO: implement Isar delete when Isar is integrated.
    await _fallback.deleteNote(id);
  }

  @override
  Future<Note?> getNote(String id) async {
    // TODO: implement Isar read when Isar is integrated.
    return await _fallback.getNote(id);
  }

  @override
  Future<List<Note>> listNotes() async {
    // TODO: implement Isar query when Isar is integrated.
    return await _fallback.listNotes();
  }

  @override
  Future<void> saveNote(Note note) async {
    // TODO: implement Isar write when Isar is integrated.
    await _fallback.saveNote(note);
  }
}
