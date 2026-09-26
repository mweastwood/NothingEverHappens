import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/calendar_day_task.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/timeline_placement_calculator.dart';

void main() {
  group('TimelinePlacementCalculator.computePlacements', () {
    test('returns empty list when tasks is empty', () {
      final placements = TimelinePlacementCalculator.computePlacements(
        [],
        getStartMinute: (_) => 0,
        getDueMinute: (_) => 60,
        getDurationMinutes: (_) => 30,
      );

      expect(placements, isEmpty);
    });

    test(
      'tasks appear at start time and extend for estimated duration when no overlap',
      () {
        final task1 = CalendarDayTask(
          id: 'T1',
          title: 'Task 1',
          priority: TaskPriority.high,
          isInstance: true,
        );
        final task2 = CalendarDayTask(
          id: 'T2',
          title: 'Task 2',
          priority: TaskPriority.medium,
          isInstance: true,
        );

        final placements = TimelinePlacementCalculator.computePlacements(
          [task1, task2],
          getStartMinute: (t) => t.id == 'T1' ? 9 * 60 : 11 * 60,
          getDueMinute: (t) => t.id == 'T1' ? 12 * 60 : 14 * 60,
          getDurationMinutes: (t) => 45,
        );

        expect(placements.length, 2);
        final p1 = placements.firstWhere((p) => p.task.id == 'T1');
        final p2 = placements.firstWhere((p) => p.task.id == 'T2');

        expect(p1.placedStart, 9 * 60);
        expect(p1.placedEnd, 9 * 60 + 45);

        expect(p2.placedStart, 11 * 60);
        expect(p2.placedEnd, 11 * 60 + 45);
      },
    );

    test(
      'pushes task further down to prevent overlap when it does not exceed due date',
      () {
        // Both start at 9:00, duration 30 min.
        // Task 1 due 10:00, Task 2 due 11:00.
        final task1 = CalendarDayTask(
          id: 'T1',
          title: 'Task 1',
          priority: TaskPriority.high,
          isInstance: true,
        );
        final task2 = CalendarDayTask(
          id: 'T2',
          title: 'Task 2',
          priority: TaskPriority.medium,
          isInstance: true,
        );

        final placements = TimelinePlacementCalculator.computePlacements(
          [task1, task2],
          getStartMinute: (_) => 9 * 60,
          getDueMinute: (t) => t.id == 'T1' ? 10 * 60 : 11 * 60,
          getDurationMinutes: (_) => 30,
        );

        expect(placements.length, 2);
        final p1 = placements.firstWhere((p) => p.task.id == 'T1');
        final p2 = placements.firstWhere((p) => p.task.id == 'T2');

        // T1 stays at 9:00 - 9:30
        expect(p1.placedStart, 9 * 60);
        expect(p1.placedEnd, 9 * 60 + 30);

        // T2 pushed to 9:30 - 10:00 (preventing overlap, within due date 11:00)
        expect(p2.placedStart, 9 * 60 + 30);
        expect(p2.placedEnd, 10 * 60);
        expect(p2.placedEnd, lessThanOrEqualTo(11 * 60));
      },
    );

    test(
      'overlap occurs only when absolutely necessary (pushing down would extend past due date)',
      () {
        // Both start at 9:00, duration 30 min, but BOTH are due at 9:30!
        final task1 = CalendarDayTask(
          id: 'T1',
          title: 'Task 1',
          priority: TaskPriority.high,
          isInstance: true,
        );
        final task2 = CalendarDayTask(
          id: 'T2',
          title: 'Task 2',
          priority: TaskPriority.medium,
          isInstance: true,
        );

        final placements = TimelinePlacementCalculator.computePlacements(
          [task1, task2],
          getStartMinute: (_) => 9 * 60,
          getDueMinute: (_) => 9 * 60 + 30,
          getDurationMinutes: (_) => 30,
        );

        expect(placements.length, 2);
        final p1 = placements.firstWhere((p) => p.task.id == 'T1');
        final p2 = placements.firstWhere((p) => p.task.id == 'T2');

        // T2 cannot be pushed past 9:30 without exceeding due date, so it overlaps at 9:00
        expect(p1.placedStart, 9 * 60);
        expect(p1.placedEnd, 9 * 60 + 30);
        expect(p2.placedStart, 9 * 60);
        expect(p2.placedEnd, 9 * 60 + 30);
      },
    );

    test(
      'prioritizes task with tighter deadline when determining which task stays earlier',
      () {
        // T_tight: start 9:00, due 9:30, duration 30.
        // T_flexible: start 9:00, due 12:00, duration 30.
        final tightTask = CalendarDayTask(
          id: 'T_tight',
          title: 'Tight Task',
          priority: TaskPriority.low,
          isInstance: true,
        );
        final flexTask = CalendarDayTask(
          id: 'T_flex',
          title: 'Flexible Task',
          priority: TaskPriority.high,
          isInstance: true,
        );

        final placements = TimelinePlacementCalculator.computePlacements(
          [flexTask, tightTask],
          getStartMinute: (_) => 9 * 60,
          getDueMinute: (t) => t.id == 'T_tight' ? 9 * 60 + 30 : 12 * 60,
          getDurationMinutes: (_) => 30,
        );

        final pTight = placements.firstWhere((p) => p.task.id == 'T_tight');
        final pFlex = placements.firstWhere((p) => p.task.id == 'T_flex');

        // T_tight gets 9:00-9:30 so it doesn't violate deadline, T_flex pushed to 9:30-10:00
        expect(pTight.placedStart, 9 * 60);
        expect(pTight.placedEnd, 9 * 60 + 30);

        expect(pFlex.placedStart, 9 * 60 + 30);
        expect(pFlex.placedEnd, 10 * 60);
      },
    );

    test('clamps boundary values at 0 and 1440 minutes', () {
      final taskEarly = CalendarDayTask(
        id: 'T_early',
        title: 'Early Task',
        priority: TaskPriority.low,
        isInstance: true,
      );
      final taskLate = CalendarDayTask(
        id: 'T_late',
        title: 'Late Task',
        priority: TaskPriority.high,
        isInstance: true,
      );

      final placements = TimelinePlacementCalculator.computePlacements(
        [taskEarly, taskLate],
        getStartMinute: (t) => t.id == 'T_early' ? -50 : 1430,
        getDueMinute: (t) => t.id == 'T_early' ? 100 : 1500,
        getDurationMinutes: (t) => t.id == 'T_early' ? 60 : 30,
      );

      final pEarly = placements.firstWhere((p) => p.task.id == 'T_early');
      final pLate = placements.firstWhere((p) => p.task.id == 'T_late');

      expect(pEarly.placedStart, greaterThanOrEqualTo(0));
      expect(pLate.placedEnd, lessThanOrEqualTo(1440));
    });

    test('adjusts dueMinute when dueMinute <= startMinute', () {
      final task = CalendarDayTask(
        id: 'T1',
        title: 'Task With Invalid Due',
        priority: TaskPriority.medium,
        isInstance: true,
      );

      final placements = TimelinePlacementCalculator.computePlacements(
        [task],
        getStartMinute: (_) => 600,
        getDueMinute: (_) => 500, // due before start
        getDurationMinutes: (_) => 20,
      );

      expect(placements.length, 1);
      final p = placements.first;
      expect(p.startMinute, 600);
      expect(p.dueMinute, 630); // clamped to start + 30
      expect(p.placedStart, 600);
      expect(p.placedEnd, 620);
    });
  });

  group('TaskTimePlacement', () {
    test('supports value equality and toString', () {
      final task = CalendarDayTask(
        id: 'T1',
        title: 'Task 1',
        priority: TaskPriority.high,
        isInstance: true,
      );
      final p1 = TaskTimePlacement(
        task: task,
        startMinute: 60,
        dueMinute: 120,
        duration: 30,
        placedStart: 60,
        placedEnd: 90,
      );
      final p2 = TaskTimePlacement(
        task: task,
        startMinute: 60,
        dueMinute: 120,
        duration: 30,
        placedStart: 60,
        placedEnd: 90,
      );
      expect(p1, equals(p2));
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1.toString(), contains('T1'));
    });
  });
}
