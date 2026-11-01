import '../civil_day.dart';
import '../relative_time.dart';
import '../scheduling_policy.dart';
import '../missed_occurrence_policy.dart';
import 'task_schedule_rule.dart';

/// A schedule for a task that repeats every N days.
class DailySchedule extends TaskScheduleRule {
  /// The date from which the repetition interval starts.
  CivilDay startDate;

  /// The number of days between occurrences.
  @override
  int interval;

  @override
  int get futureInstancesCount => 10;

  DailySchedule({
    String? id,
    String? scheduleId,
    required this.startDate,
    required int interval,
    super.startRelativeTime,
    super.dueRelativeTime,
    super.notificationRelativeTimes,
    super.schedulingPolicy,
    super.missedOccurrencePolicy,
  })  : interval = TaskScheduleRule.parseInterval(interval),
        super(
          id: id ?? TaskScheduleRule.generateId(),
          scheduleId: scheduleId ?? '',
        );

  @override
  CivilDay get scheduledDate => startDate;

  factory DailySchedule.fromJson(Map<String, dynamic> json) {
    final base = TaskScheduleRule.parseBaseJson(json);

    return DailySchedule(
      id: base.id,
      scheduleId: base.scheduleId,
      startDate: CivilDay.fromJson(
        Map<String, dynamic>.from(json['startDate'] as Map),
      ),
      interval: TaskScheduleRule.parseInterval(json['interval']),
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

    // Before start date?
    if (targetUtc.isBefore(startUtc)) {
      return false;
    }

    final difference = targetUtc.difference(startUtc).inDays;
    return difference % safeInterval == 0;
  }

  @override
  CivilDay? nextOccurrenceAfter(CivilDay date) {
    final safeInterval = interval <= 0 ? 1 : interval;
    final startUtc = startDate.toUtcDateTime();
    final currentUtc = date.toUtcDateTime();

    if (currentUtc.isBefore(startUtc)) {
      return startDate;
    }

    final daysDiff = currentUtc.difference(startUtc).inDays;
    final intervals = daysDiff ~/ safeInterval;
    final occurrenceUtc = startUtc.add(
      Duration(days: intervals * safeInterval),
    );

    final nextUtc = currentUtc.isBefore(occurrenceUtc)
        ? occurrenceUtc
        : startUtc.add(Duration(days: (intervals + 1) * safeInterval));

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
    return DailySchedule(
      id: id ?? this.id,
      scheduleId: scheduleId ?? this.scheduleId,
      startDate: startDate,
      interval: interval,
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
    if (other is! DailySchedule) return false;
    return interval == other.interval;
  }

  @override
  Map<String, dynamic> toJson() => baseToJson('daily', {
        'startDate': startDate.toJson(),
        'interval': interval,
      });
}
