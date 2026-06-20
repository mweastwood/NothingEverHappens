import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/screens/help_screen.dart';
import 'package:nothing_ever_happens/widgets/basic_task_completion_tab.dart';
import 'package:nothing_ever_happens/widgets/scheduling_playground_tab.dart';
import 'package:nothing_ever_happens/widgets/missed_policies_playground_tab.dart';
import 'package:nothing_ever_happens/widgets/one_off_scheduling_widget.dart';
import 'package:nothing_ever_happens/widgets/daily_scheduling_widget.dart';
import 'package:nothing_ever_happens/widgets/weekly_scheduling_widget.dart';
import 'package:nothing_ever_happens/widgets/monthly_scheduling_widget.dart';
import 'package:nothing_ever_happens/widgets/yearly_scheduling_widget.dart';
import 'package:nothing_ever_happens/widgets/fun_check_button.dart';
import 'package:nothing_ever_happens/widgets/task_widget.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import '../test_helper.dart';

void main() {
  setUp(() {
    AppClock.setMockTime(DateTime(2026, 6, 5));
  });

  tearDown(() {
    AppClock.reset();
  });

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

    testGoldens('BasicTaskCompletionTab shows snackbar golden', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidgetBuilder(
        const BasicTaskCompletionTab(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(400, 800),
      );

      // Complete the first task
      await tester.tap(find.byType(FunCheckButton).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      await screenMatchesGolden(
        tester,
        'basic_task_completion_tab_with_snackbar',
      );
    });

    testWidgets('tapping Undo after completing a task restores the task card', (
      WidgetTester tester,
    ) async {
      // Regression: FakeTaskRepository.undoResolveTaskInstance was a no-op,
      // so tapping Undo on the help screen did nothing visually.
      await tester.pumpWidget(buildTestWidget(const BasicTaskCompletionTab()));
      await tester.pumpAndSettle();

      expect(find.text('Practice Tasks (10 remaining)'), findsOneWidget);

      // Complete the first task
      await tester.tap(find.byType(FunCheckButton).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // Task is now removed
      expect(find.text('Water the Houseplants'), findsNothing);
      expect(find.text('Practice Tasks (9 remaining)'), findsOneWidget);

      // Undo snackbar should be visible
      expect(find.text('Undo'), findsOneWidget);

      // Tap Undo
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      // Task should be restored at its original index (top of the list)
      expect(find.text('Water the Houseplants'), findsOneWidget);
      expect(find.text('Practice Tasks (10 remaining)'), findsOneWidget);
      final taskWidgets = tester
          .widgetList<TaskWidget>(find.byType(TaskWidget))
          .toList();
      expect(taskWidgets.first.instance.title, equals('Water the Houseplants'));
    });

    testWidgets(
      'tapping Undo after dismissing a task (delete button) restores the task card',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestWidget(const BasicTaskCompletionTab()),
        );
        await tester.pumpAndSettle();

        // Dismiss the first task via the delete button
        await tester.tap(find.byKey(const Key('delete_task_button')).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();

        expect(find.text('Water the Houseplants'), findsNothing);
        expect(find.text('Practice Tasks (9 remaining)'), findsOneWidget);

        // Tap Undo
        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();

        // Task should be restored at its original index (top of the list)
        expect(find.text('Water the Houseplants'), findsOneWidget);
        expect(find.text('Practice Tasks (10 remaining)'), findsOneWidget);
        final taskWidgets = tester
            .widgetList<TaskWidget>(find.byType(TaskWidget))
            .toList();
        expect(
          taskWidgets.first.instance.title,
          equals('Water the Houseplants'),
        );
      },
    );
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
      expect(find.text('Repeating'), findsOneWidget);
      expect(find.text('Daily'), findsNothing);

      // Default should show OneOffSchedulingWidget
      expect(find.byType(OneOffSchedulingWidget), findsOneWidget);

      // Tap Repeating to show repeating chips
      await tester.tap(find.text('Repeating'));
      await tester.pumpAndSettle();

      expect(find.text('Daily'), findsOneWidget);
      expect(find.text('Weekly'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('Yearly'), findsOneWidget);
    });

    testWidgets('switching recurrence type displays corresponding widget', (
      WidgetTester tester,
    ) async {
      setLargeScreenSize(tester);
      await tester.pumpWidget(buildTestWidget(const SchedulingPlaygroundTab()));
      await tester.pumpAndSettle();

      // Switch to Daily
      await tester.tap(find.text('Repeating'));
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
      await tester.tap(find.text('Repeating'));
      await tester.pumpAndSettle();

      // Expand the interval selection tile
      await tester.tap(find.byKey(const Key('daily_interval_expansion_tile')));
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
      await tester.tap(find.text('Repeating'));
      await tester.pumpAndSettle();

      // Verify next 10 occurrences header
      expect(find.text('Next 10 Occurrences'), findsOneWidget);

      // There should be cards representing occurrences (the playground lists the calculated occurrences in cards)
      expect(
        find.byType(Card),
        findsAtLeast(2),
      ); // instructions card, editor card, occurrence cards
    });

    testWidgets('shows detailed appears and due date/times for occurrences', (
      WidgetTester tester,
    ) async {
      setLargeScreenSize(tester);
      await tester.pumpWidget(buildTestWidget(const SchedulingPlaygroundTab()));
      await tester.pumpAndSettle();

      // Default is One-off. One-off card lists Appears and Due dates/times.
      expect(find.textContaining('Appears:'), findsOneWidget);
      // There are two "Due:" text widgets: one in the editor label ("Due: ") and one in the card ("Due: ...")
      expect(find.textContaining('Due'), findsNWidgets(2));

      // Let's switch to Daily
      await tester.tap(find.text('Repeating'));
      await tester.pumpAndSettle();

      // Verify that the daily recurrence list cards also display "Appears:" and "Due:"
      expect(find.textContaining('Appears:'), findsAtLeast(10));
      expect(find.textContaining('Due:'), findsAtLeast(10));
    });

    testWidgets(
      'renders visual range highlights on the calendar grid based on task dates',
      (WidgetTester tester) async {
        setLargeScreenSize(tester);
        await tester.pumpWidget(
          buildTestWidget(const SchedulingPlaygroundTab()),
        );
        await tester.pumpAndSettle();

        final now = AppClock.now;
        final todayKey = Key('day_${now.year}_${now.month}_${now.day}');

        // Initially, start and due date are both today (single-day range).
        // Verify today has a perfect circle background and an occurrence indicator.
        final todayContainers = tester.widgetList<Container>(
          find.descendant(
            of: find.byKey(todayKey),
            matching: find.byType(Container),
          ),
        );

        bool hasPerfectCircle = false;
        bool hasOccurrenceIndicator = false;
        for (final container in todayContainers) {
          final decoration = container.decoration;
          if (decoration is BoxDecoration) {
            if (decoration.shape == BoxShape.circle) {
              if (decoration.color == Colors.transparent ||
                  decoration.color == null) {
                hasOccurrenceIndicator = true;
              } else {
                hasPerfectCircle = true;
              }
            }
          }
        }
        expect(
          hasPerfectCircle,
          isTrue,
          reason: 'Today should have a perfect circle for single-day range',
        );
        expect(
          hasOccurrenceIndicator,
          isTrue,
          reason: 'Today should have an occurrence indicator',
        );

        // Now, change the due date to 3 days from now to create a 4-day range (today, today+1, today+2, today+3).
        // We will set this directly on the dueDateTime ValueNotifier from OneOffSchedulingWidget.
        final oneOffWidgetFinder = find.byType(OneOffSchedulingWidget);
        expect(oneOffWidgetFinder, findsOneWidget);
        final oneOffWidget = tester.widget<OneOffSchedulingWidget>(
          oneOffWidgetFinder,
        );

        final threeDaysLater = now.add(const Duration(days: 3));
        oneOffWidget.dueDateTime.value = threeDaysLater;
        await tester.pumpAndSettle();

        final day1 = now;
        final day2 = now.add(const Duration(days: 1));
        final day3 = now.add(const Duration(days: 2));
        final day4 = threeDaysLater;

        final key1 = Key('day_${day1.year}_${day1.month}_${day1.day}');
        final key2 = Key('day_${day2.year}_${day2.month}_${day2.day}');
        final key3 = Key('day_${day3.year}_${day3.month}_${day3.day}');
        final key4 = Key('day_${day4.year}_${day4.month}_${day4.day}');

        // Day 1: Start day (Left-rounded cap, no occurrence indicator)
        final containers1 = tester.widgetList<Container>(
          find.descendant(
            of: find.byKey(key1),
            matching: find.byType(Container),
          ),
        );
        bool hasLeftCap = false;
        bool hasOccurrence1 = false;
        for (final container in containers1) {
          final decoration = container.decoration;
          if (decoration is BoxDecoration) {
            final borderRadius = decoration.borderRadius;
            if (borderRadius is BorderRadius &&
                borderRadius.topLeft == const Radius.circular(14) &&
                borderRadius.bottomLeft == const Radius.circular(14)) {
              hasLeftCap = true;
            }
            if (decoration.shape == BoxShape.circle &&
                (decoration.color == Colors.transparent ||
                    decoration.color == null)) {
              hasOccurrence1 = true;
            }
          }
        }
        expect(
          hasLeftCap,
          isTrue,
          reason: 'Day 1 should have a left-rounded cap',
        );
        expect(
          hasOccurrence1,
          isFalse,
          reason: 'Day 1 should not have an occurrence indicator',
        );

        // Day 2: Middle day (Shaded background, no cap, no occurrence indicator)
        final containers2 = tester.widgetList<Container>(
          find.descendant(
            of: find.byKey(key2),
            matching: find.byType(Container),
          ),
        );
        bool hasShade2 = false;
        bool hasLeftCap2 = false;
        bool hasRightCap2 = false;
        for (final container in containers2) {
          final color = container.color;
          final decoration = container.decoration;
          if (color != null) {
            if (color.a > 0.0 && color.a < 0.2) {
              hasShade2 = true;
            }
          }
          if (decoration is BoxDecoration) {
            if (decoration.color != null &&
                decoration.color!.a > 0.0 &&
                decoration.color!.a < 0.2 &&
                decoration.borderRadius == null &&
                decoration.shape != BoxShape.circle) {
              hasShade2 = true;
            }
            final borderRadius = decoration.borderRadius;
            if (borderRadius is BorderRadius) {
              if (borderRadius.topLeft == const Radius.circular(14)) {
                hasLeftCap2 = true;
              }
              if (borderRadius.topRight == const Radius.circular(14)) {
                hasRightCap2 = true;
              }
            }
          }
        }
        expect(
          hasShade2,
          isTrue,
          reason: 'Day 2 should have a shaded background',
        );
        expect(
          hasLeftCap2,
          isFalse,
          reason: 'Day 2 should not have a left-rounded cap',
        );
        expect(
          hasRightCap2,
          isFalse,
          reason: 'Day 2 should not have a right-rounded cap',
        );

        // Day 3: Middle day (Shaded background, no cap, no occurrence indicator)
        final containers3 = tester.widgetList<Container>(
          find.descendant(
            of: find.byKey(key3),
            matching: find.byType(Container),
          ),
        );
        bool hasShade3 = false;
        for (final container in containers3) {
          final color = container.color;
          final decoration = container.decoration;
          if (color != null) {
            if (color.a > 0.0 && color.a < 0.2) {
              hasShade3 = true;
            }
          }
          if (decoration is BoxDecoration) {
            if (decoration.color != null &&
                decoration.color!.a > 0.0 &&
                decoration.color!.a < 0.2 &&
                decoration.borderRadius == null &&
                decoration.shape != BoxShape.circle) {
              hasShade3 = true;
            }
          }
        }
        expect(
          hasShade3,
          isTrue,
          reason: 'Day 3 should have a shaded background',
        );

        // Day 4: Due day (Right-rounded cap, occurrence indicator)
        final containers4 = tester.widgetList<Container>(
          find.descendant(
            of: find.byKey(key4),
            matching: find.byType(Container),
          ),
        );
        bool hasRightCap = false;
        bool hasOccurrence4 = false;
        for (final container in containers4) {
          final decoration = container.decoration;
          if (decoration is BoxDecoration) {
            final borderRadius = decoration.borderRadius;
            if (borderRadius is BorderRadius &&
                borderRadius.topRight == const Radius.circular(14) &&
                borderRadius.bottomRight == const Radius.circular(14)) {
              hasRightCap = true;
            }
            if (decoration.shape == BoxShape.circle &&
                (decoration.color == Colors.transparent ||
                    decoration.color == null)) {
              hasOccurrence4 = true;
            }
          }
        }
        expect(
          hasRightCap,
          isTrue,
          reason: 'Day 4 should have a right-rounded cap',
        );
        expect(
          hasOccurrence4,
          isTrue,
          reason: 'Day 4 should have an occurrence indicator',
        );
      },
    );

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

  group('MissedPoliciesPlaygroundTab Standalone Tests', () {
    testWidgets('renders initial simulator state correctly', (
      WidgetTester tester,
    ) async {
      setLargeScreenSize(tester);
      await tester.pumpWidget(
        buildTestWidget(const MissedPoliciesPlaygroundTab()),
      );
      await tester.pumpAndSettle();

      // Check intro text
      expect(find.textContaining('Missed Occurrence Policies'), findsOneWidget);

      // Check policy options
      expect(find.text('Rollover'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Shift Schedule'), findsOneWidget);
      expect(find.text('Stack/Overlap'), findsOneWidget);

      // Check Simulated Today starts at June 1
      expect(find.text('Simulated Today: June 1'), findsOneWidget);

      // Verify the task card is rendered
      expect(find.text('Water the Houseplants'), findsOneWidget);
      expect(find.text('Scheduled: June 1'), findsOneWidget);
    });

    testWidgets('rollover policy: advance and complete shifts correctly', (
      WidgetTester tester,
    ) async {
      setLargeScreenSize(tester);
      await tester.pumpWidget(
        buildTestWidget(const MissedPoliciesPlaygroundTab()),
      );
      await tester.pumpAndSettle();

      // Advance 1 day (should make June 1 task overdue on June 2)
      await tester.tap(find.text('Advance 1 Day'));
      await tester.pumpAndSettle();

      expect(find.text('Simulated Today: June 2'), findsOneWidget);
      expect(find.text('Scheduled: June 1 (Overdue)'), findsOneWidget);

      // Complete the task by tapping the check button
      await tester.ensureVisible(find.byType(FunCheckButton).first);
      await tester.tap(find.byType(FunCheckButton).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // In Rollover, it reschedules to June 2 (which is today/June 2, so it's active)
      expect(find.text('Scheduled: June 2'), findsOneWidget);
    });

    testWidgets('skip policy: auto-skips overdue tasks', (
      WidgetTester tester,
    ) async {
      setLargeScreenSize(tester);
      await tester.pumpWidget(
        buildTestWidget(const MissedPoliciesPlaygroundTab()),
      );
      await tester.pumpAndSettle();

      // Switch to Skip
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('Simulated Today: June 1'), findsOneWidget);

      // Advance 1 Day
      await tester.tap(find.text('Advance 1 Day'));
      await tester.pumpAndSettle();

      expect(find.text('Simulated Today: June 2'), findsOneWidget);
      // Under Skip, the June 1 task is auto-skipped, so the only active task should be scheduled for June 2 (active)
      expect(find.text('Scheduled: June 2'), findsOneWidget);
      expect(find.textContaining('(Overdue)'), findsNothing);
    });

    testWidgets('shift policy: reschedules relative to completion date', (
      WidgetTester tester,
    ) async {
      setLargeScreenSize(tester);
      await tester.pumpWidget(
        buildTestWidget(const MissedPoliciesPlaygroundTab()),
      );
      await tester.pumpAndSettle();

      // Switch to Shift
      await tester.tap(find.text('Shift Schedule'));
      await tester.pumpAndSettle();

      // Advance 1 day (June 2)
      await tester.tap(find.text('Advance 1 Day'));
      await tester.pumpAndSettle();

      // Complete task
      await tester.ensureVisible(find.byType(FunCheckButton).first);
      await tester.tap(find.byType(FunCheckButton).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // In Shift, completed on June 2 -> reschedules to June 3 (active)
      expect(find.text('Scheduled: June 3'), findsOneWidget);
    });

    testWidgets('stack policy: spawns concurrent instances', (
      WidgetTester tester,
    ) async {
      setLargeScreenSize(tester);
      await tester.pumpWidget(
        buildTestWidget(const MissedPoliciesPlaygroundTab()),
      );
      await tester.pumpAndSettle();

      // Switch to Stack
      await tester.tap(find.text('Stack/Overlap'));
      await tester.pumpAndSettle();

      // Advance 1 day (June 2) -> should spawn a task for June 2, keeping June 1 overdue
      await tester.tap(find.text('Advance 1 Day'));
      await tester.pumpAndSettle();

      expect(find.text('Simulated Today: June 2'), findsOneWidget);
      expect(find.text('Scheduled: June 1 (Overdue)'), findsOneWidget);
      expect(find.text('Scheduled: June 2'), findsOneWidget);

      // Complete the June 1 task
      await tester.ensureVisible(find.byType(FunCheckButton).first);
      await tester.tap(find.byType(FunCheckButton).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // Verify June 1 task is removed, leaving only June 2
      expect(find.text('Scheduled: June 1 (Overdue)'), findsNothing);
      expect(find.text('Scheduled: June 2'), findsOneWidget);
    });

    testGoldens('MissedPoliciesPlaygroundTab renders correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidgetBuilder(
        const MissedPoliciesPlaygroundTab(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(600, 1100),
      );
      await screenMatchesGolden(
        tester,
        'missed_policies_playground_tab_golden',
      );
    });
  });

  group('HelpScreen Integration Tests', () {
    testWidgets(
      'renders BasicTaskCompletionTab and supports switching to SchedulingPlaygroundTab and MissedPoliciesPlaygroundTab',
      (WidgetTester tester) async {
        setLargeScreenSize(tester);
        await tester.pumpWidget(buildTestWidget(const HelpScreen()));
        await tester.pumpAndSettle();

        // Verify tabs are visible in TabBar
        expect(find.text('Basic Task Completion'), findsOneWidget);
        expect(find.text('Task Scheduling'), findsOneWidget);
        expect(find.text('Missed Policies'), findsOneWidget);

        // Initially renders BasicTaskCompletionTab
        expect(find.byType(BasicTaskCompletionTab), findsOneWidget);
        expect(find.byType(SchedulingPlaygroundTab), findsNothing);
        expect(find.byType(MissedPoliciesPlaygroundTab), findsNothing);

        // Tap on "Task Scheduling" tab
        await tester.tap(find.text('Task Scheduling'));
        await tester.pumpAndSettle();

        // Verify it switches to SchedulingPlaygroundTab
        expect(find.byType(SchedulingPlaygroundTab), findsOneWidget);
        expect(find.byType(BasicTaskCompletionTab), findsNothing);
        expect(find.byType(MissedPoliciesPlaygroundTab), findsNothing);

        // Tap on "Missed Policies" tab
        await tester.tap(find.text('Missed Policies'));
        await tester.pumpAndSettle();

        // Verify it switches to MissedPoliciesPlaygroundTab
        expect(find.byType(MissedPoliciesPlaygroundTab), findsOneWidget);
        expect(find.byType(SchedulingPlaygroundTab), findsNothing);
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

    testGoldens(
      'HelpScreen renders correctly with missed policies tab selected',
      (WidgetTester tester) async {
        await tester.pumpWidgetBuilder(
          const HelpScreen(),
          wrapper: l10nMaterialAppWrapper(),
          surfaceSize: const Size(600, 1100),
        );

        // Tap on Missed Policies tab
        await tester.tap(find.text('Missed Policies'));
        await tester.pumpAndSettle();

        await screenMatchesGolden(tester, 'help_screen_missed_policies');
      },
    );
  });
}
