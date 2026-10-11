import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  const defaultStart = RelativeTime(dayOffset: 0, hour: 9, minute: 0);
  const defaultDue = RelativeTime(dayOffset: 0, hour: 17, minute: 0);

  group('Schedule Rules Null on Exhaustion / Empty Tests', () {
    test('WeeklySchedule returns null when daysOfWeek is empty', () {
      const monday = CivilDay(year: 2026, month: 9, day: 7);
      final schedule = WeeklySchedule(
        startDate: monday,
        interval: 1,
        daysOfWeek: const {},
        startRelativeTime: defaultStart,
        dueRelativeTime: defaultDue,
      );

      expect(schedule.nextOccurrenceAfter(monday), isNull);
      expect(schedule.advanceAfterCompletion(monday), isNull);
    });

    test(
      'MonthlySchedule returns null when no occurrence found within 10 years',
      () {
        // 6th Monday of the month never occurs
        const start = CivilDay(year: 2026, month: 2, day: 1);
        final schedule = MonthlySchedule(
          startDate: start,
          interval: 1,
          dayOfWeek: DateTime.monday,
          occurrence: 6,
          startRelativeTime: defaultStart,
          dueRelativeTime: defaultDue,
        );

        expect(schedule.nextOccurrenceAfter(start), isNull);
        expect(schedule.advanceAfterCompletion(start), isNull);
      },
    );

    test(
      'YearlySchedule returns null when no occurrence found within 20 years',
      () {
        // Feb 30 never occurs in any calendar year
        const start = CivilDay(year: 2026, month: 2, day: 1);
        final schedule = YearlySchedule(
          startDate: start,
          interval: 1,
          month: 2,
          day: 30,
          startRelativeTime: defaultStart,
          dueRelativeTime: defaultDue,
        );

        expect(schedule.nextOccurrenceAfter(start), isNull);
        expect(schedule.advanceAfterCompletion(start), isNull);
      },
    );

    test('YearlySchedule returns null for leap day on odd-year interval', () {
      // Feb 29 on 2-year interval starting in 2025 only checks odd years
      // (which cannot be leap years)
      const start = CivilDay(year: 2025, month: 2, day: 1);
      final schedule = YearlySchedule(
        startDate: start,
        interval: 2,
        month: 2,
        day: 29,
        startRelativeTime: defaultStart,
        dueRelativeTime: defaultDue,
      );

      expect(schedule.nextOccurrenceAfter(start), isNull);
      expect(schedule.advanceAfterCompletion(start), isNull);
    });
  });
}
