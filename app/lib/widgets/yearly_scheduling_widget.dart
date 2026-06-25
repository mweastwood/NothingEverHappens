// Resolves GitHub Issue #233: Clean up the yearly scheduling widget.
import 'package:flutter/material.dart';
import '../logic/civil_day.dart';
import '../logic/relative_time.dart';
import '../logic/scheduling_policy.dart';
import '../logic/missed_occurrence_policy.dart';
import 'yearly_completion_relative_scheduling_widget.dart';
import 'yearly_fixed_scheduling_widget.dart';

class YearlySchedulingWidget extends StatelessWidget {
  final CivilDay startDate;
  final ValueChanged<CivilDay> onStartDateChanged;
  final int interval;
  final ValueChanged<int> onIntervalChanged;
  final SchedulingPolicy schedulingPolicy;
  final ValueChanged<SchedulingPolicy> onSchedulingPolicyChanged;
  final int month;
  final ValueChanged<int> onMonthChanged;
  final int day;
  final ValueChanged<int> onDayChanged;

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
  final TextEditingController? dayController;

  const YearlySchedulingWidget({
    super.key,
    required this.startDate,
    required this.onStartDateChanged,
    required this.interval,
    required this.onIntervalChanged,
    required this.schedulingPolicy,
    required this.onSchedulingPolicyChanged,
    required this.month,
    required this.onMonthChanged,
    required this.day,
    required this.onDayChanged,
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
    this.dayController,
  });

  @override
  Widget build(BuildContext context) {
    if (schedulingPolicy is CompletionRelativePolicy) {
      return YearlyCompletionRelativeSchedulingWidget(
        key: const Key('yearly_completion_relative_scheduling_widget'),
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
    } else {
      return YearlyFixedSchedulingWidget(
        key: const Key('yearly_fixed_scheduling_widget'),
        startDate: startDate,
        onStartDateChanged: onStartDateChanged,
        interval: interval,
        onIntervalChanged: onIntervalChanged,
        month: month,
        onMonthChanged: onMonthChanged,
        day: day,
        onDayChanged: onDayChanged,
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
        dayController: dayController,
      );
    }
  }
}
