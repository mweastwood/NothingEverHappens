import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/screens/help_screen.dart';
import 'package:nothing_ever_happens/widgets/basic_task_completion_tab.dart';
import 'package:nothing_ever_happens/widgets/scheduling_playground_tab.dart';
import 'package:nothing_ever_happens/widgets/one_off_scheduling_widget.dart';
import 'package:nothing_ever_happens/widgets/daily_scheduling_widget.dart';
import 'package:nothing_ever_happens/widgets/weekly_scheduling_widget.dart';
import 'package:nothing_ever_happens/widgets/monthly_scheduling_widget.dart';
import 'package:nothing_ever_happens/widgets/yearly_scheduling_widget.dart';
import 'package:nothing_ever_happens/widgets/fun_check_button.dart';
import 'package:nothing_ever_happens/widgets/task_widget.dart';
import '../test_helper.dart';

void main() {
  Widget buildTestWidget(Widget child) {
    return buildTestableWidget(child: child);
  }

  void setLargeScreenSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('BasicTaskCompletionTab Standalone Tests', () {
    testWidgets(
      'renders explanatory text and 10 tasks initially without edit buttons',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestWidget(const BasicTaskCompletionTab()),
        );
        await tester.pumpAndSettle();

        // Check for explanatory card contents
        expect(
          find.textContaining('Practice Basic Task Completion'),
          findsOneWidget,
        );
        expect(
          find.textContaining('There are two ways to complete a task:'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Tapping the checkbox on the left'),
          findsOneWidget,
        );

        // Check for 10 initial tasks remaining text
        expect(find.text('Practice Tasks (10 remaining)'), findsOneWidget);

        // Verify task widgets (all 10 are in tree)
        expect(find.byType(TaskWidget), findsNWidgets(10));
        expect(find.text('Water the Houseplants'), findsOneWidget);
        expect(find.text('Take out the Trash'), findsOneWidget);
        expect(find.text('Buy Groceries'), findsOneWidget);

        // Verify no edit pencil buttons are visible
        expect(find.byIcon(Icons.edit), findsNothing);
        expect(find.byKey(const Key('edit_pencil_button')), findsNothing);
      },
    );

    testWidgets('completing a task removes the task card', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(const BasicTaskCompletionTab()));
      await tester.pumpAndSettle();

      // Find first check button
      final checkButton = find.byType(FunCheckButton).first;
      expect(checkButton, findsOneWidget);

      // Tap it
      await tester.tap(checkButton);
      await tester.pump();
      // Wait for confetti animation delay (500ms) + collapse duration (200ms)
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // Verify task is removed
      expect(find.text('Water the Houseplants'), findsNothing);
      expect(find.byType(TaskWidget), findsNWidgets(9));
      expect(find.text('Practice Tasks (9 remaining)'), findsOneWidget);
    });

    testWidgets('dismissing a task removes the task card', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(const BasicTaskCompletionTab()));
      await tester.pumpAndSettle();

      // Find first delete button (trailing)
      final deleteButton = find.byKey(const Key('delete_task_button')).first;
      expect(deleteButton, findsOneWidget);

      // Tap it
      await tester.tap(deleteButton);
      await tester.pump();
      // Wait for delete animation delay (400ms) + collapse duration (200ms)
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // Verify task is removed
      expect(find.text('Water the Houseplants'), findsNothing);
      expect(find.byType(TaskWidget), findsNWidgets(9));
      expect(find.text('Practice Tasks (9 remaining)'), findsOneWidget);
    });

    testWidgets('reset practice button restores all 10 tasks', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(const BasicTaskCompletionTab()));
      await tester.pumpAndSettle();

      // Complete first task
      await tester.tap(find.byType(FunCheckButton).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // Dismiss second task (which is now first in list: "Take out the Trash")
      await tester.tap(find.byKey(const Key('delete_task_button')).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // Verify remaining tasks is 8
      expect(find.text('Practice Tasks (8 remaining)'), findsOneWidget);

      // Tap Reset Practice button
      await tester.tap(find.text('Reset Practice'));
      await tester.pumpAndSettle();

      // Verify reset to initial state
      expect(find.text('Practice Tasks (10 remaining)'), findsOneWidget);
      expect(find.byType(TaskWidget), findsNWidgets(10));
    });

    testGoldens('BasicTaskCompletionTab renders correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidgetBuilder(
        const BasicTaskCompletionTab(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(400, 800),
      );
      await screenMatchesGolden(tester, 'basic_task_completion_tab_golden');
    });
  });

  group('SchedulingPlaygroundTab Standalone Tests', () {
    testWidgets('renders markdown helper and segmented buttons', (
      WidgetTester tester,
    ) async {
      setLargeScreenSize(tester);
      await tester.pumpWidget(buildTestWidget(const SchedulingPlaygroundTab()));
      await tester.pumpAndSettle();

      // Explanatory markdown
      expect(find.textContaining('Practice Task Scheduling'), findsOneWidget);
      expect(find.textContaining('calendar grid'), findsOneWidget);

      // Segmented buttons
      expect(find.text('One-off'), findsOneWidget);
      expect(find.text('Daily'), findsOneWidget);
      expect(find.text('Weekly'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('Yearly'), findsOneWidget);

      // Default should show OneOffSchedulingWidget
      expect(find.byType(OneOffSchedulingWidget), findsOneWidget);
    });

    testWidgets('switching recurrence type displays corresponding widget', (
      WidgetTester tester,
    ) async {
      setLargeScreenSize(tester);
      await tester.pumpWidget(buildTestWidget(const SchedulingPlaygroundTab()));
      await tester.pumpAndSettle();

      // Switch to Daily
      await tester.tap(find.text('Daily'));
      await tester.pumpAndSettle();
      expect(find.byType(DailySchedulingWidget), findsOneWidget);

      // Switch to Weekly
      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();
      expect(find.byType(WeeklySchedulingWidget), findsOneWidget);

      // Switch to Monthly
      await tester.tap(find.text('Monthly'));
      await tester.pumpAndSettle();
      expect(find.byType(MonthlySchedulingWidget), findsOneWidget);

      // Switch to Yearly
      await tester.tap(find.text('Yearly'));
      await tester.pumpAndSettle();
      expect(find.byType(YearlySchedulingWidget), findsOneWidget);
    });

    testWidgets('shows validation error when interval is empty or 0', (
      WidgetTester tester,
    ) async {
      setLargeScreenSize(tester);
      await tester.pumpWidget(buildTestWidget(const SchedulingPlaygroundTab()));
      await tester.pumpAndSettle();

      // Switch to Daily
      await tester.tap(find.text('Daily'));
      await tester.pumpAndSettle();

      // Empty interval
      final intervalField = find.widgetWithText(TextFormField, 'Days Interval');
      expect(intervalField, findsOneWidget);

      await tester.enterText(intervalField, '');
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Please enter a valid interval'),
        findsOneWidget,
      );

      // Zero interval
      await tester.enterText(intervalField, '0');
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Please enter a valid interval'),
        findsOneWidget,
      );

      // Valid interval
      await tester.enterText(intervalField, '2');
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Please enter a valid interval'),
        findsNothing,
      );
    });

    testWidgets('calculates and shows correct number of occurrences', (
      WidgetTester tester,
    ) async {
      setLargeScreenSize(tester);
      await tester.pumpWidget(buildTestWidget(const SchedulingPlaygroundTab()));
      await tester.pumpAndSettle();

      // Switch to Daily
      await tester.tap(find.text('Daily'));
      await tester.pumpAndSettle();

      // Verify next 10 occurrences header
      expect(find.text('Next 10 Occurrences'), findsOneWidget);

      // There should be cards representing occurrences (the playground lists the calculated occurrences in cards)
      expect(
        find.byType(Card),
        findsAtLeast(2),
      ); // instructions card, editor card, occurrence cards
    });

    testGoldens('SchedulingPlaygroundTab renders correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidgetBuilder(
        const SchedulingPlaygroundTab(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(500, 1000),
      );
      await screenMatchesGolden(tester, 'scheduling_playground_tab_golden');
    });
  });

  group('HelpScreen Integration Tests', () {
    testWidgets(
      'renders BasicTaskCompletionTab and supports switching to SchedulingPlaygroundTab',
      (WidgetTester tester) async {
        setLargeScreenSize(tester);
        await tester.pumpWidget(buildTestWidget(const HelpScreen()));
        await tester.pumpAndSettle();

        // Verify both tabs are visible in TabBar
        expect(find.text('Basic Task Completion'), findsOneWidget);
        expect(find.text('Task Scheduling'), findsOneWidget);

        // Initially renders BasicTaskCompletionTab
        expect(find.byType(BasicTaskCompletionTab), findsOneWidget);
        expect(find.byType(SchedulingPlaygroundTab), findsNothing);

        // Tap on "Task Scheduling" tab
        await tester.tap(find.text('Task Scheduling'));
        await tester.pumpAndSettle();

        // Verify it switches to SchedulingPlaygroundTab
        expect(find.byType(SchedulingPlaygroundTab), findsOneWidget);
        expect(find.byType(BasicTaskCompletionTab), findsNothing);
      },
    );

    testGoldens('HelpScreen renders correctly with basic tab selected', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidgetBuilder(
        const HelpScreen(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(450, 900),
      );
      await screenMatchesGolden(tester, 'help_screen_basic_task_completion');
    });

    testGoldens('HelpScreen renders correctly with scheduling tab selected', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidgetBuilder(
        const HelpScreen(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(450, 900),
      );

      // Tap on Task Scheduling tab to update its state before matching golden
      await tester.tap(find.text('Task Scheduling'));
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, 'help_screen_task_scheduling');
    });
  });
}
