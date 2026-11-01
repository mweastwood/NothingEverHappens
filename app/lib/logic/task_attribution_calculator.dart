import 'civil_day.dart';
import 'task_instance.dart';
import 'task_schedule.dart';

/// Centralizes domain rules for attributing [TaskInstance] items and their
/// durations to a user across personal timelines, planned daily minutes, and
/// scheduler capacity evaluation.
class TaskAttributionCalculator {
  const TaskAttributionCalculator._();

  /// Evaluates whether [instance] should be attributed to [currentUserId] on the
  /// personal timeline, along with its effective status and duration.
  static ({
    bool isUserTask,
    TaskStatus effectiveStatus,
    double effectiveDuration,
  })
  evaluatePersonalTimelineAttribution({
    required TaskInstance instance,
    required String? currentUserId,
    required int familyMemberCount,
    required CivilDay today,
    required double baseDuration,
  }) {
    final safeMemberCount = familyMemberCount > 0 ? familyMemberCount : 1;

    if (instance.isFamily) {
      if (instance.assignedUserId != null &&
          instance.assignedUserId!.isNotEmpty) {
        if (instance.status == TaskStatus.completed ||
            instance.status == TaskStatus.skipped) {
          return (
            isUserTask: instance.completedByUserId == currentUserId,
            effectiveStatus: instance.status,
            effectiveDuration: baseDuration,
          );
        } else {
          return (
            isUserTask: instance.assignedUserId == currentUserId,
            effectiveStatus: instance.status,
            effectiveDuration: baseDuration,
          );
        }
      } else if (instance.familyCompletionMode ==
          FamilyCompletionMode.individual) {
        final userCompleted = instance.completedByUserIds.contains(
          currentUserId,
        );
        if (userCompleted) {
          return (
            isUserTask: true,
            effectiveStatus: TaskStatus.completed,
            effectiveDuration: baseDuration,
          );
        } else if (instance.status == TaskStatus.skipped) {
          return (
            isUserTask: instance.completedByUserId == currentUserId,
            effectiveStatus: TaskStatus.skipped,
            effectiveDuration: baseDuration,
          );
        } else if (instance.status == TaskStatus.failed ||
            (instance.status == TaskStatus.pending &&
                instance.scheduledDate.isBefore(today))) {
          return (
            isUserTask: true,
            effectiveStatus: TaskStatus.failed,
            effectiveDuration: baseDuration,
          );
        } else {
          return (
            isUserTask: true,
            effectiveStatus: TaskStatus.pending,
            effectiveDuration: baseDuration,
          );
        }
      } else {
        // Unassigned and anybody can complete
        if (instance.status == TaskStatus.completed ||
            instance.status == TaskStatus.skipped) {
          return (
            isUserTask: instance.completedByUserId == currentUserId,
            effectiveStatus: instance.status,
            effectiveDuration: baseDuration,
          );
        } else if (instance.status == TaskStatus.pending) {
          if (instance.scheduledDate.isBefore(today)) {
            return (
              isUserTask: false,
              effectiveStatus: TaskStatus.pending,
              effectiveDuration: 0.0,
            );
          } else {
            return (
              isUserTask: true,
              effectiveStatus: TaskStatus.pending,
              effectiveDuration: baseDuration / safeMemberCount,
            );
          }
        } else {
          return (
            isUserTask: false,
            effectiveStatus: instance.status,
            effectiveDuration: 0.0,
          );
        }
      }
    } else {
      if (instance.status == TaskStatus.completed ||
          instance.status == TaskStatus.skipped) {
        final isUserTask =
            instance.completedByUserId == currentUserId ||
            (instance.completedByUserId == null &&
                (instance.assignedUserId == null ||
                    instance.assignedUserId == currentUserId));
        return (
          isUserTask: isUserTask,
          effectiveStatus: instance.status,
          effectiveDuration: baseDuration,
        );
      } else {
        final isUserTask =
            instance.assignedUserId == null ||
            instance.assignedUserId == currentUserId;
        return (
          isUserTask: isUserTask,
          effectiveStatus: instance.status,
          effectiveDuration: baseDuration,
        );
      }
    }
  }

  /// Calculates the pending planned minutes attributable to [currentUserId]
  /// for [instance] given its [durationMinutes] and [familyMemberCount].
  static double calculateUserPendingPlannedMinutes({
    required TaskInstance instance,
    required String? currentUserId,
    required int familyMemberCount,
    required int durationMinutes,
  }) {
    if (durationMinutes <= 0 || instance.status != TaskStatus.pending) {
      return 0.0;
    }

    final safeMemberCount = familyMemberCount > 0 ? familyMemberCount : 1;

    if (instance.isFamily) {
      if (instance.assignedUserId != null &&
          instance.assignedUserId!.isNotEmpty) {
        return instance.assignedUserId == currentUserId
            ? durationMinutes.toDouble()
            : 0.0;
      } else if (instance.familyCompletionMode ==
          FamilyCompletionMode.individual) {
        final userCompleted =
            currentUserId != null &&
            instance.completedByUserIds.contains(currentUserId);
        return !userCompleted ? durationMinutes.toDouble() : 0.0;
      } else {
        // Unassigned and anybody can complete
        return durationMinutes / safeMemberCount;
      }
    } else {
      if (instance.assignedUserId == null ||
          instance.assignedUserId == currentUserId) {
        return durationMinutes.toDouble();
      }
      return 0.0;
    }
  }

  /// Evaluates whether [instance] (belonging to [task]) is attributable to
  /// [userId] when computing daily planned capacity hours in `MissedPolicyRunner`.
  static bool isInstanceAttributableToUserForCapacity({
    required TaskInstance instance,
    required TaskSchedule task,
    required String? userId,
  }) {
    if (instance.status == TaskStatus.skipped ||
        instance.status == TaskStatus.failed) {
      return false;
    }

    final assignedUser = instance.assignedUserId ?? task.assignedUserId;

    if (task.isFamily) {
      if (assignedUser != null && assignedUser.isNotEmpty) {
        return assignedUser == userId;
      }
      if (instance.familyCompletionMode == FamilyCompletionMode.anyone &&
          instance.status == TaskStatus.completed) {
        return userId == null ||
            userId.isEmpty ||
            instance.completedByUserId == userId ||
            instance.completedByUserIds.contains(userId);
      }
      return true;
    }

    return assignedUser == null ||
        assignedUser.isEmpty ||
        assignedUser == userId;
  }
}
