import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/missed_occurrence_policy.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/scheduling_policy.dart';
import 'package:nothing_ever_happens/logic/task_schedule_rule.dart';

class _UnrecognizedScheduleRule extends TaskScheduleRule {
  _UnrecognizedScheduleRule({
    super.id = 'unrecognized-id',
    super.scheduleId = 'unrecognized-schedule-id',
    super.startRelativeTime,
  });

  @override
  CivilDay get scheduledDate => const CivilDay(year: 2026, month: 8, day: 23);

  @override
  bool occursOn(CivilDay day) => true;

  @override
  CivilDay? nextOccurrenceAfter(CivilDay date) => null;

  @override
  bool hasSameRecurrence(TaskScheduleRule other) =>
      other is _UnrecognizedScheduleRule;

  @override
  TaskScheduleRule copyWithStartDate(CivilDay newStartDate) => this;

  @override
  TaskScheduleRule copyWithTiming({
    String? id,
    String? scheduleId,
    RelativeTime? startRelativeTime,
    RelativeTime? dueRelativeTime,
    List<RelativeTime>? notificationRelativeTimes,
    SchedulingPolicy? schedulingPolicy,
    MissedOccurrencePolicy? missedOccurrencePolicy,
  }) => this;

  @override
  TaskScheduleRule? advanceAfterCompletion(CivilDay today) => null;

  @override
  Map<String, dynamic> toJson() => {};
}

void main() {
  const defaultStart = RelativeTime(
    dayOffset: 0,
    time: TimeOfDay(hour: 9, minute: 0),
  );
  const defaultDue = RelativeTime(
    dayOffset: 0,
    time: TimeOfDay(hour: 17, minute: 30),
  );
  final defaultNotifications = [
    const RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 8, minute: 30)),
    const RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 12, minute: 0)),
  ];
  const customPolicy = MissedOccurrencePolicy.autoDismiss(
    gracePeriod: Duration(hours: 4),
  );
  const testDate = CivilDay(
    year: 2026,
    month: 8,
    day: 15,
  ); // Aug 15 2026 is Saturday (6)

  group('schedule_rule_hierarchical Tests', () {
    group('Group 1: TaskScheduleRuleHierarchicalExtension.hierarchicalKind', () {
      test('OneOffSchedule resolves to HierarchicalRecurrenceKind.oneOff', () {
        final rule = OneOffSchedule(
          date: testDate,
          startRelativeTime: defaultStart,
        );
        expect(rule.hierarchicalKind, HierarchicalRecurrenceKind.oneOff);
      });

      test(
        'DailySchedule with FixedCalendarPolicy resolves to HierarchicalRecurrenceKind.dailyFixed',
        () {
          final rule = DailySchedule(
            startDate: testDate,
            interval: 1,
            startRelativeTime: defaultStart,
            schedulingPolicy: const FixedCalendarPolicy(),
          );
          expect(rule.hierarchicalKind, HierarchicalRecurrenceKind.dailyFixed);
        },
      );

      test(
        'DailySchedule with CompletionRelativePolicy resolves to HierarchicalRecurrenceKind.dailyCompletionRelative',
        () {
          final rule = DailySchedule(
            startDate: testDate,
            interval: 1,
            startRelativeTime: defaultStart,
            schedulingPolicy: const CompletionRelativePolicy(
              interval: Duration(days: 1),
              targetTime: TimeOfDay(hour: 9, minute: 0),
            ),
          );
          expect(
            rule.hierarchicalKind,
            HierarchicalRecurrenceKind.dailyCompletionRelative,
          );
        },
      );

      test(
        'WeeklySchedule with FixedCalendarPolicy resolves to HierarchicalRecurrenceKind.weeklyFixed',
        () {
          final rule = WeeklySchedule(
            startDate: testDate,
            interval: 1,
            daysOfWeek: const {1, 3, 5},
            startRelativeTime: defaultStart,
            schedulingPolicy: const FixedCalendarPolicy(),
          );
          expect(rule.hierarchicalKind, HierarchicalRecurrenceKind.weeklyFixed);
        },
      );

      test(
        'WeeklySchedule with CompletionRelativePolicy resolves to HierarchicalRecurrenceKind.weeklyCompletionRelative',
        () {
          final rule = WeeklySchedule(
            startDate: testDate,
            interval: 1,
            daysOfWeek: const {1, 3, 5},
            startRelativeTime: defaultStart,
            schedulingPolicy: const CompletionRelativePolicy(
              interval: Duration(days: 7),
              targetTime: TimeOfDay(hour: 9, minute: 0),
            ),
          );
          expect(
            rule.hierarchicalKind,
            HierarchicalRecurrenceKind.weeklyCompletionRelative,
          );
        },
      );

      test(
        'MonthlySchedule with FixedCalendarPolicy and dayOfMonth resolves to HierarchicalRecurrenceKind.monthlyFixedDay',
        () {
          final rule = MonthlySchedule(
            startDate: testDate,
            interval: 1,
            dayOfMonth: 15,
            startRelativeTime: defaultStart,
            schedulingPolicy: const FixedCalendarPolicy(),
          );
          expect(
            rule.hierarchicalKind,
            HierarchicalRecurrenceKind.monthlyFixedDay,
          );
        },
      );

      test(
        'MonthlySchedule with FixedCalendarPolicy and null dayOfMonth resolves to HierarchicalRecurrenceKind.monthlyNthWeekday',
        () {
          final rule = MonthlySchedule(
            startDate: testDate,
            interval: 1,
            dayOfWeek: 6,
            occurrence: 3,
            startRelativeTime: defaultStart,
            schedulingPolicy: const FixedCalendarPolicy(),
          );
          expect(
            rule.hierarchicalKind,
            HierarchicalRecurrenceKind.monthlyNthWeekday,
          );
        },
      );

      test(
        'MonthlySchedule with CompletionRelativePolicy resolves to HierarchicalRecurrenceKind.monthlyCompletionRelative',
        () {
          final rule = MonthlySchedule(
            startDate: testDate,
            interval: 1,
            dayOfMonth: 15,
            startRelativeTime: defaultStart,
            schedulingPolicy: const CompletionRelativePolicy(
              interval: Duration(days: 30),
              targetTime: TimeOfDay(hour: 9, minute: 0),
            ),
          );
          expect(
            rule.hierarchicalKind,
            HierarchicalRecurrenceKind.monthlyCompletionRelative,
          );
        },
      );

      test(
        'YearlySchedule with FixedCalendarPolicy resolves to HierarchicalRecurrenceKind.yearlyFixed',
        () {
          final rule = YearlySchedule(
            startDate: testDate,
            interval: 1,
            month: 8,
            day: 15,
            startRelativeTime: defaultStart,
            schedulingPolicy: const FixedCalendarPolicy(),
          );
          expect(rule.hierarchicalKind, HierarchicalRecurrenceKind.yearlyFixed);
        },
      );

      test(
        'YearlySchedule with CompletionRelativePolicy resolves to HierarchicalRecurrenceKind.yearlyCompletionRelative',
        () {
          final rule = YearlySchedule(
            startDate: testDate,
            interval: 1,
            month: 8,
            day: 15,
            startRelativeTime: defaultStart,
            schedulingPolicy: const CompletionRelativePolicy(
              interval: Duration(days: 365),
              targetTime: TimeOfDay(hour: 9, minute: 0),
            ),
          );
          expect(
            rule.hierarchicalKind,
            HierarchicalRecurrenceKind.yearlyCompletionRelative,
          );
        },
      );

      test(
        'throws StateError when an unrecognized TaskScheduleRule subclass is passed',
        () {
          final unknownRule = _UnrecognizedScheduleRule(
            startRelativeTime: defaultStart,
          );
          expect(
            () => unknownRule.hierarchicalKind,
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                'Unknown schedule rule type',
              ),
            ),
          );
        },
      );
    });

    group('Group 2: convertRuleToKind - Metadata & Property Preservation', () {
      test('preserves common metadata fields across conversions', () {
        final source = OneOffSchedule(
          id: 'test-rule-id-123',
          scheduleId: 'test-sched-id-456',
          date: testDate,
          startRelativeTime: defaultStart,
          dueRelativeTime: defaultDue,
          notificationRelativeTimes: defaultNotifications,
          missedOccurrencePolicy: customPolicy,
        );

        for (final kind in HierarchicalRecurrenceKind.values) {
          final converted = convertRuleToKind(source, kind);
          expect(converted.id, 'test-rule-id-123', reason: 'id for $kind');
          expect(
            converted.scheduleId,
            'test-sched-id-456',
            reason: 'scheduleId for $kind',
          );
          expect(
            converted.dueRelativeTime,
            defaultDue,
            reason: 'dueRelativeTime for $kind',
          );
          expect(
            converted.notificationRelativeTimes,
            defaultNotifications,
            reason: 'notifications for $kind',
          );
          expect(
            converted.missedOccurrencePolicy,
            customPolicy,
            reason: 'missedOccurrencePolicy for $kind',
          );
        }
      });

      test('preserves custom interval values from source rules', () {
        final dailySource = DailySchedule(
          startDate: testDate,
          interval: 3,
          startRelativeTime: defaultStart,
        );
        final weeklySource = WeeklySchedule(
          startDate: testDate,
          interval: 4,
          daysOfWeek: const {2},
          startRelativeTime: defaultStart,
        );
        final monthlySource = MonthlySchedule(
          startDate: testDate,
          interval: 5,
          dayOfMonth: 10,
          startRelativeTime: defaultStart,
        );
        final yearlySource = YearlySchedule(
          startDate: testDate,
          interval: 6,
          month: 8,
          day: 15,
          startRelativeTime: defaultStart,
        );

        // Daily source with interval 3 converted to various recurring kinds
        final toWeekly =
            convertRuleToKind(
                  dailySource,
                  HierarchicalRecurrenceKind.weeklyFixed,
                )
                as WeeklySchedule;
        expect(toWeekly.interval, 3);

        final toMonthly =
            convertRuleToKind(
                  weeklySource,
                  HierarchicalRecurrenceKind.monthlyFixedDay,
                )
                as MonthlySchedule;
        expect(toMonthly.interval, 4);

        final toYearly =
            convertRuleToKind(
                  monthlySource,
                  HierarchicalRecurrenceKind.yearlyFixed,
                )
                as YearlySchedule;
        expect(toYearly.interval, 5);

        final toDaily =
            convertRuleToKind(
                  yearlySource,
                  HierarchicalRecurrenceKind.dailyCompletionRelative,
                )
                as DailySchedule;
        expect(toDaily.interval, 6);
      });

      test('defaults interval to 1 when converting from OneOffSchedule', () {
        final oneOff = OneOffSchedule(
          date: testDate,
          startRelativeTime: defaultStart,
        );

        final convertedDaily =
            convertRuleToKind(oneOff, HierarchicalRecurrenceKind.dailyFixed)
                as DailySchedule;
        expect(convertedDaily.interval, 1);

        final convertedWeekly =
            convertRuleToKind(oneOff, HierarchicalRecurrenceKind.weeklyFixed)
                as WeeklySchedule;
        expect(convertedWeekly.interval, 1);

        final convertedMonthly =
            convertRuleToKind(
                  oneOff,
                  HierarchicalRecurrenceKind.monthlyFixedDay,
                )
                as MonthlySchedule;
        expect(convertedMonthly.interval, 1);

        final convertedYearly =
            convertRuleToKind(oneOff, HierarchicalRecurrenceKind.yearlyFixed)
                as YearlySchedule;
        expect(convertedYearly.interval, 1);
      });
    });

    group('Group 3: convertRuleToKind - Target Kind Conversions', () {
      final baseRule = DailySchedule(
        id: 'base-id',
        scheduleId: 'base-schedule',
        startDate: testDate, // 2026-08-15 (Saturday, weekday 6)
        interval: 2,
        startRelativeTime: defaultStart,
        dueRelativeTime: defaultDue,
        notificationRelativeTimes: defaultNotifications,
        missedOccurrencePolicy: customPolicy,
      );

      test('converts to HierarchicalRecurrenceKind.oneOff', () {
        final result = convertRuleToKind(
          baseRule,
          HierarchicalRecurrenceKind.oneOff,
        );

        expect(result, isA<OneOffSchedule>());
        final oneOff = result as OneOffSchedule;
        expect(oneOff.date, testDate);
        expect(oneOff.startRelativeTime, defaultStart);
        expect(oneOff.dueRelativeTime, defaultDue);
        expect(oneOff.notificationRelativeTimes, defaultNotifications);
        expect(oneOff.missedOccurrencePolicy, customPolicy);
        expect(oneOff.hierarchicalKind, HierarchicalRecurrenceKind.oneOff);
      });

      test('converts to HierarchicalRecurrenceKind.dailyFixed', () {
        final result = convertRuleToKind(
          baseRule,
          HierarchicalRecurrenceKind.dailyFixed,
        );

        expect(result, isA<DailySchedule>());
        final daily = result as DailySchedule;
        expect(daily.startDate, testDate);
        expect(daily.interval, 2);
        expect(daily.schedulingPolicy, const FixedCalendarPolicy());
        expect(daily.hierarchicalKind, HierarchicalRecurrenceKind.dailyFixed);
      });

      test(
        'converts to HierarchicalRecurrenceKind.dailyCompletionRelative',
        () {
          final result = convertRuleToKind(
            baseRule,
            HierarchicalRecurrenceKind.dailyCompletionRelative,
          );

          expect(result, isA<DailySchedule>());
          final daily = result as DailySchedule;
          expect(daily.startDate, testDate);
          expect(daily.interval, 2);
          expect(
            daily.schedulingPolicy,
            const CompletionRelativePolicy(
              interval: Duration(days: 2),
              targetTime: TimeOfDay(hour: 9, minute: 0),
            ),
          );
          expect(
            daily.hierarchicalKind,
            HierarchicalRecurrenceKind.dailyCompletionRelative,
          );
        },
      );

      test('converts to HierarchicalRecurrenceKind.weeklyFixed', () {
        final result = convertRuleToKind(
          baseRule,
          HierarchicalRecurrenceKind.weeklyFixed,
        );

        expect(result, isA<WeeklySchedule>());
        final weekly = result as WeeklySchedule;
        expect(weekly.startDate, testDate);
        expect(weekly.interval, 2);
        expect(weekly.daysOfWeek, {
          testDate.toUtcDateTime().weekday,
        }); // Saturday = 6
        expect(weekly.schedulingPolicy, const FixedCalendarPolicy());
        expect(weekly.hierarchicalKind, HierarchicalRecurrenceKind.weeklyFixed);
      });

      test(
        'converts to HierarchicalRecurrenceKind.weeklyCompletionRelative',
        () {
          final result = convertRuleToKind(
            baseRule,
            HierarchicalRecurrenceKind.weeklyCompletionRelative,
          );

          expect(result, isA<WeeklySchedule>());
          final weekly = result as WeeklySchedule;
          expect(weekly.startDate, testDate);
          expect(weekly.interval, 2);
          expect(weekly.daysOfWeek, {testDate.toUtcDateTime().weekday});
          expect(
            weekly.schedulingPolicy,
            const CompletionRelativePolicy(
              interval: Duration(days: 2 * 7),
              targetTime: TimeOfDay(hour: 9, minute: 0),
            ),
          );
          expect(
            weekly.hierarchicalKind,
            HierarchicalRecurrenceKind.weeklyCompletionRelative,
          );
        },
      );

      test(
        'converts to HierarchicalRecurrenceKind.monthlyFixedDay with day clamping',
        () {
          // Test day <= 28 (day 15)
          final result15 = convertRuleToKind(
            baseRule,
            HierarchicalRecurrenceKind.monthlyFixedDay,
          );
          expect(result15, isA<MonthlySchedule>());
          final monthly15 = result15 as MonthlySchedule;
          expect(monthly15.startDate, testDate);
          expect(monthly15.interval, 2);
          expect(monthly15.dayOfMonth, 15);
          expect(monthly15.dayOfWeek, isNull);
          expect(monthly15.occurrence, isNull);
          expect(monthly15.schedulingPolicy, const FixedCalendarPolicy());
          expect(
            monthly15.hierarchicalKind,
            HierarchicalRecurrenceKind.monthlyFixedDay,
          );

          // Test day == 28
          final rule28 = OneOffSchedule(
            date: const CivilDay(year: 2026, month: 2, day: 28),
            startRelativeTime: defaultStart,
          );
          final monthly28 =
              convertRuleToKind(
                    rule28,
                    HierarchicalRecurrenceKind.monthlyFixedDay,
                  )
                  as MonthlySchedule;
          expect(monthly28.dayOfMonth, 28);

          // Test day > 28 (overflow: day 31 -> clamped to 28)
          final rule31 = OneOffSchedule(
            date: const CivilDay(year: 2026, month: 1, day: 31),
            startRelativeTime: defaultStart,
          );
          final monthly31 =
              convertRuleToKind(
                    rule31,
                    HierarchicalRecurrenceKind.monthlyFixedDay,
                  )
                  as MonthlySchedule;
          expect(monthly31.dayOfMonth, 28);

          // Test day 29 -> clamped to 28
          final rule29 = OneOffSchedule(
            date: const CivilDay(year: 2024, month: 2, day: 29),
            startRelativeTime: defaultStart,
          );
          final monthly29 =
              convertRuleToKind(
                    rule29,
                    HierarchicalRecurrenceKind.monthlyFixedDay,
                  )
                  as MonthlySchedule;
          expect(monthly29.dayOfMonth, 28);
        },
      );

      test(
        'converts to HierarchicalRecurrenceKind.monthlyNthWeekday calculating occurrence and weekday',
        () {
          // Aug 15 2026: Saturday (weekday 6). (15 - 1) ~/ 7 + 1 = 3rd occurrence
          final result = convertRuleToKind(
            baseRule,
            HierarchicalRecurrenceKind.monthlyNthWeekday,
          );
          expect(result, isA<MonthlySchedule>());
          final monthly = result as MonthlySchedule;
          expect(monthly.startDate, testDate);
          expect(monthly.interval, 2);
          expect(monthly.dayOfMonth, isNull);
          expect(monthly.dayOfWeek, 6);
          expect(monthly.occurrence, 3);
          expect(monthly.schedulingPolicy, const FixedCalendarPolicy());
          expect(
            monthly.hierarchicalKind,
            HierarchicalRecurrenceKind.monthlyNthWeekday,
          );

          // Additional date tests across occurrence bounds:
          // Day 1 (1st): Oct 1 2026 is Thursday (4) -> (1-1)~/7 + 1 = 1
          final oct1 = OneOffSchedule(
            date: const CivilDay(year: 2026, month: 10, day: 1),
            startRelativeTime: defaultStart,
          );
          final monthlyOct1 =
              convertRuleToKind(
                    oct1,
                    HierarchicalRecurrenceKind.monthlyNthWeekday,
                  )
                  as MonthlySchedule;
          expect(monthlyOct1.dayOfWeek, DateTime.thursday);
          expect(monthlyOct1.occurrence, 1);

          // Day 7 (1st): Oct 7 2026 is Wednesday (3) -> (7-1)~/7 + 1 = 1
          final oct7 = OneOffSchedule(
            date: const CivilDay(year: 2026, month: 10, day: 7),
            startRelativeTime: defaultStart,
          );
          final monthlyOct7 =
              convertRuleToKind(
                    oct7,
                    HierarchicalRecurrenceKind.monthlyNthWeekday,
                  )
                  as MonthlySchedule;
          expect(monthlyOct7.dayOfWeek, DateTime.wednesday);
          expect(monthlyOct7.occurrence, 1);

          // Day 8 (2nd): Oct 8 2026 is Thursday (4) -> (8-1)~/7 + 1 = 2
          final oct8 = OneOffSchedule(
            date: const CivilDay(year: 2026, month: 10, day: 8),
            startRelativeTime: defaultStart,
          );
          final monthlyOct8 =
              convertRuleToKind(
                    oct8,
                    HierarchicalRecurrenceKind.monthlyNthWeekday,
                  )
                  as MonthlySchedule;
          expect(monthlyOct8.dayOfWeek, DateTime.thursday);
          expect(monthlyOct8.occurrence, 2);

          // Day 28 (4th): Oct 28 2026 is Wednesday (3) -> (28-1)~/7 + 1 = 4
          final oct28 = OneOffSchedule(
            date: const CivilDay(year: 2026, month: 10, day: 28),
            startRelativeTime: defaultStart,
          );
          final monthlyOct28 =
              convertRuleToKind(
                    oct28,
                    HierarchicalRecurrenceKind.monthlyNthWeekday,
                  )
                  as MonthlySchedule;
          expect(monthlyOct28.dayOfWeek, DateTime.wednesday);
          expect(monthlyOct28.occurrence, 4);

          // Day 29 (5th): Oct 29 2026 is Thursday (4) -> (29-1)~/7 + 1 = 5
          final oct29 = OneOffSchedule(
            date: const CivilDay(year: 2026, month: 10, day: 29),
            startRelativeTime: defaultStart,
          );
          final monthlyOct29 =
              convertRuleToKind(
                    oct29,
                    HierarchicalRecurrenceKind.monthlyNthWeekday,
                  )
                  as MonthlySchedule;
          expect(monthlyOct29.dayOfWeek, DateTime.thursday);
          expect(monthlyOct29.occurrence, 5);

          // Day 31 (5th): Oct 31 2026 is Saturday (6) -> (31-1)~/7 + 1 = 5
          final oct31 = OneOffSchedule(
            date: const CivilDay(year: 2026, month: 10, day: 31),
            startRelativeTime: defaultStart,
          );
          final monthlyOct31 =
              convertRuleToKind(
                    oct31,
                    HierarchicalRecurrenceKind.monthlyNthWeekday,
                  )
                  as MonthlySchedule;
          expect(monthlyOct31.dayOfWeek, DateTime.saturday);
          expect(monthlyOct31.occurrence, 5);
        },
      );

      test(
        'converts to HierarchicalRecurrenceKind.monthlyCompletionRelative',
        () {
          final result = convertRuleToKind(
            baseRule,
            HierarchicalRecurrenceKind.monthlyCompletionRelative,
          );

          expect(result, isA<MonthlySchedule>());
          final monthly = result as MonthlySchedule;
          expect(monthly.startDate, testDate);
          expect(monthly.interval, 2);
          expect(monthly.dayOfMonth, 15);
          expect(
            monthly.schedulingPolicy,
            const CompletionRelativePolicy(
              interval: Duration(days: 2 * 30),
              targetTime: TimeOfDay(hour: 9, minute: 0),
            ),
          );
          expect(
            monthly.hierarchicalKind,
            HierarchicalRecurrenceKind.monthlyCompletionRelative,
          );

          // Clamping check for monthlyCompletionRelative with day 31
          final rule31 = OneOffSchedule(
            date: const CivilDay(year: 2026, month: 1, day: 31),
            startRelativeTime: defaultStart,
          );
          final monthly31 =
              convertRuleToKind(
                    rule31,
                    HierarchicalRecurrenceKind.monthlyCompletionRelative,
                  )
                  as MonthlySchedule;
          expect(monthly31.dayOfMonth, 28);
        },
      );

      test('converts to HierarchicalRecurrenceKind.yearlyFixed', () {
        final result = convertRuleToKind(
          baseRule,
          HierarchicalRecurrenceKind.yearlyFixed,
        );

        expect(result, isA<YearlySchedule>());
        final yearly = result as YearlySchedule;
        expect(yearly.startDate, testDate);
        expect(yearly.interval, 2);
        expect(yearly.month, 8);
        expect(yearly.day, 15);
        expect(yearly.schedulingPolicy, const FixedCalendarPolicy());
        expect(yearly.hierarchicalKind, HierarchicalRecurrenceKind.yearlyFixed);
      });

      test(
        'converts to HierarchicalRecurrenceKind.yearlyCompletionRelative',
        () {
          final result = convertRuleToKind(
            baseRule,
            HierarchicalRecurrenceKind.yearlyCompletionRelative,
          );

          expect(result, isA<YearlySchedule>());
          final yearly = result as YearlySchedule;
          expect(yearly.startDate, testDate);
          expect(yearly.interval, 2);
          expect(yearly.month, 8);
          expect(yearly.day, 15);
          expect(
            yearly.schedulingPolicy,
            const CompletionRelativePolicy(
              interval: Duration(days: 2 * 365),
              targetTime: TimeOfDay(hour: 9, minute: 0),
            ),
          );
          expect(
            yearly.hierarchicalKind,
            HierarchicalRecurrenceKind.yearlyCompletionRelative,
          );
        },
      );
    });

    group('Group 4: convertRuleToKind - Special Date & Offset Normalization', () {
      final mockNow = DateTime(2026, 8, 23, 10, 0);
      final todayCivil = CivilDay.fromDateTime(mockNow); // 2026-08-23
      final tomorrowCivil = CivilDay.fromDateTime(
        mockNow.add(const Duration(days: 1)),
      ); // 2026-08-24

      setUp(() {
        AppClock.setMockTime(mockNow);
      });

      tearDown(() {
        AppClock.reset();
      });

      test(
        'normalizes scheduledDate to today and dayOffset to 0 when converting OneOffSchedule for tomorrow with dayOffset -1 to recurring kind',
        () {
          final oneOffTomorrow = OneOffSchedule(
            date: tomorrowCivil,
            startRelativeTime: const RelativeTime(
              dayOffset: -1,
              time: TimeOfDay(hour: 20, minute: 15),
            ),
            dueRelativeTime: defaultDue,
          );

          for (final kind in HierarchicalRecurrenceKind.values) {
            if (kind == HierarchicalRecurrenceKind.oneOff) continue;

            final converted = convertRuleToKind(oneOffTomorrow, kind);
            expect(
              converted.scheduledDate,
              todayCivil,
              reason: 'scheduledDate normalized to today for $kind',
            );
            expect(
              converted.startRelativeTime,
              const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 20, minute: 15),
              ),
              reason: 'startRelativeTime normalized to dayOffset 0 for $kind',
            );
          }
        },
      );

      test(
        'does not normalize when target kind is HierarchicalRecurrenceKind.oneOff',
        () {
          final oneOffTomorrow = OneOffSchedule(
            date: tomorrowCivil,
            startRelativeTime: const RelativeTime(
              dayOffset: -1,
              time: TimeOfDay(hour: 20, minute: 15),
            ),
          );

          final converted =
              convertRuleToKind(
                    oneOffTomorrow,
                    HierarchicalRecurrenceKind.oneOff,
                  )
                  as OneOffSchedule;

          expect(converted.date, tomorrowCivil);
          expect(
            converted.startRelativeTime,
            const RelativeTime(
              dayOffset: -1,
              time: TimeOfDay(hour: 20, minute: 15),
            ),
          );
        },
      );

      test('does not normalize when scheduledDate is not tomorrow', () {
        // Date is day after tomorrow
        final dayAfterTomorrow = CivilDay.fromDateTime(
          mockNow.add(const Duration(days: 2)),
        );
        final oneOffFuture = OneOffSchedule(
          date: dayAfterTomorrow,
          startRelativeTime: const RelativeTime(
            dayOffset: -1,
            time: TimeOfDay(hour: 20, minute: 15),
          ),
        );

        final converted = convertRuleToKind(
          oneOffFuture,
          HierarchicalRecurrenceKind.dailyFixed,
        );

        expect(converted.scheduledDate, dayAfterTomorrow);
        expect(
          converted.startRelativeTime,
          const RelativeTime(
            dayOffset: -1,
            time: TimeOfDay(hour: 20, minute: 15),
          ),
        );
      });

      test('does not normalize when startRelativeTime.dayOffset is not -1', () {
        final oneOffTomorrowDayOffset0 = OneOffSchedule(
          date: tomorrowCivil,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 20, minute: 15),
          ),
        );

        final converted = convertRuleToKind(
          oneOffTomorrowDayOffset0,
          HierarchicalRecurrenceKind.dailyFixed,
        );

        expect(converted.scheduledDate, tomorrowCivil);
        expect(
          converted.startRelativeTime,
          const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 20, minute: 15),
          ),
        );
      });

      test('does not normalize when source rule is not OneOffSchedule', () {
        final dailyTomorrow = DailySchedule(
          startDate: tomorrowCivil,
          interval: 1,
          startRelativeTime: const RelativeTime(
            dayOffset: -1,
            time: TimeOfDay(hour: 20, minute: 15),
          ),
        );

        final converted = convertRuleToKind(
          dailyTomorrow,
          HierarchicalRecurrenceKind.weeklyFixed,
        );

        expect(converted.scheduledDate, tomorrowCivil);
        expect(
          converted.startRelativeTime,
          const RelativeTime(
            dayOffset: -1,
            time: TimeOfDay(hour: 20, minute: 15),
          ),
        );
      });
    });

    group('Group 5: Exhaustive Cross-Kind Conversion Matrix', () {
      TaskScheduleRule makeRule(HierarchicalRecurrenceKind kind) {
        switch (kind) {
          case HierarchicalRecurrenceKind.oneOff:
            return OneOffSchedule(
              date: testDate,
              startRelativeTime: defaultStart,
            );
          case HierarchicalRecurrenceKind.dailyFixed:
            return DailySchedule(
              startDate: testDate,
              interval: 2,
              startRelativeTime: defaultStart,
              schedulingPolicy: const FixedCalendarPolicy(),
            );
          case HierarchicalRecurrenceKind.dailyCompletionRelative:
            return DailySchedule(
              startDate: testDate,
              interval: 2,
              startRelativeTime: defaultStart,
              schedulingPolicy: const CompletionRelativePolicy(
                interval: Duration(days: 2),
                targetTime: TimeOfDay(hour: 9, minute: 0),
              ),
            );
          case HierarchicalRecurrenceKind.weeklyFixed:
            return WeeklySchedule(
              startDate: testDate,
              interval: 2,
              daysOfWeek: const {6},
              startRelativeTime: defaultStart,
              schedulingPolicy: const FixedCalendarPolicy(),
            );
          case HierarchicalRecurrenceKind.weeklyCompletionRelative:
            return WeeklySchedule(
              startDate: testDate,
              interval: 2,
              daysOfWeek: const {6},
              startRelativeTime: defaultStart,
              schedulingPolicy: const CompletionRelativePolicy(
                interval: Duration(days: 14),
                targetTime: TimeOfDay(hour: 9, minute: 0),
              ),
            );
          case HierarchicalRecurrenceKind.monthlyFixedDay:
            return MonthlySchedule(
              startDate: testDate,
              interval: 2,
              dayOfMonth: 15,
              startRelativeTime: defaultStart,
              schedulingPolicy: const FixedCalendarPolicy(),
            );
          case HierarchicalRecurrenceKind.monthlyNthWeekday:
            return MonthlySchedule(
              startDate: testDate,
              interval: 2,
              dayOfWeek: 6,
              occurrence: 3,
              startRelativeTime: defaultStart,
              schedulingPolicy: const FixedCalendarPolicy(),
            );
          case HierarchicalRecurrenceKind.monthlyCompletionRelative:
            return MonthlySchedule(
              startDate: testDate,
              interval: 2,
              dayOfMonth: 15,
              startRelativeTime: defaultStart,
              schedulingPolicy: const CompletionRelativePolicy(
                interval: Duration(days: 60),
                targetTime: TimeOfDay(hour: 9, minute: 0),
              ),
            );
          case HierarchicalRecurrenceKind.yearlyFixed:
            return YearlySchedule(
              startDate: testDate,
              interval: 2,
              month: 8,
              day: 15,
              startRelativeTime: defaultStart,
              schedulingPolicy: const FixedCalendarPolicy(),
            );
          case HierarchicalRecurrenceKind.yearlyCompletionRelative:
            return YearlySchedule(
              startDate: testDate,
              interval: 2,
              month: 8,
              day: 15,
              startRelativeTime: defaultStart,
              schedulingPolicy: const CompletionRelativePolicy(
                interval: Duration(days: 730),
                targetTime: TimeOfDay(hour: 9, minute: 0),
              ),
            );
        }
      }

      for (final fromKind in HierarchicalRecurrenceKind.values) {
        for (final toKind in HierarchicalRecurrenceKind.values) {
          test('Converts from ${fromKind.name} to ${toKind.name}', () {
            final source = makeRule(fromKind);
            final converted = convertRuleToKind(source, toKind);
            expect(converted.hierarchicalKind, toKind);
          });
        }
      }
    });
  });
}
