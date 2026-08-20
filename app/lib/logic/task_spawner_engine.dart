import 'dart:convert';

import 'task_schedule.dart';
import 'task_instance.dart';
import 'scheduler_engine.dart';

/// Central engine for evaluating task recurrence rules and calculating spawned task instances.
class TaskSpawnerEngine {
  /// Returns the next task instance to spawn based on completion time and existing instances.
  static TaskInstance? calculateNextOccurrence({
    required TaskSchedule task,
    required TaskInstance completedInstance,
    required DateTime completionTime,
    required List<TaskInstance> existingInstances,
  }) {
    return const SchedulerEngine().getNextOccurrenceToSpawn(
      task,
      completedInstance,
      completionTime,
      existingInstances,
    );
  }

  /// Returns the ID of the next occurrence to delete when undoing a completion.
  static String? calculateOccurrenceIdToUndo({
    required TaskSchedule task,
    required TaskInstance completedInstance,
    required DateTime completionTime,
    required List<TaskInstance> existingInstances,
  }) {
    return const SchedulerEngine().getNextOccurrenceIdToDelete(
      task,
      completedInstance,
      completionTime,
      existingInstances,
    );
  }

  /// Generates a hash signature for a task's schedule configuration and policy fields.
  static String computeScheduleSignature(TaskSchedule task) {
    final rulesJson = task.schedules.map((s) => s.toJson()).toList();
    return jsonEncode({
      'rules': rulesJson,
      'futureInstancesCount': task.futureInstancesCount,
      'estimatedDuration': task.estimatedDuration?.inMinutes,
      'priority': task.priority.name,
      'skipIfNoCapacity': task.skipIfNoCapacity,
      'missedPolicy': task.missedPolicy.name,
      'assignedUserId': task.assignedUserId,
      'isFamily': task.isFamily,
      'familyCompletionMode': task.familyCompletionMode.name,
    });
  }
}
