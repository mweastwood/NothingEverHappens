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
import 'package:nothing_ever_happens/logic/telemetry_service.dart';
import 'package:nothing_ever_happens/logic/family.dart';
import 'package:nothing_ever_happens/logic/notification_service.dart';
import 'package:nothing_ever_happens/logic/error_handler.dart';
import 'package:nothing_ever_happens/logic/app_logger.dart';
import 'package:nothing_ever_happens/logic/utils/app_version.dart';

class UnifiedTaskRepository implements TaskRepository {
  final HiveLocalDataSource _localDataSource;
  final TaskSyncService _syncService;
  final FirebaseFirestore? _rawFirestore;
  final TelemetryService? _telemetryService;
  final FamilyIdFetcher _familyIdFetcher;

  @override
  final String userId;
  final NotificationService? notificationService;
  final ErrorHandler? errorHandler;
  final AppLogger? logger;

  Future<void>? _activeProcessingFuture;
  bool _hasQueuedProcessing = false;
  final List<Future<void> Function()> _queuedPostProcessCallbacks = [];

  UnifiedTaskRepository({
    required HiveLocalDataSource localDataSource,
    required TaskSyncService syncService,
    required this.userId,
    FirebaseFirestore? firestore,
    this.notificationService,
    this.errorHandler,
    this.logger,
    TelemetryService? telemetryService,
    FamilyIdFetcher? familyIdFetcher,
  }) : _localDataSource = localDataSource,
       _syncService = syncService,
       _rawFirestore = firestore,
       _telemetryService = telemetryService,
       _familyIdFetcher =
           familyIdFetcher ??
           FamilyIdFetcher(
             firestore: firestore,
             userId: userId,
             errorHandler: errorHandler,
           ) {
    _initMigration();
  }

  @override
  void dispose() {}

  @override
  Future<String?> getFamilyId() => _familyIdFetcher.getFamilyId();

  void _initMigration() {
    if (userId.isEmpty) return;

    final activeUserId = _localDataSource.getActiveUserId();
    final isDifferentUser =
        activeUserId != null &&
        activeUserId.isNotEmpty &&
        activeUserId != userId;

    if (isDifferentUser || !_localDataSource.isMigrationCompleted()) {
      final migrationService = InitialFirebaseMigrationService(
        firestore: _rawFirestore,
        localDataSource: _localDataSource,
        userId: userId,
        logger: logger,
      );
      migrationService
          .migrateIfNeeded(force: isDifferentUser)
          .then((_) {
            if (_localDataSource.isMigrationCompleted()) {
              _syncService.startListeningToRemote();
              triggerMissedPolicyProcessing();
            }
          })
          .catchError((e) {
            // ignore: avoid_print
            print('Initial migration error: $e');
          });
    } else if (_localDataSource.isMigrationCompleted()) {
      _syncService.startListeningToRemote();
    }
  }

  @override
  Future<void> resetLocalDataAndResync() async {
    final migrationService = InitialFirebaseMigrationService(
      firestore: _rawFirestore,
      localDataSource: _localDataSource,
      userId: userId,
      logger: logger,
    );
    await migrationService.migrateIfNeeded(force: true);
    if (_localDataSource.isMigrationCompleted()) {
      _syncService.startListeningToRemote();
      await triggerMissedPolicyProcessing();
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
    final t = task.copyWith(updatedAt: DateTime.now(), hasPendingWrites: true);
    await _localDataSource.saveTask(t);
    await _localDataSource.markDirty(t.id);
    logger?.info(
      'task',
      'Task created: ${t.id}',
      data: {'taskId': t.id, 'title': t.title},
    );
    _syncService.sync();
    await triggerMissedPolicyProcessing();
  }

  @override
  Future<void> updateTaskSchedule(TaskModification modification) async {
    final t = modification.newTask.copyWith(
      updatedAt: DateTime.now(),
      hasPendingWrites: true,
    );
    await _localDataSource.saveTask(t);
    await _localDataSource.markDirty(t.id);
    logger?.info(
      'task',
      'Task updated: ${t.id}',
      data: {'taskId': t.id, 'title': t.title},
    );

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
          hasPendingWrites: true,
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
    logger?.info('task', 'Task deleted: $id', data: {'taskId': id});

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
  Future<void> restoreTaskSchedule(
    TaskSchedule task,
    List<TaskInstance> pendingInstances,
  ) async {
    await _localDataSource.saveTask(task.copyWith(hasPendingWrites: true));
    await _localDataSource.markDirty(task.id);
    for (final inst in pendingInstances) {
      await _localDataSource.saveInstance(
        inst.copyWith(hasPendingWrites: true),
      );
      await _localDataSource.markDirty(inst.id);
    }
    logger?.info(
      'task',
      'Task restored: ${task.id}',
      data: {'taskId': task.id, 'title': task.title},
    );
    _syncService.sync();
    await triggerMissedPolicyProcessing();
  }

  @override
  Future<TaskInstance?> completeTaskInstance(String id) async {
    final instance = _localDataSource
        .getInstances()
        .where((i) => i.id == id)
        .firstOrNull;
    if (instance == null) return null;

    if (instance.isFamily &&
        instance.familyCompletionMode == FamilyCompletionMode.individual) {
      final updatedUserIds = {...instance.completedByUserIds, userId}.toList();

      bool allCompleted = false;
      if (instance.assignedUserId != null) {
        allCompleted = updatedUserIds.contains(instance.assignedUserId);
      } else {
        final familyId = await getFamilyId();
        if (familyId != null && familyId.isNotEmpty && _rawFirestore != null) {
          try {
            final familyDoc = await _rawFirestore
                .collection('families')
                .doc(familyId)
                .get();
            if (familyDoc.exists && familyDoc.data() != null) {
              final family = Family.fromJson(familyDoc.data()!, familyDoc.id);
              if (family.members.isNotEmpty) {
                allCompleted = family.members.keys.every(
                  (memberId) => updatedUserIds.contains(memberId),
                );
              } else {
                allCompleted = true;
              }
            } else {
              allCompleted = true;
            }
          } catch (_) {
            allCompleted = true;
          }
        } else {
          allCompleted = true;
        }
      }

      if (allCompleted) {
        final completedInstance = instance.copyWith(
          status: TaskStatus.completed,
          completedByUserId: userId,
          completedAt: AppClock.now,
          completedByUserIds: updatedUserIds,
          hasPendingWrites: true,
          updatedAt: DateTime.now(),
        );
        await _localDataSource.saveInstance(completedInstance);
        await _localDataSource.markDirty(completedInstance.id);
        final totalCompleted = await _localDataSource
            .incrementTasksCompletedCount();
        await _telemetryService?.logTaskCompleted(
          taskId: id,
          scheduleId: instance.scheduleId,
          totalCompletedCount: totalCompleted,
        );
        logger?.info(
          'task',
          'Task instance completed: $id',
          data: {'instanceId': id, 'scheduleId': instance.scheduleId},
        );

        _syncService.sync();
        return completedInstance;
      } else {
        final partialInstance = instance.copyWith(
          completedByUserIds: updatedUserIds,
          hasPendingWrites: true,
          updatedAt: DateTime.now(),
        );
        await _localDataSource.saveInstance(partialInstance);
        await _localDataSource.markDirty(partialInstance.id);
        logger?.info(
          'task',
          'Task instance individually completed: $id by $userId',
          data: {'instanceId': id, 'scheduleId': instance.scheduleId},
        );

        _syncService.sync();
        return partialInstance;
      }
    }

    final completedInstance = instance.copyWith(
      status: TaskStatus.completed,
      completedByUserId: userId,
      completedAt: AppClock.now,
      statusReason: 'user_completed',
      lastModifiedByUserId: userId,
      lastModifiedByAppVersion: AppVersion.display,
      hasPendingWrites: true,
      updatedAt: DateTime.now(),
    );
    await _localDataSource.saveInstance(completedInstance);
    await _localDataSource.markDirty(completedInstance.id);
    final totalCompleted = await _localDataSource
        .incrementTasksCompletedCount();
    await _telemetryService?.logTaskCompleted(
      taskId: id,
      scheduleId: instance.scheduleId,
      totalCompletedCount: totalCompleted,
    );
    logger?.info(
      'task',
      'Task instance completed: $id',
      data: {'instanceId': id, 'scheduleId': instance.scheduleId},
    );

    _syncService.sync();
    return completedInstance;
  }

  @override
  Future<TaskInstance?> uncompleteTaskInstance(String id) async {
    final instance = _localDataSource
        .getInstances()
        .where((i) => i.id == id)
        .firstOrNull;
    if (instance == null) return null;
    await undoResolveTaskInstance(instance);
    return _localDataSource.getInstances().where((i) => i.id == id).firstOrNull;
  }

  @override
  Future<void> saveTaskInstance(TaskInstance instance) async {
    final updated = instance.copyWith(
      hasPendingWrites: true,
      updatedAt: DateTime.now(),
    );
    await _localDataSource.saveInstance(updated);
    await _localDataSource.markDirty(updated.id);
    _syncService.sync();
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
      statusReason: 'user_dismissed',
      lastModifiedByUserId: userId,
      lastModifiedByAppVersion: AppVersion.display,
      hasPendingWrites: true,
      updatedAt: DateTime.now(),
    );
    await _localDataSource.saveInstance(dismissedInstance);
    await _localDataSource.markDirty(dismissedInstance.id);
    logger?.info(
      'task',
      'Task instance dismissed: $id',
      data: {'instanceId': id, 'scheduleId': instance.scheduleId},
    );

    _syncService.sync();
    return dismissedInstance;
  }

  @override
  Future<void> undoResolveTaskInstance(TaskInstance resolvedInstance) async {
    if (resolvedInstance.isFamily &&
        resolvedInstance.familyCompletionMode ==
            FamilyCompletionMode.individual) {
      final updatedUserIds = resolvedInstance.completedByUserIds
          .where((uid) => uid != userId)
          .toList();
      final pendingInstance = resolvedInstance.copyWith(
        status: TaskStatus.pending,
        clearCompletedByUserId: true,
        clearCompletedAt: true,
        completedByUserIds: updatedUserIds,
        hasPendingWrites: true,
        updatedAt: DateTime.now(),
      );
      await _localDataSource.saveInstance(pendingInstance);
      await _localDataSource.markDirty(pendingInstance.id);
      logger?.info(
        'task',
        'Task instance individual completion undone: ${resolvedInstance.id}',
        data: {
          'instanceId': resolvedInstance.id,
          'scheduleId': resolvedInstance.scheduleId,
        },
      );
      _syncService.sync();
      return;
    }

    final pendingInstance = resolvedInstance.copyWith(
      status: TaskStatus.pending,
      clearCompletedByUserId: true,
      clearCompletedAt: true,
      hasPendingWrites: true,
      updatedAt: DateTime.now(),
    );
    await _localDataSource.saveInstance(pendingInstance);
    await _localDataSource.markDirty(pendingInstance.id);
    logger?.info(
      'task',
      'Task instance status undone: ${resolvedInstance.id}',
      data: {
        'instanceId': resolvedInstance.id,
        'scheduleId': resolvedInstance.scheduleId,
      },
    );

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
    if (!_localDataSource.isMigrationCompleted()) {
      if (postProcess != null) {
        await postProcess();
      }
      return;
    }
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

    final instancesToSave = <TaskInstance>[];
    final instancesToDelete = <String>[];
    final tasksToSave = <TaskSchedule>[];
    final dirtyIds = <String>[];

    for (final task in tasksToEvaluate) {
      final taskInstances = instancesByScheduleId[task.id] ?? [];

      final action = SchedulerEngine(logger: logger).evaluate(
        task,
        taskInstances,
        now,
        userSettings: userSettings,
        dayPlannedHours: dayPlannedHours,
        applyCapacityLimits:
            task.assignedUserId == null || task.assignedUserId == userId,
        userId: userId,
      );

      for (final inst in action.instancesToUpdate) {
        final updatedInst = inst.copyWith(
          updatedAt: DateTime.now(),
          hasPendingWrites: true,
        );
        instancesToSave.add(updatedInst);
        dirtyIds.add(updatedInst.id);

        final idx = allInstances.indexWhere((x) => x.id == inst.id);
        if (idx >= 0) {
          allInstances[idx] = updatedInst;
        }
      }

      for (final inst in action.instancesToSpawn) {
        final newInst = inst.copyWith(
          updatedAt: DateTime.now(),
          hasPendingWrites: true,
        );
        instancesToSave.add(newInst);
        dirtyIds.add(newInst.id);

        allInstances.add(newInst);
      }

      for (final instId in action.instancesToDelete) {
        instancesToDelete.add(instId);
        dirtyIds.add(instId);
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
          hasPendingWrites: true,
        );
        tasksToSave.add(updatedTask);
        dirtyIds.add(updatedTask.id);
      }
    }

    // Sweep: delete pending instances whose schedule no longer exists.
    final taskIds = tasks.map((t) => t.id).toSet();
    for (final inst in List<TaskInstance>.from(allInstances)) {
      if (inst.status == TaskStatus.pending &&
          !taskIds.contains(inst.scheduleId)) {
        instancesToDelete.add(inst.id);
        dirtyIds.add(inst.id);
        allInstances.remove(inst);
      }
    }

    if (instancesToSave.isNotEmpty) {
      await _localDataSource.saveInstances(instancesToSave);
      hasChanges = true;
    }

    if (instancesToDelete.isNotEmpty) {
      await _localDataSource.deleteInstances(instancesToDelete);
      hasChanges = true;
    }

    if (tasksToSave.isNotEmpty) {
      await _localDataSource.saveTasks(tasksToSave);
      hasChanges = true;
    }

    if (dirtyIds.isNotEmpty) {
      await _localDataSource.markDirtyBatch(dirtyIds);
    }

    logger?.debug(
      'scheduler',
      'Scheduler cycle evaluated ${tasksToEvaluate.length} tasks',
      data: {'taskCount': tasksToEvaluate.length, 'hasChanges': hasChanges},
    );

    if (hasChanges) {
      _syncService.sync();
    }
  }
}
