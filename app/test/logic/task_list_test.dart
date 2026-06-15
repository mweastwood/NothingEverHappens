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
      final nextState = TaskList([testTask]).delete('task-1');

      expect(nextState.activeTasks, isEmpty);
    });

    test('complete removes task', () {
      final nextState = TaskList([testTask]).complete('task-1');

      expect(nextState.activeTasks, isEmpty);
    });

    test(
      'complete of recurring task advances its schedule rather than removing it',
      () {
        AppClock.setMockTime(DateTime(2026, 3, 8, 9, 0));
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

        final nextState = TaskList([recurringTask]).complete('task-recur');

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

        AppClock.reset();
      },
    );

    test(
      'complete of weekly task on non-occurrence day before its occurrence does not advance it',
      () {
        // Tuesday, March 3, 2026
        AppClock.setMockTime(DateTime(2026, 3, 3, 9, 0));

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

        final nextState = TaskList([weeklyTask]).complete('task-weekly');

        // It should NOT be advanced because Wednesday (March 4) has not occurred yet.
        expect(nextState.activeTasks.length, 1);
        final updatedTask = nextState.activeTasks.first;
        final newSchedule = updatedTask.schedules.first as WeeklySchedule;
        expect(
          newSchedule.startDate,
          const CivilDay(year: 2026, month: 3, day: 2),
        );

        AppClock.reset();
      },
    );

    test(
      'complete of stack recurring task advances relative to s.scheduledDate instead of today',
      () {
        // Wednesday, June 3, 2026
        AppClock.setMockTime(DateTime(2026, 6, 3, 9, 0));

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

        final nextState = TaskList([stackTask]).complete('task-stack');

        expect(nextState.activeTasks.length, 1);
        final updatedTask = nextState.activeTasks.first;
        final newSchedule = updatedTask.schedules.first as DailySchedule;

        // Since it is stack policy, completing it on June 3 reschedules it relative to Monday June 1 -> Tuesday June 2.
        expect(
          newSchedule.startDate,
          const CivilDay(year: 2026, month: 6, day: 2),
        );

        AppClock.reset();
      },
    );
  });
}
