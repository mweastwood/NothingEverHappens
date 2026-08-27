import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/dashboard_stats.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/widgets/daily_activity_breakdown_sheet.dart';
import '../test_helper.dart';

void main() {
  group('DailyActivityBreakdownSheet', () {
    final day = CivilDay(year: 2026, month: 7, day: 1); // Wednesday

    const dummyStart = RelativeTime(
      dayOffset: 0,
      time: TimeOfDay(hour: 9, minute: 0),
    );
    const dummyDue = RelativeTime(
      dayOffset: 0,
      time: TimeOfDay(hour: 17, minute: 0),
    );

    final activeDayData = DailyStatsData(
      day: day,
      completedCount: 4,
      skippedCount: 1,
      missedCount: 1,
      completedHours: 4.0,
      completedTasks: [
        TaskInstance(
          id: 't-1',
          scheduleId: 's-1',
          ruleId: 'r-1',
          title: 'Clean the kitchen',
          description: 'Wash dishes and wipe counters',
          scheduledDate: day,
          startRelativeTime: dummyStart,
          dueRelativeTime: dummyDue,
          status: TaskStatus.completed,
          completedAt: DateTime(2026, 7, 1, 14, 30),
        ),
        TaskInstance(
          id: 't-2',
          scheduleId: 's-2',
          ruleId: 'r-2',
          title: 'Water plants',
          description: '',
          scheduledDate: day,
          startRelativeTime: dummyStart,
          dueRelativeTime: dummyDue,
          status: TaskStatus.completed,
        ),
        TaskInstance(
          id: 't-overdue',
          scheduleId: 's-overdue',
          ruleId: 'r-overdue',
          title: 'Take medication',
          description: 'Evening dose',
          scheduledDate: day,
          startRelativeTime: dummyStart,
          dueRelativeTime: dummyDue,
          status: TaskStatus.completed,
          completedAt: DateTime(2026, 7, 1, 19, 0), // Overdue (due was 17:00)
        ),
        TaskInstance(
          id: 't-severe-overdue',
          scheduleId: 's-severe',
          ruleId: 'r-severe',
          title: 'Submit quarterly report',
          description: '',
          scheduledDate: day,
          startRelativeTime: dummyStart,
          dueRelativeTime: dummyDue,
          status: TaskStatus.completed,
          completedAt: DateTime(
            2026,
            7,
            3,
            10,
            0,
          ), // Overdue by 41 hours (due was July 1 at 17:00)
        ),
      ],
      skippedTasks: [
        TaskInstance(
          id: 't-3',
          scheduleId: 's-3',
          ruleId: 'r-3',
          title: 'Vacuum living room',
          description: 'Carpet in hallway and living room',
          scheduledDate: day,
          startRelativeTime: dummyStart,
          dueRelativeTime: dummyDue,
          status: TaskStatus.skipped,
        ),
      ],
      missedTasks: [
        TaskInstance(
          id: 't-4',
          scheduleId: 's-4',
          ruleId: 'r-4',
          title: 'Take out recycling',
          description: '',
          scheduledDate: day,
          startRelativeTime: dummyStart,
          dueRelativeTime: dummyDue,
          status: TaskStatus.pending,
        ),
      ],
    );

    final emptyDayData = DailyStatsData(
      day: CivilDay(year: 2026, month: 7, day: 4),
      completedCount: 0,
      skippedCount: 0,
      missedCount: 0,
      completedHours: 0.0,
    );

    final completedOnlyDayData = DailyStatsData(
      day: CivilDay(year: 2026, month: 7, day: 5),
      completedCount: 2,
      skippedCount: 0,
      missedCount: 0,
      completedHours: 1.5,
      completedTasks: [
        TaskInstance(
          id: 't-5',
          scheduleId: 's-5',
          ruleId: 'r-5',
          title: 'Read chapter 4',
          description: 'Pages 50-80',
          scheduledDate: CivilDay(year: 2026, month: 7, day: 5),
          startRelativeTime: dummyStart,
          dueRelativeTime: dummyDue,
          status: TaskStatus.completed,
          completedAt: DateTime(2026, 7, 5, 10, 15),
        ),
        TaskInstance(
          id: 't-6',
          scheduleId: 's-6',
          ruleId: 'r-6',
          title: 'Morning stretch',
          description: '',
          scheduledDate: CivilDay(year: 2026, month: 7, day: 5),
          startRelativeTime: dummyStart,
          dueRelativeTime: dummyDue,
          status: TaskStatus.completed,
          completedAt: DateTime(2026, 7, 5, 8, 0),
        ),
      ],
    );

    testWidgets(
      'renders date header, metric chips, section headers, and task tiles',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: DailyActivityBreakdownSheet(dayData: activeDayData),
            ),
          ),
        );

        // Header date
        expect(find.text('Wednesday, Jul 1, 2026'), findsOneWidget);

        // Metric chips
        expect(find.text('2 completed'), findsOneWidget);
        expect(find.text('1 overdue'), findsOneWidget);
        expect(find.text('1 seriously overdue'), findsOneWidget);
        expect(find.text('2 skipped'), findsOneWidget);
        expect(find.text('4h'), findsOneWidget);

        // Section headers
        expect(find.text('Completed (2)'), findsOneWidget);
        expect(find.text('Completed Overdue (1)'), findsOneWidget);
        expect(find.text('Seriously Overdue (1)'), findsOneWidget);
        expect(find.text('Skipped (2)'), findsOneWidget);

        // Single-line task tiles (no descriptions shown)
        expect(find.text('Clean the kitchen'), findsOneWidget);
        expect(find.text('Jul 1, 2:30 PM'), findsOneWidget);
        expect(find.text('Wash dishes and wipe counters'), findsNothing);

        expect(find.text('Water plants'), findsOneWidget);

        expect(find.text('Take medication'), findsOneWidget);
        expect(find.text('Jul 1, 7:00 PM'), findsOneWidget);
        expect(find.text('Evening dose'), findsNothing);

        expect(find.text('Submit quarterly report'), findsOneWidget);
        expect(find.text('Jul 3, 10:00 AM'), findsOneWidget);

        expect(find.text('Vacuum living room'), findsOneWidget);
        expect(find.text('Carpet in hallway and living room'), findsNothing);

        expect(find.text('Take out recycling'), findsOneWidget);

        // Status tags
        expect(find.text('Completed'), findsNWidgets(2));
        expect(find.text('Overdue'), findsOneWidget);
        expect(find.text('Seriously Overdue'), findsOneWidget);
        expect(find.text('Skipped'), findsNWidgets(2));
      },
    );

    testWidgets('sorts tasks in order they were resolved within a section', (
      tester,
    ) async {
      final sortedDayData = DailyStatsData(
        day: day,
        completedCount: 3,
        skippedCount: 2,
        missedCount: 0,
        completedHours: 3.0,
        completedTasks: [
          TaskInstance(
            id: 't-late',
            scheduleId: 's-1',
            ruleId: 'r-1',
            title: 'Task Resolved Last (16:00)',
            description: '',
            scheduledDate: day,
            startRelativeTime: dummyStart,
            dueRelativeTime: dummyDue,
            status: TaskStatus.completed,
            completedAt: DateTime(2026, 7, 1, 16, 0),
          ),
          TaskInstance(
            id: 't-early',
            scheduleId: 's-2',
            ruleId: 'r-2',
            title: 'Task Resolved First (09:30)',
            description: '',
            scheduledDate: day,
            startRelativeTime: dummyStart,
            dueRelativeTime: dummyDue,
            status: TaskStatus.completed,
            completedAt: DateTime(2026, 7, 1, 9, 30),
          ),
          TaskInstance(
            id: 't-mid',
            scheduleId: 's-3',
            ruleId: 'r-3',
            title: 'Task Resolved Middle (12:00)',
            description: '',
            scheduledDate: day,
            startRelativeTime: dummyStart,
            dueRelativeTime: dummyDue,
            status: TaskStatus.completed,
            completedAt: DateTime(2026, 7, 1, 12, 0),
          ),
        ],
        skippedTasks: [
          TaskInstance(
            id: 't-skip-2',
            scheduleId: 's-4',
            ruleId: 'r-4',
            title: 'Skipped Second (15:00)',
            description: '',
            scheduledDate: day,
            startRelativeTime: dummyStart,
            dueRelativeTime: dummyDue,
            status: TaskStatus.skipped,
            completedAt: DateTime(2026, 7, 1, 15, 0),
          ),
          TaskInstance(
            id: 't-skip-1',
            scheduleId: 's-5',
            ruleId: 'r-5',
            title: 'Skipped First (10:00)',
            description: '',
            scheduledDate: day,
            startRelativeTime: dummyStart,
            dueRelativeTime: dummyDue,
            status: TaskStatus.skipped,
            completedAt: DateTime(2026, 7, 1, 10, 0),
          ),
        ],
      );

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: DailyActivityBreakdownSheet(dayData: sortedDayData),
          ),
        ),
      );

      // Verify task text widgets appear in resolution order
      final firstFinder = find.text('Task Resolved First (09:30)');
      final midFinder = find.text('Task Resolved Middle (12:00)');
      final lastFinder = find.text('Task Resolved Last (16:00)');

      final firstY = tester.getTopLeft(firstFinder).dy;
      final midY = tester.getTopLeft(midFinder).dy;
      final lastY = tester.getTopLeft(lastFinder).dy;

      expect(firstY < midY, isTrue);
      expect(midY < lastY, isTrue);

      final skipFirstFinder = find.text('Skipped First (10:00)');
      final skipSecondFinder = find.text('Skipped Second (15:00)');
      final skipFirstY = tester.getTopLeft(skipFirstFinder).dy;
      final skipSecondY = tester.getTopLeft(skipSecondFinder).dy;

      expect(skipFirstY < skipSecondY, isTrue);
    });

    testWidgets('renders empty state when day has no tasks', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: DailyActivityBreakdownSheet(dayData: emptyDayData),
          ),
        ),
      );

      expect(find.text('Saturday, Jul 4, 2026'), findsOneWidget);
      expect(find.text('No tasks recorded'), findsOneWidget);
      expect(find.text('No activity recorded for this day'), findsOneWidget);
      expect(find.byIcon(Icons.event_busy_outlined), findsOneWidget);
    });

    testWidgets('close button dismisses sheet when opened via show', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    DailyActivityBreakdownSheet.show(context, activeDayData),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('daily_activity_breakdown_sheet')),
        findsOneWidget,
      );

      // Tap close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('daily_activity_breakdown_sheet')),
        findsNothing,
      );
    });

    testWidgets(
      'marks completed task overdue by > 24 hours with error/red color',
      (tester) async {
        final severeOverdueTask = TaskInstance(
          id: 't-severe-overdue',
          scheduleId: 's-severe',
          ruleId: 'r-severe',
          title: 'Submit quarterly report',
          description: '',
          scheduledDate: day,
          startRelativeTime: dummyStart,
          dueRelativeTime: dummyDue,
          status: TaskStatus.completed,
          completedAt: DateTime(
            2026,
            7,
            3,
            10,
            0,
          ), // Overdue by 41 hours (due was July 1 at 17:00)
        );

        final mildOverdueTask = TaskInstance(
          id: 't-mild-overdue',
          scheduleId: 's-mild',
          ruleId: 'r-mild',
          title: 'Call dentist',
          description: '',
          scheduledDate: day,
          startRelativeTime: dummyStart,
          dueRelativeTime: dummyDue,
          status: TaskStatus.completed,
          completedAt: DateTime(2026, 7, 1, 20, 0), // Overdue by 3 hours
        );

        final testDayData = DailyStatsData(
          day: day,
          completedCount: 2,
          skippedCount: 0,
          missedCount: 0,
          completedHours: 2.0,
          completedTasks: [severeOverdueTask, mildOverdueTask],
        );

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: DailyActivityBreakdownSheet(dayData: testDayData),
            ),
          ),
        );

        expect(find.text('Submit quarterly report'), findsOneWidget);
        expect(find.text('Call dentist'), findsOneWidget);

        final icons = tester
            .widgetList<Icon>(find.byIcon(Icons.warning_amber_rounded))
            .toList();
        final BuildContext context = tester.element(
          find.byKey(const Key('daily_activity_breakdown_sheet')),
        );
        final theme = Theme.of(context);

        expect(
          icons.any((icon) => icon.color == theme.colorScheme.error),
          isTrue,
        );
        expect(
          icons.any((icon) => icon.color == Colors.amber.shade800),
          isTrue,
        );
      },
    );

    testWidgets('handles null completedAt when sorting resolved order', (
      tester,
    ) async {
      final nullTimeDayData = DailyStatsData(
        day: day,
        completedCount: 0,
        skippedCount: 2,
        missedCount: 1,
        completedHours: 0.0,
        skippedTasks: [
          TaskInstance(
            id: 't-skip-null-1',
            scheduleId: 's-1',
            ruleId: 'r-1',
            title: 'B Skipped Null',
            description: '',
            scheduledDate: day,
            startRelativeTime: dummyStart,
            dueRelativeTime: dummyDue,
            status: TaskStatus.skipped,
            completedAt: null,
            updatedAt: null,
          ),
          TaskInstance(
            id: 't-skip-null-2',
            scheduleId: 's-2',
            ruleId: 'r-2',
            title: 'A Skipped Null',
            description: '',
            scheduledDate: day,
            startRelativeTime: dummyStart,
            dueRelativeTime: dummyDue,
            status: TaskStatus.skipped,
            completedAt: null,
            updatedAt: null,
          ),
        ],
        missedTasks: [
          TaskInstance(
            id: 't-miss-null',
            scheduleId: 's-3',
            ruleId: 'r-3',
            title: 'Missed Task Null',
            description: '',
            scheduledDate: day,
            startRelativeTime: dummyStart,
            dueRelativeTime: dummyDue,
            status: TaskStatus.failed,
            completedAt: null,
            updatedAt: null,
          ),
        ],
      );

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: DailyActivityBreakdownSheet(dayData: nullTimeDayData),
          ),
        ),
      );

      expect(find.text('A Skipped Null'), findsOneWidget);
      expect(find.text('B Skipped Null'), findsOneWidget);
      expect(find.text('Missed Task Null'), findsOneWidget);
    });

    testWidgets('formats completion time using active locale', (tester) async {
      final taskWithTime = TaskInstance(
        id: 't-locale',
        scheduleId: 's-loc',
        ruleId: 'r-loc',
        title: 'Locale Task',
        description: '',
        scheduledDate: day,
        startRelativeTime: dummyStart,
        dueRelativeTime: dummyDue,
        status: TaskStatus.completed,
        completedAt: DateTime(2026, 7, 1, 14, 30),
      );

      final testDayData = DailyStatsData(
        day: day,
        completedCount: 1,
        skippedCount: 0,
        missedCount: 0,
        completedHours: 1.0,
        completedTasks: [taskWithTime],
      );

      await tester.pumpWidget(
        buildTestableWidget(
          locale: const Locale('en', 'US'),
          child: Scaffold(
            body: DailyActivityBreakdownSheet(dayData: testDayData),
          ),
        ),
      );

      expect(find.text('Jul 1, 2:30 PM'), findsOneWidget);
    });

    testWidgets(
      'renders planned tasks, chips, and Planned section header on future days',
      (tester) async {
        AppClock.setMockTime(DateTime(2026, 7, 1, 12, 0));
        addTearDown(AppClock.reset);

        final futureDay = CivilDay(year: 2026, month: 7, day: 5);
        final futureDayData = DailyStatsData(
          day: futureDay,
          plannedHours: 1.5,
          plannedTasks: [
            TaskInstance(
              id: 'plan-1',
              scheduleId: 's-1',
              ruleId: 'r-1',
              title: 'Mow lawn',
              description: '',
              scheduledDate: futureDay,
              startRelativeTime: dummyStart,
              dueRelativeTime: dummyDue,
            ),
            TaskInstance(
              id: 'plan-2',
              scheduleId: 's-2',
              ruleId: 'r-2',
              title: 'Wash car',
              description: '',
              scheduledDate: futureDay,
              startRelativeTime: dummyStart,
              dueRelativeTime: dummyDue,
            ),
          ],
        );

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: DailyActivityBreakdownSheet(dayData: futureDayData),
            ),
          ),
        );

        expect(find.text('Sunday, Jul 5, 2026'), findsOneWidget);
        expect(find.text('2 planned'), findsOneWidget);
        expect(find.text('1h 30m'), findsOneWidget);
        expect(find.text('Planned (2)'), findsOneWidget);
        expect(find.text('Mow lawn'), findsOneWidget);
        expect(find.text('Wash car'), findsOneWidget);
        expect(find.text('Planned'), findsNWidgets(2));
      },
    );

    testWidgets(
      'renders future empty state message when day is in the future',
      (tester) async {
        AppClock.setMockTime(DateTime(2026, 7, 1, 12, 0));
        addTearDown(AppClock.reset);

        final futureEmptyDay = CivilDay(year: 2026, month: 7, day: 5);
        final futureEmptyData = DailyStatsData(day: futureEmptyDay);

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: DailyActivityBreakdownSheet(dayData: futureEmptyData),
            ),
          ),
        );

        expect(find.text('Sunday, Jul 5, 2026'), findsOneWidget);
        expect(find.text('No tasks recorded'), findsOneWidget);
        expect(find.text('No tasks scheduled for this day'), findsOneWidget);
        expect(find.byIcon(Icons.event_busy_outlined), findsOneWidget);
      },
    );

    testGoldens('DailyActivityBreakdownSheet renders correctly', (
      tester,
    ) async {
      final builder = GoldenBuilder.column()
        ..addScenario(
          'Active Day Breakdown',
          Material(child: DailyActivityBreakdownSheet(dayData: activeDayData)),
        )
        ..addScenario(
          'Completed Only Breakdown',
          Material(
            child: DailyActivityBreakdownSheet(dayData: completedOnlyDayData),
          ),
        )
        ..addScenario(
          'Empty Day Breakdown',
          Material(child: DailyActivityBreakdownSheet(dayData: emptyDayData)),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(500, 1600),
      );

      await screenMatchesGolden(
        tester,
        'daily_activity_breakdown_sheet_golden',
      );
    });
  });
}
