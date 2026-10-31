import 'dart:async';

import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/logic/app_logger.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/error_handler.dart';
import 'package:nothing_ever_happens/logic/hive_local_data_source.dart';
import 'package:nothing_ever_happens/logic/scheduler_engine.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_sync_service.dart';
import 'package:nothing_ever_happens/logic/utils/app_version.dart';

/// Coordinates serialized missed-occurrence policy evaluation, dynamic next-trigger
/// timers, and post-evaluation notification/sync updates.
class MissedPolicyRunner {
  final HiveLocalDataSource _localDataSource;
  final TaskSyncService _syncService;
  final String _userId;
  final Future<String?> Function() _getFamilyId;
  final Future<void> Function(TaskSchedule task) _rescheduleTaskNotifications;
  final CloudFamilySchedulerClient? _cloudFamilySchedulerClient;
  final ErrorHandler? _errorHandler;
  final AppLogger? _logger;

  Future<void>? _activeProcessingFuture;
  bool _hasQueuedProcessing = false;
  bool _queuedEvaluateFamilyTasks = false;
  final List<Future<void> Function()> _queuedPostProcessCallbacks = [];
  Timer? _triggerTimer;
  DateTime? _scheduledTriggerTime;
  bool _isDisposed = false;

  MissedPolicyRunner({
    required HiveLocalDataSource localDataSource,
    required TaskSyncService syncService,
    required String userId,
    required Future<String?> Function() getFamilyId,
    required Future<void> Function(TaskSchedule task)
    rescheduleTaskNotifications,
    CloudFamilySchedulerClient? cloudFamilySchedulerClient,
    ErrorHandler? errorHandler,
    AppLogger? logger,
  }) : _localDataSource = localDataSource,
       _syncService = syncService,
       _userId = userId,
       _getFamilyId = getFamilyId,
       _rescheduleTaskNotifications = rescheduleTaskNotifications,
       _cloudFamilySchedulerClient = cloudFamilySchedulerClient,
       _errorHandler = errorHandler,
       _logger = logger;

  DateTime? get scheduledTriggerTime => _scheduledTriggerTime;

  void dispose() {
    _isDisposed = true;
    _triggerTimer?.cancel();
    _triggerTimer = null;
    _scheduledTriggerTime = null;
  }

  Future<void> triggerMissedPolicyProcessing({
    bool evaluateFamilyTasks = true,
    Future<void> Function()? postProcess,
  }) async {
    if (_isDisposed) return;
    if (!_localDataSource.isMigrationCompleted()) {
      if (postProcess != null) {
        await postProcess();
      }
      return;
    }
    if (postProcess != null) {
      _queuedPostProcessCallbacks.add(postProcess);
    }
    if (evaluateFamilyTasks) {
      _queuedEvaluateFamilyTasks = true;
    }
    while (true) {
      if (_isDisposed) return;
      final active = _activeProcessingFuture;
      if (active != null) {
        _hasQueuedProcessing = true;
        await active;
        if (_isDisposed ||
            (!_hasQueuedProcessing && _queuedPostProcessCallbacks.isEmpty)) {
          return;
        }
        continue;
      }

      _activeProcessingFuture = _processQueue();
      await _activeProcessingFuture;
      if (_isDisposed ||
          (!_hasQueuedProcessing && _queuedPostProcessCallbacks.isEmpty)) {
        return;
      }
    }
  }

  Future<void> _processQueue() async {
    try {
      do {
        if (_isDisposed) return;
        _hasQueuedProcessing = false;
        final shouldEvaluateFamily = _queuedEvaluateFamilyTasks;
        _queuedEvaluateFamilyTasks = false;

        final callbacksToRun = List<Future<void> Function()>.from(
          _queuedPostProcessCallbacks,
        );
        _queuedPostProcessCallbacks.clear();

        try {
          await _syncService.waitForInitialSync;
          if (_isDisposed) return;
          if (shouldEvaluateFamily) {
            final familyId = await _getFamilyId();
            if (_isDisposed) return;
            if (familyId != null && familyId.isNotEmpty) {
              unawaited(
                _cloudFamilySchedulerClient?.triggerFamilyScheduleProcessing(
                  familyId: familyId,
                ),
              );
            }
          }
          await _doProcessMissedPolicies();
        } catch (e, st) {
          _errorHandler?.report(e, stackTrace: st);
          _logger?.error(
            'task',
            'Error in auto-processing missed policies loop',
            error: e,
            stackTrace: st,
          );
        }

        for (final cb in callbacksToRun) {
          if (_isDisposed) return;
          try {
            await cb();
          } catch (e, st) {
            _errorHandler?.report(e, stackTrace: st);
            _logger?.error(
              'task',
              'Error in postProcess callback',
              error: e,
              stackTrace: st,
            );
          }
        }
      } while (!_isDisposed &&
          (_hasQueuedProcessing || _queuedPostProcessCallbacks.isNotEmpty));
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
        if (t != null && t.estimatedDuration != null) {
          final hours = t.estimatedDuration!.inMinutes / 60.0;
          if (t.isFamily) {
            final assignedUser = inst.assignedUserId ?? t.assignedUserId;
            if (assignedUser != null && assignedUser.isNotEmpty) {
              if (assignedUser == _userId) {
                dayPlannedHours[inst.scheduledDate] =
                    (dayPlannedHours[inst.scheduledDate] ?? 0.0) + hours;
              }
            } else if (inst.familyCompletionMode ==
                    FamilyCompletionMode.anyone &&
                inst.status == TaskStatus.completed) {
              if (_userId == null ||
                  inst.completedByUserId == _userId ||
                  inst.completedByUserIds.contains(_userId)) {
                dayPlannedHours[inst.scheduledDate] =
                    (dayPlannedHours[inst.scheduledDate] ?? 0.0) + hours;
              }
            } else {
              dayPlannedHours[inst.scheduledDate] =
                  (dayPlannedHours[inst.scheduledDate] ?? 0.0) + hours;
            }
          } else if (inst.status != TaskStatus.pending) {
            final assignedUser = inst.assignedUserId ?? t.assignedUserId;
            if (assignedUser == null ||
                assignedUser.isEmpty ||
                assignedUser == _userId) {
              dayPlannedHours[inst.scheduledDate] =
                  (dayPlannedHours[inst.scheduledDate] ?? 0.0) + hours;
            }
          }
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
      if (a.skipIfNoCapacity != b.skipIfNoCapacity) {
        return a.skipIfNoCapacity ? 1 : -1;
      }

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
    final allTriggerTimes = <DateTime>[];
    final tasksNeedingNotificationUpdate = <TaskSchedule>[];

    for (final task in tasksToEvaluate) {
      final taskInstances = instancesByScheduleId[task.id] ?? [];

      if (task.isFamily) {
        bool familyTaskReconciled = false;
        for (final inst in taskInstances) {
          if (inst.isFamily != task.isFamily ||
              inst.familyCompletionMode != task.familyCompletionMode) {
            final updatedInst = inst.copyWith(
              isFamily: task.isFamily,
              familyCompletionMode: task.familyCompletionMode,
              lastModifiedByUserId: _userId,
              lastModifiedByAppVersion: AppVersion.display,
              lastModifiedByPlatform: AppVersion.platform,
              updatedAt: DateTime.now().toUtc(),
              hasPendingWrites: true,
            );
            instancesToSave.add(updatedInst);
            dirtyIds.add(updatedInst.id);
            familyTaskReconciled = true;

            final idx = allInstances.indexWhere((x) => x.id == inst.id);
            if (idx >= 0) {
              allInstances[idx] = updatedInst;
            }
          }
        }
        if (familyTaskReconciled) {
          tasksNeedingNotificationUpdate.add(task);
        }
        // Shared family tasks are evaluated exclusively by the Cloud Family Scheduler.
        continue;
      }

      final action =
          SchedulerEngine(
            logger: _logger,
            appVersion: AppVersion.display,
            platform: AppVersion.platform,
          ).evaluate(
            task,
            taskInstances,
            now,
            userSettings: userSettings,
            dayPlannedHours: dayPlannedHours,
            applyCapacityLimits:
                task.assignedUserId == null || task.assignedUserId == _userId,
            userId: _userId,
          );

      allTriggerTimes.addAll(action.triggerTimes);

      for (final inst in action.instancesToUpdate) {
        final updatedInst = inst.copyWith(
          updatedAt: DateTime.now().toUtc(),
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
          updatedAt: DateTime.now().toUtc(),
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
        if (task.estimatedDuration != null) {
          final hours = task.estimatedDuration!.inMinutes / 60.0;
          dayPlannedHours[inst.scheduledDate] =
              (dayPlannedHours[inst.scheduledDate] ?? 0.0) + hours;
        }
      }

      TaskSchedule effectiveTask = task;
      if (action.updatedSchedule != null) {
        final updatedTask = action.updatedSchedule!.copyWith(
          updatedAt: DateTime.now().toUtc(),
          hasPendingWrites: true,
        );
        tasksToSave.add(updatedTask);
        dirtyIds.add(updatedTask.id);
        effectiveTask = updatedTask;
      }

      if (action.instancesToUpdate.isNotEmpty ||
          action.instancesToSpawn.isNotEmpty ||
          action.instancesToDelete.isNotEmpty) {
        tasksNeedingNotificationUpdate.add(effectiveTask);
      }
    }

    // Sweep: delete pending instances whose schedule no longer exists.
    final taskIds = tasks.map((t) => t.id).toSet();
    for (final inst in List<TaskInstance>.from(allInstances)) {
      if (inst.isFamily) {
        // Shared family instances are maintained exclusively by the Cloud Family Scheduler.
        continue;
      }
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

    for (final affectedTask in tasksNeedingNotificationUpdate) {
      if (_isDisposed) return;
      await _rescheduleTaskNotifications(affectedTask);
    }

    _logger?.debug(
      'scheduler',
      'Scheduler cycle evaluated ${tasksToEvaluate.length} tasks',
      data: {'taskCount': tasksToEvaluate.length, 'hasChanges': hasChanges},
    );

    if (hasChanges) {
      _syncService.sync();
    }

    if (_isDisposed) return;
    _scheduleNextDynamicTrigger(allTriggerTimes, now);
  }

  void _scheduleNextDynamicTrigger(List<DateTime> triggerTimes, DateTime now) {
    if (_isDisposed) return;

    DateTime? earliest;
    for (final t in triggerTimes) {
      if (t.isAfter(now)) {
        if (earliest == null || t.isBefore(earliest)) {
          earliest = t;
        }
      }
    }

    if (earliest == null) {
      _triggerTimer?.cancel();
      _triggerTimer = null;
      _scheduledTriggerTime = null;
      return;
    }

    _triggerTimer?.cancel();
    _scheduledTriggerTime = earliest;
    final delay = earliest.difference(now);
    _triggerTimer = Timer(delay, () {
      if (_isDisposed) return;
      _scheduledTriggerTime = null;
      triggerMissedPolicyProcessing(evaluateFamilyTasks: false);
    });
  }
}
