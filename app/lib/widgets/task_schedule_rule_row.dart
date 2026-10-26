import 'package:flutter/material.dart';

import '../logic/l10n_extension.dart';
import '../logic/relative_time.dart';
import '../logic/task_schedule.dart';

class TaskScheduleRuleRow extends StatelessWidget {
  final TaskScheduleRule rule;

  const TaskScheduleRuleRow({super.key, required this.rule});

  String _getRecurrenceRuleTypeName(BuildContext context) {
    final s = rule;
    if (s is DailySchedule) return context.l10n.dailyLabel;
    if (s is WeeklySchedule) return context.l10n.weeklyLabel;
    if (s is MonthlySchedule) return context.l10n.monthlyLabel;
    if (s is YearlySchedule) return context.l10n.yearlyLabel;
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

  ({String interval, String days}) _getRecurrenceRuleDetails(
    BuildContext context,
  ) {
    final schedule = rule;
    String intervalStr = '';
    String daysStr = '';
    final isCompletionRelative =
        schedule.schedulingPolicy is CompletionRelativePolicy;

    if (schedule is OneOffSchedule) {
      intervalStr = context.l10n.oneOffLabel;
    } else if (schedule is DailySchedule) {
      intervalStr = schedule.interval == 1
          ? context.l10n.everyDay
          : context.l10n.everyNDays(schedule.interval);
    } else if (schedule is WeeklySchedule) {
      intervalStr = schedule.interval == 1
          ? context.l10n.everyWeek
          : context.l10n.everyNWeeks(schedule.interval);

      if (!isCompletionRelative) {
        final dayNames = {
          1: context.l10n.weekdayShortMonday,
          2: context.l10n.weekdayShortTuesday,
          3: context.l10n.weekdayShortWednesday,
          4: context.l10n.weekdayShortThursday,
          5: context.l10n.weekdayShortFriday,
          6: context.l10n.weekdayShortSaturday,
          7: context.l10n.weekdayShortSunday,
        };
        final selectedDays = schedule.daysOfWeek.toList()..sort();
        final joinedDays = selectedDays
            .map((d) => dayNames[d] ?? '')
            .join(', ');
        daysStr = context.l10n.onDaysOfWeek(joinedDays);
      }
    } else if (schedule is MonthlySchedule) {
      intervalStr = schedule.interval == 1
          ? context.l10n.everyMonth
          : context.l10n.everyNMonths(schedule.interval);

      if (!isCompletionRelative) {
        if (schedule.dayOfMonth != null) {
          if (schedule.dayOfMonth! > 0) {
            daysStr = context.l10n.dayOfMonthOnDay(schedule.dayOfMonth!);
          } else {
            daysStr = context.l10n.dayOfMonthFromEnd(
              schedule.dayOfMonth!.abs(),
            );
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
          final occStr = occurrenceNames[schedule.occurrence] ?? '';
          final dowStr = dayOfWeekNames[schedule.dayOfWeek] ?? '';
          daysStr = context.l10n.nthDayOfWeekOccurrence(occStr, dowStr);
        }
      }
    } else if (schedule is YearlySchedule) {
      intervalStr = schedule.interval == 1
          ? context.l10n.everyYear
          : context.l10n.everyNYears(schedule.interval);

      if (!isCompletionRelative) {
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
        final mStr = monthNames[schedule.month] ?? '';
        daysStr = context.l10n.yearlyOn(mStr, schedule.day);
      }
    }

    return (interval: intervalStr, days: daysStr);
  }

  String _getMissedPolicyString(BuildContext context) {
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

  int _ruleInterval(TaskScheduleRule s) {
    if (s is DailySchedule) return s.interval;
    if (s is WeeklySchedule) return s.interval;
    if (s is MonthlySchedule) return s.interval;
    if (s is YearlySchedule) return s.interval;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = _getRecurrenceRuleDetails(context);

    String freqText = _getRecurrenceRuleTypeName(context);
    if (_ruleInterval(rule) > 1) {
      freqText = '$freqText (${parts.interval})';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
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
                      rule.schedulingPolicy is CompletionRelativePolicy
                          ? Icons.sync
                          : Icons.calendar_today,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        rule.schedulingPolicy is CompletionRelativePolicy
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
                    rule.schedulingPolicy is! CompletionRelativePolicy) ...[
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
                          _getMissedPolicyString(context),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
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
  }
}
