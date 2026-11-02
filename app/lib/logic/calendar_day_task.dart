import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_clock.dart';
import 'civil_day.dart';
import 'relative_time.dart';
import 'task_instance.dart';
import 'task_label.dart';
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

  Duration? get estimatedDuration => schedule?.estimatedDuration;

  /// Effective duration in minutes, defaulting to 30 minutes when unset.
  int get effectiveDurationMinutes =>
      (schedule?.estimatedDuration?.inMinutes ?? 30).clamp(5, 1440);

  /// Label IDs associated with this task (instance overrides schedule if non-empty).
  List<String> get labelIds {
    if (instance != null && instance!.labelIds.isNotEmpty) {
      return instance!.labelIds;
    }
    if (schedule != null && schedule!.labelIds.isNotEmpty) {
      return schedule!.labelIds;
    }
    return const <String>[];
  }

  /// Resolves the schedule rule that produced this calendar day task, if any.
  TaskScheduleRule? get effectiveRule {
    if (matchingRule != null) return matchingRule;
    final sched = schedule;
    if (sched == null || sched.schedules.isEmpty) return null;
    final ruleId = instance?.ruleId;
    if (ruleId != null && ruleId.isNotEmpty) {
      for (final rule in sched.schedules) {
        if (rule.id == ruleId) return rule;
      }
    }
    return sched.schedules.first;
  }

  /// Whether this task is an everyday fixed-calendar routine (DailySchedule with interval == 1).
  bool get isRoutineDaily {
    final rule = effectiveRule;
    if (rule == null) return false;
    if (rule.schedulingPolicy is CompletionRelativePolicy) return false;
    return rule is DailySchedule && rule.interval == 1;
  }

  /// Computes a score used to select the single "Hero / Standout" task for a day cell.
  ///
  /// Rarer schedules (one-off, yearly, monthly, weekly) and longer/higher-priority tasks
  /// outrank repetitive daily routines so the monthly view surfaces what makes each day unique.
  double get standoutScore {
    final rule = effectiveRule;
    final double rarityWeight;
    if (rule == null || rule is OneOffSchedule) {
      rarityWeight = 4.0;
    } else if (rule is YearlySchedule) {
      rarityWeight = 3.5;
    } else if (rule is MonthlySchedule) {
      rarityWeight = 3.0;
    } else if (rule.schedulingPolicy is CompletionRelativePolicy) {
      rarityWeight = 2.5;
    } else if (rule is WeeklySchedule) {
      final daysCount = rule.daysOfWeek.length.clamp(1, 7);
      rarityWeight = 1.5 + (7 - daysCount) * 0.2;
    } else if (rule is DailySchedule) {
      if (rule.interval > 1) {
        rarityWeight = 1.0 + (rule.interval.clamp(2, 14) * 0.15);
      } else {
        rarityWeight = 0.35;
      }
    } else {
      rarityWeight = 1.5;
    }

    final double priorityWeight;
    switch (priority) {
      case TaskPriority.high:
        priorityWeight = 1.5;
      case TaskPriority.medium:
        priorityWeight = 1.2;
      case TaskPriority.low:
        priorityWeight = 1.0;
    }

    final durationFactor = effectiveDurationMinutes < 15
        ? 15.0
        : effectiveDurationMinutes.toDouble();
    return rarityWeight * priorityWeight * durationFactor;
  }

  ({RelativeTime start, RelativeTime due})? get relativeTimeWindow {
    if (instance != null) {
      return (
        start: instance!.startRelativeTime,
        due: instance!.dueRelativeTime,
      );
    }
    if (matchingRule != null) {
      return (
        start: matchingRule!.startRelativeTime,
        due: matchingRule!.dueRelativeTime,
      );
    }
    return null;
  }

  String? getTimeWindow(BuildContext context) {
    final window = relativeTimeWindow;
    if (window == null) return null;
    final startTod = TimeOfDay(
      hour: window.start.hour,
      minute: window.start.minute,
    );
    final dueTod = TimeOfDay(hour: window.due.hour, minute: window.due.minute);
    return '${startTod.format(context)} – ${dueTod.format(context)}';
  }
}

/// Compares two [CalendarDayTask]s for standout hero selection and day list ordering.
int compareCalendarDayTasks(
  CalendarDayTask a,
  CalendarDayTask b, {
  bool isPastDay = false,
}) {
  if (!isPastDay && a.isCompleted != b.isCompleted) {
    return a.isCompleted ? 1 : -1;
  }
  final scoreCmp = b.standoutScore.compareTo(a.standoutScore);
  if (scoreCmp != 0) return scoreCmp;
  final priorityCmp = b.priority.index.compareTo(a.priority.index);
  if (priorityCmp != 0) return priorityCmp;
  return a.title.compareTo(b.title);
}

/// Represents a proportional color slice of a day's capacity bar.
class CalendarLabelSegment {
  /// The [TaskLabel.colorKey] for this segment, or `null` for unlabeled tasks.
  final String? colorKey;

  /// Total minutes attributed to this segment.
  final double minutes;

  const CalendarLabelSegment({required this.colorKey, required this.minutes});
}

/// Aggregated workload, standout task, and label-color breakdown for a single calendar day.
class CalendarDayWorkload {
  /// Maximum number of standout tasks rotated through on a single day cell.
  static const int maxStandoutCandidates = 4;

  /// Minimum standoutScore ratio relative to the top task for a secondary task to rotate.
  static const double minStandoutScoreRatio = 0.25;

  final List<CalendarDayTask> tasks;
  final int totalMinutes;
  final double capacityHours;
  final CalendarDayTask? standoutTask;
  final List<CalendarDayTask> standoutCandidates;
  final List<CalendarLabelSegment> segments;

  const CalendarDayWorkload({
    required this.tasks,
    required this.totalMinutes,
    required this.capacityHours,
    required this.standoutTask,
    this.standoutCandidates = const [],
    required this.segments,
  });

  factory CalendarDayWorkload.fromTasks(
    List<CalendarDayTask> tasks, {
    double capacityHours = 4.0,
    Map<String, TaskLabel> labelsMap = const {},
    bool isPastDay = false,
  }) {
    if (tasks.isEmpty) {
      return CalendarDayWorkload(
        tasks: const [],
        totalMinutes: 0,
        capacityHours: capacityHours,
        standoutTask: null,
        standoutCandidates: const [],
        segments: const [],
      );
    }

    final sortedTasks = List<CalendarDayTask>.of(tasks)
      ..sort((a, b) => compareCalendarDayTasks(a, b, isPastDay: isPastDay));
    final CalendarDayTask bestTask = sortedTasks.first;

    final List<CalendarDayTask> candidates = [bestTask];
    final double minScore = bestTask.standoutScore * minStandoutScoreRatio;
    for (var i = 1; i < sortedTasks.length; i++) {
      if (candidates.length >= maxStandoutCandidates) break;
      final candidate = sortedTasks[i];
      if (!isPastDay && !bestTask.isCompleted && candidate.isCompleted) {
        continue;
      }
      if (!bestTask.isRoutineDaily && candidate.isRoutineDaily) {
        continue;
      }
      if (candidate.standoutScore < minScore) {
        continue;
      }
      candidates.add(candidate);
    }

    int totalMins = 0;
    final Map<String?, double> minutesByColorKey = {};

    for (var i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      final durationMins = task.effectiveDurationMinutes;
      totalMins += durationMins;

      final resolvedLabels = <TaskLabel>[
        for (final id in task.labelIds)
          if (labelsMap[id] != null) labelsMap[id]!,
      ];

      if (resolvedLabels.isEmpty) {
        minutesByColorKey[null] =
            (minutesByColorKey[null] ?? 0.0) + durationMins.toDouble();
      } else {
        final share = durationMins / resolvedLabels.length;
        for (final label in resolvedLabels) {
          final key = label.colorKey.trim().toLowerCase();
          minutesByColorKey[key] = (minutesByColorKey[key] ?? 0.0) + share;
        }
      }
    }

    final segments =
        [
          for (final entry in minutesByColorKey.entries)
            if (entry.value > 0)
              CalendarLabelSegment(colorKey: entry.key, minutes: entry.value),
        ]..sort((a, b) {
          if ((a.colorKey == null) != (b.colorKey == null)) {
            return a.colorKey == null ? 1 : -1;
          }
          final minCmp = b.minutes.compareTo(a.minutes);
          if (minCmp != 0) return minCmp;
          return (a.colorKey ?? '').compareTo(b.colorKey ?? '');
        });

    return CalendarDayWorkload(
      tasks: tasks,
      totalMinutes: totalMins,
      capacityHours: capacityHours,
      standoutTask: bestTask,
      standoutCandidates: candidates,
      segments: segments,
    );
  }

  bool get isEmpty => tasks.isEmpty;
  bool get isNotEmpty => tasks.isNotEmpty;
  double get totalHours => totalMinutes / 60.0;
  double get effectiveCapacityHours => capacityHours > 0 ? capacityHours : 4.0;
  double get loadRatio => totalHours / effectiveCapacityHours;
  bool get isOverCapacity => totalHours > effectiveCapacityHours + 1e-6;
  bool get isHighLoad => !isOverCapacity && loadRatio >= 0.85;
  bool get allCompleted =>
      tasks.isNotEmpty && tasks.every((t) => t.isCompleted);
  int get additionalTasksCount => tasks.length > 1 ? tasks.length - 1 : 0;

  /// Compact planned hours label (e.g. `1.5h`, `2h`, `3.5h!`).
  String get formattedPlannedHours {
    if (totalMinutes <= 0) return '';
    final hours = totalMinutes / 60.0;
    final roundedTenths = (hours * 10).round() / 10.0;
    final text = roundedTenths == roundedTenths.roundToDouble()
        ? '${roundedTenths.toInt()}h'
        : '${roundedTenths.toStringAsFixed(1)}h';
    return isOverCapacity ? '$text!' : text;
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
  final Map<String, TaskSchedule> scheduleMap = {
    for (final s in schedules) s.id: s,
  };
  final Set<(String, String, CivilDay)> instanceRuleDateKeys = {};
  final Set<(String, CivilDay)> instanceScheduleOnlyDateKeys = {};
  for (final inst in instances) {
    final scheduledDate = inst.scheduledDate;
    if (scheduledDate.year != monthDate.year ||
        scheduledDate.month != monthDate.month) {
      continue;
    }
    final sched = scheduleMap[inst.scheduleId];
    TaskScheduleRule? matchedRule;
    if (sched != null) {
      for (final r in sched.schedules) {
        if (r.id == inst.ruleId) {
          matchedRule = r;
          break;
        }
      }
    }
    if (matchedRule != null) {
      instanceRuleDateKeys.add((inst.scheduleId, inst.ruleId, scheduledDate));
    } else {
      instanceScheduleOnlyDateKeys.add((inst.scheduleId, scheduledDate));
    }

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
      schedule: sched,
      matchingRule: matchedRule,
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
        if (rule is! OneOffSchedule &&
            rule.schedulingPolicy is! CompletionRelativePolicy)
          rule,
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
      if (instanceScheduleOnlyDateKeys.contains((sched.id, civilDay))) {
        continue; // Already has concrete instance covering schedule on that day
      }

      int projectedCountForScheduleOnDay = 0;
      for (final rule in item.rules) {
        if (instanceRuleDateKeys.contains((sched.id, rule.id, civilDay))) {
          continue; // Concrete instance already exists for this rule on this day
        }
        if (rule.occursOn(civilDay)) {
          final projectedId = projectedCountForScheduleOnDay == 0
              ? 'projected_${sched.id}_$civilDay'
              : 'projected_${sched.id}_${rule.id}_$civilDay';
          projectedCountForScheduleOnDay++;
          final task = CalendarDayTask(
            id: projectedId,
            title: sched.title,
            description: sched.description,
            priority: sched.priority,
            status: TaskStatus.pending,
            isInstance: false,
            schedule: sched,
            matchingRule: rule,
          );

          map.putIfAbsent(civilDay, () => []).add(task);
        }
      }
    }
  }

  // Sort tasks in each day by standout hero score (incomplete before completed on today/future days)
  for (final entry in map.entries) {
    final isPastDay = entry.key.isBefore(effectiveToday);
    entry.value.sort(
      (a, b) => compareCalendarDayTasks(a, b, isPastDay: isPastDay),
    );
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
