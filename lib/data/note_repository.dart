import 'package:nootes/domain/note.dart';

abstract class NoteRepository {
  Future<void> init();
  Future<List<Note>> listNotes();
  Future<Note?> getNote(String id);
  Future<void> saveNote(Note note);
  Future<void> deleteNote(String id);
}

class InMemoryNoteRepository implements NoteRepository {
  final Map<String, Note> _store = {};

  @override
  Future<void> init() async {}

  @override
  Future<void> deleteNote(String id) async {
    _store.remove(id);
  }

  @override
  Future<Note?> getNote(String id) async {
    return _store[id];
  }

  @override
  Future<List<Note>> listNotes() async {
    return _store.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<void> saveNote(Note note) async {
    note.updatedAt = DateTime.now().toUtc();
    _store[note.id] = note;
  }
}
