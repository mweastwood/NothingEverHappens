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
}
