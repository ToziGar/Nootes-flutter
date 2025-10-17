import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:nootes/widgets/enhanced_note_editor.dart';

void main() {
  testWidgets('EnhancedNoteEditor autosave via SaveIntent updates UI and calls onSave', (tester) async {
    var saved = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EnhancedNoteEditor(
          uid: 'test-uid',
          initialTitle: 'T',
          initialContent: 'C',
          mode: EditorMode.markdown,
          onSave: () {
            saved = true;
          },
        ),
      ),
    ));

    await tester.pumpAndSettle();

    // Focus the inner text field
    await tester.tap(find.byType(TextField).first);
    await tester.pump();

    // Send Ctrl+S
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

    await tester.pumpAndSettle();

    expect(saved, isTrue);

    // The status bar should show a Guardado timestamp after autosave runs
    expect(find.textContaining('Guardado'), findsOneWidget);
  });
}
