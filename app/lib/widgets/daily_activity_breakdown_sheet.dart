import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final totalTasks =
        dayData.completedTasks.length +
        dayData.skippedTasks.length +
        dayData.missedTasks.length;

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
                        if (dayData.completedOnTimeTasks.isNotEmpty) ...[
                          _buildSectionHeader(
                            context,
                            'Completed',
                            dayData.completedOnTimeTasks.length,
                            Colors.green,
                          ),
                          ...dayData.completedOnTimeTasks.map(
                            (task) => _buildTaskTile(
                              context,
                              task,
                              status: TaskStatus.completed,
                              isOverdue: false,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (dayData.completedOverdueTasks.isNotEmpty) ...[
                          _buildSectionHeader(
                            context,
                            'Completed Overdue',
                            dayData.completedOverdueTasks.length,
                            Colors.amber.shade800,
                          ),
                          ...dayData.completedOverdueTasks.map(
                            (task) => _buildTaskTile(
                              context,
                              task,
                              status: TaskStatus.completed,
                              isOverdue: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (dayData.skippedTasks.isNotEmpty) ...[
                          _buildSectionHeader(
                            context,
                            'Skipped',
                            dayData.skippedTasks.length,
                            theme.colorScheme.onSurfaceVariant,
                          ),
                          ...dayData.skippedTasks.map(
                            (task) => _buildTaskTile(
                              context,
                              task,
                              status: TaskStatus.skipped,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (dayData.missedTasks.isNotEmpty) ...[
                          _buildSectionHeader(
                            context,
                            'Missed',
                            dayData.missedTasks.length,
                            theme.colorScheme.error,
                          ),
                          ...dayData.missedTasks.map(
                            (task) => _buildTaskTile(
                              context,
                              task,
                              status: task.status,
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

    if (dayData.skippedCount > 0) {
      chips.add(
        _buildChip(
          context,
          icon: Icons.remove_circle_outline,
          label: '${dayData.skippedCount} skipped',
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    if (dayData.missedCount > 0) {
      chips.add(
        _buildChip(
          context,
          icon: Icons.cancel_outlined,
          label: '${dayData.missedCount} missed',
          color: theme.colorScheme.error,
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
      if (isOverdue || task.isCompletedOverdue) {
        if (task.isCompletedOverdueByMoreThan24Hours) {
          icon = Icons.warning_amber_rounded;
          iconColor = theme.colorScheme.error;
          tagLabel = 'Overdue';
        } else {
          icon = Icons.warning_amber_rounded;
          iconColor = isDark ? Colors.amber.shade300 : Colors.amber.shade800;
          tagLabel = 'Overdue';
        }
      } else {
        icon = Icons.check_circle;
        iconColor = isDark ? Colors.green.shade300 : Colors.green.shade700;
        tagLabel = 'Completed';
      }
    } else if (status == TaskStatus.skipped) {
      icon = Icons.remove_circle_outline;
      iconColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
      tagLabel = 'Skipped';
    } else {
      icon = Icons.cancel_outlined;
      iconColor = theme.colorScheme.error;
      tagLabel = 'Missed';
    }

    String? completionTimeStr;
    if (task.completedAt != null) {
      final dt = task.completedAt!;
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      completionTimeStr = '$hour:$minute';
    }

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
          if (completionTimeStr != null) ...[
            const SizedBox(width: 8),
            Text(
              completionTimeStr,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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
