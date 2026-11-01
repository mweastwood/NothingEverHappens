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
  @override
  final int interval;

  /// Option 1: The specific day of the month.
  /// Positive [1, 28] (day from start) or Negative [-28, -1] (day from end).
  final int? dayOfMonth;

  /// Option 2: Nth day of the week.
  /// 1 (Mon) to 7 (Sun)
  final int? dayOfWeek;

  /// Occurrence index: 1, 2, 3, 4, or -1 (last).
  final int? occurrence;

  @override
  int get futureInstancesCount => 3;

  MonthlySchedule({
    String? id,
    String? scheduleId,
    required this.startDate,
    required int interval,
    this.dayOfMonth,
    this.dayOfWeek,
    this.occurrence,
    super.startRelativeTime,
    super.dueRelativeTime,
    super.notificationRelativeTimes,
    super.schedulingPolicy,
    super.missedOccurrencePolicy,
  })  : interval = TaskScheduleRule.parseInterval(interval),
        super(
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
    final base = TaskScheduleRule.parseBaseJson(json);

    return MonthlySchedule(
      id: base.id,
      scheduleId: base.scheduleId,
      startDate: CivilDay.fromJson(
        Map<String, dynamic>.from(json['startDate'] as Map),
      ),
      interval: TaskScheduleRule.parseInterval(json['interval']),
      dayOfMonth: json['dayOfMonth'] as int?,
      dayOfWeek: json['dayOfWeek'] as int?,
      occurrence: json['occurrence'] as int?,
      startRelativeTime: base.startRelativeTime,
      dueRelativeTime: base.dueRelativeTime,
      notificationRelativeTimes: base.notificationRelativeTimes,
      schedulingPolicy: base.schedulingPolicy,
      missedOccurrencePolicy: base.missedOccurrencePolicy,
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

    final monthsDiff =
        (date.year - startDate.year) * 12 + (date.month - startDate.month);
    if (monthsDiff < 0 || monthsDiff % safeInterval != 0) {
      return false;
    }

    if (dayOfMonth != null) {
      if (dayOfMonth! > 0) {
        return date.day == dayOfMonth!;
      } else {
        // Counting from the end of the month
        final nextMonthUtc = DateTime.utc(date.year, date.month + 1, 1);
        final lastDayOfMonth =
            nextMonthUtc.subtract(const Duration(days: 1)).day;
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
        final lastDayOfMonth =
            nextMonthUtc.subtract(const Duration(days: 1)).day;
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
    final safeInterval = interval <= 0 ? 1 : interval;
    final startTotalMonths = startDate.year * 12 + (startDate.month - 1);
    final refTotalMonths = date.year * 12 + (date.month - 1);

    int cycle;
    if (refTotalMonths < startTotalMonths) {
      cycle = 0;
    } else {
      final monthsDiff = refTotalMonths - startTotalMonths;
      cycle = monthsDiff ~/ safeInterval;
    }

    // Search up to 10 years (120 months)
    for (int i = 0; i < 120; i++, cycle++) {
      final targetTotalMonths = startTotalMonths + cycle * safeInterval;
      final targetYear = targetTotalMonths ~/ 12;
      final targetMonth = (targetTotalMonths % 12) + 1;

      final occurrenceDay = _occurrenceInMonth(targetYear, targetMonth);
      if (occurrenceDay == null) continue;

      if (occurrenceDay.isAfter(date) && !occurrenceDay.isBefore(startDate)) {
        return occurrenceDay;
      }
    }
    return null;
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
    return MonthlySchedule(
      id: id ?? this.id,
      scheduleId: scheduleId ?? this.scheduleId,
      startDate: startDate,
      interval: interval,
      dayOfMonth: dayOfMonth,
      dayOfWeek: dayOfWeek,
      occurrence: occurrence,
      startRelativeTime: startRelativeTime ?? this.startRelativeTime,
      dueRelativeTime: dueRelativeTime ?? this.dueRelativeTime,
      notificationRelativeTimes:
          notificationRelativeTimes ?? this.notificationRelativeTimes,
      schedulingPolicy: TaskScheduleRule.resolveUpdatedSchedulingPolicy(
        schedulingPolicy,
        this.schedulingPolicy,
        startRelativeTime,
      ),
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
  Map<String, dynamic> toJson() => baseToJson('monthly', {
        'startDate': startDate.toJson(),
        'interval': interval,
        if (dayOfMonth != null) 'dayOfMonth': dayOfMonth,
        if (dayOfWeek != null) 'dayOfWeek': dayOfWeek,
        if (occurrence != null) 'occurrence': occurrence,
      });
}
