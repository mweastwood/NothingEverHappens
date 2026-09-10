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
  });
}
