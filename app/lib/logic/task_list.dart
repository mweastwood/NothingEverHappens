import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'civil_day.dart';
import 'task_schedule.dart';

class TaskList {
  final List<TaskSchedule> activeTasks;

  const TaskList(this.activeTasks);

  TaskList add(TaskSchedule task) {
    return TaskList([...activeTasks, task]);
  }

  TaskList complete(String taskId) {
    final now = AppClock.now;

    final taskIndex = activeTasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) return this;

    final task = activeTasks[taskIndex];
    final today = CivilDay.fromDateTime(now);

    List<TaskScheduleRule> newSchedules = task.schedules;
    int newActiveOccurrenceIndex = task.activeOccurrenceIndex;

    bool shouldRemoveTask = false;

    // Check if all schedules represent the same recurrence rule scheduled for the same date.
    // If so, we treat them as slot-based (like legacy dailyTimes).
    bool isSlotBased = false;
    if (task.schedules.isNotEmpty) {
      final first = task.schedules.first;
      bool sameRecurrence = true;
      for (final s in task.schedules) {
        if (s.scheduledDate != first.scheduledDate ||
            !s.hasSameRecurrence(first)) {
          sameRecurrence = false;
          break;
        }
      }
      isSlotBased = sameRecurrence && task.schedules.length > 1;
    }

    if (isSlotBased) {
      if (newActiveOccurrenceIndex + 1 < task.schedules.length) {
        newActiveOccurrenceIndex++;
      } else {
        newActiveOccurrenceIndex = 0;
        final List<TaskScheduleRule> list = [];
        for (final s in task.schedules) {
          final advanced = s.advanceAfterCompletion(today);
          if (advanced != null) {
            list.add(advanced);
          }
        }
        newSchedules = list;
        if (newSchedules.isEmpty) {
          shouldRemoveTask = true;
        }
      }
    } else {
      // Advance repeating schedules that occurred on or before today.
      // Remove one-off schedules that occurred on or before today.
      final List<TaskScheduleRule> list = [];
      for (final s in task.schedules) {
        final advanced = s.advanceAfterCompletion(today);
        if (advanced != null) {
          list.add(advanced);
        }
      }
      newSchedules = list;
      if (newSchedules.isEmpty) {
        shouldRemoveTask = true;
      }
      if (newActiveOccurrenceIndex >= newSchedules.length) {
        newActiveOccurrenceIndex = 0;
      }
    }

    if (shouldRemoveTask) {
      return TaskList(activeTasks.where((t) => t.id != taskId).toList());
    }

    final updatedTask = task.copyWith(
      schedules: newSchedules,
      activeOccurrenceIndex: newActiveOccurrenceIndex,
    );

    final updatedTasks = List<TaskSchedule>.from(activeTasks);
    updatedTasks[taskIndex] = updatedTask;

    return TaskList(updatedTasks);
  }

  TaskList delete(String taskId) {
    return TaskList(activeTasks.where((t) => t.id != taskId).toList());
  }

  TaskList update(TaskModification modification) {
    final updatedTasks = activeTasks.map((t) {
      return t.id == modification.newTask.id ? modification.newTask : t;
    }).toList();

    return TaskList(updatedTasks);
  }
}
