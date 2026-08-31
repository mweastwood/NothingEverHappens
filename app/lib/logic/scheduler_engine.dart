import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import 'app_logger.dart';
import 'civil_day.dart';
import 'task_schedule.dart';
import 'task_instance.dart';
import 'relative_time.dart';
import 'user_settings.dart';
import 'utils/app_version.dart';

class SchedulerAction {
  final List<TaskInstance> instancesToUpdate;
  final List<TaskInstance> instancesToSpawn;
  final List<String> instancesToDelete;
  final TaskSchedule? updatedSchedule;
  final List<DateTime> triggerTimes;

  const SchedulerAction({
    this.instancesToUpdate = const [],
    this.instancesToSpawn = const [],
    this.instancesToDelete = const [],
    this.updatedSchedule,
    this.triggerTimes = const [],
  });
}

class SchedulerEvaluationContext {
  final TaskSchedule task;
  final List<TaskInstance> taskInstances;
  final DateTime now;
  final CivilDay today;
  final UserSettings? userSettings;
  final Map<CivilDay, double>? dayPlannedHours;
  final bool applyCapacityLimits;
  final int? futureInstancesCount;
  final String? userId;

  const SchedulerEvaluationContext({
    required this.task,
    required this.taskInstances,
    required this.now,
    required this.today,
    this.userSettings,
    this.dayPlannedHours,
    this.applyCapacityLimits = true,
    this.futureInstancesCount,
    this.userId,
  });
}

class SchedulerEngine {
  /// Maximum number of days into the future to evaluate schedule rules.
  static const int maxEvaluationDays = 30;

  /// Default available capacity in hours per day when user settings are not available.
  static const double defaultDailyCapacityHours = 8.0;

  /// Conversion factor for minutes to hours.
  static const double minutesPerHour = 60.0;

  final String Function() generateId;
  final AppLogger? logger;

  const SchedulerEngine({String Function()? generateId, this.logger})
    : generateId = generateId ?? TaskInstance.generateId;

  SchedulerAction evaluate(
    TaskSchedule task,
    List<TaskInstance> taskInstances,
    DateTime now, {
    int? futureInstancesCount,
    UserSettings? userSettings,
    Map<CivilDay, double>? dayPlannedHours,
    bool applyCapacityLimits = true,
    String? userId,
  }) {
    final today = CivilDay.fromDateTime(now);
    final context = SchedulerEvaluationContext(
      task: task,
      taskInstances: taskInstances,
      now: now,
      today: today,
      userSettings: userSettings,
      dayPlannedHours: dayPlannedHours,
      applyCapacityLimits: applyCapacityLimits,
      futureInstancesCount: futureInstancesCount,
      userId: userId,
    );

    final isRecurring = task.schedules.any((s) => s is! OneOffSchedule);

    if (!isRecurring) {
      return _evaluateOneOff(context);
    }

    final recurringResult = _evaluateRecurringRules(context);
    final List<TaskInstance> toUpdate = recurringResult.toUpdate;
    final List<TaskInstance> toSpawn = recurringResult.toSpawn;
    final List<String> toDelete = recurringResult.toDelete;
    final CivilDay? maxSpawned = recurringResult.maxSpawned;

    TaskSchedule? updatedSchedule;
    if (maxSpawned != null &&
        (task.lastSpawnedDate == null ||
            maxSpawned.compareTo(task.lastSpawnedDate!) > 0)) {
      updatedSchedule = task.copyWith(lastSpawnedDate: maxSpawned);
    }

    final capacityResult = _applyCapacityLimits(
      context,
      toSpawn: toSpawn,
      toUpdate: toUpdate,
      toDelete: toDelete,
    );
    final finalToSpawn = capacityResult.finalToSpawn;
    final finalToUpdate = capacityResult.finalToUpdate;

    final uniqueTriggerTimes = _calculateTriggerTimes(
      context,
      toSpawn: finalToSpawn,
      toUpdate: finalToUpdate,
    );

    return SchedulerAction(
      instancesToUpdate: finalToUpdate,
      instancesToSpawn: finalToSpawn,
      instancesToDelete: toDelete,
      updatedSchedule: updatedSchedule,
      triggerTimes: uniqueTriggerTimes,
    );
  }

  static TaskInstance _selectCanonicalInstance(List<TaskInstance> instances) {
    assert(instances.isNotEmpty);
    if (instances.length == 1) return instances.first;

    final sorted = List<TaskInstance>.from(instances);
    sorted.sort((a, b) {
      int score(TaskInstance inst) {
        if (inst.status == TaskStatus.completed || inst.completedAt != null) {
          return 2;
        }
        if (inst.status != TaskStatus.pending) {
          return 1;
        }
        return 0;
      }

      final scoreA = score(a);
      final scoreB = score(b);
      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA);
      }
      final timeComp = b.updatedAt.compareTo(a.updatedAt);
      if (timeComp != 0) return timeComp;
      return b.id.compareTo(a.id);
    });

    return sorted.first;
  }

  ({
    List<TaskInstance> toUpdate,
    List<TaskInstance> toSpawn,
    List<String> toDelete,
    CivilDay? maxSpawned,
  })
  _evaluateRecurringRules(SchedulerEvaluationContext context) {
    final task = context.task;
    final List<TaskInstance> toUpdate = [];
    final List<TaskInstance> toSpawn = [];
    final List<String> toDelete = [];
    CivilDay? maxSpawned;

    for (int i = 0; i < task.schedules.length; i++) {
      final s = task.schedules[i];

      if (s.schedulingPolicy is CompletionRelativePolicy) {
        _evaluateCompletionRelativeRule(
          context,
          s,
          toSpawn: toSpawn,
          toDelete: toDelete,
        );
      } else {
        maxSpawned = _evaluateFixedCalendarRule(
          context,
          s,
          toUpdate: toUpdate,
          toSpawn: toSpawn,
          toDelete: toDelete,
          maxSpawned: maxSpawned,
        );
      }
    }

    return (
      toUpdate: toUpdate,
      toSpawn: toSpawn,
      toDelete: toDelete,
      maxSpawned: maxSpawned,
    );
  }

  void _evaluateCompletionRelativeRule(
    SchedulerEvaluationContext context,
    TaskScheduleRule s, {
    required List<TaskInstance> toSpawn,
    required List<String> toDelete,
  }) {
    final task = context.task;
    final taskInstances = context.taskInstances;
    final now = context.now;
    final policy = s.schedulingPolicy as CompletionRelativePolicy;
    final ruleInstances = taskInstances
        .where((inst) => _isInstanceForRule(inst, s, task))
        .toList();

    final Map<CivilDay, List<TaskInstance>> instancesByDate = {};
    for (final inst in ruleInstances) {
      instancesByDate.putIfAbsent(inst.scheduledDate, () => []).add(inst);
    }

    final List<TaskInstance> canonicalInstances = [];
    for (final entry in instancesByDate.entries) {
      final insts = entry.value;
      if (insts.length > 1) {
        final canonical = _selectCanonicalInstance(insts);
        canonicalInstances.add(canonical);
        for (final inst in insts) {
          if (inst.id != canonical.id && !toDelete.contains(inst.id)) {
            toDelete.add(inst.id);
          }
        }
      } else {
        canonicalInstances.add(insts.first);
      }
    }

    final pendingForSchedule =
        canonicalInstances
            .where((inst) => inst.status == TaskStatus.pending)
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    if (pendingForSchedule.length > 1) {
      for (int p = 1; p < pendingForSchedule.length; p++) {
        if (!toDelete.contains(pendingForSchedule[p].id)) {
          toDelete.add(pendingForSchedule[p].id);
        }
      }
    }

    if (pendingForSchedule.isEmpty) {
      CivilDay? dateToSpawn;
      if (canonicalInstances.isEmpty) {
        dateToSpawn = s.scheduledDate;
      } else {
        final resolved =
            canonicalInstances
                .where((inst) => inst.status != TaskStatus.pending)
                .toList()
              ..sort(
                (a, b) =>
                    (b.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                        .compareTo(
                          a.completedAt ??
                              DateTime.fromMillisecondsSinceEpoch(0),
                        ),
              );
        if (resolved.isNotEmpty) {
          final latest = resolved.first;
          final completedAtTime = latest.completedAt ?? now;
          final nextSpawnTime = completedAtTime.add(policy.interval);
          if (!now.isBefore(nextSpawnTime)) {
            dateToSpawn = CivilDay.fromDateTime(nextSpawnTime);
          }
        }
      }

      if (dateToSpawn != null) {
        final instId = generateId();
        final startRelative = RelativeTime(
          dayOffset: 0,
          time: policy.targetTime,
        );
        final dueRelative = _getCompletionRelativeDue(s, policy, dateToSpawn);
        final notifRelative = _getCompletionRelativeNotifications(
          s,
          policy,
          dateToSpawn,
        );

        toSpawn.add(
          TaskInstance(
            id: instId,
            scheduleId: task.id,
            ruleId: s.id,
            title: task.title,
            description: task.description,
            scheduledDate: dateToSpawn,
            startRelativeTime: startRelative,
            dueRelativeTime: dueRelative,
            notificationRelativeTimes: notifRelative,
            isFamily: task.isFamily,
            familyCompletionMode: task.familyCompletionMode,
            priority: task.priority,
            cycleId: task.cycleId,
            assignedUserId: task.assignedUserId,
            status: TaskStatus.pending,
          ),
        );
      }
    }
  }

  CivilDay? _evaluateFixedCalendarRule(
    SchedulerEvaluationContext context,
    TaskScheduleRule s, {
    required List<TaskInstance> toUpdate,
    required List<TaskInstance> toSpawn,
    required List<String> toDelete,
    CivilDay? maxSpawned,
  }) {
    final task = context.task;
    final taskInstances = context.taskInstances;
    final today = context.today;
    final futureInstancesCount = context.futureInstancesCount;

    final ruleInstances = taskInstances
        .where((inst) => _isInstanceForRule(inst, s, task))
        .toList();

    final Map<CivilDay, List<TaskInstance>> instancesByDate = {};
    for (final inst in ruleInstances) {
      instancesByDate.putIfAbsent(inst.scheduledDate, () => []).add(inst);
    }

    final Map<CivilDay, TaskInstance> workingInstances = {};
    for (final entry in instancesByDate.entries) {
      final date = entry.key;
      final insts = entry.value;
      if (insts.length > 1) {
        final canonical = _selectCanonicalInstance(insts);
        workingInstances[date] = canonical;
        for (final inst in insts) {
          if (inst.id != canonical.id && !toDelete.contains(inst.id)) {
            toDelete.add(inst.id);
          }
        }
      } else {
        workingInstances[date] = insts.first;
      }
    }

    final canonicalInstances = workingInstances.values.toList();
    final pending =
        canonicalInstances
            .where((inst) => inst.status == TaskStatus.pending)
            .toList()
          ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

    // 1. Determine the initial baseDate
    CivilDay initialBaseDate;
    if (pending.isNotEmpty) {
      initialBaseDate = pending.first.scheduledDate;
    } else {
      final resolved =
          canonicalInstances
              .where((inst) => inst.status != TaskStatus.pending)
              .toList()
            ..sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
      if (resolved.isNotEmpty) {
        final nextOcc = s.nextOccurrenceAfter(resolved.first.scheduledDate);
        if (nextOcc == null) {
          // The schedule rule is finished and has no future occurrences.
          return maxSpawned;
        }
        if (s.missedOccurrencePolicy.policy != MissedPolicy.stack &&
            nextOcc.isBefore(today)) {
          if (s.scheduledDate.compareTo(today) > 0) {
            initialBaseDate = s.scheduledDate;
          } else {
            initialBaseDate = s.occursOn(today)
                ? today
                : (s.nextOccurrenceAfter(today) ?? nextOcc);
          }
        } else {
          initialBaseDate = nextOcc;
        }
      } else {
        if (s.missedOccurrencePolicy.policy == MissedPolicy.preferNewer &&
            s.scheduledDate.isBefore(today)) {
          initialBaseDate = s.occursOn(today)
              ? today
              : (s.nextOccurrenceAfter(today) ?? s.scheduledDate);
        } else {
          initialBaseDate = s.occursOn(s.scheduledDate)
              ? s.scheduledDate
              : (s.nextOccurrenceAfter(s.scheduledDate) ?? s.scheduledDate);
        }
      }
    }

    final maxEvaluationDate = initialBaseDate.addDays(maxEvaluationDays);

    // Loop to maintain the queue of N future pending instances
    var currentBaseDate = initialBaseDate;
    final List<CivilDay> targetDates = [];
    while (true) {
      // If the currentBaseDate is past the 30-day cap, we must stop!
      if (currentBaseDate.compareTo(maxEvaluationDate) > 0) {
        break;
      }

      // Generate target pending dates (currentBaseDate up to today, plus N future occurrences after today)
      targetDates.clear();

      // 1. Generate occurrences from currentBaseDate up to today
      var current = currentBaseDate;
      while (current.compareTo(today) <= 0 &&
          current.compareTo(maxEvaluationDate) <= 0) {
        targetDates.add(current);
        final next = s.nextOccurrenceAfter(current);
        if (next != null) {
          current = next;
        } else {
          break;
        }
      }

      // 2. Generate N future occurrences after today
      var startFuture = today.isBefore(currentBaseDate)
          ? currentBaseDate
          : current;
      if (startFuture.compareTo(today) <= 0) {
        final next = s.nextOccurrenceAfter(startFuture);
        if (next != null) {
          startFuture = next;
        }
      }

      current = startFuture;
      int spawnedFutureCount = 0;
      final ruleFutureInstancesCount =
          futureInstancesCount ?? s.futureInstancesCount;
      while (spawnedFutureCount < ruleFutureInstancesCount) {
        if (current.compareTo(maxEvaluationDate) > 0) {
          break;
        }
        if (current.compareTo(today) > 0) {
          final existing = workingInstances[current];
          final isResolved =
              existing != null && existing.status != TaskStatus.pending;
          if (!isResolved) {
            targetDates.add(current);
            spawnedFutureCount++;
          }
        }
        final next = s.nextOccurrenceAfter(current);
        if (next != null) {
          current = next;
        } else {
          break;
        }
      }

      for (final date in targetDates) {
        if (!workingInstances.containsKey(date)) {
          final instId = generateId();
          RelativeTime startRelative = s.startRelativeTime;
          RelativeTime dueRelative = s.dueRelativeTime;
          WorkflowInstancePayload? workflowPayload;

          if (task.workflowType == 'mealWorkflow') {
            final cfg = task.mealWorkflowConfig ?? const MealWorkflowConfig();
            startRelative = cfg.selectTime;
            dueRelative = cfg.selectTime;
            workflowPayload = WorkflowInstancePayload(
              workflowType: 'mealWorkflow',
              stage: WorkflowStage.selectMeal,
              workflowGroupId:
                  '${task.id}-${date.year}-${date.month}-${date.day}',
            );
          }

          workingInstances[date] = TaskInstance(
            id: instId,
            scheduleId: task.id,
            ruleId: s.id,
            title: task.title,
            description: task.description,
            scheduledDate: date,
            startRelativeTime: startRelative,
            dueRelativeTime: dueRelative,
            notificationRelativeTimes: s.notificationRelativeTimes,
            isFamily: task.isFamily,
            familyCompletionMode: task.familyCompletionMode,
            priority: task.priority,
            cycleId: task.cycleId,
            assignedUserId: task.assignedUserId,
            workflowPayload: workflowPayload,
            status: TaskStatus.pending,
          );
        }
      }

      // Apply missed policies to the targetDates
      final hasNewSkipped = _applyMissedPolicy(
        workingInstances,
        canonicalInstances,
        targetDates,
        s,
        context,
      );

      // If we had any new skipped instances, the baseDate of the queue might have shifted forward.
      if (hasNewSkipped) {
        final pendingAfterMissed =
            workingInstances.values
                .where(
                  (inst) =>
                      inst.status == TaskStatus.pending &&
                      inst.scheduledDate.compareTo(maxEvaluationDate) <= 0,
                )
                .toList()
              ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

        if (pendingAfterMissed.isNotEmpty) {
          final nextBase = pendingAfterMissed.first.scheduledDate;
          if (nextBase != currentBaseDate) {
            currentBaseDate = nextBase;
            continue; // Loop again to fill the queue from the new base date
          }
        } else {
          final lastEvaluatedDate = targetDates.last;
          final nextOcc = s.nextOccurrenceAfter(lastEvaluatedDate);
          if (nextOcc != null && nextOcc.compareTo(maxEvaluationDate) <= 0) {
            currentBaseDate = nextOcc;
            continue;
          }
        }
      }

      break; // Queue is stable
    }

    // 4. Update, Spawn, or Delete based on the final workingInstances state
    for (final entry in workingInstances.entries) {
      final date = entry.key;
      final inst = entry.value;
      if (date.compareTo(today) <= 0) {
        if (maxSpawned == null || date.compareTo(maxSpawned) > 0) {
          maxSpawned = date;
        }
      }

      final orig = canonicalInstances.firstWhereOrNull((x) => x.id == inst.id);
      if (orig != null) {
        if (orig.status != inst.status) {
          toUpdate.add(inst);
        }
      } else {
        final isSkipOrOlderNewer =
            (s.missedOccurrencePolicy.policy == MissedPolicy.preferNewer ||
            s.missedOccurrencePolicy.policy == MissedPolicy.preferOlder);
        if (inst.status == TaskStatus.skipped && isSkipOrOlderNewer) {
          // Do not spawn!
        } else {
          toSpawn.add(inst);
        }
      }
    }

    // 5. Delete pending instances that are no longer in the target queue (pruning)
    _pruneStaleQueueEntries(
      pendingInstances: pending,
      targetDates: targetDates,
      today: today,
      toDelete: toDelete,
    );

    return maxSpawned;
  }

  bool _applyMissedPolicy(
    Map<CivilDay, TaskInstance> workingInstances,
    List<TaskInstance> canonicalInstances,
    List<CivilDay> targetDates,
    TaskScheduleRule rule,
    SchedulerEvaluationContext context,
  ) {
    final policy = rule.missedOccurrencePolicy.policy;
    switch (policy) {
      case MissedPolicy.stack:
        _applyStackPolicy(workingInstances, canonicalInstances, targetDates);
        return false;
      case MissedPolicy.autoDismiss:
        return _applyAutoDismissPolicy(
          workingInstances,
          canonicalInstances,
          targetDates,
          rule,
          context.now,
          context.userId,
          context.task,
        );
      case MissedPolicy.preferNewer:
        return _applyPreferNewerPolicy(
          workingInstances,
          canonicalInstances,
          targetDates,
          context.now,
          context.userId,
          context.task,
        );
      case MissedPolicy.preferOlder:
        return _applyPreferOlderPolicy(
          workingInstances,
          canonicalInstances,
          targetDates,
          context.now,
          context.userId,
          context.task,
        );
    }
  }

  void _applyStackPolicy(
    Map<CivilDay, TaskInstance> workingInstances,
    List<TaskInstance> canonicalInstances,
    List<CivilDay> targetDates,
  ) {
    for (final date in targetDates) {
      final inst = workingInstances[date]!;
      final isOriginalResolved = canonicalInstances.any(
        (x) => x.id == inst.id && x.status != TaskStatus.pending,
      );
      if (!isOriginalResolved) {
        workingInstances[date] = inst.copyWith(status: TaskStatus.pending);
      }
    }
  }

  bool _applyAutoDismissPolicy(
    Map<CivilDay, TaskInstance> workingInstances,
    List<TaskInstance> canonicalInstances,
    List<CivilDay> targetDates,
    TaskScheduleRule rule,
    DateTime now,
    String? userId,
    TaskSchedule task,
  ) {
    bool hasNewSkipped = false;
    for (final date in targetDates) {
      final inst = workingInstances[date]!;
      final isOriginalResolved = canonicalInstances.any(
        (x) => x.id == inst.id && x.status != TaskStatus.pending,
      );
      if (isOriginalResolved) continue;

      final isExpired = rule.missedOccurrencePolicy.isInstanceExpired(
        inst,
        now,
      );
      final nextStatus = isExpired ? TaskStatus.skipped : TaskStatus.pending;
      if (_updateInstanceStatus(
        workingInstances,
        date,
        nextStatus,
        statusReason: 'scheduler_auto_dismiss',
        userId: userId,
        logMessage:
            'autoDismiss: expired instance skipped for "${task.title}" ($date)',
      )) {
        hasNewSkipped = true;
      }
    }
    return hasNewSkipped;
  }

  bool _applyPreferNewerPolicy(
    Map<CivilDay, TaskInstance> workingInstances,
    List<TaskInstance> canonicalInstances,
    List<CivilDay> targetDates,
    DateTime now,
    String? userId,
    TaskSchedule task,
  ) {
    bool hasNewSkipped = false;
    final startedDates = targetDates.where((d) {
      final inst = workingInstances[d]!;
      final isOriginalResolved = canonicalInstances.any(
        (x) => x.id == inst.id && x.status != TaskStatus.pending,
      );
      if (isOriginalResolved) return false;
      final start = inst.startRelativeTime.referenceTo(d);
      return !now.isBefore(start);
    }).toList();

    final CivilDay? latestStartedDate = startedDates.isEmpty
        ? null
        : startedDates.reduce((a, b) => a.isAfter(b) ? a : b);

    for (final date in targetDates) {
      final inst = workingInstances[date]!;
      final isOriginalResolved = canonicalInstances.any(
        (x) => x.id == inst.id && x.status != TaskStatus.pending,
      );
      if (isOriginalResolved) continue;

      final TaskStatus nextStatus;
      if (latestStartedDate == null || date.compareTo(latestStartedDate) >= 0) {
        nextStatus = TaskStatus.pending;
      } else {
        nextStatus = TaskStatus.skipped;
      }
      if (_updateInstanceStatus(
        workingInstances,
        date,
        nextStatus,
        statusReason: 'scheduler_prefer_newer',
        userId: userId,
        logMessage:
            'preferNewer: older instance skipped for "${task.title}" ($date in favor of $latestStartedDate)',
      )) {
        hasNewSkipped = true;
      }
    }
    return hasNewSkipped;
  }

  bool _applyPreferOlderPolicy(
    Map<CivilDay, TaskInstance> workingInstances,
    List<TaskInstance> canonicalInstances,
    List<CivilDay> targetDates,
    DateTime now,
    String? userId,
    TaskSchedule task,
  ) {
    bool hasNewSkipped = false;
    final startedDates = targetDates.where((d) {
      final inst = workingInstances[d]!;
      final isOriginalResolved = canonicalInstances.any(
        (x) => x.id == inst.id && x.status != TaskStatus.pending,
      );
      if (isOriginalResolved) return false;
      final start = inst.startRelativeTime.referenceTo(d);
      return !now.isBefore(start);
    }).toList();

    final CivilDay? earliestStartedDate = startedDates.isEmpty
        ? null
        : startedDates.reduce((a, b) => a.isBefore(b) ? a : b);

    for (final date in targetDates) {
      final inst = workingInstances[date]!;
      final isOriginalResolved = canonicalInstances.any(
        (x) => x.id == inst.id && x.status != TaskStatus.pending,
      );
      if (isOriginalResolved) continue;

      final TaskStatus nextStatus;
      if (!now.isBefore(inst.startRelativeTime.referenceTo(date))) {
        nextStatus = date == earliestStartedDate
            ? TaskStatus.pending
            : TaskStatus.skipped;
      } else {
        nextStatus = TaskStatus.pending;
      }
      if (_updateInstanceStatus(
        workingInstances,
        date,
        nextStatus,
        statusReason: 'scheduler_prefer_older',
        userId: userId,
        logMessage:
            'preferOlder: subsequent instance skipped for "${task.title}" ($date, keeping $earliestStartedDate active)',
      )) {
        hasNewSkipped = true;
      }
    }
    return hasNewSkipped;
  }

  bool _updateInstanceStatus(
    Map<CivilDay, TaskInstance> workingInstances,
    CivilDay date,
    TaskStatus nextStatus, {
    String? statusReason,
    String? userId,
    String? logMessage,
  }) {
    final inst = workingInstances[date]!;
    if (inst.status != nextStatus) {
      workingInstances[date] = inst.copyWith(
        status: nextStatus,
        statusReason: nextStatus == TaskStatus.skipped ? statusReason : null,
        clearStatusReason: nextStatus != TaskStatus.skipped,
        lastModifiedByAppVersion: AppVersion.display,
        lastModifiedByUserId: userId,
      );
      if (nextStatus == TaskStatus.skipped) {
        if (logMessage != null) {
          logger?.debug('scheduler', logMessage);
        }
        return true;
      }
    }
    return false;
  }

  void _pruneStaleQueueEntries({
    required List<TaskInstance> pendingInstances,
    required List<CivilDay> targetDates,
    required CivilDay today,
    required List<String> toDelete,
  }) {
    final futureTargetDates = targetDates
        .where((d) => d.compareTo(today) > 0)
        .toSet();
    for (final inst in pendingInstances) {
      if (inst.scheduledDate.compareTo(today) > 0 &&
          !futureTargetDates.contains(inst.scheduledDate)) {
        if (!toDelete.contains(inst.id)) {
          toDelete.add(inst.id);
        }
      }
    }
  }

  ({List<TaskInstance> finalToSpawn, List<TaskInstance> finalToUpdate})
  _applyCapacityLimits(
    SchedulerEvaluationContext context, {
    required List<TaskInstance> toSpawn,
    List<TaskInstance> toUpdate = const [],
    List<String> toDelete = const [],
  }) {
    final task = context.task;
    final taskInstances = context.taskInstances;
    final now = context.now;
    final today = context.today;
    final userSettings = context.userSettings;
    final dayPlannedHours = context.dayPlannedHours;
    final applyCapacityLimits = context.applyCapacityLimits;

    final List<TaskInstance> finalToSpawn = [];
    final List<TaskInstance> finalToUpdate = List.from(toUpdate);
    final Map<String, int> updateIndexById = {
      for (var i = 0; i < finalToUpdate.length; i++) finalToUpdate[i].id: i,
    };
    final Set<String> toDeleteSet = toDelete.toSet();
    final Set<String> taskInstanceIds = {for (final x in taskInstances) x.id};

    if (task.skipIfNoCapacity && applyCapacityLimits) {
      final double taskDuration =
          (task.estimatedDuration ?? const Duration()).inMinutes /
          minutesPerHour;
      final Map<CivilDay, double> tempPlannedHours = dayPlannedHours != null
          ? Map.from(dayPlannedHours)
          : {};

      // 1. Process instances already in the DB that are pending or skipped (support skipping and revival)
      for (final inst in taskInstances) {
        final start = inst.startRelativeTime.referenceTo(inst.scheduledDate);
        final isFuture = now.isBefore(start);

        final isMarkedForDelete = toDeleteSet.contains(inst.id);
        final updateIdx = updateIndexById[inst.id];
        final isMarkedForUpdate = updateIdx != null;
        if (isMarkedForDelete) continue;

        final effectiveInst = isMarkedForUpdate
            ? finalToUpdate[updateIdx]
            : inst;
        final effectiveStatus = effectiveInst.status;

        if ((effectiveStatus == TaskStatus.pending ||
                effectiveStatus == TaskStatus.skipped) &&
            isFuture) {
          final capacity =
              userSettings?.getCapacityForDate(
                inst.scheduledDate.toDateTime(),
              ) ??
              defaultDailyCapacityHours;
          final planned = tempPlannedHours[inst.scheduledDate] ?? 0.0;

          if (capacity - planned < taskDuration) {
            if (effectiveStatus == TaskStatus.pending) {
              if (isMarkedForUpdate) {
                if (inst.status == TaskStatus.skipped) {
                  finalToUpdate.removeAt(updateIdx);
                  updateIndexById.remove(inst.id);
                  for (var i = updateIdx; i < finalToUpdate.length; i++) {
                    updateIndexById[finalToUpdate[i].id] = i;
                  }
                } else {
                  finalToUpdate[updateIdx] = finalToUpdate[updateIdx].copyWith(
                    status: TaskStatus.skipped,
                    statusReason: 'scheduler_capacity_limit',
                    lastModifiedByAppVersion: AppVersion.display,
                    lastModifiedByUserId: context.userId,
                  );
                }
              } else {
                final newUpdate = inst.copyWith(
                  status: TaskStatus.skipped,
                  statusReason: 'scheduler_capacity_limit',
                  lastModifiedByAppVersion: AppVersion.display,
                  lastModifiedByUserId: context.userId,
                );
                updateIndexById[newUpdate.id] = finalToUpdate.length;
                finalToUpdate.add(newUpdate);
              }
            }
          } else {
            if (effectiveStatus == TaskStatus.skipped) {
              if (!isMarkedForUpdate) {
                final newUpdate = inst.copyWith(
                  status: TaskStatus.pending,
                  clearStatusReason: true,
                  lastModifiedByAppVersion: AppVersion.display,
                  lastModifiedByUserId: context.userId,
                );
                updateIndexById[newUpdate.id] = finalToUpdate.length;
                finalToUpdate.add(newUpdate);
                tempPlannedHours[inst.scheduledDate] = planned + taskDuration;
              }
            } else if (effectiveStatus == TaskStatus.pending) {
              tempPlannedHours[inst.scheduledDate] = planned + taskDuration;
            }
          }
        }
      }

      // 2. Process toSpawn instances
      for (final inst in toSpawn) {
        if (inst.status == TaskStatus.pending &&
            inst.scheduledDate.compareTo(today) >= 0) {
          final capacity =
              userSettings?.getCapacityForDate(
                inst.scheduledDate.toDateTime(),
              ) ??
              defaultDailyCapacityHours;
          final planned = tempPlannedHours[inst.scheduledDate] ?? 0.0;

          if (capacity - planned < taskDuration) {
            finalToSpawn.add(
              inst.copyWith(
                status: TaskStatus.skipped,
                statusReason: 'scheduler_capacity_limit',
                lastModifiedByAppVersion: AppVersion.display,
                lastModifiedByUserId: context.userId,
              ),
            );
          } else {
            finalToSpawn.add(inst);
            tempPlannedHours[inst.scheduledDate] = planned + taskDuration;
          }
        } else {
          finalToSpawn.add(inst);
        }
      }

      // 3. Process toUpdate instances that were NOT in taskInstances (e.g. newly created/modified)
      for (int i = 0; i < finalToUpdate.length; i++) {
        final inst = finalToUpdate[i];
        final wasProcessed = taskInstanceIds.contains(inst.id);
        if (!wasProcessed &&
            inst.status == TaskStatus.pending &&
            inst.scheduledDate.compareTo(today) >= 0) {
          final capacity =
              userSettings?.getCapacityForDate(
                inst.scheduledDate.toDateTime(),
              ) ??
              defaultDailyCapacityHours;
          final planned = tempPlannedHours[inst.scheduledDate] ?? 0.0;

          if (capacity - planned < taskDuration) {
            finalToUpdate[i] = inst.copyWith(
              status: TaskStatus.skipped,
              statusReason: 'scheduler_capacity_limit',
              lastModifiedByAppVersion: AppVersion.display,
              lastModifiedByUserId: context.userId,
            );
          } else {
            tempPlannedHours[inst.scheduledDate] = planned + taskDuration;
          }
        }
      }
    } else {
      // If skipIfNoCapacity is false and applyCapacityLimits is true, revive any skipped instances back to pending
      if (!task.skipIfNoCapacity && applyCapacityLimits) {
        for (final inst in taskInstances) {
          final start = inst.startRelativeTime.referenceTo(inst.scheduledDate);
          final isFuture = now.isBefore(start);
          if (inst.status == TaskStatus.skipped && isFuture) {
            final isMarkedForDelete = toDeleteSet.contains(inst.id);
            if (isMarkedForDelete) continue;
            final updateIdx = updateIndexById[inst.id];
            if (updateIdx != null) {
              finalToUpdate[updateIdx] = finalToUpdate[updateIdx].copyWith(
                status: TaskStatus.pending,
              );
            } else {
              final newUpdate = inst.copyWith(status: TaskStatus.pending);
              updateIndexById[newUpdate.id] = finalToUpdate.length;
              finalToUpdate.add(newUpdate);
            }
          }
        }
      }
      finalToSpawn.addAll(toSpawn);
    }

    return (finalToSpawn: finalToSpawn, finalToUpdate: finalToUpdate);
  }

  List<DateTime> _calculateTriggerTimes(
    SchedulerEvaluationContext context, {
    required List<TaskInstance> toSpawn,
    List<TaskInstance> toUpdate = const [],
  }) {
    final task = context.task;
    final taskInstances = context.taskInstances;
    final now = context.now;

    final List<DateTime> triggerTimes = [];
    final updatedMap = {for (final inst in toUpdate) inst.id: inst};
    final effectiveExistingInstances = taskInstances
        .where((inst) => inst.scheduleId == task.id)
        .map((inst) => updatedMap[inst.id] ?? inst);

    final allCurrentInstances = [...effectiveExistingInstances, ...toSpawn];
    for (final inst in allCurrentInstances) {
      if (inst.status == TaskStatus.pending) {
        final start = inst.startRelativeTime.referenceTo(inst.scheduledDate);
        final due = inst.dueRelativeTime.referenceTo(inst.scheduledDate);
        if (start.isAfter(now)) triggerTimes.add(start);
        if (due.isAfter(now)) triggerTimes.add(due);

        final ruleIndex = _ruleIndexOfInstance(task, inst);
        if (ruleIndex >= 0 && ruleIndex < task.schedules.length) {
          final rule = task.schedules[ruleIndex];
          if (rule.missedOccurrencePolicy.policy == MissedPolicy.autoDismiss) {
            final exp = rule.missedOccurrencePolicy.calculateExpiration(due);
            if (exp != null && exp.isAfter(now)) {
              triggerTimes.add(exp);
            }
          }
        }
      }
    }
    triggerTimes.sort();
    return triggerTimes.toSet().toList();
  }

  SchedulerAction _evaluateOneOff(SchedulerEvaluationContext context) {
    final task = context.task;
    final taskInstances = context.taskInstances;

    // One-Off Schedule: Ensure an instance exists for each OneOffSchedule in the task.
    final List<TaskInstance> toSpawn = [];
    for (int i = 0; i < task.schedules.length; i++) {
      final s = task.schedules[i];
      if (s is OneOffSchedule) {
        final exists = taskInstances.any(
          (inst) =>
              _isInstanceForRule(inst, s, task) &&
              inst.scheduledDate == s.scheduledDate,
        );
        if (!exists) {
          toSpawn.add(
            TaskInstance(
              id: generateId(),
              scheduleId: task.id,
              ruleId: s.id,
              title: task.title,
              description: task.description,
              scheduledDate: s.scheduledDate,
              startRelativeTime: s.startRelativeTime,
              dueRelativeTime: s.dueRelativeTime,
              notificationRelativeTimes: s.notificationRelativeTimes,
              isFamily: task.isFamily,
              familyCompletionMode: task.familyCompletionMode,
              priority: task.priority,
              cycleId: task.cycleId,
              assignedUserId: task.assignedUserId,
              status: TaskStatus.pending,
            ),
          );
        }
      }
    }

    final capacityResult = _applyCapacityLimits(context, toSpawn: toSpawn);

    final triggerTimes = _calculateTriggerTimes(
      context,
      toSpawn: capacityResult.finalToSpawn,
      toUpdate: capacityResult.finalToUpdate,
    );

    return SchedulerAction(
      instancesToSpawn: capacityResult.finalToSpawn,
      instancesToUpdate: capacityResult.finalToUpdate,
      triggerTimes: triggerTimes,
    );
  }

  RelativeTime _shiftRelativeToStart(
    RelativeTime targetRel,
    TaskScheduleRule rule,
    CompletionRelativePolicy policy,
    CivilDay newScheduledDate,
  ) {
    final originalStartRef = rule.startRelativeTime.referenceTo(
      rule.scheduledDate,
    );
    final originalTargetRef = targetRel.referenceTo(rule.scheduledDate);
    final duration = originalTargetRef.difference(originalStartRef);

    final newStartRef = DateTime(
      newScheduledDate.year,
      newScheduledDate.month,
      newScheduledDate.day,
      policy.targetTime.hour,
      policy.targetTime.minute,
    );
    final newTargetRef = newStartRef.add(duration);
    final targetDay = CivilDay.fromDateTime(newTargetRef);
    return RelativeTime(
      dayOffset: targetDay
          .toDateTime()
          .difference(newScheduledDate.toDateTime())
          .inDays,
      time: TimeOfDay.fromDateTime(newTargetRef),
    );
  }

  RelativeTime _getCompletionRelativeDue(
    TaskScheduleRule rule,
    CompletionRelativePolicy policy,
    CivilDay newScheduledDate,
  ) {
    return _shiftRelativeToStart(
      rule.dueRelativeTime,
      rule,
      policy,
      newScheduledDate,
    );
  }

  List<RelativeTime> _getCompletionRelativeNotifications(
    TaskScheduleRule rule,
    CompletionRelativePolicy policy,
    CivilDay newScheduledDate,
  ) {
    return rule.notificationRelativeTimes
        .map(
          (notifRel) =>
              _shiftRelativeToStart(notifRel, rule, policy, newScheduledDate),
        )
        .toList();
  }

  TaskInstance? getNextOccurrenceToSpawn(
    TaskSchedule task,
    TaskInstance completedInstance,
    DateTime now,
    List<TaskInstance> taskInstances,
  ) {
    final ruleIndex = _ruleIndexOfInstance(task, completedInstance);
    if (ruleIndex < 0 || ruleIndex >= task.schedules.length) return null;
    final rule = task.schedules[ruleIndex];

    if (rule.schedulingPolicy is CompletionRelativePolicy) {
      final policy = rule.schedulingPolicy as CompletionRelativePolicy;
      final nextDate = CivilDay.fromDateTime(now.add(policy.interval));
      final nextInstId = generateId();

      final startRelative = RelativeTime(dayOffset: 0, time: policy.targetTime);
      final dueRelative = _getCompletionRelativeDue(rule, policy, nextDate);
      final notifRelative = _getCompletionRelativeNotifications(
        rule,
        policy,
        nextDate,
      );

      return TaskInstance(
        id: nextInstId,
        scheduleId: task.id,
        ruleId: rule.id,
        title: task.title,
        description: task.description,
        scheduledDate: nextDate,
        startRelativeTime: startRelative,
        dueRelativeTime: dueRelative,
        notificationRelativeTimes: notifRelative,
        isFamily: task.isFamily,
        familyCompletionMode: task.familyCompletionMode,
        priority: task.priority,
        cycleId: task.cycleId,
        assignedUserId: task.assignedUserId,
        status: TaskStatus.pending,
      );
    } else {
      // Find the latest uncompleted instance of this rule (excluding the completedInstance)
      final ruleInstances =
          taskInstances
              .where(
                (inst) =>
                    inst.ruleId == rule.id &&
                    inst.id != completedInstance.id &&
                    inst.status == TaskStatus.pending,
              )
              .toList()
            ..sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));

      final baseDate = ruleInstances.isNotEmpty
          ? ruleInstances.first.scheduledDate
          : completedInstance.scheduledDate;

      final nextDate = rule.nextOccurrenceAfter(baseDate);
      if (nextDate != null) {
        final nextInstId = generateId();
        return TaskInstance(
          id: nextInstId,
          scheduleId: task.id,
          ruleId: rule.id,
          title: task.title,
          description: task.description,
          scheduledDate: nextDate,
          startRelativeTime: rule.startRelativeTime,
          dueRelativeTime: rule.dueRelativeTime,
          notificationRelativeTimes: rule.notificationRelativeTimes,
          isFamily: task.isFamily,
          familyCompletionMode: task.familyCompletionMode,
          priority: task.priority,
          cycleId: task.cycleId,
          assignedUserId: task.assignedUserId,
          status: TaskStatus.pending,
        );
      }
    }
    return null;
  }

  String? getNextOccurrenceIdToDelete(
    TaskSchedule task,
    TaskInstance completedInstance,
    DateTime now,
    List<TaskInstance> taskInstances,
  ) {
    final ruleIndex = _ruleIndexOfInstance(task, completedInstance);
    if (ruleIndex < 0 || ruleIndex >= task.schedules.length) return null;
    final rule = task.schedules[ruleIndex];

    final ruleInstances =
        taskInstances
            .where(
              (inst) =>
                  inst.ruleId == rule.id && inst.status == TaskStatus.pending,
            )
            .toList()
          ..sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
    if (ruleInstances.isNotEmpty) {
      return ruleInstances.first.id;
    }
    return null;
  }

  bool _isInstanceForRule(
    TaskInstance inst,
    TaskScheduleRule s,
    TaskSchedule task,
  ) {
    if (inst.ruleId == s.id) return true;
    if (inst.ruleId.isEmpty && task.schedules.isNotEmpty) {
      final index = task.schedules.indexOf(s);
      return index == 0;
    }
    return false;
  }

  int _ruleIndexOfInstance(TaskSchedule task, TaskInstance instance) {
    if (task.schedules.length <= 1) return 0;
    for (int i = 0; i < task.schedules.length; i++) {
      if (task.schedules[i].id == instance.ruleId) {
        return i;
      }
    }
    // Fallback to legacy index suffix
    final parts = instance.id.split('_');
    if (parts.isNotEmpty) {
      final idxStr = parts.last;
      final idx = int.tryParse(idxStr);
      if (idx != null && idx >= 0 && idx < task.schedules.length) {
        return idx;
      }
    }
    return 0;
  }
}
