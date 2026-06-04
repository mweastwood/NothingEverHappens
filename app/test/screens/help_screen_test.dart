import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/screens/help_screen.dart';
import 'package:nothing_ever_happens/widgets/fun_check_button.dart';
import 'package:nothing_ever_happens/widgets/fun_delete_button.dart';
import '../test_helper.dart';

void main() {
  Widget buildTestWidget() {
    return buildTestableWidget(child: const HelpScreen());
  }

  testWidgets('HelpScreen displays tabs and navigates correctly', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Verify tab labels are visible
    expect(find.text('Schedules'), findsOneWidget);
    expect(find.text('Interactions'), findsOneWidget);

    // Initial tab is Schedules: Verify text details
    expect(find.textContaining('Recurring schedules'), findsOneWidget);

    // Navigate to Interactions tab
    await tester.tap(find.text('Interactions'));
    await tester.pumpAndSettle();
    expect(find.text('Water the Houseplants'), findsOneWidget);
    expect(find.text('Clean the Attic Chores'), findsOneWidget);
  });

  testWidgets('Interactions Tab check and delete buttons work', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Navigate to Interactions tab
    await tester.tap(find.text('Interactions'));
    await tester.pumpAndSettle();

    // Verify initial check button state
    expect(find.text('Task Status: Active ⭕'), findsOneWidget);

    // Tap the FunCheckButton
    await tester.tap(find.byType(FunCheckButton));
    await tester.pumpAndSettle();

    // Verify check button toggled
    expect(find.textContaining('Task Status: Completed!'), findsOneWidget);

    // Verify delete button is visible
    expect(find.text('Clean the Attic Chores'), findsOneWidget);

    // Tap the FunDeleteButton
    await tester.tap(find.byType(FunDeleteButton));
    // Pump and wait for the delete delay (350ms in code + some extra time)
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Verify task is deleted and restore button is shown
    expect(find.text('Clean the Attic Chores'), findsNothing);
    expect(find.text('Restore Task'), findsOneWidget);

    // Tap Restore Task
    await tester.tap(find.text('Restore Task'));
    await tester.pumpAndSettle();

    // Verify task card restored
    expect(find.text('Clean the Attic Chores'), findsOneWidget);
  });
}
