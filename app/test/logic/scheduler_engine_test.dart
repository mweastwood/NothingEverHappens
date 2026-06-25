import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/scheduler_engine.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';

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

        final action = SchedulerEngine.evaluate(task, [], now);

        expect(action.instancesToSpawn, hasLength(1));
        final spawned = action.instancesToSpawn.first;
        expect(spawned.id.startsWith('I-'), isTrue);
        expect(spawned.scheduledDate, today);
        expect(spawned.status, 'pending');
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
          status: 'pending',
        );

        final action = SchedulerEngine.evaluate(task, [existingInstance], now);

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
            status: 'completed',
            completedAt: now.subtract(const Duration(days: 2)),
          );

          final action = SchedulerEngine.evaluate(task, [resolvedOneOff], now);

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

        final action = SchedulerEngine.evaluate(task, [], now);

        // Should spawn 5 instances under N=1: June 16, 17, 18, 19, and future 20
        expect(action.instancesToSpawn, hasLength(5));
        expect(action.instancesToSpawn[0].scheduledDate.day, 16);
        expect(action.instancesToSpawn[0].status, 'pending');
        expect(action.instancesToSpawn[1].scheduledDate.day, 17);
        expect(action.instancesToSpawn[1].status, 'pending');
        expect(action.instancesToSpawn[2].scheduledDate.day, 18);
        expect(action.instancesToSpawn[2].status, 'pending');
        expect(action.instancesToSpawn[3].scheduledDate.day, 19);
        expect(action.instancesToSpawn[3].status, 'pending');
        expect(action.instancesToSpawn[4].scheduledDate.day, 20);
        expect(action.instancesToSpawn[4].status, 'pending');

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

          final action = SchedulerEngine.evaluate(task, [], now);

          // Under N=1, today (June 19) and tomorrow (June 20) are pending.
          // Older dates (June 17, 18) are skipped and not spawned.
          expect(action.instancesToSpawn, hasLength(2));
          expect(action.instancesToSpawn[0].scheduledDate.day, 19);
          expect(action.instancesToSpawn[0].status, 'pending');
          expect(action.instancesToSpawn[1].scheduledDate.day, 20);
          expect(action.instancesToSpawn[1].status, 'pending');
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
          status: 'pending',
        );

        final action = SchedulerEngine.evaluate(task, [existingPending], now);

        // Existing yesterday instance should be updated to skipped
        expect(action.instancesToUpdate, hasLength(1));
        expect(action.instancesToUpdate.first.status, 'skipped');

        // Today (June 19) and tomorrow (June 20) should be spawned as pending
        expect(action.instancesToSpawn, hasLength(2));
        expect(action.instancesToSpawn[0].scheduledDate.day, 19);
        expect(action.instancesToSpawn[0].status, 'pending');
        expect(action.instancesToSpawn[1].scheduledDate.day, 20);
        expect(action.instancesToSpawn[1].status, 'pending');
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
            status: 'pending',
          );

          final action = SchedulerEngine.evaluate(task, [todayInstance], now);

          // Today's instance should remain pending, meaning it is NOT updated to skipped!
          expect(action.instancesToUpdate, isEmpty);

          // Tomorrow's lookahead instance (June 20) should be spawned as pending
          expect(action.instancesToSpawn, hasLength(1));
          expect(action.instancesToSpawn[0].scheduledDate, today.addDays(1));
          expect(action.instancesToSpawn[0].status, 'pending');
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

          final action = SchedulerEngine.evaluate(task, [], now);

          // 17 (oldest) should be pending; others (18, 19, 20) are skipped and not spawned
          expect(action.instancesToSpawn, hasLength(1));
          expect(action.instancesToSpawn[0].scheduledDate.day, 17);
          expect(action.instancesToSpawn[0].status, 'pending');
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
            status: 'pending',
          );

          final action = SchedulerEngine.evaluate(task, [existingPending], now);

          // Monday's remains pending (no updates)
          expect(action.instancesToUpdate, isEmpty);

          // Today's new instances (June 19, 20) are skipped and not spawned
          expect(action.instancesToSpawn, isEmpty);
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
          status: 'pending',
        );

        final action = SchedulerEngine.evaluate(task, [yesterdayInstance], now);

        // Yesterday's instance (expired yesterday at 2:00 PM) is skipped
        expect(action.instancesToUpdate, hasLength(1));
        expect(action.instancesToUpdate.first.status, 'skipped');

        // June 19 (pending) and June 20 (pending N=1 future) should be spawned
        expect(action.instancesToSpawn, hasLength(2));
        expect(action.instancesToSpawn[0].scheduledDate, today);
        expect(action.instancesToSpawn[0].status, 'pending');
        expect(action.instancesToSpawn[1].scheduledDate, today.addDays(1));
        expect(action.instancesToSpawn[1].status, 'pending');
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
            status: 'completed',
            completedAt: DateTime(2026, 6, 19, 14, 0),
          );

          final nextInst = SchedulerEngine.getNextOccurrenceToSpawn(
            task,
            completedInstance,
            DateTime(2026, 6, 19, 14, 0),
            [completedInstance],
          );
          expect(nextInst, isNotNull);
          expect(nextInst!.scheduledDate, today.addDays(3)); // June 22
          expect(nextInst.status, 'pending');
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
          status: 'completed',
        );

        final action = SchedulerEngine.evaluate(task, [resolvedMay1], now);

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
          final action1 = SchedulerEngine.evaluate(task, [], now);
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
            status: 'completed',
            completedAt: now,
          );
          final updatedTask1 = action1.updatedSchedule!;
          final action2 = SchedulerEngine.evaluate(updatedTask1, [
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
            status: 'pending',
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
            status: 'pending',
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
            status: 'pending',
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
            status: 'pending',
          );

          final List<TaskInstance> existingInstances = [
            inst20,
            inst21,
            inst22,
            inst23,
          ];

          // Run evaluate with futureInstancesCount = 2
          final action = SchedulerEngine.evaluate(
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
    });
  });
}
