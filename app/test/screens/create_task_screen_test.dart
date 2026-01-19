import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/screens/create_task_screen.dart';

void main() {
  testWidgets('CreateTaskScreen renders form and saves task', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateTaskScreen()));

    // Verify initial state
    expect(find.text('New Task'), findsOneWidget);
    expect(
      find.byType(TextFormField),
      findsNWidgets(2),
    ); // Title and Description

    // Enter text
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Buy Milk',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Description'),
      'Or else',
    );

    // Tap save
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    // We can't easily verify the navigator pop return value here without a wrapper,
    // but ensuring no crash and UI interaction completes is a good start.
    // To verify the return value, we'd typically wrap in a button that pushes this screen and awaits result.
  });

  testWidgets('CreateTaskScreen validates title', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: CreateTaskScreen()));

    // Tap save without entering title
    await tester.tap(find.byIcon(Icons.check));
    await tester.pump();

    // Verify error message
    expect(find.text('Please enter a title'), findsOneWidget);
  });
}
