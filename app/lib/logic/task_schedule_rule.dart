import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'civil_day.dart';
import 'relative_time.dart';
import 'scheduling_policy.dart';
import 'missed_occurrence_policy.dart';
import 'app_clock.dart';

/// Defines how often a task reoccurs.
List<RelativeTime> _parseNotificationRelativeTimes(Map<String, dynamic> json) {
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

abstract class TaskScheduleRule {
  static String generateId() => 'R-${const Uuid().v4()}';

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

    final notifs = _parseNotificationRelativeTimes(json);

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

/// A schedule for a task that repeats every N days.
class DailySchedule extends TaskScheduleRule {
  /// The date from which the repetition interval starts.
  CivilDay startDate;

  /// The number of days between occurrences.
  int interval;

  DailySchedule({
    String? id,
    String? scheduleId,
    required this.startDate,
    required this.interval,
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

  factory DailySchedule.fromJson(Map<String, dynamic> json) {
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

    final notifs = _parseNotificationRelativeTimes(json);

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

    return DailySchedule(
      id: id,
      scheduleId: scheduleId,
      startDate: CivilDay.fromJson(
        Map<String, dynamic>.from(json['startDate'] as Map),
      ),
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
      id: id,
      scheduleId: scheduleId,
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
    return DailySchedule(
      id: id ?? this.id,
      scheduleId: scheduleId ?? this.scheduleId,
      startDate: startDate,
      interval: interval,
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
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scheduleId': scheduleId,
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

    final notifs = _parseNotificationRelativeTimes(json);

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
    String? id,
    String? scheduleId,
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
  }) : super(
         id: id ?? TaskScheduleRule.generateId(),
         scheduleId: scheduleId ?? '',
       ) {
    if (!((dayOfMonth != null && dayOfWeek == null && occurrence == null) ||
        (dayOfMonth == null && dayOfWeek != null && occurrence != null))) {
      throw ArgumentError();
    }
    if (!(dayOfMonth == null ||
        (dayOfMonth! >= 1 && dayOfMonth! <= 28) ||
        (dayOfMonth! >= -28 && dayOfMonth! <= -1))) {
      throw ArgumentError();
    }
  }

  @override
  CivilDay get scheduledDate => startDate;

  factory MonthlySchedule.fromJson(Map<String, dynamic> json) {
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

    final notifs = _parseNotificationRelativeTimes(json);

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

    return MonthlySchedule(
      id: id,
      scheduleId: scheduleId,
      startDate: CivilDay.fromJson(
        Map<String, dynamic>.from(json['startDate'] as Map),
      ),
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
      id: id,
      scheduleId: scheduleId,
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
    return MonthlySchedule(
      id: id ?? this.id,
      scheduleId: scheduleId ?? this.scheduleId,
      startDate: startDate,
      interval: interval,
      dayOfMonth: dayOfMonth,
      dayOfWeek: dayOfWeek,
      occurrence: occurrence,
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
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scheduleId': scheduleId,
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
    String? id,
    String? scheduleId,
    required this.startDate,
    required this.interval,
    required this.month,
    required this.day,
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

    final notifs = _parseNotificationRelativeTimes(json);

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

    return YearlySchedule(
      id: id,
      scheduleId: scheduleId,
      startDate: CivilDay.fromJson(
        Map<String, dynamic>.from(json['startDate'] as Map),
      ),
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
  final id = existingRule.id;
  final scheduleId = existingRule.scheduleId;
  var scheduledDate = existingRule.scheduledDate;
  var startRelativeTime = existingRule.startRelativeTime;
  final dueRelativeTime = existingRule.dueRelativeTime;
  final notificationRelativeTimes = existingRule.notificationRelativeTimes;
  final missedOccurrencePolicy = existingRule.missedOccurrencePolicy;

  if (kind != HierarchicalRecurrenceKind.oneOff) {
    final now = AppClock.now;
    final tomorrow = CivilDay.fromDateTime(now.add(const Duration(days: 1)));
    if (existingRule is OneOffSchedule &&
        scheduledDate == tomorrow &&
        startRelativeTime.dayOffset == -1) {
      scheduledDate = CivilDay.fromDateTime(now);
      startRelativeTime = RelativeTime(
        dayOffset: 0,
        time: startRelativeTime.time,
      );
    }
  }

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
        id: id,
        scheduleId: scheduleId,
        date: scheduledDate,
        startRelativeTime: startRelativeTime,
        dueRelativeTime: dueRelativeTime,
        notificationRelativeTimes: notificationRelativeTimes,
        missedOccurrencePolicy: missedOccurrencePolicy,
      );

    case HierarchicalRecurrenceKind.dailyFixed:
      return DailySchedule(
        id: id,
        scheduleId: scheduleId,
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
        id: id,
        scheduleId: scheduleId,
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
        id: id,
        scheduleId: scheduleId,
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
        id: id,
        scheduleId: scheduleId,
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
        id: id,
        scheduleId: scheduleId,
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
        id: id,
        scheduleId: scheduleId,
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
        id: id,
        scheduleId: scheduleId,
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
        id: id,
        scheduleId: scheduleId,
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
        id: id,
        scheduleId: scheduleId,
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
