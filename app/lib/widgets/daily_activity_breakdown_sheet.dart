import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../logic/app_clock.dart';
import '../logic/civil_day.dart';
import '../logic/dashboard_stats.dart';
import '../logic/task_instance.dart';
import '../logic/utils/format_utils.dart';

class DailyActivityBreakdownSheet extends StatelessWidget {
  final DailyStatsData dayData;

  const DailyActivityBreakdownSheet({super.key, required this.dayData});

  static Future<void> show(BuildContext context, DailyStatsData dayData) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DailyActivityBreakdownSheet(dayData: dayData),
    );
  }

  String _formatFullDate(CivilDay day) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final dt = day.toDateTime();
    final weekday = weekdays[dt.weekday - 1];
    final month = months[day.month - 1];
    return '$weekday, $month ${day.day}, ${day.year}';
  }

  int _compareResolvedOrder(TaskInstance a, TaskInstance b) {
    final aTime = a.completedAt ?? a.updatedAt;
    final bTime = b.completedAt ?? b.updatedAt;
    final cmp = aTime.compareTo(bTime);
    if (cmp != 0) return cmp;
    return a.title.compareTo(b.title);
  }

  String _formatTaskTime(BuildContext context, TaskInstance task) {
    final dt =
        task.completedAt ??
        task.dueRelativeTime.referenceTo(task.scheduledDate);
    final locale = Localizations.localeOf(context).languageCode;
    final dateStr = (dt.year != AppClock.now.year)
        ? DateFormat.yMMMd(locale).format(dt)
        : DateFormat.MMMd(locale).format(dt);
    final timeStr = DateFormat('h:mm a', locale).format(dt);
    return '$dateStr, $timeStr';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final totalTasks =
        dayData.completedTasks.length +
        dayData.skippedTasks.length +
        dayData.missedTasks.length +
        dayData.plannedTasks.length;

    final onTimeTasks = [...dayData.completedOnTimeTasks]
      ..sort(_compareResolvedOrder);
    final overdueTasks = [...dayData.completedOverdueTasks]
      ..sort(_compareResolvedOrder);
    final seriouslyOverdueTasks = [...dayData.completedSeriouslyOverdueTasks]
      ..sort(_compareResolvedOrder);
    final skippedAndMissedTasks = [
      ...dayData.skippedTasks,
      ...dayData.missedTasks,
    ]..sort(_compareResolvedOrder);
    final plannedTasks = [...dayData.plannedTasks]
      ..sort((a, b) {
        final aTime = a.dueRelativeTime.referenceTo(a.scheduledDate);
        final bTime = b.dueRelativeTime.referenceTo(b.scheduledDate);
        final cmp = aTime.compareTo(bTime);
        if (cmp != 0) return cmp;
        return a.title.compareTo(b.title);
      });

    return SafeArea(
      child: Container(
        key: const Key('daily_activity_breakdown_sheet'),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatFullDate(dayData.day),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildMetricChips(context),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Flexible(
              child: totalTasks == 0
                  ? _buildEmptyState(context)
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        if (plannedTasks.isNotEmpty) ...[
                          _buildSectionHeader(
                            context,
                            'Planned',
                            plannedTasks.length,
                            theme.colorScheme.primary,
                          ),
                          ...plannedTasks.map(
                            (task) => _buildTaskTile(
                              context,
                              task,
                              status: TaskStatus.pending,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (onTimeTasks.isNotEmpty) ...[
                          _buildSectionHeader(
                            context,
                            'Completed',
                            onTimeTasks.length,
                            Colors.green,
                          ),
                          ...onTimeTasks.map(
                            (task) => _buildTaskTile(
                              context,
                              task,
                              status: TaskStatus.completed,
                              isOverdue: false,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (overdueTasks.isNotEmpty) ...[
                          _buildSectionHeader(
                            context,
                            'Completed Overdue',
                            overdueTasks.length,
                            Colors.amber.shade800,
                          ),
                          ...overdueTasks.map(
                            (task) => _buildTaskTile(
                              context,
                              task,
                              status: TaskStatus.completed,
                              isOverdue: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (seriouslyOverdueTasks.isNotEmpty) ...[
                          _buildSectionHeader(
                            context,
                            'Seriously Overdue',
                            seriouslyOverdueTasks.length,
                            theme.colorScheme.error,
                          ),
                          ...seriouslyOverdueTasks.map(
                            (task) => _buildTaskTile(
                              context,
                              task,
                              status: TaskStatus.completed,
                              isOverdue: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (skippedAndMissedTasks.isNotEmpty) ...[
                          _buildSectionHeader(
                            context,
                            'Skipped',
                            skippedAndMissedTasks.length,
                            theme.colorScheme.onSurfaceVariant,
                          ),
                          ...skippedAndMissedTasks.map(
                            (task) => _buildTaskTile(
                              context,
                              task,
                              status: TaskStatus.skipped,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricChips(BuildContext context) {
    final theme = Theme.of(context);
    final chips = <Widget>[];

    final onTimeCount = dayData.completedOnTimeCount;
    final overdueCount = dayData.completedOverdueCount;
    final seriouslyOverdueCount = dayData.completedSeriouslyOverdueCount;
    final totalSkippedCount = dayData.skippedCount + dayData.missedCount;
    final plannedCount = dayData.plannedTasks.length;

    if (plannedCount > 0) {
      chips.add(
        _buildChip(
          context,
          icon: Icons.schedule,
          label: '$plannedCount planned',
          color: theme.colorScheme.primary,
        ),
      );
    }

    if (onTimeCount > 0) {
      chips.add(
        _buildChip(
          context,
          icon: Icons.check_circle_outline,
          label: '$onTimeCount completed',
          color: Colors.green,
        ),
      );
    }

    if (overdueCount > 0) {
      chips.add(
        _buildChip(
          context,
          icon: Icons.warning_amber_rounded,
          label: '$overdueCount overdue',
          color: Colors.amber.shade800,
        ),
      );
    }

    if (seriouslyOverdueCount > 0) {
      chips.add(
        _buildChip(
          context,
          icon: Icons.warning_amber_rounded,
          label: '$seriouslyOverdueCount seriously overdue',
          color: theme.colorScheme.error,
        ),
      );
    }

    if (totalSkippedCount > 0) {
      chips.add(
        _buildChip(
          context,
          icon: Icons.remove_circle_outline,
          label: '$totalSkippedCount skipped',
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    if (dayData.completedHours > 0) {
      chips.add(
        _buildChip(
          context,
          icon: Icons.schedule,
          label: formatDurationHours(dayData.completedHours),
          color: theme.colorScheme.primary,
        ),
      );
    } else if (dayData.plannedHours > 0) {
      chips.add(
        _buildChip(
          context,
          icon: Icons.schedule,
          label: formatDurationHours(dayData.plannedHours),
          color: theme.colorScheme.primary,
        ),
      );
    }

    if (chips.isEmpty) {
      return Text(
        'No tasks recorded',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Wrap(spacing: 6, runSpacing: 4, children: chips);
  }

  Widget _buildChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    int count,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Text(
            '$title ($count)',
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTile(
    BuildContext context,
    TaskInstance task, {
    required TaskStatus status,
    bool isOverdue = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final IconData icon;
    final Color iconColor;
    final String tagLabel;

    if (status == TaskStatus.completed) {
      if (task.isCompletedOverdueByMoreThan24Hours) {
        icon = Icons.warning_amber_rounded;
        iconColor = theme.colorScheme.error;
        tagLabel = 'Seriously Overdue';
      } else if (isOverdue || task.isCompletedOverdue) {
        icon = Icons.warning_amber_rounded;
        iconColor = isDark ? Colors.amber.shade300 : Colors.amber.shade800;
        tagLabel = 'Overdue';
      } else {
        icon = Icons.check_circle;
        iconColor = isDark ? Colors.green.shade300 : Colors.green.shade700;
        tagLabel = 'Completed';
      }
    } else if (status == TaskStatus.skipped) {
      icon = Icons.remove_circle_outline;
      iconColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
      tagLabel = 'Skipped';
    } else if (status == TaskStatus.pending) {
      icon = Icons.schedule;
      iconColor = theme.colorScheme.primary;
      tagLabel = 'Planned';
    } else {
      icon = Icons.cancel_outlined;
      iconColor = theme.colorScheme.error;
      tagLabel = 'Missed';
    }

    final taskTimeStr = _formatTaskTime(context, task);

    final isSevereOverdue =
        task.status == TaskStatus.completed &&
        task.isCompletedOverdueByMoreThan24Hours;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSevereOverdue
              ? theme.colorScheme.error.withValues(alpha: 0.5)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              task.title.isEmpty ? 'Untitled Task' : task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            taskTimeStr,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              tagLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: iconColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_busy_outlined,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'No activity recorded for this day',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
