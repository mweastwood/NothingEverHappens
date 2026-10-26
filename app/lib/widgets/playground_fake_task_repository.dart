import 'dart:async';

import '../logic/task_instance.dart';
import '../logic/task_repository.dart';
import '../logic/task_schedule.dart';

class PlaygroundFakeTaskRepository implements TaskRepository {
  @override
  final String userId;

  final FutureOr<void> Function(String) onComplete;
  final FutureOr<void> Function(String)? onDismiss;
  final FutureOr<void> Function(String)? onDeleteSchedule;
  final FutureOr<void> Function(TaskInstance)? onUndo;

  PlaygroundFakeTaskRepository({
    this.userId = 'playground_user',
    required this.onComplete,
    this.onDismiss,
    this.onDeleteSchedule,
    this.onUndo,
  });

  @override
  Future<TaskInstance?> completeTaskInstance(String id) async {
    await onComplete(id);
    return null;
  }

  @override
  Future<({TaskSchedule task, List<TaskInstance> pendingInstances})?>
  deleteTaskSchedule(String id) async {
    await onDeleteSchedule?.call(id);
    return null;
  }

  @override
  Future<void> restoreTaskSchedule(
    TaskSchedule task,
    List<TaskInstance> pendingInstances,
  ) async {}

  @override
  Future<TaskInstance?> dismissTaskInstance(String id) async {
    if (onDismiss != null) {
      await onDismiss!(id);
    } else {
      await onComplete(id);
    }
    return null;
  }

  @override
  Future<void> undoResolveTaskInstance(TaskInstance resolvedInstance) async {
    if (onUndo == null) return;
    final pending = resolvedInstance.copyWith(
      status: TaskStatus.pending,
      clearCompletedByUserId: true,
      clearCompletedAt: true,
    );
    await onUndo!(pending);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
