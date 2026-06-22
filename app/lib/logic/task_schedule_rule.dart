import 'package:flutter/material.dart';
import 'civil_day.dart';
import 'relative_time.dart';
import 'scheduling_policy.dart';
import 'missed_occurrence_policy.dart';

/// Defines how often a task reoccurs.
List<RelativeTime> _parseNotificationRelativeTimes(Map<String, dynamic> json) {
  if (json['notificationRelativeTimes'] != null) {
    final list = json['notificationRelativeTimes'] as List;
    return list
        .map((item) => RelativeTime.fromJson(item as Map<String, dynamic>))
        .toList();
  }
  if (json['notificationRelativeTime'] != null) {
    final notifJson = json['notificationRelativeTime'] as Map<String, dynamic>;
    return [RelativeTime.fromJson(notifJson)];
  }
  return [];
}

abstract class TaskScheduleRule {
  final RelativeTime startRelativeTime;
  final RelativeTime dueRelativeTime;
  final List<RelativeTime> notificationRelativeTimes;
  final SchedulingPolicy schedulingPolicy;
  final MissedOccurrencePolicy missedOccurrencePolicy;

  const TaskScheduleRule({
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
           missedOccurrencePolicy ?? const MissedOccurrencePolicy.keepAround();

  /// The scheduled date of this occurrence.
  CivilDay get scheduledDate;

  /// Checks if the task occurs on the given [date].
  bool occursOn(CivilDay date);

  /// Calculates the next occurrence of the task strictly after [date].
  CivilDay? nextOccurrenceAfter(CivilDay date);

  /// Creates a copy of this schedule with a new scheduled/start date.
  TaskScheduleRule copyWithStartDate(CivilDay newStartDate);

  /// Creates a copy of this schedule with updated timing parameters.
  TaskScheduleRule copyWithTiming({
    RelativeTime? startRelativeTime,
    RelativeTime? dueRelativeTime,
    List<RelativeTime>? notificationRelativeTimes,
    SchedulingPolicy? schedulingPolicy,
    MissedOccurrencePolicy? missedOccurrencePolicy,
  });

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

/// A schedule for a task that happens exactly once.
class OneOffSchedule extends TaskScheduleRule {
  /// The specific date the task occurs.
  CivilDay date;

  OneOffSchedule({
    required this.date,
    super.startRelativeTime,
    super.dueRelativeTime,
    super.notificationRelativeTimes,
    super.schedulingPolicy,
    super.missedOccurrencePolicy,
  });

  @override
  CivilDay get scheduledDate => date;

  factory OneOffSchedule.fromJson(Map<String, dynamic> json) {
    final startJson = json['startRelativeTime'] as Map<String, dynamic>?;
    final dueJson = json['dueRelativeTime'] as Map<String, dynamic>?;
    final start = startJson != null
        ? RelativeTime.fromJson(startJson)
        : const RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 9, minute: 0));

    final due = dueJson != null
        ? RelativeTime.fromJson(dueJson)
        : const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          );

    final notifs = _parseNotificationRelativeTimes(json);

    final schedulingPolicy = json['schedulingPolicy'] != null
        ? SchedulingPolicy.fromJson(
            json['schedulingPolicy'] as Map<String, dynamic>,
          )
        : const FixedCalendarPolicy();

    final missedOccurrencePolicy = json['missedOccurrencePolicy'] != null
        ? MissedOccurrencePolicy.fromJson(
            json['missedOccurrencePolicy'] as Map<String, dynamic>,
          )
        : const MissedOccurrencePolicy.keepAround();

    return OneOffSchedule(
      date: CivilDay.fromJson(json['date'] as Map<String, dynamic>),
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
    RelativeTime? startRelativeTime,
    RelativeTime? dueRelativeTime,
    List<RelativeTime>? notificationRelativeTimes,
    SchedulingPolicy? schedulingPolicy,
    MissedOccurrencePolicy? missedOccurrencePolicy,
  }) {
    return OneOffSchedule(
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
  Map<String, dynamic> toJson() {
    return {
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

/// A schedule for a task that repeats every N days.
class DailySchedule extends TaskScheduleRule {
  /// The date from which the repetition interval starts.
  CivilDay startDate;

  /// The number of days between occurrences.
  int interval;

  DailySchedule({
    required this.startDate,
    required this.interval,
    super.startRelativeTime,
    super.dueRelativeTime,
    super.notificationRelativeTimes,
    super.schedulingPolicy,
    super.missedOccurrencePolicy,
  });

  @override
  CivilDay get scheduledDate => startDate;

  factory DailySchedule.fromJson(Map<String, dynamic> json) {
    final startJson = json['startRelativeTime'] as Map<String, dynamic>?;
    final dueJson = json['dueRelativeTime'] as Map<String, dynamic>?;
    final start = startJson != null
        ? RelativeTime.fromJson(startJson)
        : const RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 9, minute: 0));

    final due = dueJson != null
        ? RelativeTime.fromJson(dueJson)
        : const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          );

    final notifs = _parseNotificationRelativeTimes(json);

    final schedulingPolicy = json['schedulingPolicy'] != null
        ? SchedulingPolicy.fromJson(
            json['schedulingPolicy'] as Map<String, dynamic>,
          )
        : const FixedCalendarPolicy();

    final missedOccurrencePolicy = json['missedOccurrencePolicy'] != null
        ? MissedOccurrencePolicy.fromJson(
            json['missedOccurrencePolicy'] as Map<String, dynamic>,
          )
        : const MissedOccurrencePolicy.keepAround();

    return DailySchedule(
      startDate: CivilDay.fromJson(json['startDate'] as Map<String, dynamic>),
      interval: json['interval'] as int,
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

    final difference = targetUtc.difference(startUtc).inDays;
    return difference % interval == 0;
  }

  @override
  CivilDay? nextOccurrenceAfter(CivilDay date) {
    final startUtc = startDate.toUtcDateTime();
    final currentUtc = date.toUtcDateTime();

    if (currentUtc.isBefore(startUtc)) {
      return startDate;
    }

    final daysDiff = currentUtc.difference(startUtc).inDays;
    final intervals = daysDiff ~/ interval;
    final occurrenceUtc = startUtc.add(Duration(days: intervals * interval));

    final nextUtc = currentUtc.isBefore(occurrenceUtc)
        ? occurrenceUtc
        : startUtc.add(Duration(days: (intervals + 1) * interval));

    return CivilDay(year: nextUtc.year, month: nextUtc.month, day: nextUtc.day);
  }

  @override
  TaskScheduleRule copyWithStartDate(CivilDay newStartDate) {
    return DailySchedule(
      startDate: newStartDate,
      interval: interval,
      startRelativeTime: startRelativeTime,
      dueRelativeTime: dueRelativeTime,
      notificationRelativeTimes: notificationRelativeTimes,
      schedulingPolicy: schedulingPolicy,
      missedOccurrencePolicy: missedOccurrencePolicy,
    );
  }

  @override
  TaskScheduleRule copyWithTiming({
    RelativeTime? startRelativeTime,
    RelativeTime? dueRelativeTime,
    List<RelativeTime>? notificationRelativeTimes,
    SchedulingPolicy? schedulingPolicy,
    MissedOccurrencePolicy? missedOccurrencePolicy,
  }) {
    return DailySchedule(
      startDate: startDate,
      interval: interval,
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
  Map<String, dynamic> toJson() {
    return {
      'type': 'daily',
      'startDate': startDate.toJson(),
      'interval': interval,
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

/// A schedule for a task that repeats every N weeks on specific days.
class WeeklySchedule extends TaskScheduleRule {
  /// The date from which the repetition interval starts.
  CivilDay startDate;

  /// The number of weeks between occurrences.
  int interval;

  /// The specific days of the week (1=Monday, 7=Sunday) the task occurs on.
  Set<int> daysOfWeek;

  WeeklySchedule({
    required this.startDate,
    required this.interval,
    required this.daysOfWeek,
    super.startRelativeTime,
    super.dueRelativeTime,
    super.notificationRelativeTimes,
    super.schedulingPolicy,
    super.missedOccurrencePolicy,
  });

  @override
  CivilDay get scheduledDate => startDate;

  factory WeeklySchedule.fromJson(Map<String, dynamic> json) {
    final startJson = json['startRelativeTime'] as Map<String, dynamic>?;
    final dueJson = json['dueRelativeTime'] as Map<String, dynamic>?;
    final start = startJson != null
        ? RelativeTime.fromJson(startJson)
        : const RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 9, minute: 0));

    final due = dueJson != null
        ? RelativeTime.fromJson(dueJson)
        : const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          );

    final notifs = _parseNotificationRelativeTimes(json);

    final schedulingPolicy = json['schedulingPolicy'] != null
        ? SchedulingPolicy.fromJson(
            json['schedulingPolicy'] as Map<String, dynamic>,
          )
        : const FixedCalendarPolicy();

    final missedOccurrencePolicy = json['missedOccurrencePolicy'] != null
        ? MissedOccurrencePolicy.fromJson(
            json['missedOccurrencePolicy'] as Map<String, dynamic>,
          )
        : const MissedOccurrencePolicy.keepAround();

    return WeeklySchedule(
      startDate: CivilDay.fromJson(json['startDate'] as Map<String, dynamic>),
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
    var current = date;
    for (int i = 0; i < 365 * 10; i++) {
      final currentUtc = DateTime.utc(current.year, current.month, current.day);
      final nextUtc = currentUtc.add(const Duration(days: 1));
      current = CivilDay(
        year: nextUtc.year,
        month: nextUtc.month,
        day: nextUtc.day,
      );
      if (occursOn(current)) {
        return current;
      }
    }
    throw Exception('No occurrence found within 10 years');
  }

  @override
  TaskScheduleRule copyWithStartDate(CivilDay newStartDate) {
    return WeeklySchedule(
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
    RelativeTime? startRelativeTime,
    RelativeTime? dueRelativeTime,
    List<RelativeTime>? notificationRelativeTimes,
    SchedulingPolicy? schedulingPolicy,
    MissedOccurrencePolicy? missedOccurrencePolicy,
  }) {
    return WeeklySchedule(
      startDate: startDate,
      interval: interval,
      daysOfWeek: daysOfWeek,
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
  Map<String, dynamic> toJson() {
    return {
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

/// A schedule for a task that repeats every N months.
class MonthlySchedule extends TaskScheduleRule {
  /// The date from which the recurrence starts.
  final CivilDay startDate;

  /// The number of months between occurrences.
  final int interval;

  /// Option 1: The specific day of the month.
  /// Positive [1, 28] (day from start) or Negative [-28, -1] (day from end).
  final int? dayOfMonth;

  /// Option 2: Nth day of the week.
  /// 1 (Mon) to 7 (Sun)
  final int? dayOfWeek;

  /// Occurrence index: 1, 2, 3, 4, or -1 (last).
  final int? occurrence;

  MonthlySchedule({
    required this.startDate,
    required this.interval,
    this.dayOfMonth,
    this.dayOfWeek,
    this.occurrence,
    super.startRelativeTime,
    super.dueRelativeTime,
    super.notificationRelativeTimes,
    super.schedulingPolicy,
    super.missedOccurrencePolicy,
  }) : assert(
         (dayOfMonth != null && dayOfWeek == null && occurrence == null) ||
             (dayOfMonth == null && dayOfWeek != null && occurrence != null),
       ),
       assert(
         dayOfMonth == null ||
             (dayOfMonth >= 1 && dayOfMonth <= 28) ||
             (dayOfMonth >= -28 && dayOfMonth <= -1),
       );

  @override
  CivilDay get scheduledDate => startDate;

  factory MonthlySchedule.fromJson(Map<String, dynamic> json) {
    final startJson = json['startRelativeTime'] as Map<String, dynamic>?;
    final dueJson = json['dueRelativeTime'] as Map<String, dynamic>?;
    final start = startJson != null
        ? RelativeTime.fromJson(startJson)
        : const RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 9, minute: 0));

    final due = dueJson != null
        ? RelativeTime.fromJson(dueJson)
        : const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          );

    final notifs = _parseNotificationRelativeTimes(json);

    final schedulingPolicy = json['schedulingPolicy'] != null
        ? SchedulingPolicy.fromJson(
            json['schedulingPolicy'] as Map<String, dynamic>,
          )
        : const FixedCalendarPolicy();

    final missedOccurrencePolicy = json['missedOccurrencePolicy'] != null
        ? MissedOccurrencePolicy.fromJson(
            json['missedOccurrencePolicy'] as Map<String, dynamic>,
          )
        : const MissedOccurrencePolicy.keepAround();

    return MonthlySchedule(
      startDate: CivilDay.fromJson(json['startDate'] as Map<String, dynamic>),
      interval: json['interval'] as int,
      dayOfMonth: json['dayOfMonth'] as int?,
      dayOfWeek: json['dayOfWeek'] as int?,
      occurrence: json['occurrence'] as int?,
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

    if (targetUtc.isBefore(startUtc)) {
      return false;
    }

    final monthsDiff =
        (date.year - startDate.year) * 12 + (date.month - startDate.month);
    if (monthsDiff < 0 || monthsDiff % interval != 0) {
      return false;
    }

    if (dayOfMonth != null) {
      if (dayOfMonth! > 0) {
        return date.day == dayOfMonth!;
      } else {
        // Counting from the end of the month
        final nextMonthUtc = DateTime.utc(date.year, date.month + 1, 1);
        final lastDayOfMonth = nextMonthUtc
            .subtract(const Duration(days: 1))
            .day;
        final targetDay = lastDayOfMonth + dayOfMonth! + 1;
        return date.day == targetDay;
      }
    } else if (dayOfWeek != null && occurrence != null) {
      if (targetUtc.weekday != dayOfWeek!) {
        return false;
      }

      if (occurrence! > 0) {
        final currentOccurrence = (date.day - 1) ~/ 7 + 1;
        return currentOccurrence == occurrence!;
      } else if (occurrence == -1) {
        // Last occurrence of that weekday in the month
        final nextWeekUtc = DateTime.utc(date.year, date.month, date.day + 7);
        return nextWeekUtc.month != date.month;
      }
    }

    return false;
  }

  @override
  CivilDay? nextOccurrenceAfter(CivilDay date) {
    var current = date;
    // Iterate day-by-day up to 10 years to find the next occurrence
    for (int i = 0; i < 365 * 10; i++) {
      final currentUtc = DateTime.utc(current.year, current.month, current.day);
      final nextUtc = currentUtc.add(const Duration(days: 1));
      current = CivilDay(
        year: nextUtc.year,
        month: nextUtc.month,
        day: nextUtc.day,
      );
      if (occursOn(current)) {
        return current;
      }
    }
    throw Exception('No occurrence found within 10 years');
  }

  @override
  TaskScheduleRule copyWithStartDate(CivilDay newStartDate) {
    return MonthlySchedule(
      startDate: newStartDate,
      interval: interval,
      dayOfMonth: dayOfMonth,
      dayOfWeek: dayOfWeek,
      occurrence: occurrence,
      startRelativeTime: startRelativeTime,
      dueRelativeTime: dueRelativeTime,
      notificationRelativeTimes: notificationRelativeTimes,
      schedulingPolicy: schedulingPolicy,
      missedOccurrencePolicy: missedOccurrencePolicy,
    );
  }

  @override
  TaskScheduleRule copyWithTiming({
    RelativeTime? startRelativeTime,
    RelativeTime? dueRelativeTime,
    List<RelativeTime>? notificationRelativeTimes,
    SchedulingPolicy? schedulingPolicy,
    MissedOccurrencePolicy? missedOccurrencePolicy,
  }) {
    return MonthlySchedule(
      startDate: startDate,
      interval: interval,
      dayOfMonth: dayOfMonth,
      dayOfWeek: dayOfWeek,
      occurrence: occurrence,
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
  Map<String, dynamic> toJson() {
    return {
      'type': 'monthly',
      'startDate': startDate.toJson(),
      'interval': interval,
      if (dayOfMonth != null) 'dayOfMonth': dayOfMonth,
      if (dayOfWeek != null) 'dayOfWeek': dayOfWeek,
      if (occurrence != null) 'occurrence': occurrence,
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
    required this.startDate,
    required this.interval,
    required this.month,
    required this.day,
    super.startRelativeTime,
    super.dueRelativeTime,
    super.notificationRelativeTimes,
    super.schedulingPolicy,
    super.missedOccurrencePolicy,
  });

  @override
  CivilDay get scheduledDate => startDate;

  factory YearlySchedule.fromJson(Map<String, dynamic> json) {
    final startJson = json['startRelativeTime'] as Map<String, dynamic>?;
    final dueJson = json['dueRelativeTime'] as Map<String, dynamic>?;
    final start = startJson != null
        ? RelativeTime.fromJson(startJson)
        : const RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 9, minute: 0));

    final due = dueJson != null
        ? RelativeTime.fromJson(dueJson)
        : const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          );

    final notifs = _parseNotificationRelativeTimes(json);

    final schedulingPolicy = json['schedulingPolicy'] != null
        ? SchedulingPolicy.fromJson(
            json['schedulingPolicy'] as Map<String, dynamic>,
          )
        : const FixedCalendarPolicy();

    final missedOccurrencePolicy = json['missedOccurrencePolicy'] != null
        ? MissedOccurrencePolicy.fromJson(
            json['missedOccurrencePolicy'] as Map<String, dynamic>,
          )
        : const MissedOccurrencePolicy.keepAround();

    return YearlySchedule(
      startDate: CivilDay.fromJson(json['startDate'] as Map<String, dynamic>),
      interval: json['interval'] as int,
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
    final startUtc = startDate.toUtcDateTime();
    final targetUtc = date.toUtcDateTime();

    if (targetUtc.isBefore(startUtc)) {
      return false;
    }

    if (date.month != month || date.day != day) {
      return false;
    }

    final yearsDiff = date.year - startDate.year;
    return yearsDiff >= 0 && yearsDiff % interval == 0;
  }

  @override
  CivilDay? nextOccurrenceAfter(CivilDay date) {
    var current = date;
    // Iterate day-by-day up to 20 years to find the next occurrence
    for (int i = 0; i < 365 * 20; i++) {
      final currentUtc = DateTime.utc(current.year, current.month, current.day);
      final nextUtc = currentUtc.add(const Duration(days: 1));
      current = CivilDay(
        year: nextUtc.year,
        month: nextUtc.month,
        day: nextUtc.day,
      );
      if (occursOn(current)) {
        return current;
      }
    }
    throw Exception('No occurrence found within 20 years');
  }

  @override
  TaskScheduleRule copyWithStartDate(CivilDay newStartDate) {
    return YearlySchedule(
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
    RelativeTime? startRelativeTime,
    RelativeTime? dueRelativeTime,
    List<RelativeTime>? notificationRelativeTimes,
    SchedulingPolicy? schedulingPolicy,
    MissedOccurrencePolicy? missedOccurrencePolicy,
  }) {
    return YearlySchedule(
      startDate: startDate,
      interval: interval,
      month: month,
      day: day,
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
  Map<String, dynamic> toJson() {
    return {
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

enum HierarchicalRecurrenceKind {
  oneOff,
  dailyFixed,
  dailyCompletionRelative,
  weeklyFixed,
  weeklyCompletionRelative,
  monthlyFixedDay,
  monthlyNthWeekday,
  monthlyCompletionRelative,
  yearlyFixed,
  yearlyCompletionRelative,
}

extension TaskScheduleRuleHierarchicalExtension on TaskScheduleRule {
  HierarchicalRecurrenceKind get hierarchicalKind {
    final self = this;
    if (self is OneOffSchedule) {
      return HierarchicalRecurrenceKind.oneOff;
    } else if (self is DailySchedule) {
      if (self.schedulingPolicy is CompletionRelativePolicy) {
        return HierarchicalRecurrenceKind.dailyCompletionRelative;
      }
      return HierarchicalRecurrenceKind.dailyFixed;
    } else if (self is WeeklySchedule) {
      if (self.schedulingPolicy is CompletionRelativePolicy) {
        return HierarchicalRecurrenceKind.weeklyCompletionRelative;
      }
      return HierarchicalRecurrenceKind.weeklyFixed;
    } else if (self is MonthlySchedule) {
      if (self.schedulingPolicy is CompletionRelativePolicy) {
        return HierarchicalRecurrenceKind.monthlyCompletionRelative;
      } else if (self.dayOfMonth != null) {
        return HierarchicalRecurrenceKind.monthlyFixedDay;
      }
      return HierarchicalRecurrenceKind.monthlyNthWeekday;
    } else if (self is YearlySchedule) {
      if (self.schedulingPolicy is CompletionRelativePolicy) {
        return HierarchicalRecurrenceKind.yearlyCompletionRelative;
      }
      return HierarchicalRecurrenceKind.yearlyFixed;
    }
    throw StateError('Unknown schedule rule type');
  }
}

TaskScheduleRule convertRuleToKind(
  TaskScheduleRule existingRule,
  HierarchicalRecurrenceKind kind,
) {
  final scheduledDate = existingRule.scheduledDate;
  final startRelativeTime = existingRule.startRelativeTime;
  final dueRelativeTime = existingRule.dueRelativeTime;
  final notificationRelativeTimes = existingRule.notificationRelativeTimes;
  final missedOccurrencePolicy = existingRule.missedOccurrencePolicy;

  // Read existing interval if possible, default to 1
  int interval = 1;
  final self = existingRule;
  if (self is DailySchedule) {
    interval = self.interval;
  } else if (self is WeeklySchedule) {
    interval = self.interval;
  } else if (self is MonthlySchedule) {
    interval = self.interval;
  } else if (self is YearlySchedule) {
    interval = self.interval;
  }

  switch (kind) {
    case HierarchicalRecurrenceKind.oneOff:
      return OneOffSchedule(
        date: scheduledDate,
        startRelativeTime: startRelativeTime,
        dueRelativeTime: dueRelativeTime,
        notificationRelativeTimes: notificationRelativeTimes,
        missedOccurrencePolicy: missedOccurrencePolicy,
      );

    case HierarchicalRecurrenceKind.dailyFixed:
      return DailySchedule(
        startDate: scheduledDate,
        interval: interval,
        startRelativeTime: startRelativeTime,
        dueRelativeTime: dueRelativeTime,
        notificationRelativeTimes: notificationRelativeTimes,
        schedulingPolicy: const FixedCalendarPolicy(),
        missedOccurrencePolicy: missedOccurrencePolicy,
      );

    case HierarchicalRecurrenceKind.dailyCompletionRelative:
      return DailySchedule(
        startDate: scheduledDate,
        interval: interval,
        startRelativeTime: startRelativeTime,
        dueRelativeTime: dueRelativeTime,
        notificationRelativeTimes: notificationRelativeTimes,
        schedulingPolicy: CompletionRelativePolicy(
          interval: Duration(days: interval),
          targetTime: startRelativeTime.time,
        ),
        missedOccurrencePolicy: missedOccurrencePolicy,
      );

    case HierarchicalRecurrenceKind.weeklyFixed:
      return WeeklySchedule(
        startDate: scheduledDate,
        interval: interval,
        daysOfWeek: {scheduledDate.toUtcDateTime().weekday},
        startRelativeTime: startRelativeTime,
        dueRelativeTime: dueRelativeTime,
        notificationRelativeTimes: notificationRelativeTimes,
        schedulingPolicy: const FixedCalendarPolicy(),
        missedOccurrencePolicy: missedOccurrencePolicy,
      );

    case HierarchicalRecurrenceKind.weeklyCompletionRelative:
      return WeeklySchedule(
        startDate: scheduledDate,
        interval: interval,
        daysOfWeek: {scheduledDate.toUtcDateTime().weekday},
        startRelativeTime: startRelativeTime,
        dueRelativeTime: dueRelativeTime,
        notificationRelativeTimes: notificationRelativeTimes,
        schedulingPolicy: CompletionRelativePolicy(
          interval: Duration(days: interval * 7),
          targetTime: startRelativeTime.time,
        ),
        missedOccurrencePolicy: missedOccurrencePolicy,
      );

    case HierarchicalRecurrenceKind.monthlyFixedDay:
      return MonthlySchedule(
        startDate: scheduledDate,
        interval: interval,
        dayOfMonth: scheduledDate.day <= 28 ? scheduledDate.day : 28,
        startRelativeTime: startRelativeTime,
        dueRelativeTime: dueRelativeTime,
        notificationRelativeTimes: notificationRelativeTimes,
        schedulingPolicy: const FixedCalendarPolicy(),
        missedOccurrencePolicy: missedOccurrencePolicy,
      );

    case HierarchicalRecurrenceKind.monthlyNthWeekday:
      final weekday = scheduledDate.toUtcDateTime().weekday;
      final occurrence = (scheduledDate.day - 1) ~/ 7 + 1;
      return MonthlySchedule(
        startDate: scheduledDate,
        interval: interval,
        dayOfWeek: weekday,
        occurrence: occurrence,
        startRelativeTime: startRelativeTime,
        dueRelativeTime: dueRelativeTime,
        notificationRelativeTimes: notificationRelativeTimes,
        schedulingPolicy: const FixedCalendarPolicy(),
        missedOccurrencePolicy: missedOccurrencePolicy,
      );

    case HierarchicalRecurrenceKind.monthlyCompletionRelative:
      return MonthlySchedule(
        startDate: scheduledDate,
        interval: interval,
        dayOfMonth: scheduledDate.day <= 28 ? scheduledDate.day : 28,
        startRelativeTime: startRelativeTime,
        dueRelativeTime: dueRelativeTime,
        notificationRelativeTimes: notificationRelativeTimes,
        schedulingPolicy: CompletionRelativePolicy(
          interval: Duration(days: interval * 30),
          targetTime: startRelativeTime.time,
        ),
        missedOccurrencePolicy: missedOccurrencePolicy,
      );

    case HierarchicalRecurrenceKind.yearlyFixed:
      return YearlySchedule(
        startDate: scheduledDate,
        interval: interval,
        month: scheduledDate.month,
        day: scheduledDate.day,
        startRelativeTime: startRelativeTime,
        dueRelativeTime: dueRelativeTime,
        notificationRelativeTimes: notificationRelativeTimes,
        schedulingPolicy: const FixedCalendarPolicy(),
        missedOccurrencePolicy: missedOccurrencePolicy,
      );

    case HierarchicalRecurrenceKind.yearlyCompletionRelative:
      return YearlySchedule(
        startDate: scheduledDate,
        interval: interval,
        month: scheduledDate.month,
        day: scheduledDate.day,
        startRelativeTime: startRelativeTime,
        dueRelativeTime: dueRelativeTime,
        notificationRelativeTimes: notificationRelativeTimes,
        schedulingPolicy: CompletionRelativePolicy(
          interval: Duration(days: interval * 365),
          targetTime: startRelativeTime.time,
        ),
        missedOccurrencePolicy: missedOccurrencePolicy,
      );
  }
}
