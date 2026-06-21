import 'package:flutter/material.dart';
import '../logic/task_schedule_rule.dart';
import '../logic/scheduling_policy.dart';
import 'schedule_rule_config_widget.dart';

class ScheduleConfigCard extends StatefulWidget {
  final TaskScheduleRule schedule;
  final ValueChanged<TaskScheduleRule> onChanged;
  final VoidCallback? onDelete;
  final bool isExpanded;
  final ValueChanged<bool> onExpansionChanged;

  const ScheduleConfigCard({
    super.key,
    required this.schedule,
    required this.onChanged,
    this.onDelete,
    required this.isExpanded,
    required this.onExpansionChanged,
  });

  @override
  State<ScheduleConfigCard> createState() => _ScheduleConfigCardState();
}

class _ScheduleConfigCardState extends State<ScheduleConfigCard> {
  (int, String) _getCompletionRelativeValueAndUnit(Duration duration) {
    if (duration.inMinutes == 0) return (0, 'day(s)');
    if (duration.inMinutes % (7 * 24 * 60) == 0) {
      return (duration.inDays ~/ 7, 'week(s)');
    }
    if (duration.inMinutes % (24 * 60) == 0) {
      return (duration.inDays, 'day(s)');
    }
    return (duration.inHours, 'hour(s)');
  }

  String _getSummaryText(TaskScheduleRule schedule) {
    if (schedule.schedulingPolicy is CompletionRelativePolicy) {
      final policy = schedule.schedulingPolicy as CompletionRelativePolicy;
      final (val, unit) = _getCompletionRelativeValueAndUnit(policy.interval);
      final timeStr = policy.targetTime.format(context);
      return 'Completion-relative: every $val $unit @ $timeStr';
    }
    if (schedule is OneOffSchedule) {
      return 'One-off on ${schedule.date.year}-${schedule.date.month.toString().padLeft(2, '0')}-${schedule.date.day.toString().padLeft(2, '0')}';
    } else if (schedule is DailySchedule) {
      return 'Daily, every ${schedule.interval} day(s)';
    } else if (schedule is WeeklySchedule) {
      final days = schedule.daysOfWeek
          .map((d) {
            final labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
            return labels[d - 1];
          })
          .join(', ');
      return 'Weekly, every ${schedule.interval} week(s) on $days';
    } else if (schedule is MonthlySchedule) {
      if (schedule.dayOfMonth != null) {
        return 'Monthly, every ${schedule.interval} month(s) on day ${schedule.dayOfMonth}';
      } else {
        final occurrenceLabel = schedule.occurrence == -1
            ? 'last'
            : 'nth ${schedule.occurrence}';
        final labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final weekdayLabel = labels[schedule.dayOfWeek! - 1];
        return 'Monthly, every ${schedule.interval} month(s) on $occurrenceLabel $weekdayLabel';
      }
    } else if (schedule is YearlySchedule) {
      final monthLabels = [
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
      return 'Yearly, every ${schedule.interval} year(s) on ${monthLabels[schedule.month - 1]} ${schedule.day}';
    }
    return 'Custom schedule';
  }

  IconData _getIcon(TaskScheduleRule schedule) {
    if (schedule.schedulingPolicy is CompletionRelativePolicy) {
      return Icons.replay;
    }
    if (schedule is OneOffSchedule) return Icons.event;
    if (schedule is DailySchedule) return Icons.today;
    if (schedule is WeeklySchedule) return Icons.calendar_view_week;
    if (schedule is MonthlySchedule) return Icons.calendar_view_month;
    if (schedule is YearlySchedule) return Icons.calendar_today;
    return Icons.schedule;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = widget.schedule;
    final summary = _getSummaryText(s);
    final icon = _getIcon(s);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.only(left: 4, right: 4, bottom: 12),
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: Icon(icon, color: theme.colorScheme.primary),
            title: Text(
              summary,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.onDelete != null)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    onPressed: widget.onDelete,
                    tooltip: 'Delete Schedule',
                  ),
                IconButton(
                  icon: Icon(
                    widget.isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                  ),
                  onPressed: () =>
                      widget.onExpansionChanged(!widget.isExpanded),
                ),
              ],
            ),
          ),
          if (widget.isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ScheduleRuleConfigWidget(
                schedule: s,
                onChanged: widget.onChanged,
                showNotification: true,
                showMissedPolicy: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
