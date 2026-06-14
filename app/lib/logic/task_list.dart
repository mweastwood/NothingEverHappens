import 'package:uuid/uuid.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'civil_day.dart';
import 'task_schedule.dart';
import 'task_delta.dart';

class TaskList {
  final List<TaskSchedule> activeTasks;
  final List<TaskDelta> history;
  static final _uuid = Uuid();

  const TaskList(this.activeTasks, {this.history = const []});

  TaskList add(TaskSchedule task, String userId) {
    final now = AppClock.now;
    final delta = TaskDelta(
      id: _uuid.v4(),
      taskId: task.id,
      timestamp: now,
      expiresAt: now.add(const Duration(days: 90)),
      operation: 'create',
      changedFields: task.toFirestore(),
      userId: userId,
    );

    return TaskList([...activeTasks, task], history: [...history, delta]);
  }

  TaskList complete(String taskId, String userId) {
    final now = AppClock.now;
    final delta = TaskDelta(
      id: _uuid.v4(),
      taskId: taskId,
      timestamp: now,
      expiresAt: now.add(const Duration(days: 90)),
      operation: 'complete',
      changedFields: {},
      userId: userId,
    );

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
        if (s.runtimeType != first.runtimeType ||
            s.scheduledDate != first.scheduledDate) {
          sameRecurrence = false;
          break;
        }
        if (s is DailySchedule && first is DailySchedule) {
          if (s.interval != first.interval) {
            sameRecurrence = false;
          }
        } else if (s is WeeklySchedule && first is WeeklySchedule) {
          if (s.interval != first.interval ||
              s.daysOfWeek.length != first.daysOfWeek.length ||
              !s.daysOfWeek.every(first.daysOfWeek.contains)) {
            sameRecurrence = false;
          }
        } else if (s is MonthlySchedule && first is MonthlySchedule) {
          if (s.interval != first.interval ||
              s.dayOfMonth != first.dayOfMonth) {
            sameRecurrence = false;
          }
        } else if (s is YearlySchedule && first is YearlySchedule) {
          if (s.interval != first.interval ||
              s.month != first.month ||
              s.day != first.day) {
            sameRecurrence = false;
          }
        }
      }
      isSlotBased = sameRecurrence && task.schedules.length > 1;
    }

    if (isSlotBased) {
      if (newActiveOccurrenceIndex + 1 < task.schedules.length) {
        newActiveOccurrenceIndex++;
      } else {
        newActiveOccurrenceIndex = 0;
        if (task.schedules.first is OneOffSchedule) {
          shouldRemoveTask = true;
        } else {
          newSchedules = task.schedules.map((s) {
            final CivilDay nextOccur;
            if (task.missedPolicy == MissedPolicy.rollover) {
              nextOccur = s.nextOccurrenceAfter(s.scheduledDate)!;
            } else {
              nextOccur = s.nextOccurrenceAfter(today)!;
            }
            return s.copyWithStartDate(nextOccur);
          }).toList();
        }
      }
    } else {
      // Advance repeating schedules that occurred on or before today.
      // Remove one-off schedules that occurred on or before today.
      final List<TaskScheduleRule> list = [];
      for (final s in task.schedules) {
        if (s is OneOffSchedule) {
          if (s.scheduledDate.isBefore(today) || s.scheduledDate == today) {
            // Completed! Drop it.
            continue;
          }
          list.add(s);
        } else {
          if (s.scheduledDate.isBefore(today) || s.scheduledDate == today) {
            final CivilDay nextOccur;
            if (task.missedPolicy == MissedPolicy.rollover) {
              nextOccur = s.nextOccurrenceAfter(s.scheduledDate)!;
            } else {
              nextOccur = s.nextOccurrenceAfter(today)!;
            }
            list.add(s.copyWithStartDate(nextOccur));
          } else {
            list.add(s);
          }
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
      return TaskList(
        activeTasks.where((t) => t.id != taskId).toList(),
        history: [...history, delta],
      );
    }

    final updatedTask = TaskSchedule(
      id: task.id,
      title: task.title,
      description: task.description,
      schedules: newSchedules,
      activeOccurrenceIndex: newActiveOccurrenceIndex,
      estimatedDuration: task.estimatedDuration,
      missedPolicy: task.missedPolicy,
      isMaster: task.isMaster,
      lastSpawnedDate: task.lastSpawnedDate,
      parentTaskId: task.parentTaskId,
      isFamily: task.isFamily,
      priority: task.priority,
      cycleId: task.cycleId,
      preferredBy: task.preferredBy,
      assignedUserId: task.assignedUserId,
    );

    final updatedTasks = List<TaskSchedule>.from(activeTasks);
    updatedTasks[taskIndex] = updatedTask;

    return TaskList(updatedTasks, history: [...history, delta]);
  }

  TaskList delete(String taskId, String userId) {
    final now = AppClock.now;
    final delta = TaskDelta(
      id: _uuid.v4(),
      taskId: taskId,
      timestamp: now,
      expiresAt: now.add(const Duration(days: 90)),
      operation: 'delete',
      changedFields: {},
      userId: userId,
    );

    return TaskList(
      activeTasks.where((t) => t.id != taskId).toList(),
      history: [...history, delta],
    );
  }

  TaskList update(TaskModification modification) {
    final updatedTasks = activeTasks.map((t) {
      return t.id == modification.newTask.id ? modification.newTask : t;
    }).toList();

    return TaskList(updatedTasks, history: [...history, modification.delta]);
  }
}
