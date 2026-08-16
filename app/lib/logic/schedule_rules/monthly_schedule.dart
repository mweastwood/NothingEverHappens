import 'package:flutter/material.dart';
import '../civil_day.dart';
import '../relative_time.dart';
import '../scheduling_policy.dart';
import '../missed_occurrence_policy.dart';
import 'task_schedule_rule.dart';

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
      throw ArgumentError(
        'Either dayOfMonth or both dayOfWeek and occurrence must be specified.',
      );
    }
    if (!(dayOfMonth == null ||
        (dayOfMonth! >= 1 && dayOfMonth! <= 28) ||
        (dayOfMonth! >= -28 && dayOfMonth! <= -1))) {
      throw ArgumentError(
        'dayOfMonth must be between 1 and 28 or between -28 and -1.',
      );
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

  CivilDay? _occurrenceInMonth(int year, int month) {
    if (dayOfMonth != null) {
      if (dayOfMonth! > 0) {
        final lastDayOfMonth = DateTime.utc(
          year,
          month + 1,
          1,
        ).subtract(const Duration(days: 1)).day;
        if (dayOfMonth! > lastDayOfMonth) {
          return null;
        }
        return CivilDay(year: year, month: month, day: dayOfMonth!);
      } else {
        final nextMonthUtc = DateTime.utc(year, month + 1, 1);
        final lastDayOfMonth = nextMonthUtc
            .subtract(const Duration(days: 1))
            .day;
        final targetDay = lastDayOfMonth + dayOfMonth! + 1;
        return CivilDay(year: year, month: month, day: targetDay);
      }
    } else if (dayOfWeek != null && occurrence != null) {
      final nextMonthUtc = DateTime.utc(year, month + 1, 1);
      final lastDayOfMonth = nextMonthUtc.subtract(const Duration(days: 1)).day;

      if (occurrence! > 0) {
        final firstDayWeekday = DateTime.utc(year, month, 1).weekday;
        final firstOccurrenceDay = 1 + ((dayOfWeek! - firstDayWeekday + 7) % 7);
        final targetDay = firstOccurrenceDay + (occurrence! - 1) * 7;
        if (targetDay <= lastDayOfMonth) {
          return CivilDay(year: year, month: month, day: targetDay);
        }
        return null;
      } else if (occurrence == -1) {
        final lastDayWeekday = DateTime.utc(
          year,
          month,
          lastDayOfMonth,
        ).weekday;
        final targetDay =
            lastDayOfMonth - ((lastDayWeekday - dayOfWeek! + 7) % 7);
        return CivilDay(year: year, month: month, day: targetDay);
      }
    }
    return null;
  }

  @override
  CivilDay? nextOccurrenceAfter(CivilDay date) {
    final startTotalMonths = startDate.year * 12 + (startDate.month - 1);
    final refTotalMonths = date.year * 12 + (date.month - 1);

    int cycle;
    if (refTotalMonths < startTotalMonths) {
      cycle = 0;
    } else {
      final monthsDiff = refTotalMonths - startTotalMonths;
      cycle = monthsDiff ~/ interval;
    }

    // Search up to 10 years (120 months)
    for (int i = 0; i < 120; i++, cycle++) {
      final targetTotalMonths = startTotalMonths + cycle * interval;
      final targetYear = targetTotalMonths ~/ 12;
      final targetMonth = (targetTotalMonths % 12) + 1;

      final occurrenceDay = _occurrenceInMonth(targetYear, targetMonth);
      if (occurrenceDay == null) continue;

      if (occurrenceDay.isAfter(date) && !occurrenceDay.isBefore(startDate)) {
        return occurrenceDay;
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
  bool hasSameRecurrence(TaskScheduleRule other) {
    if (other is! MonthlySchedule) return false;
    if (interval != other.interval) return false;
    if (dayOfMonth != other.dayOfMonth) return false;
    if (dayOfWeek != other.dayOfWeek) return false;
    if (occurrence != other.occurrence) return false;
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
