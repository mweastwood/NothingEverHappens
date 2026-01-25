import 'package:cloud_firestore/cloud_firestore.dart';
import 'civil_day.dart';
import 'relative_time.dart';

/// Defines how often a task reoccurs.
abstract class TaskSchedule {
  const TaskSchedule();

  /// Checks if the task occurs on the given [date].
  bool occursOn(CivilDay date);

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
    final start = startDate.toDateTime();
    final target = date.toDateTime();

    // Before start date?
    if (target.isBefore(start)) {
      return false;
    }

    final difference = target.difference(start).inDays;
    return difference % interval == 0;
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
    final start = startDate.toDateTime();
    final target = date.toDateTime();

    // Before start date?
    if (target.isBefore(start)) {
      return false;
    }

    // Check if the specific day of week is allowed
    // weekday 1 = Monday, 7 = Sunday
    if (!daysOfWeek.contains(target.weekday)) {
      return false;
    }

    // Calculate week difference
    final startOfWeekForStart = start.subtract(
      Duration(days: start.weekday - 1),
    );
    final startOfWeekForTarget = target.subtract(
      Duration(days: target.weekday - 1),
    );

    final daysDiff = startOfWeekForTarget
        .difference(startOfWeekForStart)
        .inDays;
    final weeksDiff = daysDiff ~/ 7;

    return weeksDiff % interval == 0;
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
