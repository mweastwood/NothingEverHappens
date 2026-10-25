import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/hive_local_data_source.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/scheduler_engine.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/utils/app_version.dart';

/// Reconciles local [TaskInstance] records when a [TaskSchedule] is modified.
class TaskScheduleReconciler {
  final HiveLocalDataSource _localDataSource;
  final String _userId;

  const TaskScheduleReconciler({
    required HiveLocalDataSource localDataSource,
    required String userId,
  }) : _localDataSource = localDataSource,
       _userId = userId;

  Future<void> reconcileInstancesOnUpdate({
    required TaskSchedule? oldTask,
    required TaskSchedule updatedTask,
    required Map<String, dynamic> changes,
  }) async {
    final schedulesChanged = changes.containsKey('schedules');
    final allTaskInstances = _localDataSource
        .getInstances()
        .where((i) => i.scheduleId == updatedTask.id)
        .toList();
    final instances =
        allTaskInstances.where((i) => i.status == TaskStatus.pending).toList()
          ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

    if (schedulesChanged) {
      final preservedCompletionRelativeRules = <String>{};
      for (final inst in instances) {
        final newRule = updatedTask.schedules
            .where((s) => s.id == inst.ruleId)
            .firstOrNull;
        final oldRule = oldTask?.schedules
            .where((s) => s.id == inst.ruleId)
            .firstOrNull;

        final alreadyPreservedCompletionRelative =
            newRule != null &&
            newRule.schedulingPolicy is CompletionRelativePolicy &&
            !preservedCompletionRelativeRules.add(newRule.id);

        if (newRule != null &&
            !alreadyPreservedCompletionRelative &&
            shouldPreservePendingInstanceOnScheduleEdit(
              inst: inst,
              newTask: updatedTask,
              oldRule: oldRule,
              newRule: newRule,
              changes: changes,
            )) {
          CivilDay? updatedScheduledDate;
          if (newRule.schedulingPolicy is CompletionRelativePolicy) {
            final resolvedForRule =
                allTaskInstances
                    .where(
                      (i) =>
                          i.ruleId == newRule.id &&
                          i.status != TaskStatus.pending,
                    )
                    .toList()
                  ..sort(
                    (a, b) => (b.completedAt ?? b.updatedAt).compareTo(
                      a.completedAt ?? a.updatedAt,
                    ),
                  );
            if (resolvedForRule.isNotEmpty) {
              final latest = resolvedForRule.first;
              final refTime = (latest.completedAt ?? latest.updatedAt)
                  .toLocal();
              updatedScheduledDate = CivilDay.fromDateTime(
                newRule.nextCompletionRelativeDateTime(refTime),
              );
            } else {
              updatedScheduledDate = newRule.scheduledDate;
            }
          }
          final updatedInst = buildUpdatedPendingInstance(
            inst: inst,
            task: updatedTask,
            rule: newRule,
            newScheduledDate: updatedScheduledDate,
          );
          await _localDataSource.saveInstance(updatedInst);
          await _localDataSource.markDirty(updatedInst.id);
        } else {
          await _localDataSource.deleteInstance(inst.id);
          await _localDataSource.markDirty(inst.id);
        }
      }
    } else {
      for (final inst in instances) {
        final rule = updatedTask.schedules
            .where((s) => s.id == inst.ruleId)
            .firstOrNull;
        final updatedInst = buildUpdatedPendingInstance(
          inst: inst,
          task: updatedTask,
          rule: rule,
        );
        await _localDataSource.saveInstance(updatedInst);
        await _localDataSource.markDirty(updatedInst.id);
      }
    }

    final nonPendingScopeMismatches = allTaskInstances.where(
      (i) =>
          i.status != TaskStatus.pending &&
          (i.isFamily != updatedTask.isFamily ||
              i.familyCompletionMode != updatedTask.familyCompletionMode),
    );
    for (final inst in nonPendingScopeMismatches) {
      final updatedInst = inst.copyWith(
        isFamily: updatedTask.isFamily,
        familyCompletionMode: updatedTask.familyCompletionMode,
        lastModifiedByUserId: _userId,
        lastModifiedByAppVersion: AppVersion.display,
        lastModifiedByPlatform: AppVersion.platform,
        hasPendingWrites: true,
        updatedAt: DateTime.now().toUtc(),
      );
      await _localDataSource.saveInstance(updatedInst);
      await _localDataSource.markDirty(updatedInst.id);
    }
  }

  static bool shouldPreservePendingInstanceOnScheduleEdit({
    required TaskInstance inst,
    required TaskSchedule newTask,
    required TaskScheduleRule? oldRule,
    required TaskScheduleRule newRule,
    required Map<String, dynamic> changes,
  }) {
    if (newRule.schedulingPolicy is CompletionRelativePolicy) {
      return true;
    }
    if (oldRule != null &&
        oldRule.toJson().toString() == newRule.toJson().toString()) {
      return true;
    }
    final isDateStillValid =
        !inst.scheduledDate.isBefore(newRule.scheduledDate) &&
        newRule.occursOn(inst.scheduledDate);
    if (!isDateStillValid) {
      return false;
    }
    if (oldRule != null && onlyRuleTimingsChanged(oldRule, newRule)) {
      return true;
    }
    if (newTask.isFamily && !changes.containsKey('isFamily')) {
      return true;
    }
    final hasActiveWorkflowProgress =
        inst.workflowPayload != null &&
        inst.workflowPayload!.stage != WorkflowStage.selectMeal;
    if (hasActiveWorkflowProgress || inst.completedByUserIds.isNotEmpty) {
      return true;
    }
    return false;
  }

  static bool onlyRuleTimingsChanged(
    TaskScheduleRule oldRule,
    TaskScheduleRule newRule,
  ) {
    final oldJson = Map<String, dynamic>.from(oldRule.toJson())
      ..remove('startRelativeTime')
      ..remove('dueRelativeTime')
      ..remove('notificationRelativeTimes');
    final newJson = Map<String, dynamic>.from(newRule.toJson())
      ..remove('startRelativeTime')
      ..remove('dueRelativeTime')
      ..remove('notificationRelativeTimes');
    return oldJson.toString() == newJson.toString();
  }

  static TaskInstance buildUpdatedPendingInstance({
    required TaskInstance inst,
    required TaskSchedule task,
    TaskScheduleRule? rule,
    CivilDay? newScheduledDate,
  }) {
    final effectiveDate = newScheduledDate ?? inst.scheduledDate;
    final hasStageSpecificText =
        inst.workflowPayload != null &&
        inst.workflowPayload!.stage != WorkflowStage.selectMeal;

    var startRel = inst.startRelativeTime;
    var dueRel = inst.dueRelativeTime;
    var notifRel = inst.notificationRelativeTimes;

    if (rule != null) {
      if (rule.schedulingPolicy is CompletionRelativePolicy) {
        final policy = rule.schedulingPolicy as CompletionRelativePolicy;
        startRel = RelativeTime(
          dayOffset: 0,
          hour: policy.targetHour,
          minute: policy.targetMinute,
        );
        dueRel = SchedulerEngine.shiftRelativeToStart(
          rule.dueRelativeTime,
          rule,
          policy,
          effectiveDate,
        );
        notifRel = rule.notificationRelativeTimes
            .map(
              (n) => SchedulerEngine.shiftRelativeToStart(
                n,
                rule,
                policy,
                effectiveDate,
              ),
            )
            .toList();
      } else {
        startRel = rule.startRelativeTime;
        dueRel = rule.dueRelativeTime;
        notifRel = rule.notificationRelativeTimes;
      }
    }

    if (task.workflowType == 'mealWorkflow') {
      final cfg = task.mealWorkflowConfig ?? const MealWorkflowConfig();
      final stage = inst.workflowPayload?.stage ?? WorkflowStage.selectMeal;
      switch (stage) {
        case WorkflowStage.shoppingList:
          startRel = cfg.shopTime;
          dueRel = cfg.shopTime;
          break;
        case WorkflowStage.prepDinner:
          startRel = cfg.prepTime;
          dueRel = cfg.prepTime;
          break;
        case WorkflowStage.selectMeal:
          startRel = cfg.selectTime;
          dueRel = cfg.selectTime;
          break;
      }
    }

    return inst.copyWith(
      title: hasStageSpecificText ? inst.title : task.title,
      description: hasStageSpecificText ? inst.description : task.description,
      scheduledDate: effectiveDate,
      startRelativeTime: startRel,
      dueRelativeTime: dueRel,
      notificationRelativeTimes: notifRel,
      priority: task.priority,
      isFamily: task.isFamily,
      familyCompletionMode: task.familyCompletionMode,
      labelIds: task.labelIds,
      cycleId: task.cycleId,
      clearCycleId: task.cycleId == null,
      assignedUserId: task.assignedUserId,
      clearAssignedUserId: task.assignedUserId == null,
      hasPendingWrites: true,
      updatedAt: DateTime.now().toUtc(),
    );
  }
}
