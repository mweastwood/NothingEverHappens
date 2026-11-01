import '../civil_day.dart';
import '../relative_time.dart';
import '../scheduling_policy.dart';
import '../missed_occurrence_policy.dart';
import 'task_schedule_rule.dart';

/// A schedule for a task that happens exactly once.
class OneOffSchedule extends TaskScheduleRule {
  /// The specific date the task occurs.
  CivilDay date;

  @override
  int get futureInstancesCount => 1;

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
    final base = TaskScheduleRule.parseBaseJson(json);

    return OneOffSchedule(
      id: base.id,
      scheduleId: base.scheduleId,
      date: CivilDay.fromJson(Map<String, dynamic>.from(json['date'] as Map)),
      startRelativeTime: base.startRelativeTime,
      dueRelativeTime: base.dueRelativeTime,
      notificationRelativeTimes: base.notificationRelativeTimes,
      schedulingPolicy: base.schedulingPolicy,
      missedOccurrencePolicy: base.missedOccurrencePolicy,
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
    if (other is! OneOffSchedule) return false;
    return date == other.date;
  }

  @override
  Map<String, dynamic> toJson() =>
      baseToJson('oneOff', {'date': date.toJson()});
}
