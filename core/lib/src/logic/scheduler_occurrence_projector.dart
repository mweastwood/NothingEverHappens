import '../models/civil_day.dart';
import '../models/task_instance.dart';
import '../models/task_schedule.dart';

class SchedulerOccurrenceProjector {
  const SchedulerOccurrenceProjector();

  static bool isInstanceForRule(
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

  static int ruleIndexOfInstance(TaskSchedule task, TaskInstance instance) {
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

  TaskInstance? getNextOccurrenceToSpawn(
    TaskSchedule task,
    TaskInstance completedInstance,
    DateTime now,
    List<TaskInstance> taskInstances, {
    required TaskInstance Function({
      required TaskSchedule task,
      required TaskScheduleRule rule,
      required CivilDay scheduledDate,
      DateTime? now,
      String? userId,
    }) createInstanceForRule,
    Duration? utcOffset,
    String? userId,
  }) {
    final ruleIndex = ruleIndexOfInstance(task, completedInstance);
    if (ruleIndex < 0 || ruleIndex >= task.schedules.length) return null;
    final rule = task.schedules[ruleIndex];
    if (rule is OneOffSchedule) return null;

    if (rule.schedulingPolicy is CompletionRelativePolicy) {
      final hasPendingForRule = taskInstances.any(
        (inst) =>
            isInstanceForRule(inst, rule, task) &&
            inst.id != completedInstance.id &&
            inst.status == TaskStatus.pending,
      );
      if (hasPendingForRule) return null;

      final wallClockNow =
          utcOffset != null ? now.toUtc().add(utcOffset) : now.toLocal();
      final nextSpawnTime = rule.nextCompletionRelativeDateTime(wallClockNow);
      final nextDate = CivilDay.fromDateTime(nextSpawnTime);
      return createInstanceForRule(
        task: task,
        rule: rule,
        scheduledDate: nextDate,
        now: now,
        userId: userId,
      );
    } else {
      final ruleInstances = taskInstances
          .where(
            (inst) =>
                isInstanceForRule(inst, rule, task) &&
                inst.id != completedInstance.id &&
                inst.status == TaskStatus.pending,
          )
          .toList()
        ..sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));

      final baseDate = (ruleInstances.isNotEmpty &&
              ruleInstances.first.scheduledDate.isAfter(
                completedInstance.scheduledDate,
              ))
          ? ruleInstances.first.scheduledDate
          : completedInstance.scheduledDate;

      final nextDate = rule.nextOccurrenceAfter(baseDate);
      if (nextDate != null) {
        final alreadyExists = taskInstances.any(
          (inst) =>
              isInstanceForRule(inst, rule, task) &&
              inst.scheduledDate == nextDate,
        );
        if (alreadyExists) return null;

        return createInstanceForRule(
          task: task,
          rule: rule,
          scheduledDate: nextDate,
          now: now,
          userId: userId,
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
    final ruleIndex = ruleIndexOfInstance(task, completedInstance);
    if (ruleIndex < 0 || ruleIndex >= task.schedules.length) return null;
    final rule = task.schedules[ruleIndex];
    if (rule is OneOffSchedule) return null;

    final isCompletionRelative =
        rule.schedulingPolicy is CompletionRelativePolicy;
    final ruleInstances = taskInstances
        .where(
          (inst) =>
              isInstanceForRule(inst, rule, task) &&
              inst.id != completedInstance.id &&
              inst.status == TaskStatus.pending &&
              (isCompletionRelative ||
                  inst.scheduledDate.isAfter(completedInstance.scheduledDate)),
        )
        .toList()
      ..sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
    if (ruleInstances.isNotEmpty) {
      return ruleInstances.first.id;
    }
    return null;
  }

  List<CivilDay> projectUpcomingOccurrences(
    TaskSchedule task,
    TaskScheduleRule rule,
    CivilDay fromDate, {
    int count = 5,
    List<TaskInstance> existingInstances = const [],
    Duration? utcOffset,
  }) {
    if (count <= 0) return const [];
    final List<CivilDay> result = [];

    if (rule is OneOffSchedule) {
      if (!rule.scheduledDate.isBefore(fromDate)) {
        result.add(rule.scheduledDate);
      }
      return result;
    }

    if (rule.schedulingPolicy is CompletionRelativePolicy) {
      final ruleInstances = existingInstances
          .where((inst) => isInstanceForRule(inst, rule, task))
          .toList();
      final pending = ruleInstances
          .where((inst) => inst.status == TaskStatus.pending)
          .toList()
        ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

      DateTime cursorTime;
      if (pending.isNotEmpty) {
        final firstDay = pending.first.scheduledDate;
        final effectiveFirstDay =
            firstDay.isBefore(fromDate) ? fromDate : firstDay;
        result.add(effectiveFirstDay);
        cursorTime = effectiveFirstDay.toDateTime();
      } else {
        final resolved = ruleInstances
            .where((inst) => inst.status != TaskStatus.pending)
            .toList()
          ..sort(
            (a, b) => (b.completedAt ?? b.updatedAt).compareTo(
              a.completedAt ?? a.updatedAt,
            ),
          );
        if (resolved.isNotEmpty) {
          final latest = resolved.first;
          final rawResolvedTime = latest.completedAt ?? latest.updatedAt;
          final resolvedTime = utcOffset != null
              ? rawResolvedTime.toUtc().add(utcOffset)
              : rawResolvedTime.toLocal();
          cursorTime = rule.nextCompletionRelativeDateTime(resolvedTime);
          final nextDay = CivilDay.fromDateTime(cursorTime);
          final effectiveNextDay =
              nextDay.isBefore(fromDate) ? fromDate : nextDay;
          result.add(effectiveNextDay);
          cursorTime =
              nextDay.isBefore(fromDate) ? fromDate.toDateTime() : cursorTime;
        } else {
          final startDay = rule.scheduledDate.isBefore(fromDate)
              ? fromDate
              : rule.scheduledDate;
          result.add(startDay);
          cursorTime = startDay.toDateTime();
        }
      }

      int iterations = 0;
      while (result.length < count && iterations < count * 10) {
        iterations++;
        final nextTime = rule.nextCompletionRelativeDateTime(cursorTime);
        if (!nextTime.isAfter(cursorTime)) break;
        cursorTime = nextTime;
        final day = CivilDay.fromDateTime(cursorTime);
        if (!day.isBefore(fromDate) && (result.isEmpty || result.last != day)) {
          result.add(day);
        }
      }
      return result;
    }

    var current =
        rule.occursOn(fromDate) ? fromDate : rule.nextOccurrenceAfter(fromDate);
    while (current != null && result.length < count) {
      result.add(current);
      current = rule.nextOccurrenceAfter(current);
    }
    return result;
  }
}
