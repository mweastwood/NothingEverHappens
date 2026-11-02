import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helper.dart';
import 'package:nothing_ever_happens/logic/calendar_day_task.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/task_label.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/user_settings.dart';
import 'package:nothing_ever_happens/widgets/calendar_month_card.dart';

void main() {
  final march2026 = DateTime(2026, 3, 1);
  final todayDay8 = const CivilDay(year: 2026, month: 3, day: 8);

  final sampleTasks = [
    const CalendarDayTask(
      id: 'task-1',
      title: 'Task Alpha',
      priority: TaskPriority.high,
      isInstance: true,
      isCompleted: false,
    ),
    const CalendarDayTask(
      id: 'task-2',
      title: 'Task Beta',
      priority: TaskPriority.medium,
      isInstance: true,
      isCompleted: false,
    ),
    const CalendarDayTask(
      id: 'task-3',
      title: 'Task Gamma',
      priority: TaskPriority.low,
      isInstance: true,
      isCompleted: true,
    ),
  ];

  Widget createTestWidget({required Widget child, double? width}) {
    return buildTestableWidget(
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: width ?? 600,
            child: SingleChildScrollView(child: child),
          ),
        ),
      ),
    );
  }

  testWidgets('Verify month header and weekday headers render accurately', (
    tester,
  ) async {
    await tester.pumpWidget(
      createTestWidget(
        child: CalendarMonthCard(monthDate: march2026, today: todayDay8),
      ),
    );
    await tester.pumpAndSettle();

    // Month Title
    expect(find.text('March 2026'), findsOneWidget);

    // Current Month badge
    expect(find.text('This Month'), findsOneWidget);

    // Weekday headers: S, M, T, W, T, F, S (or M, T, W, T, F, S, S)
    expect(find.text('M'), findsOneWidget);
    expect(find.text('W'), findsOneWidget);
    expect(find.text('F'), findsOneWidget);
    expect(find.text('T'), findsNWidgets(2));
    expect(find.text('S'), findsNWidgets(2));
  });

  testWidgets(
    'Verify week starting on Sunday positions day 1 in column 0 for March 2026',
    (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: CalendarMonthCard(
            monthDate: march2026,
            today: todayDay8,
            firstDayOfWeek: FirstDayOfWeek.sunday,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final slotFinders = find.byType(CalendarDayCellSlot);
      final firstSlot = tester.widget<CalendarDayCellSlot>(slotFinders.first);
      expect(firstSlot.row, equals(0));
      expect(firstSlot.col, equals(0));
      expect(firstSlot.leadingEmptyCount, equals(0));
    },
  );

  testWidgets(
    'Verify week starting on Monday positions day 1 in column 6 for March 2026',
    (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: CalendarMonthCard(
            monthDate: march2026,
            today: todayDay8,
            firstDayOfWeek: FirstDayOfWeek.monday,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final slotFinders = find.byType(CalendarDayCellSlot);
      final firstSlot = tester.widget<CalendarDayCellSlot>(slotFinders.first);
      expect(firstSlot.row, equals(0));
      expect(firstSlot.col, equals(0));
      expect(firstSlot.leadingEmptyCount, equals(6));
    },
  );

  testWidgets(
    'Verify current month badge is not shown for past/future months',
    (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: CalendarMonthCard(
            monthDate: DateTime(2026, 4, 1),
            today: todayDay8,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('April 2026'), findsOneWidget);
      expect(find.text('This Month'), findsNothing);
    },
  );

  testWidgets(
    'Verify Tier 1 responsive layout triggers when cell width >= 60 and height >= 50',
    (tester) async {
      // With width 700, cellWidth = 700 / 7 = 100 >= 60, isWide = true -> cellHeight = 62 >= 50
      await tester.pumpWidget(
        createTestWidget(
          width: 700,
          child: CalendarMonthCard(
            monthDate: march2026,
            today: todayDay8,
            isWide: true,
            dayTaskMap: {todayDay8: sampleTasks},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tier 1 shows planned hours badge, compact +N in header, and standout task title chip
      expect(find.text('1.5h'), findsOneWidget);
      expect(find.text('Task Alpha'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);
      expect(find.byType(CalendarLabelCapacityBar), findsOneWidget);
    },
  );

  testWidgets(
    'Verify Tier 2 responsive layout triggers when 42 <= cell width < 60',
    (tester) async {
      // With width 350, cellWidth = 350 / 7 = 50 (< 60 and >= 42), cellHeight = 54 >= 42
      await tester.pumpWidget(
        createTestWidget(
          width: 350,
          child: CalendarMonthCard(
            monthDate: march2026,
            today: todayDay8,
            isWide: false,
            dayTaskMap: {todayDay8: sampleTasks},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tier 2 shows first task title chip and compact "+N" overflow pill
      expect(find.text('Task Alpha'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);
      expect(find.text('+2 more'), findsNothing);
    },
  );

  testWidgets('Verify Tier 3 responsive layout triggers when cell width < 42', (
    tester,
  ) async {
    // With width 210, cellWidth = 210 / 7 = 30 (< 42)
    await tester.pumpWidget(
      createTestWidget(
        width: 210,
        child: CalendarMonthCard(
          monthDate: march2026,
          today: todayDay8,
          isWide: false,
          dayTaskMap: {todayDay8: sampleTasks},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tier 3 shows no text task chips, only compact label-segmented capacity bar
    expect(find.text('Task Alpha'), findsNothing);
    expect(find.text('+2'), findsNothing);
    expect(find.text('+2 more'), findsNothing);
    expect(find.byType(CalendarTaskChip), findsNothing);
    expect(find.byType(CalendarLabelCapacityBar), findsOneWidget);
  });

  testWidgets(
    'Verify label-segmented capacity bar divides multi-label task duration evenly and shows overload indicator',
    (tester) async {
      final labelsMap = <String, TaskLabel>{
        'lbl-home': TaskLabel(
          id: 'lbl-home',
          name: 'Home',
          colorKey: 'emerald',
          iconKey: 'home',
          scope: TaskLabelScope.personal,
          order: 0,
          createdAt: DateTime.utc(2026, 3, 1),
        ),
        'lbl-meals': TaskLabel(
          id: 'lbl-meals',
          name: 'Meals',
          colorKey: 'tangerine',
          iconKey: 'restaurant',
          scope: TaskLabelScope.personal,
          order: 1,
          createdAt: DateTime.utc(2026, 3, 1),
        ),
      };

      final multiLabelSchedule = TaskSchedule(
        id: 'S-1',
        title: 'Dinner Party Prep',
        description: '',
        priority: TaskPriority.high,
        estimatedDuration: const Duration(minutes: 180), // 3.0h
        labelIds: const ['lbl-home', 'lbl-meals'],
        schedules: const [],
      );

      final unlabeledSchedule = TaskSchedule(
        id: 'S-2',
        title: 'Quick Call',
        description: '',
        priority: TaskPriority.low,
        estimatedDuration: const Duration(minutes: 30), // 0.5h
        schedules: const [],
      );

      await tester.pumpWidget(
        createTestWidget(
          width: 700,
          child: CalendarMonthCard(
            monthDate: march2026,
            today: todayDay8,
            isWide: true,
            labelsMap: labelsMap,
            userSettings: const UserSettings(hoursAvailable: 3.0),
            dayTaskMap: {
              const CivilDay(year: 2026, month: 3, day: 12): [
                CalendarDayTask(
                  id: 't-1',
                  title: multiLabelSchedule.title,
                  priority: multiLabelSchedule.priority,
                  isInstance: true,
                  schedule: multiLabelSchedule,
                ),
                CalendarDayTask(
                  id: 't-2',
                  title: unlabeledSchedule.title,
                  priority: unlabeledSchedule.priority,
                  isInstance: true,
                  schedule: unlabeledSchedule,
                ),
              ],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 3.5h exceeds 3.0h capacity -> shows "3.5h!"
      expect(find.text('3.5h!'), findsOneWidget);
      expect(find.text('Dinner Party Prep'), findsOneWidget);

      final barWidget = tester.widget<CalendarLabelCapacityBar>(
        find.byType(CalendarLabelCapacityBar),
      );
      expect(barWidget.workload.segments, hasLength(3));
      expect(barWidget.workload.segments[0].minutes, closeTo(90.0, 1e-6));
      expect(barWidget.workload.segments[1].minutes, closeTo(90.0, 1e-6));
      expect(barWidget.workload.segments[2].colorKey, isNull);
      expect(barWidget.workload.segments[2].minutes, closeTo(30.0, 1e-6));
    },
  );

  testWidgets('Verify day cell tap invokes onDayTap callback', (tester) async {
    CivilDay? tappedDay;

    await tester.pumpWidget(
      createTestWidget(
        child: CalendarMonthCard(
          monthDate: march2026,
          today: todayDay8,
          onDayTap: (day) {
            tappedDay = day;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final day8Finder = find.descendant(
      of: find.byKey(const Key('month_card_2026_3')),
      matching: find.text('8'),
    );
    expect(day8Finder, findsOneWidget);

    await tester.tap(day8Finder);
    await tester.pumpAndSettle();

    expect(tappedDay, equals(todayDay8));
  });

  testWidgets(
    'Verify today cell renders isolated 12 FPS CalendarTodayBlobBackground and animates over time',
    (tester) async {
      CalendarTodayBlobBackground.debugForceAnimateInTests = true;
      addTearDown(() {
        CalendarTodayBlobBackground.debugForceAnimateInTests = false;
      });

      await tester.pumpWidget(
        createTestWidget(
          child: CalendarMonthCard(monthDate: march2026, today: todayDay8),
        ),
      );
      await tester.pump();

      // Only the single current day (March 8) renders CalendarTodayBlobBackground
      final blobBgFinder = find.byType(CalendarTodayBlobBackground);
      expect(blobBgFinder, findsOneWidget);

      // Verify blob sits in the lowest layer (index 0) of the month grid Stack behind all day cells
      final gridStackFinder = find.ancestor(
        of: blobBgFinder,
        matching: find.byType(Stack),
      );
      expect(gridStackFinder, findsOneWidget);
      final gridStack = tester.widget<Stack>(gridStackFinder);
      expect(gridStack.children.first, isA<Positioned>());
      expect(gridStack.children.last, isA<RepaintBoundary>());

      // Verify blob painter has its own isolated RepaintBoundary
      final repaintBoundaries = find.descendant(
        of: blobBgFinder,
        matching: find.byType(RepaintBoundary),
      );
      expect(repaintBoundaries, findsOneWidget);

      final customPaintFinder = find.descendant(
        of: blobBgFinder,
        matching: find.byType(CustomPaint),
      );
      final initialPaint = tester.widget<CustomPaint>(customPaintFinder);
      final initialPainter = initialPaint.painter as CalendarTodayBlobPainter;
      expect(initialPainter.progress, equals(0.0));

      // Pump 12 frame intervals (~1 second at 12 FPS)
      for (int i = 0; i < 12; i++) {
        await tester.pump(CalendarTodayBlobBackground.frameInterval);
      }
      final updatedPaint = tester.widget<CustomPaint>(customPaintFinder);
      final updatedPainter = updatedPaint.painter as CalendarTodayBlobPainter;
      expect(
        updatedPainter.progress,
        closeTo(
          (12 * CalendarTodayBlobBackground.frameInterval.inMilliseconds) /
              CalendarTodayBlobBackground.cycleDuration.inMilliseconds,
          0.01,
        ),
      );
      expect(updatedPainter.shouldRepaint(initialPainter), isTrue);
    },
  );

  test('getWeekdayHeaders caches results and can be cleared', () {
    clearCalendarMonthCardCaches();
    final headers1 = getWeekdayHeaders(
      'en_US',
      firstDayOfWeek: FirstDayOfWeek.sunday,
    );
    final headers2 = getWeekdayHeaders(
      'en_US',
      firstDayOfWeek: FirstDayOfWeek.sunday,
    );
    expect(identical(headers1, headers2), isTrue);

    final headersMonday = getWeekdayHeaders(
      'en_US',
      firstDayOfWeek: FirstDayOfWeek.monday,
    );
    expect(identical(headers1, headersMonday), isFalse);

    clearCalendarMonthCardCaches();
    final headers3 = getWeekdayHeaders(
      'en_US',
      firstDayOfWeek: FirstDayOfWeek.sunday,
    );
    expect(headers3, equals(headers1));
  });
}
