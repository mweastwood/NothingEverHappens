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
      test(
        'spawns all missing instances up to today and updates lastSpawnedDate',
        () {
          final startDate = today.addDays(-3); // 3 days ago (June 16)
          final task = TaskSchedule(
            id: 'stack-1',
            title: 'Stack Task',
            description: 'Piles up',
            schedules: [
              DailySchedule(
                startDate: startDate,
                interval: 1,
                missedOccurrencePolicy: const MissedOccurrencePolicy.keepAround(
                  legacyPolicy: MissedPolicy.stack,
                ),
              ),
            ],
          );

          final action = SchedulerEngine.evaluate(task, [], now);

          // Should spawn 4 instances: June 16, 17, 18, 19
          expect(action.instancesToSpawn, hasLength(4));
          expect(action.instancesToSpawn[0].scheduledDate.day, 16);
          expect(action.instancesToSpawn[1].scheduledDate.day, 17);
          expect(action.instancesToSpawn[2].scheduledDate.day, 18);
          expect(action.instancesToSpawn[3].scheduledDate.day, 19);

          expect(action.updatedSchedule, isNotNull);
          expect(action.updatedSchedule!.lastSpawnedDate, today);
        },
      );

      test('does not spawn duplicates if lastSpawnedDate is today', () {
        final startDate = today.addDays(-3);
        final task = TaskSchedule(
          id: 'stack-1',
          title: 'Stack Task',
          description: 'Piles up',
          lastSpawnedDate: today,
          schedules: [
            DailySchedule(
              startDate: startDate,
              interval: 1,
              missedOccurrencePolicy: const MissedOccurrencePolicy.keepAround(
                legacyPolicy: MissedPolicy.stack,
              ),
            ),
          ],
        );

        final action = SchedulerEngine.evaluate(task, [], now);

        expect(action.instancesToSpawn, isEmpty);
        expect(action.updatedSchedule, null);
      });
    });

    group('FixedCalendarPolicy - Rollover', () {
      test(
        'does not spawn next instance if there is already a pending instance',
        () {
          final yesterday = today.addDays(-1);
          final task = TaskSchedule(
            id: 'rollover-1',
            title: 'Rollover Task',
            description: 'Single pending only',
            schedules: [
              DailySchedule(
                startDate: yesterday,
                interval: 1,
                missedOccurrencePolicy: const MissedOccurrencePolicy.keepAround(
                  legacyPolicy: MissedPolicy.rollover,
                ),
              ),
            ],
          );

          final existingPending = TaskInstance(
            id: 'rollover-1_2026-06-18_0',
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

          expect(action.instancesToSpawn, isEmpty);
          expect(action.instancesToUpdate, isEmpty);
        },
      );

      test('spawns new instance if no pending instance exists', () {
        final task = TaskSchedule(
          id: 'rollover-1',
          title: 'Rollover Task',
          description: 'Single pending only',
          schedules: [
            DailySchedule(
              startDate: today,
              interval: 1,
              missedOccurrencePolicy: const MissedOccurrencePolicy.keepAround(
                legacyPolicy: MissedPolicy.rollover,
              ),
            ),
          ],
        );

        final action = SchedulerEngine.evaluate(task, [], now);

        expect(action.instancesToSpawn, hasLength(1));
        expect(action.instancesToSpawn.first.scheduledDate, today);
      });
    });

    group('FixedCalendarPolicy - Shift', () {
      test('does not spawn next instance if pending exists', () {
        final yesterday = today.addDays(-1);
        final task = TaskSchedule(
          id: 'shift-1',
          title: 'Shift Task',
          description: 'Shift target',
          schedules: [
            DailySchedule(
              startDate: yesterday,
              interval: 1,
              missedOccurrencePolicy: const MissedOccurrencePolicy.keepAround(
                legacyPolicy: MissedPolicy.shift,
              ),
            ),
          ],
        );

        final existingPending = TaskInstance(
          id: 'shift-1_2026-06-18_0',
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

        expect(action.instancesToSpawn, isEmpty);
      });
    });

    group('FixedCalendarPolicy - Auto-Dismiss', () {
      test(
        'auto-dismisses expired pending instance, backfills skipped gap, and spawns active next',
        () {
          // Due yesterday at 12:00 PM. Grace period is 2 hours. Expiration was yesterday at 2:00 PM.
          // Today is June 19, 10:00 AM, so yesterday's instance is way expired.
          final yesterday = today.addDays(-1);
          final task = TaskSchedule(
            id: 'autodismiss-1',
            title: 'Auto Dismiss Task',
            description: 'Dismisses missed',
            schedules: [
              DailySchedule(
                startDate: yesterday,
                interval: 1,
                missedOccurrencePolicy:
                    const MissedOccurrencePolicy.autoDismiss(
                      gracePeriod: Duration(hours: 2),
                    ),
                dueRelativeTime: const RelativeTime(
                  dayOffset: 0,
                  time: TimeOfDay(hour: 12, minute: 0),
                ),
              ),
            ],
          );

          final yesterdayPending = TaskInstance(
            id: 'autodismiss-1_2026-06-18_0',
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

          final action = SchedulerEngine.evaluate(task, [
            yesterdayPending,
          ], now);

          // Yesterday's instance should be skipped
          expect(action.instancesToUpdate, hasLength(1));
          expect(action.instancesToUpdate.first.status, 'skipped');

          // Should spawn today's instance as pending
          expect(action.instancesToSpawn, hasLength(1));
          expect(action.instancesToSpawn.first.scheduledDate, today);
          expect(action.instancesToSpawn.first.status, 'pending');
        },
      );

      test('does not dismiss pending instance within grace period', () {
        // Due today at 9:00 AM. Grace period is 2 hours (expires 11:00 AM).
        // Current time is 10:00 AM. Should stay pending.
        final task = TaskSchedule(
          id: 'autodismiss-2',
          title: 'Auto Dismiss Task',
          description: 'Within grace',
          schedules: [
            DailySchedule(
              startDate: today,
              interval: 1,
              missedOccurrencePolicy: const MissedOccurrencePolicy.autoDismiss(
                gracePeriod: Duration(hours: 2),
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 9, minute: 0),
              ),
            ),
          ],
        );

        final todayPending = TaskInstance(
          id: 'autodismiss-2_2026-06-19_0',
          scheduleId: task.id,
          title: task.title,
          description: task.description,
          scheduledDate: today,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 7, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          status: 'pending',
        );

        final action = SchedulerEngine.evaluate(task, [todayPending], now);

        expect(action.instancesToUpdate, isEmpty);
        expect(action.instancesToSpawn, isEmpty);
      });
    });

    group('CompletionRelativePolicy', () {
      test('spawns at rule date initially when no instances exist', () {
        final task = TaskSchedule(
          id: 'relative-1',
          title: 'Relative Task',
          description: 'Completion based',
          schedules: [
            DailySchedule(
              startDate: today,
              interval: 1,
              schedulingPolicy: const CompletionRelativePolicy(
                interval: Duration(days: 3),
                targetTime: TimeOfDay(hour: 9, minute: 0),
              ),
            ),
          ],
        );

        final action = SchedulerEngine.evaluate(task, [], now);

        expect(action.instancesToSpawn, hasLength(1));
        expect(action.instancesToSpawn.first.scheduledDate, today);
      });

      test('spawns new instance when interval completed threshold passed', () {
        // Completed 3 days ago (June 16) at 9:00 AM.
        // Today is June 19 at 10:00 AM, so 3 days have elapsed.
        final completedDate = today.addDays(-3);
        final task = TaskSchedule(
          id: 'relative-2',
          title: 'Relative Task',
          description: 'Completion based',
          schedules: [
            DailySchedule(
              startDate: completedDate,
              interval: 1,
              schedulingPolicy: const CompletionRelativePolicy(
                interval: Duration(days: 3),
                targetTime: TimeOfDay(hour: 9, minute: 0),
              ),
            ),
          ],
        );

        final completedInstance = TaskInstance(
          id: 'relative-2_2026-06-16_0',
          scheduleId: task.id,
          title: task.title,
          description: task.description,
          scheduledDate: completedDate,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 7, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 12, minute: 0),
          ),
          status: 'completed',
          completedAt: DateTime(2026, 6, 16, 9, 0),
        );

        final action = SchedulerEngine.evaluate(task, [completedInstance], now);

        expect(action.instancesToSpawn, hasLength(1));
        // Spawn date should be completedDate + 3 days interval = today
        expect(action.instancesToSpawn.first.scheduledDate, today);
      });

      test(
        'does not spawn next instance when interval completed threshold not yet passed',
        () {
          // Completed 2 days ago (June 17) at 9:00 AM.
          // Interval is 3 days, so threshold is June 20 at 9:00 AM.
          // Today is June 19.
          final completedDate = today.addDays(-2);
          final task = TaskSchedule(
            id: 'relative-3',
            title: 'Relative Task',
            description: 'Completion based',
            schedules: [
              DailySchedule(
                startDate: completedDate,
                interval: 1,
                schedulingPolicy: const CompletionRelativePolicy(
                  interval: Duration(days: 3),
                  targetTime: TimeOfDay(hour: 9, minute: 0),
                ),
              ),
            ],
          );

          final completedInstance = TaskInstance(
            id: 'relative-3_2026-06-17_0',
            scheduleId: task.id,
            title: task.title,
            description: task.description,
            scheduledDate: completedDate,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 7, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 12, minute: 0),
            ),
            status: 'completed',
            completedAt: DateTime(2026, 6, 17, 9, 0),
          );

          final action = SchedulerEngine.evaluate(task, [
            completedInstance,
          ], now);

          expect(action.instancesToSpawn, isEmpty);
        },
      );
    });

    group('Spawning on completion/undo calculations', () {
      test(
        'spawns completion relative next instance and calculates delete ID correctly',
        () {
          final completedDate = today;
          final task = TaskSchedule(
            id: 'relative-spawn',
            title: 'Relative Task',
            description: 'Spawning next test',
            schedules: [
              DailySchedule(
                startDate: completedDate,
                interval: 1,
                schedulingPolicy: const CompletionRelativePolicy(
                  interval: Duration(days: 3),
                  targetTime: TimeOfDay(hour: 10, minute: 0),
                ),
                dueRelativeTime: const RelativeTime(
                  dayOffset: 0,
                  time: TimeOfDay(hour: 18, minute: 0),
                ),
              ),
            ],
          );

          final completedInstance = TaskInstance(
            id: 'relative-spawn_2026-06-19_0',
            scheduleId: task.id,
            title: task.title,
            description: task.description,
            scheduledDate: completedDate,
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
          expect(nextInst!.scheduledDate, today.addDays(3));
          expect(nextInst.id, 'relative-spawn_2026-06-22');
          expect(nextInst.status, 'pending');

          final deleteId = SchedulerEngine.getNextOccurrenceIdToDelete(
            task,
            completedInstance,
            DateTime(2026, 6, 19, 14, 0),
          );
          expect(deleteId, 'relative-spawn_2026-06-22');
        },
      );

      test('spawns calendar-fixed rollover next instance correctly', () {
        final yesterday = today.addDays(-1);
        final task = TaskSchedule(
          id: 'fixed-spawn',
          title: 'Fixed Task',
          description: 'Calendar fixed test',
          schedules: [
            DailySchedule(
              startDate: yesterday,
              interval: 1,
              missedOccurrencePolicy: const MissedOccurrencePolicy.keepAround(
                legacyPolicy: MissedPolicy.rollover,
              ),
            ),
          ],
        );

        final completedInstance = TaskInstance(
          id: 'fixed-spawn_2026-06-18_0',
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
          status: 'completed',
          completedAt: now,
        );

        final nextInst = SchedulerEngine.getNextOccurrenceToSpawn(
          task,
          completedInstance,
          now,
        );
        expect(nextInst, isNotNull);
        expect(nextInst!.scheduledDate, today);
        expect(nextInst.id, 'fixed-spawn_2026-06-19');
        expect(nextInst.status, 'pending');

        final deleteId = SchedulerEngine.getNextOccurrenceIdToDelete(
          task,
          completedInstance,
          now,
        );
        expect(deleteId, 'fixed-spawn_2026-06-19');
      });
    });
  });
}
