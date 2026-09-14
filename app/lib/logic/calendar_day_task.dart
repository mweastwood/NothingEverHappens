import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final Set<(String, CivilDay)> instanceScheduleDateKeys = {};
  for (final inst in instances) {
    final scheduledDate = inst.scheduledDate;
    if (scheduledDate.year != monthDate.year ||
        scheduledDate.month != monthDate.month) {
      continue;
    }
    instanceScheduleDateKeys.add((inst.scheduleId, scheduledDate));

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

  // 2. Pre-filter schedules that have recurring rules once per month calculation
  final recurringSchedules =
      <({TaskSchedule schedule, List<TaskScheduleRule> rules})>[];
  for (final sched in schedules) {
    final recurringRules = [
      for (final rule in sched.schedules)
        if (rule is! OneOffSchedule) rule,
    ];
    if (recurringRules.isNotEmpty) {
      recurringSchedules.add((schedule: sched, rules: recurringRules));
    }
  }

  // 3. Projected recurring schedules that do not have an instance for that day
  for (int dayNum = 1; dayNum <= daysInMonth; dayNum++) {
    final civilDay = CivilDay(
      year: monthDate.year,
      month: monthDate.month,
      day: dayNum,
    );

    if (civilDay.isBefore(effectiveToday)) {
      continue;
    }

    for (final item in recurringSchedules) {
      final sched = item.schedule;
      if (instanceScheduleDateKeys.contains((sched.id, civilDay))) {
        continue; // Already has concrete instance
      }

      TaskScheduleRule? matchingRule;
      for (final rule in item.rules) {
        if (rule.occursOn(civilDay)) {
          matchingRule = rule;
          break;
        }
      }

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

/// In-memory cache for computed calendar month task mappings across the app.
class CalendarMonthTaskCache {
  final Map<DateTime, Map<CivilDay, List<CalendarDayTask>>> _cache = {};
  List<TaskInstance>? _cachedInstances;
  List<TaskSchedule>? _cachedSchedules;
  String? _cachedUserId;
  CivilDay? _cachedToday;

  Map<CivilDay, List<CalendarDayTask>> getMonthTaskMap({
    required DateTime monthDate,
    required List<TaskInstance> instances,
    required List<TaskSchedule> schedules,
    String? currentUserId,
    CivilDay? today,
  }) {
    final effectiveToday = today ?? CivilDay.fromDateTime(AppClock.now);
    if (!identical(instances, _cachedInstances) ||
        !identical(schedules, _cachedSchedules) ||
        currentUserId != _cachedUserId ||
        effectiveToday != _cachedToday) {
      _cache.clear();
      _cachedInstances = instances;
      _cachedSchedules = schedules;
      _cachedUserId = currentUserId;
      _cachedToday = effectiveToday;
    }

    final monthKey = DateTime(monthDate.year, monthDate.month, 1);
    return _cache.putIfAbsent(
      monthKey,
      () => computeMonthTaskMap(
        monthDate: monthDate,
        instances: instances,
        schedules: schedules,
        currentUserId: currentUserId,
        today: effectiveToday,
      ),
    );
  }

  void clear() {
    _cache.clear();
    _cachedInstances = null;
    _cachedSchedules = null;
    _cachedUserId = null;
    _cachedToday = null;
  }
}

/// Global shared cache instance for calendar month task projections.
final sharedCalendarMonthTaskCache = CalendarMonthTaskCache();

/// Riverpod provider exposing the shared [CalendarMonthTaskCache].
final calendarMonthTaskCacheProvider = Provider<CalendarMonthTaskCache>((ref) {
  return sharedCalendarMonthTaskCache;
});
