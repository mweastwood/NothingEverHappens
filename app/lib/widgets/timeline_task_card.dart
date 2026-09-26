import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/calendar_day_task.dart';
import '../logic/civil_day.dart';
import '../logic/l10n_extension.dart';
import '../logic/task_repository.dart';
import 'app_snackbar.dart';
import 'calendar_month_card.dart';
import 'calendar_task_details_sheet.dart';

/// Interactive card widget displaying a task on the daily timeline.
class TimelineTaskCard extends ConsumerWidget {
  final CivilDay day;
  final CalendarDayTask task;
  final double cardHeight;
  final double cardWidth;

  const TimelineTaskCard({
    super.key,
    required this.day,
    required this.task,
    required this.cardHeight,
    required this.cardWidth,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final priorityColor = getPriorityColor(theme.colorScheme, task.priority);
    final timeWindow = task.getTimeWindow(context);

    return Card(
      key: Key('timeline_task_${task.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 1.0, vertical: 1.0),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: priorityColor.withValues(alpha: 0.5), width: 1),
      ),
      color: task.isCompleted
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
          : priorityColor.withValues(alpha: 0.12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            CalendarTaskDetailsSheet.show(context, task: task, day: day),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left priority stripe
            Container(width: 4, color: priorityColor),
            const SizedBox(width: 4),

            // Checkbox / Repeat Icon
            if (cardWidth >= 50) ...[
              Center(
                child: task.isInstance
                    ? IconButton(
                        style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: const Size(18, 18),
                          padding: EdgeInsets.zero,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          maxWidth: 24,
                          minHeight: 18,
                          maxHeight: 24,
                        ),
                        icon: Icon(
                          task.isCompleted
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 15,
                          color: task.isCompleted
                              ? theme.colorScheme.primary
                              : priorityColor,
                        ),
                        onPressed: () async {
                          final repo = ref.read(taskRepositoryProvider);
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
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Icon(
                          Icons.event_repeat,
                          size: 14,
                          color: priorityColor,
                        ),
                      ),
              ),
              const SizedBox(width: 2),
            ],

            // Title and Time info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 2, right: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: cardHeight < 30
                            ? 9.5
                            : (cardWidth < 80 ? 10 : 11),
                        fontWeight: FontWeight.bold,
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: task.isCompleted
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    if (timeWindow != null && cardHeight >= 42) ...[
                      const SizedBox(height: 1),
                      Text(
                        timeWindow,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
