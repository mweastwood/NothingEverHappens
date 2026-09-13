import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../logic/auth_repository.dart';
import '../logic/calendar_day_task.dart';
import '../logic/civil_day.dart';
import '../logic/l10n_extension.dart';
import '../logic/task_repository.dart';
import '../screens/create_task_screen.dart';
import 'app_snackbar.dart';
import 'calendar_month_card.dart';

/// Modal bottom sheet displaying tasks and actions for a specific day.
class CalendarDayDetailsSheet extends ConsumerWidget {
  final CivilDay day;

  const CalendarDayDetailsSheet({super.key, required this.day});

  /// Presents the [CalendarDayDetailsSheet] inside a modal bottom sheet.
  static Future<void> show(BuildContext context, {required CivilDay day}) {
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
          child: CalendarDayDetailsSheet(day: day),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dt = day.toDateTime();
    final locale = Localizations.localeOf(context).toString();
    final formattedDate = DateFormat.yMMMMEEEEd(locale).format(dt);

    final instances = ref.watch(taskInstancesProvider).value ?? [];
    final schedules = ref.watch(taskSchedulesProvider).value ?? [];
    final currentUserId = ref.watch(authStateProvider).value?.uid;
    final monthDate = DateTime(day.year, day.month, 1);
    final monthTasks = computeMonthTaskMap(
      monthDate: monthDate,
      instances: instances,
      schedules: schedules,
      currentUserId: currentUserId,
    );
    final tasks = monthTasks[day] ?? const [];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sheet Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.tasksForDate(formattedDate),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tasks.isEmpty
                                ? context.l10n.calendarNoTasks
                                : context.l10n.taskCount(tasks.length),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.add),
                      tooltip: context.l10n.addTaskTooltip,
                      onPressed: () {
                        final navigator = Navigator.of(context);
                        navigator.pop();
                        navigator.push(
                          MaterialPageRoute(
                            builder: (context) => const CreateTaskScreen(
                              defaultToRepeating: false,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Tasks List
              if (tasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(
                    child: Text(
                      context.l10n.calendarNoTasks,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: tasks.length,
                    separatorBuilder: (context, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      final priorityColor = getPriorityColor(
                        theme.colorScheme,
                        task.priority,
                      );
                      final timeWindow = task.getTimeWindow(context);

                      return Card(
                        elevation: 0,
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: priorityColor.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          leading: task.isInstance
                              ? IconButton(
                                  icon: Icon(
                                    task.isCompleted
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color: task.isCompleted
                                        ? theme.colorScheme.primary
                                        : priorityColor,
                                  ),
                                  onPressed: () async {
                                    final repo = ref.read(
                                      taskRepositoryProvider,
                                    );
                                    if (repo != null && task.instance != null) {
                                      try {
                                        if (task.isCompleted) {
                                          await repo.uncompleteTaskInstance(
                                            task.instance!.id,
                                          );
                                        } else {
                                          await repo.completeTaskInstance(
                                            task.instance!.id,
                                          );
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
                                )
                              : Icon(Icons.event_repeat, color: priorityColor),
                          title: Text(
                            task.title,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              decoration: task.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: task.isCompleted
                                  ? theme.colorScheme.onSurface.withValues(
                                      alpha: 0.5,
                                    )
                                  : null,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (timeWindow != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  timeWindow,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              if (task.description.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  task.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: priorityColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              task.priority.name.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: priorityColor,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
