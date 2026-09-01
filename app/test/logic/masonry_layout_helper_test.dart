import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/utils/masonry_layout_helper.dart';

void main() {
  group('estimateTaskInstanceHeight', () {
    test(
      'short single-line task has smaller height than tall multiline task',
      () {
        final shortTask = TaskInstance(
          id: '1',
          scheduleId: 'S-1',
          ruleId: 'R-1',
          title: 'Take pills',
          description: '',
          scheduledDate: const CivilDay(year: 2024, month: 1, day: 1),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 12, minute: 0),
          ),
          status: TaskStatus.pending,
        );

        final tallTask = TaskInstance(
          id: '2',
          scheduleId: 'S-2',
          ruleId: 'R-2',
          title: 'Clean out CPAP',
          description:
              'Dump and clean the water reservoir. Clean hose and mask. It needs time to dry so this has to be done in the morning.',
          scheduledDate: const CivilDay(year: 2024, month: 1, day: 1),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 12, minute: 0),
          ),
          status: TaskStatus.pending,
        );

        final shortHeight = estimateTaskInstanceHeight(shortTask);
        final tallHeight = estimateTaskInstanceHeight(tallTask);

        expect(shortHeight, lessThan(tallHeight));
      },
    );

    test('tasks with multiple badges have greater estimated height', () {
      final baseTask = TaskInstance(
        id: '1',
        scheduleId: 'S-1',
        ruleId: 'R-1',
        title: 'Clean Kitchen',
        description: '',
        scheduledDate: const CivilDay(year: 2024, month: 1, day: 1),
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        status: TaskStatus.pending,
      );

      final familyTaskWithBadges = TaskInstance(
        id: '2',
        scheduleId: 'S-2',
        ruleId: 'R-2',
        title: 'Clean Kitchen',
        description: '',
        scheduledDate: const CivilDay(year: 2024, month: 1, day: 1),
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        status: TaskStatus.pending,
        isFamily: true,
        familyCompletionMode: FamilyCompletionMode.individual,
        assignedUserId: 'user-1',
        priority: TaskPriority.high,
      );

      final baseHeight = estimateTaskInstanceHeight(baseTask);
      final badgeHeight = estimateTaskInstanceHeight(familyTaskWithBadges);

      expect(baseHeight, lessThan(badgeHeight));
    });

    test(
      'deterministic now parameter adds pending badge when before start time',
      () {
        final task = TaskInstance(
          id: '1',
          scheduleId: 'S-1',
          ruleId: 'R-1',
          title: 'Task with start time',
          description: '',
          scheduledDate: const CivilDay(year: 2024, month: 1, day: 1),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 14, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          status: TaskStatus.pending,
          priority: TaskPriority.high,
          isFamily: true,
        );

        final beforeStart = DateTime(2024, 1, 1, 10, 0);
        final afterStart = DateTime(2024, 1, 1, 15, 0);

        final heightBefore = estimateTaskInstanceHeight(
          task,
          null,
          beforeStart,
        );
        final heightAfter = estimateTaskInstanceHeight(task, null, afterStart);

        expect(heightBefore, greaterThan(heightAfter));
      },
    );
  });

  group('estimateTaskScheduleHeight', () {
    test('schedules with more rules and descriptions estimate taller', () {
      final simpleSchedule = TaskSchedule(
        id: 'S-1',
        title: 'Water Plants',
        description: '',
        schedules: [
          DailySchedule(
            id: 'R-1',
            scheduleId: 'S-1',
            startDate: const CivilDay(year: 2024, month: 1, day: 1),
            interval: 1,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 8, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
          ),
        ],
      );

      final complexSchedule = TaskSchedule(
        id: 'S-2',
        title: 'Vehicle Maintenance Inspection',
        description:
            '• Check tire pressure (35 psi)\n• Top up windshield washer fluid\n• Inspect engine oil level and filter\n• Test turn signals and brake lights',
        priority: TaskPriority.high,
        isFamily: true,
        assignedUserId: 'user-1',
        schedules: [
          DailySchedule(
            id: 'R-2A',
            scheduleId: 'S-2',
            startDate: const CivilDay(year: 2024, month: 1, day: 1),
            interval: 1,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 7, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 8, minute: 0),
            ),
          ),
          WeeklySchedule(
            id: 'R-2B',
            scheduleId: 'S-2',
            startDate: const CivilDay(year: 2024, month: 1, day: 1),
            interval: 2,
            daysOfWeek: {1, 4},
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 7, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 8, minute: 0),
            ),
          ),
        ],
      );

      final simpleHeight = estimateTaskScheduleHeight(simpleSchedule);
      final complexHeight = estimateTaskScheduleHeight(complexSchedule);

      expect(simpleHeight, lessThan(complexHeight));
    });
  });
}
