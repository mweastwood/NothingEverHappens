import 'package:collection/collection.dart';

import '../models/app_logger.dart';
import '../models/civil_day.dart';
import '../models/task_schedule.dart';
import '../models/task_instance.dart';
import '../models/relative_time.dart';
import '../models/user_settings.dart';
import 'scheduler_capacity_filter.dart';
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

  SchedulerCapacityFilter get _capacityFilter => SchedulerCapacityFilter(
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
    TaskSchedule task, {
    required DateTime now,
    String? userId,
  }) {
    if (inst.isFamily == task.isFamily &&
        inst.familyCompletionMode == task.familyCompletionMode) {
      return inst;
    }
    return inst.copyWith(
      isFamily: task.isFamily,
      familyCompletionMode: task.familyCompletionMode,
      lastModifiedByAppVersion: appVersion,
      lastModifiedByPlatform: platform,
      lastModifiedByUserId: userId,
      updatedAt: now.toUtc(),
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
          _reconcileInstanceFamilyScope(
            inst,
            task,
            now: context.now,
            userId: context.userId,
          ),
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
        reconciled.add(
          _reconcileInstanceFamilyScope(
            inst,
            task,
            now: context.now,
            userId: context.userId,
          ),
        );
        updatedIds.add(inst.id);
      }
    }
    return reconciled;
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

  Map<CivilDay, TaskInstance> _deduplicateRuleInstancesByDate(
    List<TaskInstance> ruleInstances,
    List<String> toDelete,
  ) {
    final Map<CivilDay, List<TaskInstance>> instancesByDate = {};
    for (final inst in ruleInstances) {
      instancesByDate.putIfAbsent(inst.scheduledDate, () => []).add(inst);
    }

    final Map<CivilDay, TaskInstance> canonicalByDate = {};
    for (final entry in instancesByDate.entries) {
      final insts = entry.value;
      if (insts.length > 1) {
        final canonical = _selectCanonicalInstance(insts);
        canonicalByDate[entry.key] = canonical;
        for (final inst in insts) {
          if (inst.id != canonical.id && !toDelete.contains(inst.id)) {
            toDelete.add(inst.id);
          }
        }
      } else {
        canonicalByDate[entry.key] = insts.first;
      }
    }
    return canonicalByDate;
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
    final ruleInstances = taskInstances
        .where((inst) => _isInstanceForRule(inst, s, task))
        .toList();

    final canonicalInstances =
        _deduplicateRuleInstancesByDate(ruleInstances, toDelete)
            .values
            .toList();

    final pendingForSchedule = canonicalInstances
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
        final resolved = canonicalInstances
            .where((inst) => inst.status != TaskStatus.pending)
            .toList()
          ..sort(
            (a, b) => (b.completedAt ?? b.updatedAt).compareTo(
              a.completedAt ?? a.updatedAt,
            ),
          );
        if (resolved.isNotEmpty) {
          final latest = resolved.first;
          final completedAtTime = latest.completedAt ?? latest.updatedAt;
          final referenceTime = context.toEarliestWallClock(completedAtTime);
          final currentWallClock = context.toEarliestWallClock(now);
          final nextSpawnTime = s.nextCompletionRelativeDateTime(referenceTime);
          if (!currentWallClock.isBefore(nextSpawnTime)) {
            dateToSpawn = CivilDay.fromDateTime(nextSpawnTime);
          }
        }
      }

      if (dateToSpawn != null) {
        toSpawn.add(
          _createInstanceForRule(
            task: task,
            rule: s,
            scheduledDate: dateToSpawn,
            now: now,
            userId: context.userId,
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
    final latestToday = context.latestToday;
    final futureInstancesCount = context.futureInstancesCount;

    final ruleInstances = taskInstances
        .where((inst) => _isInstanceForRule(inst, s, task))
        .toList();

    final Map<CivilDay, TaskInstance> workingInstances =
        _deduplicateRuleInstancesByDate(ruleInstances, toDelete);

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
          .where((inst) => inst.status != TaskStatus.pending)
          .toList()
        ..sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
      if (resolved.isNotEmpty) {
        final nextOcc = s.nextOccurrenceAfter(resolved.first.scheduledDate);
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
        if (pastOccurrencesCount > maxEvaluationDays) {
          hitPastCap = true;
          break;
        }
        targetDates.add(current);
        pastOccurrencesCount++;
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
          final isResolved =
              existing != null && existing.status != TaskStatus.pending;
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
          workingInstances[date] = _createInstanceForRule(
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

      if (hasNewSkipped && !hitPastCap) {
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
            _createInstanceForRule(
              task: task,
              rule: s,
              scheduledDate: s.scheduledDate,
              now: context.now,
              userId: context.userId,
            ),
          );
        }
      }
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
      triggerTimes: triggerTimes,
    );
  }

  TaskInstance _createInstanceForRule({
    required TaskSchedule task,
    required TaskScheduleRule rule,
    required CivilDay scheduledDate,
    DateTime? now,
    String? userId,
  }) {
    final instId = generateId();
    RelativeTime startRelative = rule.startRelativeTime;
    RelativeTime dueRelative = rule.dueRelativeTime;
    List<RelativeTime> notifRelative = rule.notificationRelativeTimes;
    WorkflowInstancePayload? workflowPayload;

    if (rule.schedulingPolicy is CompletionRelativePolicy) {
      final policy = rule.schedulingPolicy as CompletionRelativePolicy;
      startRelative = RelativeTime(
        dayOffset: 0,
        hour: policy.targetHour,
        minute: policy.targetMinute,
      );
      dueRelative = _getCompletionRelativeDue(rule, policy, scheduledDate);
      notifRelative = _getCompletionRelativeNotifications(
        rule,
        policy,
        scheduledDate,
      );
    }

    if (task.workflowType == 'mealWorkflow') {
      final cfg = task.mealWorkflowConfig ?? const MealWorkflowConfig();
      startRelative = cfg.selectTime;
      dueRelative = cfg.selectTime;
      workflowPayload = WorkflowInstancePayload(
        workflowType: 'mealWorkflow',
        stage: WorkflowStage.selectMeal,
        workflowGroupId:
            '${task.id}-${scheduledDate.year}-${scheduledDate.month}-${scheduledDate.day}',
      );
    }

    return TaskInstance(
      id: instId,
      scheduleId: task.id,
      ruleId: rule.id,
      title: task.title,
      description: task.description,
      scheduledDate: scheduledDate,
      startRelativeTime: startRelative,
      dueRelativeTime: dueRelative,
      notificationRelativeTimes: notifRelative,
      isFamily: task.isFamily,
      familyCompletionMode: task.familyCompletionMode,
      priority: task.priority,
      cycleId: task.cycleId,
      assignedUserId: task.assignedUserId,
      workflowPayload: workflowPayload,
      status: TaskStatus.pending,
      labelIds: task.labelIds,
      lastModifiedByUserId: userId,
      lastModifiedByAppVersion: appVersion,
      lastModifiedByPlatform: platform,
      updatedAt: (now ?? DateTime.now()).toUtc(),
    );
  }

  static RelativeTime shiftRelativeToStart(
    RelativeTime targetRel,
    TaskScheduleRule rule,
    CompletionRelativePolicy policy,
    CivilDay newScheduledDate,
  ) {
    final originalStartRef = rule.startRelativeTime.referenceTo(
      rule.scheduledDate,
      utcOffset: Duration.zero,
    );
    final originalTargetRef = targetRel.referenceTo(
      rule.scheduledDate,
      utcOffset: Duration.zero,
    );
    final duration = originalTargetRef.difference(originalStartRef);

    final newStartRef = DateTime.utc(
      newScheduledDate.year,
      newScheduledDate.month,
      newScheduledDate.day,
      policy.targetHour,
      policy.targetMinute,
    );
    final newTargetRef = newStartRef.add(duration);
    final targetDay = CivilDay.fromDateTime(newTargetRef);
    return RelativeTime(
      dayOffset: targetDay
          .toUtcDateTime()
          .difference(newScheduledDate.toUtcDateTime())
          .inDays,
      hour: newTargetRef.hour,
      minute: newTargetRef.minute,
    );
  }

  RelativeTime _getCompletionRelativeDue(
    TaskScheduleRule rule,
    CompletionRelativePolicy policy,
    CivilDay newScheduledDate,
  ) {
    return shiftRelativeToStart(
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
              shiftRelativeToStart(notifRel, rule, policy, newScheduledDate),
        )
        .toList();
  }

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
        createInstanceForRule: _createInstanceForRule,
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
