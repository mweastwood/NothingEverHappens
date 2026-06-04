import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/screens/help_screen.dart';
import 'package:nothing_ever_happens/widgets/fun_check_button.dart';
import 'package:nothing_ever_happens/widgets/fun_delete_button.dart';
import '../test_helper.dart';

void main() {
  Widget buildTestWidget() {
    return buildTestableWidget(child: const HelpScreen());
  }

  testWidgets('HelpScreen displays all tabs and navigates correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Verify all tab labels are visible
    expect(find.text('General'), findsOneWidget);
    expect(find.text('Schedules'), findsOneWidget);
    expect(find.text('Interactions'), findsOneWidget);
    expect(find.text('Missed Policies'), findsOneWidget);

    // Initial tab is General: Verify description text
    expect(find.textContaining('Personal Tasks'), findsOneWidget);

    // Navigate to Schedules tab
    await tester.tap(find.text('Schedules'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Recurring schedules'), findsOneWidget);

    // Navigate to Interactions tab
    await tester.tap(find.text('Interactions'));
    await tester.pumpAndSettle();
    expect(find.text('Water the Houseplants'), findsOneWidget);
    expect(find.text('Clean the Attic Chores'), findsOneWidget);

    // Navigate to Missed Policies tab
    await tester.tap(find.text('Missed Policies'));
    await tester.pumpAndSettle();
    expect(find.text('Interactive Simulator'), findsOneWidget);
  });

  testWidgets('Interactions Tab check and delete buttons work', (
    WidgetTester tester,
  ) async {
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

  testWidgets('Missed Policy Simulator handles Rollover policy correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Navigate to Missed Policies tab
    await tester.tap(find.text('Missed Policies'));
    await tester.pumpAndSettle();

    // Default policy is Rollover. Verify simulator starting state
    expect(find.text('Policy: ROLLOVER'), findsOneWidget);
    expect(find.text('Mow the Lawn'), findsOneWidget);
    expect(find.text('Scheduled: Monday'), findsOneWidget);
    expect(find.text('OVERDUE'), findsOneWidget);

    // Tap check button inside simulator to complete late
    final checkButton = find.descendant(
      of: find.byType(ListTile),
      matching: find.byType(FunCheckButton),
    );
    expect(checkButton, findsOneWidget);
    await tester.ensureVisible(checkButton);
    await tester.pumpAndSettle();
    await tester.tap(checkButton);
    await tester.pumpAndSettle();

    // Verify task is rescheduled to Tuesday (next occurrence day after scheduled Monday)
    expect(find.text('Scheduled: Tuesday'), findsOneWidget);
    expect(
      find.text('ACTIVE'),
      findsOneWidget,
    ); // Scheduled: Tuesday, Current Day: Tuesday -> Active, not Overdue
    expect(
      find.textContaining('Completed task "Mow the Lawn"'),
      findsOneWidget,
    );
  });

  testWidgets('Missed Policy Simulator handles Skip policy correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Navigate to Missed Policies tab
    await tester.tap(find.text('Missed Policies'));
    await tester.pumpAndSettle();

    // Switch policy to Skip
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    // Verify simulator state has updated to Skip
    expect(find.text('Policy: SKIP'), findsOneWidget);
    expect(find.text('Scheduled: Monday'), findsOneWidget);

    // Auto-Skip button should be visible
    final autoSkipButton = find.text('Run Auto-Skip Check');
    expect(autoSkipButton, findsOneWidget);
    await tester.ensureVisible(autoSkipButton);
    await tester.pumpAndSettle();

    // Tap the skip check button
    await tester.tap(autoSkipButton);
    await tester.pumpAndSettle();

    // Verify skipped in logs, rescheduled to Tuesday
    expect(find.text('Scheduled: Tuesday'), findsOneWidget);
    expect(
      find.textContaining('automatically SKIPPED overdue task'),
      findsOneWidget,
    );
  });

  testWidgets('Missed Policy Simulator handles Shift policy correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Navigate to Missed Policies tab
    await tester.tap(find.text('Missed Policies'));
    await tester.pumpAndSettle();

    // Switch policy to Shift
    await tester.tap(find.text('Shift'));
    await tester.pumpAndSettle();

    // Verify starting state
    expect(find.text('Policy: SHIFT'), findsOneWidget);
    expect(find.text('Scheduled: Monday'), findsOneWidget);

    // Tap check button to complete task on Tuesday
    final checkButton = find.descendant(
      of: find.byType(ListTile),
      matching: find.byType(FunCheckButton),
    );
    await tester.ensureVisible(checkButton);
    await tester.pumpAndSettle();
    await tester.tap(checkButton);
    await tester.pumpAndSettle();

    // Task should be rescheduled to Wednesday (next occurrence after Today/Tuesday)
    expect(find.text('Scheduled: Wednesday'), findsOneWidget);
    expect(
      find.textContaining('Completed task "Mow the Lawn"'),
      findsOneWidget,
    );
  });

  testWidgets('Missed Policy Simulator handles Stack policy correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Navigate to Missed Policies tab
    await tester.tap(find.text('Missed Policies'));
    await tester.pumpAndSettle();

    // Switch policy to Stack
    await tester.tap(find.text('Stack'));
    await tester.pumpAndSettle();

    // Verify master task shown, no spawned task cards yet
    expect(find.text('Policy: STACK'), findsOneWidget);
    expect(find.textContaining('Master Task Schedule'), findsOneWidget);
    expect(find.text('MASTER'), findsOneWidget);
    expect(find.byType(FunCheckButton), findsNothing);

    // Tap Run Stack Spawning Check
    final stackSpawningCheck = find.text('Run Stack Spawning Check');
    await tester.ensureVisible(stackSpawningCheck);
    await tester.pumpAndSettle();
    await tester.tap(stackSpawningCheck);
    await tester.pumpAndSettle();

    // We should see three spawned tasks (Mon, Tue, Wed) and the master
    expect(find.text('Mow the Lawn (Mon)'), findsOneWidget);
    expect(find.text('Mow the Lawn (Tue)'), findsOneWidget);
    expect(find.text('Mow the Lawn (Wed)'), findsOneWidget);
    expect(find.textContaining('Last Spawn: Wednesday'), findsOneWidget);

    // Verify we have check buttons for the spawned cards
    expect(find.byType(FunCheckButton), findsNWidgets(3));
  });

  testGoldens('HelpScreen renders correctly', (WidgetTester tester) async {
    await tester.pumpWidgetBuilder(
      const HelpScreen(),
      wrapper: l10nMaterialAppWrapper(),
      surfaceSize: const Size(400, 800),
    );
    await screenMatchesGolden(tester, 'help_screen_general_tab');

    // Tap Schedules tab
    await tester.tap(find.text('Schedules'));
    await tester.pumpAndSettle();
    await screenMatchesGolden(tester, 'help_screen_general_schedules');
  });
}
