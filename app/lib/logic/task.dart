import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'civil_day.dart';
import 'relative_time.dart';
import 'task_delta.dart';

/// Result of a task update operation.
typedef TaskModification = ({Task newTask, TaskDelta delta});

/// Defines how often a task reoccurs.
abstract class TaskSchedule {
  const TaskSchedule();

  /// Checks if the task occurs on the given [date].
  bool occursOn(CivilDay date);

  /// Calculates the next occurrence of the task strictly after [date].
  CivilDay nextOccurrenceAfter(CivilDay date);

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
      default:
        throw Exception('Unknown schedule type: $type');
    }
  }
}

/// Enum representing the type of recurrence for UI selection.
enum RecurrenceType { oneOff, daily, weekly }

/// A schedule for a task that happens exactly once.
class OneOffSchedule extends TaskSchedule {
  /// The specific date the task occurs.
  CivilDay date;

  OneOffSchedule({required this.date});

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
  Map<String, dynamic> toJson() {
    return {
      'type': 'weekly',
      'startDate': startDate.toJson(),
      'interval': interval,
      'daysOfWeek': daysOfWeek.toList(),
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

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.startRelativeTime,
    required this.dueRelativeTime,
    required this.schedule,
  });

  factory Task.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot, [
    SnapshotOptions? options,
  ]) {
    final data = snapshot.data();
    if (data == null) {
      throw Exception('Data is null for document ${snapshot.id}');
    }
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
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'startRelativeTime': startRelativeTime.toJson(),
      'dueRelativeTime': dueRelativeTime.toJson(),
      'schedule': schedule.toJson(),
    };
  }

  static final _uuid = Uuid();

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
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      startRelativeTime: startRelativeTime ?? this.startRelativeTime,
      dueRelativeTime: dueRelativeTime ?? this.dueRelativeTime,
      schedule: schedule ?? this.schedule,
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
    final today = CivilDay.fromDateTime(current);

    if (schedule.occursOn(today)) {
      final dueTime = dueRelativeTime.referenceTo(today);
      return current.isAfter(dueTime);
    }
    return false;
  }
}
