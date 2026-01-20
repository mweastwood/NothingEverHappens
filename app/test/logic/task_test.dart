import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task.dart';

void main() {
  group('Recurrence Logic with CivilDay', () {
    test('OneOffSchedule occurs only on the specific date', () {
      const date = CivilDay(year: 2024, month: 1, day: 1);
      final schedule = OneOffSchedule(date: date);

      expect(schedule.occursOn(date), isTrue);
      expect(
        schedule.occursOn(const CivilDay(year: 2024, month: 1, day: 2)),
        isFalse,
      );
    });

    test('DailySchedule checks intervals correctly', () {
      const start = CivilDay(year: 2024, month: 1, day: 1);
      final schedule = DailySchedule(startDate: start, interval: 2);

      expect(schedule.occursOn(start), isTrue);
      expect(
        schedule.occursOn(const CivilDay(year: 2024, month: 1, day: 2)),
        isFalse,
      );
      expect(
        schedule.occursOn(const CivilDay(year: 2024, month: 1, day: 3)),
        isTrue,
      );
    });

    test('WeeklySchedule checks weeks and days correctly', () {
      // Jan 1 2024 is a Monday
      const start = CivilDay(year: 2024, month: 1, day: 1);
      final schedule = WeeklySchedule(
        startDate: start,
        interval: 1,
        daysOfWeek: {1, 3}, // Mon, Wed
      );

      expect(schedule.occursOn(start), isTrue); // Mon
      expect(
        schedule.occursOn(const CivilDay(year: 2024, month: 1, day: 2)),
        isFalse,
      ); // Tue
      expect(
        schedule.occursOn(const CivilDay(year: 2024, month: 1, day: 3)),
        isTrue,
      ); // Wed
    });
  });

  group('Task Properties', () {
    test('isOverdue checks dueFromMidnight correctly', () {
      const todayCivil = CivilDay(year: 2024, month: 1, day: 1);
      final task = Task(
        id: '1',
        title: 'Test',
        description: 'Test',
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 0, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 12, minute: 0),
        ),
        schedule: OneOffSchedule(date: todayCivil),
      );

      // 10:00 AM
      expect(task.isOverdue(DateTime(2024, 1, 1, 10, 0)), isFalse);
      // 13:00 PM
      expect(task.isOverdue(DateTime(2024, 1, 1, 13, 0)), isTrue);
    });
  });
}
