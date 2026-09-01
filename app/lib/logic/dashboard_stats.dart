import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_clock.dart';
import 'auth_repository.dart';
import 'civil_day.dart';
import 'family.dart';
import 'family_repository.dart';
import 'task_instance.dart';
import 'task_repository.dart';
import 'task_schedule.dart';

class DailyStatsData {
  final CivilDay day;
  final int completedCount;
  final int skippedCount;
  final int missedCount;
  final int plannedCount;
  final double completedHours;
  final double completedOnTimeHours;
  final double completedOverdueHours;
  final double completedSeriouslyOverdueHours;
  final double skippedHours;
  final double missedHours;
  final double plannedHours;
  final List<TaskInstance> completedTasks;
  final List<TaskInstance> skippedTasks;
  final List<TaskInstance> missedTasks;
  final List<TaskInstance> plannedTasks;
  final List<TaskInstance> completedOnTimeTasks;
  final List<TaskInstance> completedOverdueTasks;
  final List<TaskInstance> completedSeriouslyOverdueTasks;

  DailyStatsData({
    required this.day,
    this.completedCount = 0,
    this.skippedCount = 0,
    this.missedCount = 0,
    int? plannedCount,
    this.completedHours = 0.0,
    this.completedOnTimeHours = 0.0,
    this.completedOverdueHours = 0.0,
    this.completedSeriouslyOverdueHours = 0.0,
    this.skippedHours = 0.0,
    this.missedHours = 0.0,
    this.plannedHours = 0.0,
    this.completedTasks = const [],
    this.skippedTasks = const [],
    this.missedTasks = const [],
    this.plannedTasks = const [],
    List<TaskInstance>? completedOnTimeTasks,
    List<TaskInstance>? completedOverdueTasks,
    List<TaskInstance>? completedSeriouslyOverdueTasks,
  }) : plannedCount = plannedCount ?? plannedTasks.length,
       completedOnTimeTasks =
           completedOnTimeTasks ??
           completedTasks.where((t) => !t.isCompletedOverdue).toList(),
       completedOverdueTasks =
           completedOverdueTasks ??
           completedTasks
               .where(
                 (t) =>
                     t.isCompletedOverdue &&
                     !t.isCompletedOverdueByMoreThan24Hours,
               )
               .toList(),
       completedSeriouslyOverdueTasks =
           completedSeriouslyOverdueTasks ??
           completedTasks
               .where((t) => t.isCompletedOverdueByMoreThan24Hours)
               .toList();

  int get completedOnTimeCount => completedOnTimeTasks.length;
  int get completedOverdueCount => completedOverdueTasks.length;
  int get completedSeriouslyOverdueCount =>
      completedSeriouslyOverdueTasks.length;
  int get totalCompletedOverdueCount =>
      completedOverdueCount + completedSeriouslyOverdueCount;

  double get completedModeratelyOverdueHours =>
      (completedOverdueHours - completedSeriouslyOverdueHours).clamp(
        0.0,
        double.infinity,
      );
}

class PersonalLastWeekStats {
  final int completedCount;
  final double completedHours;
  final int skippedCount;
  final int missedCount;
  final double completionRate;
  final List<DailyStatsData> dailyStats;
  final CivilDay startDay;
  final CivilDay endDay;

  const PersonalLastWeekStats({
    required this.completedCount,
    required this.completedHours,
    required this.skippedCount,
    required this.missedCount,
    required this.completionRate,
    required this.dailyStats,
    required this.startDay,
    required this.endDay,
  });

  bool get hasActivity =>
      completedCount > 0 || skippedCount > 0 || missedCount > 0;
}

class FamilyMemberStats {
  final String userId;
  final String displayName;
  final String email;
  final FamilyRole role;
  final int completedCount;
  final double completedHours;
  final int skippedCount;
  final int missedCount;
  final double contributionPercentage;
  final List<TaskInstance> completedTasks;

  const FamilyMemberStats({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.role,
    required this.completedCount,
    required this.completedHours,
    required this.skippedCount,
    required this.missedCount,
    required this.contributionPercentage,
    this.completedTasks = const [],
  });
}

class FamilyLastWeekStats {
  final String familyId;
  final String familyName;
  final int totalCompletedCount;
  final double totalCompletedHours;
  final int totalSkippedCount;
  final int totalMissedCount;
  final int totalPlannedCount;
  final double totalPlannedHours;
  final double completionRate;
  final List<FamilyMemberStats> memberStats;
  final List<DailyStatsData> dailyStats;
  final CivilDay startDay;
  final CivilDay endDay;

  const FamilyLastWeekStats({
    required this.familyId,
    required this.familyName,
    required this.totalCompletedCount,
    required this.totalCompletedHours,
    required this.totalSkippedCount,
    required this.totalMissedCount,
    this.totalPlannedCount = 0,
    this.totalPlannedHours = 0.0,
    required this.completionRate,
    required this.memberStats,
    this.dailyStats = const [],
    required this.startDay,
    required this.endDay,
  });

  bool get hasActivity =>
      totalCompletedCount > 0 ||
      totalSkippedCount > 0 ||
      totalMissedCount > 0 ||
      totalPlannedCount > 0;
}

class _DailyStatsAccumulator {
  final CivilDay day;
  int completedCount = 0;
  int skippedCount = 0;
  int missedCount = 0;
  int plannedCount = 0;
  double completedHours = 0.0;
  double completedOnTimeHours = 0.0;
  double completedOverdueHours = 0.0;
  double completedSeriouslyOverdueHours = 0.0;
  double skippedHours = 0.0;
  double missedHours = 0.0;
  double plannedHours = 0.0;
  final List<TaskInstance> completedTasks = [];
  final List<TaskInstance> skippedTasks = [];
  final List<TaskInstance> missedTasks = [];
  final List<TaskInstance> plannedTasks = [];

  _DailyStatsAccumulator(this.day);

  DailyStatsData toDailyStatsData() {
    return DailyStatsData(
      day: day,
      completedCount: completedCount,
      skippedCount: skippedCount,
      missedCount: missedCount,
      plannedCount: plannedCount,
      completedHours: completedHours,
      completedOnTimeHours: completedOnTimeHours,
      completedOverdueHours: completedOverdueHours,
      completedSeriouslyOverdueHours: completedSeriouslyOverdueHours,
      skippedHours: skippedHours,
      missedHours: missedHours,
      plannedHours: plannedHours,
      completedTasks: completedTasks,
      skippedTasks: skippedTasks,
      missedTasks: missedTasks,
      plannedTasks: plannedTasks,
    );
  }
}

final personalLastWeekStatsProvider = Provider<PersonalLastWeekStats>((ref) {
  final instances = ref.watch(taskInstancesProvider).value ?? [];
  final schedules = ref.watch(taskSchedulesProvider).value ?? [];
  final currentUserId = ref.watch(authStateProvider).value?.uid;

  final profileVal = ref.watch(familyProfileStreamProvider);
  final familyProfile = profileVal.value;
  Family? family;
  if (familyProfile != null && familyProfile.familyId.isNotEmpty) {
    family = ref.watch(familyStreamProvider(familyProfile.familyId)).value;
  }
  final int familyMemberCount = (family?.members.isNotEmpty ?? false)
      ? family!.members.length
      : 1;

  final today = CivilDay.fromDateTime(AppClock.now);
  final startDay = today.addDays(-6);
  final endDay = today;

  final durationMap = <String, double>{
    for (final s in schedules)
      if (s.estimatedDuration != null)
        s.id: s.estimatedDuration!.inMinutes / 60.0,
  };

  final scheduleMap = <String, TaskSchedule>{
    for (final s in schedules) s.id: s,
  };

  final days = List.generate(7, (index) => startDay.addDays(index));
  final accByDay = <CivilDay, _DailyStatsAccumulator>{
    for (final d in days) d: _DailyStatsAccumulator(d),
  };

  int totalCompleted = 0;
  double totalHours = 0.0;
  int totalSkipped = 0;
  int totalMissed = 0;

  for (final inst in instances) {
    final schedule = scheduleMap[inst.scheduleId];
    final rule = schedule?.schedules
        .where((r) => r.id == inst.ruleId)
        .firstOrNull;
    final bool isOneOff =
        rule is OneOffSchedule ||
        (rule == null &&
            schedule != null &&
            schedule.schedules.isNotEmpty &&
            schedule.schedules.every((r) => r is OneOffSchedule));

    final CivilDay accountedDay =
        (isOneOff &&
            inst.status == TaskStatus.completed &&
            inst.completedAt != null)
        ? CivilDay.fromDateTime(inst.completedAt!)
        : inst.scheduledDate;

    final acc = accByDay[accountedDay];
    if (acc == null) {
      continue;
    }

    final double baseDuration = durationMap[inst.scheduleId] ?? 0.0;
    final bool isUserTask;
    final TaskStatus effectiveStatus;
    final double effectiveDuration;

    if (inst.isFamily) {
      if (inst.assignedUserId != null && inst.assignedUserId!.isNotEmpty) {
        if (inst.status == TaskStatus.completed ||
            inst.status == TaskStatus.skipped) {
          isUserTask = inst.completedByUserId == currentUserId;
          effectiveStatus = inst.status;
          effectiveDuration = baseDuration;
        } else {
          isUserTask = inst.assignedUserId == currentUserId;
          effectiveStatus = inst.status;
          effectiveDuration = baseDuration;
        }
      } else if (inst.familyCompletionMode == FamilyCompletionMode.individual) {
        final userCompleted = inst.completedByUserIds.contains(currentUserId);
        if (userCompleted) {
          isUserTask = true;
          effectiveStatus = TaskStatus.completed;
          effectiveDuration = baseDuration;
        } else if (inst.status == TaskStatus.skipped) {
          isUserTask = inst.completedByUserId == currentUserId;
          effectiveStatus = TaskStatus.skipped;
          effectiveDuration = baseDuration;
        } else if (inst.status == TaskStatus.failed ||
            (inst.status == TaskStatus.pending &&
                inst.scheduledDate.isBefore(today))) {
          isUserTask = true;
          effectiveStatus = TaskStatus.failed;
          effectiveDuration = baseDuration;
        } else {
          isUserTask = true;
          effectiveStatus = TaskStatus.pending;
          effectiveDuration = baseDuration;
        }
      } else {
        // Unassigned and anybody can complete
        if (inst.status == TaskStatus.completed ||
            inst.status == TaskStatus.skipped) {
          isUserTask = inst.completedByUserId == currentUserId;
          effectiveStatus = inst.status;
          effectiveDuration = baseDuration;
        } else if (inst.status == TaskStatus.pending) {
          if (inst.scheduledDate.isBefore(today)) {
            isUserTask = false;
            effectiveStatus = TaskStatus.pending;
            effectiveDuration = 0.0;
          } else {
            isUserTask = true;
            effectiveStatus = TaskStatus.pending;
            effectiveDuration = baseDuration / familyMemberCount;
          }
        } else {
          isUserTask = false;
          effectiveStatus = inst.status;
          effectiveDuration = 0.0;
        }
      }
    } else {
      if (inst.status == TaskStatus.completed ||
          inst.status == TaskStatus.skipped) {
        isUserTask =
            inst.completedByUserId == currentUserId ||
            (inst.completedByUserId == null &&
                (inst.assignedUserId == null ||
                    inst.assignedUserId == currentUserId));
        effectiveStatus = inst.status;
        effectiveDuration = baseDuration;
      } else {
        isUserTask =
            inst.assignedUserId == null || inst.assignedUserId == currentUserId;
        effectiveStatus = inst.status;
        effectiveDuration = baseDuration;
      }
    }

    if (!isUserTask) continue;

    if (effectiveStatus == TaskStatus.completed) {
      totalCompleted++;
      totalHours += effectiveDuration;
      acc.completedCount++;
      acc.completedHours += effectiveDuration;
      acc.completedTasks.add(inst);

      if (inst.isCompletedOverdue) {
        acc.completedOverdueHours += effectiveDuration;
        if (inst.isCompletedOverdueByMoreThan24Hours) {
          acc.completedSeriouslyOverdueHours += effectiveDuration;
        }
      } else {
        acc.completedOnTimeHours += effectiveDuration;
      }
    } else if (effectiveStatus == TaskStatus.skipped) {
      totalSkipped++;
      acc.skippedCount++;
      acc.skippedHours += effectiveDuration;
      acc.skippedTasks.add(inst);
    } else if (effectiveStatus == TaskStatus.failed) {
      totalMissed++;
      acc.missedCount++;
      acc.missedHours += effectiveDuration;
      acc.missedTasks.add(inst);
    } else if (effectiveStatus == TaskStatus.pending) {
      if (inst.scheduledDate.isBefore(today)) {
        totalMissed++;
        acc.missedCount++;
        acc.missedHours += effectiveDuration;
        acc.missedTasks.add(inst);
      } else {
        acc.plannedCount++;
        acc.plannedHours += effectiveDuration;
        acc.plannedTasks.add(inst);
      }
    }
  }

  final totalActionable = totalCompleted + totalSkipped + totalMissed;
  final completionRate = totalActionable > 0
      ? (totalCompleted / totalActionable)
      : 0.0;

  final dailyStats = days.map((d) => accByDay[d]!.toDailyStatsData()).toList();

  return PersonalLastWeekStats(
    completedCount: totalCompleted,
    completedHours: totalHours,
    skippedCount: totalSkipped,
    missedCount: totalMissed,
    completionRate: completionRate,
    dailyStats: dailyStats,
    startDay: startDay,
    endDay: endDay,
  );
});

final personalTimelineStatsProvider = Provider<Map<CivilDay, DailyStatsData>>((
  ref,
) {
  final instances = ref.watch(taskInstancesProvider).value ?? [];
  final schedules = ref.watch(taskSchedulesProvider).value ?? [];
  final currentUserId = ref.watch(authStateProvider).value?.uid;

  final profileVal = ref.watch(familyProfileStreamProvider);
  final familyProfile = profileVal.value;
  Family? family;
  if (familyProfile != null && familyProfile.familyId.isNotEmpty) {
    family = ref.watch(familyStreamProvider(familyProfile.familyId)).value;
  }
  final int familyMemberCount = (family?.members.isNotEmpty ?? false)
      ? family!.members.length
      : 1;

  final today = CivilDay.fromDateTime(AppClock.now);
  final startDay = today.addDays(-6);

  final durationMap = <String, double>{
    for (final s in schedules)
      if (s.estimatedDuration != null)
        s.id: s.estimatedDuration!.inMinutes / 60.0,
  };

  final scheduleMap = <String, TaskSchedule>{
    for (final s in schedules) s.id: s,
  };

  final days = List.generate(13, (index) => startDay.addDays(index));
  final accByDay = <CivilDay, _DailyStatsAccumulator>{
    for (final d in days) d: _DailyStatsAccumulator(d),
  };

  for (final inst in instances) {
    final schedule = scheduleMap[inst.scheduleId];
    final rule = schedule?.schedules
        .where((r) => r.id == inst.ruleId)
        .firstOrNull;
    final bool isOneOff =
        rule is OneOffSchedule ||
        (rule == null &&
            schedule != null &&
            schedule.schedules.isNotEmpty &&
            schedule.schedules.every((r) => r is OneOffSchedule));

    final CivilDay accountedDay =
        (isOneOff &&
            inst.status == TaskStatus.completed &&
            inst.completedAt != null)
        ? CivilDay.fromDateTime(inst.completedAt!)
        : inst.scheduledDate;

    final acc = accByDay[accountedDay];
    if (acc == null) {
      continue;
    }

    final double baseDuration = durationMap[inst.scheduleId] ?? 0.0;
    final bool isUserTask;
    final TaskStatus effectiveStatus;
    final double effectiveDuration;

    if (inst.isFamily) {
      if (inst.assignedUserId != null && inst.assignedUserId!.isNotEmpty) {
        if (inst.status == TaskStatus.completed ||
            inst.status == TaskStatus.skipped) {
          isUserTask = inst.completedByUserId == currentUserId;
          effectiveStatus = inst.status;
          effectiveDuration = baseDuration;
        } else {
          isUserTask = inst.assignedUserId == currentUserId;
          effectiveStatus = inst.status;
          effectiveDuration = baseDuration;
        }
      } else if (inst.familyCompletionMode == FamilyCompletionMode.individual) {
        final userCompleted = inst.completedByUserIds.contains(currentUserId);
        if (userCompleted) {
          isUserTask = true;
          effectiveStatus = TaskStatus.completed;
          effectiveDuration = baseDuration;
        } else if (inst.status == TaskStatus.skipped) {
          isUserTask = inst.completedByUserId == currentUserId;
          effectiveStatus = TaskStatus.skipped;
          effectiveDuration = baseDuration;
        } else if (inst.status == TaskStatus.failed ||
            (inst.status == TaskStatus.pending &&
                inst.scheduledDate.isBefore(today))) {
          isUserTask = true;
          effectiveStatus = TaskStatus.failed;
          effectiveDuration = baseDuration;
        } else {
          isUserTask = true;
          effectiveStatus = TaskStatus.pending;
          effectiveDuration = baseDuration;
        }
      } else {
        // Unassigned and anybody can complete
        if (inst.status == TaskStatus.completed ||
            inst.status == TaskStatus.skipped) {
          isUserTask = inst.completedByUserId == currentUserId;
          effectiveStatus = inst.status;
          effectiveDuration = baseDuration;
        } else if (inst.status == TaskStatus.pending) {
          if (inst.scheduledDate.isBefore(today)) {
            isUserTask = false;
            effectiveStatus = TaskStatus.pending;
            effectiveDuration = 0.0;
          } else {
            isUserTask = true;
            effectiveStatus = TaskStatus.pending;
            effectiveDuration = baseDuration / familyMemberCount;
          }
        } else {
          isUserTask = false;
          effectiveStatus = inst.status;
          effectiveDuration = 0.0;
        }
      }
    } else {
      if (inst.status == TaskStatus.completed ||
          inst.status == TaskStatus.skipped) {
        isUserTask =
            inst.completedByUserId == currentUserId ||
            (inst.completedByUserId == null &&
                (inst.assignedUserId == null ||
                    inst.assignedUserId == currentUserId));
        effectiveStatus = inst.status;
        effectiveDuration = baseDuration;
      } else {
        isUserTask =
            inst.assignedUserId == null || inst.assignedUserId == currentUserId;
        effectiveStatus = inst.status;
        effectiveDuration = baseDuration;
      }
    }

    if (!isUserTask) continue;

    if (effectiveStatus == TaskStatus.completed) {
      acc.completedCount++;
      acc.completedHours += effectiveDuration;
      acc.completedTasks.add(inst);

      if (inst.isCompletedOverdue) {
        acc.completedOverdueHours += effectiveDuration;
        if (inst.isCompletedOverdueByMoreThan24Hours) {
          acc.completedSeriouslyOverdueHours += effectiveDuration;
        }
      } else {
        acc.completedOnTimeHours += effectiveDuration;
      }
    } else if (effectiveStatus == TaskStatus.skipped) {
      acc.skippedCount++;
      acc.skippedHours += effectiveDuration;
      acc.skippedTasks.add(inst);
    } else if (effectiveStatus == TaskStatus.failed) {
      acc.missedCount++;
      acc.missedHours += effectiveDuration;
      acc.missedTasks.add(inst);
    } else if (effectiveStatus == TaskStatus.pending) {
      if (inst.scheduledDate.isBefore(today)) {
        acc.missedCount++;
        acc.missedHours += effectiveDuration;
        acc.missedTasks.add(inst);
      } else {
        acc.plannedCount++;
        acc.plannedHours += effectiveDuration;
        acc.plannedTasks.add(inst);
      }
    }
  }

  return {for (final d in days) d: accByDay[d]!.toDailyStatsData()};
});

final familyLastWeekStatsProvider = Provider<FamilyLastWeekStats?>((ref) {
  final profileVal = ref.watch(familyProfileStreamProvider);
  final familyProfile = profileVal.value;
  if (familyProfile == null || familyProfile.familyId.isEmpty) {
    return null;
  }

  final familyVal = ref.watch(familyStreamProvider(familyProfile.familyId));
  final family = familyVal.value;
  if (family == null) {
    return null;
  }

  final instances = ref.watch(taskInstancesProvider).value ?? [];
  final schedules = ref.watch(taskSchedulesProvider).value ?? [];

  final today = CivilDay.fromDateTime(AppClock.now);
  final startDay = today.addDays(-6);
  final endDay = today.addDays(6);

  final durationMap = <String, double>{
    for (final s in schedules)
      if (s.estimatedDuration != null)
        s.id: s.estimatedDuration!.inMinutes / 60.0,
  };

  final scheduleMap = <String, TaskSchedule>{
    for (final s in schedules) s.id: s,
  };

  final days = List.generate(13, (index) => startDay.addDays(index));
  final accByDay = <CivilDay, _DailyStatsAccumulator>{
    for (final d in days) d: _DailyStatsAccumulator(d),
  };

  final memberCompletedCount = <String, int>{};
  final memberCompletedHours = <String, double>{};
  final memberSkippedCount = <String, int>{};
  final memberMissedCount = <String, int>{};
  final memberCompletedTasks = <String, List<TaskInstance>>{};

  for (final m in family.members.values) {
    memberCompletedCount[m.userId] = 0;
    memberCompletedHours[m.userId] = 0.0;
    memberSkippedCount[m.userId] = 0;
    memberMissedCount[m.userId] = 0;
    memberCompletedTasks[m.userId] = [];
  }

  int totalCompleted = 0;
  double totalHours = 0.0;
  int totalSkipped = 0;
  int totalMissed = 0;
  int totalPlanned = 0;
  double totalPlannedHrs = 0.0;

  final int totalFamilyMembers = family.members.isNotEmpty
      ? family.members.length
      : 1;

  for (final inst in instances) {
    // Only strictly family tasks are included in the family breakdown
    if (!inst.isFamily) continue;

    final schedule = scheduleMap[inst.scheduleId];
    final rule = schedule?.schedules
        .where((r) => r.id == inst.ruleId)
        .firstOrNull;
    final bool isOneOff =
        rule is OneOffSchedule ||
        (rule == null &&
            schedule != null &&
            schedule.schedules.isNotEmpty &&
            schedule.schedules.every((r) => r is OneOffSchedule));

    final CivilDay accountedDay =
        (isOneOff &&
            inst.status == TaskStatus.completed &&
            inst.completedAt != null)
        ? CivilDay.fromDateTime(inst.completedAt!)
        : inst.scheduledDate;

    final acc = accByDay[accountedDay];
    if (acc == null) {
      continue;
    }

    final double baseDuration = durationMap[inst.scheduleId] ?? 0.0;

    if (inst.familyCompletionMode == FamilyCompletionMode.individual) {
      final completedUserIds = inst.completedByUserIds;
      final remainingCount = (totalFamilyMembers - completedUserIds.length)
          .clamp(0, totalFamilyMembers);

      for (final m in family.members.values) {
        if (completedUserIds.contains(m.userId)) {
          memberCompletedCount[m.userId] =
              (memberCompletedCount[m.userId] ?? 0) + 1;
          memberCompletedHours[m.userId] =
              (memberCompletedHours[m.userId] ?? 0.0) + baseDuration;
          memberCompletedTasks[m.userId]?.add(inst);
        } else if (inst.status == TaskStatus.failed ||
            (inst.status == TaskStatus.pending &&
                inst.scheduledDate.isBefore(today))) {
          memberMissedCount[m.userId] = (memberMissedCount[m.userId] ?? 0) + 1;
        } else if (inst.status == TaskStatus.skipped) {
          memberSkippedCount[m.userId] =
              (memberSkippedCount[m.userId] ?? 0) + 1;
        }
      }

      if (inst.status == TaskStatus.completed) {
        totalCompleted++;
        final taskCompletedHours = baseDuration * totalFamilyMembers;
        totalHours += taskCompletedHours;
        acc.completedCount++;
        acc.completedHours += taskCompletedHours;
        acc.completedTasks.add(inst);

        if (inst.isCompletedOverdue) {
          if (inst.isCompletedOverdueByMoreThan24Hours) {
            acc.completedSeriouslyOverdueHours += taskCompletedHours;
          } else {
            acc.completedOverdueHours += taskCompletedHours;
          }
        } else {
          acc.completedOnTimeHours += taskCompletedHours;
        }
      } else if (inst.status == TaskStatus.skipped) {
        totalSkipped++;
        final taskSkippedHours = baseDuration * totalFamilyMembers;
        acc.skippedCount++;
        acc.skippedHours += taskSkippedHours;
        acc.skippedTasks.add(inst);
      } else if (inst.status == TaskStatus.failed) {
        totalMissed++;
        final taskMissedHours = baseDuration * totalFamilyMembers;
        acc.missedCount++;
        acc.missedHours += taskMissedHours;
        acc.missedTasks.add(inst);
      } else if (inst.status == TaskStatus.pending) {
        if (inst.scheduledDate.isBefore(today)) {
          totalMissed++;
          final missedHours =
              baseDuration *
              (inst.completedByUserIds.isEmpty
                  ? totalFamilyMembers
                  : remainingCount);
          acc.missedCount++;
          acc.missedHours += missedHours;
          acc.missedTasks.add(inst);
        } else {
          final neededMembers = inst.completedByUserIds.isEmpty
              ? totalFamilyMembers
              : remainingCount;
          if (neededMembers > 0) {
            final plannedHrs = baseDuration * neededMembers;
            totalPlanned++;
            totalPlannedHrs += plannedHrs;
            acc.plannedCount++;
            acc.plannedHours += plannedHrs;
            acc.plannedTasks.add(inst);
          }
        }
      }
    } else {
      if (inst.status == TaskStatus.completed) {
        totalCompleted++;
        totalHours += baseDuration;
        acc.completedCount++;
        acc.completedHours += baseDuration;
        acc.completedTasks.add(inst);

        if (inst.isCompletedOverdue) {
          if (inst.isCompletedOverdueByMoreThan24Hours) {
            acc.completedSeriouslyOverdueHours += baseDuration;
          } else {
            acc.completedOverdueHours += baseDuration;
          }
        } else {
          acc.completedOnTimeHours += baseDuration;
        }

        final userId = inst.completedByUserId ?? inst.assignedUserId;
        if (userId != null && memberCompletedCount.containsKey(userId)) {
          memberCompletedCount[userId] =
              (memberCompletedCount[userId] ?? 0) + 1;
          memberCompletedHours[userId] =
              (memberCompletedHours[userId] ?? 0.0) + baseDuration;
          memberCompletedTasks[userId]?.add(inst);
        }
      } else if (inst.status == TaskStatus.skipped) {
        totalSkipped++;
        acc.skippedCount++;
        acc.skippedHours += baseDuration;
        acc.skippedTasks.add(inst);

        final userId = inst.completedByUserId ?? inst.assignedUserId;
        if (userId != null && memberSkippedCount.containsKey(userId)) {
          memberSkippedCount[userId] = (memberSkippedCount[userId] ?? 0) + 1;
        }
      } else if (inst.status == TaskStatus.failed) {
        totalMissed++;
        acc.missedCount++;
        acc.missedHours += baseDuration;
        acc.missedTasks.add(inst);

        final userId = inst.assignedUserId;
        if (userId != null && memberMissedCount.containsKey(userId)) {
          memberMissedCount[userId] = (memberMissedCount[userId] ?? 0) + 1;
        }
      } else if (inst.status == TaskStatus.pending) {
        if (inst.scheduledDate.isBefore(today)) {
          totalMissed++;
          acc.missedCount++;
          acc.missedHours += baseDuration;
          acc.missedTasks.add(inst);

          final userId = inst.assignedUserId;
          if (userId != null && memberMissedCount.containsKey(userId)) {
            memberMissedCount[userId] = (memberMissedCount[userId] ?? 0) + 1;
          }
        } else {
          totalPlanned++;
          totalPlannedHrs += baseDuration;
          acc.plannedCount++;
          acc.plannedHours += baseDuration;
          acc.plannedTasks.add(inst);
        }
      }
    }
  }

  final totalActionable = totalCompleted + totalSkipped + totalMissed;
  final completionRate = totalActionable > 0
      ? (totalCompleted / totalActionable)
      : 0.0;

  final sumMemberHours = memberCompletedHours.values.fold(0.0, (a, b) => a + b);
  final sumMemberCompleted = memberCompletedCount.values.fold(
    0,
    (a, b) => a + b,
  );

  final memberStatsList = family.members.values.map((member) {
    final done = memberCompletedCount[member.userId] ?? 0;
    final hrs = memberCompletedHours[member.userId] ?? 0.0;
    final skipped = memberSkippedCount[member.userId] ?? 0;
    final missed = memberMissedCount[member.userId] ?? 0;
    final tasks = memberCompletedTasks[member.userId] ?? [];
    final contribution = sumMemberHours > 0
        ? (hrs / sumMemberHours)
        : (sumMemberCompleted > 0 ? (done / sumMemberCompleted) : 0.0);

    return FamilyMemberStats(
      userId: member.userId,
      displayName: member.displayName.isNotEmpty
          ? member.displayName
          : (member.email.isNotEmpty ? member.email : 'Family Member'),
      email: member.email,
      role: member.role,
      completedCount: done,
      completedHours: hrs,
      skippedCount: skipped,
      missedCount: missed,
      contributionPercentage: contribution,
      completedTasks: tasks,
    );
  }).toList();

  // Sort member stats: highest completed hours first, then completed count, then name
  memberStatsList.sort((a, b) {
    final cmpHrs = b.completedHours.compareTo(a.completedHours);
    if (cmpHrs != 0) return cmpHrs;
    final cmpCount = b.completedCount.compareTo(a.completedCount);
    if (cmpCount != 0) return cmpCount;
    return a.displayName.compareTo(b.displayName);
  });

  final dailyStats = days.map((d) => accByDay[d]!.toDailyStatsData()).toList();

  return FamilyLastWeekStats(
    familyId: family.id,
    familyName: family.name,
    totalCompletedCount: totalCompleted,
    totalCompletedHours: totalHours,
    totalSkippedCount: totalSkipped,
    totalMissedCount: totalMissed,
    totalPlannedCount: totalPlanned,
    totalPlannedHours: totalPlannedHrs,
    completionRate: completionRate,
    memberStats: memberStatsList,
    dailyStats: dailyStats,
    startDay: startDay,
    endDay: endDay,
  );
});
