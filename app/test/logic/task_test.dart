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

    test(
      'DailySchedule occursOn works across Spring forward DST boundary (March 9, 2026)',
      () {
        // US Spring forward transition is March 8, 2026.
        const start = CivilDay(year: 2026, month: 3, day: 8);
        final schedule = DailySchedule(startDate: start, interval: 2);

        // On March 8: difference in days = 0. Modulo 2 = 0 -> true
        expect(schedule.occursOn(start), isTrue);

        // On March 9: difference in days = 1. Modulo 2 = 1 -> false
        expect(
          schedule.occursOn(const CivilDay(year: 2026, month: 3, day: 9)),
          isFalse,
        );

        // On March 10 (across DST): difference in days = 2. Modulo 2 = 0 -> true
        expect(
          schedule.occursOn(const CivilDay(year: 2026, month: 3, day: 10)),
          isTrue,
        );
      },
    );

    test(
      'WeeklySchedule occursOn works across Spring forward DST boundary (March 9, 2026)',
      () {
        // US Spring forward transition is March 8, 2026.
        // March 2, 2026 is Monday.
        const start = CivilDay(year: 2026, month: 3, day: 2);
        final schedule = WeeklySchedule(
          startDate: start,
          interval: 2, // Repeats every 2 weeks
          daysOfWeek: {1}, // Mondays
        );

        expect(schedule.occursOn(start), isTrue); // Mon March 2

        // Mon March 9 (1 week later, across DST on March 8) -> false (interval is 2 weeks)
        expect(
          schedule.occursOn(const CivilDay(year: 2026, month: 3, day: 9)),
          isFalse,
        );

        // Mon March 16 (2 weeks later, across DST) -> true
        expect(
          schedule.occursOn(const CivilDay(year: 2026, month: 3, day: 16)),
          isTrue,
        );
      },
    );

    test(
      'DailySchedule nextOccurrenceAfter calculates next occurrence correctly',
      () {
        const start = CivilDay(year: 2026, month: 3, day: 8);
        final schedule = DailySchedule(startDate: start, interval: 2);

        expect(
          schedule.nextOccurrenceAfter(
            const CivilDay(year: 2026, month: 3, day: 8),
          ),
          const CivilDay(year: 2026, month: 3, day: 10),
        );

        expect(
          schedule.nextOccurrenceAfter(
            const CivilDay(year: 2026, month: 3, day: 9),
          ),
          const CivilDay(year: 2026, month: 3, day: 10),
        );

        expect(
          schedule.nextOccurrenceAfter(
            const CivilDay(year: 2026, month: 3, day: 10),
          ),
          const CivilDay(year: 2026, month: 3, day: 12),
        );
      },
    );

    test(
      'WeeklySchedule nextOccurrenceAfter calculates next occurrence correctly',
      () {
        const start = CivilDay(year: 2026, month: 3, day: 2);
        final schedule = WeeklySchedule(
          startDate: start,
          interval: 1,
          daysOfWeek: {1, 3}, // Mon, Wed
        );

        // March 2 is Monday. Next is March 4 Wednesday
        expect(
          schedule.nextOccurrenceAfter(
            const CivilDay(year: 2026, month: 3, day: 2),
          ),
          const CivilDay(year: 2026, month: 3, day: 4),
        );

        // Next after March 3 is March 4 Wednesday
        expect(
          schedule.nextOccurrenceAfter(
            const CivilDay(year: 2026, month: 3, day: 3),
          ),
          const CivilDay(year: 2026, month: 3, day: 4),
        );

        // Next after March 4 Wednesday is March 9 Monday
        expect(
          schedule.nextOccurrenceAfter(
            const CivilDay(year: 2026, month: 3, day: 4),
          ),
          const CivilDay(year: 2026, month: 3, day: 9),
        );
      },
    );
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
