import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/widgets/spawned_instances_list.dart';
import '../test_helper.dart';

void main() {
  group('SpawnedInstancesList', () {
    final now = DateTime(2026, 10, 26, 10, 0); // Monday

    final dailyTask = TaskSchedule(
      id: 'S-test-task',
      title: 'Test Daily Task',
      description: 'Daily test description',
      schedules: [
        DailySchedule(
          id: 'R-daily-rule',
          scheduleId: 'S-test-task',
          startDate: CivilDay(year: 2026, month: 10, day: 25),
          interval: 1,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
        ),
      ],
    );

    final startRel = const RelativeTime(
      dayOffset: 0,
      time: TimeOfDay(hour: 9, minute: 0),
    );
    final dueRel = const RelativeTime(
      dayOffset: 0,
      time: TimeOfDay(hour: 17, minute: 0),
    );

    final dbInstances = [
      // Completed instance
      TaskInstance(
        id: 'I-completed',
        scheduleId: 'S-test-task',
        ruleId: 'R-daily-rule',
        title: 'Test Daily Task',
        description: 'Daily test description',
        scheduledDate: CivilDay(year: 2026, month: 10, day: 24),
        startRelativeTime: startRel,
        dueRelativeTime: dueRel,
        status: 'completed',
        completedAt: DateTime(2026, 10, 24, 11, 30),
      ),
      // Skipped instance
      TaskInstance(
        id: 'I-skipped',
        scheduleId: 'S-test-task',
        ruleId: 'R-daily-rule',
        title: 'Test Daily Task',
        description: 'Daily test description',
        scheduledDate: CivilDay(year: 2026, month: 10, day: 23),
        startRelativeTime: startRel,
        dueRelativeTime: dueRel,
        status: 'skipped',
      ),
      // Missed instance (past due)
      TaskInstance(
        id: 'I-missed',
        scheduleId: 'S-test-task',
        ruleId: 'R-daily-rule',
        title: 'Test Daily Task',
        description: 'Daily test description',
        scheduledDate: CivilDay(year: 2026, month: 10, day: 22),
        startRelativeTime: startRel,
        dueRelativeTime: dueRel,
        status: 'pending',
      ),
      // Active instance (started but not yet past due)
      TaskInstance(
        id: 'I-active',
        scheduleId: 'S-test-task',
        ruleId: 'R-daily-rule',
        title: 'Test Daily Task',
        description: 'Daily test description',
        scheduledDate: CivilDay(year: 2026, month: 10, day: 26),
        startRelativeTime: startRel,
        dueRelativeTime: dueRel,
        status: 'pending',
      ),
    ];

    testWidgets('renders computed future and past instances correctly', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: SpawnedInstancesList(
                task: dailyTask,
                dbInstances: dbInstances,
                now: now,
              ),
            ),
          ),
        ),
      );

      // Verify Headers
      expect(find.text('Next 10 Occurrences'), findsOneWidget);
      expect(find.text('Last 10 Occurrences'), findsOneWidget);

      // Verify Future Occurrences (dates after Monday Oct 26, 10:00)
      // dailyTask has futureInstancesCount = 3
      // Future dates generated should be Oct 27, 28, 29.
      expect(find.text('Tuesday, October 27, 2026'), findsOneWidget);
      expect(find.text('Wednesday, October 28, 2026'), findsOneWidget);
      expect(find.text('Thursday, October 29, 2026'), findsOneWidget);

      expect(
        find.byKey(const Key('spawned_occurrence_card_0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('spawned_occurrence_card_1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('spawned_occurrence_card_2')),
        findsOneWidget,
      );

      // Verify Past Occurrences
      // Should show the 4 instances in dbInstances:
      // Oct 26 (Active), Oct 24 (Completed), Oct 23 (Skipped), Oct 22 (Missed)
      expect(find.text('Monday, October 26, 2026'), findsOneWidget);
      expect(find.text('Saturday, October 24, 2026'), findsOneWidget);
      expect(find.text('Friday, October 23, 2026'), findsOneWidget);
      expect(find.text('Thursday, October 22, 2026'), findsOneWidget);

      // Verify status text and icons
      expect(
        find.text('Completed: Saturday, October 24, 2026 11:30 AM'),
        findsOneWidget,
      );
      expect(find.text('Skipped'), findsOneWidget);
      expect(
        find.text('Missed (Due: Thursday, October 22, 2026 5:00 PM)'),
        findsOneWidget,
      );
      expect(
        find.text('Active (Due: Monday, October 26, 2026 5:00 PM)'),
        findsOneWidget,
      );

      // Card keys check
      expect(find.byKey(const Key('past_occurrence_card_0')), findsOneWidget);
      expect(find.byKey(const Key('past_occurrence_card_1')), findsOneWidget);
      expect(find.byKey(const Key('past_occurrence_card_2')), findsOneWidget);
      expect(find.byKey(const Key('past_occurrence_card_3')), findsOneWidget);
    });

    testWidgets('renders placeholder when no future or past occurrences', (
      tester,
    ) async {
      final finishedTask = TaskSchedule(
        id: 'S-finished-task',
        title: 'Finished Task',
        description: 'No more occurrences',
        schedules: [
          OneOffSchedule(
            id: 'R-oneoff-rule',
            scheduleId: 'S-finished-task',
            date: CivilDay(year: 2026, month: 10, day: 25), // In the past
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
          ),
        ],
      );

      final futureTask = TaskSchedule(
        id: 'S-future-task',
        title: 'Future Task',
        description: 'Starts in future',
        schedules: [
          DailySchedule(
            id: 'R-daily-future-rule',
            scheduleId: 'S-future-task',
            startDate: CivilDay(year: 2026, month: 11, day: 1), // Future
            interval: 1,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
          ),
        ],
      );

      // Test 1: finishedTask (has past, no future)
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: SpawnedInstancesList(
                task: finishedTask,
                dbInstances: const [],
                now: now,
              ),
            ),
          ),
        ),
      );

      expect(
        find.text(
          'No future occurrences scheduled. Ensure all inputs are valid.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('past_occurrence_card_0')), findsOneWidget);
      expect(find.text('No past occurrences.'), findsNothing);

      // Test 2: futureTask (has future, no past)
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: SpawnedInstancesList(
                task: futureTask,
                dbInstances: const [],
                now: now,
              ),
            ),
          ),
        ),
      );

      expect(
        find.text(
          'No future occurrences scheduled. Ensure all inputs are valid.',
        ),
        findsNothing,
      );
      expect(find.text('No past occurrences.'), findsOneWidget);
    });

    testGoldens('SpawnedInstancesList renders correctly', (tester) async {
      final monthlyTask = TaskSchedule(
        id: 'S-test-task-monthly',
        title: 'Test Monthly Task',
        description: 'Monthly test description',
        schedules: [
          MonthlySchedule(
            id: 'R-monthly-rule',
            scheduleId: 'S-test-task-monthly',
            startDate: CivilDay(year: 2026, month: 10, day: 25),
            interval: 1,
            dayOfMonth: 25,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
          ),
        ],
      );

      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 0.45)
        ..addScenario(
          'SpawnedInstancesList Default with Past and Future',
          Material(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: SingleChildScrollView(
                child: SpawnedInstancesList(
                  task: monthlyTask,
                  dbInstances: dbInstances,
                  now: now,
                ),
              ),
            ),
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(400, 1000),
      );

      await screenMatchesGolden(tester, 'spawned_instances_list_golden');
    });
  });
}
