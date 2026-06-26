import 'package:flutter/material.dart';
import '../logic/task_schedule_rule.dart';
import '../logic/scheduling_policy.dart';
import '../logic/l10n_extension.dart';
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
  (int, String) _getCompletionRelativeValueAndUnit(
    BuildContext context,
    Duration duration,
  ) {
    final l10n = context.l10n;
    if (duration.inMinutes == 0) return (0, l10n.unitDays);
    if (duration.inMinutes % (7 * 24 * 60) == 0) {
      return (duration.inDays ~/ 7, l10n.unitWeeks);
    }
    if (duration.inMinutes % (24 * 60) == 0) {
      return (duration.inDays, l10n.unitDays);
    }
    return (duration.inHours, l10n.unitHours);
  }

  String _getShortWeekdayName(BuildContext context, int day) {
    final l10n = context.l10n;
    switch (day) {
      case 1:
        return l10n.weekdayShortMonday;
      case 2:
        return l10n.weekdayShortTuesday;
      case 3:
        return l10n.weekdayShortWednesday;
      case 4:
        return l10n.weekdayShortThursday;
      case 5:
        return l10n.weekdayShortFriday;
      case 6:
        return l10n.weekdayShortSaturday;
      case 7:
        return l10n.weekdayShortSunday;
      default:
        return '';
    }
  }

  String _getShortMonthName(BuildContext context, int month) {
    final l10n = context.l10n;
    switch (month) {
      case 1:
        return l10n.monthShortJanuary;
      case 2:
        return l10n.monthShortFebruary;
      case 3:
        return l10n.monthShortMarch;
      case 4:
        return l10n.monthShortApril;
      case 5:
        return l10n.monthShortMay;
      case 6:
        return l10n.monthShortJune;
      case 7:
        return l10n.monthShortJuly;
      case 8:
        return l10n.monthShortAugust;
      case 9:
        return l10n.monthShortSeptember;
      case 10:
        return l10n.monthShortOctober;
      case 11:
        return l10n.monthShortNovember;
      case 12:
        return l10n.monthShortDecember;
      default:
        return '';
    }
  }

  String _getSummaryText(TaskScheduleRule schedule) {
    final l10n = context.l10n;
    if (schedule.schedulingPolicy is CompletionRelativePolicy) {
      final policy = schedule.schedulingPolicy as CompletionRelativePolicy;
      final (val, unit) = _getCompletionRelativeValueAndUnit(
        context,
        policy.interval,
      );
      final timeStr = policy.targetTime.format(context);
      return l10n.completionRelativeSummary(val.toString(), unit, timeStr);
    }
    if (schedule is OneOffSchedule) {
      final dateStr =
          '${schedule.date.year}-${schedule.date.month.toString().padLeft(2, '0')}-${schedule.date.day.toString().padLeft(2, '0')}';
      return l10n.oneOffSummary(dateStr);
    } else if (schedule is DailySchedule) {
      return l10n.dailySummary(schedule.interval.toString());
    } else if (schedule is WeeklySchedule) {
      final days = schedule.daysOfWeek
          .map((d) => _getShortWeekdayName(context, d))
          .join(', ');
      return l10n.weeklySummary(schedule.interval.toString(), days);
    } else if (schedule is MonthlySchedule) {
      if (schedule.dayOfMonth != null) {
        return l10n.monthlySummaryDay(
          schedule.interval.toString(),
          schedule.dayOfMonth.toString(),
        );
      } else {
        final occurrenceNames = {
          1: l10n.firstOccurrence,
          2: l10n.secondOccurrence,
          3: l10n.thirdOccurrence,
          4: l10n.fourthOccurrence,
          -1: l10n.lastOccurrence,
        };
        final occurrenceLabel = occurrenceNames[schedule.occurrence] ?? '';
        final weekdayLabel = _getShortWeekdayName(context, schedule.dayOfWeek!);
        return l10n.monthlySummaryNth(
          schedule.interval.toString(),
          occurrenceLabel,
          weekdayLabel,
        );
      }
    } else if (schedule is YearlySchedule) {
      final monthLabel = _getShortMonthName(context, schedule.month);
      return l10n.yearlySummary(
        schedule.interval.toString(),
        monthLabel,
        schedule.day.toString(),
      );
    }
    return l10n.customScheduleSummary;
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
                    tooltip: context.l10n.deleteScheduleTooltip,
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
