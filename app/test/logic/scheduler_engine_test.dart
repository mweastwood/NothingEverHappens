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
        expect(spawned.id, 'oneoff-1_2026-06-19');
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

        // Should spawn 4 instances: June 16, 17, 18, 19
        expect(action.instancesToSpawn, hasLength(4));
        expect(action.instancesToSpawn[0].scheduledDate.day, 16);
        expect(action.instancesToSpawn[0].status, 'pending');
        expect(action.instancesToSpawn[1].scheduledDate.day, 17);
        expect(action.instancesToSpawn[1].status, 'pending');
        expect(action.instancesToSpawn[2].scheduledDate.day, 18);
        expect(action.instancesToSpawn[2].status, 'pending');
        expect(action.instancesToSpawn[3].scheduledDate.day, 19);
        expect(action.instancesToSpawn[3].status, 'pending');

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

          // 17, 18 should be marked skipped, 19 should be pending
          expect(action.instancesToSpawn, hasLength(3));
          expect(action.instancesToSpawn[0].scheduledDate.day, 17);
          expect(action.instancesToSpawn[0].status, 'skipped');
          expect(action.instancesToSpawn[1].scheduledDate.day, 18);
          expect(action.instancesToSpawn[1].status, 'skipped');
          expect(action.instancesToSpawn[2].scheduledDate.day, 19);
          expect(action.instancesToSpawn[2].status, 'pending');
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

        // Today's instance should be spawned as pending
        expect(action.instancesToSpawn, hasLength(1));
        expect(action.instancesToSpawn.first.scheduledDate, today);
        expect(action.instancesToSpawn.first.status, 'pending');
      });
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

          // 17 (oldest) should be pending; 18 and 19 should be skipped
          expect(action.instancesToSpawn, hasLength(3));
          expect(action.instancesToSpawn[0].scheduledDate.day, 17);
          expect(action.instancesToSpawn[0].status, 'pending');
          expect(action.instancesToSpawn[1].scheduledDate.day, 18);
          expect(action.instancesToSpawn[1].status, 'skipped');
          expect(action.instancesToSpawn[2].scheduledDate.day, 19);
          expect(action.instancesToSpawn[2].status, 'skipped');
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

          // Today's new instance is spawned as skipped
          expect(action.instancesToSpawn, hasLength(1));
          expect(action.instancesToSpawn.first.scheduledDate, today);
          expect(action.instancesToSpawn.first.status, 'skipped');
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

        // Today's instance is spawned as pending (since it's 10:00 AM, due at 12:00 PM, not expired)
        expect(action.instancesToSpawn, hasLength(1));
        expect(action.instancesToSpawn.first.scheduledDate, today);
        expect(action.instancesToSpawn.first.status, 'pending');
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
          );
          expect(nextInst, isNotNull);
          expect(nextInst!.scheduledDate, today.addDays(3)); // June 22
          expect(nextInst.status, 'pending');
        },
      );
    });

    group('30-Day Window Progress / Sticking Bugs', () {
      test('advances lastSpawnedDate through gaps of 30+ days without occurrences', () {
        // Today is June 19, 2026.
        // Start date is May 1, 2026 (49 days ago).
        // The task is bi-monthly (every 2 months), occurring on the 1st of the month.
        // Occurrences: May 1, July 1, etc.
        // The first evaluation (normally run on May 1) spawned the May 1 instance and set lastSpawnedDate to May 1.
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

        // Evaluation today (June 19):
        // It should check from May 2 to June 19.
        // Since there are no occurrences in this range (next is July 1), datesToSpawn is empty.
        // If it works correctly, it should advance lastSpawnedDate to June 19 (or up to June 19)
        // so it doesn't get stuck checking the same range forever.
        final action = SchedulerEngine.evaluate(task, [], now);

        expect(action.instancesToSpawn, isEmpty);
        expect(action.updatedSchedule, isNotNull);
        // It should have advanced lastSpawnedDate past May 1 (since it checked 30 days from May 2 to May 31).
        expect(action.updatedSchedule!.lastSpawnedDate, isNotNull);
        expect(
          action.updatedSchedule!.lastSpawnedDate!.isBefore(startDate),
          isFalse,
        );
        expect(
          action.updatedSchedule!.lastSpawnedDate!,
          equals(CivilDay(year: 2026, month: 5, day: 31)),
        );
      });

      test(
        'regression: monthly task starting > 30 days ago gets evaluated up to today and spawns task',
        () {
          // Today is June 19, 2026.
          // Start date is May 1, 2026 (49 days ago).
          // The task is monthly (every 1 month), occurring on the 15th of the month.
          // Occurrences: May 15, June 15.
          // The task is brand new (lastSpawnedDate is null).
          // In the first evaluation (up to 30 days from May 1):
          // It checks May 1 to May 30. It finds May 15, spawns it, updates lastSpawnedDate to May 15.
          // In the second evaluation (from May 16 to June 19):
          // It checks May 16 to June 14 (30 days). No occurrence?
          // Wait, June 15 is on day 31, so it is NOT checked in the first 30 days after May 15!
          // So the second evaluation checks May 16 to June 14.
          // Since no occurrence is in that range, datesToSpawn is empty.
          // If it gets stuck, lastSpawnedDate stays May 15.
          // So it never checks June 15, and the June 15 task is never spawned!
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

          // First evaluate from null.
          // It starts checking at May 1, and runs for 30 days up to May 30.
          // It finds the May 15 occurrence and spawns it, and advances lastSpawnedDate to May 30 (the last checked date).
          final action1 = SchedulerEngine.evaluate(task, [], now);
          expect(action1.instancesToSpawn, hasLength(1));
          expect(
            action1.instancesToSpawn.first.scheduledDate,
            equals(CivilDay(year: 2026, month: 5, day: 15)),
          );
          expect(
            action1.updatedSchedule!.lastSpawnedDate,
            equals(CivilDay(year: 2026, month: 5, day: 30)),
          );

          // Second evaluate with the updated task from action1.
          // It starts checking at May 31 and runs up to today (June 19) - a span of 20 days.
          // It finds the June 15 occurrence and spawns it, and advances lastSpawnedDate to June 19 (today).
          final updatedTask1 = action1.updatedSchedule!;
          final action2 = SchedulerEngine.evaluate(updatedTask1, [], now);

          expect(action2.instancesToSpawn, hasLength(1));
          expect(
            action2.instancesToSpawn.first.scheduledDate,
            equals(CivilDay(year: 2026, month: 6, day: 15)),
          );
          expect(action2.updatedSchedule, isNotNull);
          expect(
            action2.updatedSchedule!.lastSpawnedDate,
            equals(CivilDay(year: 2026, month: 6, day: 19)),
          );
        },
      );
    });
  });
}
