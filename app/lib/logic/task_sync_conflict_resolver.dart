import 'package:flutter/foundation.dart' show listEquals;
import 'package:nothing_ever_happens/logic/task_instance.dart';

/// Stateless conflict resolution and slot arbitration rules for local vs. remote [TaskInstance]s.
class TaskSyncConflictResolver {
  const TaskSyncConflictResolver._();

  /// Compares timestamps at millisecond resolution to determine if [a] is strictly
  /// newer than [b], avoiding conflict loops from sub-millisecond precision differences.
  static bool isStrictlyNewer(DateTime a, DateTime b) {
    return a.millisecondsSinceEpoch > b.millisecondsSinceEpoch;
  }

  static bool hasSlotUserActionOrProgress(TaskInstance inst) {
    final isSchedulerAction =
        (inst.parsedStatusReason?.isSchedulerAction ?? false) ||
        (inst.statusReason?.startsWith('scheduler_') ?? false);
    if (isSchedulerAction) {
      return false;
    }
    if (inst.status == TaskStatus.completed ||
        inst.status == TaskStatus.skipped ||
        inst.parsedStatusReason == InstanceStatusReason.userModified ||
        (inst.parsedStatusReason?.isUserAction ?? false) ||
        (inst.statusReason?.startsWith('user_') ?? false)) {
      return true;
    }
    if (inst.completedByUserIds.isNotEmpty) {
      return true;
    }
    if (inst.workflowPayload != null &&
        inst.workflowPayload!.stage != WorkflowStage.selectMeal) {
      return true;
    }
    return false;
  }

  static bool isEquivalentPendingSlotInstance(TaskInstance a, TaskInstance b) {
    if (a.status != TaskStatus.pending || b.status != TaskStatus.pending) {
      return false;
    }
    return a.title == b.title &&
        a.description == b.description &&
        a.startRelativeTime == b.startRelativeTime &&
        a.dueRelativeTime == b.dueRelativeTime &&
        a.priority == b.priority &&
        a.isFamily == b.isFamily &&
        a.familyCompletionMode == b.familyCompletionMode &&
        a.assignedUserId == b.assignedUserId &&
        a.cycleId == b.cycleId &&
        listEquals(a.labelIds, b.labelIds) &&
        listEquals(a.notificationRelativeTimes, b.notificationRelativeTimes);
  }

  static bool doesSlotCandidateWin(TaskInstance local, TaskInstance remote) {
    final localHasUserProgress = hasSlotUserActionOrProgress(local);
    final remoteHasUserProgress = hasSlotUserActionOrProgress(remote);
    if (localHasUserProgress != remoteHasUserProgress) {
      return localHasUserProgress;
    }
    if (!localHasUserProgress &&
        !remoteHasUserProgress &&
        isEquivalentPendingSlotInstance(local, remote)) {
      if (local.updatedAt.millisecondsSinceEpoch ==
          remote.updatedAt.millisecondsSinceEpoch) {
        return local.id.compareTo(remote.id) < 0;
      }
      // Prefer the earlier-spawned canonical pending instance over a later
      // duplicate lookahead spawn for the same unchanged schedule slot.
      return isStrictlyNewer(remote.updatedAt, local.updatedAt);
    }
    if (local.updatedAt.millisecondsSinceEpoch ==
        remote.updatedAt.millisecondsSinceEpoch) {
      return local.id.compareTo(remote.id) < 0;
    }
    return doesLocalWin(local, remote);
  }

  static bool doesLocalWin(TaskInstance local, TaskInstance remote) {
    final localIsUser =
        local.parsedStatusReason == InstanceStatusReason.userModified ||
        ((local.status != TaskStatus.pending) &&
            ((local.parsedStatusReason?.isUserAction ?? false) ||
                (local.statusReason?.startsWith('user_') ?? false)));
    final remoteIsUser =
        remote.parsedStatusReason == InstanceStatusReason.userModified ||
        ((remote.status != TaskStatus.pending) &&
            ((remote.parsedStatusReason?.isUserAction ?? false) ||
                (remote.statusReason?.startsWith('user_') ?? false)));
    final localIsScheduler =
        (local.parsedStatusReason?.isSchedulerAction ?? false) ||
        (local.statusReason?.startsWith('scheduler_') ?? false);
    final remoteIsScheduler =
        (remote.parsedStatusReason?.isSchedulerAction ?? false) ||
        (remote.statusReason?.startsWith('scheduler_') ?? false);

    // 1. User vs. Scheduler Conflict & Non-downgrade Invariant:
    // A user action (user_completed, user_dismissed) always wins over an automated
    // scheduler action (scheduler_*), regardless of updatedAt timestamps.
    if (localIsUser && remoteIsScheduler) {
      return true;
    }
    if (remoteIsUser && localIsScheduler) {
      return false;
    }

    // 3. Homogeneous Resolution:
    // If both records are user_*, both are scheduler_*, or neither, fall back to Last-Write-Wins based on updatedAt.
    // Compare in milliseconds to avoid sub-millisecond precision differences between platforms causing conflict loops.
    return isStrictlyNewer(local.updatedAt, remote.updatedAt);
  }
}
