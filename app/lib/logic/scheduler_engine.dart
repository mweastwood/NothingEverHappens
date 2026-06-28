import 'package:flutter/material.dart';
import 'civil_day.dart';
import 'task_schedule.dart';
import 'task_instance.dart';
import 'relative_time.dart';

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

class SchedulerEngine {
  static SchedulerAction evaluate(
    TaskSchedule task,
    List<TaskInstance> taskInstances,
    DateTime now, {
    int? futureInstancesCount,
  }) {
    final resolvedFutureInstancesCount =
        futureInstancesCount ?? task.futureInstancesCount;
    final today = CivilDay.fromDateTime(now);
    final isRecurring = task.schedules.any((s) => s is! OneOffSchedule);

    if (!isRecurring) {
      // One-Off Schedule: Ensure an instance exists for each OneOffSchedule in the task.
      final List<TaskInstance> toSpawn = [];
      for (int i = 0; i < task.schedules.length; i++) {
        final s = task.schedules[i];
        if (s is OneOffSchedule) {
          final exists = taskInstances.any(
            (inst) =>
                inst.ruleId == s.id && inst.scheduledDate == s.scheduledDate,
          );
          if (!exists) {
            toSpawn.add(
              TaskInstance(
                id: TaskInstance.generateId(),
                scheduleId: task.id,
                ruleId: s.id,
                title: task.title,
                description: task.description,
                scheduledDate: s.scheduledDate,
                startRelativeTime: s.startRelativeTime,
                dueRelativeTime: s.dueRelativeTime,
                notificationRelativeTimes: s.notificationRelativeTimes,
                isFamily: task.isFamily,
                priority: task.priority,
                cycleId: task.cycleId,
                assignedUserId: task.assignedUserId,
                status: 'pending',
              ),
            );
          }
        }
      }
      return SchedulerAction(instancesToSpawn: toSpawn);
    }

    // Recurring Schedule
    final List<TaskInstance> toUpdate = [];
    final List<TaskInstance> toSpawn = [];
    final List<String> toDelete = [];
    CivilDay? maxSpawned;

    for (int i = 0; i < task.schedules.length; i++) {
      final s = task.schedules[i];

      if (s.schedulingPolicy is CompletionRelativePolicy) {
        final policy = s.schedulingPolicy as CompletionRelativePolicy;
        final ruleInstances = taskInstances
            .where((inst) => inst.ruleId == s.id)
            .toList();
        final pendingForSchedule = ruleInstances
            .where((inst) => inst.status == 'pending')
            .toList();

        if (pendingForSchedule.isEmpty) {
          CivilDay? dateToSpawn;
          if (ruleInstances.isEmpty) {
            dateToSpawn = s.scheduledDate;
          } else {
            final resolved =
                ruleInstances
                    .where(
                      (inst) =>
                          inst.status != 'pending' && inst.completedAt != null,
                    )
                    .toList()
                  ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
            if (resolved.isNotEmpty) {
              final latest = resolved.first;
              final nextSpawnTime = latest.completedAt!.add(policy.interval);
              if (!now.isBefore(nextSpawnTime)) {
                dateToSpawn = CivilDay.fromDateTime(nextSpawnTime);
              }
            }
          }

          if (dateToSpawn != null) {
            final instId = TaskInstance.generateId();
            final startRelative = RelativeTime(
              dayOffset: 0,
              time: policy.targetTime,
            );
            final dueRelative = _getCompletionRelativeDue(
              s,
              policy,
              dateToSpawn,
            );
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
                priority: task.priority,
                cycleId: task.cycleId,
                assignedUserId: task.assignedUserId,
                status: 'pending',
              ),
            );
          }
        }
      } else {
        // FixedCalendarPolicy: N future instances queue-based model
        final ruleInstances = taskInstances
            .where((inst) => inst.ruleId == s.id)
            .toList();
        final pending =
            ruleInstances.where((inst) => inst.status == 'pending').toList()
              ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

        // 1. Determine the initial baseDate
        CivilDay initialBaseDate;
        if (pending.isNotEmpty) {
          initialBaseDate = pending.first.scheduledDate;
        } else {
          final resolved =
              ruleInstances.where((inst) => inst.status != 'pending').toList()
                ..sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
          if (resolved.isNotEmpty) {
            final nextOcc = s.nextOccurrenceAfter(resolved.first.scheduledDate);
            if (nextOcc == null) {
              // The schedule rule is finished and has no future occurrences.
              continue;
            }
            initialBaseDate = nextOcc;
          } else {
            initialBaseDate = s.occursOn(s.scheduledDate)
                ? s.scheduledDate
                : (s.nextOccurrenceAfter(s.scheduledDate) ?? s.scheduledDate);
          }
        }

        final maxEvaluationDate = initialBaseDate.addDays(30);

        // Keep a set/list of all instances for this rule (both existing DB ones and candidates we spawn)
        // We will update their statuses as we loop.
        final Map<CivilDay, TaskInstance> workingInstances = {};
        for (final inst in ruleInstances) {
          workingInstances[inst.scheduledDate] = inst;
        }

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
          for (int j = 0; j < resolvedFutureInstancesCount; j++) {
            if (current.compareTo(today) > 0 &&
                current.compareTo(maxEvaluationDate) <= 0) {
              targetDates.add(current);
              final next = s.nextOccurrenceAfter(current);
              if (next != null) {
                current = next;
              } else {
                break;
              }
            } else {
              break;
            }
          }

          for (final date in targetDates) {
            if (!workingInstances.containsKey(date)) {
              final instId = TaskInstance.generateId();
              workingInstances[date] = TaskInstance(
                id: instId,
                scheduleId: task.id,
                ruleId: s.id,
                title: task.title,
                description: task.description,
                scheduledDate: date,
                startRelativeTime: s.startRelativeTime,
                dueRelativeTime: s.dueRelativeTime,
                notificationRelativeTimes: s.notificationRelativeTimes,
                isFamily: task.isFamily,
                priority: task.priority,
                cycleId: task.cycleId,
                assignedUserId: task.assignedUserId,
                status: 'pending',
              );
            }
          }

          // Apply missed policies to the targetDates
          final policy = s.missedOccurrencePolicy.policy;
          bool hasNewSkipped = false;

          if (policy == MissedPolicy.stack) {
            for (final date in targetDates) {
              final inst = workingInstances[date]!;
              workingInstances[date] = inst.copyWith(status: 'pending');
            }
          } else if (policy == MissedPolicy.autoDismiss) {
            for (final date in targetDates) {
              final inst = workingInstances[date]!;
              final isExpired = s.missedOccurrencePolicy.isInstanceExpired(
                inst,
                now,
              );
              final nextStatus = isExpired ? 'skipped' : 'pending';
              if (inst.status != nextStatus) {
                workingInstances[date] = inst.copyWith(status: nextStatus);
                if (nextStatus == 'skipped') {
                  hasNewSkipped = true;
                }
              }
            }
          } else if (policy == MissedPolicy.preferNewer) {
            final pastOrPresentDates = targetDates
                .where((d) => !d.isAfter(today))
                .toList();
            final CivilDay? latestPastOrPresentDate = pastOrPresentDates.isEmpty
                ? null
                : pastOrPresentDates.reduce((a, b) => a.isAfter(b) ? a : b);

            for (final date in targetDates) {
              final inst = workingInstances[date]!;
              final String nextStatus;
              if (date.isAfter(today)) {
                nextStatus = 'pending';
              } else {
                nextStatus = date == latestPastOrPresentDate
                    ? 'pending'
                    : 'skipped';
              }
              if (inst.status != nextStatus) {
                workingInstances[date] = inst.copyWith(status: nextStatus);
                if (nextStatus == 'skipped') {
                  hasNewSkipped = true;
                }
              }
            }
          } else if (policy == MissedPolicy.preferOlder) {
            final earliestScheduledDate = targetDates.reduce(
              (a, b) => a.isBefore(b) ? a : b,
            );
            for (final date in targetDates) {
              final inst = workingInstances[date]!;
              final isEarliest = date == earliestScheduledDate;
              final nextStatus = isEarliest ? 'pending' : 'skipped';
              if (inst.status != nextStatus) {
                workingInstances[date] = inst.copyWith(status: nextStatus);
                if (nextStatus == 'skipped') {
                  hasNewSkipped = true;
                }
              }
            }
          }

          // If we had any new skipped instances, the baseDate of the queue might have shifted forward.
          if (hasNewSkipped) {
            final pendingAfterMissed =
                workingInstances.values
                    .where(
                      (inst) =>
                          inst.status == 'pending' &&
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
              if (nextOcc != null &&
                  nextOcc.compareTo(maxEvaluationDate) <= 0) {
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

          final existsInDb = ruleInstances.any((x) => x.id == inst.id);
          if (existsInDb) {
            final orig = ruleInstances.firstWhere((x) => x.id == inst.id);
            if (orig.status != inst.status) {
              toUpdate.add(inst);
            }
          } else {
            final isSkipOrOlderNewer =
                (s.missedOccurrencePolicy.policy == MissedPolicy.preferNewer ||
                s.missedOccurrencePolicy.policy == MissedPolicy.preferOlder);
            if (inst.status == 'skipped' && isSkipOrOlderNewer) {
              // Do not spawn!
            } else {
              toSpawn.add(inst);
            }
          }
        }

        // 5. Delete pending instances that are no longer in the target queue (pruning)
        final futureTargetDates = targetDates
            .where((d) => d.compareTo(today) > 0)
            .toSet();
        for (final inst in pending) {
          if (inst.scheduledDate.compareTo(today) > 0 &&
              !futureTargetDates.contains(inst.scheduledDate)) {
            toDelete.add(inst.id);
          }
        }
      }
    }

    // Calculate critical times
    final List<DateTime> triggerTimes = [];
    final allCurrentInstances = [
      ...taskInstances.where((inst) => inst.scheduleId == task.id),
      ...toSpawn,
    ];
    for (final inst in allCurrentInstances) {
      if (inst.status == 'pending') {
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
    final uniqueTriggerTimes = triggerTimes.toSet().toList();

    TaskSchedule? updatedSchedule;
    if (maxSpawned != null &&
        (task.lastSpawnedDate == null ||
            maxSpawned.compareTo(task.lastSpawnedDate!) > 0)) {
      updatedSchedule = task.copyWith(lastSpawnedDate: maxSpawned);
    }

    return SchedulerAction(
      instancesToUpdate: toUpdate,
      instancesToSpawn: toSpawn,
      instancesToDelete: toDelete,
      updatedSchedule: updatedSchedule,
      triggerTimes: uniqueTriggerTimes,
    );
  }

  static RelativeTime _shiftRelativeToStart(
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

  static RelativeTime _getCompletionRelativeDue(
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

  static List<RelativeTime> _getCompletionRelativeNotifications(
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

  static TaskInstance? getNextOccurrenceToSpawn(
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
      final nextInstId = TaskInstance.generateId();

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
        priority: task.priority,
        cycleId: task.cycleId,
        assignedUserId: task.assignedUserId,
        status: 'pending',
      );
    } else {
      // Find the latest uncompleted instance of this rule (excluding the completedInstance)
      final ruleInstances =
          taskInstances
              .where(
                (inst) =>
                    inst.ruleId == rule.id &&
                    inst.id != completedInstance.id &&
                    inst.status == 'pending',
              )
              .toList()
            ..sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));

      final baseDate = ruleInstances.isNotEmpty
          ? ruleInstances.first.scheduledDate
          : completedInstance.scheduledDate;

      final nextDate = rule.nextOccurrenceAfter(baseDate);
      if (nextDate != null) {
        final nextInstId = TaskInstance.generateId();
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
          priority: task.priority,
          cycleId: task.cycleId,
          assignedUserId: task.assignedUserId,
          status: 'pending',
        );
      }
    }
    return null;
  }

  static String? getNextOccurrenceIdToDelete(
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
            .where((inst) => inst.ruleId == rule.id && inst.status == 'pending')
            .toList()
          ..sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
    if (ruleInstances.isNotEmpty) {
      return ruleInstances.first.id;
    }
    return null;
  }

  static int _ruleIndexOfInstance(TaskSchedule task, TaskInstance instance) {
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
