import 'civil_day.dart';

/// Defines how often a task reoccurs.
abstract class TaskSchedule {
  /// Checks if the task occurs on the given [date].
  bool occursOn(CivilDay date);
}

/// A schedule for a task that happens exactly once.
class OneOffSchedule extends TaskSchedule {
  /// The specific date the task occurs.
  CivilDay date;

  OneOffSchedule({required this.date});

  @override
  bool occursOn(CivilDay date) {
    return this.date == date;
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
}

/// Represents a single task in the todo list.
class Task {
  /// Unique identifier for the task.
  String id;

  /// The title of the task.
  String title;

  /// Detailed description of the task.
  String description;

  /// The start time offset from midnight when the task becomes active.
  Duration startFromMidnight;

  /// The due time offset from midnight after which the task is overdue.
  Duration dueFromMidnight;

  /// The recurrence schedule for the task.
  TaskSchedule schedule;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.startFromMidnight,
    required this.dueFromMidnight,
    required this.schedule,
  });

  /// Checks if the task is overdue at [current] time.
  bool isOverdue(DateTime current) {
    final today = CivilDay.fromDateTime(current);

    if (schedule.occursOn(today)) {
      final midnight = today.toDateTime();
      final dueTime = midnight.add(dueFromMidnight);
      return current.isAfter(dueTime);
    }
    return false;
  }
}
