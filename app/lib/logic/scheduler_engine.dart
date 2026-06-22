import 'package:flutter/material.dart';
import 'civil_day.dart';
import 'task_schedule.dart';
import 'task_instance.dart';
import 'relative_time.dart';

class SchedulerAction {
  final List<TaskInstance> instancesToUpdate;
  final List<TaskInstance> instancesToSpawn;
  final TaskSchedule? updatedSchedule;

  const SchedulerAction({
    this.instancesToUpdate = const [],
    this.instancesToSpawn = const [],
    this.updatedSchedule,
  });
}

class SchedulerEngine {
  static SchedulerAction evaluate(
    TaskSchedule task,
    List<TaskInstance> taskInstances,
    DateTime now,
  ) {
    final today = CivilDay.fromDateTime(now);
    final isRecurring = task.schedules.any((s) => s is! OneOffSchedule);

    if (!isRecurring) {
      // One-Off Schedule: Ensure an instance exists for each OneOffSchedule in the task.
      final List<TaskInstance> toSpawn = [];
      for (int i = 0; i < task.schedules.length; i++) {
        final s = task.schedules[i];
        if (s is OneOffSchedule) {
          final instId = _instanceIdFor(task, s.scheduledDate, i);
          final exists = taskInstances.any((inst) => inst.id == instId);
          if (!exists) {
            toSpawn.add(
              TaskInstance(
                id: instId,
                scheduleId: task.id,
                title: task.title,
                description: task.description,
                scheduledDate: s.scheduledDate,
                startRelativeTime: s.startRelativeTime,
                dueRelativeTime: s.dueRelativeTime,
                notificationRelativeTime: s.notificationRelativeTime,
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
    CivilDay? newLastSpawnedDate = task.lastSpawnedDate;

    for (int i = 0; i < task.schedules.length; i++) {
      final s = task.schedules[i];
      final schedInstances = taskInstances.where((inst) {
        if (task.schedules.length <= 1) return true;
        return inst.id.endsWith('_$i');
      }).toList();

      final pendingForSchedule = schedInstances
          .where((inst) => inst.status == 'pending')
          .toList();

      if (s.schedulingPolicy is CompletionRelativePolicy) {
        final policy = s.schedulingPolicy as CompletionRelativePolicy;

        if (pendingForSchedule.isEmpty) {
          CivilDay? dateToSpawn;
          if (schedInstances.isEmpty) {
            dateToSpawn = s.scheduledDate;
          } else {
            final resolved =
                schedInstances
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
            final instId = _instanceIdFor(task, dateToSpawn, i);
            if (!taskInstances.any((inst) => inst.id == instId)) {
              final startRelative = RelativeTime(
                dayOffset: 0,
                time: policy.targetTime,
              );
              final dueRelative = _getCompletionRelativeDue(
                s,
                policy,
                dateToSpawn,
              );
              final notifRelative = _getCompletionRelativeNotification(
                s,
                policy,
                dateToSpawn,
              );

              toSpawn.add(
                TaskInstance(
                  id: instId,
                  scheduleId: task.id,
                  title: task.title,
                  description: task.description,
                  scheduledDate: dateToSpawn,
                  startRelativeTime: startRelative,
                  dueRelativeTime: dueRelative,
                  notificationRelativeTime: notifRelative,
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
      } else {
        // FixedCalendarPolicy logic
        final lastSpawned = task.lastSpawnedDate;
        final minStartDate = s.scheduledDate;

        CivilDay checkDate = lastSpawned != null
            ? lastSpawned.addDays(1)
            : minStartDate;

        List<CivilDay> datesToSpawn = [];
        int daysChecked = 0;
        while ((checkDate.isBefore(today) || checkDate == today) &&
            daysChecked < 30) {
          if (s.occursOn(checkDate)) {
            datesToSpawn.add(checkDate);
          }
          checkDate = checkDate.addDays(1);
          daysChecked++;
        }

        final List<TaskInstance> candidates = [];
        if (datesToSpawn.isNotEmpty) {
          for (final date in datesToSpawn) {
            final instId = _instanceIdFor(task, date, i);
            if (!taskInstances.any((inst) => inst.id == instId)) {
              candidates.add(
                TaskInstance(
                  id: instId,
                  scheduleId: task.id,
                  title: task.title,
                  description: task.description,
                  scheduledDate: date,
                  startRelativeTime: s.startRelativeTime,
                  dueRelativeTime: s.dueRelativeTime,
                  notificationRelativeTime: s.notificationRelativeTime,
                  isFamily: task.isFamily,
                  priority: task.priority,
                  cycleId: task.cycleId,
                  assignedUserId: task.assignedUserId,
                  status: 'pending',
                ),
              );
            }
          }

          final latestSpawned = datesToSpawn.last;
          if (newLastSpawnedDate == null ||
              newLastSpawnedDate.isBefore(latestSpawned)) {
            newLastSpawnedDate = latestSpawned;
          }
        }

        final existingForSchedule = schedInstances.toList();
        final allInstances = <TaskInstance>[
          ...existingForSchedule,
          ...candidates,
        ];

        final nonCompleted = allInstances
            .where((inst) => inst.status != 'completed')
            .toList();

        void updateInstance(TaskInstance inst) {
          final existsInDb = taskInstances.any((x) => x.id == inst.id);
          if (existsInDb) {
            final orig = taskInstances.firstWhere((x) => x.id == inst.id);
            if (orig.status != inst.status) {
              toUpdate.add(inst);
            }
          } else {
            toSpawn.add(inst);
          }
        }

        if (nonCompleted.isNotEmpty) {
          final policy = s.missedOccurrencePolicy.policy;

          if (policy == MissedPolicy.stack) {
            for (final inst in nonCompleted) {
              updateInstance(inst.copyWith(status: 'pending'));
            }
          } else if (policy == MissedPolicy.autoDismiss) {
            for (final inst in nonCompleted) {
              final isExpired = s.missedOccurrencePolicy.isInstanceExpired(
                inst,
                now,
              );
              final nextStatus = isExpired ? 'skipped' : 'pending';
              updateInstance(inst.copyWith(status: nextStatus));
            }
          } else if (policy == MissedPolicy.preferNewer) {
            final latestScheduledDate = nonCompleted
                .map((inst) => inst.scheduledDate)
                .reduce((a, b) => a.isBefore(b) ? b : a);

            for (final inst in nonCompleted) {
              final nextStatus = inst.scheduledDate == latestScheduledDate
                  ? 'pending'
                  : 'skipped';
              updateInstance(inst.copyWith(status: nextStatus));
            }
          } else if (policy == MissedPolicy.preferOlder) {
            final earliestScheduledDate = nonCompleted
                .map((inst) => inst.scheduledDate)
                .reduce((a, b) => a.isBefore(b) ? a : b);

            for (final inst in nonCompleted) {
              final nextStatus = inst.scheduledDate == earliestScheduledDate
                  ? 'pending'
                  : 'skipped';
              updateInstance(inst.copyWith(status: nextStatus));
            }
          }
        }
      }
    }

    final updatedSchedule = (newLastSpawnedDate != task.lastSpawnedDate)
        ? task.copyWith(lastSpawnedDate: newLastSpawnedDate)
        : null;

    return SchedulerAction(
      instancesToUpdate: toUpdate,
      instancesToSpawn: toSpawn,
      updatedSchedule: updatedSchedule,
    );
  }

  static String _instanceIdFor(
    TaskSchedule task,
    CivilDay date,
    int ruleIndex,
  ) {
    final dateStr = date.toString();
    return task.schedules.length == 1
        ? '${task.id}_$dateStr'
        : '${task.id}_${dateStr}_$ruleIndex';
  }

  static RelativeTime _getCompletionRelativeDue(
    TaskScheduleRule rule,
    CompletionRelativePolicy policy,
    CivilDay newScheduledDate,
  ) {
    final originalStartRef = rule.startRelativeTime.referenceTo(
      rule.scheduledDate,
    );
    final originalDueRef = rule.dueRelativeTime.referenceTo(rule.scheduledDate);
    final duration = originalDueRef.difference(originalStartRef);

    final newStartRef = DateTime(
      newScheduledDate.year,
      newScheduledDate.month,
      newScheduledDate.day,
      policy.targetTime.hour,
      policy.targetTime.minute,
    );
    final newDueRef = newStartRef.add(duration);
    final dueDay = CivilDay.fromDateTime(newDueRef);
    return RelativeTime(
      dayOffset: dueDay
          .toDateTime()
          .difference(newScheduledDate.toDateTime())
          .inDays,
      time: TimeOfDay.fromDateTime(newDueRef),
    );
  }

  static RelativeTime? _getCompletionRelativeNotification(
    TaskScheduleRule rule,
    CompletionRelativePolicy policy,
    CivilDay newScheduledDate,
  ) {
    if (rule.notificationRelativeTime == null) return null;
    final originalStartRef = rule.startRelativeTime.referenceTo(
      rule.scheduledDate,
    );
    final originalNotifRef = rule.notificationRelativeTime!.referenceTo(
      rule.scheduledDate,
    );
    final duration = originalNotifRef.difference(originalStartRef);

    final newStartRef = DateTime(
      newScheduledDate.year,
      newScheduledDate.month,
      newScheduledDate.day,
      policy.targetTime.hour,
      policy.targetTime.minute,
    );
    final newNotifRef = newStartRef.add(duration);
    final notifDay = CivilDay.fromDateTime(newNotifRef);
    return RelativeTime(
      dayOffset: notifDay
          .toDateTime()
          .difference(newScheduledDate.toDateTime())
          .inDays,
      time: TimeOfDay.fromDateTime(newNotifRef),
    );
  }

  static TaskInstance? getNextOccurrenceToSpawn(
    TaskSchedule task,
    TaskInstance completedInstance,
    DateTime now,
  ) {
    final ruleIndex = _ruleIndexOfInstance(task, completedInstance);
    if (ruleIndex < 0 || ruleIndex >= task.schedules.length) return null;
    final rule = task.schedules[ruleIndex];

    if (rule.schedulingPolicy is CompletionRelativePolicy) {
      final policy = rule.schedulingPolicy as CompletionRelativePolicy;
      final nextDate = CivilDay.fromDateTime(now.add(policy.interval));
      final nextInstId = _instanceIdFor(task, nextDate, ruleIndex);

      final startRelative = RelativeTime(dayOffset: 0, time: policy.targetTime);
      final dueRelative = _getCompletionRelativeDue(rule, policy, nextDate);
      final notifRelative = _getCompletionRelativeNotification(
        rule,
        policy,
        nextDate,
      );

      return TaskInstance(
        id: nextInstId,
        scheduleId: task.id,
        title: task.title,
        description: task.description,
        scheduledDate: nextDate,
        startRelativeTime: startRelative,
        dueRelativeTime: dueRelative,
        notificationRelativeTime: notifRelative,
        isFamily: task.isFamily,
        priority: task.priority,
        cycleId: task.cycleId,
        assignedUserId: task.assignedUserId,
        status: 'pending',
      );
    } else {
      final today = CivilDay.fromDateTime(now);
      final refDate = today.isBefore(completedInstance.scheduledDate)
          ? completedInstance.scheduledDate.addDays(1)
          : today.addDays(1);

      CivilDay? nextDate;
      if (rule.occursOn(refDate)) {
        nextDate = refDate;
      } else {
        final candidate = rule.nextOccurrenceAfter(refDate);
        if (candidate != null && !candidate.isBefore(refDate)) {
          nextDate = candidate;
        }
      }

      if (nextDate != null) {
        final nextInstId = _instanceIdFor(task, nextDate, ruleIndex);
        return TaskInstance(
          id: nextInstId,
          scheduleId: task.id,
          title: task.title,
          description: task.description,
          scheduledDate: nextDate,
          startRelativeTime: rule.startRelativeTime,
          dueRelativeTime: rule.dueRelativeTime,
          notificationRelativeTime: rule.notificationRelativeTime,
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
  ) {
    final ruleIndex = _ruleIndexOfInstance(task, completedInstance);
    if (ruleIndex < 0 || ruleIndex >= task.schedules.length) return null;
    final rule = task.schedules[ruleIndex];

    if (rule.schedulingPolicy is CompletionRelativePolicy) {
      final policy = rule.schedulingPolicy as CompletionRelativePolicy;
      final nextDate = CivilDay.fromDateTime(now.add(policy.interval));
      return _instanceIdFor(task, nextDate, ruleIndex);
    } else {
      final today = CivilDay.fromDateTime(now);
      final refDate = today.isBefore(completedInstance.scheduledDate)
          ? completedInstance.scheduledDate.addDays(1)
          : today.addDays(1);

      CivilDay? nextDate;
      if (rule.occursOn(refDate)) {
        nextDate = refDate;
      } else {
        final candidate = rule.nextOccurrenceAfter(refDate);
        if (candidate != null && !candidate.isBefore(refDate)) {
          nextDate = candidate;
        }
      }

      if (nextDate != null) {
        return _instanceIdFor(task, nextDate, ruleIndex);
      }
    }
    return null;
  }

  static int _ruleIndexOfInstance(TaskSchedule task, TaskInstance instance) {
    if (task.schedules.length <= 1) return 0;
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
