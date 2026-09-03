import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test_factories.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/scheduler_engine.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/user_settings.dart';

void main() {
  group('SchedulerEngine Tests', () {
    final now = DateTime(2026, 6, 19, 10, 0); // Friday 10:00 AM
    final today = CivilDay.fromDateTime(now);

    group('OneOffSchedule', () {
      test('spawns instance when none exists', () {
        final task = TestTaskFactory.createOneOff(
          id: 'oneoff-1',
          title: 'One Off Task',
          description: 'A simple one-off task',
          date: today,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
        );

        final action = const SchedulerEngine().evaluate(task, [], now);

        expect(action.instancesToSpawn, hasLength(1));
        final spawned = action.instancesToSpawn.first;
        expect(spawned.id.startsWith('I-'), isTrue);
        expect(spawned.scheduledDate, today);
        expect(spawned.status, TaskStatus.pending);
        expect(action.instancesToUpdate, isEmpty);
        expect(action.updatedSchedule, null);
      });

      test('does not spawn instance if it already exists', () {
        final task = TestTaskFactory.createOneOff(
          id: 'oneoff-1',
          title: 'One Off Task',
          description: 'A simple one-off task',
          date: today,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
        );

        final existingInstance = TaskInstance(
          id: 'oneoff-1_2026-06-19',
          scheduleId: task.id,
          ruleId: task.schedules.first.id,
          title: task.title,
          description: task.description,
          scheduledDate: today,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          status: TaskStatus.pending,
        );

        final action = const SchedulerEngine().evaluate(task, [
          existingInstance,
        ], now);

        expect(action.instancesToSpawn, isEmpty);
        expect(action.instancesToUpdate, isEmpty);
        expect(action.updatedSchedule, null);
      });
    });

    group('Mixed Schedule Resurrection Bug', () {
      test(
        'does not resurrect resolved one-off instance when task is recurring due to daily rule',
        () {
          final oneOffRule = OneOffSchedule(
            date: today.addDays(-2),
            missedOccurrencePolicy: const MissedOccurrencePolicy.autoDismiss(
              gracePeriod: Duration.zero,
            ),
          );
          final dailyRule = DailySchedule(
            startDate: today.addDays(-1),
            interval: 1,
          );
          final task = TaskSchedule(
            id: 'mixed-1',
            title: 'Mixed Task',
            description: 'Daily + One-off',
            schedules: [oneOffRule, dailyRule],
          );

          final resolvedOneOff = TaskInstance(
            id: 'I-oneoff',
            scheduleId: task.id,
            ruleId: oneOffRule.id,
            title: task.title,
            description: task.description,
            scheduledDate: today.addDays(-2),
            startRelativeTime: oneOffRule.startRelativeTime,
            dueRelativeTime: oneOffRule.dueRelativeTime,
            status: TaskStatus.completed,
            completedAt: now.subtract(const Duration(days: 2)),
          );

          final action = const SchedulerEngine().evaluate(task, [
            resolvedOneOff,
          ], now);

          // Verify that resolvedOneOff is not modified / rescheduled / marked as skipped
          final changedIds = action.instancesToUpdate.map((i) => i.id).toList();
          expect(changedIds, isNot(contains(resolvedOneOff.id)));
        },
      );
    });

    group('FixedCalendarPolicy - Stack', () {
      test('spawns all missing instances up to today as pending', () {
        final startDate = today.addDays(-3); // June 16
        final task = TestTaskFactory.createDaily(
          id: 'stack-1',
          title: 'Stack Task',
          description: 'Piles up',
          startDate: startDate,
          interval: 1,
          missedOccurrencePolicy: const MissedOccurrencePolicy.stack(),
        );

        final action = const SchedulerEngine().evaluate(
          task,
          [],
          now,
          futureInstancesCount: 1,
        );

        // Should spawn 5 instances under N=1: June 16, 17, 18, 19, and future 20
        expect(action.instancesToSpawn, hasLength(5));
        expect(action.instancesToSpawn[0].scheduledDate.day, 16);
        expect(action.instancesToSpawn[0].status, TaskStatus.pending);
        expect(action.instancesToSpawn[1].scheduledDate.day, 17);
        expect(action.instancesToSpawn[1].status, TaskStatus.pending);
        expect(action.instancesToSpawn[2].scheduledDate.day, 18);
        expect(action.instancesToSpawn[2].status, TaskStatus.pending);
        expect(action.instancesToSpawn[3].scheduledDate.day, 19);
        expect(action.instancesToSpawn[3].status, TaskStatus.pending);
        expect(action.instancesToSpawn[4].scheduledDate.day, 20);
        expect(action.instancesToSpawn[4].status, TaskStatus.pending);

        expect(action.updatedSchedule!.lastSpawnedDate, today);
      });
    });

    group('FixedCalendarPolicy - Prefer Newer', () {
      test(
        'skips older missed instances and keeps only the latest pending',
        () {
          final startDate = today.addDays(-2); // June 17
          final task = TestTaskFactory.createDaily(
            id: 'newer-1',
            title: 'Prefer Newer Task',
            description: 'Keeps newest only',
            startDate: startDate,
            interval: 1,
            missedOccurrencePolicy: const MissedOccurrencePolicy.preferNewer(),
          );

          final action = const SchedulerEngine().evaluate(
            task,
            [],
            now,
            futureInstancesCount: 1,
          );

          // Under N=1, today (June 19) and tomorrow (June 20) are pending.
          // Older dates (June 17, 18) are skipped and not spawned.
          expect(action.instancesToSpawn, hasLength(2));
          expect(action.instancesToSpawn[0].scheduledDate.day, 19);
          expect(action.instancesToSpawn[0].status, TaskStatus.pending);
          expect(action.instancesToSpawn[1].scheduledDate.day, 20);
          expect(action.instancesToSpawn[1].status, TaskStatus.pending);
        },
      );

      test('skips previous pending when a new occurrence is evaluated', () {
        final yesterday = today.addDays(-1);
        final task = TestTaskFactory.createDaily(
          id: 'newer-2',
          title: 'Prefer Newer Task 2',
          description: 'Advances active',
          startDate: yesterday,
          interval: 1,
          missedOccurrencePolicy: const MissedOccurrencePolicy.preferNewer(),
        );

        final existingPending = TaskInstance(
          id: 'newer-2_2026-06-18',
          scheduleId: task.id,
          ruleId: task.schedules.first.id,
          title: task.title,
          description: task.description,
          scheduledDate: yesterday,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          status: TaskStatus.pending,
        );

        final action = const SchedulerEngine().evaluate(
          task,
          [existingPending],
          now,
          futureInstancesCount: 1,
        );

        // Existing yesterday instance should be updated to skipped
        expect(action.instancesToUpdate, hasLength(1));
        expect(action.instancesToUpdate.first.status, TaskStatus.skipped);

        // Today (June 19) and tomorrow (June 20) should be spawned as pending
        expect(action.instancesToSpawn, hasLength(2));
        expect(action.instancesToSpawn[0].scheduledDate.day, 19);
        expect(action.instancesToSpawn[0].status, TaskStatus.pending);
        expect(action.instancesToSpawn[1].scheduledDate.day, 20);
        expect(action.instancesToSpawn[1].status, TaskStatus.pending);
      });

      test(
        'keeps today\'s instance as pending and does not skip it in favor of a future lookahead instance',
        () {
          final task = TestTaskFactory.createDaily(
            id: 'newer-3',
            title: 'Prefer Newer Task 3',
            description: 'Today is active, tomorrow is future',
            startDate: today,
            interval: 1,
            missedOccurrencePolicy: const MissedOccurrencePolicy.preferNewer(),
          );

          // Simulate where today's instance is already spawned as pending in DB
          final todayInstance = TaskInstance(
            id: 'newer-3_2026-06-19',
            scheduleId: task.id,
            ruleId: task.schedules.first.id,
            title: task.title,
            description: task.description,
            scheduledDate: today,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.pending,
          );

          final action = const SchedulerEngine().evaluate(
            task,
            [todayInstance],
            now,
            futureInstancesCount: 1,
          );

          // Today's instance should remain pending, meaning it is NOT updated to skipped!
          expect(action.instancesToUpdate, isEmpty);

          // Tomorrow's lookahead instance (June 20) should be spawned as pending
          expect(action.instancesToSpawn, hasLength(1));
          expect(action.instancesToSpawn[0].scheduledDate, today.addDays(1));
          expect(action.instancesToSpawn[0].status, TaskStatus.pending);
        },
      );

      test(
        'does not skip yesterday\'s missed instance if today\'s instance start time is in the future',
        () {
          // today is June 19, 10:00 AM (Friday)
          // Let's set now to June 19, 8:00 AM (before the 10:00 AM start time)
          final evalTime = DateTime(2026, 6, 19, 8, 0);
          final yesterday = today.addDays(-1); // June 18

          final task = TestTaskFactory.createDaily(
            id: 'newer-bug-test',
            title: 'Prefer Newer Start Time Task',
            description: 'Start time test',
            startDate: yesterday,
            interval: 1,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 10, minute: 0), // Starts at 10:00 AM
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            missedOccurrencePolicy: const MissedOccurrencePolicy.preferNewer(),
          );

          final yesterdayInstance = TaskInstance(
            id: 'newer-bug-test_yesterday',
            scheduleId: task.id,
            ruleId: task.schedules.first.id,
            title: task.title,
            description: task.description,
            scheduledDate: yesterday,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 10, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.pending,
          );

          final action = const SchedulerEngine().evaluate(
            task,
            [yesterdayInstance],
            evalTime,
            futureInstancesCount: 1,
          );

          // Yesterday's instance should NOT be marked as skipped,
          // because today's instance (June 19) has not reached its start time (10:00 AM) yet.
          expect(action.instancesToUpdate, isEmpty);
        },
      );

      test(
        'does not skip older pending occurrence when yesterday occurrence is already completed and today has not started',
        () {
          // today is June 19, 10:00 AM (Friday)
          // Let's set now to June 19, 8:00 AM (before today's 10:00 AM start time)
          final evalTime = DateTime(2026, 6, 19, 8, 0);
          final dayBeforeYesterday = today.addDays(-2); // June 17
          final yesterday = today.addDays(-1); // June 18

          final task = TestTaskFactory.createDaily(
            id: 'newer-completed-test',
            title: 'Prefer Newer Completed Test',
            description: 'Test prefer newer with completed prior instance',
            startDate: dayBeforeYesterday,
            interval: 1,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 10, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            missedOccurrencePolicy: const MissedOccurrencePolicy.preferNewer(),
          );

          final olderPending = TaskInstance(
            id: 'newer-completed-test_older',
            scheduleId: task.id,
            ruleId: task.schedules.first.id,
            title: task.title,
            description: task.description,
            scheduledDate: dayBeforeYesterday,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 10, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.pending,
          );

          final completedYesterday = TaskInstance(
            id: 'newer-completed-test_yesterday',
            scheduleId: task.id,
            ruleId: task.schedules.first.id,
            title: task.title,
            description: task.description,
            scheduledDate: yesterday,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 10, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.completed,
            completedAt: DateTime(2026, 6, 18, 11, 0),
          );

          final action = const SchedulerEngine().evaluate(
            task,
            [olderPending, completedYesterday],
            evalTime,
            futureInstancesCount: 2,
          );

          // Older pending instance should NOT be marked as skipped,
          // because completedYesterday is resolved and today has not started yet.
          expect(action.instancesToUpdate, isEmpty);

          // Today (June 19) and tomorrow (June 20) are spawned as pending lookaheads
          final spawnedDates = action.instancesToSpawn
              .map((x) => x.scheduledDate.day)
              .toList();
          expect(spawnedDates.contains(19), isTrue);
          expect(spawnedDates.contains(20), isTrue);
          expect(
            action.instancesToSpawn
                .firstWhere((x) => x.scheduledDate.day == 19)
                .status,
            TaskStatus.pending,
          );
        },
      );

      test(
        'does not skip today started occurrence when yesterday occurrence is already completed',
        () {
          // today is June 19, 10:00 AM (started at 9:00 AM)
          final yesterday = today.addDays(-1); // June 18
          final task = TestTaskFactory.createDaily(
            id: 'newer-completed-today-test',
            title: 'Prefer Newer Completed Today Test',
            description: 'Test prefer newer with completed yesterday instance',
            startDate: yesterday,
            interval: 1,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            missedOccurrencePolicy: const MissedOccurrencePolicy.preferNewer(),
          );

          final completedYesterday = TaskInstance(
            id: 'newer-completed-today-test_yesterday',
            scheduleId: task.id,
            ruleId: task.schedules.first.id,
            title: task.title,
            description: task.description,
            scheduledDate: yesterday,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.completed,
            completedAt: DateTime(2026, 6, 18, 12, 0),
          );

          final todayInstance = TaskInstance(
            id: 'newer-completed-today-test_today',
            scheduleId: task.id,
            ruleId: task.schedules.first.id,
            title: task.title,
            description: task.description,
            scheduledDate: today,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.pending,
          );

          final action = const SchedulerEngine().evaluate(
            task,
            [completedYesterday, todayInstance],
            now, // 10:00 AM, today has started
            futureInstancesCount: 2,
          );

          // Today's instance should NOT be updated to skipped; it should remain pending
          expect(action.instancesToUpdate, isEmpty);

          // Only future lookahead instances (tomorrow June 20, etc.) are spawned
          final spawnedDates = action.instancesToSpawn
              .map((x) => x.scheduledDate.day)
              .toList();
          expect(spawnedDates.contains(20), isTrue);
          expect(
            action.instancesToSpawn
                .firstWhere((x) => x.scheduledDate.day == 20)
                .status,
            TaskStatus.pending,
          );
        },
      );

      test(
        'does not skip today started occurrence when yesterday occurrence is already skipped',
        () {
          // today is June 19, 10:00 AM (started at 9:00 AM)
          final yesterday = today.addDays(-1); // June 18
          final task = TestTaskFactory.createDaily(
            id: 'newer-skipped-today-test',
            title: 'Prefer Newer Skipped Today Test',
            description: 'Test prefer newer with skipped yesterday instance',
            startDate: yesterday,
            interval: 1,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            missedOccurrencePolicy: const MissedOccurrencePolicy.preferNewer(),
          );

          final skippedYesterday = TaskInstance(
            id: 'newer-skipped-today-test_yesterday',
            scheduleId: task.id,
            ruleId: task.schedules.first.id,
            title: task.title,
            description: task.description,
            scheduledDate: yesterday,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.skipped,
          );

          final todayInstance = TaskInstance(
            id: 'newer-skipped-today-test_today',
            scheduleId: task.id,
            ruleId: task.schedules.first.id,
            title: task.title,
            description: task.description,
            scheduledDate: today,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.pending,
          );

          final action = const SchedulerEngine().evaluate(
            task,
            [skippedYesterday, todayInstance],
            now, // 10:00 AM, today has started
            futureInstancesCount: 2,
          );

          // Today's instance should NOT be updated to skipped; it should remain pending
          expect(action.instancesToUpdate, isEmpty);

          // Future lookahead instances (tomorrow June 20, etc.) are spawned as pending
          final spawnedDates = action.instancesToSpawn
              .map((x) => x.scheduledDate.day)
              .toList();
          expect(spawnedDates.contains(20), isTrue);
          expect(
            action.instancesToSpawn
                .firstWhere((x) => x.scheduledDate.day == 20)
                .status,
            TaskStatus.pending,
          );
        },
      );

      test(
        'evaluates active started occurrence correctly and skips prior pending occurrence when prior occurrences include completed or skipped tasks under preferNewer',
        () {
          // June 17: pending
          // June 18: completed
          // June 19 (today, 10:00 AM): started at 9:00 AM, pending
          final dayBeforeYesterday = today.addDays(-2); // June 17
          final yesterday = today.addDays(-1); // June 18
          final task = TestTaskFactory.createDaily(
            id: 'newer-mixed-prior-test',
            title: 'Prefer Newer Mixed Prior Test',
            description:
                'Test prefer newer with mixed prior resolved instances',
            startDate: dayBeforeYesterday,
            interval: 1,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            missedOccurrencePolicy: const MissedOccurrencePolicy.preferNewer(),
          );

          final june17Instance = TaskInstance(
            id: 'newer-mixed-prior-test_june17',
            scheduleId: task.id,
            ruleId: task.schedules.first.id,
            title: task.title,
            description: task.description,
            scheduledDate: dayBeforeYesterday,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.pending,
          );

          final june18Instance = TaskInstance(
            id: 'newer-mixed-prior-test_june18',
            scheduleId: task.id,
            ruleId: task.schedules.first.id,
            title: task.title,
            description: task.description,
            scheduledDate: yesterday,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.completed,
            completedAt: DateTime(2026, 6, 18, 12, 0),
          );

          final todayInstance = TaskInstance(
            id: 'newer-mixed-prior-test_today',
            scheduleId: task.id,
            ruleId: task.schedules.first.id,
            title: task.title,
            description: task.description,
            scheduledDate: today,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.pending,
          );

          final action = const SchedulerEngine().evaluate(
            task,
            [june17Instance, june18Instance, todayInstance],
            now, // 10:00 AM, today has started
            futureInstancesCount: 1,
          );

          // June 17 instance should be updated to skipped (since June 19 has started and is latest)
          // June 18 remains completed (not in instancesToUpdate)
          expect(action.instancesToUpdate, hasLength(1));
          expect(action.instancesToUpdate.first.id, june17Instance.id);
          expect(action.instancesToUpdate.first.status, TaskStatus.skipped);

          // Future instance (June 20) is spawned as pending
          expect(action.instancesToSpawn, hasLength(1));
          expect(action.instancesToSpawn.first.scheduledDate.day, 20);
          expect(action.instancesToSpawn.first.status, TaskStatus.pending);
        },
      );
    });

    group('FixedCalendarPolicy - Prefer Older', () {
      test(
        'keeps the oldest missed instance pending, and skips subsequent newer ones',
        () {
          final startDate = today.addDays(-2); // June 17
          final task = TestTaskFactory.createDaily(
            id: 'older-1',
            title: 'Prefer Older Task',
            description: 'Keeps oldest only',
            startDate: startDate,
            interval: 1,
            missedOccurrencePolicy: const MissedOccurrencePolicy.preferOlder(),
          );

          final action = const SchedulerEngine().evaluate(task, [], now);

          // June 17 (oldest started) should be spawned as pending
          final spawnedDates = action.instancesToSpawn
              .map((x) => x.scheduledDate.day)
              .toList();
          expect(spawnedDates.contains(17), isTrue);
          expect(
            action.instancesToSpawn
                .firstWhere((x) => x.scheduledDate.day == 17)
                .status,
            TaskStatus.pending,
          );

          // June 18 and June 19 have started but are not oldest, so they should be skipped (not spawned)
          expect(spawnedDates.contains(18), isFalse);
          expect(spawnedDates.contains(19), isFalse);

          // Future lookahead instances (June 20, etc.) are pending (spawned)
          expect(spawnedDates.contains(20), isTrue);
          expect(
            action.instancesToSpawn
                .firstWhere((x) => x.scheduledDate.day == 20)
                .status,
            TaskStatus.pending,
          );
        },
      );

      test(
        'does not spawn any new pending if old is still pending, skips newer candidates',
        () {
          final yesterday = today.addDays(-1);
          final task = TestTaskFactory.createDaily(
            id: 'older-2',
            title: 'Prefer Older Task 2',
            description: 'Keeps oldest only',
            startDate: yesterday,
            interval: 1,
            missedOccurrencePolicy: const MissedOccurrencePolicy.preferOlder(),
          );

          final existingPending = TaskInstance(
            id: 'older-2_2026-06-18',
            scheduleId: task.id,
            ruleId: task.schedules.first.id,
            title: task.title,
            description: task.description,
            scheduledDate: yesterday,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.pending,
          );

          final action = const SchedulerEngine().evaluate(
            task,
            [existingPending],
            now,
            futureInstancesCount: 1,
          );

          // Yesterday's (June 18) remains pending (no updates)
          expect(action.instancesToUpdate, isEmpty);

          // Today's instance (June 19) has started, so it is skipped (not spawned)
          final spawnedDates = action.instancesToSpawn
              .map((x) => x.scheduledDate.day)
              .toList();
          expect(spawnedDates.contains(19), isFalse);

          // Tomorrow's instance (June 20, future) has not started yet, so it is pending (spawned)
          expect(action.instancesToSpawn, hasLength(1));
          expect(action.instancesToSpawn[0].scheduledDate.day, 20);
          expect(action.instancesToSpawn[0].status, TaskStatus.pending);
        },
      );

      test(
        'keeps future lookahead occurrences pending and only skips them when their start time is crossed if an older instance is still pending',
        () {
          // today is June 19, 10:00 AM (Friday)
          // Let's set now to June 19, 8:00 AM (before the 10:00 AM start time of today's instance)
          final evalTime = DateTime(2026, 6, 19, 8, 0);
          final yesterday = today.addDays(-1); // June 18

          final task = TestTaskFactory.createDaily(
            id: 'older-bug-test',
            title: 'Prefer Older Start Time Task',
            description: 'Start time test',
            startDate: yesterday,
            interval: 1,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 10, minute: 0), // Starts at 10:00 AM
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            missedOccurrencePolicy: const MissedOccurrencePolicy.preferOlder(),
          );

          final yesterdayInstance = TaskInstance(
            id: 'older-bug-test_yesterday',
            scheduleId: task.id,
            ruleId: task.schedules.first.id,
            title: task.title,
            description: task.description,
            scheduledDate: yesterday,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 10, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.pending,
          );

          final action = const SchedulerEngine().evaluate(
            task,
            [yesterdayInstance],
            evalTime,
            futureInstancesCount: 1,
          );

          // Yesterday's instance should remain pending
          expect(yesterdayInstance.status, TaskStatus.pending);

          // Both today's instance (June 19) and tomorrow's instance (June 20, lookahead) have not started,
          // so both should be spawned as pending!
          expect(action.instancesToSpawn, hasLength(2));
          final spawnedDates = action.instancesToSpawn
              .map((x) => x.scheduledDate.day)
              .toList();
          expect(spawnedDates.contains(19), isTrue);
          expect(spawnedDates.contains(20), isTrue);
          expect(
            action.instancesToSpawn
                .firstWhere((x) => x.scheduledDate.day == 19)
                .status,
            TaskStatus.pending,
          );
          expect(
            action.instancesToSpawn
                .firstWhere((x) => x.scheduledDate.day == 20)
                .status,
            TaskStatus.pending,
          );
        },
      );

      test(
        'does not skip today started occurrence when yesterday occurrence is already completed',
        () {
          // today is June 19, 10:00 AM (started at 9:00 AM)
          final yesterday = today.addDays(-1); // June 18
          final task = TestTaskFactory.createDaily(
            id: 'older-completed-test',
            title: 'Prefer Older Completed Test',
            description: 'Test prefer older with completed prior instance',
            startDate: yesterday,
            interval: 1,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            missedOccurrencePolicy: const MissedOccurrencePolicy.preferOlder(),
          );

          final completedYesterday = TaskInstance(
            id: 'older-completed-test_yesterday',
            scheduleId: task.id,
            ruleId: task.schedules.first.id,
            title: task.title,
            description: task.description,
            scheduledDate: yesterday,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.completed,
            completedAt: DateTime(2026, 6, 19, 1, 0),
          );

          final todayInstance = TaskInstance(
            id: 'older-completed-test_today',
            scheduleId: task.id,
            ruleId: task.schedules.first.id,
            title: task.title,
            description: task.description,
            scheduledDate: today,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.pending,
          );

          final action = const SchedulerEngine().evaluate(
            task,
            [completedYesterday, todayInstance],
            now, // 10:00 AM, today has started
            futureInstancesCount: 2,
          );

          // Today's instance should NOT be updated to skipped; it should remain pending
          expect(action.instancesToUpdate, isEmpty);

          // Only future lookahead instances (tomorrow June 20, etc.) are spawned
          final spawnedDates = action.instancesToSpawn
              .map((x) => x.scheduledDate.day)
              .toList();
          expect(spawnedDates.contains(20), isTrue);
          expect(
            action.instancesToSpawn
                .firstWhere((x) => x.scheduledDate.day == 20)
                .status,
            TaskStatus.pending,
          );
        },
      );

      test(
        'does not skip today started occurrence when yesterday occurrence is already skipped',
        () {
          // today is June 19, 10:00 AM (started at 9:00 AM)
          final yesterday = today.addDays(-1); // June 18
          final task = TestTaskFactory.createDaily(
            id: 'older-skipped-test',
            title: 'Prefer Older Skipped Test',
            description: 'Test prefer older with skipped prior instance',
            startDate: yesterday,
            interval: 1,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            missedOccurrencePolicy: const MissedOccurrencePolicy.preferOlder(),
          );

          final skippedYesterday = TaskInstance(
            id: 'older-skipped-test_yesterday',
            scheduleId: task.id,
            ruleId: task.schedules.first.id,
            title: task.title,
            description: task.description,
            scheduledDate: yesterday,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.skipped,
          );

          final todayInstance = TaskInstance(
            id: 'older-skipped-test_today',
            scheduleId: task.id,
            ruleId: task.schedules.first.id,
            title: task.title,
            description: task.description,
            scheduledDate: today,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.pending,
          );

          final action = const SchedulerEngine().evaluate(
            task,
            [skippedYesterday, todayInstance],
            now, // 10:00 AM, today has started
            futureInstancesCount: 2,
          );

          // Today's instance should NOT be updated to skipped; it should remain pending
          expect(action.instancesToUpdate, isEmpty);

          // Future lookahead instances (tomorrow June 20, etc.) are spawned as pending
          final spawnedDates = action.instancesToSpawn
              .map((x) => x.scheduledDate.day)
              .toList();
          expect(spawnedDates.contains(20), isTrue);
          expect(
            action.instancesToSpawn
                .firstWhere((x) => x.scheduledDate.day == 20)
                .status,
            TaskStatus.pending,
          );
        },
      );
    });

    group('FixedCalendarPolicy - Auto-Dismiss', () {
      test('auto-dismisses expired pending, keeps within grace period', () {
        final yesterday = today.addDays(-1);
        final task = TestTaskFactory.createDaily(
          id: 'dismiss-1',
          title: 'Auto Dismiss Task',
          description: 'Auto Dismiss Task',
          startDate: yesterday,
          interval: 1,
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 12, minute: 0),
          ),
          missedOccurrencePolicy: const MissedOccurrencePolicy.autoDismiss(
            gracePeriod: Duration(hours: 2),
          ),
        );

        final yesterdayInstance = TaskInstance(
          id: 'dismiss-1_2026-06-18',
          scheduleId: task.id,
          ruleId: task.schedules.first.id,
          title: task.title,
          description: task.description,
          scheduledDate: yesterday,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 12, minute: 0),
          ),
          status: TaskStatus.pending,
        );

        final action = const SchedulerEngine().evaluate(
          task,
          [yesterdayInstance],
          now,
          futureInstancesCount: 1,
        );

        // Yesterday's instance (expired yesterday at 2:00 PM) is skipped
        expect(action.instancesToUpdate, hasLength(1));
        expect(action.instancesToUpdate.first.status, TaskStatus.skipped);

        // June 19 (pending) and June 20 (pending N=1 future) should be spawned
        expect(action.instancesToSpawn, hasLength(2));
        expect(action.instancesToSpawn[0].scheduledDate, today);
        expect(action.instancesToSpawn[0].status, TaskStatus.pending);
        expect(action.instancesToSpawn[1].scheduledDate, today.addDays(1));
        expect(action.instancesToSpawn[1].status, TaskStatus.pending);
      });
    });

    group('Completion-Relative Rescheduling Tests', () {
      test(
        'spawns completion relative next instance relative to completion time',
        () {
          final task = TestTaskFactory.createDaily(
            id: 'relative-spawn',
            title: 'Completion Relative Task',
            description: 'Relative task',
            startDate: today.addDays(-1),
            interval: 3,
            schedulingPolicy: const CompletionRelativePolicy(
              interval: Duration(days: 3),
              targetTime: TimeOfDay(hour: 9, minute: 0),
            ),
          );

          final completedInstance = TaskInstance(
            id: 'relative-spawn_2026-06-18',
            scheduleId: task.id,
            ruleId: task.schedules.first.id,
            title: task.title,
            description: task.description,
            scheduledDate: today.addDays(-1),
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.completed,
            completedAt: DateTime(2026, 6, 19, 14, 0),
          );

          final nextInst = const SchedulerEngine().getNextOccurrenceToSpawn(
            task,
            completedInstance,
            DateTime(2026, 6, 19, 14, 0),
            [completedInstance],
          );
          expect(nextInst, isNotNull);
          expect(nextInst!.scheduledDate, today.addDays(3)); // June 22
          expect(nextInst.status, TaskStatus.pending);
        },
      );
    });

    group('30-Day Window Progress / Sticking Bugs', () {
      test('spawns future occurrences through gaps without occurrences', () {
        final startDate = CivilDay(year: 2026, month: 5, day: 1);
        final task = TaskSchedule(
          id: 'bimonthly-task',
          title: 'Bi-monthly Task',
          description: 'Every 2 months',
          lastSpawnedDate: startDate, // Set to May 1
          schedules: [
            MonthlySchedule(startDate: startDate, interval: 2, dayOfMonth: 1),
          ],
        );

        // Pre-create the resolved May 1 instance to move the queue base date forward to July 1
        final resolvedMay1 = TaskInstance(
          id: 'I-bimonthly-may1',
          scheduleId: task.id,
          ruleId: task.schedules.first.id,
          title: task.title,
          description: task.description,
          scheduledDate: startDate,
          startRelativeTime: task.schedules.first.startRelativeTime,
          dueRelativeTime: task.schedules.first.dueRelativeTime,
          status: TaskStatus.completed,
        );

        final action = const SchedulerEngine().evaluate(task, [
          resolvedMay1,
        ], now);

        // Under N=1 model, the future July 1 occurrence is spawned immediately
        expect(action.instancesToSpawn, hasLength(1));
        expect(
          action.instancesToSpawn.first.scheduledDate,
          equals(CivilDay(year: 2026, month: 7, day: 1)),
        );
        expect(action.updatedSchedule, isNull);
      });

      test(
        'regression: monthly task starting > 30 days ago gets evaluated up to today and spawns task',
        () {
          final startDate = CivilDay(year: 2026, month: 5, day: 1);
          final task = TaskSchedule(
            id: 'monthly-stuck-task',
            title: 'Monthly Stuck Task',
            description: 'Occurs on 15th',
            lastSpawnedDate: null,
            schedules: [
              MonthlySchedule(
                startDate: startDate,
                interval: 1,
                dayOfMonth: 15,
              ),
            ],
          );

          // First evaluate from null. Capped at 30 days from May 1 -> May 31. Spawns May 15.
          final action1 = const SchedulerEngine().evaluate(task, [], now);
          expect(action1.instancesToSpawn, hasLength(1));
          expect(
            action1.instancesToSpawn.first.scheduledDate,
            equals(CivilDay(year: 2026, month: 5, day: 15)),
          );
          expect(
            action1.updatedSchedule!.lastSpawnedDate,
            equals(CivilDay(year: 2026, month: 5, day: 15)),
          );

          // Complete the May 15 instance, and evaluate again. Capped at 30 days from June 15 -> July 15.
          final spawnedMay15 = action1.instancesToSpawn.first.copyWith(
            status: TaskStatus.completed,
            completedAt: now,
          );
          final updatedTask1 = action1.updatedSchedule!;
          final action2 = const SchedulerEngine().evaluate(updatedTask1, [
            spawnedMay15,
          ], now);

          expect(action2.instancesToSpawn, hasLength(2));
          expect(
            action2.instancesToSpawn.map((i) => i.scheduledDate).toList(),
            containsAll([
              CivilDay(year: 2026, month: 6, day: 15),
              CivilDay(year: 2026, month: 7, day: 15),
            ]),
          );
          expect(
            action2.updatedSchedule!.lastSpawnedDate,
            equals(CivilDay(year: 2026, month: 6, day: 15)),
          );
        },
      );
    });

    group('Pruning/Decreasing future instances', () {
      test(
        'correctly deletes extra future pending instances when futureInstancesCount decreases',
        () {
          final dailyRule = DailySchedule(
            startDate: today.addDays(1),
            interval: 1,
          );
          final task = TaskSchedule(
            id: 'prune-task',
            title: 'Daily Task',
            description: 'Desc',
            schedules: [dailyRule],
          );

          // We have 4 existing pending instances in the DB
          final inst20 = TaskInstance(
            id: 'inst-1',
            scheduleId: task.id,
            ruleId: dailyRule.id,
            title: task.title,
            description: task.description,
            scheduledDate: today.addDays(1), // June 20
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.pending,
          );
          final inst21 = TaskInstance(
            id: 'inst-2',
            scheduleId: task.id,
            ruleId: dailyRule.id,
            title: task.title,
            description: task.description,
            scheduledDate: today.addDays(2), // June 21
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.pending,
          );
          final inst22 = TaskInstance(
            id: 'inst-3',
            scheduleId: task.id,
            ruleId: dailyRule.id,
            title: task.title,
            description: task.description,
            scheduledDate: today.addDays(3), // June 22
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.pending,
          );
          final inst23 = TaskInstance(
            id: 'inst-4',
            scheduleId: task.id,
            ruleId: dailyRule.id,
            title: task.title,
            description: task.description,
            scheduledDate: today.addDays(4), // June 23
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.pending,
          );

          final List<TaskInstance> existingInstances = [
            inst20,
            inst21,
            inst22,
            inst23,
          ];

          // Run evaluate with futureInstancesCount = 2
          final action = const SchedulerEngine().evaluate(
            task,
            existingInstances,
            now,
            futureInstancesCount: 2,
          );

          // It should keep the first 2 (June 20, 21) and delete the last 2 (June 22, 23)
          expect(action.instancesToDelete, containsAll(['inst-3', 'inst-4']));
          expect(action.instancesToDelete, hasLength(2));
          expect(action.instancesToSpawn, isEmpty);
          expect(action.instancesToUpdate, isEmpty);
        },
      );

      test('uses task.futureInstancesCount if parameter is omitted', () {
        final dailyRule = DailySchedule(
          startDate: today.addDays(1),
          interval: 1,
        );
        final task = TaskSchedule(
          id: 'task-fallback-count',
          title: 'Daily Task',
          description: 'Desc',
          schedules: [dailyRule],
        );

        // Evaluate without passing futureInstancesCount parameter
        final action = const SchedulerEngine().evaluate(task, const [], now);

        // It should spawn 10 instances (the fallback from task.futureInstancesCount for Daily)
        expect(action.instancesToSpawn, hasLength(10));
      });
    });

    group('Future task limit with resolved tasks', () {
      final now = DateTime(2026, 6, 1, 10, 0); // Monday
      final today = CivilDay(year: 2026, month: 6, day: 1);

      test(
        'resolved future tasks do not count towards futureInstancesCount limit',
        () {
          final dailyRule = DailySchedule(
            startDate: today,
            interval: 1,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
          );
          final task = TaskSchedule(
            id: 'task-id',
            title: 'Daily Task',
            description: 'Desc',
            schedules: [dailyRule],
          );

          // Tuesday is tomorrow. Wednesday onwards are subsequent days.
          // Tuesday's instance is already in the DB and is completed.
          final completedTomorrow = TaskInstance(
            id: 'inst-tue',
            scheduleId: task.id,
            ruleId: dailyRule.id,
            title: task.title,
            description: task.description,
            scheduledDate: today.addDays(1), // Tuesday
            startRelativeTime: dailyRule.startRelativeTime,
            dueRelativeTime: dailyRule.dueRelativeTime,
            status: TaskStatus.completed,
          );

          // Evaluation:
          // We have a completed future instance on Tuesday.
          // Under new rules, Daily task pre-creates 10 pending future instances.
          final action = const SchedulerEngine().evaluate(task, [
            completedTomorrow,
          ], now);

          // Tuesday is completed (resolved), so it shouldn't count.
          // It should spawn 10 pending future instances starting from Wednesday.
          final spawnedDates = action.instancesToSpawn
              .map((i) => i.scheduledDate)
              .toList();
          expect(
            spawnedDates,
            containsAll(List.generate(10, (i) => today.addDays(i + 2))),
          );
          expect(action.instancesToSpawn, hasLength(10));

          // The completed Tuesday instance status must remain completed (no update/delete)
          expect(action.instancesToUpdate, isEmpty);
          expect(action.instancesToDelete, isEmpty);
        },
      );

      test(
        'resolved tasks are not modified by missed occurrence policies (stack, autoDismiss, preferNewer, preferOlder)',
        () {
          final dailyRule = DailySchedule(
            startDate: today.addDays(-2), // Started Saturday
            interval: 1,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            missedOccurrencePolicy: const MissedOccurrencePolicy.stack(),
          );
          final task = TaskSchedule(
            id: 'task-id',
            title: 'Daily Task',
            description: 'Desc',
            schedules: [dailyRule],
          );

          // Sunday's instance was completed. Saturday's instance is pending (overdue).
          final satInstance = TaskInstance(
            id: 'inst-sat',
            scheduleId: task.id,
            ruleId: dailyRule.id,
            title: task.title,
            description: task.description,
            scheduledDate: today.addDays(-2), // Saturday
            startRelativeTime: dailyRule.startRelativeTime,
            dueRelativeTime: dailyRule.dueRelativeTime,
            status: TaskStatus.pending,
          );
          final sunInstance = TaskInstance(
            id: 'inst-sun',
            scheduleId: task.id,
            ruleId: dailyRule.id,
            title: task.title,
            description: task.description,
            scheduledDate: today.addDays(-1), // Sunday
            startRelativeTime: dailyRule.startRelativeTime,
            dueRelativeTime: dailyRule.dueRelativeTime,
            status: TaskStatus.completed, // Resolved
          );

          // Run evaluate
          final action = const SchedulerEngine().evaluate(task, [
            satInstance,
            sunInstance,
          ], now);

          // The resolved Sunday instance (status: completed) must not be updated or reverted to pending/skipped
          final updatedCompletedInst = action.instancesToUpdate.any(
            (i) => i.id == 'inst-sun',
          );
          expect(updatedCompletedInst, isFalse);
        },
      );
    });

    group('Per-rule lookahead limits', () {
      test('rule-specific futureInstancesCount yields correct values', () {
        final daily = DailySchedule(startDate: today, interval: 1);
        final weekly = WeeklySchedule(
          startDate: today,
          interval: 1,
          daysOfWeek: {1},
        );
        final monthly = MonthlySchedule(
          startDate: today,
          interval: 1,
          dayOfMonth: 1,
        );
        final yearly = YearlySchedule(
          startDate: today,
          interval: 1,
          month: 6,
          day: 19,
        );
        final oneOff = OneOffSchedule(date: today);

        expect(daily.futureInstancesCount, 10);
        expect(weekly.futureInstancesCount, 5);
        expect(monthly.futureInstancesCount, 3);
        expect(yearly.futureInstancesCount, 2);
        expect(oneOff.futureInstancesCount, 1);
      });

      test(
        'spawns occurrences according to each rule limit when rules are mixed',
        () {
          final dailyRule = DailySchedule(startDate: today, interval: 1);
          final weeklyRule = WeeklySchedule(
            startDate: today,
            interval: 1,
            daysOfWeek: const {5}, // Friday (same as today)
          );

          final task = TaskSchedule(
            id: 'mixed-rule-limit-task',
            title: 'Mixed Task',
            description: 'Desc',
            schedules: [dailyRule, weeklyRule],
          );

          final action = const SchedulerEngine().evaluate(task, const [], now);

          // Daily rule (limit 10) spawns today + 10 lookahead = 11 daily instances
          final dailySpawns = action.instancesToSpawn
              .where((inst) => inst.ruleId == dailyRule.id)
              .toList();
          expect(dailySpawns, hasLength(11));

          // Weekly rule (limit 5) spawns today + 4 lookahead = 5 weekly instances
          final weeklySpawns = action.instancesToSpawn
              .where((inst) => inst.ruleId == weeklyRule.id)
              .toList();
          expect(weeklySpawns, hasLength(5));
        },
      );
    });

    group('skipIfNoCapacity Tests', () {
      test('skips instances when daily capacity is insufficient', () {
        final task = TestTaskFactory.createDaily(
          id: 'cap-1',
          title: 'Capacity Task',
          description: 'Skips when full',
          startDate: today,
          interval: 1,
          estimatedDuration: const Duration(hours: 5),
          skipIfNoCapacity: true,
        );

        // Mock UserSettings with 0 capacity on today and today+1, but 8 hours on today+2
        final userSettings = UserSettings(
          hoursAvailable: 8.0,
          dailyCapacityOverrides: {
            today.toString(): 0.0,
            today.addDays(1).toString(): 0.0,
          },
        );

        final action = const SchedulerEngine().evaluate(
          task,
          [],
          now,
          futureInstancesCount: 2,
          userSettings: userSettings,
          dayPlannedHours: {},
        );

        // The generated occurrences should have status: TaskStatus.skipped on today and tomorrow (June 20),
        // but status: TaskStatus.pending on today+2 (June 21)
        expect(action.instancesToSpawn, hasLength(3)); // today, tomorrow, day+2

        final instToday = action.instancesToSpawn.firstWhere(
          (x) => x.scheduledDate == today,
        );
        final instTomorrow = action.instancesToSpawn.firstWhere(
          (x) => x.scheduledDate == today.addDays(1),
        );
        final instDay2 = action.instancesToSpawn.firstWhere(
          (x) => x.scheduledDate == today.addDays(2),
        );

        expect(instToday.status, TaskStatus.skipped);
        expect(instTomorrow.status, TaskStatus.skipped);
        expect(instDay2.status, TaskStatus.pending);
      });

      test('competing capacity dependent tasks prioritized by priority', () {
        // High priority task
        final taskHigh = TestTaskFactory.createOneOff(
          id: 'cap-high',
          title: 'High Priority Task',
          description: 'High',
          priority: TaskPriority.high,
          date: today,
          estimatedDuration: const Duration(hours: 5),
          skipIfNoCapacity: true,
        );

        // Medium priority task
        final taskMed = TestTaskFactory.createOneOff(
          id: 'cap-med',
          title: 'Medium Priority Task',
          description: 'Med',
          priority: TaskPriority.medium,
          date: today,
          estimatedDuration: const Duration(hours: 5),
          skipIfNoCapacity: true,
        );

        final userSettings = UserSettings(
          hoursAvailable: 8.0,
        ); // 8 hours capacity each day

        // Evaluate taskHigh first (it has higher priority)
        final dayPlannedHours = <CivilDay, double>{};
        final actionHigh = const SchedulerEngine().evaluate(
          taskHigh,
          [],
          now,
          userSettings: userSettings,
          dayPlannedHours: dayPlannedHours,
        );

        expect(actionHigh.instancesToSpawn, hasLength(1));
        expect(actionHigh.instancesToSpawn.first.status, TaskStatus.pending);

        // Mark today as having 5 hours planned (from taskHigh)
        dayPlannedHours[today] = 5.0;

        // Evaluate taskMed (with updated dayPlannedHours)
        final actionMed = const SchedulerEngine().evaluate(
          taskMed,
          [],
          now,
          userSettings: userSettings,
          dayPlannedHours: dayPlannedHours,
        );

        // Since today only has 3 hours remaining (8 - 5), and taskMed requires 5 hours,
        // it must be skipped.
        expect(actionMed.instancesToSpawn, hasLength(1));
        expect(actionMed.instancesToSpawn.first.status, TaskStatus.skipped);
      });

      test(
        'competing capacity tasks with equal priority prioritize least recently completed task',
        () {
          final taskA = TestTaskFactory.createOneOff(
            id: 'cap-a',
            title: 'Task A',
            description: '',
            priority: TaskPriority.medium,
            date: today,
            estimatedDuration: const Duration(hours: 5),
            skipIfNoCapacity: true,
          );

          final taskB = TestTaskFactory.createOneOff(
            id: 'cap-b',
            title: 'Task B',
            description: '',
            priority: TaskPriority.medium,
            date: today,
            estimatedDuration: const Duration(hours: 5),
            skipIfNoCapacity: true,
          );

          final userSettings = UserSettings(hoursAvailable: 8.0);

          // Task A was completed on June 18 (yesterday).
          // Task B was completed on June 17 (2 days ago).
          // B is least recently completed, so B should be evaluated first,
          // getting 'pending' and leaving A with insufficient capacity ('skipped').
          final allInstances = [
            TaskInstance(
              scheduleId: 'S-cap-a',
              ruleId: 'r1',
              title: 'Task A Completed',
              description: '',
              scheduledDate: today.addDays(-1),
              startRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 9, minute: 0),
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 17, minute: 0),
              ),
              status: TaskStatus.completed,
              completedAt: now.subtract(const Duration(days: 1)),
            ),
            TaskInstance(
              scheduleId: 'S-cap-b',
              ruleId: 'r2',
              title: 'Task B Completed',
              description: '',
              scheduledDate: today.addDays(-2),
              startRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 9, minute: 0),
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 17, minute: 0),
              ),
              status: TaskStatus.completed,
              completedAt: now.subtract(const Duration(days: 2)),
            ),
          ];

          final list = [taskA, taskB];
          final Map<String, DateTime> lastCompletionCache = {};
          DateTime getLastCompletionTime(TaskSchedule t) {
            return lastCompletionCache.putIfAbsent(t.id, () {
              final completed = allInstances
                  .where(
                    (inst) =>
                        inst.scheduleId == t.id &&
                        inst.status == TaskStatus.completed,
                  )
                  .toList();
              if (completed.isEmpty) {
                return DateTime.fromMillisecondsSinceEpoch(0);
              }
              return completed
                  .map(
                    (inst) =>
                        inst.completedAt ??
                        DateTime.fromMillisecondsSinceEpoch(0),
                  )
                  .reduce((a, b) => a.isAfter(b) ? a : b);
            });
          }

          list.sort((a, b) {
            final pCompare = b.priority.index.compareTo(a.priority.index);
            if (pCompare != 0) return pCompare;
            if (a.skipIfNoCapacity && b.skipIfNoCapacity) {
              final aTime = getLastCompletionTime(a);
              final bTime = getLastCompletionTime(b);
              final timeCompare = aTime.compareTo(bTime);
              if (timeCompare != 0) return timeCompare;
            }
            return a.id.compareTo(b.id);
          });

          expect(list.first.id, 'S-cap-b');

          final dayPlannedHours = <CivilDay, double>{};
          final actionB = const SchedulerEngine().evaluate(
            list[0],
            [],
            now,
            userSettings: userSettings,
            dayPlannedHours: dayPlannedHours,
          );
          expect(actionB.instancesToSpawn.first.status, TaskStatus.pending);
          dayPlannedHours[today] = 5.0;

          final actionA = const SchedulerEngine().evaluate(
            list[1],
            [],
            now,
            userSettings: userSettings,
            dayPlannedHours: dayPlannedHours,
          );
          expect(actionA.instancesToSpawn.first.status, TaskStatus.skipped);
        },
      );

      test(
        'revives previously skipped instance back to pending if capacity becomes available',
        () {
          final task = TestTaskFactory.createOneOff(
            id: 'cap-revive',
            title: 'Revive Task',
            description: 'Revives to pending',
            date: today.addDays(1),
            estimatedDuration: const Duration(hours: 4),
            skipIfNoCapacity: true,
          );

          final existingInst = TaskInstance(
            id: 'inst-skipped-today',
            scheduleId: 'cap-revive',
            ruleId: task.schedules.first.id,
            title: 'Revive Task',
            description: 'Revives to pending',
            scheduledDate: today.addDays(1),
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.skipped,
          );

          final userSettings = UserSettings(hoursAvailable: 8.0);
          final action = const SchedulerEngine().evaluate(
            task,
            [existingInst],
            now,
            userSettings: userSettings,
            dayPlannedHours: {},
          );

          expect(action.instancesToUpdate, hasLength(1));
          expect(action.instancesToUpdate.first.id, 'inst-skipped-today');
          expect(action.instancesToUpdate.first.status, TaskStatus.pending);
        },
      );

      test(
        'revives previously skipped instance back to pending if skipIfNoCapacity is toggled off',
        () {
          final task = TestTaskFactory.createOneOff(
            id: 'cap-revive',
            title: 'Revive Task',
            description: 'Revives to pending',
            date: today.addDays(1),
            estimatedDuration: const Duration(hours: 4),
            skipIfNoCapacity: false,
          );

          final existingInst = TaskInstance(
            id: 'inst-skipped-today',
            scheduleId: 'cap-revive',
            ruleId: task.schedules.first.id,
            title: 'Revive Task',
            description: 'Revives to pending',
            scheduledDate: today.addDays(1),
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.skipped,
          );

          final userSettings = UserSettings(hoursAvailable: 2.0);
          final action = const SchedulerEngine().evaluate(
            task,
            [existingInst],
            now,
            userSettings: userSettings,
            dayPlannedHours: {},
          );

          expect(action.instancesToUpdate, hasLength(1));
          expect(action.instancesToUpdate.first.status, TaskStatus.pending);
        },
      );

      test(
        'does not apply capacity limits (no skip, no revival) if applyCapacityLimits is false',
        () {
          final task = TestTaskFactory.createOneOff(
            id: 'cap-no-apply',
            title: 'No Apply Task',
            description: 'No capacity evaluation',
            date: today.addDays(1),
            estimatedDuration: const Duration(hours: 5),
            skipIfNoCapacity: true,
          );

          // We have 0 capacity, so if limits were applied, this would be skipped.
          // Since limits are NOT applied, it should spawn as pending, not skipped.
          final userSettings = UserSettings(hoursAvailable: 0.0);
          final actionSpawn = const SchedulerEngine().evaluate(
            task,
            [],
            now,
            userSettings: userSettings,
            dayPlannedHours: {},
            applyCapacityLimits: false,
          );
          expect(actionSpawn.instancesToSpawn, hasLength(1));
          expect(actionSpawn.instancesToSpawn.first.status, TaskStatus.pending);

          // Similarly, if we have an existing skipped future task, it should not be touched (no revival or changes).
          final existingInst = TaskInstance(
            id: 'inst-skipped-today',
            scheduleId: 'cap-no-apply',
            ruleId: task.schedules.first.id,
            title: 'No Apply Task',
            description: 'No capacity evaluation',
            scheduledDate: today.addDays(1),
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.skipped,
          );
          final actionUpdate = const SchedulerEngine().evaluate(
            task,
            [existingInst],
            now,
            userSettings: userSettings,
            dayPlannedHours: {},
            applyCapacityLimits: false,
          );
          expect(actionUpdate.instancesToUpdate, isEmpty);
        },
      );

      test(
        'skips existing pending instance when prior tasks exceed capacity, and keeps pending when capacity is available',
        () {
          final task = TestTaskFactory.createOneOff(
            id: 'cap-check',
            title: 'Capacity Check Task',
            description: 'Capacity evaluation',
            estimatedDuration: const Duration(hours: 5),
            skipIfNoCapacity: true,
            date: today.addDays(1),
          );

          final existingInst = TaskInstance(
            id: 'inst-pending-tomorrow',
            scheduleId:
                'S-cap-check', // TaskSchedule automatically prepends 'S-'
            ruleId: task.schedules.first.id,
            title: 'Capacity Check Task',
            description: 'Capacity evaluation',
            scheduledDate: today.addDays(1),
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.pending,
          );

          final userSettings = UserSettings(hoursAvailable: 8.0);

          // Scenario 1: Prior tasks already planned 5.0 hours on that day (8 - 5 = 3 available < 5 task duration)
          final actionExceeded = const SchedulerEngine().evaluate(
            task,
            [existingInst],
            now,
            userSettings: userSettings,
            dayPlannedHours: {today.addDays(1): 5.0},
          );

          // Expect the existing instance to be updated to skipped because capacity was exceeded by prior tasks.
          expect(actionExceeded.instancesToUpdate, hasLength(1));
          expect(
            actionExceeded.instancesToUpdate.first.status,
            TaskStatus.skipped,
          );

          // Scenario 2: Prior tasks only planned 2.0 hours (8 - 2 = 6 available >= 5 task duration)
          final actionAvailable = const SchedulerEngine().evaluate(
            task,
            [existingInst],
            now,
            userSettings: userSettings,
            dayPlannedHours: {today.addDays(1): 2.0},
          );

          // Instance stays pending, so no updates needed.
          expect(actionAvailable.instancesToUpdate, isEmpty);
        },
      );
    });
    group('Missed Occurrence Policies Strategy Unit Tests', () {
      test(
        'Skip (Drop Occurrence): Overdue Monday task is automatically skipped/expired and rescheduled to next calendar occurrence',
        () {
          final monday = const CivilDay(year: 2026, month: 5, day: 25);
          final task = TaskSchedule(
            id: 'skip-task',
            title: 'Take out trash',
            description: 'Every day',
            schedules: [
              DailySchedule(
                startDate: monday,
                interval: 1,
                missedOccurrencePolicy:
                    const MissedOccurrencePolicy.autoDismiss(
                      gracePeriod: Duration.zero,
                    ),
                startRelativeTime: const RelativeTime(
                  dayOffset: 0,
                  time: TimeOfDay(hour: 9, minute: 0),
                ),
                dueRelativeTime: const RelativeTime(
                  dayOffset: 0,
                  time: TimeOfDay(hour: 17, minute: 0),
                ),
              ),
            ],
          );

          final mondayInst = TaskInstance(
            id: 'monday',
            scheduleId: task.id,
            ruleId: task.schedules[0].id,
            title: task.title,
            description: task.description,
            scheduledDate: monday,
            startRelativeTime: task.schedules[0].startRelativeTime,
            dueRelativeTime: task.schedules[0].dueRelativeTime,
            status: TaskStatus.pending,
          );

          final tuesdayDateTime = DateTime(2026, 5, 26, 10, 0);

          final action = const SchedulerEngine().evaluate(task, [
            mondayInst,
          ], tuesdayDateTime);

          expect(action.instancesToUpdate, hasLength(1));
          expect(action.instancesToUpdate.first.id, 'monday');
          expect(action.instancesToUpdate.first.status, TaskStatus.skipped);

          expect(action.instancesToSpawn, isNotEmpty);
          expect(action.instancesToSpawn.first.scheduledDate.day, 26);
          expect(action.instancesToSpawn.first.status, TaskStatus.pending);
        },
      );

      test(
        'Auto-dismiss with zero grace period on mixed task drops passed one-off schedules',
        () {
          final monday = const CivilDay(year: 2026, month: 5, day: 25);

          final mixedTask = TaskSchedule(
            id: 'mixed-skip-task',
            title: 'Mixed skip task',
            description: 'Testing skip policy on mixed task',
            schedules: [
              OneOffSchedule(
                date: monday,
                missedOccurrencePolicy:
                    const MissedOccurrencePolicy.autoDismiss(
                      gracePeriod: Duration.zero,
                    ),
                startRelativeTime: const RelativeTime(
                  dayOffset: 0,
                  time: TimeOfDay(hour: 9, minute: 0),
                ),
                dueRelativeTime: const RelativeTime(
                  dayOffset: 0,
                  time: TimeOfDay(hour: 17, minute: 0),
                ),
              ),
              DailySchedule(
                startDate: monday,
                interval: 1,
                missedOccurrencePolicy:
                    const MissedOccurrencePolicy.autoDismiss(
                      gracePeriod: Duration.zero,
                    ),
                startRelativeTime: const RelativeTime(
                  dayOffset: 0,
                  time: TimeOfDay(hour: 9, minute: 0),
                ),
                dueRelativeTime: const RelativeTime(
                  dayOffset: 0,
                  time: TimeOfDay(hour: 17, minute: 0),
                ),
              ),
            ],
          );

          final mondayOneOffInst = TaskInstance(
            id: 'mon-oneoff',
            scheduleId: mixedTask.id,
            ruleId: mixedTask.schedules[0].id,
            title: mixedTask.title,
            description: mixedTask.description,
            scheduledDate: monday,
            startRelativeTime: mixedTask.schedules[0].startRelativeTime,
            dueRelativeTime: mixedTask.schedules[0].dueRelativeTime,
            status: TaskStatus.pending,
          );

          final mondayDailyInst = TaskInstance(
            id: 'mon-daily',
            scheduleId: mixedTask.id,
            ruleId: mixedTask.schedules[1].id,
            title: mixedTask.title,
            description: mixedTask.description,
            scheduledDate: monday,
            startRelativeTime: mixedTask.schedules[1].startRelativeTime,
            dueRelativeTime: mixedTask.schedules[1].dueRelativeTime,
            status: TaskStatus.pending,
          );

          final tuesdayDateTime = DateTime(2026, 5, 26, 10, 0);

          final action = const SchedulerEngine().evaluate(mixedTask, [
            mondayOneOffInst,
            mondayDailyInst,
          ], tuesdayDateTime);

          expect(action.instancesToUpdate, hasLength(2));
          final updatedOneOff = action.instancesToUpdate.firstWhere(
            (i) => i.ruleId == mixedTask.schedules[0].id,
          );
          final updatedDaily = action.instancesToUpdate.firstWhere(
            (i) => i.ruleId == mixedTask.schedules[1].id,
          );

          expect(updatedOneOff.status, TaskStatus.skipped);
          expect(updatedDaily.status, TaskStatus.skipped);

          expect(action.instancesToSpawn, isNotEmpty);
          expect(
            action.instancesToSpawn.first.ruleId,
            mixedTask.schedules[1].id,
          );
          expect(action.instancesToSpawn.first.scheduledDate.day, 26);
          expect(action.instancesToSpawn.first.status, TaskStatus.pending);
        },
      );

      test(
        'Auto-dismiss with zero grace period with daily cross-midnight due time does not skip early',
        () {
          final task = TaskSchedule(
            id: 'cross-midnight-task',
            title: 'Cross Midnight Task',
            description: 'Testing skip policy cross midnight',
            schedules: [
              DailySchedule(
                startDate: const CivilDay(year: 2026, month: 6, day: 18),
                interval: 1,
                missedOccurrencePolicy:
                    const MissedOccurrencePolicy.autoDismiss(
                      gracePeriod: Duration.zero,
                    ),
                startRelativeTime: const RelativeTime(
                  dayOffset: 0,
                  time: TimeOfDay(hour: 5, minute: 0),
                ),
                dueRelativeTime: const RelativeTime(
                  dayOffset: 0,
                  time: TimeOfDay(hour: 11, minute: 0),
                ),
              ),
              DailySchedule(
                startDate: const CivilDay(year: 2026, month: 6, day: 18),
                interval: 1,
                missedOccurrencePolicy:
                    const MissedOccurrencePolicy.autoDismiss(
                      gracePeriod: Duration.zero,
                    ),
                startRelativeTime: const RelativeTime(
                  dayOffset: 0,
                  time: TimeOfDay(hour: 20, minute: 0),
                ),
                dueRelativeTime: const RelativeTime(
                  dayOffset: 1,
                  time: TimeOfDay(hour: 2, minute: 0),
                ),
              ),
            ],
          );

          final sched0Inst = TaskInstance(
            id: 's0-18',
            scheduleId: task.id,
            ruleId: task.schedules[0].id,
            title: task.title,
            description: task.description,
            scheduledDate: const CivilDay(year: 2026, month: 6, day: 18),
            startRelativeTime: task.schedules[0].startRelativeTime,
            dueRelativeTime: task.schedules[0].dueRelativeTime,
            status: TaskStatus.pending,
          );

          final sched1Inst = TaskInstance(
            id: 's1-18',
            scheduleId: task.id,
            ruleId: task.schedules[1].id,
            title: task.title,
            description: task.description,
            scheduledDate: const CivilDay(year: 2026, month: 6, day: 18),
            startRelativeTime: task.schedules[1].startRelativeTime,
            dueRelativeTime: task.schedules[1].dueRelativeTime,
            status: TaskStatus.pending,
          );

          // Move to Thursday June 18th 10:00 PM (past sched0 due, before sched1 due)
          final thurs10pm = DateTime(2026, 6, 18, 22, 0);

          var action = const SchedulerEngine().evaluate(task, [
            sched0Inst,
            sched1Inst,
          ], thurs10pm);

          expect(action.instancesToUpdate, hasLength(1));
          expect(action.instancesToUpdate.first.ruleId, task.schedules[0].id);
          expect(action.instancesToUpdate.first.status, TaskStatus.skipped);

          // Move to Friday June 19th 12:05 AM (past midnight, but BEFORE due time 2:00 AM)
          final fri1205am = DateTime(2026, 6, 19, 0, 5);
          // Sched1 inst should still be pending, and Friday's instance should spawn.

          action = const SchedulerEngine().evaluate(task, [
            sched0Inst.copyWith(status: TaskStatus.skipped),
            sched1Inst,
          ], fri1205am);

          expect(action.instancesToUpdate, isEmpty);
          expect(
            action.instancesToSpawn.any(
              (i) =>
                  i.ruleId == task.schedules[1].id && i.scheduledDate.day == 19,
            ),
            isTrue,
          );

          // Move to Friday June 19th 2:05 AM (AFTER due time 2:00 AM)
          final fri205am = DateTime(2026, 6, 19, 2, 5);

          action = const SchedulerEngine().evaluate(task, [
            sched0Inst.copyWith(status: TaskStatus.skipped),
            sched1Inst,
          ], fri205am);

          expect(action.instancesToUpdate, hasLength(1));
          expect(action.instancesToUpdate.first.ruleId, task.schedules[1].id);
          expect(action.instancesToUpdate.first.status, TaskStatus.skipped);
        },
      );

      test(
        'Auto-Dismiss missed policy respects custom grace period and auto-dismisses after grace period passes',
        () {
          final monday = const CivilDay(year: 2026, month: 5, day: 25);
          final task = TaskSchedule(
            id: 'grace-skip-task',
            title: 'Grace Skip Task',
            description: 'Testing grace period skip policy',
            schedules: [
              DailySchedule(
                startDate: monday,
                interval: 1,
                startRelativeTime: const RelativeTime(
                  dayOffset: 0,
                  time: TimeOfDay(hour: 9, minute: 0),
                ),
                dueRelativeTime: const RelativeTime(
                  dayOffset: 0,
                  time: TimeOfDay(hour: 17, minute: 0),
                ),
                missedOccurrencePolicy:
                    const MissedOccurrencePolicy.autoDismiss(
                      gracePeriod: Duration(hours: 3),
                    ),
              ),
            ],
          );

          final mondayInst = TaskInstance(
            id: 'mon-grace',
            scheduleId: task.id,
            ruleId: task.schedules[0].id,
            title: task.title,
            description: task.description,
            scheduledDate: monday,
            startRelativeTime: task.schedules[0].startRelativeTime,
            dueRelativeTime: task.schedules[0].dueRelativeTime,
            status: TaskStatus.pending,
          );

          // Move time to 6:00 PM (past due time of 5:00 PM, but within 3-hour grace period)
          final withinGrace = DateTime(2026, 5, 25, 18, 0);

          var action = const SchedulerEngine().evaluate(task, [
            mondayInst,
          ], withinGrace);
          expect(action.instancesToUpdate, isEmpty);

          // Move time to 8:05 PM (past 3-hour grace period)
          final pastGrace = DateTime(2026, 5, 25, 20, 5);

          action = const SchedulerEngine().evaluate(task, [
            mondayInst,
          ], pastGrace);
          expect(action.instancesToUpdate, hasLength(1));
          expect(action.instancesToUpdate.first.status, TaskStatus.skipped);
        },
      );

      test(
        'Stack/Overlap (Allow Concurrency): Master task missed for Monday and Tuesday spawns separate cards on Wednesday',
        () {
          final monday = const CivilDay(year: 2026, month: 5, day: 25);
          final task = TaskSchedule(
            id: 'stack-task',
            title: 'Read a book',
            description: 'Every day',
            schedules: [
              DailySchedule(
                startDate: monday,
                interval: 1,
                startRelativeTime: const RelativeTime(
                  dayOffset: 0,
                  time: TimeOfDay(hour: 9, minute: 0),
                ),
                dueRelativeTime: const RelativeTime(
                  dayOffset: 0,
                  time: TimeOfDay(hour: 17, minute: 0),
                ),
              ),
            ],
            missedPolicy: MissedPolicy.stack,
            isMaster: true,
          );

          // Wednesday
          final wednesdayDateTime = DateTime(2026, 5, 27, 10, 0);

          final action = const SchedulerEngine().evaluate(
            task,
            [],
            wednesdayDateTime,
            futureInstancesCount: 10,
          );

          expect(action.instancesToSpawn.length, 13);

          final spawnedDates = action.instancesToSpawn
              .map((i) => i.scheduledDate.day)
              .toSet();
          expect(spawnedDates.containsAll([25, 26, 27]), isTrue);

          expect(
            action.updatedSchedule?.lastSpawnedDate,
            const CivilDay(year: 2026, month: 5, day: 27),
          );
        },
      );
    });

    group('Custom generateId callback', () {
      test('evaluate() utilizes custom generateId for OneOffSchedule', () {
        final engine = SchedulerEngine(generateId: () => 'custom-oneoff-id');
        final task = TaskSchedule(
          id: 'oneoff-custom',
          title: 'One Off Custom ID Task',
          description: 'A custom id test task',
          schedules: [OneOffSchedule(date: today)],
        );

        final action = engine.evaluate(task, [], now);

        expect(action.instancesToSpawn, hasLength(1));
        expect(action.instancesToSpawn.first.id, 'custom-oneoff-id');
      });

      test('evaluate() utilizes custom generateId for FixedCalendarPolicy', () {
        var idCounter = 1;
        final engine = SchedulerEngine(
          generateId: () => 'custom-fixed-${idCounter++}',
        );
        final task = TaskSchedule(
          id: 'fixed-custom',
          title: 'Fixed Custom ID Task',
          description: 'A custom id test task',
          schedules: [DailySchedule(startDate: today, interval: 1)],
        );

        final action = engine.evaluate(task, [], now, futureInstancesCount: 2);

        // Today + 2 future lookaheads
        expect(action.instancesToSpawn, hasLength(3));
        expect(
          action.instancesToSpawn.map((inst) => inst.id).toList(),
          equals(['custom-fixed-1', 'custom-fixed-2', 'custom-fixed-3']),
        );
      });

      test(
        'evaluate() utilizes custom generateId for CompletionRelativePolicy',
        () {
          final engine = SchedulerEngine(
            generateId: () => 'custom-relative-id',
          );
          final task = TaskSchedule(
            id: 'relative-custom',
            title: 'Relative Custom ID Task',
            description: 'A custom id test task',
            schedules: [
              DailySchedule(
                startDate: today,
                interval: 1,
                schedulingPolicy: const CompletionRelativePolicy(
                  interval: Duration(days: 1),
                  targetTime: TimeOfDay(hour: 9, minute: 0),
                ),
              ),
            ],
          );

          final action = engine.evaluate(task, [], now);

          expect(action.instancesToSpawn, hasLength(1));
          expect(action.instancesToSpawn.first.id, 'custom-relative-id');
        },
      );

      test(
        'getNextOccurrenceToSpawn() utilizes custom generateId for FixedCalendarPolicy',
        () {
          final engine = SchedulerEngine(
            generateId: () => 'custom-next-fixed-id',
          );
          final dailyRule = DailySchedule(startDate: today, interval: 1);
          final task = TaskSchedule(
            id: 'fixed-next-task',
            title: 'Fixed Next Task',
            description: 'A custom id test task',
            schedules: [dailyRule],
          );

          final completedInstance = TaskInstance(
            id: 'completed-fixed-1',
            scheduleId: task.id,
            ruleId: dailyRule.id,
            title: task.title,
            description: task.description,
            scheduledDate: today,
            startRelativeTime: dailyRule.startRelativeTime,
            dueRelativeTime: dailyRule.dueRelativeTime,
            status: TaskStatus.completed,
            completedAt: now,
          );

          final nextInstance = engine.getNextOccurrenceToSpawn(
            task,
            completedInstance,
            now,
            [completedInstance],
          );

          expect(nextInstance, isNotNull);
          expect(nextInstance!.id, 'custom-next-fixed-id');
          expect(nextInstance.scheduledDate, today.addDays(1));
        },
      );

      test(
        'getNextOccurrenceToSpawn() utilizes custom generateId for CompletionRelativePolicy',
        () {
          final engine = SchedulerEngine(
            generateId: () => 'custom-next-relative-id',
          );
          final crRule = DailySchedule(
            startDate: today,
            interval: 1,
            schedulingPolicy: const CompletionRelativePolicy(
              interval: Duration(days: 2),
              targetTime: TimeOfDay(hour: 9, minute: 0),
            ),
          );
          final task = TaskSchedule(
            id: 'relative-next-task',
            title: 'Relative Next Task',
            description: 'A custom id test task',
            schedules: [crRule],
          );

          final completedInstance = TaskInstance(
            id: 'completed-relative-1',
            scheduleId: task.id,
            ruleId: crRule.id,
            title: task.title,
            description: task.description,
            scheduledDate: today,
            startRelativeTime: crRule.startRelativeTime,
            dueRelativeTime: crRule.dueRelativeTime,
            status: TaskStatus.completed,
            completedAt: now,
          );

          final nextInstance = engine.getNextOccurrenceToSpawn(
            task,
            completedInstance,
            now,
            [completedInstance],
          );

          expect(nextInstance, isNotNull);
          expect(nextInstance!.id, 'custom-next-relative-id');
          expect(nextInstance.scheduledDate, today.addDays(2));
        },
      );
    });

    group('Capacity limit edge cases & trigger time tests', () {
      test(
        'reviving skipped instance does not re-add to instancesToUpdate if already skipped in DB when still over capacity',
        () {
          final task = TaskSchedule(
            id: 'task-overcap',
            title: 'Over Capacity Task',
            description: '',
            estimatedDuration: const Duration(hours: 4),
            skipIfNoCapacity: true,
            schedules: [
              OneOffSchedule(
                date: today.addDays(1),
                startRelativeTime: const RelativeTime(
                  dayOffset: 0,
                  time: TimeOfDay(hour: 10, minute: 0),
                ),
                dueRelativeTime: const RelativeTime(
                  dayOffset: 0,
                  time: TimeOfDay(hour: 18, minute: 0),
                ),
              ),
            ],
          );

          final existingSkippedInst = TaskInstance(
            id: 'inst-overcap',
            scheduleId: task.id,
            ruleId: task.schedules.first.id,
            title: task.title,
            description: task.description,
            scheduledDate: today.addDays(1),
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 10, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 18, minute: 0),
            ),
            status: TaskStatus.skipped,
          );

          final userSettings = UserSettings(hoursAvailable: 0.0);

          final action = const SchedulerEngine().evaluate(
            task,
            [existingSkippedInst],
            now,
            userSettings: userSettings,
          );

          // Since capacity is 0 and the DB status was already 'skipped',
          // reverting the staged pending back to skipped should remove it from instancesToUpdate
          // to prevent redundant database writes.
          expect(
            action.instancesToUpdate.any((x) => x.id == 'inst-overcap'),
            isFalse,
          );
        },
      );

      test(
        'tempPlannedHours does not subtract duration of completed task instances',
        () {
          final tomorrow = today.addDays(1);
          final rule1 = DailySchedule(
            id: 'rule-1',
            startDate: tomorrow,
            interval: 1,
          );
          final rule2 = OneOffSchedule(
            id: 'rule-2',
            date: tomorrow,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 14, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 18, minute: 0),
            ),
          );
          final task = TaskSchedule(
            id: 'task-completed-cap',
            title: 'Completed Cap Task',
            description: '',
            estimatedDuration: const Duration(hours: 4),
            skipIfNoCapacity: true,
            schedules: [rule1, rule2],
          );

          final completedInst = TaskInstance(
            id: 'inst-completed',
            scheduleId: task.id,
            ruleId: rule1.id,
            title: task.title,
            description: task.description,
            scheduledDate: tomorrow,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 8, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 12, minute: 0),
            ),
            status: TaskStatus.completed,
          );

          // Total capacity is 6 hours, 4 hours is already taken by the completed instance.
          // dayPlannedHours reflects total planned hours on that day.
          final userSettings = UserSettings(hoursAvailable: 6.0);
          final dayPlannedHours = {tomorrow: 4.0};

          // Evaluating a new instance attempt on the same day when remaining capacity is only 2 hours (6.0 - 4.0 = 2.0 < 4.0)
          // If completedInst is not wrongly subtracted from tempPlannedHours, remaining capacity remains 2.0 < 4.0, so the new instance is skipped.
          // If completedInst was wrongly subtracted, planned becomes 4.0 - 4.0 = 0.0, remaining capacity becomes 6.0 >= 4.0, wrongly pending.
          final action = const SchedulerEngine().evaluate(
            task,
            [completedInst],
            now,
            userSettings: userSettings,
            dayPlannedHours: dayPlannedHours,
          );

          final spawnedTomorrow = action.instancesToSpawn.firstWhere(
            (x) =>
                x.ruleId == task.schedules.last.id &&
                x.scheduledDate == tomorrow,
          );
          expect(spawnedTomorrow.status, TaskStatus.skipped);
        },
      );

      test(
        'ghost capacity: instance staged to skipped by rule does not consume capacity',
        () {
          final yesterday = today.addDays(-1);
          final task = TaskSchedule(
            id: 'task-ghost',
            title: 'Ghost Capacity Task',
            description: '',
            estimatedDuration: const Duration(hours: 6),
            skipIfNoCapacity: true,
            schedules: [
              DailySchedule(
                startDate: yesterday,
                interval: 1,
                dueRelativeTime: const RelativeTime(
                  dayOffset: 0,
                  time: TimeOfDay(hour: 12, minute: 0),
                ),
                missedOccurrencePolicy:
                    const MissedOccurrencePolicy.autoDismiss(
                      gracePeriod: Duration.zero,
                    ),
              ),
            ],
          );

          final yesterdayInst = TaskInstance(
            id: 'inst-ghost',
            scheduleId: task.id,
            ruleId: task.schedules.first.id,
            title: task.title,
            description: task.description,
            scheduledDate: yesterday,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 12, minute: 0),
            ),
            status: TaskStatus.pending,
          );

          final action = const SchedulerEngine().evaluate(task, [
            yesterdayInst,
          ], now);

          // yesterdayInst is auto-dismissed (skipped)
          expect(
            action.instancesToUpdate
                .firstWhere((x) => x.id == 'inst-ghost')
                .status,
            TaskStatus.skipped,
          );
        },
      );

      test('no spurious trigger times for skipped instances', () {
        final tomorrow = today.addDays(1);
        final task = TaskSchedule(
          id: 'task-no-trigger-skipped',
          title: 'No Spurious Trigger',
          description: '',
          estimatedDuration: const Duration(hours: 10),
          skipIfNoCapacity: true,
          schedules: [
            OneOffSchedule(
              date: tomorrow,
              startRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 10, minute: 0),
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 18, minute: 0),
              ),
            ),
          ],
        );

        final userSettings = UserSettings(hoursAvailable: 0.0); // No capacity

        final action = const SchedulerEngine().evaluate(
          task,
          [],
          now,
          userSettings: userSettings,
        );

        expect(action.instancesToSpawn, hasLength(1));
        expect(action.instancesToSpawn.first.status, TaskStatus.skipped);
        // Since the spawned instance is skipped due to capacity limits, no trigger times should be generated
        expect(action.triggerTimes, isEmpty);
      });

      test(
        'populates triggerTimes for one-off tasks with future start/due times',
        () {
          final tomorrow = today.addDays(1);
          final task = TaskSchedule(
            id: 'task-oneoff-trigger',
            title: 'One-off Trigger',
            description: '',
            schedules: [
              OneOffSchedule(
                date: tomorrow,
                startRelativeTime: const RelativeTime(
                  dayOffset: 0,
                  time: TimeOfDay(hour: 10, minute: 0),
                ),
                dueRelativeTime: const RelativeTime(
                  dayOffset: 0,
                  time: TimeOfDay(hour: 18, minute: 0),
                ),
              ),
            ],
          );

          final action = const SchedulerEngine().evaluate(task, [], now);

          expect(action.instancesToSpawn, hasLength(1));
          expect(action.instancesToSpawn.first.status, TaskStatus.pending);
          expect(action.triggerTimes, isNotEmpty);
          final expectedStart = tomorrow.toDateTime().add(
            const Duration(hours: 10),
          );
          final expectedDue = tomorrow.toDateTime().add(
            const Duration(hours: 18),
          );
          expect(
            action.triggerTimes,
            containsAll([expectedStart, expectedDue]),
          );
        },
      );
    });

    group('Duplicate Instance Pruning and Deduplication', () {
      test(
        'prunes duplicate instances for the same scheduledDate and keeps resolved instance',
        () {
          final scheduleRule = DailySchedule(startDate: today, interval: 1);
          final task = TaskSchedule(
            id: 'task-dedup-1',
            title: 'Daily Dedup Task',
            description: 'Test',
            schedules: [scheduleRule],
            updatedAt: now,
          );

          final completedInstance = TaskInstance(
            id: 'inst-completed-1',
            scheduleId: task.id,
            ruleId: scheduleRule.id,
            title: task.title,
            description: task.description,
            scheduledDate: today,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.completed,
            completedAt: now.subtract(const Duration(hours: 1)),
            updatedAt: now.subtract(const Duration(hours: 1)),
          );

          final pendingInstance = TaskInstance(
            id: 'inst-pending-1',
            scheduleId: task.id,
            ruleId: scheduleRule.id,
            title: task.title,
            description: task.description,
            scheduledDate: today,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.pending,
            updatedAt: now,
          );

          final action = const SchedulerEngine().evaluate(task, [
            completedInstance,
            pendingInstance,
          ], now);

          expect(action.instancesToDelete, contains('inst-pending-1'));
          expect(action.instancesToDelete, isNot(contains('inst-completed-1')));
          expect(
            action.instancesToSpawn.any((i) => i.scheduledDate == today),
            isFalse,
          );
        },
      );

      test(
        'prunes duplicate pending instances for the same scheduledDate and keeps newest updatedAt',
        () {
          final scheduleRule = DailySchedule(startDate: today, interval: 1);
          final task = TaskSchedule(
            id: 'task-dedup-2',
            title: 'Daily Pending Dedup Task',
            description: 'Test',
            schedules: [scheduleRule],
            updatedAt: now,
          );

          final olderPending = TaskInstance(
            id: 'inst-older-pending',
            scheduleId: task.id,
            ruleId: scheduleRule.id,
            title: task.title,
            description: task.description,
            scheduledDate: today,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.pending,
            updatedAt: now.subtract(const Duration(hours: 2)),
          );

          final newerPending = TaskInstance(
            id: 'inst-newer-pending',
            scheduleId: task.id,
            ruleId: scheduleRule.id,
            title: task.title,
            description: task.description,
            scheduledDate: today,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.pending,
            updatedAt: now.subtract(const Duration(hours: 1)),
          );

          final action = const SchedulerEngine().evaluate(task, [
            olderPending,
            newerPending,
          ], now);

          expect(action.instancesToDelete, contains('inst-older-pending'));
          expect(
            action.instancesToDelete,
            isNot(contains('inst-newer-pending')),
          );
        },
      );
    });

    group('Telemetry & StatusReason Attributions', () {
      test('sets statusReason and appVersion on preferOlder skips', () {
        final task = TestTaskFactory.createDaily(
          id: 'task-prefer-older',
          title: 'Clean Kitchen',
          description: 'Daily chore',
          startDate: today.addDays(-1),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          missedOccurrencePolicy: const MissedOccurrencePolicy(
            policy: MissedPolicy.preferOlder,
          ),
        );

        final yesterdayInst = TaskInstance(
          id: 'inst-yesterday',
          scheduleId: task.id,
          ruleId: task.schedules.first.id,
          title: task.title,
          description: task.description,
          scheduledDate: today.addDays(-1),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          status: TaskStatus.pending,
        );

        final todayInst = TaskInstance(
          id: 'inst-today',
          scheduleId: task.id,
          ruleId: task.schedules.first.id,
          title: task.title,
          description: task.description,
          scheduledDate: today,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          status: TaskStatus.pending,
        );

        final action = const SchedulerEngine().evaluate(
          task,
          [yesterdayInst, todayInst],
          now,
          userId: 'user-123',
        );

        final updatedToday = action.instancesToUpdate.firstWhere(
          (x) => x.id == 'inst-today',
        );
        expect(updatedToday.status, TaskStatus.skipped);
        expect(updatedToday.statusReason, 'scheduler_prefer_older');
        expect(updatedToday.lastModifiedByUserId, 'user-123');
        expect(updatedToday.lastModifiedByAppVersion, isNotNull);
        expect(updatedToday.lastModifiedByPlatform, isNotNull);
      });

      test('sets statusReason and appVersion on preferNewer skips', () {
        final task = TestTaskFactory.createDaily(
          id: 'task-prefer-newer',
          title: 'Daily Checkin',
          description: 'Daily',
          startDate: today.addDays(-1),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          missedOccurrencePolicy: const MissedOccurrencePolicy(
            policy: MissedPolicy.preferNewer,
          ),
        );

        final yesterdayInst = TaskInstance(
          id: 'inst-yesterday',
          scheduleId: task.id,
          ruleId: task.schedules.first.id,
          title: task.title,
          description: task.description,
          scheduledDate: today.addDays(-1),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          status: TaskStatus.pending,
        );

        final todayInst = TaskInstance(
          id: 'inst-today',
          scheduleId: task.id,
          ruleId: task.schedules.first.id,
          title: task.title,
          description: task.description,
          scheduledDate: today,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          status: TaskStatus.pending,
        );

        final action = const SchedulerEngine().evaluate(
          task,
          [yesterdayInst, todayInst],
          now,
          userId: 'user-123',
        );

        final updatedYesterday = action.instancesToUpdate.firstWhere(
          (x) => x.id == 'inst-yesterday',
        );
        expect(updatedYesterday.status, TaskStatus.skipped);
        expect(updatedYesterday.statusReason, 'scheduler_prefer_newer');
        expect(updatedYesterday.lastModifiedByUserId, 'user-123');
        expect(updatedYesterday.lastModifiedByAppVersion, isNotNull);
        expect(updatedYesterday.lastModifiedByPlatform, isNotNull);
      });

      test('sets statusReason and appVersion on autoDismiss skips', () {
        final task = TestTaskFactory.createDaily(
          id: 'task-autodismiss',
          title: 'Daily Trash',
          description: 'Daily',
          startDate: today.addDays(-2),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          missedOccurrencePolicy: const MissedOccurrencePolicy.autoDismiss(
            gracePeriod: Duration(hours: 12),
          ),
        );

        final oldInst = TaskInstance(
          id: 'inst-old',
          scheduleId: task.id,
          ruleId: task.schedules.first.id,
          title: task.title,
          description: task.description,
          scheduledDate: today.addDays(-2),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          status: TaskStatus.pending,
        );

        final action = const SchedulerEngine().evaluate(
          task,
          [oldInst],
          now,
          userId: 'user-456',
        );

        final updatedOld = action.instancesToUpdate.firstWhere(
          (x) => x.id == 'inst-old',
        );
        expect(updatedOld.status, TaskStatus.skipped);
        expect(updatedOld.statusReason, 'scheduler_auto_dismiss');
        expect(updatedOld.lastModifiedByUserId, 'user-456');
        expect(updatedOld.lastModifiedByAppVersion, isNotNull);
        expect(updatedOld.lastModifiedByPlatform, isNotNull);
      });

      test(
        'preferOlder does not skip today when prior days were skipped or when starting from past resolved date',
        () {
          final startDate = const CivilDay(year: 2026, month: 8, day: 16);
          final today = const CivilDay(year: 2026, month: 8, day: 26);
          final now = DateTime(
            2026,
            8,
            26,
            13,
            0,
          ); // 1:00 PM, after 9:00 AM start

          final task = TestTaskFactory.createDaily(
            id: 'prefer-older-cascade-bug',
            title: 'Clean Kitchen',
            description: 'Daily chore',
            startDate: startDate,
            interval: 1,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            missedOccurrencePolicy: const MissedOccurrencePolicy.preferOlder(),
          );

          // Aug 23 completed
          final completedAug23 = TaskInstance(
            id: 'inst_aug23',
            scheduleId: task.id,
            ruleId: task.schedules.first.id,
            title: task.title,
            description: task.description,
            scheduledDate: const CivilDay(year: 2026, month: 8, day: 23),
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.completed,
            completedAt: DateTime(2026, 8, 24, 6, 0),
          );

          // Lookahead previously created Aug 26 as pending
          final pendingToday = TaskInstance(
            id: 'inst_aug26',
            scheduleId: task.id,
            ruleId: task.schedules.first.id,
            title: task.title,
            description: task.description,
            scheduledDate: today,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.pending,
          );

          // Evaluating with only the resolved Aug 23 and pending today (Aug 24 & 25 not in DB)
          final action = const SchedulerEngine().evaluate(
            task,
            [completedAug23, pendingToday],
            now,
            futureInstancesCount: 5,
          );

          // Today's instance (Aug 26) must NOT be updated to skipped!
          final todayUpdate = action.instancesToUpdate.where(
            (x) => x.scheduledDate == today,
          );
          expect(
            todayUpdate.isEmpty ||
                todayUpdate.first.status == TaskStatus.pending,
            isTrue,
            reason:
                'Today instance (Aug 26) should stay pending, not get skipped',
          );
        },
      );

      test(
        'preferOlder does not revive a skipped instance when older instance is completed, but waits for tomorrow',
        () {
          final startDate = const CivilDay(year: 2026, month: 8, day: 16);
          final day1 = const CivilDay(year: 2026, month: 8, day: 24);
          final day2 = const CivilDay(year: 2026, month: 8, day: 25);
          final day3 = const CivilDay(year: 2026, month: 8, day: 26);

          final task = TestTaskFactory.createDaily(
            id: 'prefer-older-no-revival-test',
            title: 'Clean Kitchen',
            description: 'Daily chore',
            startDate: startDate,
            interval: 1,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            missedOccurrencePolicy: const MissedOccurrencePolicy.preferOlder(),
          );

          // Step 1: On Day 2 morning (10am), Day 1 was still pending, so Day 2 was skipped
          final pendingDay1 = TaskInstance(
            id: 'inst_day1',
            scheduleId: task.id,
            ruleId: task.schedules.first.id,
            title: task.title,
            description: task.description,
            scheduledDate: day1,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.pending,
          );

          final evalDay2Morning = DateTime(2026, 8, 25, 10, 0);
          final actionDay2Morning = const SchedulerEngine().evaluate(
            task,
            [pendingDay1],
            evalDay2Morning,
            futureInstancesCount: 5,
          );

          // Day 1 remains pending, Day 2 is not spawned as pending (skipped by rule)
          final spawnedDay2 = actionDay2Morning.instancesToSpawn.where(
            (x) => x.scheduledDate == day2,
          );
          expect(spawnedDay2, isEmpty);

          // Step 2: On Day 2 afternoon (3pm), user completes Day 1
          final completedDay1 = pendingDay1.copyWith(
            status: TaskStatus.completed,
            completedAt: DateTime(2026, 8, 25, 15, 0),
          );
          final skippedDay2 = TaskInstance(
            id: 'inst_day2',
            scheduleId: task.id,
            ruleId: task.schedules.first.id,
            title: task.title,
            description: task.description,
            scheduledDate: day2,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.skipped,
            statusReason: 'scheduler_prefer_older',
          );

          final evalDay2Afternoon = DateTime(2026, 8, 25, 16, 0);
          final actionDay2Afternoon = const SchedulerEngine().evaluate(
            task,
            [completedDay1, skippedDay2],
            evalDay2Afternoon,
            futureInstancesCount: 5,
          );

          // Day 2 was skipped and must NOT come back to life (not in instancesToUpdate)
          final day2Updates = actionDay2Afternoon.instancesToUpdate.where(
            (x) => x.id == 'inst_day2',
          );
          expect(day2Updates, isEmpty);

          // Step 3: On Day 3 morning (10am), Day 3 arrives. Because Day 1 & Day 2 are resolved, Day 3 must be pending!
          final evalDay3Morning = DateTime(2026, 8, 26, 10, 0);
          final actionDay3Morning = const SchedulerEngine().evaluate(
            task,
            [completedDay1, skippedDay2],
            evalDay3Morning,
            futureInstancesCount: 5,
          );

          // Day 3 should be spawned as pending!
          final spawnedDay3 = actionDay3Morning.instancesToSpawn.firstWhere(
            (x) => x.scheduledDate == day3,
          );
          expect(spawnedDay3.status, TaskStatus.pending);
        },
      );
    });

    group('Safe element lookup tests', () {
      test(
        'evaluates safely without StateError when candidate instances are absent',
        () {
          final dailyRule = DailySchedule(
            startDate: const CivilDay(year: 2026, month: 8, day: 25),
            interval: 1,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
          );
          final task = TaskSchedule(
            id: 'task-safe-test',
            title: 'Daily Task',
            description: 'Desc',
            schedules: [dailyRule],
            skipIfNoCapacity: true,
          );

          final now = DateTime(2026, 8, 25, 10, 0);
          expect(
            () => const SchedulerEngine().evaluate(
              task,
              [],
              now,
              applyCapacityLimits: true,
              userSettings: const UserSettings(hoursAvailable: 1.0),
            ),
            returnsNormally,
          );
        },
      );
    });
  });
}
