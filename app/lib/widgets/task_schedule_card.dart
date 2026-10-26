import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/family_repository.dart';
import '../logic/label_repository.dart';
import '../logic/task_label.dart';
import '../logic/l10n_extension.dart';
import '../logic/task_repository.dart';
import '../logic/task_schedule.dart';
import '../logic/undo_notifier.dart';
import '../logic/user_settings_repository.dart';
import '../screens/create_task_screen.dart';
import 'markdown_styles.dart';
import 'task_badges.dart';
import 'task_hero_stripe.dart';
import 'task_schedule_rule_row.dart';
import 'undo_snackbar.dart';

class TaskScheduleCard extends ConsumerWidget {
  final TaskSchedule task;
  final bool? isParent;
  final bool? showLastSpawnedDate;
  final TaskRepository? repository;
  final VoidCallback? onEdit;
  final VoidCallback? onCopy;
  final VoidCallback? onDelete;
  final List<TaskLabel>? labels;

  const TaskScheduleCard({
    super.key,
    required this.task,
    this.isParent,
    this.showLastSpawnedDate,
    this.repository,
    this.onEdit,
    this.onCopy,
    this.onDelete,
    this.labels,
  });

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

  List<TaskLabel> _resolveLabels(WidgetRef ref) {
    if (labels != null) {
      return labels!;
    }
    if (task.labelIds.isEmpty) return const [];
    final labelsMap = ref.watch(allLabelsMapProvider);
    return task.labelIds
        .map((id) => labelsMap[id])
        .whereType<TaskLabel>()
        .toList();
  }

  List<Widget> _buildLabelBadges(BuildContext context, List<TaskLabel> labels) {
    if (labels.isEmpty) return const <Widget>[];
    return labels
        .map(
          (label) => TaskBadge(
            icon: LabelIcons.getIcon(label.iconKey),
            label: label.name,
            color: LabelPalette.getColor(label.colorKey, context),
            fontSize: 11,
          ),
        )
        .toList();
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TaskRepository repository,
    TaskSchedule task,
  ) {
    final effectiveIsParent =
        isParent ??
        (ref.read(familyProfileStreamProvider).value?.familyRole == 'parent');
    if (task.isFamily && !effectiveIsParent) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.deleteTaskConfirmTitle),
          content: Text(context.l10n.deleteTaskConfirmBody(task.title)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.cancelButton),
            ),
            FilledButton(
              key: Key('confirm_delete_schedule_button_${task.id}'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                final deletedData = await repository.deleteTaskSchedule(
                  task.id,
                );
                if (deletedData != null && context.mounted) {
                  UndoSnackBar.show(
                    context: context,
                    ref: ref,
                    action: UndoDeleteTaskScheduleAction(
                      message: context.l10n.scheduleDeleted(task.title),
                      schedule: deletedData.task,
                      pendingInstances: deletedData.pendingInstances,
                    ),
                    repository: repository,
                    undoneLabel: context.l10n.taskRestored(task.title),
                  );
                }
              },
              child: Text(context.l10n.deleteButton),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveIsParent =
        isParent ??
        (ref.watch(familyProfileStreamProvider).value?.familyRole == 'parent');
    final effectiveShowLastSpawnedDate =
        showLastSpawnedDate ??
        (ref.watch(userSettingsProvider).value?.showLastSpawnedDate ?? false);
    final effectiveRepository = repository ?? ref.watch(taskRepositoryProvider);
    final theme = Theme.of(context);
    final canDelete = !task.isFamily || effectiveIsParent;
    final resolvedLabels = _resolveLabels(ref);
    final labelColors = resolvedLabels
        .map((l) => LabelPalette.getColor(l.colorKey, context))
        .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
        elevation: 2.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Card Header with Title, priority, actions (high density)
                Padding(
                  padding: const EdgeInsets.only(
                    left: 12.0,
                    right: 4.0,
                    top: 8.0,
                    bottom: 0.0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        key: Key('copy_schedule_button_${task.id}'),
                        icon: const Icon(Icons.copy_outlined, size: 20),
                        visualDensity: VisualDensity.compact,
                        tooltip: context.l10n.copyScheduleTooltip,
                        onPressed:
                            onCopy ??
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      CreateTaskScreen(taskToDuplicate: task),
                                ),
                              );
                            },
                      ),
                      IconButton(
                        key: Key('edit_schedule_button_${task.id}'),
                        icon: const Icon(
                          Icons.edit_calendar_outlined,
                          size: 20,
                        ),
                        visualDensity: VisualDensity.compact,
                        tooltip: context.l10n.editScheduleTooltip,
                        onPressed:
                            onEdit ??
                            () {
                              SystemNavigator.routeInformationUpdated(
                                uri: Uri.parse('/edit/${task.id}'),
                              );
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      CreateTaskScreen(taskToEdit: task),
                                ),
                              ).then((_) {
                                SystemNavigator.routeInformationUpdated(
                                  uri: Uri.parse('/schedules'),
                                );
                              });
                            },
                      ),
                      if (canDelete)
                        IconButton(
                          key: Key('delete_schedule_button_${task.id}'),
                          icon: Icon(
                            Icons.delete_outline,
                            color: theme.colorScheme.error,
                            size: 20,
                          ),
                          visualDensity: VisualDensity.compact,
                          tooltip: context.l10n.deleteTaskTooltip,
                          onPressed:
                              onDelete ??
                              () {
                                if (effectiveRepository != null) {
                                  _confirmDelete(
                                    context,
                                    ref,
                                    effectiveRepository,
                                    task,
                                  );
                                }
                              },
                        ),
                    ],
                  ),
                ),
                if (task.isFamily || resolvedLabels.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 12.0,
                      right: 12.0,
                      bottom: 8.0,
                    ),
                    child: Wrap(
                      spacing: 6.0,
                      runSpacing: 6.0,
                      children: [
                        if (task.isFamily)
                          TaskBadge(
                            icon: Icons.people_alt,
                            label: context.l10n.familyTab,
                            color: theme.colorScheme.primary,
                            fontSize: 11,
                          ),
                        if (task.isFamily &&
                            task.familyCompletionMode ==
                                FamilyCompletionMode.individual)
                          TaskBadge(
                            icon: Icons.checklist,
                            label: context.l10n.completionModeIndividualLabel,
                            color: theme.colorScheme.primary,
                            fontSize: 11,
                          ),
                        if (task.isFamily && task.assignedUserId != null)
                          TaskAssigneeBadge(
                            userId: task.assignedUserId!,
                            fontSize: 11,
                          ),
                        ..._buildLabelBadges(context, resolvedLabels),
                      ],
                    ),
                  ),
                if (task.description.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 12.0,
                      right: 12.0,
                      bottom: 8.0,
                    ),
                    child: MarkdownBody(
                      data: task.description,
                      selectable: false,
                      styleSheet: MarkdownStyles.taskDescription(
                        context,
                        textStyle: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (task.estimatedDuration != null)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 12.0,
                      right: 12.0,
                      bottom: 8.0,
                    ),
                    child: Text(
                      context.l10n.estimatedEffortLabel(
                        _formatDuration(task.estimatedDuration!),
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                  ),
                if (effectiveShowLastSpawnedDate)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 12.0,
                      right: 12.0,
                      bottom: 8.0,
                    ),
                    child: Text(
                      'lastSpawnedDate: ${task.lastSpawnedDate?.toString() ?? "null"}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11.0,
                        height: 1.2,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ),
                const Divider(height: 1, thickness: 0.5),
                // Rule list inside task card (high density)
                for (int idx = 0; idx < task.schedules.length; idx++) ...[
                  if (idx > 0)
                    const Divider(height: 1, indent: 12, endIndent: 12),
                  TaskScheduleRuleRow(rule: task.schedules[idx]),
                ],
              ],
            ),
            if (labelColors.isNotEmpty)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: TaskHeroStripe(colors: labelColors),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
