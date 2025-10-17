import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:nootes/editor/markdown_editor.dart';

void main() {
  testWidgets('SaveIntent triggers onAutoSave', (tester) async {
    final controller = TextEditingController(text: 'initial');
    String? saved;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MarkdownEditor(
          controller: controller,
          autoSaveInterval: const Duration(seconds: 10), // long so debounce won't fire
          onAutoSave: (s) {
            saved = s;
          },
        ),
      ),
    ));

  // Ensure widget is built and focused
  await tester.pumpAndSettle();
  await tester.tap(find.byType(TextField));
  await tester.pump();

  // Send Ctrl+S (simulate on Windows) using key down/up
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.keyS);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.keyS);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

  // Allow actions to run
  await tester.pumpAndSettle();

  expect(saved, equals('initial'));
  });
}
