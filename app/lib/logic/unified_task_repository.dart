import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nothing_ever_happens/logic/hive_local_data_source.dart';
import 'package:nothing_ever_happens/logic/task_sync_service.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/scheduler_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nothing_ever_happens/logic/initial_firebase_migration_service.dart';
import 'package:nothing_ever_happens/logic/telemetry_service.dart';
import 'package:nothing_ever_happens/logic/family.dart';
import 'package:nothing_ever_happens/logic/firestore_paths.dart';
import 'package:nothing_ever_happens/logic/notification_service.dart';
import 'package:nothing_ever_happens/logic/error_handler.dart';
import 'package:nothing_ever_happens/logic/app_logger.dart';
import 'package:nothing_ever_happens/logic/missed_policy_runner.dart';
import 'package:nothing_ever_happens/logic/task_schedule_reconciler.dart';
import 'package:nothing_ever_happens/logic/utils/app_version.dart';

class UnifiedTaskRepository implements TaskRepository {
  final HiveLocalDataSource _localDataSource;
  final TaskSyncService _syncService;
  final FirebaseFirestore? _rawFirestore;
  final TelemetryService? _telemetryService;
  final FamilyIdFetcher _familyIdFetcher;
  final TaskScheduleReconciler _scheduleReconciler;
  late final MissedPolicyRunner _missedPolicyRunner;
  final CloudFamilySchedulerClient? cloudFamilySchedulerClient;
  final bool _isActivePremium;

  @override
  final String userId;
  final NotificationService? notificationService;
  final ErrorHandler? errorHandler;
  final AppLogger? logger;

  Future<void>? _initializationFuture;

  @visibleForTesting
  DateTime? get scheduledTriggerTime =>
      _missedPolicyRunner.scheduledTriggerTime;

  /// Completes when the initial migration and repository setup finishes.
  Future<void> get initializationFuture =>
      _initializationFuture ?? Future.value();

  UnifiedTaskRepository({
    required HiveLocalDataSource localDataSource,
    required TaskSyncService syncService,
    required this.userId,
    FirebaseFirestore? firestore,
    this.notificationService,
    this.errorHandler,
    this.logger,
    this.cloudFamilySchedulerClient,
    TelemetryService? telemetryService,
    FamilyIdFetcher? familyIdFetcher,
    bool? isActivePremium,
  }) : _localDataSource = localDataSource,
       _syncService = syncService,
       _rawFirestore = firestore,
       _telemetryService = telemetryService,
       _isActivePremium = isActivePremium ?? syncService.isActivePremium,
       _scheduleReconciler = TaskScheduleReconciler(
         localDataSource: localDataSource,
         userId: userId,
       ),
       _familyIdFetcher =
           familyIdFetcher ??
           FamilyIdFetcher(
             firestore: firestore,
             userId: userId,
             errorHandler: errorHandler,
           ) {
    _missedPolicyRunner = MissedPolicyRunner(
      localDataSource: _localDataSource,
      syncService: _syncService,
      userId: userId,
      getFamilyId: getFamilyId,
      rescheduleTaskNotifications: _rescheduleOrCancelNotificationsForTask,
      cloudFamilySchedulerClient: cloudFamilySchedulerClient,
      errorHandler: errorHandler,
      logger: logger,
    );
    _initMigration();
  }

  @override
  void dispose() {
    _missedPolicyRunner.dispose();
  }

  @override
  Future<String?> getFamilyId() => _familyIdFetcher.getFamilyId();

  void _initMigration() {
    if (userId.isEmpty) {
      _initializationFuture = Future.value();
      return;
    }

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
        isActivePremium: _isActivePremium,
        logger: logger,
      );
      _initializationFuture = migrationService
          .migrateIfNeeded(force: isDifferentUser)
          .then((_) async {
            if (_localDataSource.isMigrationCompleted()) {
              _syncService.startListeningToRemote();
              await triggerMissedPolicyProcessing();
            }
          })
          .catchError((e, st) {
            errorHandler?.report(e, stackTrace: st);
            logger?.error(
              'task',
              'Initial migration error',
              error: e,
              stackTrace: st,
            );
          });
    } else if (_localDataSource.isMigrationCompleted()) {
      _syncService.startListeningToRemote();
      _initializationFuture = Future.value();
    } else {
      _initializationFuture = Future.value();
    }
  }

  @override
  Future<void> resetLocalDataAndResync() async {
    if (!_isActivePremium || userId.isEmpty) {
      return;
    }
    final migrationService = InitialFirebaseMigrationService(
      firestore: _rawFirestore,
      localDataSource: _localDataSource,
      userId: userId,
      isActivePremium: _isActivePremium,
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
    final t = task.copyWith(
      updatedAt: DateTime.now().toUtc(),
      hasPendingWrites: true,
    );
    await _localDataSource.saveTask(t);
    await _localDataSource.markDirty(t.id);
    logger?.info(
      'task',
      'Task created: ${t.id}',
      data: {'taskId': t.id, 'title': t.title},
    );
    await triggerMissedPolicyProcessing(evaluateFamilyTasks: t.isFamily);
    await _rescheduleOrCancelNotificationsForTask(t);
    _syncService.sync();
  }

  @override
  Future<void> updateTaskSchedule(TaskModification modification) async {
    final oldTask = _localDataSource
        .getTasks()
        .where((x) => x.id == modification.newTask.id)
        .firstOrNull;
    final changes = modification.changes;
    final schedulesChanged = changes.containsKey('schedules');
    final yesterday = CivilDay.fromDateTime(AppClock.now).addDays(-1);

    final t = modification.newTask.copyWith(
      lastSpawnedDate: schedulesChanged
          ? yesterday
          : modification.newTask.lastSpawnedDate,
      updatedAt: DateTime.now().toUtc(),
      hasPendingWrites: true,
    );
    await _localDataSource.saveTask(t);
    await _localDataSource.markDirty(t.id);
    logger?.info(
      'task',
      'Task updated: ${t.id}',
      data: {'taskId': t.id, 'title': t.title},
    );

    await _scheduleReconciler.reconcileInstancesOnUpdate(
      oldTask: oldTask,
      updatedTask: t,
      changes: changes,
    );

    await triggerMissedPolicyProcessing(
      evaluateFamilyTasks: t.isFamily || changes.containsKey('isFamily'),
    );
    await _rescheduleOrCancelNotificationsForTask(t);
    _syncService.sync();
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

    await notificationService?.cancelNotifications(id);
    await triggerMissedPolicyProcessing(evaluateFamilyTasks: task.isFamily);
    _syncService.sync();
    return (task: task, pendingInstances: pendingInstances);
  }

  @override
  Future<void> restoreTaskSchedule(
    TaskSchedule task,
    List<TaskInstance> pendingInstances,
  ) async {
    final t = task.copyWith(hasPendingWrites: true);
    await _localDataSource.saveTask(t);
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
    await triggerMissedPolicyProcessing(evaluateFamilyTasks: task.isFamily);
    await _rescheduleOrCancelNotificationsForTask(t);
    _syncService.sync();
  }

  @override
  Future<TaskInstance?> completeTaskInstance(String id) async {
    final instance = _localDataSource
        .getInstances()
        .where((i) => i.id == id)
        .firstOrNull;
    if (instance == null) return null;

    final task = _localDataSource
        .getTasks()
        .where((t) => t.id == instance.scheduleId)
        .firstOrNull;
    final isFamily = task?.isFamily ?? instance.isFamily;
    final familyCompletionMode =
        task?.familyCompletionMode ?? instance.familyCompletionMode;

    if (isFamily && familyCompletionMode == FamilyCompletionMode.individual) {
      final updatedUserIds = {...instance.completedByUserIds, userId}.toList();

      bool allCompleted = false;
      if (instance.assignedUserId != null) {
        allCompleted = updatedUserIds.contains(instance.assignedUserId);
      } else {
        final familyId = await getFamilyId();
        if (familyId != null && familyId.isNotEmpty && _rawFirestore != null) {
          try {
            final familyDoc = await _rawFirestore
                .collection(FirestorePaths.families)
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
          isFamily: isFamily,
          familyCompletionMode: familyCompletionMode,
          status: TaskStatus.completed,
          completedByUserId: userId,
          completedAt: AppClock.now,
          completedByUserIds: updatedUserIds,
          statusReason: InstanceStatusReason.userCompleted.value,
          lastModifiedByUserId: userId,
          lastModifiedByAppVersion: AppVersion.display,
          lastModifiedByPlatform: AppVersion.platform,
          hasPendingWrites: true,
          updatedAt: DateTime.now().toUtc(),
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
        if (isFamily) {
          final familyId = await getFamilyId();
          if (familyId != null && familyId.isNotEmpty) {
            unawaited(
              cloudFamilySchedulerClient?.triggerFamilyScheduleProcessing(
                familyId: familyId,
              ),
            );
          }
        }
        return completedInstance;
      } else {
        final partialInstance = instance.copyWith(
          isFamily: isFamily,
          familyCompletionMode: familyCompletionMode,
          completedByUserIds: updatedUserIds,
          lastModifiedByUserId: userId,
          lastModifiedByAppVersion: AppVersion.display,
          lastModifiedByPlatform: AppVersion.platform,
          hasPendingWrites: true,
          updatedAt: DateTime.now().toUtc(),
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
      isFamily: isFamily,
      familyCompletionMode: familyCompletionMode,
      status: TaskStatus.completed,
      completedByUserId: userId,
      completedAt: AppClock.now,
      statusReason: InstanceStatusReason.userCompleted.value,
      lastModifiedByUserId: userId,
      lastModifiedByAppVersion: AppVersion.display,
      lastModifiedByPlatform: AppVersion.platform,
      hasPendingWrites: true,
      updatedAt: DateTime.now().toUtc(),
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

    if (isFamily) {
      final familyId = await getFamilyId();
      if (familyId != null && familyId.isNotEmpty) {
        unawaited(
          cloudFamilySchedulerClient?.triggerFamilyScheduleProcessing(
            familyId: familyId,
          ),
        );
      }
    } else if (task != null) {
      await _spawnNextOccurrence(
        task,
        completedInstance,
        completedInstance.completedAt?.toLocal() ?? AppClock.now,
      );
      await _reEvaluateCapacityIfNeeded(task);
      await _rescheduleOrCancelNotificationsForTask(task);
    }
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
      updatedAt: DateTime.now().toUtc(),
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

    final task = _localDataSource
        .getTasks()
        .where((t) => t.id == instance.scheduleId)
        .firstOrNull;
    final isFamily = task?.isFamily ?? instance.isFamily;
    final familyCompletionMode =
        task?.familyCompletionMode ?? instance.familyCompletionMode;

    final dismissedInstance = instance.copyWith(
      isFamily: isFamily,
      familyCompletionMode: familyCompletionMode,
      status: TaskStatus.skipped,
      completedByUserId: userId,
      completedAt: AppClock.now,
      statusReason: InstanceStatusReason.userDismissed.value,
      lastModifiedByUserId: userId,
      lastModifiedByAppVersion: AppVersion.display,
      lastModifiedByPlatform: AppVersion.platform,
      hasPendingWrites: true,
      updatedAt: DateTime.now().toUtc(),
    );
    await _localDataSource.saveInstance(dismissedInstance);
    await _localDataSource.markDirty(dismissedInstance.id);
    logger?.info(
      'task',
      'Task instance dismissed: $id',
      data: {'instanceId': id, 'scheduleId': instance.scheduleId},
    );

    if (isFamily) {
      final familyId = await getFamilyId();
      if (familyId != null && familyId.isNotEmpty) {
        unawaited(
          cloudFamilySchedulerClient?.triggerFamilyScheduleProcessing(
            familyId: familyId,
          ),
        );
      }
    } else if (task != null) {
      await _spawnNextOccurrence(
        task,
        dismissedInstance,
        dismissedInstance.completedAt?.toLocal() ?? AppClock.now,
      );
      await _reEvaluateCapacityIfNeeded(task);
      await _rescheduleOrCancelNotificationsForTask(task);
    }
    _syncService.sync();
    return dismissedInstance;
  }

  Future<void> _rescheduleOrCancelNotificationsForTask(
    TaskSchedule task,
  ) async {
    if (notificationService == null) return;
    final isRecurring = task.schedules.any((s) => s is! OneOffSchedule);
    if (isRecurring) {
      await notificationService?.scheduleNotifications(task);
    } else {
      final hasRemainingPending = _localDataSource.getInstances().any(
        (i) => i.scheduleId == task.id && i.status == TaskStatus.pending,
      );
      if (hasRemainingPending || task.isFamily) {
        await notificationService?.scheduleNotifications(task);
      } else {
        await notificationService?.cancelNotifications(task.id);
      }
    }
  }

  Future<void> _reEvaluateCapacityIfNeeded(TaskSchedule? task) async {
    if (task == null || task.estimatedDuration == null) return;
    final hasCapacityDependentTasks = _localDataSource.getTasks().any(
      (t) => !t.isFamily && t.skipIfNoCapacity,
    );
    if (hasCapacityDependentTasks) {
      await triggerMissedPolicyProcessing(evaluateFamilyTasks: false);
    }
  }

  Future<void> _spawnNextOccurrence(
    TaskSchedule task,
    TaskInstance completedInstance,
    DateTime now,
  ) async {
    final isRecurring = task.schedules.any((s) => s is! OneOffSchedule);
    if (!isRecurring) return;

    final instances = _localDataSource
        .getInstances()
        .where((i) => i.scheduleId == task.id)
        .toList();
    final nextInst =
        SchedulerEngine(
          appVersion: AppVersion.display,
          platform: AppVersion.platform,
        ).getNextOccurrenceToSpawn(
          task,
          completedInstance,
          now,
          instances,
          userId: userId,
        );
    if (nextInst != null) {
      final nextWithPendingWrites = nextInst.copyWith(
        hasPendingWrites: true,
        updatedAt: DateTime.now().toUtc(),
      );
      await _localDataSource.saveInstance(nextWithPendingWrites);
      await _localDataSource.markDirty(nextWithPendingWrites.id);
      logger?.info(
        'task',
        'Spawned next occurrence: ${nextWithPendingWrites.id}',
        data: {'instanceId': nextWithPendingWrites.id, 'scheduleId': task.id},
      );
    }
  }

  @override
  Future<void> undoResolveTaskInstance(TaskInstance resolvedInstance) async {
    final task = _localDataSource
        .getTasks()
        .where((t) => t.id == resolvedInstance.scheduleId)
        .firstOrNull;
    final isFamilyTask = task?.isFamily ?? resolvedInstance.isFamily;
    final familyCompletionMode =
        task?.familyCompletionMode ?? resolvedInstance.familyCompletionMode;

    if (isFamilyTask &&
        familyCompletionMode == FamilyCompletionMode.individual) {
      final updatedUserIds = resolvedInstance.completedByUserIds
          .where((uid) => uid != userId)
          .toList();
      final pendingInstance = resolvedInstance.copyWith(
        isFamily: isFamilyTask,
        familyCompletionMode: familyCompletionMode,
        status: TaskStatus.pending,
        clearCompletedByUserId: true,
        clearCompletedAt: true,
        clearStatusReason: true,
        completedByUserIds: updatedUserIds,
        lastModifiedByUserId: userId,
        lastModifiedByAppVersion: AppVersion.display,
        lastModifiedByPlatform: AppVersion.platform,
        hasPendingWrites: true,
        updatedAt: DateTime.now().toUtc(),
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
      final familyId = await getFamilyId();
      if (familyId != null && familyId.isNotEmpty) {
        unawaited(
          cloudFamilySchedulerClient?.triggerFamilyScheduleProcessing(
            familyId: familyId,
          ),
        );
      }
      return;
    }

    final pendingInstance = resolvedInstance.copyWith(
      isFamily: isFamilyTask,
      familyCompletionMode: familyCompletionMode,
      status: TaskStatus.pending,
      clearCompletedByUserId: true,
      clearCompletedAt: true,
      clearStatusReason: true,
      lastModifiedByUserId: userId,
      lastModifiedByAppVersion: AppVersion.display,
      lastModifiedByPlatform: AppVersion.platform,
      hasPendingWrites: true,
      updatedAt: DateTime.now().toUtc(),
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

    if (isFamilyTask) {
      // Family task instance lifecycle is managed by the cloud scheduler;
      // do not delete locally spawned next occurrences on-device.
      final familyId = await getFamilyId();
      if (familyId != null && familyId.isNotEmpty) {
        unawaited(
          cloudFamilySchedulerClient?.triggerFamilyScheduleProcessing(
            familyId: familyId,
          ),
        );
      }
    } else if (task != null) {
      if (task.schedules.any((s) => s is! OneOffSchedule)) {
        final instances = _localDataSource
            .getInstances()
            .where(
              (i) => i.scheduleId == task.id && i.id != resolvedInstance.id,
            )
            .toList();
        final nextId = const SchedulerEngine().getNextOccurrenceIdToDelete(
          task,
          resolvedInstance,
          resolvedInstance.completedAt?.toLocal() ?? AppClock.now,
          instances,
        );
        if (nextId != null && nextId != resolvedInstance.id) {
          await _localDataSource.deleteInstance(nextId);
          await _localDataSource.markDirty(nextId);
        }
      }
      await _reEvaluateCapacityIfNeeded(task);
      await notificationService?.scheduleNotifications(task);
    }
    _syncService.sync();
  }

  @override
  Future<void> triggerMissedPolicyProcessing({
    bool evaluateFamilyTasks = true,
    Future<void> Function()? postProcess,
  }) => _missedPolicyRunner.triggerMissedPolicyProcessing(
    evaluateFamilyTasks: evaluateFamilyTasks,
    postProcess: postProcess,
  );
}
