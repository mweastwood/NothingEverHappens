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
  ) =>
      _parseNotificationRelativeTimes(json);

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
  })  : startRelativeTime = startRelativeTime ??
            const RelativeTime(
              dayOffset: 0,
              hour: 9,
              minute: 0,
            ),
        dueRelativeTime = dueRelativeTime ??
            const RelativeTime(
              dayOffset: 0,
              hour: 17,
              minute: 0,
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
  ///
  /// Returns `null` if there are no further occurrences (e.g. the schedule is
  /// exhausted or has no valid recurring dates).
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

  /// Calculates the next spawn [DateTime] for a rule using
  /// [CompletionRelativePolicy], advancing by true calendar months or years
  /// for [MonthlySchedule] and [YearlySchedule] rules (clamping to the end of
  /// the month when needed, e.g. Jan 31 + 1 month -> Feb 28/29) instead of
  /// fixed 30-day or 365-day approximations.
  DateTime nextCompletionRelativeDateTime(DateTime resolvedAt) {
    final policy = schedulingPolicy;
    if (policy is! CompletionRelativePolicy) {
      return resolvedAt;
    }

    DateTime buildDateTime(int year, int month, int day) {
      if (resolvedAt.isUtc) {
        return DateTime.utc(
          year,
          month,
          day,
          resolvedAt.hour,
          resolvedAt.minute,
          resolvedAt.second,
          resolvedAt.millisecond,
          resolvedAt.microsecond,
        );
      }
      return DateTime(
        year,
        month,
        day,
        resolvedAt.hour,
        resolvedAt.minute,
        resolvedAt.second,
        resolvedAt.millisecond,
        resolvedAt.microsecond,
      );
    }

    final self = this;
    if (self is MonthlySchedule &&
        policy.interval == Duration(days: self.interval * 30)) {
      final totalMonths = (resolvedAt.month - 1) + self.interval;
      final targetYear = resolvedAt.year + (totalMonths ~/ 12);
      final targetMonth = (totalMonths % 12) + 1;
      final maxDaysInMonth = DateTime(targetYear, targetMonth + 1, 0).day;
      final targetDay =
          resolvedAt.day > maxDaysInMonth ? maxDaysInMonth : resolvedAt.day;
      return buildDateTime(targetYear, targetMonth, targetDay);
    }

    if (self is YearlySchedule &&
        policy.interval == Duration(days: self.interval * 365)) {
      final targetYear = resolvedAt.year + self.interval;
      final targetMonth = resolvedAt.month;
      final maxDaysInMonth = DateTime(targetYear, targetMonth + 1, 0).day;
      final targetDay =
          resolvedAt.day > maxDaysInMonth ? maxDaysInMonth : resolvedAt.day;
      return buildDateTime(targetYear, targetMonth, targetDay);
    }

    return resolvedAt.add(policy.interval);
  }

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
