import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
        final task = TaskSchedule(
          id: 'oneoff-1',
          title: 'One Off Task',
          description: 'A simple one-off task',
          schedules: [
            OneOffSchedule(
              date: today,
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
        final task = TaskSchedule(
          id: 'oneoff-1',
          title: 'One Off Task',
          description: 'A simple one-off task',
          schedules: [
            OneOffSchedule(
              date: today,
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
        final task = TaskSchedule(
          id: 'stack-1',
          title: 'Stack Task',
          description: 'Piles up',
          schedules: [
            DailySchedule(
              startDate: startDate,
              interval: 1,
              missedOccurrencePolicy: const MissedOccurrencePolicy.stack(),
            ),
          ],
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
          final task = TaskSchedule(
            id: 'newer-1',
            title: 'Prefer Newer Task',
            description: 'Keeps newest only',
            schedules: [
              DailySchedule(
                startDate: startDate,
                interval: 1,
                missedOccurrencePolicy:
                    const MissedOccurrencePolicy.preferNewer(),
              ),
            ],
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
        final task = TaskSchedule(
          id: 'newer-2',
          title: 'Prefer Newer Task 2',
          description: 'Advances active',
          lastSpawnedDate: yesterday,
          schedules: [
            DailySchedule(
              startDate: yesterday,
              interval: 1,
              missedOccurrencePolicy:
                  const MissedOccurrencePolicy.preferNewer(),
            ),
          ],
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
          final task = TaskSchedule(
            id: 'newer-3',
            title: 'Prefer Newer Task 3',
            description: 'Today is active, tomorrow is future',
            lastSpawnedDate: today,
            schedules: [
              DailySchedule(
                startDate: today,
                interval: 1,
                missedOccurrencePolicy:
                    const MissedOccurrencePolicy.preferNewer(),
              ),
            ],
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

          final task = TaskSchedule(
            id: 'newer-bug-test',
            title: 'Prefer Newer Start Time Task',
            description: 'Start time test',
            lastSpawnedDate: yesterday,
            schedules: [
              DailySchedule(
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
                missedOccurrencePolicy:
                    const MissedOccurrencePolicy.preferNewer(),
              ),
            ],
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
    });

    group('FixedCalendarPolicy - Prefer Older', () {
      test(
        'keeps the oldest missed instance pending, and skips subsequent newer ones',
        () {
          final startDate = today.addDays(-2); // June 17
          final task = TaskSchedule(
            id: 'older-1',
            title: 'Prefer Older Task',
            description: 'Keeps oldest only',
            schedules: [
              DailySchedule(
                startDate: startDate,
                interval: 1,
                missedOccurrencePolicy:
                    const MissedOccurrencePolicy.preferOlder(),
              ),
            ],
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
          final task = TaskSchedule(
            id: 'older-2',
            title: 'Prefer Older Task 2',
            description: 'Keeps oldest only',
            lastSpawnedDate: yesterday,
            schedules: [
              DailySchedule(
                startDate: yesterday,
                interval: 1,
                missedOccurrencePolicy:
                    const MissedOccurrencePolicy.preferOlder(),
              ),
            ],
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

          final task = TaskSchedule(
            id: 'older-bug-test',
            title: 'Prefer Older Start Time Task',
            description: 'Start time test',
            lastSpawnedDate: yesterday,
            schedules: [
              DailySchedule(
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
                missedOccurrencePolicy:
                    const MissedOccurrencePolicy.preferOlder(),
              ),
            ],
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
    });

    group('FixedCalendarPolicy - Auto-Dismiss', () {
      test('auto-dismisses expired pending, keeps within grace period', () {
        final yesterday = today.addDays(-1);
        final task = TaskSchedule(
          id: 'dismiss-1',
          title: 'Auto Dismiss Task',
          description: 'Auto Dismiss Task',
          schedules: [
            DailySchedule(
              startDate: yesterday,
              interval: 1,
              dueRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 12, minute: 0),
              ),
              missedOccurrencePolicy: const MissedOccurrencePolicy.autoDismiss(
                gracePeriod: Duration(hours: 2),
              ),
            ),
          ],
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
          final task = TaskSchedule(
            id: 'relative-spawn',
            title: 'Completion Relative Task',
            description: 'Relative task',
            schedules: [
              DailySchedule(
                startDate: today.addDays(-1),
                interval: 3,
                schedulingPolicy: const CompletionRelativePolicy(
                  interval: Duration(days: 3),
                  targetTime: TimeOfDay(hour: 9, minute: 0),
                ),
              ),
            ],
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
        final task = TaskSchedule(
          id: 'cap-1',
          title: 'Capacity Task',
          description: 'Skips when full',
          estimatedDuration: const Duration(hours: 4),
          skipIfNoCapacity: true,
          schedules: [DailySchedule(startDate: today, interval: 1)],
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
        final taskHigh = TaskSchedule(
          id: 'cap-high',
          title: 'High Priority Task',
          description: 'High',
          priority: TaskPriority.high,
          estimatedDuration: const Duration(hours: 5),
          skipIfNoCapacity: true,
          schedules: [OneOffSchedule(date: today)],
        );

        // Medium priority task
        final taskMed = TaskSchedule(
          id: 'cap-med',
          title: 'Medium Priority Task',
          description: 'Med',
          priority: TaskPriority.medium,
          estimatedDuration: const Duration(hours: 5),
          skipIfNoCapacity: true,
          schedules: [OneOffSchedule(date: today)],
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
          final taskA = TaskSchedule(
            id: 'cap-a',
            title: 'Task A',
            description: '',
            priority: TaskPriority.medium,
            estimatedDuration: const Duration(hours: 5),
            skipIfNoCapacity: true,
            schedules: [OneOffSchedule(date: today)],
          );

          final taskB = TaskSchedule(
            id: 'cap-b',
            title: 'Task B',
            description: '',
            priority: TaskPriority.medium,
            estimatedDuration: const Duration(hours: 5),
            skipIfNoCapacity: true,
            schedules: [OneOffSchedule(date: today)],
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
          final task = TaskSchedule(
            id: 'cap-revive',
            title: 'Revive Task',
            description: 'Revives to pending',
            estimatedDuration: const Duration(hours: 4),
            skipIfNoCapacity: true,
            schedules: [OneOffSchedule(date: today.addDays(1))],
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
          final task = TaskSchedule(
            id: 'cap-revive',
            title: 'Revive Task',
            description: 'Revives to pending',
            estimatedDuration: const Duration(hours: 4),
            skipIfNoCapacity: false,
            schedules: [OneOffSchedule(date: today.addDays(1))],
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
          final task = TaskSchedule(
            id: 'cap-no-apply',
            title: 'No Apply Task',
            description: 'No capacity evaluation',
            estimatedDuration: const Duration(hours: 4),
            skipIfNoCapacity: true,
            schedules: [OneOffSchedule(date: today.addDays(1))],
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
          final task = TaskSchedule(
            id: 'cap-check',
            title: 'Capacity Check Task',
            description: 'Capacity evaluation',
            estimatedDuration: const Duration(hours: 5),
            skipIfNoCapacity: true,
            schedules: [OneOffSchedule(date: today.addDays(1))],
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

          action = const SchedulerEngine().evaluate(task, [mondayInst], pastGrace);
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
  });
}
