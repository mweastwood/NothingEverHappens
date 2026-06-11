import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
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
        daysOfWeek: const {1, 3}, // Mon, Wed
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
          daysOfWeek: const {1}, // Mondays
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
          daysOfWeek: const {1, 3}, // Mon, Wed
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

    test(
      'MonthlySchedule checks intervals and dayOfMonth (positive) correctly',
      () {
        const start = CivilDay(year: 2024, month: 1, day: 10);
        final schedule = MonthlySchedule(
          startDate: start,
          interval: 2,
          dayOfMonth: 15,
        );

        expect(
          schedule.occursOn(const CivilDay(year: 2024, month: 1, day: 15)),
          isTrue,
        );
        expect(
          schedule.occursOn(const CivilDay(year: 2024, month: 2, day: 15)),
          isFalse,
        );
        expect(
          schedule.occursOn(const CivilDay(year: 2024, month: 3, day: 15)),
          isTrue,
        );
        expect(
          schedule.occursOn(const CivilDay(year: 2024, month: 3, day: 16)),
          isFalse,
        );
      },
    );

    test(
      'MonthlySchedule checks intervals and dayOfMonth (negative) correctly',
      () {
        const start = CivilDay(year: 2024, month: 1, day: 10);
        final schedule = MonthlySchedule(
          startDate: start,
          interval: 1,
          dayOfMonth: -1,
        );

        expect(
          schedule.occursOn(const CivilDay(year: 2024, month: 1, day: 31)),
          isTrue,
        );
        expect(
          schedule.occursOn(const CivilDay(year: 2024, month: 2, day: 29)),
          isTrue,
        ); // Leap year
        expect(
          schedule.occursOn(const CivilDay(year: 2024, month: 2, day: 28)),
          isFalse,
        );
      },
    );

    test('MonthlySchedule checks nthDayOfWeek correctly', () {
      const start = CivilDay(year: 2024, month: 1, day: 1);
      final schedule = MonthlySchedule(
        startDate: start,
        interval: 1,
        dayOfWeek: 2,
        occurrence: 2,
      );

      expect(
        schedule.occursOn(const CivilDay(year: 2024, month: 1, day: 9)),
        isTrue,
      );
      expect(
        schedule.occursOn(const CivilDay(year: 2024, month: 1, day: 2)),
        isFalse,
      );
      expect(
        schedule.occursOn(const CivilDay(year: 2024, month: 2, day: 13)),
        isTrue,
      );
    });

    test('MonthlySchedule nextOccurrenceAfter works correctly', () {
      const start = CivilDay(year: 2024, month: 1, day: 1);
      final schedule = MonthlySchedule(
        startDate: start,
        interval: 1,
        dayOfMonth: 15,
      );

      expect(
        schedule.nextOccurrenceAfter(
          const CivilDay(year: 2024, month: 1, day: 10),
        ),
        const CivilDay(year: 2024, month: 1, day: 15),
      );
      expect(
        schedule.nextOccurrenceAfter(
          const CivilDay(year: 2024, month: 1, day: 15),
        ),
        const CivilDay(year: 2024, month: 2, day: 15),
      );
    });

    test('MonthlySchedule asserts dayOfMonth ranges correctly', () {
      const start = CivilDay(year: 2024, month: 1, day: 1);

      expect(
        () => MonthlySchedule(startDate: start, interval: 1, dayOfMonth: 1),
        returnsNormally,
      );
      expect(
        () => MonthlySchedule(startDate: start, interval: 1, dayOfMonth: 28),
        returnsNormally,
      );
      expect(
        () => MonthlySchedule(startDate: start, interval: 1, dayOfMonth: -1),
        returnsNormally,
      );
      expect(
        () => MonthlySchedule(startDate: start, interval: 1, dayOfMonth: -28),
        returnsNormally,
      );

      expect(
        () => MonthlySchedule(startDate: start, interval: 1, dayOfMonth: 0),
        throwsAssertionError,
      );
      expect(
        () => MonthlySchedule(startDate: start, interval: 1, dayOfMonth: 29),
        throwsAssertionError,
      );
      expect(
        () => MonthlySchedule(startDate: start, interval: 1, dayOfMonth: -29),
        throwsAssertionError,
      );
    });

    test('YearlySchedule checks intervals, month, and day correctly', () {
      const start = CivilDay(year: 2024, month: 10, day: 24);
      final schedule = YearlySchedule(
        startDate: start,
        interval: 2,
        month: 10,
        day: 24,
      );

      expect(
        schedule.occursOn(const CivilDay(year: 2024, month: 10, day: 24)),
        isTrue,
      );
      expect(
        schedule.occursOn(const CivilDay(year: 2025, month: 10, day: 24)),
        isFalse,
      );
      expect(
        schedule.occursOn(const CivilDay(year: 2026, month: 10, day: 24)),
        isTrue,
      );
      expect(
        schedule.occursOn(const CivilDay(year: 2026, month: 10, day: 25)),
        isFalse,
      );
    });

    test('YearlySchedule nextOccurrenceAfter works correctly', () {
      const start = CivilDay(year: 2024, month: 10, day: 24);
      final schedule = YearlySchedule(
        startDate: start,
        interval: 1,
        month: 10,
        day: 24,
      );

      expect(
        schedule.nextOccurrenceAfter(
          const CivilDay(year: 2024, month: 10, day: 20),
        ),
        const CivilDay(year: 2024, month: 10, day: 24),
      );
      expect(
        schedule.nextOccurrenceAfter(
          const CivilDay(year: 2024, month: 10, day: 24),
        ),
        const CivilDay(year: 2025, month: 10, day: 24),
      );
    });

    test('MonthlySchedule checks last occurrence of dayOfWeek correctly', () {
      const start = CivilDay(year: 2024, month: 1, day: 1);
      final schedule = MonthlySchedule(
        startDate: start,
        interval: 1,
        dayOfWeek: 5, // Friday
        occurrence: -1, // Last
      );

      // January 26, 2024 is the last Friday of January
      expect(
        schedule.occursOn(const CivilDay(year: 2024, month: 1, day: 26)),
        isTrue,
      );
      // January 19, 2024 is NOT the last Friday
      expect(
        schedule.occursOn(const CivilDay(year: 2024, month: 1, day: 19)),
        isFalse,
      );
      // February 23, 2024 is the last Friday of February
      expect(
        schedule.occursOn(const CivilDay(year: 2024, month: 2, day: 23)),
        isTrue,
      );
    });

    test('YearlySchedule nextOccurrenceAfter handles leap years correctly', () {
      const start = CivilDay(year: 2024, month: 2, day: 29);
      final schedule = YearlySchedule(
        startDate: start,
        interval: 1,
        month: 2,
        day: 29,
      );

      // The next leap year after 2024 is 2028
      expect(
        schedule.nextOccurrenceAfter(
          const CivilDay(year: 2024, month: 2, day: 29),
        ),
        const CivilDay(year: 2028, month: 2, day: 29),
      );
    });
  });
}
