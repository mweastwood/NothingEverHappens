import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/logic/task_list.dart';
import 'package:nothing_ever_happens/logic/task.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';

void main() {
  group('TaskList', () {
    const userId = 'test-user-id';
    final testTask = Task(
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

    test('add generates a "create" delta and updates list', () {
      final nextState = const TaskList([]).add(testTask, userId);

      expect(nextState.activeTasks, [testTask]);

      final delta = nextState.history.last;
      expect(delta.operation, 'create');
      expect(delta.taskId, testTask.id);
      expect(delta.userId, userId);
      expect(delta.changedFields['title'], testTask.title);
      expect(delta.expiresAt.difference(delta.timestamp).inDays, 90);
    });

    test('delete generates a "delete" delta and removes task', () {
      final nextState = TaskList([testTask]).delete('task-1', userId);

      expect(nextState.activeTasks, isEmpty);

      final delta = nextState.history.last;
      expect(delta.operation, 'delete');
      expect(delta.taskId, 'task-1');
      expect(delta.userId, userId);
      expect(delta.changedFields, isEmpty);
    });

    test('complete generates a "complete" delta and removes task', () {
      final nextState = TaskList([testTask]).complete('task-1', userId);

      expect(nextState.activeTasks, isEmpty);

      final delta = nextState.history.last;
      expect(delta.operation, 'complete');
      expect(delta.taskId, 'task-1');
      expect(delta.userId, userId);
      expect(delta.changedFields, isEmpty);
    });

    test(
      'complete of recurring task advances its schedule rather than removing it',
      () {
        AppClock.setMockTime(DateTime(2026, 3, 8, 9, 0));
        final recurringTask = Task(
          id: 'task-recur',
          title: 'Daily Task',
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

        final nextState = TaskList([
          recurringTask,
        ]).complete('task-recur', userId);

        // It should NOT be removed!
        expect(nextState.activeTasks.length, 1);
        final updatedTask = nextState.activeTasks.first;
        expect(updatedTask.id, 'task-recur');

        // The new start date of the schedule should be advanced to the next occurrence
        final newSchedule = updatedTask.schedules.first as DailySchedule;
        expect(
          newSchedule.startDate,
          const CivilDay(year: 2026, month: 3, day: 10),
        );

        final delta = nextState.history.last;
        expect(delta.operation, 'complete');
        expect(delta.taskId, 'task-recur');
        expect(delta.userId, userId);

        AppClock.reset();
      },
    );
  });

  group('TaskDelta', () {
    // Implicitly tested via TaskList.
  });
}
