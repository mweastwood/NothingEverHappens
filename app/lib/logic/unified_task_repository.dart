import 'dart:async';

import 'package:nothing_ever_happens/logic/hive_local_data_source.dart';
import 'package:nothing_ever_happens/logic/task_sync_service.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/scheduler_engine.dart';
import 'package:nothing_ever_happens/logic/task_spawner_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nothing_ever_happens/logic/initial_firebase_migration_service.dart';

class UnifiedTaskRepository extends TaskRepository {
  final HiveLocalDataSource _localDataSource;
  final TaskSyncService _syncService;
  final FirebaseFirestore? _rawFirestore;

  Future<void>? _activeProcessingFuture;
  bool _hasQueuedProcessing = false;
  final List<Future<void> Function()> _queuedPostProcessCallbacks = [];

  UnifiedTaskRepository({
    required HiveLocalDataSource localDataSource,
    required TaskSyncService syncService,
    required super.userId,
    super.firestore,
    super.notificationService,
    super.errorHandler,
  }) : _localDataSource = localDataSource,
       _syncService = syncService,
       _rawFirestore = firestore {
    _initMigration();
  }

  void _initMigration() {
    if (!_localDataSource.isMigrationCompleted() && userId.isNotEmpty) {
      final migrationService = InitialFirebaseMigrationService(
        firestore: _rawFirestore,
        localDataSource: _localDataSource,
        userId: userId,
      );
      migrationService
          .migrateIfNeeded()
          .then((_) {
            triggerMissedPolicyProcessing();
          })
          .catchError((e) {
            // ignore: avoid_print
            print('Initial migration error: $e');
          });
    }
  }

  @override
  Stream<List<TaskSchedule>> getTasks() {
    scheduleMicrotask(() => triggerMissedPolicyProcessing());
    return _localDataSource.watchTasks();
  }

  @override
  Stream<List<TaskInstance>> getInstances() {
    return _localDataSource.watchInstances();
  }

  @override
  Future<void> addTaskSchedule(TaskSchedule task) async {
    final t = task.copyWith(updatedAt: DateTime.now());
    await _localDataSource.saveTask(t);
    await _localDataSource.markDirty(t.id);
    _syncService.sync();
    await triggerMissedPolicyProcessing();
  }

  @override
  Future<void> updateTaskSchedule(TaskModification modification) async {
    final t = modification.newTask.copyWith(updatedAt: DateTime.now());
    await _localDataSource.saveTask(t);
    await _localDataSource.markDirty(t.id);

    final changes = modification.changes;
    if (changes.containsKey('schedules')) {
      final instances = _localDataSource
          .getInstances()
          .where((i) => i.scheduleId == t.id && i.status == TaskStatus.pending)
          .toList();
      for (final inst in instances) {
        await _localDataSource.deleteInstance(inst.id);
        await _localDataSource.markDirty(inst.id);
      }
    } else {
      final instances = _localDataSource
          .getInstances()
          .where((i) => i.scheduleId == t.id && i.status == TaskStatus.pending)
          .toList();
      for (final inst in instances) {
        final updatedInst = inst.copyWith(
          title: t.title,
          description: t.description,
          priority: t.priority,
          isFamily: t.isFamily,
          cycleId: t.cycleId,
          clearCycleId: t.cycleId == null,
          assignedUserId: t.assignedUserId,
          clearAssignedUserId: t.assignedUserId == null,
          updatedAt: DateTime.now(),
        );
        await _localDataSource.saveInstance(updatedInst);
        await _localDataSource.markDirty(updatedInst.id);
      }
    }

    _syncService.sync();
    await triggerMissedPolicyProcessing();
  }

  @override
  Future<({TaskSchedule task, List<TaskInstance> pendingInstances})?>
  deleteTaskSchedule(String id) async {
    final task = _localDataSource
        .getTasks()
        .where((t) => t.id == id)
        .firstOrNull;
    if (task == null) return null;

    await _localDataSource.deleteTask(id);
    await _localDataSource.markDirty(id);

    final pendingInstances = <TaskInstance>[];
    final instances = _localDataSource
        .getInstances()
        .where((i) => i.scheduleId == id)
        .toList();
    for (final inst in instances) {
      if (inst.status == TaskStatus.pending) {
        pendingInstances.add(inst);
        await _localDataSource.deleteInstance(inst.id);
        await _localDataSource.markDirty(inst.id);
      }
    }

    _syncService.sync();
    await triggerMissedPolicyProcessing();
    return (task: task, pendingInstances: pendingInstances);
  }

  @override
  Future<TaskInstance?> completeTaskInstance(String id) async {
    final instance = _localDataSource
        .getInstances()
        .where((i) => i.id == id)
        .firstOrNull;
    if (instance == null) return null;

    final completedInstance = instance.copyWith(
      status: TaskStatus.completed,
      completedByUserId: userId,
      completedAt: AppClock.now,
      updatedAt: DateTime.now(),
    );
    await _localDataSource.saveInstance(completedInstance);
    await _localDataSource.markDirty(completedInstance.id);

    final task = _localDataSource
        .getTasks()
        .where((t) => t.id == instance.scheduleId)
        .firstOrNull;
    if (task != null && task.schedules.any((s) => s is! OneOffSchedule)) {
      final instances = _localDataSource
          .getInstances()
          .where((i) => i.scheduleId == task.id)
          .toList();
      final nextInst = TaskSpawnerEngine.calculateNextOccurrence(
        task: task,
        completedInstance: completedInstance,
        completionTime: AppClock.now,
        existingInstances: instances,
      );
      if (nextInst != null) {
        final nextInstToSave = nextInst.copyWith(updatedAt: DateTime.now());
        await _localDataSource.saveInstance(nextInstToSave);
        await _localDataSource.markDirty(nextInstToSave.id);
      }
    }

    _syncService.sync();
    return completedInstance;
  }

  @override
  Future<TaskInstance?> dismissTaskInstance(String id) async {
    final instance = _localDataSource
        .getInstances()
        .where((i) => i.id == id)
        .firstOrNull;
    if (instance == null) return null;

    final dismissedInstance = instance.copyWith(
      status: TaskStatus.skipped,
      completedByUserId: userId,
      completedAt: AppClock.now,
      updatedAt: DateTime.now(),
    );
    await _localDataSource.saveInstance(dismissedInstance);
    await _localDataSource.markDirty(dismissedInstance.id);

    final task = _localDataSource
        .getTasks()
        .where((t) => t.id == instance.scheduleId)
        .firstOrNull;
    if (task != null && task.schedules.any((s) => s is! OneOffSchedule)) {
      final instances = _localDataSource
          .getInstances()
          .where((i) => i.scheduleId == task.id)
          .toList();
      final nextInst = TaskSpawnerEngine.calculateNextOccurrence(
        task: task,
        completedInstance: dismissedInstance,
        completionTime: AppClock.now,
        existingInstances: instances,
      );
      if (nextInst != null) {
        final nextInstToSave = nextInst.copyWith(updatedAt: DateTime.now());
        await _localDataSource.saveInstance(nextInstToSave);
        await _localDataSource.markDirty(nextInstToSave.id);
      }
    }

    _syncService.sync();
    return dismissedInstance;
  }

  @override
  Future<void> undoResolveTaskInstance(TaskInstance resolvedInstance) async {
    final pendingInstance = resolvedInstance.copyWith(
      status: TaskStatus.pending,
      clearCompletedByUserId: true,
      clearCompletedAt: true,
      updatedAt: DateTime.now(),
    );
    await _localDataSource.saveInstance(pendingInstance);
    await _localDataSource.markDirty(pendingInstance.id);

    final task = _localDataSource
        .getTasks()
        .where((t) => t.id == resolvedInstance.scheduleId)
        .firstOrNull;
    if (task != null && task.schedules.any((s) => s is! OneOffSchedule)) {
      final instances = _localDataSource
          .getInstances()
          .where((i) => i.scheduleId == task.id)
          .toList();
      final nextId = TaskSpawnerEngine.calculateOccurrenceIdToUndo(
        task: task,
        completedInstance: resolvedInstance,
        completionTime: resolvedInstance.completedAt ?? AppClock.now,
        existingInstances: instances,
      );
      if (nextId != null) {
        await _localDataSource.deleteInstance(nextId);
        await _localDataSource.markDirty(nextId);
      }
    }

    _syncService.sync();
  }

  @override
  Future<void> triggerMissedPolicyProcessing({
    Future<void> Function()? postProcess,
  }) async {
    if (postProcess != null) {
      _queuedPostProcessCallbacks.add(postProcess);
    }
    while (true) {
      final active = _activeProcessingFuture;
      if (active != null) {
        _hasQueuedProcessing = true;
        await active;
        if (!_hasQueuedProcessing && _queuedPostProcessCallbacks.isEmpty) {
          return;
        }
        continue;
      }

      _activeProcessingFuture = _processQueue();
      await _activeProcessingFuture;
      if (!_hasQueuedProcessing && _queuedPostProcessCallbacks.isEmpty) {
        return;
      }
    }
  }

  Future<void> _processQueue() async {
    try {
      do {
        _hasQueuedProcessing = false;
        final callbacksToRun = List<Future<void> Function()>.from(
          _queuedPostProcessCallbacks,
        );
        _queuedPostProcessCallbacks.clear();

        try {
          await _doProcessMissedPolicies();
        } catch (e) {
          // ignore: avoid_print
          print('Error in auto-processing missed policies loop: $e');
        }

        for (final cb in callbacksToRun) {
          try {
            await cb();
          } catch (e) {
            // ignore: avoid_print
            print('Error in postProcess callback: $e');
          }
        }
      } while (_hasQueuedProcessing || _queuedPostProcessCallbacks.isNotEmpty);
    } finally {
      _activeProcessingFuture = null;
    }
  }

  Future<void> _doProcessMissedPolicies() async {
    final now = AppClock.now;
    final tasks = _localDataSource.getTasks();
    final allInstances = _localDataSource.getInstances();
    final userSettings = _localDataSource.getSettings();

    final Map<CivilDay, double> dayPlannedHours = {};
    for (final inst in allInstances) {
      if (inst.status != TaskStatus.skipped &&
          inst.status != TaskStatus.failed) {
        final t = tasks.where((ts) => ts.id == inst.scheduleId).firstOrNull;
        if (t != null && t.estimatedDuration != null && !t.skipIfNoCapacity) {
          final hours = t.estimatedDuration!.inMinutes / 60.0;
          dayPlannedHours[inst.scheduledDate] =
              (dayPlannedHours[inst.scheduledDate] ?? 0.0) + hours;
        }
      }
    }

    final Map<String, DateTime> lastCompletionCache = {};
    DateTime getLastCompletionTime(TaskSchedule task) {
      return lastCompletionCache.putIfAbsent(task.id, () {
        final completed = allInstances
            .where(
              (inst) =>
                  inst.scheduleId == task.id &&
                  inst.status == TaskStatus.completed,
            )
            .toList();
        if (completed.isEmpty) {
          return DateTime.fromMillisecondsSinceEpoch(0);
        }
        return completed
            .map(
              (inst) =>
                  inst.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
            )
            .reduce((a, b) => a.isAfter(b) ? a : b);
      });
    }

    final tasksToEvaluate = List<TaskSchedule>.from(tasks);
    tasksToEvaluate.sort((a, b) {
      final pCompare = b.priority.index.compareTo(a.priority.index);
      if (pCompare != 0) return pCompare;

      if (a.skipIfNoCapacity && b.skipIfNoCapacity) {
        final aTime = getLastCompletionTime(a);
        final bTime = getLastCompletionTime(b);
        final timeCompare = aTime.compareTo(bTime);
        if (timeCompare != 0) return timeCompare;
      }

      return a.id.compareTo(b.id);
    });

    bool hasChanges = false;

    final Map<String, List<TaskInstance>> instancesByScheduleId = {};
    for (final inst in allInstances) {
      instancesByScheduleId.putIfAbsent(inst.scheduleId, () => []).add(inst);
    }

    for (final task in tasksToEvaluate) {
      final taskInstances = instancesByScheduleId[task.id] ?? [];

      final action = const SchedulerEngine().evaluate(
        task,
        taskInstances,
        now,
        userSettings: userSettings,
        dayPlannedHours: dayPlannedHours,
        applyCapacityLimits:
            task.assignedUserId == null || task.assignedUserId == userId,
      );

      for (final inst in action.instancesToUpdate) {
        final updatedInst = inst.copyWith(updatedAt: DateTime.now());
        await _localDataSource.saveInstance(updatedInst);
        await _localDataSource.markDirty(updatedInst.id);
        hasChanges = true;

        final idx = allInstances.indexWhere((x) => x.id == inst.id);
        if (idx >= 0) {
          allInstances[idx] = updatedInst;
        }
      }

      for (final inst in action.instancesToSpawn) {
        final newInst = inst.copyWith(updatedAt: DateTime.now());
        await _localDataSource.saveInstance(newInst);
        await _localDataSource.markDirty(newInst.id);
        hasChanges = true;

        allInstances.add(newInst);
      }

      for (final instId in action.instancesToDelete) {
        await _localDataSource.deleteInstance(instId);
        await _localDataSource.markDirty(instId);
        hasChanges = true;
        allInstances.removeWhere((x) => x.id == instId);
      }

      final activeInstances = allInstances.where(
        (i) => i.scheduleId == task.id && i.status == TaskStatus.pending,
      );
      for (final inst in activeInstances) {
        if (task.estimatedDuration != null && task.skipIfNoCapacity) {
          final hours = task.estimatedDuration!.inMinutes / 60.0;
          dayPlannedHours[inst.scheduledDate] =
              (dayPlannedHours[inst.scheduledDate] ?? 0.0) + hours;
        }
      }

      if (action.updatedSchedule != null) {
        final updatedTask = action.updatedSchedule!.copyWith(
          updatedAt: DateTime.now(),
        );
        await _localDataSource.saveTask(updatedTask);
        await _localDataSource.markDirty(updatedTask.id);
        hasChanges = true;
      }
    }

    if (hasChanges) {
      _syncService.sync();
    }
  }
}
