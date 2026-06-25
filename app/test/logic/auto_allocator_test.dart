import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/auto_allocator.dart';

void main() {
  group('AutoAllocator Unit Tests', () {
    test(
      'allocates tasks respecting capacity limits and prioritizing high priority',
      () {
        final task1 = TaskSchedule(
          id: 'S-t1',
          title: 'TaskSchedule 1',
          description: '',
          schedules: [
            OneOffSchedule(
              id: 'R-t1',
              scheduleId: 'S-t1',
              date: const CivilDay(year: 2026, month: 6, day: 1),
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
          estimatedDuration: const Duration(minutes: 60),
          priority: TaskPriority.high,
        );

        final task2 = TaskSchedule(
          id: 'S-t2',
          title: 'TaskSchedule 2',
          description: '',
          schedules: [
            OneOffSchedule(
              id: 'R-t2',
              scheduleId: 'S-t2',
              date: const CivilDay(year: 2026, month: 6, day: 1),
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
          estimatedDuration: const Duration(minutes: 60),
          priority: TaskPriority.low,
        );

        final assignments = AutoAllocator.allocate(
          userIds: ['alice', 'bob'],
          userWeeklyCapacities: {
            'alice': 90.0, // 90 mins capacity
            'bob': 30.0, // 30 mins capacity
          },
          userPersonalEfforts: {'alice': 0.0, 'bob': 0.0},
          familyTasks: [task2, task1], // Shuffle input order
        );

        // task1 (high priority, 60m) should go to alice because bob (30m) doesn't have capacity.
        expect(assignments['S-t1'], 'alice');
        // task2 (low priority, 60m) should not be allocated to bob (30m cap) either.
        // Can it be allocated to alice? Alice has 90m capacity, task1 took 60m, leaving 30m.
        // task2 requires 60m, so it cannot be allocated to alice either.
        expect(assignments.containsKey('S-t2'), isFalse);
      },
    );

    test('prefers users who starred the task', () {
      final task = TaskSchedule(
        id: 'S-t1',
        title: 'Clean living room',
        description: '',
        schedules: [
          OneOffSchedule(
            id: 'R-t1',
            scheduleId: 'S-t1',
            date: const CivilDay(year: 2026, month: 6, day: 1),
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
        estimatedDuration: const Duration(minutes: 30),
        priority: TaskPriority.medium,
        preferredBy: const {'bob': true},
      );

      final assignments = AutoAllocator.allocate(
        userIds: ['alice', 'bob'],
        userWeeklyCapacities: {'alice': 120.0, 'bob': 120.0},
        userPersonalEfforts: {'alice': 0.0, 'bob': 0.0},
        familyTasks: [task],
      );

      // Should be assigned to bob since he starred it, even though Alice and Bob have equal capacity.
      expect(assignments['S-t1'], 'bob');
    });

    test('subtracts personal task efforts from user capacities', () {
      final task = TaskSchedule(
        id: 'S-t1',
        title: 'Chore',
        description: '',
        schedules: [
          OneOffSchedule(
            id: 'R-t1',
            scheduleId: 'S-t1',
            date: const CivilDay(year: 2026, month: 6, day: 1),
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
        estimatedDuration: const Duration(minutes: 60),
        priority: TaskPriority.medium,
      );

      final assignments = AutoAllocator.allocate(
        userIds: ['alice', 'bob'],
        userWeeklyCapacities: {'alice': 120.0, 'bob': 120.0},
        userPersonalEfforts: {
          'alice':
              80.0, // Alice has 80 mins of personal tasks (120 - 80 = 40 mins remaining)
          'bob':
              20.0, // Bob has 20 mins of personal tasks (120 - 20 = 100 mins remaining)
        },
        familyTasks: [task],
      );

      // The task requires 60 mins. Alice only has 40 mins left, so it must go to Bob.
      expect(assignments['S-t1'], 'bob');
    });

    test('balances workload by capacity when no one starred', () {
      final task = TaskSchedule(
        id: 'S-t1',
        title: 'Chore',
        description: '',
        schedules: [
          OneOffSchedule(
            id: 'R-t1',
            scheduleId: 'S-t1',
            date: const CivilDay(year: 2026, month: 6, day: 1),
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
        estimatedDuration: const Duration(minutes: 30),
        priority: TaskPriority.medium,
      );

      final assignments = AutoAllocator.allocate(
        userIds: ['alice', 'bob'],
        userWeeklyCapacities: {
          'alice': 120.0, // Alice has more remaining capacity
          'bob': 60.0,
        },
        userPersonalEfforts: {'alice': 0.0, 'bob': 0.0},
        familyTasks: [task],
      );

      expect(assignments['S-t1'], 'alice');
    });
  });
}
