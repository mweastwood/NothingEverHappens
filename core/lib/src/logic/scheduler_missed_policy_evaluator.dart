import '../models/app_logger.dart';
import '../models/civil_day.dart';
import '../models/missed_occurrence_policy.dart';
import '../models/task_instance.dart';
import '../models/task_schedule_rule.dart';
import 'scheduler_engine.dart';

class SchedulerMissedPolicyEvaluator {
  final AppLogger? logger;
  final String? appVersion;
  final String? platform;

  const SchedulerMissedPolicyEvaluator({
    this.logger,
    this.appVersion,
    this.platform,
  });

  bool applyMissedPolicy(
    Map<CivilDay, TaskInstance> workingInstances,
    List<TaskInstance> canonicalInstances,
    List<CivilDay> targetDates,
    TaskScheduleRule rule,
    SchedulerEvaluationContext context,
  ) {
    final policy = rule.missedOccurrencePolicy.policy;
    switch (policy) {
      case MissedPolicy.stack:
        _applyStackPolicy(
          workingInstances,
          canonicalInstances,
          targetDates,
          context,
        );
        return false;
      case MissedPolicy.autoDismiss:
        return _applyAutoDismissPolicy(
          workingInstances,
          canonicalInstances,
          targetDates,
          rule,
          context,
        );
      case MissedPolicy.preferNewer:
        return _applyPreferNewerPolicy(
          workingInstances,
          canonicalInstances,
          targetDates,
          context,
        );
      case MissedPolicy.preferOlder:
        return _applyPreferOlderPolicy(
          workingInstances,
          canonicalInstances,
          targetDates,
          context,
        );
    }
  }

  bool _isOriginalResolved(
    TaskInstance inst,
    List<TaskInstance> canonicalInstances,
  ) {
    return canonicalInstances.any(
      (x) => x.id == inst.id && x.status != TaskStatus.pending,
    );
  }

  void _applyStackPolicy(
    Map<CivilDay, TaskInstance> workingInstances,
    List<TaskInstance> canonicalInstances,
    List<CivilDay> targetDates,
    SchedulerEvaluationContext context,
  ) {
    for (final date in targetDates) {
      final inst = workingInstances[date]!;
      if (!_isOriginalResolved(inst, canonicalInstances) &&
          inst.status != TaskStatus.pending) {
        workingInstances[date] = inst.copyWith(
          status: TaskStatus.pending,
          clearStatusReason: true,
          lastModifiedByAppVersion: appVersion,
          lastModifiedByPlatform: platform,
          lastModifiedByUserId: context.userId,
          updatedAt: context.now.toUtc(),
        );
      }
    }
  }

  bool _applyAutoDismissPolicy(
    Map<CivilDay, TaskInstance> workingInstances,
    List<TaskInstance> canonicalInstances,
    List<CivilDay> targetDates,
    TaskScheduleRule rule,
    SchedulerEvaluationContext context,
  ) {
    final now = context.now;
    final userId = context.userId;
    final task = context.task;
    bool hasNewSkipped = false;
    for (final date in targetDates) {
      final inst = workingInstances[date]!;
      if (_isOriginalResolved(inst, canonicalInstances)) continue;

      final isExpired = rule.missedOccurrencePolicy.isInstanceExpired(
        inst,
        now,
        utcOffset: context.latestUtcOffset,
      );
      final nextStatus = isExpired ? TaskStatus.skipped : TaskStatus.pending;
      if (_updateInstanceStatus(
        workingInstances,
        date,
        nextStatus,
        now: now,
        statusReason: InstanceStatusReason.schedulerAutoDismiss.value,
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
    SchedulerEvaluationContext context,
  ) {
    final now = context.now;
    final latestToday = context.latestToday;
    final userId = context.userId;
    final task = context.task;
    bool hasNewSkipped = false;
    final startedDates = targetDates.where((d) {
      if (d.isAfter(latestToday)) return false;
      final inst = workingInstances[d]!;
      if (_isOriginalResolved(inst, canonicalInstances)) return false;
      final start = context.referenceToLatest(inst.startRelativeTime, d);
      return !now.isBefore(start);
    }).toList();

    final CivilDay? latestStartedDate = startedDates.isEmpty
        ? null
        : startedDates.reduce((a, b) => a.isAfter(b) ? a : b);

    for (final date in targetDates) {
      final inst = workingInstances[date]!;
      if (_isOriginalResolved(inst, canonicalInstances)) continue;

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
        now: now,
        statusReason: InstanceStatusReason.schedulerPreferNewer.value,
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
    SchedulerEvaluationContext context,
  ) {
    final now = context.now;
    final today = context.today;
    final latestToday = context.latestToday;
    final userId = context.userId;
    final task = context.task;
    bool hasNewSkipped = false;
    final startedDates = targetDates.where((d) {
      if (d.isAfter(today)) return false;
      final inst = workingInstances[d]!;
      if (_isOriginalResolved(inst, canonicalInstances)) return false;
      final start = context.referenceToEarliest(inst.startRelativeTime, d);
      return !now.isBefore(start);
    }).toList();

    final CivilDay? earliestStartedDate = startedDates.isEmpty
        ? null
        : startedDates.reduce((a, b) => a.isBefore(b) ? a : b);

    for (final date in targetDates) {
      final inst = workingInstances[date]!;
      if (_isOriginalResolved(inst, canonicalInstances)) continue;

      final TaskStatus nextStatus;
      if (date == earliestStartedDate) {
        nextStatus = TaskStatus.pending;
      } else if (!date.isAfter(latestToday) &&
          !now.isBefore(
            context.referenceToLatest(inst.startRelativeTime, date),
          )) {
        nextStatus = TaskStatus.skipped;
      } else {
        nextStatus = TaskStatus.pending;
      }
      if (_updateInstanceStatus(
        workingInstances,
        date,
        nextStatus,
        now: now,
        statusReason: InstanceStatusReason.schedulerPreferOlder.value,
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
    required DateTime now,
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
        lastModifiedByAppVersion: appVersion,
        lastModifiedByPlatform: platform,
        lastModifiedByUserId: userId,
        updatedAt: now.toUtc(),
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
}
