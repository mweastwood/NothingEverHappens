import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('SchedulerMissedPolicyEvaluator', () {
    const evaluator = SchedulerMissedPolicyEvaluator(
      appVersion: '1.0.0',
      platform: 'test',
    );
    final now = DateTime.utc(2026, 3, 10, 12, 0);
    const today = CivilDay(year: 2026, month: 3, day: 10);
    const day8 = CivilDay(year: 2026, month: 3, day: 8);
    const day9 = CivilDay(year: 2026, month: 3, day: 9);

    TaskInstance makeInstance(
      String id,
      CivilDay date, {
      TaskStatus status = TaskStatus.pending,
    }) {
      return TaskInstance(
        id: id,
        scheduleId: 'S-1',
        ruleId: 'R-1',
        title: 'Daily Task',
        description: '',
        scheduledDate: date,
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
        status: status,
        updatedAt: DateTime.utc(2026, 3, 1, 0, 0),
      );
    }

    test('preferNewer skips older started instances and keeps latest active',
        () {
      final rule = DailySchedule(
        id: 'R-1',
        scheduleId: 'S-1',
        startDate: day8,
        interval: 1,
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
        missedOccurrencePolicy: const MissedOccurrencePolicy(
          policy: MissedPolicy.preferNewer,
        ),
      );
      final task = TaskSchedule(
        id: 'S-1',
        title: 'Daily Task',
        description: '',
        schedules: [rule],
      );
      final inst8 = makeInstance('I-8', day8);
      final inst9 = makeInstance('I-9', day9);
      final inst10 = makeInstance('I-10', today);
      final working = {day8: inst8, day9: inst9, today: inst10};
      final context = SchedulerEvaluationContext(
        task: task,
        taskInstances: [inst8, inst9, inst10],
        now: now,
        today: today,
      );

      final hasNewSkipped = evaluator.applyMissedPolicy(
        working,
        [inst8, inst9, inst10],
        [day8, day9, today],
        rule,
        context,
      );

      expect(hasNewSkipped, isTrue);
      expect(working[day8]!.status, TaskStatus.skipped);
      expect(working[day9]!.status, TaskStatus.skipped);
      expect(working[today]!.status, TaskStatus.pending);
    });

    test(
        'preferOlder keeps earliest started instance and skips newer started ones',
        () {
      final rule = DailySchedule(
        id: 'R-1',
        scheduleId: 'S-1',
        startDate: day8,
        interval: 1,
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
        missedOccurrencePolicy: const MissedOccurrencePolicy(
          policy: MissedPolicy.preferOlder,
        ),
      );
      final task = TaskSchedule(
        id: 'S-1',
        title: 'Daily Task',
        description: '',
        schedules: [rule],
      );
      final inst8 = makeInstance('I-8', day8);
      final inst9 = makeInstance('I-9', day9);
      final inst10 = makeInstance('I-10', today);
      final working = {day8: inst8, day9: inst9, today: inst10};
      final context = SchedulerEvaluationContext(
        task: task,
        taskInstances: [inst8, inst9, inst10],
        now: now,
        today: today,
      );

      final hasNewSkipped = evaluator.applyMissedPolicy(
        working,
        [inst8, inst9, inst10],
        [day8, day9, today],
        rule,
        context,
      );

      expect(hasNewSkipped, isTrue);
      expect(working[day8]!.status, TaskStatus.pending);
      expect(working[day9]!.status, TaskStatus.skipped);
      expect(working[today]!.status, TaskStatus.skipped);
    });
  });

  group('SchedulerCapacityFilter', () {
    const filter = SchedulerCapacityFilter(
      appVersion: '1.0.0',
      platform: 'test',
    );
    final now = DateTime.utc(2026, 3, 10, 8, 0);
    const today = CivilDay(year: 2026, month: 3, day: 10);
    const tomorrow = CivilDay(year: 2026, month: 3, day: 11);

    test(
        'skips spawned instance when remaining capacity is insufficient and revives when disabled',
        () {
      final task = TaskSchedule(
        id: 'S-cap',
        title: 'Capacity Task',
        description: '',
        skipIfNoCapacity: true,
        estimatedDuration: const Duration(hours: 2),
        schedules: [
          DailySchedule(
            id: 'R-cap',
            scheduleId: 'S-cap',
            startDate: today,
            interval: 1,
            startRelativeTime:
                const RelativeTime(dayOffset: 0, hour: 10, minute: 0),
            dueRelativeTime:
                const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
          ),
        ],
      );
      final candidate = TaskInstance(
        id: 'I-cap-1',
        scheduleId: 'S-cap',
        ruleId: 'R-cap',
        title: 'Capacity Task',
        description: '',
        scheduledDate: tomorrow,
        startRelativeTime:
            const RelativeTime(dayOffset: 0, hour: 10, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
        status: TaskStatus.pending,
      );

      final context = SchedulerEvaluationContext(
        task: task,
        taskInstances: const [],
        now: now,
        today: today,
        userSettings: const UserSettings(hoursAvailable: 2.0),
        dayPlannedHours: {tomorrow: 1.0},
      );

      final skippedResult = filter.applyCapacityLimits(
        context,
        toSpawn: [candidate],
      );
      expect(skippedResult.finalToSpawn.single.status, TaskStatus.skipped);
      expect(
        skippedResult.finalToSpawn.single.statusReason,
        InstanceStatusReason.schedulerCapacityLimit.value,
      );

      final disabledContext = SchedulerEvaluationContext(
        task: task.copyWith(skipIfNoCapacity: false),
        taskInstances: [skippedResult.finalToSpawn.single],
        now: now,
        today: today,
      );
      final revivedResult = filter.applyCapacityLimits(
        disabledContext,
        toSpawn: const [],
      );
      expect(revivedResult.finalToUpdate.single.status, TaskStatus.pending);
      expect(revivedResult.finalToUpdate.single.statusReason, isNull);
    });
  });

  group('SchedulerOccurrenceProjector', () {
    const projector = SchedulerOccurrenceProjector();

    test(
        'projects fixed daily occurrences and matches rule index with fallback',
        () {
      final rule1 = DailySchedule(
        id: 'R-1',
        scheduleId: 'S-1',
        startDate: const CivilDay(year: 2026, month: 3, day: 1),
        interval: 2,
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
      );
      final rule2 = DailySchedule(
        id: 'R-2',
        scheduleId: 'S-1',
        startDate: const CivilDay(year: 2026, month: 3, day: 2),
        interval: 2,
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
      );
      final task = TaskSchedule(
        id: 'S-1',
        title: 'Multi Rule Task',
        description: '',
        schedules: [rule1, rule2],
      );

      final projected = projector.projectUpcomingOccurrences(
        task,
        rule1,
        const CivilDay(year: 2026, month: 3, day: 2),
        count: 3,
      );
      expect(projected, const [
        CivilDay(year: 2026, month: 3, day: 3),
        CivilDay(year: 2026, month: 3, day: 5),
        CivilDay(year: 2026, month: 3, day: 7),
      ]);

      final legacyInstance = TaskInstance(
        id: 'I-legacy_1',
        scheduleId: 'S-1',
        ruleId: 'unknown',
        title: 'Multi Rule Task',
        description: '',
        scheduledDate: const CivilDay(year: 2026, month: 3, day: 2),
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
      );
      expect(
        SchedulerOccurrenceProjector.ruleIndexOfInstance(task, legacyInstance),
        1,
      );
    });
  });
}
