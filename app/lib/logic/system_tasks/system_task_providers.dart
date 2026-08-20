import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_clock.dart';
import '../user_settings.dart';
import '../user_settings_repository.dart';
import 'system_task.dart';

String getSystemTaskWeekIdentifier(DateTime date) {
  final monday = date.subtract(Duration(days: date.weekday - 1));
  return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
}

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
      const SystemTask(
        id: 'verify_weekly_capacity',
        title: 'Confirm capacity for this week',
        description:
            'Review and confirm your available chore hours to clear this task.',
        icon: Icons.assignment_turned_in,
        priority: SystemTaskPriority.high,
        category: SystemTaskCategory.capacity,
        actionLabel: 'Confirm Capacity',
      ),
    );
  }

  return tasks;
});
