import 'package:flutter/material.dart';
import '../logic/civil_day.dart';
import '../logic/relative_time.dart';
import '../logic/scheduling_policy.dart';
import '../logic/missed_occurrence_policy.dart';
import 'monthly_fixed_scheduling_widget.dart';
import 'monthly_nth_weekday_scheduling_widget.dart';
import 'monthly_completion_relative_scheduling_widget.dart';

class MonthlySchedulingWidget extends StatelessWidget {
  final CivilDay startDate;
  final ValueChanged<CivilDay> onStartDateChanged;
  final int interval;
  final ValueChanged<int> onIntervalChanged;
  final SchedulingPolicy schedulingPolicy;
  final ValueChanged<SchedulingPolicy> onSchedulingPolicyChanged;
  final String ruleType; // 'dayOfMonth' or 'nthDayOfWeek'
  final ValueChanged<String> onRuleTypeChanged;
  final int? dayOfMonth;
  final ValueChanged<int?> onDayOfMonthChanged;
  final int? occurrence;
  final ValueChanged<int?> onOccurrenceChanged;
  final int? dayOfWeek;
  final ValueChanged<int?> onDayOfWeekChanged;

  final RelativeTime startRelativeTime;
  final ValueChanged<RelativeTime> onStartRelativeTimeChanged;
  final RelativeTime dueRelativeTime;
  final ValueChanged<RelativeTime> onDueRelativeTimeChanged;
  final RelativeTime? notificationRelativeTime;
  final ValueChanged<RelativeTime?> onNotificationRelativeTimeChanged;
  final MissedOccurrencePolicy? missedOccurrencePolicy;
  final ValueChanged<MissedOccurrencePolicy>? onMissedOccurrencePolicyChanged;

  final bool showNotification;
  final bool showMissedPolicy;
  final bool readOnly;
  final TextEditingController? intervalController;
  final TextEditingController? dayOfMonthController;

  const MonthlySchedulingWidget({
    super.key,
    required this.startDate,
    required this.onStartDateChanged,
    required this.interval,
    required this.onIntervalChanged,
    required this.schedulingPolicy,
    required this.onSchedulingPolicyChanged,
    required this.ruleType,
    required this.onRuleTypeChanged,
    required this.dayOfMonth,
    required this.onDayOfMonthChanged,
    required this.occurrence,
    required this.onOccurrenceChanged,
    required this.dayOfWeek,
    required this.onDayOfWeekChanged,
    required this.startRelativeTime,
    required this.onStartRelativeTimeChanged,
    required this.dueRelativeTime,
    required this.onDueRelativeTimeChanged,
    required this.notificationRelativeTime,
    required this.onNotificationRelativeTimeChanged,
    this.missedOccurrencePolicy,
    this.onMissedOccurrencePolicyChanged,
    this.showNotification = true,
    this.showMissedPolicy = true,
    this.readOnly = false,
    this.intervalController,
    this.dayOfMonthController,
  });

  @override
  Widget build(BuildContext context) {
    if (schedulingPolicy is CompletionRelativePolicy) {
      return MonthlyCompletionRelativeSchedulingWidget(
        key: const Key('monthly_completion_relative_scheduling_widget'),
        interval: interval,
        onIntervalChanged: onIntervalChanged,
        startRelativeTime: startRelativeTime,
        onStartRelativeTimeChanged: onStartRelativeTimeChanged,
        dueRelativeTime: dueRelativeTime,
        onDueRelativeTimeChanged: onDueRelativeTimeChanged,
        notificationRelativeTime: notificationRelativeTime,
        onNotificationRelativeTimeChanged: onNotificationRelativeTimeChanged,
        showNotification: showNotification,
        readOnly: readOnly,
        intervalController: intervalController,
      );
    } else if (ruleType == 'dayOfMonth') {
      return MonthlyFixedSchedulingWidget(
        key: const Key('monthly_fixed_scheduling_widget'),
        startDate: startDate,
        onStartDateChanged: onStartDateChanged,
        interval: interval,
        onIntervalChanged: onIntervalChanged,
        dayOfMonth: dayOfMonth,
        onDayOfMonthChanged: onDayOfMonthChanged,
        startRelativeTime: startRelativeTime,
        onStartRelativeTimeChanged: onStartRelativeTimeChanged,
        dueRelativeTime: dueRelativeTime,
        onDueRelativeTimeChanged: onDueRelativeTimeChanged,
        notificationRelativeTime: notificationRelativeTime,
        onNotificationRelativeTimeChanged: onNotificationRelativeTimeChanged,
        missedOccurrencePolicy: missedOccurrencePolicy,
        onMissedOccurrencePolicyChanged: onMissedOccurrencePolicyChanged,
        showNotification: showNotification,
        showMissedPolicy: showMissedPolicy,
        readOnly: readOnly,
        intervalController: intervalController,
        dayOfMonthController: dayOfMonthController,
      );
    } else {
      return MonthlyNthWeekdaySchedulingWidget(
        key: const Key('monthly_nth_weekday_scheduling_widget'),
        startDate: startDate,
        onStartDateChanged: onStartDateChanged,
        interval: interval,
        onIntervalChanged: onIntervalChanged,
        occurrence: occurrence,
        onOccurrenceChanged: onOccurrenceChanged,
        dayOfWeek: dayOfWeek,
        onDayOfWeekChanged: onDayOfWeekChanged,
        startRelativeTime: startRelativeTime,
        onStartRelativeTimeChanged: onStartRelativeTimeChanged,
        dueRelativeTime: dueRelativeTime,
        onDueRelativeTimeChanged: onDueRelativeTimeChanged,
        notificationRelativeTime: notificationRelativeTime,
        onNotificationRelativeTimeChanged: onNotificationRelativeTimeChanged,
        missedOccurrencePolicy: missedOccurrencePolicy,
        onMissedOccurrencePolicyChanged: onMissedOccurrencePolicyChanged,
        showNotification: showNotification,
        showMissedPolicy: showMissedPolicy,
        readOnly: readOnly,
        intervalController: intervalController,
      );
    }
  }
}
