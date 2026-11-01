import '../models/civil_day.dart';
import '../models/relative_time.dart';
import '../models/task_instance.dart';
import '../models/task_schedule.dart';

class SchedulerInstanceFactory {
  final String Function() generateId;
  final String? appVersion;
  final String? platform;

  const SchedulerInstanceFactory({
    String Function()? generateId,
    this.appVersion = 'unknown',
    this.platform = 'unknown',
  }) : generateId = generateId ?? TaskInstance.generateId;

  TaskInstance createInstanceForRule({
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
      dueRelative = getCompletionRelativeDue(rule, policy, scheduledDate);
      notifRelative = getCompletionRelativeNotifications(
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
        workflowGroupId: WorkflowInstancePayload.generateGroupId(
          task.id,
          scheduledDate,
        ),
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

  static RelativeTime getCompletionRelativeDue(
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

  static List<RelativeTime> getCompletionRelativeNotifications(
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
}
