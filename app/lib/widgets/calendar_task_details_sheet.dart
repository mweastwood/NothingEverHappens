import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../logic/auth_repository.dart';
import '../logic/calendar_day_task.dart';
import '../logic/civil_day.dart';
import '../logic/l10n_extension.dart';
import '../logic/task_instance.dart';
import '../logic/task_repository.dart';
import '../logic/task_schedule.dart';
import '../screens/create_task_screen.dart';
import 'app_snackbar.dart';
import 'calendar_month_card.dart';

/// Modal bottom sheet displaying detailed information and actions for a single task.
class CalendarTaskDetailsSheet extends ConsumerWidget {
  final CalendarDayTask task;
  final CivilDay day;

  const CalendarTaskDetailsSheet({
    super.key,
    required this.task,
    required this.day,
  });

  /// Presents the [CalendarTaskDetailsSheet] inside a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required CalendarDayTask task,
    required CivilDay day,
  }) {
    final container = ProviderScope.containerOf(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return UncontrolledProviderScope(
          container: container,
          child: CalendarTaskDetailsSheet(task: task, day: day),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes <= 0) return '';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours > 0) {
      final hourStr = hours == 1 ? '1 hr' : '$hours hrs';
      final minStr = remainingMinutes > 0 ? '$remainingMinutes min' : '';
      return minStr.isEmpty ? hourStr : '$hourStr $minStr';
    } else {
      return '$minutes min';
    }
  }

  String _getPriorityLabel(BuildContext context, TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return context.l10n.priorityHigh;
      case TaskPriority.medium:
        return context.l10n.priorityMedium;
      case TaskPriority.low:
        return context.l10n.priorityLow;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final formattedDate = DateFormat.yMMMMEEEEd(
      locale,
    ).format(day.toDateTime());

    final instances = ref.watch(taskInstancesProvider).value ?? [];
    final schedules = ref.watch(taskSchedulesProvider).value ?? [];
    final currentUserId = ref.watch(authStateProvider).value?.uid;

    final updatedInstance = task.instance != null
        ? instances.cast<TaskInstance?>().firstWhere(
            (inst) => inst?.id == task.instance!.id,
            orElse: () => task.instance,
          )
        : null;

    final scheduleId =
        updatedInstance?.scheduleId ??
        task.instance?.scheduleId ??
        task.schedule?.id;

    final resolvedSchedule = scheduleId != null
        ? schedules.cast<TaskSchedule?>().firstWhere(
            (s) => s?.id == scheduleId,
            orElse: () => task.schedule,
          )
        : task.schedule;

    final bool isCompleted = updatedInstance != null
        ? ((updatedInstance.isFamily && currentUserId != null)
              ? updatedInstance.isCompletedForUser(currentUserId)
              : updatedInstance.status == TaskStatus.completed)
        : task.isCompleted;

    final title = updatedInstance?.title ?? task.title;
    final description = updatedInstance?.description ?? task.description;
    final priority = updatedInstance?.priority ?? task.priority;

    final priorityColor = getPriorityColor(theme.colorScheme, priority);
    final priorityLabel = _getPriorityLabel(context, priority);
    final timeWindow = task.getTimeWindow(context);

    final duration =
        resolvedSchedule?.estimatedDuration ?? task.estimatedDuration;
    final durationStr = duration != null ? _formatDuration(duration) : null;

    final isFamily =
        (updatedInstance?.isFamily ?? task.instance?.isFamily ?? false) ||
        (resolvedSchedule?.isFamily ?? false);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title & Close Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      key: const Key('calendar_task_details_title'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: isCompleted
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Badges: Priority, Status, Family
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Priority Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: priorityColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      priorityLabel.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: priorityColor,
                      ),
                    ),
                  ),

                  // Status Badge
                  if (task.isInstance)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (isCompleted
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.secondary)
                                .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCompleted ? Icons.check_circle : Icons.schedule,
                            size: 14,
                            color: isCompleted
                                ? theme.colorScheme.primary
                                : theme.colorScheme.secondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isCompleted
                                ? context.l10n.completedBadge
                                : context.l10n.pendingBadge,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isCompleted
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiary.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_repeat,
                            size: 14,
                            color: theme.colorScheme.tertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            context.l10n.projectedOccurrence,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.tertiary,
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (isFamily)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people,
                            size: 14,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            context.l10n.familyTab,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Date & Time info
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      formattedDate,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              if (timeWindow != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        timeWindow,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (durationStr != null && durationStr.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.estimatedDurationLabel(durationStr),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // Description section
              if (description.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Text(
                  context.l10n.descriptionFieldLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(description, style: theme.textTheme.bodyMedium),
              ],

              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Completion toggle button (for concrete instances)
              if (task.isInstance && updatedInstance != null) ...[
                FilledButton.tonalIcon(
                  key: const Key(
                    'calendar_task_details_toggle_complete_button',
                  ),
                  icon: Icon(
                    isCompleted ? Icons.replay : Icons.check_circle_outline,
                  ),
                  label: Text(
                    isCompleted
                        ? context.l10n.markAsIncomplete
                        : context.l10n.markAsCompleted,
                  ),
                  onPressed: () async {
                    final repo = ref.read(taskRepositoryProvider);
                    if (repo != null) {
                      try {
                        if (isCompleted) {
                          await repo.uncompleteTaskInstance(updatedInstance.id);
                        } else {
                          await repo.completeTaskInstance(updatedInstance.id);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          AppSnackBar.show(
                            context,
                            content: Text(
                              '${context.l10n.somethingWentWrong} $e',
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
                const SizedBox(height: 8),
              ],

              // Edit Task button (if schedule is available)
              if (resolvedSchedule != null) ...[
                OutlinedButton.icon(
                  key: const Key('calendar_task_details_edit_button'),
                  icon: const Icon(Icons.edit, size: 18),
                  label: Text(context.l10n.editTaskTitle),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            CreateTaskScreen(taskToEdit: resolvedSchedule),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
