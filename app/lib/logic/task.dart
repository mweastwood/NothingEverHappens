import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'civil_day.dart';
import 'relative_time.dart';
import 'task_delta.dart';

enum MissedPolicy { rollover, skip, shift, stack }

/// Result of a task update operation.
typedef TaskModification = ({Task newTask, TaskDelta delta});

/// Represents a start and due time of day for an occurrence on a given day.
class DailyOccurrenceTime {
  final TimeOfDay startTime;
  final TimeOfDay dueTime;
  final TimeOfDay? notificationTime;

  const DailyOccurrenceTime({
    required this.startTime,
    required this.dueTime,
    this.notificationTime,
  });

  factory DailyOccurrenceTime.fromJson(Map<String, dynamic> json) {
    return DailyOccurrenceTime(
      startTime: TimeOfDay(
        hour: json['startHour'] as int,
        minute: json['startMinute'] as int,
      ),
      dueTime: TimeOfDay(
        hour: json['dueHour'] as int,
        minute: json['dueMinute'] as int,
      ),
      notificationTime:
          json['notificationHour'] != null && json['notificationMinute'] != null
          ? TimeOfDay(
              hour: json['notificationHour'] as int,
              minute: json['notificationMinute'] as int,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startHour': startTime.hour,
      'startMinute': startTime.minute,
      'dueHour': dueTime.hour,
      'dueMinute': dueTime.minute,
      if (notificationTime != null) 'notificationHour': notificationTime!.hour,
      if (notificationTime != null)
        'notificationMinute': notificationTime!.minute,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DailyOccurrenceTime &&
        other.startTime == startTime &&
        other.dueTime == dueTime &&
        other.notificationTime == notificationTime;
  }

  @override
  int get hashCode => Object.hash(startTime, dueTime, notificationTime);

  @override
  String toString() {
    final notifStr = notificationTime != null
        ? '${notificationTime!.hour}:${notificationTime!.minute.toString().padLeft(2, '0')}'
        : 'none';
    return 'DailyOccurrenceTime(start: ${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')}, due: ${dueTime.hour}:${dueTime.minute.toString().padLeft(2, '0')}, notification: $notifStr)';
  }
}

/// Defines how often a task reoccurs.
abstract class TaskSchedule {
  const TaskSchedule();

  /// The scheduled date of this occurrence.
  CivilDay get scheduledDate;

  /// Checks if the task occurs on the given [date].
  bool occursOn(CivilDay date);

  /// Calculates the next occurrence of the task strictly after [date].
  CivilDay nextOccurrenceAfter(CivilDay date);

  /// Creates a copy of this schedule with a new scheduled/start date.
  TaskSchedule copyWithStartDate(CivilDay newStartDate);

  Map<String, dynamic> toJson();

  factory TaskSchedule.fromJson(Map<String, dynamic> json) {
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
class OneOffSchedule extends TaskSchedule {
  /// The specific date the task occurs.
  CivilDay date;

  OneOffSchedule({required this.date});

  @override
  CivilDay get scheduledDate => date;

  factory OneOffSchedule.fromJson(Map<String, dynamic> json) {
    return OneOffSchedule(
      date: CivilDay.fromJson(json['date'] as Map<String, dynamic>),
    );
  }

  @override
  bool occursOn(CivilDay date) {
    return this.date == date;
  }

  @override
  CivilDay nextOccurrenceAfter(CivilDay date) {
    return this.date;
  }

  @override
  TaskSchedule copyWithStartDate(CivilDay newStartDate) {
    return OneOffSchedule(date: newStartDate);
  }

  @override
  Map<String, dynamic> toJson() {
    return {'type': 'oneOff', 'date': date.toJson()};
  }
}

/// A schedule for a task that repeats every N days.
class DailySchedule extends TaskSchedule {
  /// The date from which the repetition interval starts.
  CivilDay startDate;

  /// The number of days between occurrences.
  int interval;

  DailySchedule({required this.startDate, required this.interval});

  @override
  CivilDay get scheduledDate => startDate;

  factory DailySchedule.fromJson(Map<String, dynamic> json) {
    return DailySchedule(
      startDate: CivilDay.fromJson(json['startDate'] as Map<String, dynamic>),
      interval: json['interval'] as int,
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
  CivilDay nextOccurrenceAfter(CivilDay date) {
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
  TaskSchedule copyWithStartDate(CivilDay newStartDate) {
    return DailySchedule(startDate: newStartDate, interval: interval);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'daily',
      'startDate': startDate.toJson(),
      'interval': interval,
    };
  }
}

/// A schedule for a task that repeats every N weeks on specific days.
class WeeklySchedule extends TaskSchedule {
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
  });

  @override
  CivilDay get scheduledDate => startDate;

  factory WeeklySchedule.fromJson(Map<String, dynamic> json) {
    return WeeklySchedule(
      startDate: CivilDay.fromJson(json['startDate'] as Map<String, dynamic>),
      interval: json['interval'] as int,
      daysOfWeek: (json['daysOfWeek'] as List<dynamic>).cast<int>().toSet(),
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
  CivilDay nextOccurrenceAfter(CivilDay date) {
    var current = date;
    while (true) {
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
  }

  @override
  TaskSchedule copyWithStartDate(CivilDay newStartDate) {
    return WeeklySchedule(
      startDate: newStartDate,
      interval: interval,
      daysOfWeek: daysOfWeek,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'weekly',
      'startDate': startDate.toJson(),
      'interval': interval,
      'daysOfWeek': daysOfWeek.toList(),
    };
  }
}

/// A schedule for a task that repeats every N months.
class MonthlySchedule extends TaskSchedule {
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
    return MonthlySchedule(
      startDate: CivilDay.fromJson(json['startDate'] as Map<String, dynamic>),
      interval: json['interval'] as int,
      dayOfMonth: json['dayOfMonth'] as int?,
      dayOfWeek: json['dayOfWeek'] as int?,
      occurrence: json['occurrence'] as int?,
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
  CivilDay nextOccurrenceAfter(CivilDay date) {
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
  TaskSchedule copyWithStartDate(CivilDay newStartDate) {
    return MonthlySchedule(
      startDate: newStartDate,
      interval: interval,
      dayOfMonth: dayOfMonth,
      dayOfWeek: dayOfWeek,
      occurrence: occurrence,
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
    };
  }
}

/// A schedule for a task that repeats every N years.
class YearlySchedule extends TaskSchedule {
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
  });

  @override
  CivilDay get scheduledDate => startDate;

  factory YearlySchedule.fromJson(Map<String, dynamic> json) {
    return YearlySchedule(
      startDate: CivilDay.fromJson(json['startDate'] as Map<String, dynamic>),
      interval: json['interval'] as int,
      month: json['month'] as int,
      day: json['day'] as int,
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
  CivilDay nextOccurrenceAfter(CivilDay date) {
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
  TaskSchedule copyWithStartDate(CivilDay newStartDate) {
    return YearlySchedule(
      startDate: newStartDate,
      interval: interval,
      month: month,
      day: day,
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
    };
  }
}

/// Represents a single task in the todo list.
class Task {
  /// Unique identifier for the task.
  String id;

  /// The title of the task.
  String title;

  /// Detailed description of the task.
  String description;

  /// The start relative time.
  RelativeTime startRelativeTime;

  /// The due relative time.
  RelativeTime dueRelativeTime;

  /// The recurrence schedule for the task.
  TaskSchedule schedule;

  /// The list of daily occurrence times for tasks scheduled multiple times per day.
  List<DailyOccurrenceTime> dailyTimes;

  /// The index of the currently active occurrence time in [dailyTimes].
  int activeOccurrenceIndex;

  /// The estimated effort for the task (optional).
  Duration? estimatedDuration;

  /// The policy to apply when a task occurrence is missed.
  MissedPolicy missedPolicy;

  /// Whether this task represents a master/template recurring schedule.
  bool isMaster;

  /// The date up to which stack occurrences have been spawned.
  CivilDay? lastSpawnedDate;

  /// If this task is a spawned occurrence of a master task, this is the parent task's ID.
  String? parentTaskId;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.startRelativeTime,
    required this.dueRelativeTime,
    required this.schedule,
    this.dailyTimes = const [],
    this.activeOccurrenceIndex = 0,
    this.estimatedDuration,
    this.missedPolicy = MissedPolicy.rollover,
    this.isMaster = false,
    this.lastSpawnedDate,
    this.parentTaskId,
  });

  /// The starting day of this occurrence.
  CivilDay get startDate {
    final startDateTime = startRelativeTime.referenceTo(schedule.scheduledDate);
    return CivilDay.fromDateTime(startDateTime);
  }

  factory Task.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot, [
    SnapshotOptions? options,
  ]) {
    final data = snapshot.data();
    if (data == null) {
      throw Exception('Data is null for document ${snapshot.id}');
    }
    final dailyTimesRaw = data['dailyTimes'] as List<dynamic>?;
    final dailyTimes = dailyTimesRaw != null
        ? dailyTimesRaw
              .map(
                (item) =>
                    DailyOccurrenceTime.fromJson(item as Map<String, dynamic>),
              )
              .toList()
        : <DailyOccurrenceTime>[];

    final missedPolicyStr = data['missedPolicy'] as String? ?? 'rollover';
    final missedPolicy = MissedPolicy.values.firstWhere(
      (e) => e.name == missedPolicyStr,
      orElse: () => MissedPolicy.rollover,
    );

    final isMaster = data['isMaster'] as bool? ?? false;
    final lastSpawnedDateRaw = data['lastSpawnedDate'] as Map<String, dynamic>?;
    final lastSpawnedDate = lastSpawnedDateRaw != null
        ? CivilDay.fromJson(lastSpawnedDateRaw)
        : null;
    final parentTaskId = data['parentTaskId'] as String?;

    return Task(
      id: snapshot.id,
      title: data['title'] as String? ?? 'Untitled',
      description: data['description'] as String? ?? '',
      startRelativeTime: RelativeTime.fromJson(
        data['startRelativeTime'] as Map<String, dynamic>,
      ),
      dueRelativeTime: RelativeTime.fromJson(
        data['dueRelativeTime'] as Map<String, dynamic>,
      ),
      schedule: TaskSchedule.fromJson(data['schedule'] as Map<String, dynamic>),
      dailyTimes: dailyTimes,
      activeOccurrenceIndex: data['activeOccurrenceIndex'] as int? ?? 0,
      estimatedDuration: data['estimatedDuration'] != null
          ? Duration(minutes: data['estimatedDuration'] as int)
          : null,
      missedPolicy: missedPolicy,
      isMaster: isMaster,
      lastSpawnedDate: lastSpawnedDate,
      parentTaskId: parentTaskId,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'startRelativeTime': startRelativeTime.toJson(),
      'dueRelativeTime': dueRelativeTime.toJson(),
      'schedule': schedule.toJson(),
      'dailyTimes': dailyTimes.map((t) => t.toJson()).toList(),
      'activeOccurrenceIndex': activeOccurrenceIndex,
      'estimatedDuration': estimatedDuration?.inMinutes,
      'missedPolicy': missedPolicy.name,
      'isMaster': isMaster,
      if (lastSpawnedDate != null) 'lastSpawnedDate': lastSpawnedDate!.toJson(),
      if (parentTaskId != null) 'parentTaskId': parentTaskId,
    };
  }

  static final _uuid = Uuid();

  /// Updates multiple fields of the task and returns the modified task and delta.
  TaskModification edit({
    required String newTitle,
    required String newDescription,
    required RelativeTime newStartRelativeTime,
    required RelativeTime newDueRelativeTime,
    required TaskSchedule newSchedule,
    required List<DailyOccurrenceTime> newDailyTimes,
    required Duration? newEstimatedDuration,
    required String userId,
    required MissedPolicy newMissedPolicy,
    required bool newIsMaster,
    required CivilDay? newLastSpawnedDate,
  }) {
    final newTask = _copyWith(
      title: newTitle,
      description: newDescription,
      startRelativeTime: newStartRelativeTime,
      dueRelativeTime: newDueRelativeTime,
      schedule: newSchedule,
      dailyTimes: newDailyTimes,
      estimatedDuration: newEstimatedDuration,
      clearEstimatedDuration: newEstimatedDuration == null,
      missedPolicy: newMissedPolicy,
      isMaster: newIsMaster,
      lastSpawnedDate: newLastSpawnedDate,
      clearLastSpawnedDate: newLastSpawnedDate == null,
    );

    final changes = <String, dynamic>{};
    if (newTitle != title) changes['title'] = newTitle;
    if (newDescription != description) changes['description'] = newDescription;
    if (newStartRelativeTime != startRelativeTime) {
      changes['startRelativeTime'] = newStartRelativeTime.toJson();
    }
    if (newDueRelativeTime != dueRelativeTime) {
      changes['dueRelativeTime'] = newDueRelativeTime.toJson();
    }

    final oldScheduleJson = schedule.toJson();
    final newScheduleJson = newSchedule.toJson();
    if (oldScheduleJson.toString() != newScheduleJson.toString()) {
      changes['schedule'] = newScheduleJson;
    }

    final oldDailyTimesJson = dailyTimes
        .map((t) => t.toJson())
        .toList()
        .toString();
    final newDailyTimesJson = newDailyTimes
        .map((t) => t.toJson())
        .toList()
        .toString();
    if (oldDailyTimesJson != newDailyTimesJson) {
      changes['dailyTimes'] = newDailyTimes.map((t) => t.toJson()).toList();
    }

    if (estimatedDuration != newEstimatedDuration) {
      changes['estimatedDuration'] = newEstimatedDuration?.inMinutes;
    }

    if (missedPolicy != newMissedPolicy) {
      changes['missedPolicy'] = newMissedPolicy.name;
    }

    if (isMaster != newIsMaster) {
      changes['isMaster'] = newIsMaster;
    }

    if (lastSpawnedDate != newLastSpawnedDate) {
      changes['lastSpawnedDate'] = newLastSpawnedDate?.toJson();
    }

    final now = AppClock.now;
    final delta = TaskDelta(
      id: _uuid.v4(),
      taskId: id,
      timestamp: now,
      expiresAt: now.add(const Duration(days: 90)),
      operation: 'update',
      changedFields: changes,
      userId: userId,
    );

    return (newTask: newTask, delta: delta);
  }

  /// Updates the title and returns the modified task and delta.
  TaskModification updateTitle(String newTitle, String userId) {
    final newTask = _copyWith(title: newTitle);
    final delta = _createUpdateDelta(
      field: 'title',
      newValue: newTitle,
      userId: userId,
    );
    return (newTask: newTask, delta: delta);
  }

  /// Updates the description and returns the modified task and delta.
  TaskModification updateDescription(String newDescription, String userId) {
    final newTask = _copyWith(description: newDescription);
    final delta = _createUpdateDelta(
      field: 'description',
      newValue: newDescription,
      userId: userId,
    );
    return (newTask: newTask, delta: delta);
  }

  /// Updates the schedule and returns the modified task and delta.
  TaskModification reschedule(TaskSchedule newSchedule, String userId) {
    final newTask = _copyWith(schedule: newSchedule);
    final delta = _createUpdateDelta(
      field: 'schedule',
      newValue: newSchedule.toJson(),
      userId: userId,
    );
    return (newTask: newTask, delta: delta);
  }

  /// Updates the start relative time and returns the modified task and delta.
  TaskModification updateStart(RelativeTime newStart, String userId) {
    final newTask = _copyWith(startRelativeTime: newStart);
    final delta = _createUpdateDelta(
      field: 'startRelativeTime',
      newValue: newStart.toJson(),
      userId: userId,
    );
    return (newTask: newTask, delta: delta);
  }

  /// Updates the due relative time and returns the modified task and delta.
  TaskModification updateDue(RelativeTime newDue, String userId) {
    final newTask = _copyWith(dueRelativeTime: newDue);
    final delta = _createUpdateDelta(
      field: 'dueRelativeTime',
      newValue: newDue.toJson(),
      userId: userId,
    );
    return (newTask: newTask, delta: delta);
  }

  Task _copyWith({
    String? title,
    String? description,
    RelativeTime? startRelativeTime,
    RelativeTime? dueRelativeTime,
    TaskSchedule? schedule,
    List<DailyOccurrenceTime>? dailyTimes,
    int? activeOccurrenceIndex,
    Duration? estimatedDuration,
    bool clearEstimatedDuration = false,
    MissedPolicy? missedPolicy,
    bool? isMaster,
    CivilDay? lastSpawnedDate,
    bool clearLastSpawnedDate = false,
    String? parentTaskId,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      startRelativeTime: startRelativeTime ?? this.startRelativeTime,
      dueRelativeTime: dueRelativeTime ?? this.dueRelativeTime,
      schedule: schedule ?? this.schedule,
      dailyTimes: dailyTimes ?? this.dailyTimes,
      activeOccurrenceIndex:
          activeOccurrenceIndex ?? this.activeOccurrenceIndex,
      estimatedDuration: clearEstimatedDuration
          ? null
          : (estimatedDuration ?? this.estimatedDuration),
      missedPolicy: missedPolicy ?? this.missedPolicy,
      isMaster: isMaster ?? this.isMaster,
      lastSpawnedDate: clearLastSpawnedDate
          ? null
          : (lastSpawnedDate ?? this.lastSpawnedDate),
      parentTaskId: parentTaskId ?? this.parentTaskId,
    );
  }

  TaskDelta _createUpdateDelta({
    required String field,
    required dynamic newValue,
    required String userId,
  }) {
    final now = AppClock.now;
    return TaskDelta(
      id: _uuid.v4(),
      taskId: id,
      timestamp: now,
      expiresAt: now.add(const Duration(days: 90)),
      operation: 'update',
      changedFields: {field: newValue},
      userId: userId,
    );
  }

  /// Checks if the task is overdue at [current] time.
  bool isOverdue(DateTime current) {
    final dueDateTime = dueRelativeTime.referenceTo(schedule.scheduledDate);
    return current.isAfter(dueDateTime);
  }
}
