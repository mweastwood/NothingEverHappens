import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('SchedulerEngine Core Tests', () {
    test('evaluates daily task and spawns instances', () {
      final today = CivilDay(year: 2026, month: 9, day: 8);
      final now = DateTime(2026, 9, 8, 8, 0);

      final task = TaskSchedule(
        id: 'task-1',
        title: 'Daily Task',
        description: 'Test task',
        schedules: [
          DailySchedule(
            startDate: today,
            interval: 1,
            startRelativeTime: const RelativeTime(hour: 9, minute: 0),
            dueRelativeTime: const RelativeTime(hour: 17, minute: 0),
          ),
        ],
      );

      final action = const SchedulerEngine().evaluate(task, [], now);
      expect(action.instancesToSpawn, isNotEmpty);
      expect(action.instancesToSpawn.first.title, equals('Daily Task'));
      expect(action.instancesToSpawn.first.scheduledDate, equals(today));
      expect(action.instancesToSpawn.first.status, equals(TaskStatus.pending));
    });

    test('evaluates completion relative scheduling', () {
      final today = CivilDay(year: 2026, month: 9, day: 8);
      final completedAt = DateTime(2026, 9, 8, 10, 0);
      final now = DateTime(2026, 9, 10, 12, 0); // 2 days later

      final task = TaskSchedule(
        id: 'task-cr',
        title: 'Completion Relative Task',
        description: 'Test task',
        schedules: [
          DailySchedule(
            startDate: today,
            interval: 2,
            startRelativeTime: const RelativeTime(hour: 9, minute: 0),
            dueRelativeTime: const RelativeTime(hour: 17, minute: 0),
            schedulingPolicy: const CompletionRelativePolicy(
              interval: Duration(days: 2),
              targetHour: 9,
              targetMinute: 0,
            ),
          ),
        ],
      );

      final completedInst = TaskInstance(
        id: 'inst-completed',
        scheduleId: task.id,
        ruleId: task.schedules.first.id,
        title: task.title,
        description: task.description,
        scheduledDate: today,
        startRelativeTime: const RelativeTime(hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(hour: 17, minute: 0),
        status: TaskStatus.completed,
        completedAt: completedAt,
      );

      final action =
          const SchedulerEngine().evaluate(task, [completedInst], now);
      expect(action.instancesToSpawn, hasLength(1));
      expect(
        action.instancesToSpawn.first.scheduledDate,
        equals(CivilDay(year: 2026, month: 9, day: 10)),
      );
    });

    test('evaluates completion relative scheduling when occurrence is skipped',
        () {
      final today = CivilDay(year: 2026, month: 9, day: 8);
      final skippedAt = DateTime(2026, 9, 8, 10, 0);
      final now = DateTime(2026, 9, 10, 12, 0); // 2 days later

      final task = TaskSchedule(
        id: 'task-cr',
        title: 'Completion Relative Task',
        description: 'Test task',
        schedules: [
          DailySchedule(
            startDate: today,
            interval: 2,
            startRelativeTime: const RelativeTime(hour: 9, minute: 0),
            dueRelativeTime: const RelativeTime(hour: 17, minute: 0),
            schedulingPolicy: const CompletionRelativePolicy(
              interval: Duration(days: 2),
              targetHour: 9,
              targetMinute: 0,
            ),
          ),
        ],
      );

      final skippedInst = TaskInstance(
        id: 'inst-skipped',
        scheduleId: task.id,
        ruleId: task.schedules.first.id,
        title: task.title,
        description: task.description,
        scheduledDate: today,
        startRelativeTime: const RelativeTime(hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(hour: 17, minute: 0),
        status: TaskStatus.skipped,
        completedAt: null,
        updatedAt: skippedAt,
      );

      final action = const SchedulerEngine().evaluate(task, [skippedInst], now);
      expect(action.instancesToSpawn, hasLength(1));
      expect(
        action.instancesToSpawn.first.scheduledDate,
        equals(CivilDay(year: 2026, month: 9, day: 10)),
      );
    });

    test(
        'evaluates completion relative scheduling ordering when older completed instance exists before skipped instance',
        () {
      final startDate = CivilDay(year: 2026, month: 9, day: 1);
      final completedAt = DateTime(2026, 9, 1, 10, 0);
      final skippedAt = DateTime(2026, 9, 8, 10, 0);
      final now = DateTime(2026, 9, 10, 12, 0);

      final task = TaskSchedule(
        id: 'task-cr',
        title: 'Completion Relative Task',
        description: 'Test task',
        schedules: [
          DailySchedule(
            startDate: startDate,
            interval: 2,
            startRelativeTime: const RelativeTime(hour: 9, minute: 0),
            dueRelativeTime: const RelativeTime(hour: 17, minute: 0),
            schedulingPolicy: const CompletionRelativePolicy(
              interval: Duration(days: 2),
              targetHour: 9,
              targetMinute: 0,
            ),
          ),
        ],
      );

      final olderCompletedInst = TaskInstance(
        id: 'inst-1',
        scheduleId: task.id,
        ruleId: task.schedules.first.id,
        title: task.title,
        description: task.description,
        scheduledDate: startDate,
        startRelativeTime: const RelativeTime(hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(hour: 17, minute: 0),
        status: TaskStatus.completed,
        completedAt: completedAt,
        updatedAt: completedAt,
      );

      final newerSkippedInst = TaskInstance(
        id: 'inst-2',
        scheduleId: task.id,
        ruleId: task.schedules.first.id,
        title: task.title,
        description: task.description,
        scheduledDate: CivilDay(year: 2026, month: 9, day: 8),
        startRelativeTime: const RelativeTime(hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(hour: 17, minute: 0),
        status: TaskStatus.skipped,
        completedAt: null,
        updatedAt: skippedAt,
      );

      final action = const SchedulerEngine()
          .evaluate(task, [olderCompletedInst, newerSkippedInst], now);
      expect(action.instancesToSpawn, hasLength(1));
      expect(
        action.instancesToSpawn.first.scheduledDate,
        equals(CivilDay(year: 2026, month: 9, day: 10)),
      );
    });

    test('spawned instances inherit labelIds from parent schedule', () {
      final today = CivilDay(year: 2026, month: 9, day: 8);
      final now = DateTime(2026, 9, 8, 8, 0);

      final task = TaskSchedule(
        id: 'task-labels',
        title: 'Labeled Daily Task',
        description: 'Test task',
        labelIds: const ['L-cleaning', 'L-urgent'],
        schedules: [
          DailySchedule(
            startDate: today,
            interval: 1,
            startRelativeTime: const RelativeTime(hour: 9, minute: 0),
            dueRelativeTime: const RelativeTime(hour: 17, minute: 0),
          ),
        ],
      );

      final action = const SchedulerEngine().evaluate(task, [], now);
      expect(action.instancesToSpawn, isNotEmpty);
      for (final inst in action.instancesToSpawn) {
        expect(inst.labelIds, equals(['L-cleaning', 'L-urgent']));
      }

      final oneOffTask = TaskSchedule(
        id: 'task-oneoff',
        title: 'One-off Task',
        description: 'Desc',
        labelIds: const ['L-groceries'],
        schedules: [
          OneOffSchedule(
            date: today,
            startRelativeTime: const RelativeTime(hour: 10, minute: 0),
            dueRelativeTime: const RelativeTime(hour: 12, minute: 0),
          ),
        ],
      );

      final oneOffAction =
          const SchedulerEngine().evaluate(oneOffTask, [], now);
      expect(oneOffAction.instancesToSpawn, isNotEmpty);
      expect(
        oneOffAction.instancesToSpawn.first.labelIds,
        equals(['L-groceries']),
      );
    });
  });
}
