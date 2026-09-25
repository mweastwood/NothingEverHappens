import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/calendar_day_task.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';

void main() {
  final march2026 = DateTime(2026, 3, 1);
  const today = CivilDay(year: 2026, month: 3, day: 8);

  final dailySchedule = TaskSchedule(
    id: 'S-daily',
    title: 'Daily Task',
    description: 'Daily recurring schedule',
    priority: TaskPriority.high,
    schedules: [
      DailySchedule(
        id: 'R-daily',
        scheduleId: 'S-daily',
        startDate: const CivilDay(year: 2026, month: 3, day: 1),
        interval: 1,
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 8, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 12, minute: 0),
      ),
    ],
  );

  final sampleInstance = TaskInstance(
    id: 'I-1',
    scheduleId: 'S-daily',
    ruleId: 'R-daily',
    title: 'Daily Task',
    description: 'Daily recurring schedule',
    priority: TaskPriority.high,
    scheduledDate: const CivilDay(year: 2026, month: 3, day: 8),
    startRelativeTime: const RelativeTime(dayOffset: 0, hour: 8, minute: 0),
    dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 12, minute: 0),
    status: TaskStatus.completed,
  );

  final sampleInstancesList = [sampleInstance];
  final sampleSchedulesList = [dailySchedule];

  group('CalendarMonthTaskCache', () {
    test(
      'returns cached month task map on repeated calls with same parameters',
      () {
        final cache = CalendarMonthTaskCache();
        final map1 = cache.getMonthTaskMap(
          monthDate: march2026,
          instances: sampleInstancesList,
          schedules: sampleSchedulesList,
          today: today,
          currentUserId: 'user-1',
        );

        final map2 = cache.getMonthTaskMap(
          monthDate: march2026,
          instances: sampleInstancesList,
          schedules: sampleSchedulesList,
          today: today,
          currentUserId: 'user-1',
        );

        expect(identical(map1, map2), isTrue);
      },
    );

    test('invalidates cache when instances list reference changes', () {
      final cache = CalendarMonthTaskCache();
      final map1 = cache.getMonthTaskMap(
        monthDate: march2026,
        instances: sampleInstancesList,
        schedules: sampleSchedulesList,
        today: today,
        currentUserId: 'user-1',
      );

      final updatedInstance = sampleInstance.copyWith(
        status: TaskStatus.pending,
      );
      final map2 = cache.getMonthTaskMap(
        monthDate: march2026,
        instances: [updatedInstance],
        schedules: sampleSchedulesList,
        today: today,
        currentUserId: 'user-1',
      );

      expect(identical(map1, map2), isFalse);
    });

    test('invalidates cache when schedules list reference changes', () {
      final cache = CalendarMonthTaskCache();
      final map1 = cache.getMonthTaskMap(
        monthDate: march2026,
        instances: sampleInstancesList,
        schedules: sampleSchedulesList,
        today: today,
        currentUserId: 'user-1',
      );

      final map2 = cache.getMonthTaskMap(
        monthDate: march2026,
        instances: sampleInstancesList,
        schedules: [
          dailySchedule,
          TaskSchedule(
            id: 'S-another',
            title: 'Another task',
            description: 'Another description',
            priority: TaskPriority.low,
            schedules: const [],
          ),
        ],
        today: today,
        currentUserId: 'user-1',
      );

      expect(identical(map1, map2), isFalse);
    });

    test('invalidates cache when user ID changes', () {
      final cache = CalendarMonthTaskCache();
      final map1 = cache.getMonthTaskMap(
        monthDate: march2026,
        instances: sampleInstancesList,
        schedules: sampleSchedulesList,
        today: today,
        currentUserId: 'user-1',
      );

      final map2 = cache.getMonthTaskMap(
        monthDate: march2026,
        instances: sampleInstancesList,
        schedules: sampleSchedulesList,
        today: today,
        currentUserId: 'user-2',
      );

      expect(identical(map1, map2), isFalse);
    });

    test('clear() empties the cache', () {
      final cache = CalendarMonthTaskCache();
      final map1 = cache.getMonthTaskMap(
        monthDate: march2026,
        instances: sampleInstancesList,
        schedules: sampleSchedulesList,
        today: today,
        currentUserId: 'user-1',
      );

      cache.clear();

      final map2 = cache.getMonthTaskMap(
        monthDate: march2026,
        instances: sampleInstancesList,
        schedules: sampleSchedulesList,
        today: today,
        currentUserId: 'user-1',
      );

      expect(identical(map1, map2), isFalse);
      expect(map1.length, equals(map2.length));
    });
  });

  group('computeMonthTaskMap', () {
    final completionRelativeDailySchedule = TaskSchedule(
      id: 'S-completion-rel-daily',
      title: 'Water plants (Completion Relative)',
      description: 'Water every 3 days after completion',
      priority: TaskPriority.medium,
      schedules: [
        DailySchedule(
          id: 'R-completion-rel-daily',
          scheduleId: 'S-completion-rel-daily',
          startDate: const CivilDay(year: 2026, month: 3, day: 1),
          interval: 3,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 9,
            minute: 0,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 18,
            minute: 0,
          ),
          schedulingPolicy: const CompletionRelativePolicy(
            interval: Duration(days: 3),
            targetHour: 9,
            targetMinute: 0,
          ),
        ),
      ],
    );

    final completionRelativeWeeklySchedule = TaskSchedule(
      id: 'S-completion-rel-weekly',
      title: 'Mow lawn (Completion Relative Weekly)',
      description: 'Mow lawn every 1 week after completion',
      priority: TaskPriority.low,
      schedules: [
        WeeklySchedule(
          id: 'R-completion-rel-weekly',
          scheduleId: 'S-completion-rel-weekly',
          startDate: const CivilDay(year: 2026, month: 3, day: 1),
          interval: 1,
          daysOfWeek: {1},
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 10,
            minute: 0,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 16,
            minute: 0,
          ),
          schedulingPolicy: const CompletionRelativePolicy(
            interval: Duration(days: 7),
            targetHour: 10,
            targetMinute: 0,
          ),
        ),
      ],
    );

    final fixedRecurringSchedule = TaskSchedule(
      id: 'S-fixed-recurring',
      title: 'Daily vitamins (Fixed Calendar)',
      description: 'Take daily vitamins',
      priority: TaskPriority.high,
      schedules: [
        DailySchedule(
          id: 'R-fixed-recurring',
          scheduleId: 'S-fixed-recurring',
          startDate: const CivilDay(year: 2026, month: 3, day: 1),
          interval: 1,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 8,
            minute: 0,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 12,
            minute: 0,
          ),
          schedulingPolicy: const FixedCalendarPolicy(),
        ),
      ],
    );

    test(
      'suppresses projected occurrences across the month for completion-relative schedules when no instances exist',
      () {
        final map = computeMonthTaskMap(
          monthDate: march2026,
          instances: const [],
          schedules: [
            completionRelativeDailySchedule,
            completionRelativeWeeklySchedule,
          ],
          today: today,
        );

        // Completion-relative tasks have non-deterministic future dates and must never project phantom tasks.
        final allTasks = map.values.expand((tasks) => tasks).toList();
        expect(allTasks, isEmpty);
      },
    );

    test(
      'retains active/concrete instances for completion-relative schedules without projecting future phantom occurrences',
      () {
        final concreteInstance = TaskInstance(
          id: 'I-rel-1',
          scheduleId: 'S-completion-rel-daily',
          ruleId: 'R-completion-rel-daily',
          title: 'Water plants (Completion Relative)',
          description: 'Water every 3 days after completion',
          priority: TaskPriority.medium,
          scheduledDate: const CivilDay(year: 2026, month: 3, day: 10),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 9,
            minute: 0,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 18,
            minute: 0,
          ),
          status: TaskStatus.pending,
        );

        final map = computeMonthTaskMap(
          monthDate: march2026,
          instances: [concreteInstance],
          schedules: [completionRelativeDailySchedule],
          today: today,
        );

        // March 10 should have the concrete instance
        final tasksOnMarch10 =
            map[const CivilDay(year: 2026, month: 3, day: 10)] ?? [];
        expect(tasksOnMarch10, hasLength(1));
        expect(tasksOnMarch10.first.id, equals('I-rel-1'));
        expect(tasksOnMarch10.first.isInstance, isTrue);

        // No projected tasks should exist on any other day of the month
        final allTasks = map.values.expand((tasks) => tasks).toList();
        expect(allTasks, hasLength(1));
        expect(allTasks.first.id, equals('I-rel-1'));
      },
    );

    test(
      'continues to project recurring occurrences for fixed calendar schedules',
      () {
        final map = computeMonthTaskMap(
          monthDate: march2026,
          instances: const [],
          schedules: [fixedRecurringSchedule],
          today: today,
        );

        // Days from today (March 8) through end of March (31) should have projected occurrences
        for (int day = 8; day <= 31; day++) {
          final dayTasks = map[CivilDay(year: 2026, month: 3, day: day)] ?? [];
          expect(dayTasks, hasLength(1));
          expect(dayTasks.first.isInstance, isFalse);
          expect(dayTasks.first.schedule?.id, equals('S-fixed-recurring'));
        }
      },
    );
  });
}
