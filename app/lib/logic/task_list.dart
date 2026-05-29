import 'package:uuid/uuid.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'civil_day.dart';
import 'task.dart';
import 'task_delta.dart';
import 'relative_time.dart';

class TaskList {
  final List<Task> activeTasks;
  final List<TaskDelta> history;
  static final _uuid = Uuid();

  const TaskList(this.activeTasks, {this.history = const []});

  TaskList add(Task task, String userId) {
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
    if (taskIndex == -1) {
      // Fallback for backward compatibility (e.g. empty activeTasks context)
      return TaskList(
        activeTasks.where((t) => t.id != taskId).toList(),
        history: [...history, delta],
      );
    }

    final task = activeTasks[taskIndex];
    if (task.schedule is OneOffSchedule) {
      return TaskList(
        activeTasks.where((t) => t.id != taskId).toList(),
        history: [...history, delta],
      );
    } else {
      // Check if there are multiple occurrence times per day
      if (task.dailyTimes.isNotEmpty &&
          task.activeOccurrenceIndex < task.dailyTimes.length - 1) {
        // Advance to the next occurrence on the SAME day
        final nextIndex = task.activeOccurrenceIndex + 1;
        final nextOccurrence = task.dailyTimes[nextIndex];
        final updatedTask = Task(
          id: task.id,
          title: task.title,
          description: task.description,
          startRelativeTime: RelativeTime(
            dayOffset: 0,
            time: nextOccurrence.startTime,
          ),
          dueRelativeTime: RelativeTime(
            dayOffset: 0,
            time: nextOccurrence.dueTime,
          ),
          schedule: task.schedule, // same schedule (same startDate!)
          dailyTimes: task.dailyTimes,
          activeOccurrenceIndex: nextIndex,
          estimatedDuration: task.estimatedDuration,
          missedPolicy: task.missedPolicy,
          isMaster: task.isMaster,
          lastSpawnedDate: task.lastSpawnedDate,
          parentTaskId: task.parentTaskId,
        );

        final updatedTasks = List<Task>.from(activeTasks);
        updatedTasks[taskIndex] = updatedTask;

        return TaskList(updatedTasks, history: [...history, delta]);
      } else {
        // We either have no dailyTimes (fallback/compatibility), or we have completed the last daily occurrence.
        // Reschedule the recurring task to the next occurrence day.
        final today = CivilDay.fromDateTime(now);
        
        final nextOccur = task.schedule.nextOccurrenceAfter(task.schedule.scheduledDate);

        TaskSchedule newSchedule;
        if (task.schedule is DailySchedule) {
          final ds = task.schedule as DailySchedule;
          newSchedule = DailySchedule(
            startDate: nextOccur,
            interval: ds.interval,
          );
        } else if (task.schedule is WeeklySchedule) {
          final ws = task.schedule as WeeklySchedule;
          newSchedule = WeeklySchedule(
            startDate: nextOccur,
            interval: ws.interval,
            daysOfWeek: ws.daysOfWeek,
          );
        } else {
          newSchedule = task.schedule;
        }

        // Reset to the first occurrence time (or keep existing startRelativeTime / dueRelativeTime if dailyTimes is empty)
        final firstOccurStart = task.dailyTimes.isNotEmpty
            ? RelativeTime(dayOffset: 0, time: task.dailyTimes[0].startTime)
            : task.startRelativeTime;
        final firstOccurDue = task.dailyTimes.isNotEmpty
            ? RelativeTime(dayOffset: 0, time: task.dailyTimes[0].dueTime)
            : task.dueRelativeTime;

        final updatedTask = Task(
          id: task.id,
          title: task.title,
          description: task.description,
          startRelativeTime: firstOccurStart,
          dueRelativeTime: firstOccurDue,
          schedule: newSchedule,
          dailyTimes: task.dailyTimes,
          activeOccurrenceIndex: 0, // reset
          estimatedDuration: task.estimatedDuration,
          missedPolicy: task.missedPolicy,
          isMaster: task.isMaster,
          lastSpawnedDate: task.lastSpawnedDate,
          parentTaskId: task.parentTaskId,
        );

        final updatedTasks = List<Task>.from(activeTasks);
        updatedTasks[taskIndex] = updatedTask;

        return TaskList(updatedTasks, history: [...history, delta]);
      }
    }
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
