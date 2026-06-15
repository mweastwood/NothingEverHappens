import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_list.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';

void main() {
  group('Multiple Schedules & Standardized Timing Unit Tests', () {
    test('TaskSchedule can be constructed with multiple mixed schedules', () {
      final startCivil = const CivilDay(year: 2026, month: 6, day: 1);
      final schedules = [
        DailySchedule(
          startDate: startCivil,
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
        WeeklySchedule(
          startDate: startCivil,
          interval: 1,
          daysOfWeek: const {1, 5},
          startRelativeTime: const RelativeTime(
            dayOffset: -1,
            time: TimeOfDay(hour: 18, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 1,
            time: TimeOfDay(hour: 12, minute: 0),
          ),
          notificationRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 8, minute: 0),
          ),
        ),
      ];

      final task = TaskSchedule(
        id: 'mixed-task',
        title: 'Mixed Scheduling TaskSchedule',
        description: 'Testing mixed scheduling',
        schedules: schedules,
      );

      expect(task.schedules.length, 2);
      expect(task.schedules[0], isA<DailySchedule>());
      expect(task.schedules[1], isA<WeeklySchedule>());

      // Verify standardized timing properties inside each schedule
      expect(task.schedules[0].startRelativeTime.time.hour, 9);
      expect(task.schedules[0].dueRelativeTime.time.hour, 17);
      expect(task.schedules[0].dueRelativeTime.dayOffset, 0);

      expect(task.schedules[1].startRelativeTime.dayOffset, -1);
      expect(task.schedules[1].dueRelativeTime.dayOffset, 1);
      expect(task.schedules[1].dueRelativeTime.time.hour, 12);
      expect(task.schedules[1].notificationRelativeTime?.time.hour, 8);
    });

    test('TaskList.complete advances multiple repeating schedules correctly', () {
      final start = const CivilDay(year: 2026, month: 6, day: 1); // Monday

      final schedules = [
        DailySchedule(
          startDate: start,
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
        WeeklySchedule(
          startDate: start,
          interval: 1,
          daysOfWeek: const {1, 3}, // Monday, Wednesday
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 10, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 18, minute: 0),
          ),
        ),
      ];

      final task = TaskSchedule(
        id: 'complete-task',
        title: 'Mixed schedule complete',
        description: 'Complete test',
        schedules: schedules,
        missedPolicy: MissedPolicy.rollover,
      );

      final taskList = TaskList([task]);

      // Complete on Monday, June 1
      final monday = DateTime(2026, 6, 1, 12, 0);
      AppClock.setMockTime(monday);
      final nextState = taskList.complete('complete-task');

      final updatedTask = nextState.activeTasks.firstWhere(
        (t) => t.id == 'complete-task',
      );
      expect(updatedTask.schedules.length, 2);

      // Daily schedule should advance to Tuesday, June 2
      final daily = updatedTask.schedules[0] as DailySchedule;
      expect(daily.startDate, const CivilDay(year: 2026, month: 6, day: 2));

      // Weekly schedule should advance to Wednesday, June 3 (the next weekday occurrence)
      final weekly = updatedTask.schedules[1] as WeeklySchedule;
      expect(weekly.startDate, const CivilDay(year: 2026, month: 6, day: 3));

      AppClock.reset();
    });

    test(
      'TaskList.complete on mixed schedules removes completed one-off schedules and keeps future ones',
      () {
        final start = const CivilDay(year: 2026, month: 6, day: 1); // Monday
        final schedules = [
          OneOffSchedule(
            date: start, // June 1
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
          ),
          OneOffSchedule(
            date: const CivilDay(
              year: 2026,
              month: 6,
              day: 5,
            ), // June 5 (future)
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 10, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 18, minute: 0),
            ),
          ),
          DailySchedule(
            startDate: start,
            interval: 1,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 11, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 19, minute: 0),
            ),
          ),
        ];

        final task = TaskSchedule(
          id: 'mixed-oneoff-task',
          title: 'Mixed one-off complete',
          description: 'Complete test',
          schedules: schedules,
          missedPolicy: MissedPolicy.rollover,
        );

        final taskList = TaskList([task]);

        final monday = DateTime(2026, 6, 1, 12, 0);
        AppClock.setMockTime(monday);
        final nextState = taskList.complete('mixed-oneoff-task');

        final updatedTask = nextState.activeTasks.firstWhere(
          (t) => t.id == 'mixed-oneoff-task',
        );

        // The completed one-off schedule (June 1) should be removed.
        // The future one-off schedule (June 5) should remain.
        // The daily schedule should advance to June 2.
        expect(updatedTask.schedules.length, 2);
        expect(updatedTask.schedules[0], isA<OneOffSchedule>());
        expect(
          (updatedTask.schedules[0] as OneOffSchedule).date,
          const CivilDay(year: 2026, month: 6, day: 5),
        );
        expect(updatedTask.schedules[1], isA<DailySchedule>());
        expect(
          (updatedTask.schedules[1] as DailySchedule).startDate,
          const CivilDay(year: 2026, month: 6, day: 2),
        );

        AppClock.reset();
      },
    );

    test(
      'TaskList.complete on task with multiple one-off schedules on same date completes slot by slot',
      () {
        final start = const CivilDay(year: 2026, month: 6, day: 1); // Monday
        final schedules = [
          OneOffSchedule(
            date: start,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 10, minute: 0),
            ),
          ),
          OneOffSchedule(
            date: start,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 14, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 15, minute: 0),
            ),
          ),
        ];

        final task = TaskSchedule(
          id: 'multi-oneoff-slots',
          title: 'Multi one-off slots complete',
          description: 'Complete test',
          schedules: schedules,
        );

        final taskList = TaskList([task]);

        final monday = DateTime(2026, 6, 1, 12, 0);
        AppClock.setMockTime(monday);

        // Complete first slot
        var state = taskList.complete('multi-oneoff-slots');
        expect(state.activeTasks.length, 1);
        expect(state.activeTasks.first.activeOccurrenceIndex, 1);
        expect(
          state.activeTasks.first.schedules.length,
          2,
        ); // schedules list is unchanged during slot advance

        // Complete second (last) slot
        state = state.complete('multi-oneoff-slots');
        expect(
          state.activeTasks.length,
          0,
        ); // Removed since all one-offs are completed

        AppClock.reset();
      },
    );

    test(
      'TaskList.complete on task with multiple one-off schedules on different dates completes and removes task only when last is completed',
      () {
        final schedules = [
          OneOffSchedule(
            date: const CivilDay(year: 2026, month: 6, day: 1),
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 10, minute: 0),
            ),
          ),
          OneOffSchedule(
            date: const CivilDay(year: 2026, month: 6, day: 3),
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 14, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 15, minute: 0),
            ),
          ),
        ];

        final task = TaskSchedule(
          id: 'multi-oneoff-dates',
          title: 'Multi one-off dates complete',
          description: 'Complete test',
          schedules: schedules,
        );

        final taskList = TaskList([task]);

        // Complete on Monday, June 1
        final monday = DateTime(2026, 6, 1, 12, 0);
        AppClock.setMockTime(monday);
        var state = taskList.complete('multi-oneoff-dates');
        expect(state.activeTasks.length, 1);

        final updatedTask = state.activeTasks.first;
        expect(updatedTask.schedules.length, 1); // June 1 schedule removed
        expect(
          (updatedTask.schedules.first as OneOffSchedule).date,
          const CivilDay(year: 2026, month: 6, day: 3),
        );

        // Complete on Wednesday, June 3
        final wednesday = DateTime(2026, 6, 3, 16, 0);
        AppClock.setMockTime(wednesday);
        state = state.complete('multi-oneoff-dates');
        expect(
          state.activeTasks.length,
          0,
        ); // Removed since last one-off completed

        AppClock.reset();
      },
    );
  });
}
