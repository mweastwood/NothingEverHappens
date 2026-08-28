import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_clock.dart';
import '../auth_repository.dart';
import '../task_instance.dart';
import '../task_repository.dart';
import '../user_settings.dart';
import '../user_settings_repository.dart';
import 'system_task.dart';

String getSystemTaskWeekIdentifier(DateTime date) {
  final monday = date.subtract(Duration(days: date.weekday - 1));
  return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
}

final missedFamilyTasksProvider = Provider<List<SystemTask>>((ref) {
  final settingsVal = ref.watch(userSettingsProvider);
  if (settingsVal.isLoading || settingsVal.hasError) {
    return const [];
  }
  final settings = settingsVal.value ?? const UserSettings(hoursAvailable: 8.0);

  final authUser = ref.watch(authStateProvider).value;
  final currentUserId = authUser?.uid;
  if (currentUserId == null || currentUserId.isEmpty) {
    return const [];
  }

  final instancesVal = ref.watch(taskInstancesProvider);
  if (instancesVal.isLoading || instancesVal.hasError) {
    return const [];
  }
  final instances = instancesVal.value ?? const [];

  final now = AppClock.now;
  final cutoff5amToday = DateTime(now.year, now.month, now.day, 5, 0);

  if (now.isBefore(cutoff5amToday)) {
    return const [];
  }

  final todayStr =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final acknowledgedList =
      settings.acknowledgedMissedTaskCommunications ?? const [];

  final tasks = <SystemTask>[];

  for (final instance in instances) {
    if (!instance.isFamily) continue;
    if (instance.assignedUserId != currentUserId) continue;
    if (instance.status != TaskStatus.pending ||
        instance.isCompletedForUser(currentUserId)) {
      continue;
    }

    final dueDateTime = instance.dueRelativeTime.referenceTo(
      instance.scheduledDate,
    );
    if (!dueDateTime.isBefore(cutoff5amToday)) {
      continue;
    }

    final ackKey = '${instance.id}:$todayStr';
    if (acknowledgedList.contains(ackKey)) {
      continue;
    }

    void handleAcknowledge() {
      final currentAcks =
          settings.acknowledgedMissedTaskCommunications ?? const [];
      if (!currentAcks.contains(ackKey)) {
        final updatedAcks = [...currentAcks, ackKey];
        final updatedSettings = settings.copyWith(
          acknowledgedMissedTaskCommunications: updatedAcks,
        );
        ref
            .read(userSettingsRepositoryProvider)
            ?.updateSettings(updatedSettings);
      }
    }

    tasks.add(
      SystemTask(
        id: 'missed_family_task_comm_${instance.id}_$todayStr',
        title: 'Communicate missed chore: ${instance.title}',
        description:
            'This family task was missed before 5:00 AM. Reach out to your family and own responsibility for the missed task by 5:00 PM today.',
        icon: Icons.record_voice_over,
        priority: SystemTaskPriority.high,
        category: SystemTaskCategory.family,
        actionLabel: 'Mark Communicated',
        isDismissible: true,
        onAction: handleAcknowledge,
        onDismiss: handleAcknowledge,
      ),
    );
  }

  return tasks;
});

final activeSystemTasksProvider = Provider<List<SystemTask>>((ref) {
  final settingsVal = ref.watch(userSettingsProvider);
  if (settingsVal.isLoading || settingsVal.hasError) {
    return const [];
  }
  final settings = settingsVal.value ?? const UserSettings(hoursAvailable: 8.0);
  final tasks = <SystemTask>[];

  final currentWeekId = getSystemTaskWeekIdentifier(AppClock.now);
  final isCapacityConfirmed =
      settings.lastCapacityConfirmedWeek == currentWeekId;

  if (!isCapacityConfirmed) {
    tasks.add(
      SystemTask(
        id: 'verify_weekly_capacity',
        title: 'Confirm capacity for this week',
        description:
            'Review and confirm your available chore hours to clear this task.',
        icon: Icons.assignment_turned_in,
        priority: SystemTaskPriority.high,
        category: SystemTaskCategory.capacity,
        actionLabel: 'Confirm Capacity',
        onAction: () {
          ref
              .read(userSettingsRepositoryProvider)
              ?.updateSettings(
                settings.copyWith(lastCapacityConfirmedWeek: currentWeekId),
              );
        },
      ),
    );
  }

  final missedFamilyTasks = ref.watch(missedFamilyTasksProvider);
  tasks.addAll(missedFamilyTasks);

  return tasks;
});
