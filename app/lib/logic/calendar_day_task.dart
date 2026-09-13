import 'package:flutter/material.dart';

import 'app_clock.dart';
import 'civil_day.dart';
import 'task_instance.dart';
import 'task_schedule.dart';

/// Unified representation of a task scheduled for a specific day on the calendar.
class CalendarDayTask {
  final String id;
  final String title;
  final String description;
  final TaskPriority priority;
  final TaskStatus status;
  final bool isInstance;
  final TaskInstance? instance;
  final TaskSchedule? schedule;
  final TaskScheduleRule? matchingRule;
  final bool isCompleted;

  const CalendarDayTask({
    required this.id,
    required this.title,
    this.description = '',
    required this.priority,
    this.status = TaskStatus.pending,
    required this.isInstance,
    this.instance,
    this.schedule,
    this.matchingRule,
    bool? isCompleted,
  }) : isCompleted = isCompleted ?? (status == TaskStatus.completed);

  String? getTimeWindow(BuildContext context) {
    if (instance != null) {
      final startTod = TimeOfDay(
        hour: instance!.startRelativeTime.hour,
        minute: instance!.startRelativeTime.minute,
      );
      final dueTod = TimeOfDay(
        hour: instance!.dueRelativeTime.hour,
        minute: instance!.dueRelativeTime.minute,
      );
      return '${startTod.format(context)} – ${dueTod.format(context)}';
    } else if (matchingRule != null) {
      final startTod = TimeOfDay(
        hour: matchingRule!.startRelativeTime.hour,
        minute: matchingRule!.startRelativeTime.minute,
      );
      final dueTod = TimeOfDay(
        hour: matchingRule!.dueRelativeTime.hour,
        minute: matchingRule!.dueRelativeTime.minute,
      );
      return '${startTod.format(context)} – ${dueTod.format(context)}';
    }
    return null;
  }
}

/// Computes the mapping of civil days to unified calendar day tasks for a given month.
Map<CivilDay, List<CalendarDayTask>> computeMonthTaskMap({
  required DateTime monthDate,
  required List<TaskInstance> instances,
  required List<TaskSchedule> schedules,
  String? currentUserId,
  CivilDay? today,
}) {
  final Map<CivilDay, List<CalendarDayTask>> map = {};
  final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
  final effectiveToday = today ?? CivilDay.fromDateTime(AppClock.now);

  // 1. Concrete instances
  final Set<String> instanceScheduleDateKeys = {};
  for (final inst in instances) {
    final scheduledDate = inst.scheduledDate;
    if (scheduledDate.year != monthDate.year ||
        scheduledDate.month != monthDate.month) {
      continue;
    }
    instanceScheduleDateKeys.add('${inst.scheduleId}_$scheduledDate');

    if (inst.status == TaskStatus.skipped || inst.status == TaskStatus.failed) {
      continue;
    }

    final bool isCompleted = (inst.isFamily && currentUserId != null)
        ? inst.isCompletedForUser(currentUserId)
        : (inst.status == TaskStatus.completed);

    final task = CalendarDayTask(
      id: inst.id,
      title: inst.title,
      description: inst.description,
      priority: inst.priority,
      status: inst.status,
      isInstance: true,
      instance: inst,
      isCompleted: isCompleted,
    );

    map.putIfAbsent(scheduledDate, () => []).add(task);
  }

  // 2. Projected recurring schedules that do not have an instance for that day
  for (int dayNum = 1; dayNum <= daysInMonth; dayNum++) {
    final civilDay = CivilDay(
      year: monthDate.year,
      month: monthDate.month,
      day: dayNum,
    );

    if (civilDay.isBefore(effectiveToday)) {
      continue;
    }

    for (final sched in schedules) {
      final key = '${sched.id}_$civilDay';
      if (instanceScheduleDateKeys.contains(key)) {
        continue; // Already has concrete instance
      }

      final isRecurring = sched.schedules.any((s) => s is! OneOffSchedule);
      if (!isRecurring) {
        continue;
      }

      final matchingRule = sched.schedules.cast<TaskScheduleRule?>().firstWhere(
        (r) => r != null && r is! OneOffSchedule && r.occursOn(civilDay),
        orElse: () => null,
      );

      if (matchingRule != null) {
        final task = CalendarDayTask(
          id: 'projected_${sched.id}_$civilDay',
          title: sched.title,
          description: sched.description,
          priority: sched.priority,
          status: TaskStatus.pending,
          isInstance: false,
          schedule: sched,
          matchingRule: matchingRule,
        );

        map.putIfAbsent(civilDay, () => []).add(task);
      }
    }
  }

  // Sort tasks in each day: incomplete before completed, then high priority to low
  for (final list in map.values) {
    list.sort((a, b) {
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      return b.priority.index.compareTo(a.priority.index);
    });
  }

  return map;
}
