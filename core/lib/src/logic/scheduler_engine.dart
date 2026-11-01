import 'package:collection/collection.dart';

import '../models/app_logger.dart';
import '../models/civil_day.dart';
import '../models/task_schedule.dart';
import '../models/task_instance.dart';
import '../models/relative_time.dart';
import '../models/user_settings.dart';
import 'scheduler_capacity_filter.dart';
import 'scheduler_instance_deduplicator.dart';
import 'scheduler_instance_factory.dart';
import 'scheduler_missed_policy_evaluator.dart';
import 'scheduler_occurrence_projector.dart';

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
  final CivilDay latestToday;
  final UserSettings? userSettings;
  final Map<CivilDay, double>? dayPlannedHours;
  final bool applyCapacityLimits;
  final int? futureInstancesCount;
  final String? userId;
  final String? appVersion;
  final String? platform;
  final Duration? earliestUtcOffset;
  final Duration? latestUtcOffset;

  const SchedulerEvaluationContext({
    required this.task,
    required this.taskInstances,
    required this.now,
    required this.today,
    CivilDay? latestToday,
    this.userSettings,
    this.dayPlannedHours,
    this.applyCapacityLimits = true,
    this.futureInstancesCount,
    this.userId,
    this.appVersion,
    this.platform,
    this.earliestUtcOffset,
    this.latestUtcOffset,
  }) : latestToday = latestToday ?? today;

  DateTime referenceToEarliest(RelativeTime rel, CivilDay day) =>
      rel.referenceTo(day, utcOffset: earliestUtcOffset);

  DateTime referenceToLatest(RelativeTime rel, CivilDay day) =>
      rel.referenceTo(day, utcOffset: latestUtcOffset);

  DateTime toEarliestWallClock(DateTime instant) => earliestUtcOffset != null
      ? instant.toUtc().add(earliestUtcOffset!)
      : (now.isUtc ? instant.toUtc() : instant.toLocal());

  TaskInstance stampModified(
    TaskInstance inst, {
    TaskStatus? status,
    String? statusReason,
    bool clearStatusReason = false,
    bool? isFamily,
    FamilyCompletionMode? familyCompletionMode,
  }) {
    return inst.copyWith(
      status: status,
      statusReason: statusReason,
      clearStatusReason: clearStatusReason,
      isFamily: isFamily,
      familyCompletionMode: familyCompletionMode,
      lastModifiedByAppVersion: appVersion,
      lastModifiedByPlatform: platform,
      lastModifiedByUserId: userId,
      updatedAt: now.toUtc(),
    );
  }
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
  final String? appVersion;
  final String? platform;

  const SchedulerEngine({
    String Function()? generateId,
    this.logger,
    this.appVersion = 'unknown',
    this.platform = 'unknown',
  }) : generateId = generateId ?? TaskInstance.generateId;

  SchedulerMissedPolicyEvaluator get _missedPolicyEvaluator =>
      SchedulerMissedPolicyEvaluator(
        logger: logger,
        appVersion: appVersion,
        platform: platform,
      );

  SchedulerCapacityFilter get _capacityFilter =>
      SchedulerCapacityFilter(appVersion: appVersion, platform: platform);

  SchedulerInstanceFactory get _instanceFactory => SchedulerInstanceFactory(
        generateId: generateId,
        appVersion: appVersion,
        platform: platform,
      );

  static const SchedulerOccurrenceProjector _occurrenceProjector =
      SchedulerOccurrenceProjector();

  SchedulerAction evaluate(
    TaskSchedule task,
    List<TaskInstance> taskInstances,
    DateTime now, {
    int? futureInstancesCount,
    UserSettings? userSettings,
    Map<CivilDay, double>? dayPlannedHours,
    bool applyCapacityLimits = true,
    String? userId,
    Duration? utcOffset,
    Duration? earliestUtcOffset,
    Duration? latestUtcOffset,
  }) {
    final rawEarliest = earliestUtcOffset ?? utcOffset ?? latestUtcOffset;
    final rawLatest = latestUtcOffset ?? utcOffset ?? earliestUtcOffset;
    final resolvedEarliestOffset = (rawEarliest != null && rawLatest != null)
        ? (rawEarliest >= rawLatest ? rawEarliest : rawLatest)
        : (rawEarliest ?? rawLatest);
    final resolvedLatestOffset = (rawEarliest != null && rawLatest != null)
        ? (rawEarliest <= rawLatest ? rawEarliest : rawLatest)
        : (rawLatest ?? rawEarliest);

    final today = resolvedEarliestOffset != null
        ? CivilDay.fromDateTime(now.toUtc().add(resolvedEarliestOffset))
        : CivilDay.fromDateTime(now);
    final latestToday = resolvedLatestOffset != null
        ? CivilDay.fromDateTime(now.toUtc().add(resolvedLatestOffset))
        : today;

    final context = SchedulerEvaluationContext(
      task: task,
      taskInstances: taskInstances,
      now: now,
      today: today,
      latestToday: latestToday,
      userSettings: userSettings,
      dayPlannedHours: dayPlannedHours,
      applyCapacityLimits: applyCapacityLimits,
      futureInstancesCount: futureInstancesCount,
      userId: userId,
      appVersion: appVersion,
      platform: platform,
      earliestUtcOffset: resolvedEarliestOffset,
      latestUtcOffset: resolvedLatestOffset,
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
      updatedSchedule = task.copyWith(
        lastSpawnedDate: maxSpawned,
        updatedAt: now.toUtc(),
      );
    }

    final capacityResult = _capacityFilter.applyCapacityLimits(
      context,
      toSpawn: toSpawn,
      toUpdate: toUpdate,
      toDelete: toDelete,
    );
    final finalToSpawn = capacityResult.finalToSpawn;
    final finalToUpdate = _reconcileScopeMismatches(
      context,
      toUpdate: capacityResult.finalToUpdate,
      toDelete: toDelete,
    );

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

  TaskInstance _reconcileInstanceFamilyScope(
    TaskInstance inst,
    TaskSchedule task,
    SchedulerEvaluationContext context,
  ) {
    if (inst.isFamily == task.isFamily &&
        inst.familyCompletionMode == task.familyCompletionMode) {
      return inst;
    }
    return context.stampModified(
      inst,
      isFamily: task.isFamily,
      familyCompletionMode: task.familyCompletionMode,
    );
  }

  List<TaskInstance> _reconcileScopeMismatches(
    SchedulerEvaluationContext context, {
    required List<TaskInstance> toUpdate,
    List<String> toDelete = const [],
  }) {
    final task = context.task;
    final toDeleteSet = toDelete.toSet();
    final reconciled = <TaskInstance>[
      for (final inst in toUpdate)
        if (!toDeleteSet.contains(inst.id))
          _reconcileInstanceFamilyScope(inst, task, context),
    ];
    final updatedIds = {for (final inst in reconciled) inst.id};

    for (final inst in context.taskInstances) {
      final belongsToTask = inst.scheduleId == task.id ||
          task.schedules.any((s) => _isInstanceForRule(inst, s, task));
      if (!belongsToTask) continue;
      if (toDeleteSet.contains(inst.id) || updatedIds.contains(inst.id)) {
        continue;
      }
      if (inst.isFamily != task.isFamily ||
          inst.familyCompletionMode != task.familyCompletionMode) {
        reconciled.add(_reconcileInstanceFamilyScope(inst, task, context));
        updatedIds.add(inst.id);
      }
    }
    return reconciled;
  }

  ({
    List<TaskInstance> toUpdate,
    List<TaskInstance> toSpawn,
    List<String> toDelete,
    CivilDay? maxSpawned,
  }) _evaluateRecurringRules(SchedulerEvaluationContext context) {
    final task = context.task;
    final List<TaskInstance> toUpdate = [];
    final List<TaskInstance> toSpawn = [];
    final List<String> toDelete = [];
    CivilDay? maxSpawned;

    for (int i = 0; i < task.schedules.length; i++) {
      final s = task.schedules[i];

      if (s.schedulingPolicy is CompletionRelativePolicy) {
        maxSpawned = _evaluateCompletionRelativeRule(
          context,
          s,
          toUpdate: toUpdate,
          toSpawn: toSpawn,
          toDelete: toDelete,
          maxSpawned: maxSpawned,
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

  CivilDay? _evaluateCompletionRelativeRule(
    SchedulerEvaluationContext context,
    TaskScheduleRule s, {
    required List<TaskInstance> toUpdate,
    required List<TaskInstance> toSpawn,
    required List<String> toDelete,
    CivilDay? maxSpawned,
  }) {
    final task = context.task;
    final taskInstances = context.taskInstances;
    final now = context.now;
    final today = context.today;
    final ruleInstances = taskInstances
        .where((inst) => _isInstanceForRule(inst, s, task))
        .toList();

    final canonicalByDate =
        SchedulerInstanceDeduplicator.deduplicateRuleInstancesByDate(
      ruleInstances,
      toDelete,
    );
    final canonicalInstances = canonicalByDate.values.toList();
    final deduplicatedRuleInstances =
        ruleInstances.where((inst) => !toDelete.contains(inst.id)).toList();

    final pendingForSchedule = deduplicatedRuleInstances
        .where((inst) => inst.status == TaskStatus.pending)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    if (pendingForSchedule.length > 1) {
      final primaryPending = pendingForSchedule.first;
      for (int p = 1; p < pendingForSchedule.length; p++) {
        final candidate = pendingForSchedule[p];
        final isSiblingWorkflowStage =
            candidate.scheduledDate == primaryPending.scheduledDate &&
                candidate.workflowPayload?.stage !=
                    primaryPending.workflowPayload?.stage;
        if (!isSiblingWorkflowStage && !toDelete.contains(candidate.id)) {
          toDelete.add(candidate.id);
        }
      }
      pendingForSchedule.removeWhere((inst) => toDelete.contains(inst.id));
    }

    if (pendingForSchedule.isNotEmpty &&
        s.missedOccurrencePolicy.policy == MissedPolicy.autoDismiss) {
      final expiredPending = <TaskInstance>[];
      for (final activePending in pendingForSchedule) {
        final isExpired = s.missedOccurrencePolicy.isInstanceExpired(
          activePending,
          now,
          utcOffset: context.latestUtcOffset,
        );
        if (isExpired) {
          expiredPending.add(activePending);
        }
      }
      for (final activePending in expiredPending) {
        final skippedInst = context.stampModified(
          activePending,
          status: TaskStatus.skipped,
          statusReason: InstanceStatusReason.schedulerAutoDismiss.value,
        );
        toUpdate.add(skippedInst);
        canonicalByDate[skippedInst.scheduledDate] = skippedInst;
        final idx = canonicalInstances.indexWhere(
          (x) => x.id == skippedInst.id,
        );
        if (idx >= 0) {
          canonicalInstances[idx] = skippedInst;
        }
        final dedupIdx = deduplicatedRuleInstances.indexWhere(
          (x) => x.id == skippedInst.id,
        );
        if (dedupIdx >= 0) {
          deduplicatedRuleInstances[dedupIdx] = skippedInst;
        }
        pendingForSchedule.removeWhere((x) => x.id == skippedInst.id);
      }
    }

    final hasCurrentOrFutureCapacitySkipped = canonicalInstances.any(
      (inst) =>
          inst.status == TaskStatus.skipped &&
          inst.statusReason ==
              InstanceStatusReason.schedulerCapacityLimit.value &&
          !inst.scheduledDate.isBefore(context.latestToday),
    );

    if (pendingForSchedule.isEmpty && !hasCurrentOrFutureCapacitySkipped) {
      CivilDay? dateToSpawn;
      final anchor =
          SchedulerOccurrenceProjector.computeNextCompletionRelativeDateTime(
        task,
        s,
        deduplicatedRuleInstances,
        toWallClock: context.toEarliestWallClock,
      );

      if (anchor.resolvedDay != null &&
          anchor.resolvedDay!.compareTo(today) <= 0) {
        if (maxSpawned == null ||
            anchor.resolvedDay!.compareTo(maxSpawned) > 0) {
          maxSpawned = anchor.resolvedDay;
        }
      }

      if (anchor.nextSpawnTime != null) {
        final currentWallClock = context.toEarliestWallClock(now);
        if (!currentWallClock.isBefore(anchor.nextSpawnTime!)) {
          dateToSpawn = CivilDay.fromDateTime(anchor.nextSpawnTime!);
        }
      } else {
        dateToSpawn = s.scheduledDate;
      }

      if (dateToSpawn != null && canonicalByDate.containsKey(dateToSpawn)) {
        if (dateToSpawn.isBefore(context.today) &&
            !canonicalByDate.containsKey(context.today)) {
          dateToSpawn = context.today;
        } else {
          var candidate = dateToSpawn.isBefore(context.today)
              ? context.today.addDays(1)
              : dateToSpawn.addDays(1);
          while (canonicalByDate.containsKey(candidate)) {
            candidate = candidate.addDays(1);
          }
          final policy = s.schedulingPolicy as CompletionRelativePolicy;
          final candidateTrigger = DateTime.utc(
            candidate.year,
            candidate.month,
            candidate.day,
            policy.targetHour,
            policy.targetMinute,
          );
          final currentWallClock = context.toEarliestWallClock(now);
          dateToSpawn =
              !currentWallClock.isBefore(candidateTrigger) ? candidate : null;
        }
      }

      if (dateToSpawn != null) {
        toSpawn.add(
          _instanceFactory.createInstanceForRule(
            task: task,
            rule: s,
            scheduledDate: dateToSpawn,
            now: now,
            userId: context.userId,
          ),
        );
      }
    }
    return maxSpawned;
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
    final latestToday = context.latestToday;
    final futureInstancesCount = context.futureInstancesCount;

    final ruleInstances = taskInstances
        .where((inst) => _isInstanceForRule(inst, s, task))
        .toList();

    final Map<CivilDay, TaskInstance> workingInstances =
        SchedulerInstanceDeduplicator.deduplicateRuleInstancesByDate(
      ruleInstances,
      toDelete,
    );

    final canonicalInstances = workingInstances.values.toList();
    final pending = canonicalInstances
        .where((inst) => inst.status == TaskStatus.pending)
        .toList()
      ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

    // 1. Determine the initial baseDate
    CivilDay initialBaseDate;
    if (pending.isNotEmpty) {
      initialBaseDate = pending.first.scheduledDate;
    } else {
      final resolved = canonicalInstances
          .where(
            (inst) =>
                inst.status != TaskStatus.pending &&
                inst.statusReason !=
                    InstanceStatusReason.schedulerCapacityLimit.value,
          )
          .toList()
        ..sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
      final CivilDay? lastResolvedOrSpawnedDate = resolved.isNotEmpty
          ? resolved.first.scheduledDate
          : (task.lastSpawnedDate != null &&
                  task.lastSpawnedDate!.compareTo(s.scheduledDate) >= 0
              ? task.lastSpawnedDate
              : null);
      if (lastResolvedOrSpawnedDate != null) {
        final nextOcc = s.nextOccurrenceAfter(lastResolvedOrSpawnedDate);
        if (nextOcc == null) {
          return maxSpawned;
        }
        if (s.missedOccurrencePolicy.policy != MissedPolicy.stack &&
            s.missedOccurrencePolicy.policy != MissedPolicy.preferOlder &&
            nextOcc.isBefore(latestToday)) {
          if (s.scheduledDate.compareTo(latestToday) > 0) {
            initialBaseDate = s.scheduledDate;
          } else {
            initialBaseDate = s.occursOn(latestToday)
                ? latestToday
                : (s.nextOccurrenceAfter(latestToday) ?? nextOcc);
          }
        } else {
          initialBaseDate = nextOcc;
        }
      } else {
        final firstOcc = s.occursOn(s.scheduledDate)
            ? s.scheduledDate
            : s.nextOccurrenceAfter(s.scheduledDate);
        if (firstOcc == null) {
          return maxSpawned;
        }
        if (s.missedOccurrencePolicy.policy == MissedPolicy.preferNewer &&
            firstOcc.isBefore(latestToday)) {
          final fromToday = s.occursOn(latestToday)
              ? latestToday
              : s.nextOccurrenceAfter(latestToday);
          if (fromToday == null) {
            return maxSpawned;
          }
          initialBaseDate = fromToday;
        } else {
          initialBaseDate = firstOcc;
        }
      }
    }

    var currentBaseDate = initialBaseDate;
    final List<CivilDay> targetDates = [];
    final ruleFutureInstancesCount =
        futureInstancesCount ?? s.futureInstancesCount;
    int safetyIterations = 0;
    while (safetyIterations < maxEvaluationDays) {
      safetyIterations++;

      targetDates.clear();

      // 1. Past catch-up: generate occurrences from currentBaseDate up to today
      var current = currentBaseDate;
      int pastOccurrencesCount = 0;
      bool hitPastCap = false;
      while (current.compareTo(today) <= 0) {
        final isNewOccurrence = !workingInstances.containsKey(current);
        if (isNewOccurrence && pastOccurrencesCount > maxEvaluationDays) {
          hitPastCap = true;
          break;
        }
        targetDates.add(current);
        if (isNewOccurrence) {
          pastOccurrencesCount++;
        }
        final next = s.nextOccurrenceAfter(current);
        if (next != null) {
          current = next;
        } else {
          break;
        }
      }

      // 2. Future lookahead: generate N future occurrences after today
      if (!hitPastCap) {
        var startFuture =
            today.isBefore(currentBaseDate) ? currentBaseDate : current;
        if (startFuture.compareTo(today) <= 0) {
          final next = s.nextOccurrenceAfter(startFuture);
          if (next != null) {
            startFuture = next;
          }
        }

        current = startFuture;
        int spawnedFutureCount = 0;
        while (spawnedFutureCount < ruleFutureInstancesCount &&
            current.compareTo(today) > 0) {
          final existing = workingInstances[current];
          final isResolved = existing != null &&
              existing.status != TaskStatus.pending &&
              existing.statusReason !=
                  InstanceStatusReason.schedulerCapacityLimit.value;
          if (!isResolved) {
            targetDates.add(current);
            spawnedFutureCount++;
          }
          final next = s.nextOccurrenceAfter(current);
          if (next != null) {
            current = next;
          } else {
            break;
          }
        }
      }

      for (final date in targetDates) {
        if (!workingInstances.containsKey(date)) {
          workingInstances[date] = _instanceFactory.createInstanceForRule(
            task: task,
            rule: s,
            scheduledDate: date,
            now: context.now,
            userId: context.userId,
          );
        }
      }

      final hasNewSkipped = _missedPolicyEvaluator.applyMissedPolicy(
        workingInstances,
        canonicalInstances,
        targetDates,
        s,
        context,
      );

      if (hasNewSkipped) {
        final pendingAfterMissed = workingInstances.values
            .where((inst) => inst.status == TaskStatus.pending)
            .toList()
          ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

        if (pendingAfterMissed.isNotEmpty) {
          final nextBase = pendingAfterMissed.first.scheduledDate;
          if (nextBase != currentBaseDate) {
            currentBaseDate = nextBase;
            continue;
          }
        } else if (targetDates.isNotEmpty) {
          final lastEvaluatedDate = targetDates.last;
          final nextOcc = s.nextOccurrenceAfter(lastEvaluatedDate);
          if (nextOcc != null &&
              (nextOcc.compareTo(today) <= 0 || ruleFutureInstancesCount > 0)) {
            currentBaseDate = nextOcc;
            continue;
          }
        }
      }

      break;
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
          if (inst.status == TaskStatus.skipped) {
            final pendingSiblings = ruleInstances.where(
              (x) =>
                  x.id != inst.id &&
                  !toDelete.contains(x.id) &&
                  x.scheduledDate == date &&
                  x.status == TaskStatus.pending,
            );
            for (final sibling in pendingSiblings) {
              final shouldSkipSibling =
                  s.missedOccurrencePolicy.policy != MissedPolicy.autoDismiss ||
                      s.missedOccurrencePolicy.isInstanceExpired(
                        sibling,
                        context.now,
                        utcOffset: context.latestUtcOffset,
                      );
              if (shouldSkipSibling) {
                toUpdate.add(
                  context.stampModified(
                    sibling,
                    status: TaskStatus.skipped,
                    statusReason: inst.statusReason,
                  ),
                );
              }
            }
          }
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
      today: latestToday,
      toDelete: toDelete,
    );

    return maxSpawned;
  }

  void _pruneStaleQueueEntries({
    required List<TaskInstance> pendingInstances,
    required List<CivilDay> targetDates,
    required CivilDay today,
    required List<String> toDelete,
  }) {
    final futureTargetDates =
        targetDates.where((d) => d.compareTo(today) > 0).toSet();
    for (final inst in pendingInstances) {
      if (inst.scheduledDate.compareTo(today) > 0 &&
          !futureTargetDates.contains(inst.scheduledDate)) {
        if (!toDelete.contains(inst.id)) {
          toDelete.add(inst.id);
        }
      }
    }
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
        final start = context.referenceToEarliest(
          inst.startRelativeTime,
          inst.scheduledDate,
        );
        final due = context.referenceToLatest(
          inst.dueRelativeTime,
          inst.scheduledDate,
        );
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

    final List<TaskInstance> toSpawn = [];
    CivilDay? maxSpawned;
    for (int i = 0; i < task.schedules.length; i++) {
      final s = task.schedules[i];
      if (s is OneOffSchedule) {
        final existingForRule = taskInstances
            .where(
              (inst) =>
                  _isInstanceForRule(inst, s, task) &&
                  inst.scheduledDate == s.scheduledDate,
            )
            .toList();
        final exists = existingForRule.isNotEmpty;
        final hasResolved = existingForRule.any(
          (inst) => inst.status != TaskStatus.pending,
        );
        final otherRuleAccountsForLastSpawned = task.lastSpawnedDate != null &&
            task.schedules.any(
              (other) =>
                  other.id != s.id &&
                  taskInstances.any(
                    (inst) =>
                        _isInstanceForRule(inst, other, task) &&
                        inst.scheduledDate.compareTo(task.lastSpawnedDate!) ==
                            0,
                  ),
            );
        final alreadySpawned = task.lastSpawnedDate != null &&
            !otherRuleAccountsForLastSpawned &&
            s.scheduledDate.compareTo(task.lastSpawnedDate!) <= 0;
        if (!exists && !alreadySpawned) {
          toSpawn.add(
            _instanceFactory.createInstanceForRule(
              task: task,
              rule: s,
              scheduledDate: s.scheduledDate,
              now: context.now,
              userId: context.userId,
            ),
          );
          if (s.scheduledDate.compareTo(context.today) <= 0) {
            if (maxSpawned == null ||
                s.scheduledDate.compareTo(maxSpawned) > 0) {
              maxSpawned = s.scheduledDate;
            }
          }
        } else if (hasResolved &&
            s.scheduledDate.compareTo(context.today) <= 0) {
          if (maxSpawned == null || s.scheduledDate.compareTo(maxSpawned) > 0) {
            maxSpawned = s.scheduledDate;
          }
        }
      }
    }

    TaskSchedule? updatedSchedule;
    if (maxSpawned != null &&
        (task.lastSpawnedDate == null ||
            maxSpawned.compareTo(task.lastSpawnedDate!) > 0)) {
      updatedSchedule = task.copyWith(
        lastSpawnedDate: maxSpawned,
        updatedAt: context.now.toUtc(),
      );
    }

    final capacityResult = _capacityFilter.applyCapacityLimits(
      context,
      toSpawn: toSpawn,
    );
    final finalToUpdate = _reconcileScopeMismatches(
      context,
      toUpdate: capacityResult.finalToUpdate,
    );

    final triggerTimes = _calculateTriggerTimes(
      context,
      toSpawn: capacityResult.finalToSpawn,
      toUpdate: finalToUpdate,
    );

    return SchedulerAction(
      instancesToSpawn: capacityResult.finalToSpawn,
      instancesToUpdate: finalToUpdate,
      updatedSchedule: updatedSchedule,
      triggerTimes: triggerTimes,
    );
  }

  static RelativeTime shiftRelativeToStart(
    RelativeTime targetRel,
    TaskScheduleRule rule,
    CompletionRelativePolicy policy,
    CivilDay newScheduledDate,
  ) =>
      SchedulerInstanceFactory.shiftRelativeToStart(
        targetRel,
        rule,
        policy,
        newScheduledDate,
      );

  TaskInstance? getNextOccurrenceToSpawn(
    TaskSchedule task,
    TaskInstance completedInstance,
    DateTime now,
    List<TaskInstance> taskInstances, {
    Duration? utcOffset,
    String? userId,
  }) =>
      _occurrenceProjector.getNextOccurrenceToSpawn(
        task,
        completedInstance,
        now,
        taskInstances,
        createInstanceForRule: _instanceFactory.createInstanceForRule,
        utcOffset: utcOffset,
        userId: userId,
      );

  String? getNextOccurrenceIdToDelete(
    TaskSchedule task,
    TaskInstance completedInstance,
    DateTime now,
    List<TaskInstance> taskInstances,
  ) =>
      _occurrenceProjector.getNextOccurrenceIdToDelete(
        task,
        completedInstance,
        now,
        taskInstances,
      );

  /// Projects up to [count] upcoming [CivilDay] occurrences for [rule] on or
  /// after [fromDate], accounting for [existingInstances] when [rule] uses
  /// [CompletionRelativePolicy].
  List<CivilDay> projectUpcomingOccurrences(
    TaskSchedule task,
    TaskScheduleRule rule,
    CivilDay fromDate, {
    int count = 5,
    List<TaskInstance> existingInstances = const [],
    Duration? utcOffset,
  }) =>
      _occurrenceProjector.projectUpcomingOccurrences(
        task,
        rule,
        fromDate,
        count: count,
        existingInstances: existingInstances,
        utcOffset: utcOffset,
      );

  bool _isInstanceForRule(
    TaskInstance inst,
    TaskScheduleRule s,
    TaskSchedule task,
  ) =>
      SchedulerOccurrenceProjector.isInstanceForRule(inst, s, task);

  int _ruleIndexOfInstance(TaskSchedule task, TaskInstance instance) =>
      SchedulerOccurrenceProjector.ruleIndexOfInstance(task, instance);
}
