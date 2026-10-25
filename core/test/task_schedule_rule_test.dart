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

      test('returns null when daysOfWeek is empty', () {
        const monday = CivilDay(year: 2026, month: 9, day: 7);
        final schedule = WeeklySchedule(
          startDate: monday,
          interval: 1,
          daysOfWeek: const {},
          startRelativeTime: defaultStart,
          dueRelativeTime: defaultDue,
        );

        expect(schedule.nextOccurrenceAfter(monday), isNull);
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

      test('returns null when no occurrence found within 10 years', () {
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

      test('returns null when no occurrence found within search limit', () {
        // Feb 30 never occurs
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
      });

      test('returns null for leap day on odd-year interval', () {
        // Feb 29 on 2-year interval starting in odd year (2025)
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

    group('Recurrence Logic with CivilDay', () {
      const testStart = RelativeTime(dayOffset: 0, hour: 9, minute: 0);
      const testDue = RelativeTime(dayOffset: 0, hour: 17, minute: 0);

      test(
        'DailySchedule occursOn works across Spring forward DST boundary (March 9, 2026)',
        () {
          const start = CivilDay(year: 2026, month: 3, day: 8);
          final schedule = DailySchedule(
            startDate: start,
            interval: 2,
            startRelativeTime: testStart,
            dueRelativeTime: testDue,
          );

          expect(schedule.occursOn(start), isTrue);
          expect(
            schedule.occursOn(const CivilDay(year: 2026, month: 3, day: 9)),
            isFalse,
          );
          expect(
            schedule.occursOn(const CivilDay(year: 2026, month: 3, day: 10)),
            isTrue,
          );
        },
      );

      test(
        'WeeklySchedule occursOn works across Spring forward DST boundary (March 9, 2026)',
        () {
          const start = CivilDay(year: 2026, month: 3, day: 2);
          final schedule = WeeklySchedule(
            startDate: start,
            interval: 2,
            daysOfWeek: const {1},
            startRelativeTime: testStart,
            dueRelativeTime: testDue,
          );

          expect(schedule.occursOn(start), isTrue);
          expect(
            schedule.occursOn(const CivilDay(year: 2026, month: 3, day: 9)),
            isFalse,
          );
          expect(
            schedule.occursOn(const CivilDay(year: 2026, month: 3, day: 16)),
            isTrue,
          );
        },
      );

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
          throwsArgumentError,
        );
        expect(
          () => MonthlySchedule(
            startDate: start,
            interval: 1,
            dayOfMonth: 29,
            startRelativeTime: testStart,
            dueRelativeTime: testDue,
          ),
          throwsArgumentError,
        );
        expect(
          () => MonthlySchedule(
            startDate: start,
            interval: 1,
            dayOfMonth: -29,
            startRelativeTime: testStart,
            dueRelativeTime: testDue,
          ),
          throwsArgumentError,
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

        expect(
          schedule.occursOn(const CivilDay(year: 2024, month: 1, day: 26)),
          isTrue,
        );
        expect(
          schedule.occursOn(const CivilDay(year: 2024, month: 1, day: 19)),
          isFalse,
        );
        expect(
          schedule.occursOn(const CivilDay(year: 2024, month: 2, day: 23)),
          isTrue,
        );
      });

      test(
        'MonthlySchedule occursOn and nextOccurrenceAfter negative dayOfMonth boundary tests',
        () {
          const start = CivilDay(year: 2026, month: 1, day: 1);
          final scheduleLast = MonthlySchedule(
            startDate: start,
            interval: 1,
            dayOfMonth: -1,
            startRelativeTime: testStart,
            dueRelativeTime: testDue,
          );

          expect(
            scheduleLast
                .occursOn(const CivilDay(year: 2026, month: 1, day: 31)),
            isTrue,
          );
          expect(
            scheduleLast
                .occursOn(const CivilDay(year: 2026, month: 2, day: 28)),
            isTrue,
          );
          expect(
            scheduleLast
                .occursOn(const CivilDay(year: 2026, month: 2, day: 29)),
            isFalse,
          );
          expect(
            scheduleLast
                .occursOn(const CivilDay(year: 2028, month: 2, day: 29)),
            isTrue,
          );

          final scheduleMinus28 = MonthlySchedule(
            startDate: start,
            interval: 1,
            dayOfMonth: -28,
            startRelativeTime: testStart,
            dueRelativeTime: testDue,
          );

          expect(
            scheduleMinus28.occursOn(
              const CivilDay(year: 2026, month: 1, day: 4),
            ),
            isTrue,
          );
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

        expect(
          schedule.occursOn(const CivilDay(year: 2026, month: 1, day: 31)),
          isTrue,
        );
        expect(
          schedule.occursOn(const CivilDay(year: 2026, month: 1, day: 24)),
          isFalse,
        );
        expect(
          schedule.occursOn(const CivilDay(year: 2026, month: 2, day: 28)),
          isFalse,
        );
        expect(
          schedule.nextOccurrenceAfter(
            const CivilDay(year: 2026, month: 1, day: 31),
          ),
          const CivilDay(year: 2026, month: 5, day: 30),
        );
      });
    });

    group('CompletionRelativePolicy Sync Tests', () {
      test(
        'DailySchedule copyWithTiming updates CompletionRelativePolicy targetTime',
        () {
          final schedule = DailySchedule(
            startDate: const CivilDay(year: 2024, month: 1, day: 1),
            interval: 5,
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
            schedulingPolicy: const CompletionRelativePolicy(
              interval: Duration(days: 5),
              targetHour: 9,
              targetMinute: 0,
            ),
          );

          final updated = schedule.copyWithTiming(
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              hour: 11,
              minute: 30,
            ),
          ) as DailySchedule;

          expect(updated.startRelativeTime.hour, 11);
          expect(updated.startRelativeTime.minute, 30);
          expect(updated.schedulingPolicy, isA<CompletionRelativePolicy>());
          final policy = updated.schedulingPolicy as CompletionRelativePolicy;
          expect(policy.targetHour, 11);
          expect(policy.targetMinute, 30);
          expect(policy.interval, const Duration(days: 5));
        },
      );
    });

    group('hasSameRecurrence Tests across all TaskScheduleRule subclasses', () {
      test('OneOffSchedule hasSameRecurrence compares date accurately', () {
        final s1 = OneOffSchedule(
          id: 'r1',
          scheduleId: 'sched1',
          date: const CivilDay(year: 2026, month: 8, day: 14),
        );
        final s2 = OneOffSchedule(
          id: 'r2',
          scheduleId: 'sched2',
          date: const CivilDay(year: 2026, month: 8, day: 14),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 10,
            minute: 0,
          ),
        );
        final sDifferentDate = OneOffSchedule(
          date: const CivilDay(year: 2026, month: 8, day: 15),
        );
        final sDifferentType = DailySchedule(
          startDate: const CivilDay(year: 2026, month: 8, day: 14),
          interval: 1,
        );

        expect(s1.hasSameRecurrence(s2), isTrue);
        expect(s2.hasSameRecurrence(s1), isTrue);
        expect(s1.hasSameRecurrence(sDifferentDate), isFalse);
        expect(s1.hasSameRecurrence(sDifferentType), isFalse);
      });

      test('DailySchedule hasSameRecurrence compares interval accurately', () {
        final s1 = DailySchedule(
          id: 'd1',
          startDate: const CivilDay(year: 2026, month: 1, day: 1),
          interval: 3,
        );
        final s2 = DailySchedule(
          id: 'd2',
          startDate: const CivilDay(year: 2026, month: 6, day: 15),
          interval: 3,
        );
        final sDifferentInterval = DailySchedule(
          startDate: const CivilDay(year: 2026, month: 1, day: 1),
          interval: 5,
        );
        final sDifferentType = WeeklySchedule(
          startDate: const CivilDay(year: 2026, month: 1, day: 1),
          interval: 3,
          daysOfWeek: const {1},
        );

        expect(s1.hasSameRecurrence(s2), isTrue);
        expect(s2.hasSameRecurrence(s1), isTrue);
        expect(s1.hasSameRecurrence(sDifferentInterval), isFalse);
        expect(s1.hasSameRecurrence(sDifferentType), isFalse);
      });

      test(
        'WeeklySchedule hasSameRecurrence compares interval and daysOfWeek',
        () {
          final s1 = WeeklySchedule(
            startDate: const CivilDay(year: 2026, month: 1, day: 1),
            interval: 2,
            daysOfWeek: const {1, 3, 5},
          );
          final s2 = WeeklySchedule(
            startDate: const CivilDay(year: 2026, month: 5, day: 10),
            interval: 2,
            daysOfWeek: const {5, 1, 3},
          );
          final sDifferentInterval = WeeklySchedule(
            startDate: const CivilDay(year: 2026, month: 1, day: 1),
            interval: 1,
            daysOfWeek: const {1, 3, 5},
          );
          final sDifferentDays = WeeklySchedule(
            startDate: const CivilDay(year: 2026, month: 1, day: 1),
            interval: 2,
            daysOfWeek: const {1, 3, 6},
          );
          final sFewerDays = WeeklySchedule(
            startDate: const CivilDay(year: 2026, month: 1, day: 1),
            interval: 2,
            daysOfWeek: const {1, 3},
          );
          final sDifferentType = OneOffSchedule(
            date: const CivilDay(year: 2026, month: 1, day: 1),
          );

          expect(s1.hasSameRecurrence(s2), isTrue);
          expect(s2.hasSameRecurrence(s1), isTrue);
          expect(s1.hasSameRecurrence(sDifferentInterval), isFalse);
          expect(s1.hasSameRecurrence(sDifferentDays), isFalse);
          expect(s1.hasSameRecurrence(sFewerDays), isFalse);
          expect(s1.hasSameRecurrence(sDifferentType), isFalse);
        },
      );

      test(
        'MonthlySchedule hasSameRecurrence compares recurrence rules accurately',
        () {
          final sDay15A = MonthlySchedule(
            startDate: const CivilDay(year: 2026, month: 1, day: 1),
            interval: 1,
            dayOfMonth: 15,
          );
          final sDay15B = MonthlySchedule(
            startDate: const CivilDay(year: 2026, month: 4, day: 15),
            interval: 1,
            dayOfMonth: 15,
          );
          final sDay16 = MonthlySchedule(
            startDate: const CivilDay(year: 2026, month: 1, day: 1),
            interval: 1,
            dayOfMonth: 16,
          );
          final sDay15Interval2 = MonthlySchedule(
            startDate: const CivilDay(year: 2026, month: 1, day: 1),
            interval: 2,
            dayOfMonth: 15,
          );
          final sLastDayA = MonthlySchedule(
            startDate: const CivilDay(year: 2026, month: 1, day: 1),
            interval: 1,
            dayOfMonth: -1,
          );
          final sLastDayB = MonthlySchedule(
            startDate: const CivilDay(year: 2026, month: 7, day: 1),
            interval: 1,
            dayOfMonth: -1,
          );
          final s2ndTuesdayA = MonthlySchedule(
            startDate: const CivilDay(year: 2026, month: 1, day: 1),
            interval: 1,
            dayOfWeek: 2,
            occurrence: 2,
          );
          final s2ndTuesdayB = MonthlySchedule(
            startDate: const CivilDay(year: 2026, month: 8, day: 1),
            interval: 1,
            dayOfWeek: 2,
            occurrence: 2,
          );
          final s3rdTuesday = MonthlySchedule(
            startDate: const CivilDay(year: 2026, month: 1, day: 1),
            interval: 1,
            dayOfWeek: 2,
            occurrence: 3,
          );
          final s2ndWednesday = MonthlySchedule(
            startDate: const CivilDay(year: 2026, month: 1, day: 1),
            interval: 1,
            dayOfWeek: 3,
            occurrence: 2,
          );

          expect(sDay15A.hasSameRecurrence(sDay15B), isTrue);
          expect(sDay15A.hasSameRecurrence(sDay16), isFalse);
          expect(sDay15A.hasSameRecurrence(sDay15Interval2), isFalse);
          expect(sLastDayA.hasSameRecurrence(sLastDayB), isTrue);
          expect(sLastDayA.hasSameRecurrence(sDay15A), isFalse);
          expect(s2ndTuesdayA.hasSameRecurrence(s2ndTuesdayB), isTrue);
          expect(s2ndTuesdayA.hasSameRecurrence(s3rdTuesday), isFalse);
          expect(s2ndTuesdayA.hasSameRecurrence(s2ndWednesday), isFalse);
          expect(s2ndTuesdayA.hasSameRecurrence(sDay15A), isFalse);

          final sDifferentType = YearlySchedule(
            startDate: const CivilDay(year: 2026, month: 1, day: 1),
            interval: 1,
            month: 1,
            day: 15,
          );
          expect(sDay15A.hasSameRecurrence(sDifferentType), isFalse);
        },
      );

      test(
        'YearlySchedule hasSameRecurrence compares interval, month, and day',
        () {
          final s1 = YearlySchedule(
            startDate: const CivilDay(year: 2024, month: 2, day: 29),
            interval: 4,
            month: 2,
            day: 29,
          );
          final s2 = YearlySchedule(
            startDate: const CivilDay(year: 2028, month: 2, day: 29),
            interval: 4,
            month: 2,
            day: 29,
          );
          final sDifferentInterval = YearlySchedule(
            startDate: const CivilDay(year: 2024, month: 2, day: 29),
            interval: 1,
            month: 2,
            day: 29,
          );
          final sDifferentMonth = YearlySchedule(
            startDate: const CivilDay(year: 2024, month: 2, day: 29),
            interval: 4,
            month: 3,
            day: 29,
          );
          final sDifferentDay = YearlySchedule(
            startDate: const CivilDay(year: 2024, month: 2, day: 29),
            interval: 4,
            month: 2,
            day: 28,
          );
          final sDifferentType = DailySchedule(
            startDate: const CivilDay(year: 2024, month: 2, day: 29),
            interval: 4,
          );

          expect(s1.hasSameRecurrence(s2), isTrue);
          expect(s2.hasSameRecurrence(s1), isTrue);
          expect(s1.hasSameRecurrence(sDifferentInterval), isFalse);
          expect(s1.hasSameRecurrence(sDifferentMonth), isFalse);
          expect(s1.hasSameRecurrence(sDifferentDay), isFalse);
          expect(s1.hasSameRecurrence(sDifferentType), isFalse);
        },
      );
    });

    group('Mathematical nextOccurrenceAfter edge case and boundary tests', () {
      test(
        'WeeklySchedule nextOccurrenceAfter jumps across multi-week gaps directly',
        () {
          const start = CivilDay(year: 2026, month: 6, day: 2);
          final schedule = WeeklySchedule(
            startDate: start,
            interval: 4,
            daysOfWeek: const {2, 4},
          );

          expect(
            schedule.nextOccurrenceAfter(
              const CivilDay(year: 2026, month: 6, day: 2),
            ),
            const CivilDay(year: 2026, month: 6, day: 4),
          );
          expect(
            schedule.nextOccurrenceAfter(
              const CivilDay(year: 2026, month: 6, day: 4),
            ),
            const CivilDay(year: 2026, month: 6, day: 30),
          );
          expect(
            schedule.nextOccurrenceAfter(
              const CivilDay(year: 2026, month: 6, day: 15),
            ),
            const CivilDay(year: 2026, month: 6, day: 30),
          );
        },
      );

      test(
        'MonthlySchedule nextOccurrenceAfter handles nth weekday and year wrap accurately',
        () {
          const start = CivilDay(year: 2026, month: 11, day: 1);
          final schedule = MonthlySchedule(
            startDate: start,
            interval: 1,
            dayOfWeek: 1,
            occurrence: 1,
          );

          expect(
            schedule.nextOccurrenceAfter(
              const CivilDay(year: 2026, month: 10, day: 31),
            ),
            const CivilDay(year: 2026, month: 11, day: 2),
          );
          expect(
            schedule.nextOccurrenceAfter(
              const CivilDay(year: 2026, month: 11, day: 2),
            ),
            const CivilDay(year: 2026, month: 12, day: 7),
          );
          expect(
            schedule.nextOccurrenceAfter(
              const CivilDay(year: 2026, month: 12, day: 7),
            ),
            const CivilDay(year: 2027, month: 1, day: 4),
          );
        },
      );

      test(
        'YearlySchedule nextOccurrenceAfter handles leap day correctly across century non-leap years',
        () {
          const start = CivilDay(year: 2096, month: 2, day: 29);
          final schedule = YearlySchedule(
            startDate: start,
            interval: 1,
            month: 2,
            day: 29,
          );

          expect(
            schedule.nextOccurrenceAfter(
              const CivilDay(year: 2096, month: 2, day: 29),
            ),
            const CivilDay(year: 2104, month: 2, day: 29),
          );
        },
      );
    });

    group('Zero and Negative Interval Handling (Issue #623)', () {
      test(
        'DailySchedule constructor and fromJson default interval <= 0 to 1',
        () {
          const start = CivilDay(year: 2026, month: 1, day: 1);
          final schedule = DailySchedule(
            startDate: start,
            interval: 0,
            startRelativeTime: defaultStart,
            dueRelativeTime: defaultDue,
          );

          expect(schedule.interval, equals(1));
          expect(schedule.occursOn(start), isTrue);
          expect(
            schedule.nextOccurrenceAfter(start),
            equals(const CivilDay(year: 2026, month: 1, day: 2)),
          );

          final jsonSchedule = DailySchedule.fromJson({
            'startDate': start.toJson(),
            'interval': 0,
          });
          expect(jsonSchedule.interval, equals(1));
          expect(jsonSchedule.occursOn(start), isTrue);
          expect(
            jsonSchedule.nextOccurrenceAfter(start),
            equals(const CivilDay(year: 2026, month: 1, day: 2)),
          );
        },
      );

      test(
        'WeeklySchedule constructor and fromJson default interval <= 0 to 1',
        () {
          const start = CivilDay(year: 2026, month: 1, day: 5);
          final schedule = WeeklySchedule(
            startDate: start,
            interval: 0,
            daysOfWeek: const {1},
            startRelativeTime: defaultStart,
            dueRelativeTime: defaultDue,
          );

          expect(schedule.interval, equals(1));
          expect(schedule.occursOn(start), isTrue);
          expect(
            schedule.nextOccurrenceAfter(start),
            equals(const CivilDay(year: 2026, month: 1, day: 12)),
          );

          final jsonSchedule = WeeklySchedule.fromJson({
            'startDate': start.toJson(),
            'interval': -1,
            'daysOfWeek': [1],
          });
          expect(jsonSchedule.interval, equals(1));
          expect(jsonSchedule.occursOn(start), isTrue);
        },
      );

      test(
        'MonthlySchedule constructor and fromJson default interval <= 0 to 1',
        () {
          const start = CivilDay(year: 2026, month: 1, day: 15);
          final schedule = MonthlySchedule(
            startDate: start,
            interval: 0,
            dayOfMonth: 15,
            startRelativeTime: defaultStart,
            dueRelativeTime: defaultDue,
          );

          expect(schedule.interval, equals(1));
          expect(schedule.occursOn(start), isTrue);
          expect(
            schedule.nextOccurrenceAfter(start),
            equals(const CivilDay(year: 2026, month: 2, day: 15)),
          );

          final jsonSchedule = MonthlySchedule.fromJson({
            'startDate': start.toJson(),
            'interval': 0,
            'dayOfMonth': 15,
          });
          expect(jsonSchedule.interval, equals(1));
          expect(jsonSchedule.occursOn(start), isTrue);
        },
      );

      test(
        'YearlySchedule constructor and fromJson default interval <= 0 to 1',
        () {
          const start = CivilDay(year: 2026, month: 5, day: 10);
          final schedule = YearlySchedule(
            startDate: start,
            interval: 0,
            month: 5,
            day: 10,
            startRelativeTime: defaultStart,
            dueRelativeTime: defaultDue,
          );

          expect(schedule.interval, equals(1));
          expect(schedule.occursOn(start), isTrue);
          expect(
            schedule.nextOccurrenceAfter(start),
            equals(const CivilDay(year: 2027, month: 5, day: 10)),
          );

          final jsonSchedule = YearlySchedule.fromJson({
            'startDate': start.toJson(),
            'interval': -5,
            'month': 5,
            'day': 10,
          });
          expect(jsonSchedule.interval, equals(1));
          expect(jsonSchedule.occursOn(start), isTrue);
        },
      );
    });
  });
}
