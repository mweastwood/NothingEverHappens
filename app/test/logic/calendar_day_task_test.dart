import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/calendar_day_task.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_label.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';

void main() {
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
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 8, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 12, minute: 0),
      ),
    ],
  );

  final sampleInstance = TaskInstance(
    id: 'I-1',
    scheduleId: 'S-daily',
    ruleId: 'R-daily',
    title: 'Daily Task',
    description: 'Daily recurring schedule',
    priority: TaskPriority.high,
    scheduledDate: const CivilDay(year: 2026, month: 3, day: 8),
    startRelativeTime: const RelativeTime(dayOffset: 0, hour: 8, minute: 0),
    dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 12, minute: 0),
    status: TaskStatus.completed,
  );

  final sampleInstancesList = [sampleInstance];
  final sampleSchedulesList = [dailySchedule];

  group('CalendarMonthTaskCache', () {
    test(
      'returns cached month task map on repeated calls with same parameters',
      () {
        final cache = CalendarMonthTaskCache();
        final map1 = cache.getMonthTaskMap(
          monthDate: march2026,
          instances: sampleInstancesList,
          schedules: sampleSchedulesList,
          today: today,
          currentUserId: 'user-1',
        );

        final map2 = cache.getMonthTaskMap(
          monthDate: march2026,
          instances: sampleInstancesList,
          schedules: sampleSchedulesList,
          today: today,
          currentUserId: 'user-1',
        );

        expect(identical(map1, map2), isTrue);
      },
    );

    test('invalidates cache when instances list reference changes', () {
      final cache = CalendarMonthTaskCache();
      final map1 = cache.getMonthTaskMap(
        monthDate: march2026,
        instances: sampleInstancesList,
        schedules: sampleSchedulesList,
        today: today,
        currentUserId: 'user-1',
      );

      final updatedInstance = sampleInstance.copyWith(
        status: TaskStatus.pending,
      );
      final map2 = cache.getMonthTaskMap(
        monthDate: march2026,
        instances: [updatedInstance],
        schedules: sampleSchedulesList,
        today: today,
        currentUserId: 'user-1',
      );

      expect(identical(map1, map2), isFalse);
    });

    test('invalidates cache when schedules list reference changes', () {
      final cache = CalendarMonthTaskCache();
      final map1 = cache.getMonthTaskMap(
        monthDate: march2026,
        instances: sampleInstancesList,
        schedules: sampleSchedulesList,
        today: today,
        currentUserId: 'user-1',
      );

      final map2 = cache.getMonthTaskMap(
        monthDate: march2026,
        instances: sampleInstancesList,
        schedules: [
          dailySchedule,
          TaskSchedule(
            id: 'S-another',
            title: 'Another task',
            description: 'Another description',
            priority: TaskPriority.low,
            schedules: const [],
          ),
        ],
        today: today,
        currentUserId: 'user-1',
      );

      expect(identical(map1, map2), isFalse);
    });

    test('invalidates cache when user ID changes', () {
      final cache = CalendarMonthTaskCache();
      final map1 = cache.getMonthTaskMap(
        monthDate: march2026,
        instances: sampleInstancesList,
        schedules: sampleSchedulesList,
        today: today,
        currentUserId: 'user-1',
      );

      final map2 = cache.getMonthTaskMap(
        monthDate: march2026,
        instances: sampleInstancesList,
        schedules: sampleSchedulesList,
        today: today,
        currentUserId: 'user-2',
      );

      expect(identical(map1, map2), isFalse);
    });

    test('clear() empties the cache', () {
      final cache = CalendarMonthTaskCache();
      final map1 = cache.getMonthTaskMap(
        monthDate: march2026,
        instances: sampleInstancesList,
        schedules: sampleSchedulesList,
        today: today,
        currentUserId: 'user-1',
      );

      cache.clear();

      final map2 = cache.getMonthTaskMap(
        monthDate: march2026,
        instances: sampleInstancesList,
        schedules: sampleSchedulesList,
        today: today,
        currentUserId: 'user-1',
      );

      expect(identical(map1, map2), isFalse);
      expect(map1.length, equals(map2.length));
    });
  });

  group('computeMonthTaskMap', () {
    final completionRelativeDailySchedule = TaskSchedule(
      id: 'S-completion-rel-daily',
      title: 'Water plants (Completion Relative)',
      description: 'Water every 3 days after completion',
      priority: TaskPriority.medium,
      schedules: [
        DailySchedule(
          id: 'R-completion-rel-daily',
          scheduleId: 'S-completion-rel-daily',
          startDate: const CivilDay(year: 2026, month: 3, day: 1),
          interval: 3,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 9,
            minute: 0,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 18,
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

    final completionRelativeWeeklySchedule = TaskSchedule(
      id: 'S-completion-rel-weekly',
      title: 'Mow lawn (Completion Relative Weekly)',
      description: 'Mow lawn every 1 week after completion',
      priority: TaskPriority.low,
      schedules: [
        WeeklySchedule(
          id: 'R-completion-rel-weekly',
          scheduleId: 'S-completion-rel-weekly',
          startDate: const CivilDay(year: 2026, month: 3, day: 1),
          interval: 1,
          daysOfWeek: {1},
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 10,
            minute: 0,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 16,
            minute: 0,
          ),
          schedulingPolicy: const CompletionRelativePolicy(
            interval: Duration(days: 7),
            targetHour: 10,
            targetMinute: 0,
          ),
        ),
      ],
    );

    final fixedRecurringSchedule = TaskSchedule(
      id: 'S-fixed-recurring',
      title: 'Daily vitamins (Fixed Calendar)',
      description: 'Take daily vitamins',
      priority: TaskPriority.high,
      schedules: [
        DailySchedule(
          id: 'R-fixed-recurring',
          scheduleId: 'S-fixed-recurring',
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
          schedulingPolicy: const FixedCalendarPolicy(),
        ),
      ],
    );

    test(
      'suppresses projected occurrences across the month for completion-relative schedules when no instances exist',
      () {
        final map = computeMonthTaskMap(
          monthDate: march2026,
          instances: const [],
          schedules: [
            completionRelativeDailySchedule,
            completionRelativeWeeklySchedule,
          ],
          today: today,
        );

        // Completion-relative tasks have non-deterministic future dates and must never project phantom tasks.
        final allTasks = map.values.expand((tasks) => tasks).toList();
        expect(allTasks, isEmpty);
      },
    );

    test(
      'retains active/concrete instances for completion-relative schedules without projecting future phantom occurrences',
      () {
        final concreteInstance = TaskInstance(
          id: 'I-rel-1',
          scheduleId: 'S-completion-rel-daily',
          ruleId: 'R-completion-rel-daily',
          title: 'Water plants (Completion Relative)',
          description: 'Water every 3 days after completion',
          priority: TaskPriority.medium,
          scheduledDate: const CivilDay(year: 2026, month: 3, day: 10),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 9,
            minute: 0,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 18,
            minute: 0,
          ),
          status: TaskStatus.pending,
        );

        final map = computeMonthTaskMap(
          monthDate: march2026,
          instances: [concreteInstance],
          schedules: [completionRelativeDailySchedule],
          today: today,
        );

        // March 10 should have the concrete instance
        final tasksOnMarch10 =
            map[const CivilDay(year: 2026, month: 3, day: 10)] ?? [];
        expect(tasksOnMarch10, hasLength(1));
        expect(tasksOnMarch10.first.id, equals('I-rel-1'));
        expect(tasksOnMarch10.first.isInstance, isTrue);

        // No projected tasks should exist on any other day of the month
        final allTasks = map.values.expand((tasks) => tasks).toList();
        expect(allTasks, hasLength(1));
        expect(allTasks.first.id, equals('I-rel-1'));
      },
    );

    test(
      'continues to project recurring occurrences for fixed calendar schedules',
      () {
        final map = computeMonthTaskMap(
          monthDate: march2026,
          instances: const [],
          schedules: [fixedRecurringSchedule],
          today: today,
        );

        // Days from today (March 8) through end of March (31) should have projected occurrences
        for (int day = 8; day <= 31; day++) {
          final dayTasks = map[CivilDay(year: 2026, month: 3, day: day)] ?? [];
          expect(dayTasks, hasLength(1));
          expect(dayTasks.first.isInstance, isFalse);
          expect(dayTasks.first.schedule?.id, equals('S-fixed-recurring'));
        }
      },
    );

    test(
      'ranks rarer weekly and monthly tasks above everyday daily routines via standoutScore',
      () {
        final dailyHigh = TaskSchedule(
          id: 'S-daily-routine',
          title: 'Water Plants',
          description: '',
          priority: TaskPriority.high,
          estimatedDuration: const Duration(minutes: 15),
          schedules: [
            DailySchedule(
              id: 'R-daily-routine',
              scheduleId: 'S-daily-routine',
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

        final weeklyMedium = TaskSchedule(
          id: 'S-weekly-plan',
          title: 'Review Weekly Plan',
          description: '',
          priority: TaskPriority.medium,
          estimatedDuration: const Duration(minutes: 45),
          schedules: [
            WeeklySchedule(
              id: 'R-weekly-plan',
              scheduleId: 'S-weekly-plan',
              startDate: const CivilDay(year: 2026, month: 3, day: 1),
              interval: 1,
              daysOfWeek: {1, 3, 5}, // Mon, Wed, Fri
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
            ),
          ],
        );

        final monthlyMedium = TaskSchedule(
          id: 'S-monthly-bill',
          title: 'Pay Utilities Bill',
          description: '',
          priority: TaskPriority.medium,
          estimatedDuration: const Duration(minutes: 45),
          schedules: [
            MonthlySchedule(
              id: 'R-monthly-bill',
              scheduleId: 'S-monthly-bill',
              startDate: const CivilDay(year: 2026, month: 3, day: 1),
              interval: 1,
              dayOfMonth: 16, // Monday March 16, 2026
              startRelativeTime: const RelativeTime(
                dayOffset: 0,
                hour: 10,
                minute: 0,
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 0,
                hour: 18,
                minute: 0,
              ),
            ),
          ],
        );

        final map = computeMonthTaskMap(
          monthDate: march2026,
          instances: const [],
          schedules: [dailyHigh, weeklyMedium, monthlyMedium],
          today: today,
        );

        // Tuesday March 10 only has daily routine
        final march10 = map[const CivilDay(year: 2026, month: 3, day: 10)]!;
        expect(march10.first.title, equals('Water Plants'));
        expect(march10.first.isRoutineDaily, isTrue);

        // Monday March 9 has daily + weekly -> weekly wins standout
        final march9 = map[const CivilDay(year: 2026, month: 3, day: 9)]!;
        expect(march9.first.title, equals('Review Weekly Plan'));
        expect(march9.first.isRoutineDaily, isFalse);

        // Monday March 16 has daily + weekly + monthly -> monthly wins standout
        final march16 = map[const CivilDay(year: 2026, month: 3, day: 16)]!;
        expect(march16.first.title, equals('Pay Utilities Bill'));
      },
    );
  });

  group('CalendarDayWorkload', () {
    final labelsMap = <String, TaskLabel>{
      'lbl-home': TaskLabel(
        id: 'lbl-home',
        name: 'Home',
        colorKey: 'emerald',
        iconKey: 'home',
        scope: TaskLabelScope.personal,
        order: 0,
        createdAt: DateTime.utc(2026, 3, 1),
      ),
      'lbl-finance': TaskLabel(
        id: 'lbl-finance',
        name: 'Finance',
        colorKey: 'cobalt',
        iconKey: 'payments',
        scope: TaskLabelScope.personal,
        order: 1,
        createdAt: DateTime.utc(2026, 3, 1),
      ),
      'lbl-meals': TaskLabel(
        id: 'lbl-meals',
        name: 'Meals',
        colorKey: 'tangerine',
        iconKey: 'restaurant',
        scope: TaskLabelScope.personal,
        order: 2,
        createdAt: DateTime.utc(2026, 3, 1),
      ),
    };

    test(
      'divides task duration evenly across multiple labels on a single task and falls back to null for unlabeled tasks',
      () {
        final multiLabelSchedule = TaskSchedule(
          id: 'S-multi-lbl',
          title: 'Budget & Home Audit',
          description: '',
          priority: TaskPriority.high,
          estimatedDuration: const Duration(minutes: 60),
          labelIds: const ['lbl-home', 'lbl-finance'],
          schedules: const [],
        );
        final unlabeledSchedule = TaskSchedule(
          id: 'S-unlabeled',
          title: 'Misc Errand',
          description: '',
          priority: TaskPriority.low,
          estimatedDuration: const Duration(minutes: 30),
          schedules: const [],
        );

        final tasks = [
          CalendarDayTask(
            id: 't-1',
            title: multiLabelSchedule.title,
            priority: multiLabelSchedule.priority,
            isInstance: true,
            schedule: multiLabelSchedule,
          ),
          CalendarDayTask(
            id: 't-2',
            title: unlabeledSchedule.title,
            priority: unlabeledSchedule.priority,
            isInstance: true,
            schedule: unlabeledSchedule,
          ),
        ];

        final workload = CalendarDayWorkload.fromTasks(
          tasks,
          capacityHours: 2.0,
          labelsMap: labelsMap,
        );

        expect(workload.totalMinutes, equals(90));
        expect(workload.totalHours, closeTo(1.5, 1e-6));
        expect(workload.loadRatio, closeTo(0.75, 1e-6));
        expect(workload.isOverCapacity, isFalse);
        expect(workload.formattedPlannedHours, equals('1.5h'));

        // 60m divided evenly between emerald and cobalt -> 30m each, plus 30m unlabeled (null) last
        expect(workload.segments, hasLength(3));
        expect(workload.segments[0].colorKey, equals('cobalt'));
        expect(workload.segments[0].minutes, closeTo(30.0, 1e-6));
        expect(workload.segments[1].colorKey, equals('emerald'));
        expect(workload.segments[1].minutes, closeTo(30.0, 1e-6));
        expect(workload.segments[2].colorKey, isNull);
        expect(workload.segments[2].minutes, closeTo(30.0, 1e-6));
      },
    );

    test('detects overload and appends exclamation mark to planned hours', () {
      final bigSchedule = TaskSchedule(
        id: 'S-big',
        title: 'Deep Clean Garage',
        description: '',
        priority: TaskPriority.high,
        estimatedDuration: const Duration(minutes: 210), // 3.5h
        labelIds: const ['lbl-home'],
        schedules: const [],
      );

      final workload = CalendarDayWorkload.fromTasks(
        [
          CalendarDayTask(
            id: 't-big',
            title: bigSchedule.title,
            priority: bigSchedule.priority,
            isInstance: true,
            schedule: bigSchedule,
          ),
        ],
        capacityHours: 3.0,
        labelsMap: labelsMap,
      );

      expect(workload.isOverCapacity, isTrue);
      expect(workload.formattedPlannedHours, equals('3.5h!'));
    });
  });
}
