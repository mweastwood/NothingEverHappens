import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/widgets/spawned_future_instances_list.dart';
import '../test_helper.dart';

void main() {
  group('SpawnedFutureInstancesList', () {
    final now = DateTime(2026, 10, 26, 10, 0); // Monday

    final dailyTask = TaskSchedule(
      id: 'S-test-task',
      title: 'Test Daily Task',
      description: 'Daily test description',
      futureInstancesCount: 3,
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

    testWidgets('renders computed spawned instances correctly', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: SpawnedFutureInstancesList(
                task: dailyTask,
                dbInstances: const [],
                now: now,
              ),
            ),
          ),
        ),
      );

      // The DailyTask starts on 2026-10-25.
      // now is 2026-10-26 10:00.
      // The instance for 2026-10-26 started at 9:00, which is in the past.
      // The future instances to spawn will be for:
      // - 2026-10-27
      // - 2026-10-28
      // - 2026-10-29
      expect(find.text('Next 10 Occurrences'), findsOneWidget);
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
    });

    testWidgets('renders placeholder when no occurrences', (tester) async {
      final finishedTask = TaskSchedule(
        id: 'S-finished-task',
        title: 'Finished Task',
        description: 'No more occurrences',
        futureInstancesCount: 3,
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

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SpawnedFutureInstancesList(
              task: finishedTask,
              dbInstances: const [],
              now: now,
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
    });

    testGoldens('SpawnedFutureInstancesList renders correctly', (tester) async {
      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 1.2)
        ..addScenario(
          'SpawnedFutureInstancesList Default',
          Material(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: SpawnedFutureInstancesList(
                task: dailyTask,
                dbInstances: const [],
                now: now,
              ),
            ),
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(400, 500),
      );

      await screenMatchesGolden(tester, 'spawned_future_instances_list_golden');
    });
  });
}
