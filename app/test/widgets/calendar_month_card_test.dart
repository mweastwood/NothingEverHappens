import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helper.dart';
import 'package:nothing_ever_happens/logic/calendar_day_task.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_label.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/user_settings.dart';
import 'package:nothing_ever_happens/widgets/calendar_month_card.dart';

void main() {
  final march2026 = DateTime(2026, 3, 1);
  final todayDay8 = const CivilDay(year: 2026, month: 3, day: 8);

  final sampleLabelsMap = <String, TaskLabel>{
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
    'lbl-health': TaskLabel(
      id: 'lbl-health',
      name: 'Health',
      colorKey: 'rose',
      iconKey: 'medication',
      scope: TaskLabelScope.personal,
      order: 2,
      createdAt: DateTime.utc(2026, 3, 1),
    ),
  };

  Widget createTestWidget({required Widget child, double? width}) {
    return buildTestableWidget(
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: width ?? 400,
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

    expect(find.text('March 2026'), findsOneWidget);
    expect(find.text('This Month'), findsOneWidget);

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
    'Routine and weekly tasks fold into capacity bar only while one-off/rare tasks show label dots',
    (tester) async {
      final weeklyRule = WeeklySchedule(
        id: 'R-weekly',
        scheduleId: 'S-weekly',
        startDate: const CivilDay(year: 2026, month: 3, day: 1),
        interval: 1,
        daysOfWeek: {1},
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 7, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 8, minute: 0),
      );
      final weeklySchedule = TaskSchedule(
        id: 'S-weekly',
        title: 'Go to the gym',
        description: '',
        priority: TaskPriority.medium,
        estimatedDuration: const Duration(minutes: 60),
        labelIds: const ['lbl-home'],
        schedules: [weeklyRule],
      );

      final oneOffRule = OneOffSchedule(
        id: 'R-dentist',
        scheduleId: 'S-dentist',
        date: const CivilDay(year: 2026, month: 3, day: 12),
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          hour: 14,
          minute: 0,
        ),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 15, minute: 0),
      );
      final oneOffSchedule = TaskSchedule(
        id: 'S-dentist',
        title: 'Dentist Appointment',
        description: '',
        priority: TaskPriority.high,
        estimatedDuration: const Duration(minutes: 60),
        labelIds: const ['lbl-health'],
        schedules: [oneOffRule],
      );

      final monthlyRule = MonthlySchedule(
        id: 'R-filter',
        scheduleId: 'S-filter',
        startDate: const CivilDay(year: 2026, month: 3, day: 1),
        interval: 1,
        dayOfMonth: 12,
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          hour: 10,
          minute: 0,
        ),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 11, minute: 0),
      );
      final monthlySchedule = TaskSchedule(
        id: 'S-filter',
        title: 'Replace HVAC Filter',
        description: '',
        priority: TaskPriority.medium,
        estimatedDuration: const Duration(minutes: 30),
        labelIds: const ['lbl-home'],
        schedules: [monthlyRule],
      );

      await tester.pumpWidget(
        createTestWidget(
          width: 400,
          child: CalendarMonthCard(
            monthDate: march2026,
            today: todayDay8,
            labelsMap: sampleLabelsMap,
            dayTaskMap: {
              const CivilDay(year: 2026, month: 3, day: 9): [
                CalendarDayTask(
                  id: 't-gym',
                  title: weeklySchedule.title,
                  priority: weeklySchedule.priority,
                  isInstance: false,
                  schedule: weeklySchedule,
                  matchingRule: weeklyRule,
                ),
              ],
              const CivilDay(year: 2026, month: 3, day: 12): [
                CalendarDayTask(
                  id: 't-dentist',
                  title: oneOffSchedule.title,
                  priority: oneOffSchedule.priority,
                  isInstance: true,
                  schedule: oneOffSchedule,
                  matchingRule: oneOffRule,
                ),
                CalendarDayTask(
                  id: 't-filter',
                  title: monthlySchedule.title,
                  priority: monthlySchedule.priority,
                  isInstance: false,
                  schedule: monthlySchedule,
                  matchingRule: monthlyRule,
                ),
              ],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Month grid stays clean: no task titles crammed inside day cells
      expect(find.text('Go to the gym'), findsNothing);
      expect(find.text('Dentist Appointment'), findsNothing);

      // Day 9 (routine weekly only) has a capacity bar but NO highlighted label dots
      final day9Dots = tester.widget<CalendarHighlightedDotsRow>(
        find.byKey(const Key('highlighted_dots_2026_3_9')),
      );
      expect(day9Dots.dotColorKeys, isEmpty);

      // Day 12 (one-off + monthly) renders two label-colored dots
      final day12Dots = tester.widget<CalendarHighlightedDotsRow>(
        find.byKey(const Key('highlighted_dots_2026_3_12')),
      );
      expect(day12Dots.dotColorKeys, equals(['rose', 'emerald']));

      // Both days render a CalendarLabelCapacityBar
      expect(find.byType(CalendarLabelCapacityBar), findsNWidgets(2));
    },
  );

  testWidgets(
    'Verify label-segmented capacity bar divides multi-label task duration evenly and scales across overloaded months',
    (tester) async {
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

      final heavySchedule = TaskSchedule(
        id: 'S-3',
        title: 'Full Day Move',
        description: '',
        priority: TaskPriority.high,
        estimatedDuration: const Duration(minutes: 360), // 6.0h
        schedules: const [],
      );

      await tester.pumpWidget(
        createTestWidget(
          width: 400,
          child: CalendarMonthCard(
            monthDate: march2026,
            today: todayDay8,
            labelsMap: sampleLabelsMap,
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
              const CivilDay(year: 2026, month: 3, day: 14): [
                CalendarDayTask(
                  id: 't-3',
                  title: heavySchedule.title,
                  priority: heavySchedule.priority,
                  isInstance: true,
                  schedule: heavySchedule,
                ),
              ],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bars = tester
          .widgetList<CalendarLabelCapacityBar>(
            find.byType(CalendarLabelCapacityBar),
          )
          .toList();
      expect(bars, hasLength(2));

      final day12Bar = bars.firstWhere((b) => b.workload.totalMinutes == 210);
      expect(day12Bar.workload.isOverCapacity, isTrue);
      // Scaled to peak month hours (6.0h) instead of flatlining at 3.0h
      expect(day12Bar.scaleCapacityHours, closeTo(6.0, 1e-6));
      expect(day12Bar.workload.segments, hasLength(3));
      expect(day12Bar.workload.segments[0].minutes, closeTo(90.0, 1e-6));
      expect(day12Bar.workload.segments[1].minutes, closeTo(90.0, 1e-6));
      expect(day12Bar.workload.segments[2].colorKey, isNull);
      expect(day12Bar.workload.segments[2].minutes, closeTo(30.0, 1e-6));
    },
  );

  testWidgets('Verify day cell tap invokes onDayTap callback', (tester) async {
    CivilDay? tappedDay;

    await tester.pumpWidget(
      createTestWidget(
        child: CalendarMonthCard(
          monthDate: march2026,
          today: todayDay8,
          selectedDay: todayDay8,
          onDayTap: (day) {
            tappedDay = day;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final day8Finder = find.byKey(const Key('calendar_day_2026_3_8'));
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

      final blobBgFinder = find.byType(CalendarTodayBlobBackground);
      expect(blobBgFinder, findsOneWidget);

      final gridStackFinder = find.ancestor(
        of: blobBgFinder,
        matching: find.byType(Stack),
      );
      expect(gridStackFinder, findsOneWidget);
      final gridStack = tester.widget<Stack>(gridStackFinder);
      expect(gridStack.children.first, isA<Positioned>());
      expect(gridStack.children.last, isA<RepaintBoundary>());

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
