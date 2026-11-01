import 'package:collection/collection.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'task_repository.dart';
import 'task_instance.dart';
import 'task_schedule.dart';

const _deepEquals = DeepCollectionEquality();

sealed class UndoableAction {
  final String message;
  const UndoableAction({required this.message});

  Future<void> undo(TaskRepository repo);
}

class UndoResolveTaskInstanceAction extends UndoableAction {
  final TaskInstance instance;

  const UndoResolveTaskInstanceAction({
    required super.message,
    required this.instance,
  });

  @override
  Future<void> undo(TaskRepository repo) async {
    await repo.undoResolveTaskInstance(instance);
  }
}

class UndoDeleteTaskScheduleAction extends UndoableAction {
  final TaskSchedule schedule;
  final List<TaskInstance> pendingInstances;

  const UndoDeleteTaskScheduleAction({
    required super.message,
    required this.schedule,
    required this.pendingInstances,
  });

  @override
  Future<void> undo(TaskRepository repo) async {
    await repo.restoreTaskSchedule(schedule, pendingInstances);
  }
}

class UndoEditTaskScheduleAction extends UndoableAction {
  final TaskSchedule previousSchedule;
  final TaskSchedule currentSchedule;

  const UndoEditTaskScheduleAction({
    required super.message,
    required this.previousSchedule,
    required this.currentSchedule,
  });

  @override
  Future<void> undo(TaskRepository repo) async {
    final prevSchedulesJson = previousSchedule.schedules
        .map((s) => s.toJson())
        .toList();
    final currSchedulesJson = currentSchedule.schedules
        .map((s) => s.toJson())
        .toList();
    final schedulesChanged = !_deepEquals.equals(
      prevSchedulesJson,
      currSchedulesJson,
    );

    final modification = (
      newTask: previousSchedule,
      changes: <String, dynamic>{
        if (previousSchedule.title != currentSchedule.title)
          'title': previousSchedule.title,
        if (previousSchedule.description != currentSchedule.description)
          'description': previousSchedule.description,
        if (schedulesChanged) 'schedules': prevSchedulesJson,
        if (previousSchedule.priority != currentSchedule.priority)
          'priority': previousSchedule.priority.name,
        if (previousSchedule.isFamily != currentSchedule.isFamily)
          'isFamily': previousSchedule.isFamily,
        if (previousSchedule.familyCompletionMode !=
            currentSchedule.familyCompletionMode)
          'familyCompletionMode': previousSchedule.familyCompletionMode.name,
        if (previousSchedule.assignedUserId != currentSchedule.assignedUserId)
          'assignedUserId': previousSchedule.assignedUserId,
        if (!_deepEquals.equals(
          previousSchedule.labelIds,
          currentSchedule.labelIds,
        ))
          'labelIds': previousSchedule.labelIds,
        if (previousSchedule.estimatedDuration !=
            currentSchedule.estimatedDuration)
          'estimatedDuration': previousSchedule.estimatedDuration?.inMinutes,
        if (previousSchedule.skipIfNoCapacity !=
            currentSchedule.skipIfNoCapacity)
          'skipIfNoCapacity': previousSchedule.skipIfNoCapacity,
        if (previousSchedule.workflowType != currentSchedule.workflowType)
          'workflowType': previousSchedule.workflowType,
        if (!_deepEquals.equals(
          previousSchedule.mealWorkflowConfig?.toJson(),
          currentSchedule.mealWorkflowConfig?.toJson(),
        ))
          'mealWorkflowConfig': previousSchedule.mealWorkflowConfig?.toJson(),
        if (previousSchedule.cycleId != currentSchedule.cycleId)
          'cycleId': previousSchedule.cycleId,
        if (previousSchedule.preferredBy != currentSchedule.preferredBy)
          'preferredBy': previousSchedule.preferredBy,
        if (previousSchedule.appLaunchUrl != currentSchedule.appLaunchUrl)
          'appLaunchUrl': previousSchedule.appLaunchUrl,
      },
    );
    await repo.updateTaskSchedule(modification);
  }
}

class UndoNotifier extends StateNotifier<UndoableAction?> {
  UndoNotifier() : super(null);

  void register(UndoableAction action) {
    state = action;
  }

  void clear() {
    state = null;
  }

  Future<bool> undo(TaskRepository repo) async {
    final action = state;
    if (action == null) return false;
    state = null;
    try {
      await action.undo(repo);
      return true;
    } catch (_) {
      rethrow;
    }
  }
}

final undoNotifierProvider =
    StateNotifierProvider<UndoNotifier, UndoableAction?>((ref) {
      return UndoNotifier();
    });
