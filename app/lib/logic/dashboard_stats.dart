import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_clock.dart';
import 'auth_repository.dart';
import 'civil_day.dart';
import 'family.dart';
import 'family_repository.dart';
import 'task_instance.dart';
import 'task_repository.dart';

class DailyStatsData {
  final CivilDay day;
  final int completedCount;
  final int skippedCount;
  final int missedCount;
  final double completedHours;
  final double completedOnTimeHours;
  final double completedOverdueHours;
  final double skippedHours;
  final double missedHours;
  final List<TaskInstance> completedTasks;
  final List<TaskInstance> skippedTasks;
  final List<TaskInstance> missedTasks;

  const DailyStatsData({
    required this.day,
    required this.completedCount,
    required this.skippedCount,
    required this.missedCount,
    required this.completedHours,
    this.completedOnTimeHours = 0.0,
    this.completedOverdueHours = 0.0,
    this.skippedHours = 0.0,
    this.missedHours = 0.0,
    this.completedTasks = const [],
    this.skippedTasks = const [],
    this.missedTasks = const [],
  });
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
  });
}

class FamilyLastWeekStats {
  final String familyId;
  final String familyName;
  final int totalCompletedCount;
  final double totalCompletedHours;
  final int totalSkippedCount;
  final int totalMissedCount;
  final double completionRate;
  final List<FamilyMemberStats> memberStats;
  final CivilDay startDay;
  final CivilDay endDay;

  const FamilyLastWeekStats({
    required this.familyId,
    required this.familyName,
    required this.totalCompletedCount,
    required this.totalCompletedHours,
    required this.totalSkippedCount,
    required this.totalMissedCount,
    required this.completionRate,
    required this.memberStats,
    required this.startDay,
    required this.endDay,
  });

  bool get hasActivity =>
      totalCompletedCount > 0 || totalSkippedCount > 0 || totalMissedCount > 0;
}

final personalLastWeekStatsProvider = Provider<PersonalLastWeekStats>((ref) {
  final instances = ref.watch(taskInstancesProvider).valueOrNull ?? [];
  final schedules = ref.watch(taskSchedulesProvider).valueOrNull ?? [];
  final currentUserId = ref.watch(authStateProvider).valueOrNull?.uid;

  final today = CivilDay.fromDateTime(AppClock.now);
  final startDay = today.addDays(-6);
  final endDay = today;

  final durationMap = <String, double>{
    for (final s in schedules)
      if (s.estimatedDuration != null)
        s.id: s.estimatedDuration!.inMinutes / 60.0,
  };

  final days = List.generate(7, (index) => startDay.addDays(index));
  final dailyCompleted = <CivilDay, int>{for (final d in days) d: 0};
  final dailySkipped = <CivilDay, int>{for (final d in days) d: 0};
  final dailyMissed = <CivilDay, int>{for (final d in days) d: 0};
  final dailyHours = <CivilDay, double>{for (final d in days) d: 0.0};
  final dailyCompletedOnTimeHours = <CivilDay, double>{
    for (final d in days) d: 0.0,
  };
  final dailyCompletedOverdueHours = <CivilDay, double>{
    for (final d in days) d: 0.0,
  };
  final dailySkippedHours = <CivilDay, double>{for (final d in days) d: 0.0};
  final dailyMissedHours = <CivilDay, double>{for (final d in days) d: 0.0};
  final dailyCompletedTasks = <CivilDay, List<TaskInstance>>{
    for (final d in days) d: [],
  };
  final dailySkippedTasks = <CivilDay, List<TaskInstance>>{
    for (final d in days) d: [],
  };
  final dailyMissedTasks = <CivilDay, List<TaskInstance>>{
    for (final d in days) d: [],
  };

  int totalCompleted = 0;
  double totalHours = 0.0;
  int totalSkipped = 0;
  int totalMissed = 0;

  for (final inst in instances) {
    final schedDay = inst.scheduledDate;
    if (schedDay.isBefore(startDay) || schedDay.isAfter(endDay)) {
      continue;
    }

    final bool isUserTask;
    if (inst.isFamily) {
      if (inst.status == TaskStatus.completed ||
          inst.status == TaskStatus.skipped) {
        isUserTask = inst.completedByUserId == currentUserId;
      } else {
        isUserTask = inst.assignedUserId == currentUserId;
      }
    } else {
      if (inst.status == TaskStatus.completed ||
          inst.status == TaskStatus.skipped) {
        isUserTask =
            inst.completedByUserId == currentUserId ||
            (inst.completedByUserId == null &&
                (inst.assignedUserId == null ||
                    inst.assignedUserId == currentUserId));
      } else {
        isUserTask =
            inst.assignedUserId == null || inst.assignedUserId == currentUserId;
      }
    }

    if (!isUserTask) continue;

    final duration = durationMap[inst.scheduleId] ?? 0.0;

    if (inst.status == TaskStatus.completed) {
      totalCompleted++;
      totalHours += duration;
      dailyCompleted[schedDay] = (dailyCompleted[schedDay] ?? 0) + 1;
      dailyHours[schedDay] = (dailyHours[schedDay] ?? 0.0) + duration;
      dailyCompletedTasks[schedDay]?.add(inst);

      final dueDateTime = inst.dueRelativeTime.referenceTo(inst.scheduledDate);
      final isOverdue =
          inst.completedAt != null && inst.completedAt!.isAfter(dueDateTime);
      if (isOverdue) {
        dailyCompletedOverdueHours[schedDay] =
            (dailyCompletedOverdueHours[schedDay] ?? 0.0) + duration;
      } else {
        dailyCompletedOnTimeHours[schedDay] =
            (dailyCompletedOnTimeHours[schedDay] ?? 0.0) + duration;
      }
    } else if (inst.status == TaskStatus.skipped) {
      totalSkipped++;
      dailySkipped[schedDay] = (dailySkipped[schedDay] ?? 0) + 1;
      dailySkippedHours[schedDay] =
          (dailySkippedHours[schedDay] ?? 0.0) + duration;
      dailySkippedTasks[schedDay]?.add(inst);
    } else if (inst.status == TaskStatus.failed) {
      totalMissed++;
      dailyMissed[schedDay] = (dailyMissed[schedDay] ?? 0) + 1;
      dailyMissedHours[schedDay] =
          (dailyMissedHours[schedDay] ?? 0.0) + duration;
      dailyMissedTasks[schedDay]?.add(inst);
    } else if (inst.status == TaskStatus.pending && schedDay.isBefore(today)) {
      totalMissed++;
      dailyMissed[schedDay] = (dailyMissed[schedDay] ?? 0) + 1;
      dailyMissedHours[schedDay] =
          (dailyMissedHours[schedDay] ?? 0.0) + duration;
      dailyMissedTasks[schedDay]?.add(inst);
    }
  }

  final totalActionable = totalCompleted + totalSkipped + totalMissed;
  final completionRate = totalActionable > 0
      ? (totalCompleted / totalActionable)
      : 0.0;

  final dailyStats = days.map((d) {
    return DailyStatsData(
      day: d,
      completedCount: dailyCompleted[d] ?? 0,
      skippedCount: dailySkipped[d] ?? 0,
      missedCount: dailyMissed[d] ?? 0,
      completedHours: dailyHours[d] ?? 0.0,
      completedOnTimeHours: dailyCompletedOnTimeHours[d] ?? 0.0,
      completedOverdueHours: dailyCompletedOverdueHours[d] ?? 0.0,
      skippedHours: dailySkippedHours[d] ?? 0.0,
      missedHours: dailyMissedHours[d] ?? 0.0,
      completedTasks: dailyCompletedTasks[d] ?? const [],
      skippedTasks: dailySkippedTasks[d] ?? const [],
      missedTasks: dailyMissedTasks[d] ?? const [],
    );
  }).toList();

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

final familyLastWeekStatsProvider = Provider<FamilyLastWeekStats?>((ref) {
  final profileVal = ref.watch(familyProfileStreamProvider);
  final familyProfile = profileVal.valueOrNull;
  if (familyProfile == null || familyProfile.familyId.isEmpty) {
    return null;
  }

  final familyVal = ref.watch(familyStreamProvider(familyProfile.familyId));
  final family = familyVal.valueOrNull;
  if (family == null) {
    return null;
  }

  final instances = ref.watch(taskInstancesProvider).valueOrNull ?? [];
  final schedules = ref.watch(taskSchedulesProvider).valueOrNull ?? [];

  final today = CivilDay.fromDateTime(AppClock.now);
  final startDay = today.addDays(-6);
  final endDay = today;

  final durationMap = <String, double>{
    for (final s in schedules)
      if (s.estimatedDuration != null)
        s.id: s.estimatedDuration!.inMinutes / 60.0,
  };

  final memberCompletedCount = <String, int>{};
  final memberCompletedHours = <String, double>{};
  final memberSkippedCount = <String, int>{};
  final memberMissedCount = <String, int>{};

  for (final m in family.members.values) {
    memberCompletedCount[m.userId] = 0;
    memberCompletedHours[m.userId] = 0.0;
    memberSkippedCount[m.userId] = 0;
    memberMissedCount[m.userId] = 0;
  }

  int totalCompleted = 0;
  double totalHours = 0.0;
  int totalSkipped = 0;
  int totalMissed = 0;

  for (final inst in instances) {
    // Only strictly family tasks are included in the family breakdown
    if (!inst.isFamily) continue;

    final schedDay = inst.scheduledDate;
    if (schedDay.isBefore(startDay) || schedDay.isAfter(endDay)) {
      continue;
    }

    final duration = durationMap[inst.scheduleId] ?? 0.0;

    if (inst.status == TaskStatus.completed) {
      totalCompleted++;
      totalHours += duration;
      final userId = inst.completedByUserId ?? inst.assignedUserId;
      if (userId != null && memberCompletedCount.containsKey(userId)) {
        memberCompletedCount[userId] = (memberCompletedCount[userId] ?? 0) + 1;
        memberCompletedHours[userId] =
            (memberCompletedHours[userId] ?? 0.0) + duration;
      }
    } else if (inst.status == TaskStatus.skipped) {
      totalSkipped++;
      final userId = inst.completedByUserId ?? inst.assignedUserId;
      if (userId != null && memberSkippedCount.containsKey(userId)) {
        memberSkippedCount[userId] = (memberSkippedCount[userId] ?? 0) + 1;
      }
    } else if (inst.status == TaskStatus.failed) {
      totalMissed++;
      final userId = inst.assignedUserId;
      if (userId != null && memberMissedCount.containsKey(userId)) {
        memberMissedCount[userId] = (memberMissedCount[userId] ?? 0) + 1;
      }
    } else if (inst.status == TaskStatus.pending && schedDay.isBefore(today)) {
      totalMissed++;
      final userId = inst.assignedUserId;
      if (userId != null && memberMissedCount.containsKey(userId)) {
        memberMissedCount[userId] = (memberMissedCount[userId] ?? 0) + 1;
      }
    }
  }

  final totalActionable = totalCompleted + totalSkipped + totalMissed;
  final completionRate = totalActionable > 0
      ? (totalCompleted / totalActionable)
      : 0.0;

  final memberStatsList = family.members.values.map((member) {
    final done = memberCompletedCount[member.userId] ?? 0;
    final hrs = memberCompletedHours[member.userId] ?? 0.0;
    final skipped = memberSkippedCount[member.userId] ?? 0;
    final missed = memberMissedCount[member.userId] ?? 0;
    final contribution = totalCompleted > 0 ? (done / totalCompleted) : 0.0;

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
    );
  }).toList();

  // Sort member stats: highest completed count first, then name
  memberStatsList.sort((a, b) {
    final cmp = b.completedCount.compareTo(a.completedCount);
    if (cmp != 0) return cmp;
    return a.displayName.compareTo(b.displayName);
  });

  return FamilyLastWeekStats(
    familyId: family.id,
    familyName: family.name,
    totalCompletedCount: totalCompleted,
    totalCompletedHours: totalHours,
    totalSkippedCount: totalSkipped,
    totalMissedCount: totalMissed,
    completionRate: completionRate,
    memberStats: memberStatsList,
    startDay: startDay,
    endDay: endDay,
  );
});
