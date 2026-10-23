import 'package:flutter/material.dart';
import '../logic/l10n_extension.dart';
import '../logic/relative_time.dart';
import 'completion_relative_scheduling_widget.dart';

class MonthlyCompletionRelativeSchedulingWidget extends StatelessWidget {
  final int interval;
  final ValueChanged<int> onIntervalChanged;
  final RelativeTime startRelativeTime;
  final ValueChanged<RelativeTime> onStartRelativeTimeChanged;
  final RelativeTime dueRelativeTime;
  final ValueChanged<RelativeTime> onDueRelativeTimeChanged;
  final RelativeTime? notificationRelativeTime;
  final ValueChanged<RelativeTime?> onNotificationRelativeTimeChanged;

  final bool showNotification;
  final bool readOnly;
  final TextEditingController? intervalController;

  const MonthlyCompletionRelativeSchedulingWidget({
    super.key,
    required this.interval,
    required this.onIntervalChanged,
    required this.startRelativeTime,
    required this.onStartRelativeTimeChanged,
    required this.dueRelativeTime,
    required this.onDueRelativeTimeChanged,
    required this.notificationRelativeTime,
    required this.onNotificationRelativeTimeChanged,
    this.showNotification = true,
    this.readOnly = false,
    this.intervalController,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CompletionRelativeSchedulingWidget(
      interval: interval,
      onIntervalChanged: onIntervalChanged,
      unitSingular: l10n.presetMonthSingular,
      unitPlural: l10n.presetMonthPlural,
      helpText: l10n.completionRelativeHelpMonthly(interval),
      keyPrefix: 'monthly_completion',
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
  }
}
