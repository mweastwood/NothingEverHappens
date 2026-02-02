import 'package:uuid/uuid.dart';
import 'task.dart';
import 'task_delta.dart';

class TaskList {
  final List<Task> activeTasks;
  final List<TaskDelta> history;
  static final _uuid = Uuid();

  const TaskList(this.activeTasks, {this.history = const []});

  TaskList add(Task task, String userId) {
    final now = DateTime.now();
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
    final now = DateTime.now();
    final delta = TaskDelta(
      id: _uuid.v4(),
      taskId: taskId,
      timestamp: now,
      expiresAt: now.add(const Duration(days: 90)),
      operation: 'complete',
      changedFields: {},
      userId: userId,
    );

    return TaskList(
      activeTasks.where((t) => t.id != taskId).toList(),
      history: [...history, delta],
    );
  }

  TaskList delete(String taskId, String userId) {
    final now = DateTime.now();
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
