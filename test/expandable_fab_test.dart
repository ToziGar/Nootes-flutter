import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nootes/widgets/expandable_fab.dart';

void main() {
  testWidgets('ExpandableFab shows actions when tapped', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        floatingActionButton: ExpandableFab(actions: [
          FloatingActionButton.small(onPressed: () {}, child: const Icon(Icons.add)),
          FloatingActionButton.small(onPressed: () {}, child: const Icon(Icons.photo)),
        ]),
      ),
    ));

    // Initial: FABs for actions are present in the tree (they animate scale)
    expect(find.byType(FloatingActionButton), findsNWidgets(3));

    // Tap the main FAB to expand (main FAB is the last FloatingActionButton in the stack)
    final fabs = find.byType(FloatingActionButton);
    await tester.tap(fabs.last);
    await tester.pumpAndSettle();

    // When expanded, the background dismiss Container (color black26) is present
    expect(
      find.byWidgetPredicate((w) => w is Container && w.decoration == null && (w.color == Colors.black26)),
      findsOneWidget,
    );
  });
}
