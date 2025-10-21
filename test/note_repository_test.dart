import 'package:flutter_test/flutter_test.dart';
import 'package:nootes/data/note_repository.dart';
import 'package:nootes/domain/note.dart';

void main() {
  test('InMemoryNoteRepository CRUD', () async {
    final repo = InMemoryNoteRepository();
    await repo.init();

    final n1 = Note(id: '1', title: 'First', content: 'Hello');
    final n2 = Note(id: '2', title: 'Second', content: 'World');

    await repo.saveNote(n1);
    await repo.saveNote(n2);

    final list = await repo.listNotes();
    expect(list.length, 2);

    final first = await repo.getNote('1');
    expect(first?.title, 'First');

    n1.content = 'Updated';
    await repo.saveNote(n1);
    final updated = await repo.getNote('1');
    expect(updated?.content, 'Updated');

    await repo.deleteNote('2');
    final afterDelete = await repo.listNotes();
    expect(afterDelete.length, 1);
  });
}
