import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';

void main() {
  const testStart = RelativeTime(
    dayOffset: 0,
    time: TimeOfDay(hour: 9, minute: 0),
  );
  const testDue = RelativeTime(
    dayOffset: 0,
    time: TimeOfDay(hour: 17, minute: 0),
  );

  group('Recurrence Logic with CivilDay', () {
    test('OneOffSchedule occurs only on the specific date', () {
      const date = CivilDay(year: 2024, month: 1, day: 1);
      final schedule = OneOffSchedule(
        date: date,
        startRelativeTime: testStart,
        dueRelativeTime: testDue,
      );

      expect(schedule.occursOn(date), isTrue);
      expect(
        schedule.occursOn(const CivilDay(year: 2024, month: 1, day: 2)),
        isFalse,
      );
    });

    test('DailySchedule checks intervals correctly', () {
      const start = CivilDay(year: 2024, month: 1, day: 1);
      final schedule = DailySchedule(
        startDate: start,
        interval: 2,
        startRelativeTime: testStart,
        dueRelativeTime: testDue,
      );

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
        startRelativeTime: testStart,
        dueRelativeTime: testDue,
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
        final schedule = DailySchedule(
          startDate: start,
          interval: 2,
          startRelativeTime: testStart,
          dueRelativeTime: testDue,
        );

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
          startRelativeTime: testStart,
          dueRelativeTime: testDue,
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
        final schedule = DailySchedule(
          startDate: start,
          interval: 2,
          startRelativeTime: testStart,
          dueRelativeTime: testDue,
        );

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
          startRelativeTime: testStart,
          dueRelativeTime: testDue,
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
          startRelativeTime: testStart,
          dueRelativeTime: testDue,
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
          startRelativeTime: testStart,
          dueRelativeTime: testDue,
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
        startRelativeTime: testStart,
        dueRelativeTime: testDue,
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
        startRelativeTime: testStart,
        dueRelativeTime: testDue,
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
        () => MonthlySchedule(
          startDate: start,
          interval: 1,
          dayOfMonth: 1,
          startRelativeTime: testStart,
          dueRelativeTime: testDue,
        ),
        returnsNormally,
      );
      expect(
        () => MonthlySchedule(
          startDate: start,
          interval: 1,
          dayOfMonth: 28,
          startRelativeTime: testStart,
          dueRelativeTime: testDue,
        ),
        returnsNormally,
      );
      expect(
        () => MonthlySchedule(
          startDate: start,
          interval: 1,
          dayOfMonth: -1,
          startRelativeTime: testStart,
          dueRelativeTime: testDue,
        ),
        returnsNormally,
      );
      expect(
        () => MonthlySchedule(
          startDate: start,
          interval: 1,
          dayOfMonth: -28,
          startRelativeTime: testStart,
          dueRelativeTime: testDue,
        ),
        returnsNormally,
      );

      expect(
        () => MonthlySchedule(
          startDate: start,
          interval: 1,
          dayOfMonth: 0,
          startRelativeTime: testStart,
          dueRelativeTime: testDue,
        ),
        throwsAssertionError,
      );
      expect(
        () => MonthlySchedule(
          startDate: start,
          interval: 1,
          dayOfMonth: 29,
          startRelativeTime: testStart,
          dueRelativeTime: testDue,
        ),
        throwsAssertionError,
      );
      expect(
        () => MonthlySchedule(
          startDate: start,
          interval: 1,
          dayOfMonth: -29,
          startRelativeTime: testStart,
          dueRelativeTime: testDue,
        ),
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
        startRelativeTime: testStart,
        dueRelativeTime: testDue,
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
        startRelativeTime: testStart,
        dueRelativeTime: testDue,
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
        startRelativeTime: testStart,
        dueRelativeTime: testDue,
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
        startRelativeTime: testStart,
        dueRelativeTime: testDue,
      );

      // The next leap year after 2024 is 2028
      expect(
        schedule.nextOccurrenceAfter(
          const CivilDay(year: 2024, month: 2, day: 29),
        ),
        const CivilDay(year: 2028, month: 2, day: 29),
      );
    });

    test('OneOffSchedule nextOccurrenceAfter boundary tests', () {
      const date = CivilDay(year: 2026, month: 6, day: 1);
      final schedule = OneOffSchedule(
        date: date,
        startRelativeTime: testStart,
        dueRelativeTime: testDue,
      );

      // returns null on or after the scheduled date
      expect(
        schedule.nextOccurrenceAfter(
          const CivilDay(year: 2026, month: 6, day: 1),
        ),
        isNull,
      );
      // returns scheduled date if reference is before it
      expect(
        schedule.nextOccurrenceAfter(
          const CivilDay(year: 2026, month: 5, day: 31),
        ),
        const CivilDay(year: 2026, month: 6, day: 1),
      );
      // returns null after the scheduled date
      expect(
        schedule.nextOccurrenceAfter(
          const CivilDay(year: 2026, month: 6, day: 2),
        ),
        isNull,
      );
    });

    test('DailySchedule occursOn with large interval (e.g. 100 days)', () {
      const start = CivilDay(year: 2026, month: 1, day: 1);
      final schedule = DailySchedule(
        startDate: start,
        interval: 100,
        startRelativeTime: testStart,
        dueRelativeTime: testDue,
      );

      expect(
        schedule.occursOn(const CivilDay(year: 2026, month: 1, day: 1)),
        isTrue,
      );
      expect(
        schedule.occursOn(const CivilDay(year: 2026, month: 1, day: 2)),
        isFalse,
      );
      // 100 days after Jan 1: Jan has 31 days, Feb has 28 days (2026 is non-leap), Mar has 31 days.
      // Jan 1 + 100 days = April 11 (30 days left in Jan, 28 in Feb, 31 in Mar -> 30+28+31 = 89 days, so 11 days into April).
      expect(
        schedule.occursOn(const CivilDay(year: 2026, month: 4, day: 11)),
        isTrue,
      );
      expect(
        schedule.nextOccurrenceAfter(
          const CivilDay(year: 2026, month: 1, day: 2),
        ),
        const CivilDay(year: 2026, month: 4, day: 11),
      );
    });

    test(
      'WeeklySchedule with empty daysOfWeek throws exception on nextOccurrenceAfter',
      () {
        const start = CivilDay(year: 2026, month: 6, day: 1);
        final schedule = WeeklySchedule(
          startDate: start,
          interval: 1,
          daysOfWeek: const {},
          startRelativeTime: testStart,
          dueRelativeTime: testDue,
        );

        expect(
          () => schedule.nextOccurrenceAfter(start),
          throwsA(isA<Exception>()),
        );
      },
    );

    test(
      'WeeklySchedule occursOn and nextOccurrenceAfter bi-weekly with multiple weekdays',
      () {
        // June 1, 2026 is a Monday (weekday = 1)
        const start = CivilDay(year: 2026, month: 6, day: 1);
        final schedule = WeeklySchedule(
          startDate: start,
          interval: 2,
          daysOfWeek: const {1, 3}, // Mon, Wed
          startRelativeTime: testStart,
          dueRelativeTime: testDue,
        );

        // Week 1 (Monday June 1 to Sunday June 7):
        expect(
          schedule.occursOn(const CivilDay(year: 2026, month: 6, day: 1)),
          isTrue,
        ); // Mon
        expect(
          schedule.occursOn(const CivilDay(year: 2026, month: 6, day: 3)),
          isTrue,
        ); // Wed
        expect(
          schedule.occursOn(const CivilDay(year: 2026, month: 6, day: 5)),
          isFalse,
        ); // Fri

        // Week 2 (Monday June 8 to Sunday June 14) - should NOT occur since interval = 2
        expect(
          schedule.occursOn(const CivilDay(year: 2026, month: 6, day: 8)),
          isFalse,
        );
        expect(
          schedule.occursOn(const CivilDay(year: 2026, month: 6, day: 10)),
          isFalse,
        );

        // Week 3 (Monday June 15 to Sunday June 21) - should occur
        expect(
          schedule.occursOn(const CivilDay(year: 2026, month: 6, day: 15)),
          isTrue,
        );
        expect(
          schedule.occursOn(const CivilDay(year: 2026, month: 6, day: 17)),
          isTrue,
        );

        // nextOccurrenceAfter checks
        expect(
          schedule.nextOccurrenceAfter(
            const CivilDay(year: 2026, month: 6, day: 1),
          ),
          const CivilDay(year: 2026, month: 6, day: 3),
        );
        expect(
          schedule.nextOccurrenceAfter(
            const CivilDay(year: 2026, month: 6, day: 3),
          ),
          const CivilDay(year: 2026, month: 6, day: 15),
        );
      },
    );

    test(
      'MonthlySchedule occursOn and nextOccurrenceAfter negative dayOfMonth boundary tests',
      () {
        const start = CivilDay(year: 2026, month: 1, day: 1);
        final scheduleLast = MonthlySchedule(
          startDate: start,
          interval: 1,
          dayOfMonth: -1, // Last day of month
          startRelativeTime: testStart,
          dueRelativeTime: testDue,
        );

        expect(
          scheduleLast.occursOn(const CivilDay(year: 2026, month: 1, day: 31)),
          isTrue,
        );
        expect(
          scheduleLast.occursOn(const CivilDay(year: 2026, month: 2, day: 28)),
          isTrue,
        ); // 2026 is non-leap
        expect(
          scheduleLast.occursOn(const CivilDay(year: 2026, month: 2, day: 29)),
          isFalse,
        );
        expect(
          scheduleLast.occursOn(const CivilDay(year: 2028, month: 2, day: 29)),
          isTrue,
        ); // 2028 is leap year

        final scheduleMinus28 = MonthlySchedule(
          startDate: start,
          interval: 1,
          dayOfMonth: -28, // 28th day from the end of the month
          startRelativeTime: testStart,
          dueRelativeTime: testDue,
        );

        // Jan has 31 days. Last day is 31st. -1 = 31. -28 = 31 - 28 + 1 = 4th of Jan.
        expect(
          scheduleMinus28.occursOn(
            const CivilDay(year: 2026, month: 1, day: 4),
          ),
          isTrue,
        );
        // Feb has 28 days. Last day is 28th. -1 = 28. -28 = 28 - 28 + 1 = 1st of Feb.
        expect(
          scheduleMinus28.occursOn(
            const CivilDay(year: 2026, month: 2, day: 1),
          ),
          isTrue,
        );

        expect(
          scheduleLast.nextOccurrenceAfter(
            const CivilDay(year: 2026, month: 1, day: 31),
          ),
          const CivilDay(year: 2026, month: 2, day: 28),
        );
      },
    );

    test('MonthlySchedule occursOn nthDayOfWeek 5th weekday tests', () {
      const start = CivilDay(year: 2026, month: 1, day: 1);
      final schedule = MonthlySchedule(
        startDate: start,
        interval: 1,
        dayOfWeek: 6, // Saturday
        occurrence: 5, // 5th Saturday
        startRelativeTime: testStart,
        dueRelativeTime: testDue,
      );

      // Jan 2026 Saturdays: Jan 3 (1st), Jan 10 (2nd), Jan 17 (3rd), Jan 24 (4th), Jan 31 (5th)
      expect(
        schedule.occursOn(const CivilDay(year: 2026, month: 1, day: 31)),
        isTrue,
      );
      expect(
        schedule.occursOn(const CivilDay(year: 2026, month: 1, day: 24)),
        isFalse,
      );

      // Feb 2026 Saturdays: Feb 7 (1st), Feb 14 (2nd), Feb 21 (3rd), Feb 28 (4th). No 5th Saturday.
      expect(
        schedule.occursOn(const CivilDay(year: 2026, month: 2, day: 28)),
        isFalse,
      );

      // nextOccurrenceAfter Jan 31 should jump to the next month with a 5th Saturday (which is May 30, 2026)
      expect(
        schedule.nextOccurrenceAfter(
          const CivilDay(year: 2026, month: 1, day: 31),
        ),
        const CivilDay(year: 2026, month: 5, day: 30),
      );
    });

    test(
      'MonthlySchedule occursOn and nextOccurrenceAfter with interval = 3 months',
      () {
        const start = CivilDay(year: 2026, month: 1, day: 10);
        final schedule = MonthlySchedule(
          startDate: start,
          interval: 3,
          dayOfMonth: 15,
          startRelativeTime: testStart,
          dueRelativeTime: testDue,
        );

        // Occurs 15th on Jan, Apr, Jul, Oct, Jan...
        expect(
          schedule.occursOn(const CivilDay(year: 2026, month: 1, day: 15)),
          isTrue,
        );
        expect(
          schedule.occursOn(const CivilDay(year: 2026, month: 2, day: 15)),
          isFalse,
        );
        expect(
          schedule.occursOn(const CivilDay(year: 2026, month: 3, day: 15)),
          isFalse,
        );
        expect(
          schedule.occursOn(const CivilDay(year: 2026, month: 4, day: 15)),
          isTrue,
        );

        expect(
          schedule.nextOccurrenceAfter(
            const CivilDay(year: 2026, month: 1, day: 15),
          ),
          const CivilDay(year: 2026, month: 4, day: 15),
        );
      },
    );

    test(
      'YearlySchedule occursOn and nextOccurrenceAfter with interval = 4 years on leap day',
      () {
        const start = CivilDay(year: 2024, month: 2, day: 29);
        final schedule = YearlySchedule(
          startDate: start,
          interval: 4, // every 4 years
          month: 2,
          day: 29,
          startRelativeTime: testStart,
          dueRelativeTime: testDue,
        );

        expect(
          schedule.occursOn(const CivilDay(year: 2024, month: 2, day: 29)),
          isTrue,
        );
        expect(
          schedule.occursOn(const CivilDay(year: 2028, month: 2, day: 29)),
          isTrue,
        );
        // 2032 is leap year, 2032 - 2024 = 8. 8 % 4 = 0 -> occurs
        expect(
          schedule.occursOn(const CivilDay(year: 2032, month: 2, day: 29)),
          isTrue,
        );

        expect(
          schedule.nextOccurrenceAfter(
            const CivilDay(year: 2024, month: 2, day: 29),
          ),
          const CivilDay(year: 2028, month: 2, day: 29),
        );
      },
    );
  });
}
