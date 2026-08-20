import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/logic/task_list.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';

void main() {
  group('TaskList', () {
    final testTask = TaskSchedule(
      id: 'task-1',
      title: 'Original Title',
      description: 'Original Description',
      schedules: [
        OneOffSchedule(
          date: const CivilDay(year: 2024, month: 1, day: 1),
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

    test('add updates list', () {
      final nextState = const TaskList([]).add(testTask);

      expect(nextState.activeTasks, [testTask]);
    });

    test('delete removes task', () {
      final nextState = TaskList([testTask]).delete('S-task-1');

      expect(nextState.activeTasks, isEmpty);
    });

    test('complete removes task', () {
      final nextState = TaskList([testTask]).complete('S-task-1');

      expect(nextState.activeTasks, isEmpty);
    });

    test(
      'complete of recurring task advances its schedule rather than removing it',
      () {
        AppClock.setMockTime(DateTime(2026, 3, 8, 9, 0));
        addTearDown(AppClock.reset);
        final recurringTask = TaskSchedule(
          id: 'task-recur',
          title: 'Daily TaskSchedule',
          description: 'Test description',
          schedules: [
            DailySchedule(
              startDate: const CivilDay(year: 2026, month: 3, day: 8),
              interval: 2,
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

        final nextState = TaskList([recurringTask]).complete('S-task-recur');

        // It should NOT be removed!
        expect(nextState.activeTasks.length, 1);
        final updatedTask = nextState.activeTasks.first;
        expect(updatedTask.id, 'S-task-recur');

        // The new start date of the schedule should be advanced to the next occurrence
        final newSchedule = updatedTask.schedules.first as DailySchedule;
        expect(
          newSchedule.startDate,
          const CivilDay(year: 2026, month: 3, day: 10),
        );
      },
    );

    test(
      'complete of weekly task on non-occurrence day before its occurrence does not advance it',
      () {
        // Tuesday, March 3, 2026
        AppClock.setMockTime(DateTime(2026, 3, 3, 9, 0));
        addTearDown(AppClock.reset);

        final weeklyTask = TaskSchedule(
          id: 'task-weekly',
          title: 'Weekly TaskSchedule',
          description: 'Test description',
          schedules: [
            WeeklySchedule(
              startDate: const CivilDay(year: 2026, month: 3, day: 2), // Mon
              interval: 1,
              daysOfWeek: const {3}, // Wednesday only
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

        final nextState = TaskList([weeklyTask]).complete('S-task-weekly');

        // It should NOT be advanced because Wednesday (March 4) has not occurred yet.
        expect(nextState.activeTasks.length, 1);
        final updatedTask = nextState.activeTasks.first;
        final newSchedule = updatedTask.schedules.first as WeeklySchedule;
        expect(
          newSchedule.startDate,
          const CivilDay(year: 2026, month: 3, day: 2),
        );
      },
    );
    test(
      'complete of stack recurring task advances relative to today instead of s.scheduledDate',
      () {
        // Wednesday, June 3, 2026
        AppClock.setMockTime(DateTime(2026, 6, 3, 9, 0));
        addTearDown(AppClock.reset);

        final stackTask = TaskSchedule(
          id: 'task-stack',
          title: 'Stack TaskSchedule',
          description: 'Test description',
          missedPolicy: MissedPolicy.stack,
          schedules: [
            DailySchedule(
              startDate: const CivilDay(
                year: 2026,
                month: 6,
                day: 1,
              ), // Monday June 1
              interval: 1,
            ),
          ],
        );

        final nextState = TaskList([stackTask]).complete('S-task-stack');

        expect(nextState.activeTasks.length, 1);
        final updatedTask = nextState.activeTasks.first;
        final newSchedule = updatedTask.schedules.first as DailySchedule;

        // Reschedules relative to today (June 3) -> Thursday June 4
        expect(
          newSchedule.startDate,
          const CivilDay(year: 2026, month: 6, day: 4),
        );
      },
    );

    test(
      'complete of recurring task preserves all modern task metadata fields',
      () {
        AppClock.setMockTime(DateTime(2026, 3, 8, 9, 0));
        addTearDown(AppClock.reset);

        final recurringTask = TaskSchedule(
          id: 'task-recur-metadata',
          title: 'Daily Task with Metadata',
          description: 'Preserve me',
          estimatedDuration: const Duration(minutes: 45),
          isMaster: true,
          lastSpawnedDate: const CivilDay(year: 2026, month: 3, day: 7),
          parentTaskId: 'parent-123',
          isFamily: true,
          familyCompletionMode: FamilyCompletionMode.individual,
          priority: TaskPriority.high,
          cycleId: 'cycle-789',
          preferredBy: {'user-1': true, 'user-2': false},
          assignedUserId: 'user-1',
          appLaunchUrl: 'duolingo://',
          workflowType: 'mealWorkflow',
          mealWorkflowConfig: const MealWorkflowConfig(
            selectTime: RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 11, minute: 0),
            ),
            shopTime: RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 15, minute: 0),
            ),
            prepTime: RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 19, minute: 0),
            ),
          ),
          skipIfNoCapacity: true,
          schedules: [
            DailySchedule(
              startDate: const CivilDay(year: 2026, month: 3, day: 8),
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
        );

        final nextState = TaskList([
          recurringTask,
        ]).complete('S-task-recur-metadata');

        expect(nextState.activeTasks.length, 1);
        final updatedTask = nextState.activeTasks.first;

        expect(updatedTask.id, 'S-task-recur-metadata');
        expect(updatedTask.title, 'Daily Task with Metadata');
        expect(updatedTask.description, 'Preserve me');
        expect(updatedTask.estimatedDuration, const Duration(minutes: 45));
        expect(updatedTask.isMaster, true);
        expect(
          updatedTask.lastSpawnedDate,
          const CivilDay(year: 2026, month: 3, day: 7),
        );
        expect(updatedTask.parentTaskId, 'parent-123');
        expect(updatedTask.isFamily, true);
        expect(
          updatedTask.familyCompletionMode,
          FamilyCompletionMode.individual,
        );
        expect(updatedTask.priority, TaskPriority.high);
        expect(updatedTask.cycleId, 'cycle-789');
        expect(updatedTask.preferredBy, {'user-1': true, 'user-2': false});
        expect(updatedTask.assignedUserId, 'user-1');
        expect(updatedTask.appLaunchUrl, 'duolingo://');
        expect(updatedTask.workflowType, 'mealWorkflow');
        expect(updatedTask.mealWorkflowConfig, isNotNull);
        expect(
          updatedTask.mealWorkflowConfig?.selectTime,
          const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 11, minute: 0),
          ),
        );
        expect(
          updatedTask.mealWorkflowConfig?.shopTime,
          const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 15, minute: 0),
          ),
        );
        expect(
          updatedTask.mealWorkflowConfig?.prepTime,
          const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 19, minute: 0),
          ),
        );
        expect(updatedTask.skipIfNoCapacity, true);

        // Schedule was advanced to March 9
        final newSchedule = updatedTask.schedules.first as DailySchedule;
        expect(
          newSchedule.startDate,
          const CivilDay(year: 2026, month: 3, day: 9),
        );
      },
    );
  });
}
