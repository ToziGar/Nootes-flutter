import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/widgets/smart_tag_suggestions.dart';

void main() {
  group('SmartTagSuggestions Widget', () {
    testWidgets('shows and hides suggestions with toggle', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SmartTagSuggestions(
          title: 'Test',
          content: 'Content',
          currentTags: [],
          onTagSelected: (_) {},
        ),
      ));
      expect(find.text('Etiquetas sugeridas'), findsOneWidget);
      await tester.tap(find.byTooltip('Ocultar sugerencias'));
      await tester.pumpAndSettle();
      expect(find.text('Mostrar etiquetas sugeridas'), findsOneWidget);
      await tester.tap(find.text('Mostrar etiquetas sugeridas'));
      await tester.pumpAndSettle();
      expect(find.text('Etiquetas sugeridas'), findsOneWidget);
    });

    testWidgets('calls onTagSelected for each tag with Agregar todas', (tester) async {
      final selected = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: SmartTagSuggestions(
          title: 'Test',
          content: 'email test #tag',
          currentTags: [],
          onTagSelected: (tag) => selected.add(tag),
        ),
      ));
      await tester.pumpAndSettle();
      // Wait for debounce and suggestions
      await tester.pump(const Duration(milliseconds: 400));
      final addAllBtn = find.text('Agregar todas');
      expect(addAllBtn, findsOneWidget);
      await tester.tap(addAllBtn);
      await tester.pumpAndSettle();
      // Should have added all suggestions
      expect(selected.length, greaterThan(1));
    });

    testWidgets('calls onTagSelected for single tag', (tester) async {
      String? selected;
      await tester.pumpWidget(MaterialApp(
        home: SmartTagSuggestions(
          title: 'Test',
          content: 'email test #tag',
          currentTags: [],
          onTagSelected: (tag) => selected = tag,
        ),
      ));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      final chip = find.byType(ActionChip).first;
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(selected, isNotNull);
    });
  });
}
