import 'package:uuid/uuid.dart';
import 'app_clock.dart';
import 'civil_day.dart';
import 'task.dart';
import 'task_delta.dart';

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
      // Reschedule the recurring task
      final today = CivilDay.fromDateTime(now);
      final nextOccur = task.schedule.nextOccurrenceAfter(today);

      TaskSchedule newSchedule;
      if (task.schedule is DailySchedule) {
        final ds = task.schedule as DailySchedule;
        newSchedule = DailySchedule(startDate: nextOccur, interval: ds.interval);
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

      final updatedTask = Task(
        id: task.id,
        title: task.title,
        description: task.description,
        startRelativeTime: task.startRelativeTime,
        dueRelativeTime: task.dueRelativeTime,
        schedule: newSchedule,
      );

      final updatedTasks = List<Task>.from(activeTasks);
      updatedTasks[taskIndex] = updatedTask;

      return TaskList(
        updatedTasks,
        history: [...history, delta]);
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
