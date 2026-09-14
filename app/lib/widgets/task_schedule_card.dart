import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/family_repository.dart';
import '../logic/label_repository.dart';
import '../logic/task_label.dart';
import '../logic/l10n_extension.dart';
import '../logic/relative_time.dart';
import '../logic/task_repository.dart';
import '../logic/task_schedule.dart';
import '../logic/undo_notifier.dart';
import '../logic/user_profile_provider.dart';
import '../logic/user_settings_repository.dart';
import '../screens/create_task_screen.dart';
import 'markdown_styles.dart';
import 'undo_snackbar.dart';

class TaskScheduleCard extends ConsumerWidget {
  final TaskSchedule task;
  final bool? isParent;
  final bool? showLastSpawnedDate;
  final TaskRepository? repository;
  final VoidCallback? onEdit;
  final VoidCallback? onCopy;
  final VoidCallback? onDelete;

  const TaskScheduleCard({
    super.key,
    required this.task,
    this.isParent,
    this.showLastSpawnedDate,
    this.repository,
    this.onEdit,
    this.onCopy,
    this.onDelete,
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

  Widget _buildBadge(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.4 : 0.25),
          width: 1,
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRecurrenceRuleTypeName(
    BuildContext context,
    TaskScheduleRule? schedule,
  ) {
    if (schedule == null) return '';
    if (schedule is DailySchedule) return context.l10n.dailyLabel;
    if (schedule is WeeklySchedule) return context.l10n.weeklyLabel;
    if (schedule is MonthlySchedule) return context.l10n.monthlyLabel;
    if (schedule is YearlySchedule) return context.l10n.yearlyLabel;
    return context.l10n.oneOffLabel;
  }

  String _formatRelativeTime(BuildContext context, RelativeTime rt) {
    final formattedTime = rt.time.format(context);
    if (rt.dayOffset > 0) {
      return '$formattedTime (+${rt.dayOffset})';
    } else if (rt.dayOffset < 0) {
      return '$formattedTime (${rt.dayOffset})';
    }
    return formattedTime;
  }

  ({String interval, String days, String start}) _getRecurrenceRuleDetails(
    BuildContext context,
    TaskScheduleRule? schedule,
  ) {
    if (schedule == null) return (interval: '', days: '', start: '');

    String intervalStr = '';
    String startStr = '';
    String daysStr = '';

    if (schedule is OneOffSchedule) {
      final dateStr =
          '${schedule.date.year}-${schedule.date.month.toString().padLeft(2, '0')}-${schedule.date.day.toString().padLeft(2, '0')}';
      intervalStr = context.l10n.oneOffLabel;
      startStr = context.l10n.startingDate(dateStr);
    } else if (schedule is DailySchedule) {
      final ds = schedule;
      intervalStr = ds.interval == 1
          ? context.l10n.everyDay
          : context.l10n.everyNDays(ds.interval);
      final dateStr =
          '${ds.startDate.year}-${ds.startDate.month.toString().padLeft(2, '0')}-${ds.startDate.day.toString().padLeft(2, '0')}';
      startStr = context.l10n.startingDate(dateStr);
    } else if (schedule is WeeklySchedule) {
      final ws = schedule;
      intervalStr = ws.interval == 1
          ? context.l10n.everyWeek
          : context.l10n.everyNWeeks(ws.interval);
      final dateStr =
          '${ws.startDate.year}-${ws.startDate.month.toString().padLeft(2, '0')}-${ws.startDate.day.toString().padLeft(2, '0')}';
      startStr = context.l10n.startingDate(dateStr);

      final dayNames = {
        1: context.l10n.weekdayShortMonday,
        2: context.l10n.weekdayShortTuesday,
        3: context.l10n.weekdayShortWednesday,
        4: context.l10n.weekdayShortThursday,
        5: context.l10n.weekdayShortFriday,
        6: context.l10n.weekdayShortSaturday,
        7: context.l10n.weekdayShortSunday,
      };
      final selectedDays = ws.daysOfWeek.toList()..sort();
      final joinedDays = selectedDays.map((d) => dayNames[d] ?? '').join(', ');
      daysStr = context.l10n.onDaysOfWeek(joinedDays);
    } else if (schedule is MonthlySchedule) {
      final ms = schedule;
      intervalStr = ms.interval == 1
          ? context.l10n.everyMonth
          : context.l10n.everyNMonths(ms.interval);
      final dateStr =
          '${ms.startDate.year}-${ms.startDate.month.toString().padLeft(2, '0')}-${ms.startDate.day.toString().padLeft(2, '0')}';
      startStr = context.l10n.startingDate(dateStr);

      if (ms.dayOfMonth != null) {
        if (ms.dayOfMonth! > 0) {
          daysStr = context.l10n.dayOfMonthOnDay(ms.dayOfMonth!);
        } else {
          daysStr = context.l10n.dayOfMonthFromEnd(ms.dayOfMonth!.abs());
        }
      } else {
        final occurrenceNames = {
          1: context.l10n.firstOccurrence,
          2: context.l10n.secondOccurrence,
          3: context.l10n.thirdOccurrence,
          4: context.l10n.fourthOccurrence,
          -1: context.l10n.lastOccurrence,
        };
        final dayOfWeekNames = {
          1: context.l10n.weekdayMonday,
          2: context.l10n.weekdayTuesday,
          3: context.l10n.weekdayWednesday,
          4: context.l10n.weekdayThursday,
          5: context.l10n.weekdayFriday,
          6: context.l10n.weekdaySaturday,
          7: context.l10n.weekdaySunday,
        };
        final occStr = occurrenceNames[ms.occurrence] ?? '';
        final dowStr = dayOfWeekNames[ms.dayOfWeek] ?? '';
        daysStr = context.l10n.nthDayOfWeekOccurrence(occStr, dowStr);
      }
    } else if (schedule is YearlySchedule) {
      final ys = schedule;
      intervalStr = ys.interval == 1
          ? context.l10n.everyYear
          : context.l10n.everyNYears(ys.interval);
      final dateStr =
          '${ys.startDate.year}-${ys.startDate.month.toString().padLeft(2, '0')}-${ys.startDate.day.toString().padLeft(2, '0')}';
      startStr = context.l10n.startingDate(dateStr);

      final monthNames = {
        1: context.l10n.monthJanuary,
        2: context.l10n.monthFebruary,
        3: context.l10n.monthMarch,
        4: context.l10n.monthApril,
        5: context.l10n.monthMay,
        6: context.l10n.monthJune,
        7: context.l10n.monthJuly,
        8: context.l10n.monthAugust,
        9: context.l10n.monthSeptember,
        10: context.l10n.monthOctober,
        11: context.l10n.monthNovember,
        12: context.l10n.monthDecember,
      };
      final mStr = monthNames[ys.month] ?? '';
      daysStr = context.l10n.yearlyOn(mStr, ys.day);
    }

    return (interval: intervalStr, days: daysStr, start: startStr);
  }

  String _getMissedPolicyString(BuildContext context, TaskScheduleRule rule) {
    if (rule is OneOffSchedule) return '';
    final policy = rule.missedOccurrencePolicy;
    switch (policy.policy) {
      case MissedPolicy.preferNewer:
        return context.l10n.preferNewerTitle;
      case MissedPolicy.preferOlder:
        return context.l10n.preferOlderTitle;
      case MissedPolicy.stack:
        return context.l10n.stackPolicyTitle;
      case MissedPolicy.autoDismiss:
        final minutes = policy.gracePeriod.inMinutes;
        if (minutes == 0) {
          return '${context.l10n.autoDismissPolicyTitle} (${context.l10n.immediatelyPolicy})';
        } else if (minutes == 60) {
          return '${context.l10n.autoDismissPolicyTitle} (${context.l10n.oneHourPolicy})';
        } else if (minutes == 6 * 60) {
          return '${context.l10n.autoDismissPolicyTitle} (${context.l10n.sixHoursPolicy})';
        } else if (minutes == 12 * 60) {
          return '${context.l10n.autoDismissPolicyTitle} (${context.l10n.twelveHoursPolicy})';
        } else if (minutes == 24 * 60) {
          return '${context.l10n.autoDismissPolicyTitle} (${context.l10n.twentyFourHoursPolicy})';
        } else if (minutes % (7 * 24 * 60) == 0) {
          final weeks = minutes ~/ (7 * 24 * 60);
          return '${context.l10n.autoDismissPolicyTitle} ($weeks ${context.l10n.unitWeeks})';
        } else if (minutes % (24 * 60) == 0) {
          final days = minutes ~/ (24 * 60);
          return '${context.l10n.autoDismissPolicyTitle} ($days ${context.l10n.unitDays})';
        } else if (minutes % 60 == 0) {
          final hours = minutes ~/ 60;
          return '${context.l10n.autoDismissPolicyTitle} ($hours ${context.l10n.unitHours})';
        } else {
          return '${context.l10n.autoDismissPolicyTitle} ($minutes ${context.l10n.unitMinutes})';
        }
    }
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
        elevation: 2.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Column(
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
                    icon: const Icon(Icons.edit_calendar_outlined, size: 20),
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
            if (task.isFamily || task.labelIds.isNotEmpty)
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
                      _buildBadge(
                        context,
                        icon: Icons.people_alt,
                        label: context.l10n.familyTab,
                        color: theme.colorScheme.primary,
                      ),
                    if (task.isFamily &&
                        task.familyCompletionMode ==
                            FamilyCompletionMode.individual)
                      _buildBadge(
                        context,
                        icon: Icons.checklist,
                        label: context.l10n.completionModeIndividualLabel,
                        color: theme.colorScheme.primary,
                      ),
                    if (task.isFamily && task.assignedUserId != null)
                      _buildBadge(
                        context,
                        icon: Icons.assignment_ind,
                        label: ref
                            .watch(userNameProvider(task.assignedUserId!))
                            .when(
                              data: (name) => context.l10n.assignedTo(name),
                              loading: () => context.l10n.loadingBadge,
                              error: (_, _) => context.l10n.assignedBadge,
                            ),
                        color: theme.colorScheme.primary,
                      ),
                    ...() {
                      final allLabels = ref.watch(allLabelsMapProvider);
                      return task.labelIds
                          .map((id) => allLabels[id])
                          .whereType<TaskLabel>()
                          .map(
                            (label) => _buildBadge(
                              context,
                              icon: LabelIcons.getIcon(label.iconKey),
                              label: label.name,
                              color: LabelPalette.getColor(
                                label.colorKey,
                                context,
                              ),
                            ),
                          );
                    }(),
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
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: task.schedules.length,
              separatorBuilder: (context, _) =>
                  const Divider(height: 1, indent: 12, endIndent: 12),
              itemBuilder: (context, idx) {
                final rule = task.schedules[idx];
                final parts = _getRecurrenceRuleDetails(context, rule);

                String freqText = _getRecurrenceRuleTypeName(context, rule);
                int interval = 1;
                if (rule is DailySchedule) {
                  interval = rule.interval;
                } else if (rule is WeeklySchedule) {
                  interval = rule.interval;
                } else if (rule is MonthlySchedule) {
                  interval = rule.interval;
                } else if (rule is YearlySchedule) {
                  interval = rule.interval;
                }
                if (interval > 1) {
                  freqText = '$freqText (${parts.interval})';
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Column 1
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              freqText,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (parts.days.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                parts.days,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Column 2
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  rule.schedulingPolicy
                                          is CompletionRelativePolicy
                                      ? Icons.sync
                                      : Icons.calendar_today,
                                  size: 14,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    rule.schedulingPolicy
                                            is CompletionRelativePolicy
                                        ? context.l10n.completionRelativeLabel
                                        : context.l10n.fixedCalendarLabel,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (rule is! OneOffSchedule &&
                                rule.schedulingPolicy
                                    is! CompletionRelativePolicy) ...[
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.assignment_late_outlined,
                                    size: 14,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _getMissedPolicyString(context, rule),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${_formatRelativeTime(context, rule.startRelativeTime)} -- ${_formatRelativeTime(context, rule.dueRelativeTime)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
