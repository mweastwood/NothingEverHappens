import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/calendar_day_task.dart';
import 'package:nothing_ever_happens/logic/calendar_timeline_layout_engine.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';

void main() {
  const testDay = CivilDay(year: 2026, month: 6, day: 15);

  TaskInstance makeInstance({
    required String id,
    required RelativeTime start,
    required RelativeTime due,
    TaskPriority priority = TaskPriority.medium,
  }) {
    return TaskInstance(
      id: id,
      scheduleId: 'S-$id',
      ruleId: 'R-$id',
      title: 'Task $id',
      description: '',
      scheduledDate: testDay,
      startRelativeTime: start,
      dueRelativeTime: due,
      priority: priority,
    );
  }

  group('CalendarTimelineLayoutEngine time helpers', () {
    test(
      'extracts start, due, and duration from TaskInstance and schedule',
      () {
        final inst = makeInstance(
          id: '1',
          start: const RelativeTime(dayOffset: 0, hour: 9, minute: 15),
          due: const RelativeTime(dayOffset: 0, hour: 11, minute: 30),
        );
        final sched = TaskSchedule(
          id: 'S-1',
          title: 'Task 1',
          description: '',
          estimatedDuration: const Duration(minutes: 45),
        );
        final task = CalendarDayTask(
          id: '1',
          title: 'Task 1',
          priority: TaskPriority.medium,
          isInstance: true,
          instance: inst,
          schedule: sched,
        );

        expect(CalendarTimelineLayoutEngine.getStartMinute(task), 9 * 60 + 15);
        expect(CalendarTimelineLayoutEngine.getDueMinute(task), 11 * 60 + 30);
        expect(
          CalendarTimelineLayoutEngine.getEstimatedDurationMinutes(task),
          45,
        );
      },
    );

    test('clamps dayOffset < 0 and > 0 for start and due minutes', () {
      final rule = DailySchedule(
        id: 'R-1',
        scheduleId: 'S-1',
        startDate: testDay,
        interval: 1,
        startRelativeTime: const RelativeTime(
          dayOffset: -1,
          hour: 22,
          minute: 0,
        ),
        dueRelativeTime: const RelativeTime(dayOffset: 1, hour: 2, minute: 0),
      );
      final task = CalendarDayTask(
        id: 'proj-1',
        title: 'Projected',
        priority: TaskPriority.low,
        isInstance: false,
        matchingRule: rule,
      );

      expect(CalendarTimelineLayoutEngine.getStartMinute(task), 0);
      expect(CalendarTimelineLayoutEngine.getDueMinute(task), 1440);
      expect(
        CalendarTimelineLayoutEngine.getEstimatedDurationMinutes(task),
        30,
      );
    });

    test(
      'falls back to defaults when neither instance nor rule is present',
      () {
        const task = CalendarDayTask(
          id: 'bare',
          title: 'Bare Task',
          priority: TaskPriority.medium,
          isInstance: false,
        );

        expect(CalendarTimelineLayoutEngine.getStartMinute(task), 9 * 60);
        expect(CalendarTimelineLayoutEngine.getDueMinute(task), 10 * 60);
        expect(
          CalendarTimelineLayoutEngine.getEstimatedDurationMinutes(task),
          30,
        );
      },
    );
  });

  group('CalendarTimelineLayoutEngine.layoutTasks', () {
    test('returns empty list when given no tasks', () {
      expect(
        CalendarTimelineLayoutEngine.layoutTasks(const [], 300.0),
        isEmpty,
      );
    });

    test('lays out non-overlapping tasks in a single full-width column', () {
      final t1 = CalendarDayTask(
        id: '1',
        title: 'Morning',
        priority: TaskPriority.high,
        isInstance: true,
        instance: makeInstance(
          id: '1',
          start: const RelativeTime(dayOffset: 0, hour: 8, minute: 0),
          due: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
        ),
      );
      final t2 = CalendarDayTask(
        id: '2',
        title: 'Afternoon',
        priority: TaskPriority.medium,
        isInstance: true,
        instance: makeInstance(
          id: '2',
          start: const RelativeTime(dayOffset: 0, hour: 14, minute: 0),
          due: const RelativeTime(dayOffset: 0, hour: 15, minute: 0),
        ),
      );

      final items = CalendarTimelineLayoutEngine.layoutTasks([t1, t2], 204.0);
      expect(items, hasLength(2));

      expect(items[0].task.id, '1');
      expect(items[0].columnIndex, 0);
      expect(items[0].totalColumns, 1);
      expect(items[0].left, 2.0);
      expect(items[0].width, 198.0);
      expect(items[0].top, 8 * 60.0);
      expect(items[0].height, 30.0);

      expect(items[1].task.id, '2');
      expect(items[1].columnIndex, 0);
      expect(items[1].totalColumns, 1);
      expect(items[1].left, 2.0);
      expect(items[1].width, 198.0);
      expect(items[1].top, 14 * 60.0);
      expect(items[1].height, 30.0);
    });

    test(
      'packs overlapping cluster into greedy columns and reuses freed columns',
      () {
        // Task A: 9:00 - 10:00 (duration 60, due 10:00)
        // Task B: 9:00 - 9:30 (duration 30, due 9:30)
        // Task C: 9:30 - 10:00 (duration 30, due 10:00)
        // A and B overlap at 9:00 -> 2 columns.
        // C starts at 9:30 when B ends -> reuses B's column, so totalColumns stays 2.
        final sched60 = TaskSchedule(
          id: 'S-A',
          title: 'A',
          description: '',
          estimatedDuration: const Duration(minutes: 60),
        );
        final taskA = CalendarDayTask(
          id: 'A',
          title: 'A',
          priority: TaskPriority.high,
          isInstance: true,
          schedule: sched60,
          instance: makeInstance(
            id: 'A',
            start: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
            due: const RelativeTime(dayOffset: 0, hour: 10, minute: 0),
            priority: TaskPriority.high,
          ),
        );
        final taskB = CalendarDayTask(
          id: 'B',
          title: 'B',
          priority: TaskPriority.medium,
          isInstance: true,
          instance: makeInstance(
            id: 'B',
            start: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
            due: const RelativeTime(dayOffset: 0, hour: 9, minute: 30),
          ),
        );
        final taskC = CalendarDayTask(
          id: 'C',
          title: 'C',
          priority: TaskPriority.low,
          isInstance: true,
          instance: makeInstance(
            id: 'C',
            start: const RelativeTime(dayOffset: 0, hour: 9, minute: 30),
            due: const RelativeTime(dayOffset: 0, hour: 10, minute: 0),
          ),
        );

        final items = CalendarTimelineLayoutEngine.layoutTasks([
          taskA,
          taskB,
          taskC,
        ], 204.0);
        expect(items, hasLength(3));
        for (final item in items) {
          expect(item.totalColumns, 2);
          expect(item.width, 98.0);
        }

        final itemA = items.firstWhere((i) => i.task.id == 'A');
        final itemB = items.firstWhere((i) => i.task.id == 'B');
        final itemC = items.firstWhere((i) => i.task.id == 'C');

        expect(itemA.columnIndex, isNot(equals(itemB.columnIndex)));
        expect(itemC.columnIndex, equals(itemB.columnIndex));
      },
    );
  });
}
