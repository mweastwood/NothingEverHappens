import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  const defaultStart = RelativeTime(dayOffset: 0, hour: 9, minute: 0);
  const defaultDue = RelativeTime(dayOffset: 0, hour: 17, minute: 0);

  group('TaskScheduleRule Tests', () {
    group('OneOffSchedule', () {
      test('occurs only on its specific date', () {
        const date = CivilDay(year: 2026, month: 9, day: 15);
        final schedule = OneOffSchedule(
          date: date,
          startRelativeTime: defaultStart,
          dueRelativeTime: defaultDue,
        );

        expect(schedule.scheduledDate, equals(date));
        expect(schedule.occursOn(date), isTrue);
        expect(
          schedule.occursOn(const CivilDay(year: 2026, month: 9, day: 16)),
          isFalse,
        );
        expect(
          schedule.occursOn(const CivilDay(year: 2026, month: 9, day: 14)),
          isFalse,
        );
        expect(schedule.nextOccurrenceAfter(date), isNull);
        expect(
          schedule.nextOccurrenceAfter(
            const CivilDay(year: 2026, month: 9, day: 10),
          ),
          equals(date),
        );
      });

      test('advanceAfterCompletion returns null if date is on or before today',
          () {
        const date = CivilDay(year: 2026, month: 9, day: 15);
        final schedule = OneOffSchedule(
          date: date,
          startRelativeTime: defaultStart,
          dueRelativeTime: defaultDue,
        );

        // Completed on the day
        expect(schedule.advanceAfterCompletion(date), isNull);
        // Completed after the day
        expect(
          schedule.advanceAfterCompletion(
            const CivilDay(year: 2026, month: 9, day: 16),
          ),
          isNull,
        );
        // Today is before scheduled date (not completed yet)
        expect(
          schedule.advanceAfterCompletion(
            const CivilDay(year: 2026, month: 9, day: 10),
          ),
          equals(schedule),
        );
      });

      test('toJson and fromJson polymorphic round-trip', () {
        const date = CivilDay(year: 2026, month: 9, day: 15);
        final schedule = OneOffSchedule(
          id: 'oneoff-1',
          scheduleId: 'sched-1',
          date: date,
          startRelativeTime: defaultStart,
          dueRelativeTime: defaultDue,
        );

        final json = schedule.toJson();
        expect(json['type'], equals('oneOff'));

        final deserialized = TaskScheduleRule.fromJson(json);
        expect(deserialized, isA<OneOffSchedule>());
        expect((deserialized as OneOffSchedule).date, equals(date));
        expect(deserialized.id, equals('oneoff-1'));
      });
    });

    group('DailySchedule', () {
      test('checks interval recurrence and next occurrence', () {
        const startDate = CivilDay(year: 2026, month: 9, day: 1);
        final schedule = DailySchedule(
          startDate: startDate,
          interval: 3,
          startRelativeTime: defaultStart,
          dueRelativeTime: defaultDue,
        );

        expect(schedule.occursOn(startDate), isTrue);
        expect(
          schedule.occursOn(const CivilDay(year: 2026, month: 9, day: 2)),
          isFalse,
        );
        expect(
          schedule.occursOn(const CivilDay(year: 2026, month: 9, day: 4)),
          isTrue,
        );

        expect(
          schedule.nextOccurrenceAfter(startDate),
          equals(const CivilDay(year: 2026, month: 9, day: 4)),
        );
      });

      test('advanceAfterCompletion advances startDate to next occurrence', () {
        const startDate = CivilDay(year: 2026, month: 9, day: 1);
        final schedule = DailySchedule(
          startDate: startDate,
          interval: 2,
          startRelativeTime: defaultStart,
          dueRelativeTime: defaultDue,
        );

        final advanced = schedule.advanceAfterCompletion(
          const CivilDay(year: 2026, month: 9, day: 1),
        );
        expect(advanced, isNotNull);
        expect(
          advanced!.scheduledDate,
          equals(const CivilDay(year: 2026, month: 9, day: 3)),
        );
      });

      test('toJson and fromJson polymorphic round-trip', () {
        const startDate = CivilDay(year: 2026, month: 9, day: 1);
        final schedule = DailySchedule(
          id: 'daily-1',
          scheduleId: 'sched-1',
          startDate: startDate,
          interval: 2,
          startRelativeTime: defaultStart,
          dueRelativeTime: defaultDue,
        );

        final json = schedule.toJson();
        expect(json['type'], equals('daily'));

        final deserialized = TaskScheduleRule.fromJson(json);
        expect(deserialized, isA<DailySchedule>());
        expect((deserialized as DailySchedule).interval, equals(2));
      });
    });

    group('WeeklySchedule', () {
      test('occurs on specified days of week', () {
        // 2026-09-07 is a Monday (weekday 1)
        const monday = CivilDay(year: 2026, month: 9, day: 7);
        const tuesday = CivilDay(year: 2026, month: 9, day: 8);
        const wednesday = CivilDay(year: 2026, month: 9, day: 9);

        final schedule = WeeklySchedule(
          startDate: monday,
          interval: 1,
          daysOfWeek: const {1, 3}, // Mon, Wed
          startRelativeTime: defaultStart,
          dueRelativeTime: defaultDue,
        );

        expect(schedule.occursOn(monday), isTrue);
        expect(schedule.occursOn(tuesday), isFalse);
        expect(schedule.occursOn(wednesday), isTrue);

        expect(schedule.nextOccurrenceAfter(monday), equals(wednesday));
      });

      test('toJson and fromJson polymorphic round-trip', () {
        const monday = CivilDay(year: 2026, month: 9, day: 7);
        final schedule = WeeklySchedule(
          id: 'weekly-1',
          scheduleId: 'sched-1',
          startDate: monday,
          interval: 1,
          daysOfWeek: const {1, 5},
          startRelativeTime: defaultStart,
          dueRelativeTime: defaultDue,
        );

        final json = schedule.toJson();
        expect(json['type'], equals('weekly'));

        final deserialized = TaskScheduleRule.fromJson(json);
        expect(deserialized, isA<WeeklySchedule>());
        expect((deserialized as WeeklySchedule).daysOfWeek, equals({1, 5}));
      });
    });

    group('MonthlySchedule', () {
      test('fixed dayOfMonth occurs correctly', () {
        const start = CivilDay(year: 2026, month: 9, day: 15);
        final schedule = MonthlySchedule(
          startDate: start,
          interval: 1,
          dayOfMonth: 15,
          startRelativeTime: defaultStart,
          dueRelativeTime: defaultDue,
        );

        expect(schedule.occursOn(start), isTrue);
        expect(
          schedule.occursOn(const CivilDay(year: 2026, month: 9, day: 16)),
          isFalse,
        );
        expect(
          schedule.nextOccurrenceAfter(start),
          equals(const CivilDay(year: 2026, month: 10, day: 15)),
        );
      });

      test('nth weekday occurs correctly', () {
        // 2nd Tuesday of September 2026:
        // Sep 1 is Tuesday (1st), Sep 8 is Tuesday (2nd)
        const start = CivilDay(year: 2026, month: 9, day: 1);
        final schedule = MonthlySchedule(
          startDate: start,
          interval: 1,
          dayOfWeek: 2, // Tuesday
          occurrence: 2, // 2nd
          startRelativeTime: defaultStart,
          dueRelativeTime: defaultDue,
        );

        expect(
          schedule.occursOn(const CivilDay(year: 2026, month: 9, day: 8)),
          isTrue,
        );
        expect(
          schedule.occursOn(const CivilDay(year: 2026, month: 9, day: 1)),
          isFalse,
        );
      });

      test('toJson and fromJson polymorphic round-trip', () {
        const start = CivilDay(year: 2026, month: 9, day: 15);
        final schedule = MonthlySchedule(
          id: 'monthly-1',
          scheduleId: 'sched-1',
          startDate: start,
          interval: 2,
          dayOfMonth: 15,
          startRelativeTime: defaultStart,
          dueRelativeTime: defaultDue,
        );

        final json = schedule.toJson();
        expect(json['type'], equals('monthly'));

        final deserialized = TaskScheduleRule.fromJson(json);
        expect(deserialized, isA<MonthlySchedule>());
        expect((deserialized as MonthlySchedule).dayOfMonth, equals(15));
        expect(deserialized.interval, equals(2));
      });
    });

    group('YearlySchedule', () {
      test('occurs on specific month and day each year', () {
        const start = CivilDay(year: 2026, month: 12, day: 25);
        final schedule = YearlySchedule(
          startDate: start,
          interval: 1,
          month: 12,
          day: 25,
          startRelativeTime: defaultStart,
          dueRelativeTime: defaultDue,
        );

        expect(schedule.occursOn(start), isTrue);
        expect(
          schedule.occursOn(const CivilDay(year: 2026, month: 12, day: 24)),
          isFalse,
        );
        expect(
          schedule.nextOccurrenceAfter(start),
          equals(const CivilDay(year: 2027, month: 12, day: 25)),
        );
      });

      test('toJson and fromJson polymorphic round-trip', () {
        const start = CivilDay(year: 2026, month: 12, day: 25);
        final schedule = YearlySchedule(
          id: 'yearly-1',
          scheduleId: 'sched-1',
          startDate: start,
          interval: 1,
          month: 12,
          day: 25,
          startRelativeTime: defaultStart,
          dueRelativeTime: defaultDue,
        );

        final json = schedule.toJson();
        expect(json['type'], equals('yearly'));

        final deserialized = TaskScheduleRule.fromJson(json);
        expect(deserialized, isA<YearlySchedule>());
        expect((deserialized as YearlySchedule).month, equals(12));
        expect(deserialized.day, equals(25));
      });
    });

    group('Hierarchical Recurrence Extension & Conversion', () {
      test('determines hierarchicalKind and converts rule to kind', () {
        const start = CivilDay(year: 2026, month: 9, day: 8);
        final rule = DailySchedule(
          startDate: start,
          interval: 1,
          startRelativeTime: defaultStart,
          dueRelativeTime: defaultDue,
        );

        expect(
          rule.hierarchicalKind,
          equals(HierarchicalRecurrenceKind.dailyFixed),
        );

        final converted = convertRuleToKind(
          rule,
          HierarchicalRecurrenceKind.dailyCompletionRelative,
        );
        expect(
          converted.hierarchicalKind,
          equals(HierarchicalRecurrenceKind.dailyCompletionRelative),
        );
        expect(converted.schedulingPolicy, isA<CompletionRelativePolicy>());
      });
    });
  });
}
