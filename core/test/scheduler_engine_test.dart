import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('SchedulerEngine Core Tests', () {
    test('evaluates daily task and spawns instances', () {
      final today = CivilDay(year: 2026, month: 9, day: 8);
      final now = DateTime(2026, 9, 8, 8, 0);

      final task = TaskSchedule(
        id: 'task-1',
        title: 'Daily Task',
        description: 'Test task',
        schedules: [
          DailySchedule(
            startDate: today,
            interval: 1,
            startRelativeTime: const RelativeTime(hour: 9, minute: 0),
            dueRelativeTime: const RelativeTime(hour: 17, minute: 0),
          ),
        ],
      );

      final action = const SchedulerEngine().evaluate(task, [], now);
      expect(action.instancesToSpawn, isNotEmpty);
      expect(action.instancesToSpawn.first.title, equals('Daily Task'));
      expect(action.instancesToSpawn.first.scheduledDate, equals(today));
      expect(action.instancesToSpawn.first.status, equals(TaskStatus.pending));
    });

    test('evaluates completion relative scheduling', () {
      final today = CivilDay(year: 2026, month: 9, day: 8);
      final completedAt = DateTime(2026, 9, 8, 10, 0);
      final now = DateTime(2026, 9, 10, 12, 0); // 2 days later

      final task = TaskSchedule(
        id: 'task-cr',
        title: 'Completion Relative Task',
        description: 'Test task',
        schedules: [
          DailySchedule(
            startDate: today,
            interval: 2,
            startRelativeTime: const RelativeTime(hour: 9, minute: 0),
            dueRelativeTime: const RelativeTime(hour: 17, minute: 0),
            schedulingPolicy: const CompletionRelativePolicy(
              interval: Duration(days: 2),
              targetHour: 9,
              targetMinute: 0,
            ),
          ),
        ],
      );

      final completedInst = TaskInstance(
        id: 'inst-completed',
        scheduleId: task.id,
        ruleId: task.schedules.first.id,
        title: task.title,
        description: task.description,
        scheduledDate: today,
        startRelativeTime: const RelativeTime(hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(hour: 17, minute: 0),
        status: TaskStatus.completed,
        completedAt: completedAt,
      );

      final action =
          const SchedulerEngine().evaluate(task, [completedInst], now);
      expect(action.instancesToSpawn, hasLength(1));
      expect(
        action.instancesToSpawn.first.scheduledDate,
        equals(CivilDay(year: 2026, month: 9, day: 10)),
      );
    });

    test('evaluates completion relative scheduling when occurrence is skipped',
        () {
      final today = CivilDay(year: 2026, month: 9, day: 8);
      final skippedAt = DateTime(2026, 9, 8, 10, 0);
      final now = DateTime(2026, 9, 10, 12, 0); // 2 days later

      final task = TaskSchedule(
        id: 'task-cr',
        title: 'Completion Relative Task',
        description: 'Test task',
        schedules: [
          DailySchedule(
            startDate: today,
            interval: 2,
            startRelativeTime: const RelativeTime(hour: 9, minute: 0),
            dueRelativeTime: const RelativeTime(hour: 17, minute: 0),
            schedulingPolicy: const CompletionRelativePolicy(
              interval: Duration(days: 2),
              targetHour: 9,
              targetMinute: 0,
            ),
          ),
        ],
      );

      final skippedInst = TaskInstance(
        id: 'inst-skipped',
        scheduleId: task.id,
        ruleId: task.schedules.first.id,
        title: task.title,
        description: task.description,
        scheduledDate: today,
        startRelativeTime: const RelativeTime(hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(hour: 17, minute: 0),
        status: TaskStatus.skipped,
        completedAt: null,
        updatedAt: skippedAt,
      );

      final action = const SchedulerEngine().evaluate(task, [skippedInst], now);
      expect(action.instancesToSpawn, hasLength(1));
      expect(
        action.instancesToSpawn.first.scheduledDate,
        equals(CivilDay(year: 2026, month: 9, day: 10)),
      );
    });

    test(
        'evaluates completion relative scheduling ordering when older completed instance exists before skipped instance',
        () {
      final startDate = CivilDay(year: 2026, month: 9, day: 1);
      final completedAt = DateTime(2026, 9, 1, 10, 0);
      final skippedAt = DateTime(2026, 9, 8, 10, 0);
      final now = DateTime(2026, 9, 10, 12, 0);

      final task = TaskSchedule(
        id: 'task-cr',
        title: 'Completion Relative Task',
        description: 'Test task',
        schedules: [
          DailySchedule(
            startDate: startDate,
            interval: 2,
            startRelativeTime: const RelativeTime(hour: 9, minute: 0),
            dueRelativeTime: const RelativeTime(hour: 17, minute: 0),
            schedulingPolicy: const CompletionRelativePolicy(
              interval: Duration(days: 2),
              targetHour: 9,
              targetMinute: 0,
            ),
          ),
        ],
      );

      final olderCompletedInst = TaskInstance(
        id: 'inst-1',
        scheduleId: task.id,
        ruleId: task.schedules.first.id,
        title: task.title,
        description: task.description,
        scheduledDate: startDate,
        startRelativeTime: const RelativeTime(hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(hour: 17, minute: 0),
        status: TaskStatus.completed,
        completedAt: completedAt,
        updatedAt: completedAt,
      );

      final newerSkippedInst = TaskInstance(
        id: 'inst-2',
        scheduleId: task.id,
        ruleId: task.schedules.first.id,
        title: task.title,
        description: task.description,
        scheduledDate: CivilDay(year: 2026, month: 9, day: 8),
        startRelativeTime: const RelativeTime(hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(hour: 17, minute: 0),
        status: TaskStatus.skipped,
        completedAt: null,
        updatedAt: skippedAt,
      );

      final action = const SchedulerEngine()
          .evaluate(task, [olderCompletedInst, newerSkippedInst], now);
      expect(action.instancesToSpawn, hasLength(1));
      expect(
        action.instancesToSpawn.first.scheduledDate,
        equals(CivilDay(year: 2026, month: 9, day: 10)),
      );
    });

    test('spawned instances inherit labelIds from parent schedule', () {
      final today = CivilDay(year: 2026, month: 9, day: 8);
      final now = DateTime(2026, 9, 8, 8, 0);

      final task = TaskSchedule(
        id: 'task-labels',
        title: 'Labeled Daily Task',
        description: 'Test task',
        labelIds: const ['L-cleaning', 'L-urgent'],
        schedules: [
          DailySchedule(
            startDate: today,
            interval: 1,
            startRelativeTime: const RelativeTime(hour: 9, minute: 0),
            dueRelativeTime: const RelativeTime(hour: 17, minute: 0),
          ),
        ],
      );

      final action = const SchedulerEngine().evaluate(task, [], now);
      expect(action.instancesToSpawn, isNotEmpty);
      for (final inst in action.instancesToSpawn) {
        expect(inst.labelIds, equals(['L-cleaning', 'L-urgent']));
      }

      final oneOffTask = TaskSchedule(
        id: 'task-oneoff',
        title: 'One-off Task',
        description: 'Desc',
        labelIds: const ['L-groceries'],
        schedules: [
          OneOffSchedule(
            date: today,
            startRelativeTime: const RelativeTime(hour: 10, minute: 0),
            dueRelativeTime: const RelativeTime(hour: 12, minute: 0),
          ),
        ],
      );

      final oneOffAction =
          const SchedulerEngine().evaluate(oneOffTask, [], now);
      expect(oneOffAction.instancesToSpawn, isNotEmpty);
      expect(
        oneOffAction.instancesToSpawn.first.labelIds,
        equals(['L-groceries']),
      );
    });

    test('evaluates exhausted schedule rule gracefully without throwing', () {
      final today = CivilDay(year: 2026, month: 9, day: 8);
      final now = DateTime(2026, 9, 8, 8, 0);

      final weeklyEmpty = WeeklySchedule(
        id: 'R-empty-weekly',
        scheduleId: 'task-exhausted',
        startDate: today,
        interval: 1,
        daysOfWeek: const {},
        startRelativeTime: const RelativeTime(hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(hour: 17, minute: 0),
      );

      final task = TaskSchedule(
        id: 'task-exhausted',
        title: 'Exhausted Schedule Task',
        description: 'Test task',
        schedules: [weeklyEmpty],
      );

      final completedInst = TaskInstance(
        id: 'inst-completed',
        scheduleId: task.id,
        ruleId: task.schedules.first.id,
        title: task.title,
        description: task.description,
        scheduledDate: today,
        startRelativeTime: const RelativeTime(hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(hour: 17, minute: 0),
        status: TaskStatus.completed,
        completedAt: now,
      );

      // Should not throw Exception('No occurrence found within 10 years')
      final action = const SchedulerEngine().evaluate(
        task,
        [completedInst],
        now,
      );
      expect(action.instancesToSpawn, isEmpty);
    });

    test(
        'evaluates exhausted schedule rule with no existing instances without spawning bogus startDate occurrence',
        () {
      final today = const CivilDay(year: 2026, month: 9, day: 8);
      final now = DateTime(2026, 9, 8, 8, 0);

      final weeklyEmpty = WeeklySchedule(
        id: 'R-empty-weekly',
        scheduleId: 'task-exhausted-initial',
        startDate: today,
        interval: 1,
        daysOfWeek: const {},
      );
      final leapYearOdd = YearlySchedule(
        id: 'R-leap-odd',
        scheduleId: 'task-exhausted-initial',
        startDate: const CivilDay(year: 2025, month: 2, day: 28),
        interval: 2,
        month: 2,
        day: 29,
      );

      final task = TaskSchedule(
        id: 'task-exhausted-initial',
        title: 'Exhausted Initial Task',
        description: 'Should spawn nothing',
        schedules: [weeklyEmpty, leapYearOdd],
      );

      final action = const SchedulerEngine().evaluate(task, const [], now);
      expect(action.instancesToSpawn, isEmpty);
    });

    test(
        'capacity limits do not revive user-dismissed or policy-skipped instances',
        () {
      final today = const CivilDay(year: 2026, month: 9, day: 8);
      final tomorrow = today.addDays(1);
      final dayAfter = today.addDays(2);
      final threeDaysOut = today.addDays(3);
      final now = DateTime(2026, 9, 8, 8, 0);

      final rule = DailySchedule(
        id: 'R-cap',
        scheduleId: 'task-cap',
        startDate: today,
        interval: 1,
        startRelativeTime: const RelativeTime(hour: 10, minute: 0),
        dueRelativeTime: const RelativeTime(hour: 17, minute: 0),
      );

      final taskWithCapacity = TaskSchedule(
        id: 'task-cap',
        title: 'Capacity Task',
        description: 'Test capacity revival',
        estimatedDuration: const Duration(hours: 2),
        skipIfNoCapacity: true,
        schedules: [rule],
      );

      final userDismissed = TaskInstance(
        id: 'I-user-dismissed',
        scheduleId: taskWithCapacity.id,
        ruleId: rule.id,
        title: taskWithCapacity.title,
        description: taskWithCapacity.description,
        scheduledDate: today,
        startRelativeTime: rule.startRelativeTime,
        dueRelativeTime: rule.dueRelativeTime,
        status: TaskStatus.skipped,
        statusReason: InstanceStatusReason.userDismissed.value,
      );

      final policySkipped = TaskInstance(
        id: 'I-policy-skipped',
        scheduleId: taskWithCapacity.id,
        ruleId: rule.id,
        title: taskWithCapacity.title,
        description: taskWithCapacity.description,
        scheduledDate: tomorrow,
        startRelativeTime: rule.startRelativeTime,
        dueRelativeTime: rule.dueRelativeTime,
        status: TaskStatus.skipped,
        statusReason: InstanceStatusReason.schedulerPreferOlder.value,
      );

      final capacitySkipped = TaskInstance(
        id: 'I-capacity-skipped',
        scheduleId: taskWithCapacity.id,
        ruleId: rule.id,
        title: taskWithCapacity.title,
        description: taskWithCapacity.description,
        scheduledDate: dayAfter,
        startRelativeTime: rule.startRelativeTime,
        dueRelativeTime: rule.dueRelativeTime,
        status: TaskStatus.skipped,
        statusReason: InstanceStatusReason.schedulerCapacityLimit.value,
      );

      final autoDismissSkipped = TaskInstance(
        id: 'I-autodismiss-skipped',
        scheduleId: taskWithCapacity.id,
        ruleId: rule.id,
        title: taskWithCapacity.title,
        description: taskWithCapacity.description,
        scheduledDate: threeDaysOut,
        startRelativeTime: rule.startRelativeTime,
        dueRelativeTime: rule.dueRelativeTime,
        status: TaskStatus.skipped,
        statusReason: InstanceStatusReason.schedulerAutoDismiss.value,
      );

      // 1. With skipIfNoCapacity: true and plenty of capacity, only capacitySkipped is revived
      final action1 = const SchedulerEngine().evaluate(
        taskWithCapacity,
        [userDismissed, policySkipped, capacitySkipped, autoDismissSkipped],
        now,
      );
      expect(
        action1.instancesToUpdate.map((i) => i.id).toList(),
        equals(['I-capacity-skipped']),
      );
      expect(action1.instancesToUpdate.first.status, TaskStatus.pending);
      expect(action1.instancesToUpdate.first.statusReason, isNull);

      // 2. With skipIfNoCapacity: false, still only capacitySkipped is revived
      final taskWithoutCapacity =
          taskWithCapacity.copyWith(skipIfNoCapacity: false);
      final action2 = const SchedulerEngine().evaluate(
        taskWithoutCapacity,
        [userDismissed, policySkipped, capacitySkipped, autoDismissSkipped],
        now,
      );
      expect(
        action2.instancesToUpdate.map((i) => i.id).toList(),
        equals(['I-capacity-skipped']),
      );
      expect(action2.instancesToUpdate.first.status, TaskStatus.pending);
      expect(action2.instancesToUpdate.first.statusReason, isNull);
    });

    test(
        'spawns full future lookahead queue for MonthlySchedule and YearlySchedule beyond 30 days',
        () {
      final today = const CivilDay(year: 2026, month: 6, day: 15);
      final now = DateTime(2026, 6, 15, 9, 0);

      final monthlyRule = MonthlySchedule(
        id: 'R-monthly',
        scheduleId: 'task-lookahead',
        startDate: today,
        interval: 1,
        dayOfMonth: 15,
      );
      final yearlyRule = YearlySchedule(
        id: 'R-yearly',
        scheduleId: 'task-lookahead',
        startDate: today,
        interval: 1,
        month: 6,
        day: 15,
      );

      final task = TaskSchedule(
        id: 'task-lookahead',
        title: 'Lookahead Task',
        description: 'Monthly and Yearly lookahead',
        schedules: [monthlyRule, yearlyRule],
      );

      final action = const SchedulerEngine().evaluate(task, const [], now);

      final monthlySpawns = action.instancesToSpawn
          .where((i) => i.ruleId == monthlyRule.id)
          .map((i) => i.scheduledDate)
          .toList();
      // Today + 3 future months
      expect(
        monthlySpawns,
        equals([
          const CivilDay(year: 2026, month: 6, day: 15),
          const CivilDay(year: 2026, month: 7, day: 15),
          const CivilDay(year: 2026, month: 8, day: 15),
          const CivilDay(year: 2026, month: 9, day: 15),
        ]),
      );

      final yearlySpawns = action.instancesToSpawn
          .where((i) => i.ruleId == yearlyRule.id)
          .map((i) => i.scheduledDate)
          .toList();
      // Today + 2 future years
      expect(
        yearlySpawns,
        equals([
          const CivilDay(year: 2026, month: 6, day: 15),
          const CivilDay(year: 2027, month: 6, day: 15),
          const CivilDay(year: 2028, month: 6, day: 15),
        ]),
      );
    });

    test(
        'preferNewer and preferOlder do not prematurely skip today or tomorrow when startRelativeTime has negative dayOffset',
        () {
      final today = const CivilDay(year: 2026, month: 9, day: 8);
      final tomorrow = today.addDays(1);
      final now = DateTime(2026, 9, 8, 21, 0); // 9:00 PM on today

      // Tomorrow's occurrence has startRelativeTime dayOffset: -1, hour: 20 (Today at 8:00 PM)
      final preferNewerTask = TaskSchedule(
        id: 'task-prefer-newer-neg',
        title: 'Prefer Newer Negative Offset',
        description: 'Desc',
        schedules: [
          DailySchedule(
            id: 'R-pn',
            scheduleId: 'task-prefer-newer-neg',
            startDate: today,
            interval: 1,
            startRelativeTime:
                const RelativeTime(dayOffset: -1, hour: 20, minute: 0),
            dueRelativeTime:
                const RelativeTime(dayOffset: 0, hour: 18, minute: 0),
            missedOccurrencePolicy: const MissedOccurrencePolicy.preferNewer(),
          ),
        ],
      );

      final actionNewer = const SchedulerEngine().evaluate(
        preferNewerTask,
        const [],
        now,
        futureInstancesCount: 1,
      );
      final todayNewer = actionNewer.instancesToSpawn
          .firstWhere((i) => i.scheduledDate == today);
      final tomorrowNewer = actionNewer.instancesToSpawn
          .firstWhere((i) => i.scheduledDate == tomorrow);
      expect(todayNewer.status, TaskStatus.pending);
      expect(tomorrowNewer.status, TaskStatus.pending);

      final preferOlderTask = TaskSchedule(
        id: 'task-prefer-older-neg',
        title: 'Prefer Older Negative Offset',
        description: 'Desc',
        schedules: [
          DailySchedule(
            id: 'R-po',
            scheduleId: 'task-prefer-older-neg',
            startDate: today,
            interval: 1,
            startRelativeTime:
                const RelativeTime(dayOffset: -1, hour: 20, minute: 0),
            dueRelativeTime:
                const RelativeTime(dayOffset: 0, hour: 18, minute: 0),
            missedOccurrencePolicy: const MissedOccurrencePolicy.preferOlder(),
          ),
        ],
      );

      final actionOlder = const SchedulerEngine().evaluate(
        preferOlderTask,
        const [],
        now,
        futureInstancesCount: 1,
      );
      final todayOlder = actionOlder.instancesToSpawn
          .firstWhere((i) => i.scheduledDate == today);
      final tomorrowOlder = actionOlder.instancesToSpawn
          .firstWhere((i) => i.scheduledDate == tomorrow);
      expect(todayOlder.status, TaskStatus.pending);
      expect(tomorrowOlder.status, TaskStatus.pending);
    });

    test(
        'MonthlySchedule and YearlySchedule with CompletionRelativePolicy advance by calendar months and years',
        () {
      final jan31 = const CivilDay(year: 2026, month: 1, day: 31);
      final monthlyRule = MonthlySchedule(
        id: 'R-monthly-cr',
        scheduleId: 'task-monthly-cr',
        startDate: jan31,
        interval: 1,
        dayOfMonth: -1,
        schedulingPolicy: const CompletionRelativePolicy(
          interval: Duration(days: 30),
          targetHour: 9,
          targetMinute: 0,
        ),
      );
      final monthlyTask = TaskSchedule(
        id: 'task-monthly-cr',
        title: 'Monthly CR',
        description: 'Clamps Jan 31 -> Feb 28',
        schedules: [monthlyRule],
      );

      final completedJan31 = TaskInstance(
        id: 'I-jan31',
        scheduleId: monthlyTask.id,
        ruleId: monthlyRule.id,
        title: monthlyTask.title,
        description: monthlyTask.description,
        scheduledDate: jan31,
        startRelativeTime: const RelativeTime(hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(hour: 17, minute: 0),
        status: TaskStatus.completed,
        completedAt: DateTime(2026, 1, 31, 10, 0),
      );

      // getNextOccurrenceToSpawn clamps Jan 31 + 1 month to Feb 28 (not March 2)
      final spawnedNext = const SchedulerEngine().getNextOccurrenceToSpawn(
        monthlyTask,
        completedJan31,
        DateTime(2026, 1, 31, 10, 0),
        [completedJan31],
      );
      expect(spawnedNext, isNotNull);
      expect(
        spawnedNext!.scheduledDate,
        equals(const CivilDay(year: 2026, month: 2, day: 28)),
      );

      // evaluate() also spawns Feb 28 once Feb 28 10:00 arrives
      final evalAction = const SchedulerEngine().evaluate(
        monthlyTask,
        [completedJan31],
        DateTime(2026, 2, 28, 12, 0),
      );
      expect(evalAction.instancesToSpawn, hasLength(1));
      expect(
        evalAction.instancesToSpawn.first.scheduledDate,
        equals(const CivilDay(year: 2026, month: 2, day: 28)),
      );

      // YearlySchedule clamps Feb 29, 2024 + 1 year to Feb 28, 2025
      final leapDay2024 = const CivilDay(year: 2024, month: 2, day: 29);
      final yearlyRule = YearlySchedule(
        id: 'R-yearly-cr',
        scheduleId: 'task-yearly-cr',
        startDate: leapDay2024,
        interval: 1,
        month: 2,
        day: 29,
        schedulingPolicy: const CompletionRelativePolicy(
          interval: Duration(days: 365),
          targetHour: 9,
          targetMinute: 0,
        ),
      );
      expect(
        CivilDay.fromDateTime(
          yearlyRule.nextCompletionRelativeDateTime(
            DateTime(2024, 2, 29, 10, 0),
          ),
        ),
        equals(const CivilDay(year: 2025, month: 2, day: 28)),
      );
    });

    test(
        'getNextOccurrenceToSpawn preserves mealWorkflow payload and getNextOccurrenceIdToDelete never deletes older overdue instances',
        () {
      final today = const CivilDay(year: 2026, month: 9, day: 8);
      final yesterday = today.addDays(-1);
      final tomorrow = today.addDays(1);
      final now = DateTime(2026, 9, 8, 12, 0);

      final rule = DailySchedule(
        id: 'R-meal',
        scheduleId: 'task-meal',
        startDate: yesterday,
        interval: 1,
      );
      final mealTask = TaskSchedule(
        id: 'task-meal',
        title: 'Dinner Plan',
        description: 'Meal task',
        workflowType: 'mealWorkflow',
        mealWorkflowConfig: const MealWorkflowConfig(
          selectTime: RelativeTime(dayOffset: -1, hour: 19, minute: 0),
        ),
        schedules: [rule],
      );

      final overduePending = TaskInstance(
        id: 'I-overdue',
        scheduleId: mealTask.id,
        ruleId: rule.id,
        title: mealTask.title,
        description: mealTask.description,
        scheduledDate: yesterday,
        startRelativeTime: rule.startRelativeTime,
        dueRelativeTime: rule.dueRelativeTime,
        status: TaskStatus.pending,
      );

      final completedToday = TaskInstance(
        id: 'I-today',
        scheduleId: mealTask.id,
        ruleId: rule.id,
        title: mealTask.title,
        description: mealTask.description,
        scheduledDate: today,
        startRelativeTime: rule.startRelativeTime,
        dueRelativeTime: rule.dueRelativeTime,
        status: TaskStatus.completed,
        completedAt: now,
      );

      final spawned = const SchedulerEngine().getNextOccurrenceToSpawn(
        mealTask,
        completedToday,
        now,
        [overduePending, completedToday],
      );
      expect(spawned, isNotNull);
      expect(spawned!.scheduledDate, equals(tomorrow));
      expect(spawned.workflowPayload, isNotNull);
      expect(spawned.workflowPayload!.stage, WorkflowStage.selectMeal);
      expect(
        spawned.startRelativeTime,
        equals(const RelativeTime(dayOffset: -1, hour: 19, minute: 0)),
      );

      // Undoing completedToday when only overduePending exists must NOT delete overduePending
      final idToDeleteWithoutFuture =
          const SchedulerEngine().getNextOccurrenceIdToDelete(
        mealTask,
        completedToday,
        now,
        [overduePending],
      );
      expect(idToDeleteWithoutFuture, isNull);

      // Undoing completedToday when future spawned exists deletes the future instance
      final idToDeleteWithFuture =
          const SchedulerEngine().getNextOccurrenceIdToDelete(
        mealTask,
        completedToday,
        now,
        [overduePending, spawned],
      );
      expect(idToDeleteWithFuture, equals(spawned.id));
    });
  });
}
