import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../civil_day.dart';
import '../relative_time.dart';
import '../scheduling_policy.dart';
import '../missed_occurrence_policy.dart';
import 'one_off_schedule.dart';
import 'daily_schedule.dart';
import 'weekly_schedule.dart';
import 'monthly_schedule.dart';
import 'yearly_schedule.dart';

/// Defines how often a task reoccurs.
List<RelativeTime> parseNotificationRelativeTimes(Map<String, dynamic> json) {
  if (json['notificationRelativeTimes'] != null) {
    final list = json['notificationRelativeTimes'] as List;
    return list
        .map(
          (item) =>
              RelativeTime.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }
  if (json['notificationRelativeTime'] != null) {
    final notifRaw = json['notificationRelativeTime'] as Map;
    return [RelativeTime.fromJson(Map<String, dynamic>.from(notifRaw))];
  }
  return [];
}

List<RelativeTime> _parseNotificationRelativeTimes(Map<String, dynamic> json) =>
    parseNotificationRelativeTimes(json);

abstract class TaskScheduleRule {
  static String generateId() => 'R-${const Uuid().v4()}';

  static List<RelativeTime> parseNotificationRelativeTimes(
    Map<String, dynamic> json,
  ) => _parseNotificationRelativeTimes(json);

  final String id;
  final String scheduleId;
  final RelativeTime startRelativeTime;
  final RelativeTime dueRelativeTime;
  final List<RelativeTime> notificationRelativeTimes;
  final SchedulingPolicy schedulingPolicy;
  final MissedOccurrencePolicy missedOccurrencePolicy;

  int get futureInstancesCount {
    final self = this;
    if (self is DailySchedule) return 10;
    if (self is WeeklySchedule) return 5;
    if (self is MonthlySchedule) return 3;
    if (self is YearlySchedule) return 2;
    return 1;
  }

  const TaskScheduleRule({
    required this.id,
    required this.scheduleId,
    RelativeTime? startRelativeTime,
    RelativeTime? dueRelativeTime,
    List<RelativeTime>? notificationRelativeTimes,
    SchedulingPolicy? schedulingPolicy,
    MissedOccurrencePolicy? missedOccurrencePolicy,
  }) : startRelativeTime =
           startRelativeTime ??
           const RelativeTime(
             dayOffset: 0,
             time: TimeOfDay(hour: 9, minute: 0),
           ),
       dueRelativeTime =
           dueRelativeTime ??
           const RelativeTime(
             dayOffset: 0,
             time: TimeOfDay(hour: 17, minute: 0),
           ),
       notificationRelativeTimes = notificationRelativeTimes ?? const [],
       schedulingPolicy = schedulingPolicy ?? const FixedCalendarPolicy(),
       missedOccurrencePolicy =
           missedOccurrencePolicy ?? const MissedOccurrencePolicy.stack();

  /// The scheduled date of this occurrence.
  CivilDay get scheduledDate;

  /// Checks if the task occurs on the given [date].
  bool occursOn(CivilDay date);

  /// Calculates the next occurrence of the task strictly after [date].
  CivilDay? nextOccurrenceAfter(CivilDay date);

  /// Checks if two rules have identical recurrence patterns.
  bool hasSameRecurrence(TaskScheduleRule other);

  /// Creates a copy of this schedule with a new scheduled/start date.
  TaskScheduleRule copyWithStartDate(CivilDay newStartDate);

  /// Creates a copy of this schedule with updated timing parameters.
  TaskScheduleRule copyWithTiming({
    String? id,
    String? scheduleId,
    RelativeTime? startRelativeTime,
    RelativeTime? dueRelativeTime,
    List<RelativeTime>? notificationRelativeTimes,
    SchedulingPolicy? schedulingPolicy,
    MissedOccurrencePolicy? missedOccurrencePolicy,
  });

  /// Returns the next schedule rule after completing on or before [today],
  /// or `null` if this rule should be removed (e.g., a completed one-off).
  ///
  /// For one-off schedules: returns `null` if the scheduled date is on or
  /// before [today] (completed), otherwise returns `this` unchanged.
  /// For recurring schedules: advances to the next occurrence after [today].
  TaskScheduleRule? advanceAfterCompletion(CivilDay today);
  Map<String, dynamic> toJson();

  factory TaskScheduleRule.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'oneOff':
        return OneOffSchedule.fromJson(json);
      case 'daily':
        return DailySchedule.fromJson(json);
      case 'weekly':
        return WeeklySchedule.fromJson(json);
      case 'monthly':
        return MonthlySchedule.fromJson(json);
      case 'yearly':
        return YearlySchedule.fromJson(json);
      default:
        throw Exception('Unknown schedule type: $type');
    }
  }
}

/// Enum representing the type of recurrence for UI selection.
enum RecurrenceType { oneOff, daily, weekly, monthly, yearly }
