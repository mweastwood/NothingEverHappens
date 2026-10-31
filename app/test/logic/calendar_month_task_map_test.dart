import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/screens/calendar_screen.dart';

void main() {
  group('CalendarScreen.computeMonthTaskMap', () {
    final march2026 = DateTime(2026, 3, 1);
    const today = CivilDay(year: 2026, month: 3, day: 8);

    final dailySchedule = TaskSchedule(
      id: 'S-daily',
      title: 'Daily Task',
      description: 'Daily recurring schedule',
      priority: TaskPriority.high,
      schedules: [
        DailySchedule(
          id: 'R-daily',
          scheduleId: 'S-daily',
          startDate: const CivilDay(year: 2026, month: 3, day: 1),
          interval: 1,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 8,
            minute: 0,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 12,
            minute: 0,
          ),
        ),
      ],
    );

    final oneOffSchedule = TaskSchedule(
      id: 'S-oneoff',
      title: 'One-off Task',
      description: 'One-off non-recurring schedule',
      priority: TaskPriority.low,
      schedules: [
        OneOffSchedule(
          id: 'R-oneoff',
          scheduleId: 'S-oneoff',
          date: const CivilDay(year: 2026, month: 3, day: 15),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 10,
            minute: 0,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 11,
            minute: 0,
          ),
        ),
      ],
    );

    test(
      'skipped concrete instance is excluded and prevents projected task resurrection',
      () {
        final skippedInstance = TaskInstance(
          id: 'I-skipped',
          scheduleId: 'S-daily',
          ruleId: 'R-daily',
          title: 'Daily Task',
          description: 'Daily recurring schedule',
          priority: TaskPriority.high,
          scheduledDate: today,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 8,
            minute: 0,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 12,
            minute: 0,
          ),
          status: TaskStatus.skipped,
        );

        final map = CalendarScreen.computeMonthTaskMap(
          march2026,
          [skippedInstance],
          [dailySchedule],
          today: today,
        );

        // On today (March 8), the task was skipped. It must NOT appear in the map.
        expect(map[today], isNull);
      },
    );

    test(
      'failed concrete instance is excluded and prevents projected task resurrection',
      () {
        final failedInstance = TaskInstance(
          id: 'I-failed',
          scheduleId: 'S-daily',
          ruleId: 'R-daily',
          title: 'Daily Task',
          description: 'Daily recurring schedule',
          priority: TaskPriority.high,
          scheduledDate: today,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 8,
            minute: 0,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 12,
            minute: 0,
          ),
          status: TaskStatus.failed,
        );

        final map = CalendarScreen.computeMonthTaskMap(
          march2026,
          [failedInstance],
          [dailySchedule],
          today: today,
        );

        // On today (March 8), the task failed. It must NOT appear in the map.
        expect(map[today], isNull);
      },
    );

    test('schedules with only OneOffSchedule rules are never projected', () {
      final map = CalendarScreen.computeMonthTaskMap(march2026, [], [
        oneOffSchedule,
      ], today: today);

      // March 15 has no instance, but oneOffSchedule is non-recurring, so it must not be projected
      const day15 = CivilDay(year: 2026, month: 3, day: 15);
      expect(map[day15], isNull);
      expect(map.isEmpty, isTrue);
    });

    test('recurring tasks are not projected onto past dates prior to today', () {
      final map = CalendarScreen.computeMonthTaskMap(march2026, [], [
        dailySchedule,
      ], today: today);

      // Days 1 through 7 are prior to today (March 8). No tasks should be projected there.
      for (int d = 1; d < 8; d++) {
        final pastDay = CivilDay(year: 2026, month: 3, day: d);
        expect(
          map[pastDay],
          isNull,
          reason: 'Past day $pastDay should not have projected tasks',
        );
      }

      // Today and future days should have projected tasks
      expect(map[today], isNotNull);
      expect(map[today]!.first.id, 'projected_S-daily_2026-03-08');
      const day9 = CivilDay(year: 2026, month: 3, day: 9);
      expect(map[day9], isNotNull);
      expect(map[day9]!.first.id, 'projected_S-daily_2026-03-09');
    });

    test(
      'past concrete instances are retained while projections are suppressed',
      () {
        const pastDay = CivilDay(year: 2026, month: 3, day: 5);
        final pastInstance = TaskInstance(
          id: 'I-past',
          scheduleId: 'S-daily',
          ruleId: 'R-daily',
          title: 'Daily Task',
          description: 'Daily recurring schedule',
          priority: TaskPriority.high,
          scheduledDate: pastDay,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 8,
            minute: 0,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 12,
            minute: 0,
          ),
          status: TaskStatus.completed,
        );

        final map = CalendarScreen.computeMonthTaskMap(
          march2026,
          [pastInstance],
          [dailySchedule],
          today: today,
        );

        expect(map[pastDay], isNotNull);
        expect(map[pastDay]!.length, 1);
        expect(map[pastDay]!.first.id, 'I-past');
        expect(map[pastDay]!.first.isCompleted, isTrue);
      },
    );

    test(
      'pending concrete instance on a future date suppresses duplicate projection',
      () {
        const futureDay = CivilDay(year: 2026, month: 3, day: 10);
        final pendingInstance = TaskInstance(
          id: 'I-pending-future',
          scheduleId: 'S-daily',
          ruleId: 'R-daily',
          title: 'Daily Task',
          description: 'Daily recurring schedule',
          priority: TaskPriority.high,
          scheduledDate: futureDay,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 8,
            minute: 0,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 12,
            minute: 0,
          ),
          status: TaskStatus.pending,
        );

        final map = CalendarScreen.computeMonthTaskMap(
          march2026,
          [pendingInstance],
          [dailySchedule],
          today: today,
        );

        expect(map[futureDay], isNotNull);
        expect(map[futureDay]!.length, 1);
        final task = map[futureDay]!.first;
        expect(task.id, 'I-pending-future');
        expect(task.isInstance, isTrue);
        expect(task.status, TaskStatus.pending);
      },
    );

    test(
      'completion-relative recurring schedule suppresses phantom projected occurrences',
      () {
        final completionRelativeSchedule = TaskSchedule(
          id: 'S-completion-rel',
          title: 'Completion Relative Task',
          description: 'Every 3 days after completion',
          priority: TaskPriority.medium,
          schedules: [
            DailySchedule(
              id: 'R-completion-rel',
              scheduleId: 'S-completion-rel',
              startDate: const CivilDay(year: 2026, month: 3, day: 1),
              interval: 3,
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
                interval: Duration(days: 3),
                targetHour: 9,
                targetMinute: 0,
              ),
            ),
          ],
        );

        final map = CalendarScreen.computeMonthTaskMap(march2026, [], [
          completionRelativeSchedule,
        ], today: today);

        // Should have zero projected occurrences across the entire month
        expect(map.isEmpty, isTrue);
      },
    );

    test(
      'projects multiple recurring rules on the same day and only suppresses rule with concrete instance',
      () {
        const targetDay = CivilDay(year: 2026, month: 3, day: 10);
        final morningRule = DailySchedule(
          id: 'R-morning',
          scheduleId: 'S-multi',
          startDate: const CivilDay(year: 2026, month: 3, day: 1),
          interval: 1,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 8,
            minute: 0,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 10,
            minute: 0,
          ),
        );
        final eveningRule = DailySchedule(
          id: 'R-evening',
          scheduleId: 'S-multi',
          startDate: const CivilDay(year: 2026, month: 3, day: 1),
          interval: 1,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 18,
            minute: 0,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 20,
            minute: 0,
          ),
        );
        final multiRuleSchedule = TaskSchedule(
          id: 'S-multi',
          title: 'Twice Daily Medication',
          description: '',
          schedules: [morningRule, eveningRule],
        );

        final morningInstance = TaskInstance(
          id: 'I-morning-10',
          scheduleId: 'S-multi',
          ruleId: 'R-morning',
          title: 'Twice Daily Medication',
          description: '',
          scheduledDate: targetDay,
          startRelativeTime: morningRule.startRelativeTime,
          dueRelativeTime: morningRule.dueRelativeTime,
          status: TaskStatus.pending,
        );

        final map = CalendarScreen.computeMonthTaskMap(
          march2026,
          [morningInstance],
          [multiRuleSchedule],
          today: today,
        );

        // On March 10, morningRule has a concrete instance and eveningRule is projected
        expect(map[targetDay], hasLength(2));
        expect(map[targetDay]!.any((t) => t.id == 'I-morning-10'), isTrue);
        expect(
          map[targetDay]!.any(
            (t) => !t.isInstance && t.matchingRule?.id == 'R-evening',
          ),
          isTrue,
        );

        // On March 11, both morningRule and eveningRule are projected
        const nextDay = CivilDay(year: 2026, month: 3, day: 11);
        expect(map[nextDay], hasLength(2));
      },
    );
  });
}
