import '../models/civil_day.dart';
import '../models/task_instance.dart';
import '../models/user_settings.dart';
import 'scheduler_engine.dart';

class SchedulerCapacityFilter {
  final String? appVersion;
  final String? platform;

  const SchedulerCapacityFilter({
    this.appVersion,
    this.platform,
  });

  double _capacityForDate(UserSettings? userSettings, CivilDay day) {
    return userSettings?.getCapacityForDate(day.toDateTime()) ??
        SchedulerEngine.defaultDailyCapacityHours;
  }

  TaskInstance _markSkippedByCapacity(
    TaskInstance inst,
    SchedulerEvaluationContext context,
  ) {
    return inst.copyWith(
      status: TaskStatus.skipped,
      statusReason: InstanceStatusReason.schedulerCapacityLimit.value,
      lastModifiedByAppVersion: appVersion,
      lastModifiedByPlatform: platform,
      lastModifiedByUserId: context.userId,
      updatedAt: context.now.toUtc(),
    );
  }

  TaskInstance _reviveFromCapacitySkip(
    TaskInstance inst,
    SchedulerEvaluationContext context,
  ) {
    return inst.copyWith(
      status: TaskStatus.pending,
      clearStatusReason: true,
      lastModifiedByAppVersion: appVersion,
      lastModifiedByPlatform: platform,
      lastModifiedByUserId: context.userId,
      updatedAt: context.now.toUtc(),
    );
  }

  ({List<TaskInstance> finalToSpawn, List<TaskInstance> finalToUpdate})
      applyCapacityLimits(
    SchedulerEvaluationContext context, {
    required List<TaskInstance> toSpawn,
    List<TaskInstance> toUpdate = const [],
    List<String> toDelete = const [],
  }) {
    final task = context.task;
    final taskInstances = context.taskInstances;
    final now = context.now;
    final latestToday = context.latestToday;
    final userSettings = context.userSettings;
    final dayPlannedHours = context.dayPlannedHours;
    final applyCapacityLimits = context.applyCapacityLimits;

    final List<TaskInstance> finalToSpawn = [];
    final List<TaskInstance> finalToUpdate = List.from(toUpdate);
    final Map<String, int> updateIndexById = {
      for (var i = 0; i < finalToUpdate.length; i++) finalToUpdate[i].id: i,
    };
    final Set<String> toDeleteSet = toDelete.toSet();
    final Set<String> taskInstanceIds = {for (final x in taskInstances) x.id};

    if (task.skipIfNoCapacity && applyCapacityLimits) {
      final double taskDuration =
          (task.estimatedDuration ?? const Duration()).inMinutes /
              SchedulerEngine.minutesPerHour;
      final Map<CivilDay, double> tempPlannedHours =
          dayPlannedHours != null ? Map.from(dayPlannedHours) : {};

      // 1. Process instances already in the DB that are pending or skipped (support skipping and revival)
      for (final inst in taskInstances) {
        final start = context.referenceToEarliest(
          inst.startRelativeTime,
          inst.scheduledDate,
        );
        final due = context.referenceToLatest(
          inst.dueRelativeTime,
          inst.scheduledDate,
        );
        final isEligibleWindow = now.isBefore(start) ||
            (!inst.scheduledDate.isBefore(latestToday) && now.isBefore(due));

        final isMarkedForDelete = toDeleteSet.contains(inst.id);
        final updateIdx = updateIndexById[inst.id];
        final isMarkedForUpdate = updateIdx != null;
        if (isMarkedForDelete) continue;

        final effectiveInst =
            isMarkedForUpdate ? finalToUpdate[updateIdx] : inst;
        final effectiveStatus = effectiveInst.status;

        if ((effectiveStatus == TaskStatus.pending ||
                effectiveInst.isRevivableByCapacity) &&
            isEligibleWindow) {
          final capacity = _capacityForDate(userSettings, inst.scheduledDate);
          final planned = tempPlannedHours[inst.scheduledDate] ?? 0.0;

          if (capacity - planned < taskDuration) {
            if (effectiveStatus == TaskStatus.pending) {
              if (isMarkedForUpdate) {
                if (inst.status == TaskStatus.skipped) {
                  finalToUpdate.removeAt(updateIdx);
                  updateIndexById.remove(inst.id);
                  for (var i = updateIdx; i < finalToUpdate.length; i++) {
                    updateIndexById[finalToUpdate[i].id] = i;
                  }
                } else {
                  finalToUpdate[updateIdx] = _markSkippedByCapacity(
                    finalToUpdate[updateIdx],
                    context,
                  );
                }
              } else {
                final newUpdate = _markSkippedByCapacity(inst, context);
                updateIndexById[newUpdate.id] = finalToUpdate.length;
                finalToUpdate.add(newUpdate);
              }
            }
          } else {
            if (effectiveInst.isRevivableByCapacity) {
              if (!isMarkedForUpdate) {
                final newUpdate = _reviveFromCapacitySkip(inst, context);
                updateIndexById[newUpdate.id] = finalToUpdate.length;
                finalToUpdate.add(newUpdate);
                tempPlannedHours[inst.scheduledDate] = planned + taskDuration;
              }
            } else if (effectiveStatus == TaskStatus.pending) {
              tempPlannedHours[inst.scheduledDate] = planned + taskDuration;
            }
          }
        }
      }

      // 2. Process toSpawn instances
      for (final inst in toSpawn) {
        if (inst.status == TaskStatus.pending &&
            inst.scheduledDate.compareTo(latestToday) >= 0) {
          final capacity = _capacityForDate(userSettings, inst.scheduledDate);
          final planned = tempPlannedHours[inst.scheduledDate] ?? 0.0;

          if (capacity - planned < taskDuration) {
            finalToSpawn.add(_markSkippedByCapacity(inst, context));
          } else {
            finalToSpawn.add(inst);
            tempPlannedHours[inst.scheduledDate] = planned + taskDuration;
          }
        } else {
          finalToSpawn.add(inst);
        }
      }

      // 3. Process toUpdate instances that were NOT in taskInstances (e.g. newly created/modified)
      for (int i = 0; i < finalToUpdate.length; i++) {
        final inst = finalToUpdate[i];
        final wasProcessed = taskInstanceIds.contains(inst.id);
        if (!wasProcessed &&
            inst.status == TaskStatus.pending &&
            inst.scheduledDate.compareTo(latestToday) >= 0) {
          final capacity = _capacityForDate(userSettings, inst.scheduledDate);
          final planned = tempPlannedHours[inst.scheduledDate] ?? 0.0;

          if (capacity - planned < taskDuration) {
            finalToUpdate[i] = _markSkippedByCapacity(inst, context);
          } else {
            tempPlannedHours[inst.scheduledDate] = planned + taskDuration;
          }
        }
      }
    } else {
      // If skipIfNoCapacity is false and applyCapacityLimits is true, revive only capacity-skipped instances back to pending
      if (!task.skipIfNoCapacity && applyCapacityLimits) {
        for (final inst in taskInstances) {
          final start = context.referenceToEarliest(
            inst.startRelativeTime,
            inst.scheduledDate,
          );
          final due = context.referenceToLatest(
            inst.dueRelativeTime,
            inst.scheduledDate,
          );
          final isEligibleWindow = now.isBefore(start) ||
              (!inst.scheduledDate.isBefore(latestToday) && now.isBefore(due));
          if (inst.isRevivableByCapacity && isEligibleWindow) {
            final isMarkedForDelete = toDeleteSet.contains(inst.id);
            if (isMarkedForDelete) continue;
            final updateIdx = updateIndexById[inst.id];
            if (updateIdx != null) {
              if (finalToUpdate[updateIdx].isRevivableByCapacity) {
                finalToUpdate[updateIdx] = _reviveFromCapacitySkip(
                  finalToUpdate[updateIdx],
                  context,
                );
              }
            } else {
              final newUpdate = _reviveFromCapacitySkip(inst, context);
              updateIndexById[newUpdate.id] = finalToUpdate.length;
              finalToUpdate.add(newUpdate);
            }
          }
        }
      }
      finalToSpawn.addAll(toSpawn);
    }

    return (finalToSpawn: finalToSpawn, finalToUpdate: finalToUpdate);
  }
}
