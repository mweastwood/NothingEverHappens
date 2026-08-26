import 'package:flutter/material.dart';

import '../civil_day.dart';
import '../relative_time.dart';
import '../scheduling_policy.dart';
import '../missed_occurrence_policy.dart';
import 'task_schedule_rule.dart';

/// A schedule for a task that repeats every N years.
class YearlySchedule extends TaskScheduleRule {
  /// The date from which the recurrence starts.
  final CivilDay startDate;

  /// The number of years between occurrences.
  final int interval;

  /// Month of the year (1 = Jan, 12 = Dec).
  final int month;

  /// Day of the month (1 = first day, 31 = last day).
  final int day;

  YearlySchedule({
    String? id,
    String? scheduleId,
    required this.startDate,
    required int interval,
    required this.month,
    required this.day,
    super.startRelativeTime,
    super.dueRelativeTime,
    super.notificationRelativeTimes,
    super.schedulingPolicy,
    super.missedOccurrencePolicy,
  }) : interval = interval <= 0 ? 1 : interval,
       super(
         id: id ?? TaskScheduleRule.generateId(),
         scheduleId: scheduleId ?? '',
       );

  @override
  CivilDay get scheduledDate => startDate;

  factory YearlySchedule.fromJson(Map<String, dynamic> json) {
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

    final rawInterval = json['interval'] as int? ?? 1;
    final interval = rawInterval <= 0 ? 1 : rawInterval;

    return YearlySchedule(
      id: id,
      scheduleId: scheduleId,
      startDate: CivilDay.fromJson(
        Map<String, dynamic>.from(json['startDate'] as Map),
      ),
      interval: interval,
      month: json['month'] as int,
      day: json['day'] as int,
      startRelativeTime: start,
      dueRelativeTime: due,
      notificationRelativeTimes: notifs,
      schedulingPolicy: schedulingPolicy,
      missedOccurrencePolicy: missedOccurrencePolicy,
    );
  }

  @override
  bool occursOn(CivilDay date) {
    final safeInterval = interval <= 0 ? 1 : interval;
    final startUtc = startDate.toUtcDateTime();
    final targetUtc = date.toUtcDateTime();

    if (targetUtc.isBefore(startUtc)) {
      return false;
    }

    if (date.month != month || date.day != day) {
      return false;
    }

    final yearsDiff = date.year - startDate.year;
    return yearsDiff >= 0 && yearsDiff % safeInterval == 0;
  }

  CivilDay? _occurrenceInYear(int year) {
    final lastDayOfMonth = DateTime.utc(
      year,
      month + 1,
      1,
    ).subtract(const Duration(days: 1)).day;
    if (day > lastDayOfMonth) {
      return null;
    }
    return CivilDay(year: year, month: month, day: day);
  }

  @override
  CivilDay? nextOccurrenceAfter(CivilDay date) {
    final safeInterval = interval <= 0 ? 1 : interval;
    int cycle;
    if (date.year < startDate.year) {
      cycle = 0;
    } else {
      final yearsDiff = date.year - startDate.year;
      cycle = yearsDiff ~/ safeInterval;
    }

    // Search up to 100 cycles
    for (int i = 0; i < 100; i++, cycle++) {
      final targetYear = startDate.year + cycle * safeInterval;
      final occurrenceDay = _occurrenceInYear(targetYear);
      if (occurrenceDay == null) continue;

      if (occurrenceDay.isAfter(date) && !occurrenceDay.isBefore(startDate)) {
        return occurrenceDay;
      }
    }
    throw Exception('No occurrence found within 20 years');
  }

  @override
  TaskScheduleRule copyWithStartDate(CivilDay newStartDate) {
    return YearlySchedule(
      id: id,
      scheduleId: scheduleId,
      startDate: newStartDate,
      interval: interval,
      month: month,
      day: day,
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
    return YearlySchedule(
      id: id ?? this.id,
      scheduleId: scheduleId ?? this.scheduleId,
      startDate: startDate,
      interval: interval,
      month: month,
      day: day,
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
    if (other is! YearlySchedule) return false;
    if (interval != other.interval) return false;
    if (month != other.month) return false;
    if (day != other.day) return false;
    return true;
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
      'type': 'yearly',
      'startDate': startDate.toJson(),
      'interval': interval,
      'month': month,
      'day': day,
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
