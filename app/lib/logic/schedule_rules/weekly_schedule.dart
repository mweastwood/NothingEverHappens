import 'package:flutter/material.dart';
import '../civil_day.dart';
import '../relative_time.dart';
import '../scheduling_policy.dart';
import '../missed_occurrence_policy.dart';
import 'task_schedule_rule.dart';

/// A schedule for a task that repeats every N weeks on specific days.
class WeeklySchedule extends TaskScheduleRule {
  /// The date from which the repetition interval starts.
  CivilDay startDate;

  /// The number of weeks between occurrences.
  int interval;

  /// The specific days of the week (1=Monday, 7=Sunday) the task occurs on.
  Set<int> daysOfWeek;

  WeeklySchedule({
    String? id,
    String? scheduleId,
    required this.startDate,
    required this.interval,
    required this.daysOfWeek,
    super.startRelativeTime,
    super.dueRelativeTime,
    super.notificationRelativeTimes,
    super.schedulingPolicy,
    super.missedOccurrencePolicy,
  }) : super(
         id: id ?? TaskScheduleRule.generateId(),
         scheduleId: scheduleId ?? '',
       );

  @override
  CivilDay get scheduledDate => startDate;

  factory WeeklySchedule.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? TaskScheduleRule.generateId();
    final scheduleId = json['scheduleId'] as String? ?? '';
    final startJson = json['startRelativeTime'] as Map?;
    final dueJson = json['dueRelativeTime'] as Map?;
    final start = startJson != null
        ? RelativeTime.fromJson(Map<String, dynamic>.from(startJson))
        : const RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 9, minute: 0));

    final due = dueJson != null
        ? RelativeTime.fromJson(Map<String, dynamic>.from(dueJson))
        : const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          );

    final notifs = parseNotificationRelativeTimes(json);

    final schedulingPolicy = json['schedulingPolicy'] != null
        ? SchedulingPolicy.fromJson(
            Map<String, dynamic>.from(json['schedulingPolicy'] as Map),
          )
        : const FixedCalendarPolicy();

    final missedOccurrencePolicy = json['missedOccurrencePolicy'] != null
        ? MissedOccurrencePolicy.fromJson(
            Map<String, dynamic>.from(json['missedOccurrencePolicy'] as Map),
          )
        : const MissedOccurrencePolicy.stack();

    return WeeklySchedule(
      id: id,
      scheduleId: scheduleId,
      startDate: CivilDay.fromJson(
        Map<String, dynamic>.from(json['startDate'] as Map),
      ),
      interval: json['interval'] as int,
      daysOfWeek: (json['daysOfWeek'] as List<dynamic>).cast<int>().toSet(),
      startRelativeTime: start,
      dueRelativeTime: due,
      notificationRelativeTimes: notifs,
      schedulingPolicy: schedulingPolicy,
      missedOccurrencePolicy: missedOccurrencePolicy,
    );
  }

  @override
  bool occursOn(CivilDay date) {
    final startUtc = startDate.toUtcDateTime();
    final targetUtc = date.toUtcDateTime();

    // Before start date?
    if (targetUtc.isBefore(startUtc)) {
      return false;
    }

    // Check if the specific day of week is allowed
    // weekday 1 = Monday, 7 = Sunday
    if (!daysOfWeek.contains(targetUtc.weekday)) {
      return false;
    }

    // Calculate week difference
    final startOfWeekForStart = startUtc.subtract(
      Duration(days: startUtc.weekday - 1),
    );
    final startOfWeekForTarget = targetUtc.subtract(
      Duration(days: targetUtc.weekday - 1),
    );

    final daysDiff = startOfWeekForTarget
        .difference(startOfWeekForStart)
        .inDays;
    final weeksDiff = daysDiff ~/ 7;

    return weeksDiff % interval == 0;
  }

  @override
  CivilDay? nextOccurrenceAfter(CivilDay date) {
    if (daysOfWeek.isEmpty) {
      throw Exception('No occurrence found within 10 years');
    }

    final startUtc = startDate.toUtcDateTime();
    final refUtc = date.toUtcDateTime();

    // The occurrence must be strictly after `date` and on or after `startDate`
    final nextDayUtc = refUtc.add(const Duration(days: 1));
    final minDateUtc = nextDayUtc.isBefore(startUtc) ? startUtc : nextDayUtc;

    final startOfWeekForStart = startUtc.subtract(
      Duration(days: startUtc.weekday - 1),
    );
    final startOfWeekForMin = minDateUtc.subtract(
      Duration(days: minDateUtc.weekday - 1),
    );

    final daysDiff = startOfWeekForMin.difference(startOfWeekForStart).inDays;
    final weeksDiff = daysDiff ~/ 7;
    final k = weeksDiff % interval;

    final sortedDays = daysOfWeek.toList()..sort();

    if (k == 0) {
      // In an active week: check if there is an occurrence on or after minDateUtc
      for (final w in sortedDays) {
        final candUtc = startOfWeekForMin.add(Duration(days: w - 1));
        if (!candUtc.isBefore(minDateUtc)) {
          return CivilDay(
            year: candUtc.year,
            month: candUtc.month,
            day: candUtc.day,
          );
        }
      }
    }

    // Otherwise (or if all active days in current week have passed), jump to next active week
    final weeksToJump = k == 0 ? interval : (interval - k);
    final nextActiveWeekStart = startOfWeekForMin.add(
      Duration(days: weeksToJump * 7),
    );
    final firstDayInNextWeek = nextActiveWeekStart.add(
      Duration(days: sortedDays.first - 1),
    );

    return CivilDay(
      year: firstDayInNextWeek.year,
      month: firstDayInNextWeek.month,
      day: firstDayInNextWeek.day,
    );
  }

  @override
  TaskScheduleRule copyWithStartDate(CivilDay newStartDate) {
    return WeeklySchedule(
      id: id,
      scheduleId: scheduleId,
      startDate: newStartDate,
      interval: interval,
      daysOfWeek: daysOfWeek,
      startRelativeTime: startRelativeTime,
      dueRelativeTime: dueRelativeTime,
      notificationRelativeTimes: notificationRelativeTimes,
      schedulingPolicy: schedulingPolicy,
      missedOccurrencePolicy: missedOccurrencePolicy,
    );
  }

  @override
  TaskScheduleRule copyWithTiming({
    String? id,
    String? scheduleId,
    RelativeTime? startRelativeTime,
    RelativeTime? dueRelativeTime,
    List<RelativeTime>? notificationRelativeTimes,
    SchedulingPolicy? schedulingPolicy,
    MissedOccurrencePolicy? missedOccurrencePolicy,
  }) {
    final newStart = startRelativeTime ?? this.startRelativeTime;
    var newPolicy = schedulingPolicy ?? this.schedulingPolicy;
    if (newPolicy is CompletionRelativePolicy && startRelativeTime != null) {
      newPolicy = CompletionRelativePolicy(
        interval: newPolicy.interval,
        targetTime: startRelativeTime.time,
      );
    }
    return WeeklySchedule(
      id: id ?? this.id,
      scheduleId: scheduleId ?? this.scheduleId,
      startDate: startDate,
      interval: interval,
      daysOfWeek: daysOfWeek,
      startRelativeTime: newStart,
      dueRelativeTime: dueRelativeTime ?? this.dueRelativeTime,
      notificationRelativeTimes:
          notificationRelativeTimes ?? this.notificationRelativeTimes,
      schedulingPolicy: newPolicy,
      missedOccurrencePolicy:
          missedOccurrencePolicy ?? this.missedOccurrencePolicy,
    );
  }

  @override
  bool hasSameRecurrence(TaskScheduleRule other) {
    if (other is! WeeklySchedule) return false;
    if (interval != other.interval) return false;
    if (daysOfWeek.length != other.daysOfWeek.length) return false;
    return daysOfWeek.every(other.daysOfWeek.contains);
  }

  @override
  TaskScheduleRule? advanceAfterCompletion(CivilDay today) {
    final firstOccur = occursOn(scheduledDate)
        ? scheduledDate
        : nextOccurrenceAfter(scheduledDate);
    if (firstOccur != null &&
        (firstOccur.isBefore(today) || firstOccur == today)) {
      final refDate = today.isBefore(scheduledDate) ? firstOccur : today;
      final nextOccur = nextOccurrenceAfter(refDate);
      if (nextOccur != null) {
        return copyWithStartDate(nextOccur);
      }
      return null;
    }
    return this;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scheduleId': scheduleId,
      'type': 'weekly',
      'startDate': startDate.toJson(),
      'interval': interval,
      'daysOfWeek': daysOfWeek.toList(),
      'startRelativeTime': startRelativeTime.toJson(),
      'dueRelativeTime': dueRelativeTime.toJson(),
      'schedulingPolicy': schedulingPolicy.toJson(),
      'missedOccurrencePolicy': missedOccurrencePolicy.toJson(),
      if (notificationRelativeTimes.isNotEmpty)
        'notificationRelativeTimes': notificationRelativeTimes
            .map((t) => t.toJson())
            .toList(),
    };
  }
}
