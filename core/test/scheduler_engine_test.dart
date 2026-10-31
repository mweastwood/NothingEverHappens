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

    test(
      'getNextOccurrenceToSpawn normalizes UTC completedAt to local calendar date for CompletionRelativePolicy',
      () {
        final jan31 = const CivilDay(year: 2026, month: 1, day: 31);
        final rule = MonthlySchedule(
          id: 'R-monthly-cr',
          scheduleId: 'task-cr',
          startDate: jan31,
          interval: 1,
          dayOfMonth: -1,
          schedulingPolicy: const CompletionRelativePolicy(
            interval: Duration(days: 30),
            targetHour: 9,
            targetMinute: 0,
          ),
        );
        final task = TaskSchedule(
          id: 'task-cr',
          title: 'Monthly CR Task',
          description: 'Test',
          schedules: [rule],
        );

        // Late-evening local time on Jan 31 (stored as UTC on TaskInstance.completedAt)
        final localCompletionTime = DateTime(2026, 1, 31, 22, 0);
        final completedInstance = TaskInstance(
          id: 'I-jan31',
          scheduleId: task.id,
          ruleId: rule.id,
          title: task.title,
          description: task.description,
          scheduledDate: jan31,
          startRelativeTime: rule.startRelativeTime,
          dueRelativeTime: rule.dueRelativeTime,
          status: TaskStatus.completed,
          completedAt: localCompletionTime, // TaskInstance converts this to UTC
        );
        expect(completedInstance.completedAt!.isUtc, isTrue);

        final spawned = const SchedulerEngine().getNextOccurrenceToSpawn(
          task,
          completedInstance,
          completedInstance.completedAt!,
          [completedInstance],
        );

        expect(spawned, isNotNull);
        expect(
          spawned!.scheduledDate,
          equals(const CivilDay(year: 2026, month: 2, day: 28)),
        );
      },
    );

    test(
      'projectUpcomingOccurrences handles OneOff, fixed-calendar, and CompletionRelativePolicy edge cases',
      () {
        const engine = SchedulerEngine();
        final fromDate = const CivilDay(year: 2026, month: 6, day: 10);

        // 1. OneOffSchedule before and on/after fromDate
        final pastOneOff = OneOffSchedule(
          id: 'R-oneoff-past',
          date: const CivilDay(year: 2026, month: 6, day: 5),
        );
        final futureOneOff = OneOffSchedule(
          id: 'R-oneoff-future',
          date: const CivilDay(year: 2026, month: 6, day: 12),
        );
        final oneOffTask = TaskSchedule(
          id: 'T-oneoff',
          title: 'OneOff',
          description: '',
          schedules: [pastOneOff, futureOneOff],
        );
        expect(
          engine.projectUpcomingOccurrences(oneOffTask, pastOneOff, fromDate),
          isEmpty,
        );
        expect(
          engine.projectUpcomingOccurrences(oneOffTask, futureOneOff, fromDate),
          equals([const CivilDay(year: 2026, month: 6, day: 12)]),
        );

        // 2. Fixed-calendar rule
        final weeklyRule = WeeklySchedule(
          id: 'R-weekly',
          startDate: const CivilDay(year: 2026, month: 6, day: 1),
          interval: 1,
          daysOfWeek: const {3}, // Wednesday (June 10, 17, 24)
        );
        final weeklyTask = TaskSchedule(
          id: 'T-weekly',
          title: 'Weekly',
          description: '',
          schedules: [weeklyRule],
        );
        expect(
          engine.projectUpcomingOccurrences(
            weeklyTask,
            weeklyRule,
            fromDate,
            count: 3,
          ),
          equals([
            const CivilDay(year: 2026, month: 6, day: 10),
            const CivilDay(year: 2026, month: 6, day: 17),
            const CivilDay(year: 2026, month: 6, day: 24),
          ]),
        );

        // 3. CompletionRelativePolicy: initial (no instances), overdue pending, elapsed resolved, and sub-day deduplication
        final crDailyRule = DailySchedule(
          id: 'R-cr-daily',
          scheduleId: 'T-cr',
          startDate: const CivilDay(year: 2026, month: 6, day: 1),
          interval: 2,
          schedulingPolicy: const CompletionRelativePolicy(
            interval: Duration(days: 2),
            targetHour: 9,
            targetMinute: 0,
          ),
        );
        final crTask = TaskSchedule(
          id: 'T-cr',
          title: 'CR Task',
          description: '',
          schedules: [crDailyRule],
        );

        // Initial (startDate before fromDate -> clamps to fromDate)
        expect(
          engine.projectUpcomingOccurrences(
            crTask,
            crDailyRule,
            fromDate,
            count: 3,
          ),
          equals([
            const CivilDay(year: 2026, month: 6, day: 10),
            const CivilDay(year: 2026, month: 6, day: 12),
            const CivilDay(year: 2026, month: 6, day: 14),
          ]),
        );

        // Overdue pending instance (scheduledDate June 5 < fromDate June 10 -> clamps first upcoming to June 10)
        final overduePending = TaskInstance(
          id: 'I-overdue',
          scheduleId: crTask.id,
          ruleId: crDailyRule.id,
          title: crTask.title,
          description: crTask.description,
          scheduledDate: const CivilDay(year: 2026, month: 6, day: 5),
          startRelativeTime: crDailyRule.startRelativeTime,
          dueRelativeTime: crDailyRule.dueRelativeTime,
          status: TaskStatus.pending,
        );
        expect(
          engine.projectUpcomingOccurrences(
            crTask,
            crDailyRule,
            fromDate,
            count: 3,
            existingInstances: [overduePending],
          ),
          equals([
            const CivilDay(year: 2026, month: 6, day: 10),
            const CivilDay(year: 2026, month: 6, day: 12),
            const CivilDay(year: 2026, month: 6, day: 14),
          ]),
        );

        // Resolved instance whose next occurrence is in the past (completed June 1 + 2d = June 3 < June 10 -> clamps to June 10)
        final oldResolved = TaskInstance(
          id: 'I-resolved-old',
          scheduleId: crTask.id,
          ruleId: crDailyRule.id,
          title: crTask.title,
          description: crTask.description,
          scheduledDate: const CivilDay(year: 2026, month: 6, day: 1),
          startRelativeTime: crDailyRule.startRelativeTime,
          dueRelativeTime: crDailyRule.dueRelativeTime,
          status: TaskStatus.completed,
          completedAt: DateTime(2026, 6, 1, 10, 0),
        );
        expect(
          engine.projectUpcomingOccurrences(
            crTask,
            crDailyRule,
            fromDate,
            count: 3,
            existingInstances: [oldResolved],
          ),
          equals([
            const CivilDay(year: 2026, month: 6, day: 10),
            const CivilDay(year: 2026, month: 6, day: 12),
            const CivilDay(year: 2026, month: 6, day: 14),
          ]),
        );

        // Sub-day CompletionRelativePolicy interval deduplicates same CivilDay
        final subDayRule = DailySchedule(
          id: 'R-subday',
          scheduleId: 'T-subday',
          startDate: fromDate,
          interval: 1,
          schedulingPolicy: const CompletionRelativePolicy(
            interval: Duration(hours: 6),
            targetHour: 9,
            targetMinute: 0,
          ),
        );
        final subDayTask = TaskSchedule(
          id: 'T-subday',
          title: 'Sub-day CR',
          description: '',
          schedules: [subDayRule],
        );
        final projectedSubDay = engine.projectUpcomingOccurrences(
          subDayTask,
          subDayRule,
          fromDate,
          count: 3,
        );
        expect(
          projectedSubDay,
          equals([
            const CivilDay(year: 2026, month: 6, day: 10),
            const CivilDay(year: 2026, month: 6, day: 11),
            const CivilDay(year: 2026, month: 6, day: 12),
          ]),
        );
      },
    );

    group('Timezone-Aware & Multi-Timezone Bounding-Box Evaluation', () {
      const engine = SchedulerEngine();

      test(
        'utcOffset evaluates floating wall-clock start and autoDismiss relative to target timezone instead of UTC',
        () {
          const pdtOffset = Duration(hours: -7);
          final rule = DailySchedule(
            id: 'R-tz-daily',
            scheduleId: 'T-tz-daily',
            startDate: const CivilDay(year: 2026, month: 9, day: 10),
            interval: 1,
            startRelativeTime: const RelativeTime(hour: 7, minute: 30),
            dueRelativeTime: const RelativeTime(hour: 20, minute: 0),
          );
          final task = TaskSchedule(
            id: 'T-tz-daily',
            title: 'Daily Mass',
            description: '',
            missedOccurrencePolicy: const MissedOccurrencePolicy.autoDismiss(
              gracePeriod: Duration.zero,
            ),
            schedules: [rule],
          );

          // 1. At 2026-09-10 10:00 UTC (03:00 PDT): spawns for today with pending status, triggerTimes includes 07:30 PDT (14:30 UTC)
          final beforeStart = engine.evaluate(
            task,
            [],
            DateTime.utc(2026, 9, 10, 10, 0),
            utcOffset: pdtOffset,
          );
          final sept10Inst = beforeStart.instancesToSpawn.firstWhere(
            (i) =>
                i.scheduledDate ==
                const CivilDay(year: 2026, month: 9, day: 10),
          );
          expect(sept10Inst.status, equals(TaskStatus.pending));
          expect(
            beforeStart.triggerTimes,
            contains(DateTime.utc(2026, 9, 10, 14, 30)),
          );

          // 2. At 2026-09-10 14:30 UTC (07:30 PDT): triggerTimes includes 20:00 PDT (03:00 UTC next day)
          final atStart = engine.evaluate(
            task,
            beforeStart.instancesToSpawn,
            DateTime.utc(2026, 9, 10, 14, 30),
            utcOffset: pdtOffset,
          );
          expect(atStart.instancesToUpdate, isEmpty);
          expect(
            atStart.triggerTimes,
            contains(DateTime.utc(2026, 9, 11, 3, 0)),
          );

          // 3. At 2026-09-10 21:00 UTC (14:00 PDT): past 20:00 UTC, but still 14:00 PDT -> MUST NOT auto-dismiss!
          final midAfternoonPdt = engine.evaluate(
            task,
            beforeStart.instancesToSpawn,
            DateTime.utc(2026, 9, 10, 21, 0),
            utcOffset: pdtOffset,
          );
          expect(midAfternoonPdt.instancesToUpdate, isEmpty);

          // 4. At 2026-09-11 03:01 UTC (20:01 PDT on Sep 10): past 20:00 PDT -> auto-dismisses Sep 10 instance!
          final atDuePdt = engine.evaluate(
            task,
            beforeStart.instancesToSpawn,
            DateTime.utc(2026, 9, 11, 3, 1),
            utcOffset: pdtOffset,
          );
          expect(atDuePdt.instancesToUpdate, hasLength(1));
          expect(
            atDuePdt.instancesToUpdate.single.scheduledDate,
            equals(const CivilDay(year: 2026, month: 9, day: 10)),
          );
          expect(
            atDuePdt.instancesToUpdate.single.status,
            equals(TaskStatus.skipped),
          );
          expect(
            atDuePdt.instancesToUpdate.single.statusReason,
            equals(InstanceStatusReason.schedulerAutoDismiss.value),
          );
        },
      );

      test(
        'earliestUtcOffset and latestUtcOffset implement Option 1 bounding-box window for multi-timezone families',
        () {
          const edtOffset = Duration(hours: -4); // Eastern member (earliest)
          const pdtOffset = Duration(hours: -7); // Western member (latest)

          final rule = DailySchedule(
            id: 'R-family-tz',
            scheduleId: 'T-family-tz',
            startDate: const CivilDay(year: 2026, month: 9, day: 10),
            interval: 1,
            startRelativeTime: const RelativeTime(hour: 8, minute: 0),
            dueRelativeTime: const RelativeTime(hour: 20, minute: 0),
          );
          final task = TaskSchedule(
            id: 'T-family-tz',
            title: 'Family Chore',
            description: '',
            isFamily: true,
            missedOccurrencePolicy: const MissedOccurrencePolicy.autoDismiss(
              gracePeriod: Duration.zero,
            ),
            schedules: [rule],
          );

          // 1. At 2026-09-10 11:00 UTC (07:00 EDT / 04:00 PDT): triggerTimes includes 08:00 EDT (12:00 UTC)
          final beforeEasternStart = engine.evaluate(
            task,
            [],
            DateTime.utc(2026, 9, 10, 11, 0),
            earliestUtcOffset: edtOffset,
            latestUtcOffset: pdtOffset,
          );
          expect(
            beforeEasternStart.triggerTimes,
            contains(DateTime.utc(2026, 9, 10, 12, 0)),
          );

          // 2. At 2026-09-11 01:00 UTC (21:00 EDT / 18:00 PDT): past due in EDT, still active in PDT -> NOT dismissed!
          final afterEasternDue = engine.evaluate(
            task,
            beforeEasternStart.instancesToSpawn,
            DateTime.utc(2026, 9, 11, 1, 0),
            earliestUtcOffset: edtOffset,
            latestUtcOffset: pdtOffset,
          );
          expect(afterEasternDue.instancesToUpdate, isEmpty);
          expect(
            afterEasternDue.triggerTimes,
            contains(DateTime.utc(2026, 9, 11, 3, 0)),
          );

          // 3. At 2026-09-11 03:01 UTC (23:01 EDT / 20:01 PDT): due in westernmost timezone -> dismissed
          final atWesternDue = engine.evaluate(
            task,
            beforeEasternStart.instancesToSpawn,
            DateTime.utc(2026, 9, 11, 3, 1),
            earliestUtcOffset: edtOffset,
            latestUtcOffset: pdtOffset,
          );
          expect(atWesternDue.instancesToUpdate, hasLength(1));
          expect(
            atWesternDue.instancesToUpdate.single.scheduledDate,
            equals(const CivilDay(year: 2026, month: 9, day: 10)),
          );
          expect(
            atWesternDue.instancesToUpdate.single.status,
            equals(TaskStatus.skipped),
          );
        },
      );

      test(
        'CompletionRelativePolicy computes next scheduledDate in earliestUtcOffset local wall-clock time across UTC midnight',
        () {
          const pdtOffset = Duration(hours: -7);
          final rule = DailySchedule(
            id: 'R-cr-tz',
            scheduleId: 'T-cr-tz',
            startDate: const CivilDay(year: 2026, month: 9, day: 10),
            interval: 1,
            startRelativeTime: const RelativeTime(hour: 8, minute: 0),
            dueRelativeTime: const RelativeTime(hour: 20, minute: 0),
            schedulingPolicy: const CompletionRelativePolicy(
              interval: Duration(days: 1),
              targetHour: 8,
              targetMinute: 0,
            ),
          );
          final task = TaskSchedule(
            id: 'T-cr-tz',
            title: 'Water Plants',
            description: '',
            schedules: [rule],
          );

          // Completed on 2026-09-10 at 20:00 PDT, which is 2026-09-11 03:00 UTC (next UTC day!)
          final completedInstance = TaskInstance(
            id: 'I-cr-1',
            scheduleId: task.id,
            ruleId: rule.id,
            title: task.title,
            description: task.description,
            scheduledDate: const CivilDay(year: 2026, month: 9, day: 10),
            startRelativeTime: rule.startRelativeTime,
            dueRelativeTime: rule.dueRelativeTime,
            status: TaskStatus.completed,
            completedAt: DateTime.utc(2026, 9, 11, 3, 0),
          );

          // At 2026-09-12 03:00 UTC (2026-09-11 20:00 PDT): 24h after completion,
          // local calendar day in PDT is Sep 11 (whereas in UTC it would be Sep 12).
          final afterIntervalPdt = engine.evaluate(
            task,
            [completedInstance],
            DateTime.utc(2026, 9, 12, 3, 0),
            utcOffset: pdtOffset,
          );
          expect(afterIntervalPdt.instancesToSpawn, hasLength(1));
          expect(
            afterIntervalPdt.instancesToSpawn.single.scheduledDate,
            equals(const CivilDay(year: 2026, month: 9, day: 11)),
          );

          // Verify getNextOccurrenceToSpawn and projectUpcomingOccurrences also respect utcOffset
          final nextToSpawn = engine.getNextOccurrenceToSpawn(
            task,
            completedInstance,
            DateTime.utc(2026, 9, 11, 3, 0),
            [completedInstance],
            utcOffset: pdtOffset,
          );
          expect(
            nextToSpawn?.scheduledDate,
            equals(const CivilDay(year: 2026, month: 9, day: 11)),
          );
          final projected = engine.projectUpcomingOccurrences(
            task,
            rule,
            const CivilDay(year: 2026, month: 9, day: 10),
            count: 2,
            existingInstances: [completedInstance],
            utcOffset: pdtOffset,
          );
          expect(
            projected,
            equals([
              const CivilDay(year: 2026, month: 9, day: 11),
              const CivilDay(year: 2026, month: 9, day: 12),
            ]),
          );
        },
      );

      test(
        'preferNewer and preferOlder wait until startRelativeTime in latestUtcOffset before skipping across multi-timezone bounding box',
        () {
          const edtOffset = Duration(hours: -4); // Eastern member (earliest)
          const pdtOffset = Duration(hours: -7); // Western member (latest)

          final rule = DailySchedule(
            id: 'R-pref',
            scheduleId: 'T-pref',
            startDate: const CivilDay(year: 2026, month: 9, day: 10),
            interval: 1,
            startRelativeTime: const RelativeTime(hour: 8, minute: 0),
            dueRelativeTime: const RelativeTime(hour: 20, minute: 0),
          );

          final preferNewerTask = TaskSchedule(
            id: 'T-pref',
            title: 'Prefer Newer Family Task',
            description: '',
            isFamily: true,
            missedOccurrencePolicy: const MissedOccurrencePolicy.preferNewer(),
            schedules: [rule],
          );

          final sept10Inst = TaskInstance(
            id: 'I-sep10',
            scheduleId: 'S-T-pref',
            ruleId: 'R-pref',
            title: 'Prefer Newer Family Task',
            description: '',
            isFamily: true,
            scheduledDate: const CivilDay(year: 2026, month: 9, day: 10),
            startRelativeTime: rule.startRelativeTime,
            dueRelativeTime: rule.dueRelativeTime,
            status: TaskStatus.pending,
          );
          final sept11Inst = TaskInstance(
            id: 'I-sep11',
            scheduleId: 'S-T-pref',
            ruleId: 'R-pref',
            title: 'Prefer Newer Family Task',
            description: '',
            isFamily: true,
            scheduledDate: const CivilDay(year: 2026, month: 9, day: 11),
            startRelativeTime: rule.startRelativeTime,
            dueRelativeTime: rule.dueRelativeTime,
            status: TaskStatus.pending,
          );

          // 1. At 2026-09-11 13:00 UTC (09:00 EDT / 06:00 PDT):
          // Sep 11 08:00 has started in EDT, but NOT yet in PDT (06:00 PDT < 08:00 PDT).
          // Neither preferNewer nor preferOlder should skip yet!
          final beforeWesternStartNewer = engine.evaluate(
            preferNewerTask,
            [sept10Inst, sept11Inst],
            DateTime.utc(2026, 9, 11, 13, 0),
            earliestUtcOffset: edtOffset,
            latestUtcOffset: pdtOffset,
          );
          expect(beforeWesternStartNewer.instancesToUpdate, isEmpty);

          final preferOlderTask = preferNewerTask.copyWith(
            missedOccurrencePolicy: const MissedOccurrencePolicy.preferOlder(),
          );
          final beforeWesternStartOlder = engine.evaluate(
            preferOlderTask,
            [sept10Inst, sept11Inst],
            DateTime.utc(2026, 9, 11, 13, 0),
            earliestUtcOffset: edtOffset,
            latestUtcOffset: pdtOffset,
          );
          expect(beforeWesternStartOlder.instancesToUpdate, isEmpty);

          // 2. At 2026-09-11 15:01 UTC (11:01 EDT / 08:01 PDT):
          // Sep 11 08:00 has now started in PDT (latestUtcOffset) as well!
          final afterWesternStartNewer = engine.evaluate(
            preferNewerTask,
            [sept10Inst, sept11Inst],
            DateTime.utc(2026, 9, 11, 15, 1),
            earliestUtcOffset: edtOffset,
            latestUtcOffset: pdtOffset,
          );
          expect(afterWesternStartNewer.instancesToUpdate, hasLength(1));
          expect(
            afterWesternStartNewer.instancesToUpdate.single.id,
            equals('I-sep10'),
          );
          expect(
            afterWesternStartNewer.instancesToUpdate.single.statusReason,
            equals(InstanceStatusReason.schedulerPreferNewer.value),
          );

          final afterWesternStartOlder = engine.evaluate(
            preferOlderTask,
            [sept10Inst, sept11Inst],
            DateTime.utc(2026, 9, 11, 15, 1),
            earliestUtcOffset: edtOffset,
            latestUtcOffset: pdtOffset,
          );
          expect(afterWesternStartOlder.instancesToUpdate, hasLength(1));
          expect(
            afterWesternStartOlder.instancesToUpdate.single.id,
            equals('I-sep11'),
          );
          expect(
            afterWesternStartOlder.instancesToUpdate.single.statusReason,
            equals(InstanceStatusReason.schedulerPreferOlder.value),
          );
        },
      );
    });

    group('Family Scope & Completion Mode Reconciliation', () {
      test(
        'reconciles stale isFamily and familyCompletionMode on existing pending, skipped, and completed instances for fixed-calendar, completion-relative, and one-off tasks',
        () {
          const engine = SchedulerEngine(
            appVersion: 'v1.9.10',
            platform: 'test',
          );
          final now = DateTime.utc(2026, 10, 21, 10, 0);

          final rule = WeeklySchedule(
            id: 'R-trash',
            scheduleId: 'S-trash',
            startDate: const CivilDay(year: 2026, month: 10, day: 1),
            interval: 1,
            daysOfWeek: const {DateTime.friday},
            startRelativeTime: const RelativeTime(hour: 9, minute: 0),
            dueRelativeTime: const RelativeTime(hour: 17, minute: 0),
          );

          final personalTask = TaskSchedule(
            id: 'S-trash',
            title: 'Take in the trash',
            description: '',
            isFamily: false,
            familyCompletionMode: FamilyCompletionMode.anyone,
            schedules: [rule],
          );

          final staleCompleted = TaskInstance(
            id: 'I-completed-fam',
            scheduleId: 'S-trash',
            ruleId: 'R-trash',
            title: 'Take in the trash',
            description: '',
            scheduledDate: const CivilDay(year: 2026, month: 10, day: 9),
            startRelativeTime: rule.startRelativeTime,
            dueRelativeTime: rule.dueRelativeTime,
            isFamily: true,
            familyCompletionMode: FamilyCompletionMode.individual,
            status: TaskStatus.completed,
            completedAt: DateTime.utc(2026, 10, 9, 18, 0),
          );

          final staleMissedPending = TaskInstance(
            id: 'I-missed-fam',
            scheduleId: 'S-trash',
            ruleId: 'R-trash',
            title: 'Take in the trash',
            description: '',
            scheduledDate: const CivilDay(year: 2026, month: 10, day: 16),
            startRelativeTime: rule.startRelativeTime,
            dueRelativeTime: rule.dueRelativeTime,
            isFamily: true,
            status: TaskStatus.pending,
          );

          final staleFuturePending = [
            for (final day in [
              const CivilDay(year: 2026, month: 10, day: 23),
              const CivilDay(year: 2026, month: 10, day: 30),
              const CivilDay(year: 2026, month: 11, day: 6),
              const CivilDay(year: 2026, month: 11, day: 13),
              const CivilDay(year: 2026, month: 11, day: 20),
            ])
              TaskInstance(
                id: 'I-future-$day',
                scheduleId: 'S-trash',
                ruleId: 'R-trash',
                title: 'Take in the trash',
                description: '',
                scheduledDate: day,
                startRelativeTime: rule.startRelativeTime,
                dueRelativeTime: rule.dueRelativeTime,
                isFamily: true,
                status: TaskStatus.pending,
              ),
          ];

          final action = engine.evaluate(
            personalTask.copyWith(
              missedOccurrencePolicy: const MissedOccurrencePolicy.autoDismiss(
                gracePeriod: Duration(days: 1),
              ),
            ),
            [staleCompleted, staleMissedPending, ...staleFuturePending],
            now,
            userId: 'user-1',
          );

          // All 7 existing instances (1 completed, 1 newly skipped, 5 future pending)
          // must be returned in instancesToUpdate with isFamily: false.
          expect(action.instancesToUpdate, hasLength(7));
          for (final updated in action.instancesToUpdate) {
            expect(updated.isFamily, isFalse);
            expect(updated.familyCompletionMode, FamilyCompletionMode.anyone);
            expect(updated.lastModifiedByUserId, 'user-1');
            expect(updated.lastModifiedByAppVersion, 'v1.9.10');
            expect(updated.lastModifiedByPlatform, 'test');
          }

          final updatedMissed = action.instancesToUpdate.firstWhere(
            (i) => i.id == 'I-missed-fam',
          );
          expect(updatedMissed.status, TaskStatus.skipped);
          expect(updatedMissed.isFamily, isFalse);

          // One-off task with stale isFamily on existing instance
          final oneOffRule = OneOffSchedule(
            id: 'R-oneoff',
            scheduleId: 'S-oneoff',
            date: const CivilDay(year: 2026, month: 10, day: 25),
          );
          final oneOffTask = TaskSchedule(
            id: 'S-oneoff',
            title: 'One-Off Personal',
            description: '',
            isFamily: false,
            schedules: [oneOffRule],
          );
          final staleOneOffInst = TaskInstance(
            id: 'I-oneoff',
            scheduleId: 'S-oneoff',
            ruleId: 'R-oneoff',
            title: 'One-Off Personal',
            description: '',
            scheduledDate: const CivilDay(year: 2026, month: 10, day: 25),
            startRelativeTime: oneOffRule.startRelativeTime,
            dueRelativeTime: oneOffRule.dueRelativeTime,
            isFamily: true,
            status: TaskStatus.pending,
          );
          final oneOffAction = engine.evaluate(
            oneOffTask,
            [staleOneOffInst],
            now,
          );
          expect(oneOffAction.instancesToSpawn, isEmpty);
          expect(oneOffAction.instancesToUpdate, hasLength(1));
          expect(oneOffAction.instancesToUpdate.single.isFamily, isFalse);
          expect(oneOffAction.instancesToUpdate.single.updatedAt, now.toUtc());
        },
      );

      test(
        'bumps updatedAt to now.toUtc() and sets lastModifiedBy metadata on spawned instances, updated instances, updatedSchedule, and getNextOccurrenceToSpawn',
        () {
          const engine = SchedulerEngine(
            appVersion: 'v1.9.10',
            platform: 'linux',
          );
          final oldTimestamp = DateTime.utc(2026, 9, 1, 0, 0);
          final evalNow = DateTime.utc(2026, 10, 21, 9, 30);

          final rule = DailySchedule(
            id: 'R-daily',
            scheduleId: 'S-daily',
            startDate: const CivilDay(year: 2026, month: 10, day: 19),
            interval: 1,
            startRelativeTime: const RelativeTime(hour: 8, minute: 0),
            dueRelativeTime: const RelativeTime(hour: 10, minute: 0),
            missedOccurrencePolicy: const MissedOccurrencePolicy.autoDismiss(
              gracePeriod: Duration(hours: 2),
            ),
          );
          final task = TaskSchedule(
            id: 'S-daily',
            title: 'Daily Task',
            description: '',
            schedules: [rule],
            updatedAt: oldTimestamp,
          );

          final expiredInst = TaskInstance(
            id: 'I-oct19',
            scheduleId: 'S-daily',
            ruleId: 'R-daily',
            title: 'Daily Task',
            description: '',
            scheduledDate: const CivilDay(year: 2026, month: 10, day: 19),
            startRelativeTime: rule.startRelativeTime,
            dueRelativeTime: rule.dueRelativeTime,
            status: TaskStatus.pending,
            updatedAt: oldTimestamp,
          );

          final action = engine.evaluate(
            task,
            [expiredInst],
            evalNow,
            userId: 'user-meta',
          );

          expect(action.updatedSchedule, isNotNull);
          expect(action.updatedSchedule!.updatedAt, equals(evalNow));

          expect(action.instancesToUpdate, isNotEmpty);
          for (final updated in action.instancesToUpdate) {
            expect(updated.updatedAt, equals(evalNow));
            expect(updated.lastModifiedByUserId, equals('user-meta'));
            expect(updated.lastModifiedByAppVersion, equals('v1.9.10'));
            expect(updated.lastModifiedByPlatform, equals('linux'));
          }

          expect(action.instancesToSpawn, isNotEmpty);
          for (final spawned in action.instancesToSpawn) {
            expect(spawned.updatedAt, equals(evalNow));
            expect(spawned.lastModifiedByUserId, equals('user-meta'));
            expect(spawned.lastModifiedByAppVersion, equals('v1.9.10'));
            expect(spawned.lastModifiedByPlatform, equals('linux'));
          }

          final nextSpawned = engine.getNextOccurrenceToSpawn(
            task,
            expiredInst.copyWith(status: TaskStatus.completed),
            evalNow,
            const [],
            userId: 'user-meta',
          );
          expect(nextSpawned, isNotNull);
          expect(nextSpawned!.updatedAt, equals(evalNow));
          expect(nextSpawned.lastModifiedByUserId, equals('user-meta'));
          expect(nextSpawned.lastModifiedByAppVersion, equals('v1.9.10'));
          expect(nextSpawned.lastModifiedByPlatform, equals('linux'));
        },
      );

      test(
        'fixed-calendar rule with >30 existing stacked past instances spawns new occurrences up to today and future lookahead',
        () {
          const engine = SchedulerEngine();
          final evalNow = DateTime.utc(2026, 3, 15, 10, 0);
          final startDate = const CivilDay(year: 2026, month: 2, day: 1);
          final today = const CivilDay(year: 2026, month: 3, day: 15);

          final rule = DailySchedule(
            id: 'R-daily-stack',
            scheduleId: 'S-daily-stack',
            startDate: startDate,
            interval: 1,
            missedOccurrencePolicy: const MissedOccurrencePolicy(
              policy: MissedPolicy.stack,
            ),
          );
          final task = TaskSchedule(
            id: 'S-daily-stack',
            title: 'Stacked Daily Task',
            description: '',
            schedules: [rule],
          );

          // Pre-populate 35 already-spawned pending instances from Feb 1 through Mar 7
          final existingInstances = <TaskInstance>[];
          var d = startDate;
          for (var i = 0; i < 35; i++) {
            existingInstances.add(
              TaskInstance(
                id: 'I-stack-$i',
                scheduleId: task.id,
                ruleId: rule.id,
                title: task.title,
                description: '',
                scheduledDate: d,
                startRelativeTime: rule.startRelativeTime,
                dueRelativeTime: rule.dueRelativeTime,
                status: TaskStatus.pending,
              ),
            );
            d = d.addDays(1);
          }

          final action = engine.evaluate(
            task,
            existingInstances,
            evalNow,
            futureInstancesCount: 2,
            utcOffset: Duration.zero,
          );
          final spawnedDates =
              action.instancesToSpawn.map((i) => i.scheduledDate).toSet();

          // Should spawn remaining past dates up to today (Mar 15) plus 2 future occurrences (Mar 16, Mar 17)
          expect(spawnedDates, contains(today));
          expect(
            spawnedDates,
            contains(const CivilDay(year: 2026, month: 3, day: 16)),
          );
          expect(
            spawnedDates,
            contains(const CivilDay(year: 2026, month: 3, day: 17)),
          );
        },
      );
    });
  });
}
