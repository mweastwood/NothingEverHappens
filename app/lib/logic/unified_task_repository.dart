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
import 'package:nothing_ever_happens/logic/user_settings.dart';
import 'package:nothing_ever_happens/logic/initial_firebase_migration_service.dart';

class UnifiedTaskRepository extends TaskRepository {
  final HiveLocalDataSource _localDataSource;
  final TaskSyncService _syncService;
  final FirebaseFirestore? _rawFirestore;

  bool _isProcessingMissedPolicies = false;

  UnifiedTaskRepository({
    required HiveLocalDataSource localDataSource,
    required TaskSyncService syncService,
    required super.userId,
    super.firestore,
    super.notificationService,
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
    triggerMissedPolicyProcessing();
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
          .where((i) => i.scheduleId == t.id && i.status == 'pending')
          .toList();
      for (final inst in instances) {
        await _localDataSource.deleteInstance(inst.id);
        await _localDataSource.markDirty(inst.id);
      }
    } else {
      final instances = _localDataSource
          .getInstances()
          .where((i) => i.scheduleId == t.id && i.status == 'pending')
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
    triggerMissedPolicyProcessing();
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
      if (inst.status == 'pending') {
        pendingInstances.add(inst);
        await _localDataSource.deleteInstance(inst.id);
        await _localDataSource.markDirty(inst.id);
      }
    }

    _syncService.sync();
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
      status: 'completed',
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
      status: 'dismissed',
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
      status: 'pending',
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
  Future<void> triggerMissedPolicyProcessing() async {
    if (_isProcessingMissedPolicies) return;
    _isProcessingMissedPolicies = true;

    try {
      final now = AppClock.now;
      final tasks = _localDataSource.getTasks();
      final allInstances = _localDataSource.getInstances();
      final userSettings = const UserSettings(
        hoursAvailable: 8,
      ); // Default fallback if no settings

      final Map<CivilDay, double> dayPlannedHours = {};
      for (final inst in allInstances) {
        if (inst.status != 'skipped' && inst.status != 'failed') {
          final t = tasks.where((ts) => ts.id == inst.scheduleId).firstOrNull;
          if (t != null && t.estimatedDuration != null) {
            final hours = t.estimatedDuration!.inMinutes / 60.0;
            dayPlannedHours[inst.scheduledDate] =
                (dayPlannedHours[inst.scheduledDate] ?? 0.0) + hours;
          }
        }
      }

      bool hasChanges = false;

      final Map<String, List<TaskInstance>> instancesByScheduleId = {};
      for (final inst in allInstances) {
        instancesByScheduleId.putIfAbsent(inst.scheduleId, () => []).add(inst);
      }

      for (final task in tasks) {
        final taskInstances = instancesByScheduleId[task.id] ?? [];

        final action = SchedulerEngine.evaluate(
          task,
          taskInstances,
          now,
          userSettings: userSettings,
          dayPlannedHours: dayPlannedHours,
          applyCapacityLimits: task.assignedUserId == userId,
        );

        for (final inst in action.instancesToUpdate) {
          final updatedInst = inst.copyWith(updatedAt: DateTime.now());
          await _localDataSource.saveInstance(updatedInst);
          await _localDataSource.markDirty(updatedInst.id);
          hasChanges = true;
        }

        for (final inst in action.instancesToSpawn) {
          final newInst = inst.copyWith(updatedAt: DateTime.now());
          await _localDataSource.saveInstance(newInst);
          await _localDataSource.markDirty(newInst.id);
          hasChanges = true;
        }

        for (final instId in action.instancesToDelete) {
          await _localDataSource.deleteInstance(instId);
          await _localDataSource.markDirty(instId);
          hasChanges = true;
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
    } finally {
      _isProcessingMissedPolicies = false;
    }
  }
}
