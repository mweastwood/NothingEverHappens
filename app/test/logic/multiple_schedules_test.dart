import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';

void main() {
  group('Multiple Schedules & Standardized Timing Unit Tests', () {
    test('TaskSchedule can be constructed with multiple mixed schedules', () {
      final startCivil = const CivilDay(year: 2026, month: 6, day: 1);
      final schedules = [
        DailySchedule(
          startDate: startCivil,
          interval: 1,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 9,
            minute: 0,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 17,
            minute: 0,
          ),
        ),
        WeeklySchedule(
          startDate: startCivil,
          interval: 1,
          daysOfWeek: const {1, 5},
          startRelativeTime: const RelativeTime(
            dayOffset: -1,
            hour: 18,
            minute: 0,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 1,
            hour: 12,
            minute: 0,
          ),
          notificationRelativeTimes: const [
            RelativeTime(dayOffset: 0, hour: 8, minute: 0),
          ],
        ),
      ];

      final task = TaskSchedule(
        id: 'mixed-task',
        title: 'Mixed Scheduling TaskSchedule',
        description: 'Testing mixed scheduling',
        schedules: schedules,
      );

      expect(task.schedules.length, 2);
      expect(task.schedules[0], isA<DailySchedule>());
      expect(task.schedules[1], isA<WeeklySchedule>());

      // Verify standardized timing properties inside each schedule
      expect(task.schedules[0].startRelativeTime.time.hour, 9);
      expect(task.schedules[0].dueRelativeTime.time.hour, 17);
      expect(task.schedules[0].dueRelativeTime.dayOffset, 0);

      expect(task.schedules[1].startRelativeTime.dayOffset, -1);
      expect(task.schedules[1].dueRelativeTime.dayOffset, 1);
      expect(task.schedules[1].dueRelativeTime.time.hour, 12);
      expect(task.schedules[1].notificationRelativeTimes.first.time.hour, 8);
    });
  });
}
