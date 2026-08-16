import 'package:flutter/material.dart';
import '../civil_day.dart';
import '../relative_time.dart';
import '../scheduling_policy.dart';
import '../missed_occurrence_policy.dart';
import 'task_schedule_rule.dart';

/// A schedule for a task that happens exactly once.
class OneOffSchedule extends TaskScheduleRule {
  /// The specific date the task occurs.
  CivilDay date;

  OneOffSchedule({
    String? id,
    String? scheduleId,
    required this.date,
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
  CivilDay get scheduledDate => date;

  factory OneOffSchedule.fromJson(Map<String, dynamic> json) {
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

    return OneOffSchedule(
      id: id,
      scheduleId: scheduleId,
      date: CivilDay.fromJson(Map<String, dynamic>.from(json['date'] as Map)),
      startRelativeTime: start,
      dueRelativeTime: due,
      notificationRelativeTimes: notifs,
      schedulingPolicy: schedulingPolicy,
      missedOccurrencePolicy: missedOccurrencePolicy,
    );
  }

  @override
  bool occursOn(CivilDay date) {
    return this.date == date;
  }

  @override
  CivilDay? nextOccurrenceAfter(CivilDay date) {
    if (date.isBefore(this.date)) {
      return this.date;
    }
    return null;
  }

  @override
  TaskScheduleRule copyWithStartDate(CivilDay newStartDate) {
    return OneOffSchedule(
      id: id,
      scheduleId: scheduleId,
      date: newStartDate,
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
    return OneOffSchedule(
      id: id ?? this.id,
      scheduleId: scheduleId ?? this.scheduleId,
      date: date,
      startRelativeTime: startRelativeTime ?? this.startRelativeTime,
      dueRelativeTime: dueRelativeTime ?? this.dueRelativeTime,
      notificationRelativeTimes:
          notificationRelativeTimes ?? this.notificationRelativeTimes,
      schedulingPolicy: schedulingPolicy ?? this.schedulingPolicy,
      missedOccurrencePolicy:
          missedOccurrencePolicy ?? this.missedOccurrencePolicy,
    );
  }

  @override
  bool hasSameRecurrence(TaskScheduleRule other) {
    if (other is! OneOffSchedule) return false;
    return date == other.date;
  }

  @override
  TaskScheduleRule? advanceAfterCompletion(CivilDay today) {
    if (scheduledDate.isBefore(today) || scheduledDate == today) {
      return null; // Completed one-off, remove it.
    }
    return this; // Future one-off, keep it.
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scheduleId': scheduleId,
      'type': 'oneOff',
      'date': date.toJson(),
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
