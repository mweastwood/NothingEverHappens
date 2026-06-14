import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_list.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';

void main() {
  group('Thorough Task Scheduling Combinations & Permutations', () {
    const defaultStart = RelativeTime(
      dayOffset: 0,
      time: TimeOfDay(hour: 9, minute: 0),
    );
    const defaultDue = RelativeTime(
      dayOffset: 0,
      time: TimeOfDay(hour: 17, minute: 0),
    );

    group('Weekly + Monthly Mixed Schedules', () {
      test('Occurs on either weekly or monthly specified days', () {
        // Start: June 15, 2026 (Monday)
        final startDate = const CivilDay(year: 2026, month: 6, day: 15);
        final weekly = WeeklySchedule(
          startDate: startDate,
          interval: 1,
          daysOfWeek: const {1}, // Mondays
          startRelativeTime: defaultStart,
          dueRelativeTime: defaultDue,
        );

        final monthly = MonthlySchedule(
          startDate: startDate,
          interval: 1,
          dayOfMonth: 20, // 20th of every month
          startRelativeTime: defaultStart,
          dueRelativeTime: defaultDue,
        );

        // Monday June 15 - is Monday (true), is not 20th (false) -> true
        expect(
          weekly.occursOn(const CivilDay(year: 2026, month: 6, day: 15)) ||
              monthly.occursOn(const CivilDay(year: 2026, month: 6, day: 15)),
          isTrue,
        );

        // Saturday June 20 - is not Monday (false), is 20th (true) -> true
        expect(
          weekly.occursOn(const CivilDay(year: 2026, month: 6, day: 20)) ||
              monthly.occursOn(const CivilDay(year: 2026, month: 6, day: 20)),
          isTrue,
        );

        // Sunday June 21 - is not Monday (false), is not 20th (false) -> false
        expect(
          weekly.occursOn(const CivilDay(year: 2026, month: 6, day: 21)) ||
              monthly.occursOn(const CivilDay(year: 2026, month: 6, day: 21)),
          isFalse,
        );
      });

      test(
        'nextOccurrenceAfter computes next correct date from either schedule',
        () {
          final startDate = const CivilDay(year: 2026, month: 6, day: 15);
          final weekly = WeeklySchedule(
            startDate: startDate,
            interval: 1,
            daysOfWeek: const {1}, // Mondays
          );

          final monthly = MonthlySchedule(
            startDate: startDate,
            interval: 1,
            dayOfMonth: 20, // 20th
          );

          // Starting from Monday June 15:
          // Next Monday is June 22. Next 20th is June 20.
          // So the overall earliest next occurrence is June 20.
          final nextWeekly = weekly.nextOccurrenceAfter(startDate);
          final nextMonthly = monthly.nextOccurrenceAfter(startDate);

          expect(nextWeekly, const CivilDay(year: 2026, month: 6, day: 22));
          expect(nextMonthly, const CivilDay(year: 2026, month: 6, day: 20));
        },
      );
    });

    group('Weekly + Daily Mixed Schedules', () {
      test(
        'Advancement and occursOn checks for Daily (2-day interval) + Weekly (Fridays)',
        () {
          final startDate = const CivilDay(
            year: 2026,
            month: 6,
            day: 15,
          ); // Monday
          final daily = DailySchedule(startDate: startDate, interval: 2);
          final weekly = WeeklySchedule(
            startDate: startDate,
            interval: 1,
            daysOfWeek: const {5}, // Friday
          );

          // June 15 (Mon) - daily true, weekly false -> true
          expect(
            daily.occursOn(const CivilDay(year: 2026, month: 6, day: 15)) ||
                weekly.occursOn(const CivilDay(year: 2026, month: 6, day: 15)),
            isTrue,
          );

          // June 16 (Tue) - daily false, weekly false -> false
          expect(
            daily.occursOn(const CivilDay(year: 2026, month: 6, day: 16)) ||
                weekly.occursOn(const CivilDay(year: 2026, month: 6, day: 16)),
            isFalse,
          );

          // June 17 (Wed) - daily true, weekly false -> true
          expect(
            daily.occursOn(const CivilDay(year: 2026, month: 6, day: 17)) ||
                weekly.occursOn(const CivilDay(year: 2026, month: 6, day: 17)),
            isTrue,
          );

          // June 19 (Fri) - daily true (15 + 4 days), weekly true -> true
          expect(
            daily.occursOn(const CivilDay(year: 2026, month: 6, day: 19)) ||
                weekly.occursOn(const CivilDay(year: 2026, month: 6, day: 19)),
            isTrue,
          );
        },
      );
    });

    group('Daily + Monthly Mixed Schedules', () {
      test('Daily (every day) + Monthly (last day of month)', () {
        final startDate = const CivilDay(year: 2026, month: 2, day: 25);
        final daily = DailySchedule(startDate: startDate, interval: 1);
        final monthly = MonthlySchedule(
          startDate: startDate,
          interval: 1,
          dayOfMonth: -1,
        );

        // Feb 28 - both occur (daily due to every day, monthly due to last day of Feb)
        expect(
          daily.occursOn(const CivilDay(year: 2026, month: 2, day: 28)),
          isTrue,
        );
        expect(
          monthly.occursOn(const CivilDay(year: 2026, month: 2, day: 28)),
          isTrue,
        );
      });
    });

    group('Multiple Weekly Schedules', () {
      test('Weekly (Mon/Wed) + Weekly (Sat/Sun)', () {
        final startDate = const CivilDay(year: 2026, month: 6, day: 15);
        final w1 = WeeklySchedule(
          startDate: startDate,
          interval: 1,
          daysOfWeek: const {1, 3},
        );
        final w2 = WeeklySchedule(
          startDate: startDate,
          interval: 1,
          daysOfWeek: const {6, 7},
        );

        // June 15 (Mon) -> w1 true, w2 false
        expect(
          w1.occursOn(const CivilDay(year: 2026, month: 6, day: 15)),
          isTrue,
        );
        expect(
          w2.occursOn(const CivilDay(year: 2026, month: 6, day: 15)),
          isFalse,
        );

        // June 20 (Sat) -> w1 false, w2 true
        expect(
          w1.occursOn(const CivilDay(year: 2026, month: 6, day: 20)),
          isFalse,
        );
        expect(
          w2.occursOn(const CivilDay(year: 2026, month: 6, day: 20)),
          isTrue,
        );
      });
    });

    group('OneOff + Weekly + Monthly Triple Mixed Schedules', () {
      test(
        'Completion advances only the active/past occurrences and preserves future ones',
        () {
          final startDate = const CivilDay(
            year: 2026,
            month: 6,
            day: 15,
          ); // Monday
          final schedules = [
            OneOffSchedule(
              date: const CivilDay(year: 2026, month: 6, day: 16),
            ), // Tuesday (One-off)
            WeeklySchedule(
              startDate: startDate,
              interval: 1,
              daysOfWeek: const {1},
            ), // Mondays
            MonthlySchedule(
              startDate: startDate,
              interval: 1,
              dayOfMonth: 20,
            ), // 20th
          ];

          final task = TaskSchedule(
            id: 'triple-mixed',
            title: 'Triple Mixed',
            description: 'Testing 3 schedule types',
            schedules: schedules,
            missedPolicy: MissedPolicy.rollover,
          );

          final taskList = TaskList([task]);

          // Mock time to Monday June 15
          AppClock.setMockTime(DateTime(2026, 6, 15, 12, 0));
          var nextState = taskList.complete('triple-mixed', 'user-1');

          var updatedTask = nextState.activeTasks.firstWhere(
            (t) => t.id == 'triple-mixed',
          );
          expect(updatedTask.schedules.length, 3);

          // Weekly schedule should advance from June 15 to June 22
          final weekly = updatedTask.schedules[1] as WeeklySchedule;
          expect(
            weekly.startDate,
            const CivilDay(year: 2026, month: 6, day: 22),
          );

          // Monthly schedule advances to next occurrence (June 20) since startDate was today
          final monthly = updatedTask.schedules[2] as MonthlySchedule;
          expect(
            monthly.startDate,
            const CivilDay(year: 2026, month: 6, day: 20),
          );

          // OneOff stays June 16 (future)
          final oneoff = updatedTask.schedules[0] as OneOffSchedule;
          expect(oneoff.date, const CivilDay(year: 2026, month: 6, day: 16));

          // Now move clock to June 16 and complete again
          AppClock.setMockTime(DateTime(2026, 6, 16, 12, 0));
          nextState = nextState.complete('triple-mixed', 'user-1');

          updatedTask = nextState.activeTasks.firstWhere(
            (t) => t.id == 'triple-mixed',
          );
          // The one-off from June 16 should now be removed since it occurred/completed
          expect(updatedTask.schedules.length, 2);
          expect(updatedTask.schedules[0], isA<WeeklySchedule>());
          expect(updatedTask.schedules[1], isA<MonthlySchedule>());

          AppClock.reset();
        },
      );
    });

    group('Missed Policy Variations on Mixed Schedules', () {
      test(
        'Rollover: mixed schedules advance sequentially based on elapsed dates',
        () {
          final startDate = const CivilDay(
            year: 2026,
            month: 6,
            day: 15,
          ); // Monday
          final schedules = [
            WeeklySchedule(
              startDate: startDate,
              interval: 1,
              daysOfWeek: const {1},
            ), // Mon
            WeeklySchedule(
              startDate: startDate,
              interval: 1,
              daysOfWeek: const {3},
            ), // Wed
          ];

          final task = TaskSchedule(
            id: 'rollover-mixed',
            title: 'Rollover Mixed',
            description: 'Testing Rollover',
            schedules: schedules,
            missedPolicy: MissedPolicy.rollover,
          );

          final taskList = TaskList([task]);

          // Complete on Monday June 15
          AppClock.setMockTime(DateTime(2026, 6, 15, 12, 0));
          var nextState = taskList.complete('rollover-mixed', 'user-1');

          var updatedTask = nextState.activeTasks.firstWhere(
            (t) => t.id == 'rollover-mixed',
          );
          // Monday schedule advances to next Monday (June 22)
          expect(
            (updatedTask.schedules[0] as WeeklySchedule).startDate,
            const CivilDay(year: 2026, month: 6, day: 22),
          );
          // Wednesday schedule advances to next Wednesday (June 17) since startDate was today
          expect(
            (updatedTask.schedules[1] as WeeklySchedule).startDate,
            const CivilDay(year: 2026, month: 6, day: 17),
          );

          AppClock.reset();
        },
      );

      test(
        'Skip: mixed schedules skip past occurrences and reschedule to next upcoming dates',
        () {
          final startDate = const CivilDay(
            year: 2026,
            month: 6,
            day: 15,
          ); // Monday
          final schedules = [
            WeeklySchedule(
              startDate: startDate,
              interval: 1,
              daysOfWeek: const {1},
            ), // Mon
            WeeklySchedule(
              startDate: startDate,
              interval: 1,
              daysOfWeek: const {3},
            ), // Wed
          ];

          final task = TaskSchedule(
            id: 'skip-mixed',
            title: 'Skip Mixed',
            description: 'Testing Skip',
            schedules: schedules,
            missedPolicy: MissedPolicy.skip,
          );

          final taskList = TaskList([task]);

          // Mock time to Friday June 19 (so Monday 15th and Wednesday 17th are both in the past)
          AppClock.setMockTime(DateTime(2026, 6, 19, 12, 0));
          final nextState = taskList.complete('skip-mixed', 'user-1');

          final updatedTask = nextState.activeTasks.firstWhere(
            (t) => t.id == 'skip-mixed',
          );
          // Under Skip policy:
          // Mon June 15 schedule should skip to next Monday (June 22)
          expect(
            (updatedTask.schedules[0] as WeeklySchedule).startDate,
            const CivilDay(year: 2026, month: 6, day: 22),
          );
          // Wed June 17 schedule should skip to next Wednesday (June 24)
          expect(
            (updatedTask.schedules[1] as WeeklySchedule).startDate,
            const CivilDay(year: 2026, month: 6, day: 24),
          );

          AppClock.reset();
        },
      );

      test(
        'Shift: mixed schedules shift dates forward relative to completion time',
        () {
          final startDate = const CivilDay(
            year: 2026,
            month: 6,
            day: 15,
          ); // Monday
          final schedules = [
            DailySchedule(startDate: startDate, interval: 3), // every 3 days
          ];

          final task = TaskSchedule(
            id: 'shift-mixed',
            title: 'Shift Mixed',
            description: 'Testing Shift',
            schedules: schedules,
            missedPolicy: MissedPolicy.shift,
          );

          final taskList = TaskList([task]);

          // Complete 2 days late on Wednesday June 17
          AppClock.setMockTime(DateTime(2026, 6, 17, 12, 0));
          final nextState = taskList.complete('shift-mixed', 'user-1');

          final updatedTask = nextState.activeTasks.firstWhere(
            (t) => t.id == 'shift-mixed',
          );
          // Under Shift policy (advances task strictly after completion time June 17 -> June 18):
          expect(
            (updatedTask.schedules[0] as DailySchedule).startDate,
            const CivilDay(year: 2026, month: 6, day: 18),
          );

          AppClock.reset();
        },
      );
    });

    group('Edge Cases & Boundaries', () {
      test('MonthlySchedule: End of month rollover and negative days', () {
        final startDate = const CivilDay(year: 2026, month: 1, day: 31);
        final schedule = MonthlySchedule(
          startDate: startDate,
          interval: 1,
          dayOfMonth: -1, // Last day of month
        );

        // Should occur on Jan 31
        expect(
          schedule.occursOn(const CivilDay(year: 2026, month: 1, day: 31)),
          isTrue,
        );
        // Should occur on Feb 28 (non-leap year last day)
        expect(
          schedule.occursOn(const CivilDay(year: 2026, month: 2, day: 28)),
          isTrue,
        );
        // Should not occur on Feb 27
        expect(
          schedule.occursOn(const CivilDay(year: 2026, month: 2, day: 27)),
          isFalse,
        );
      });

      test(
        'MonthlySchedule: Last occurrence of day of week (occurrence = -1)',
        () {
          final startDate = const CivilDay(year: 2026, month: 6, day: 1);
          final schedule = MonthlySchedule(
            startDate: startDate,
            interval: 1,
            dayOfWeek: 1, // Mondays
            occurrence: -1, // Last Monday of the month
          );

          // June 2026 Mondays: 1, 8, 15, 22, 29.
          // Last Monday is June 29.
          expect(
            schedule.occursOn(const CivilDay(year: 2026, month: 6, day: 29)),
            isTrue,
          );
          expect(
            schedule.occursOn(const CivilDay(year: 2026, month: 6, day: 22)),
            isFalse,
          );
        },
      );

      test('YearlySchedule: Leap year February 29th occurrences', () {
        final startDate = const CivilDay(
          year: 2024,
          month: 2,
          day: 29,
        ); // Leap year
        final schedule = YearlySchedule(
          startDate: startDate,
          interval: 1,
          month: 2,
          day: 29,
        );

        // Occurs on Feb 29, 2024
        expect(schedule.occursOn(startDate), isTrue);
        // nextOccurrenceAfter correctly skips non-leap years (2025, 2026, 2027) and finds Feb 29, 2028
        expect(
          schedule.nextOccurrenceAfter(startDate),
          const CivilDay(year: 2028, month: 2, day: 29),
        );
      });

      test('WeeklySchedule: Safety bound for empty daysOfWeek', () {
        final startDate = const CivilDay(year: 2026, month: 6, day: 15);
        final schedule = WeeklySchedule(
          startDate: startDate,
          interval: 1,
          daysOfWeek: const {}, // Empty weekdays!
        );

        expect(
          () => schedule.nextOccurrenceAfter(startDate),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('No occurrence found within 10 years'),
            ),
          ),
        );
      });
    });
  });
}
