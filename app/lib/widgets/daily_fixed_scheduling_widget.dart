import 'package:flutter/material.dart';

import '../logic/civil_day.dart';
import '../logic/relative_time.dart';
import '../logic/missed_occurrence_policy.dart';
import '../logic/l10n_extension.dart';
import 'recurring_schedule_scaffold.dart';

class DailyFixedSchedulingWidget extends StatefulWidget {
  final CivilDay startDate;
  final ValueChanged<CivilDay> onStartDateChanged;
  final int interval;
  final ValueChanged<int> onIntervalChanged;
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

  const DailyFixedSchedulingWidget({
    super.key,
    required this.startDate,
    required this.onStartDateChanged,
    required this.interval,
    required this.onIntervalChanged,
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
  });

  @override
  State<DailyFixedSchedulingWidget> createState() =>
      _DailyFixedSchedulingWidgetState();
}

class _DailyFixedSchedulingWidgetState extends State<DailyFixedSchedulingWidget>
    with ScheduleTimingControllersMixin {
  @override
  void initState() {
    super.initState();
    initTimingControllers(
      startRelativeTime: widget.startRelativeTime,
      onStartRelativeTimeChanged: widget.onStartRelativeTimeChanged,
      dueRelativeTime: widget.dueRelativeTime,
      onDueRelativeTimeChanged: widget.onDueRelativeTimeChanged,
      notificationRelativeTime: widget.notificationRelativeTime,
      onNotificationRelativeTimeChanged:
          widget.onNotificationRelativeTimeChanged,
    );
  }

  @override
  void didUpdateWidget(DailyFixedSchedulingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncTimingControllers(
      startRelativeTime: widget.startRelativeTime,
      onStartRelativeTimeChanged: widget.onStartRelativeTimeChanged,
      dueRelativeTime: widget.dueRelativeTime,
      onDueRelativeTimeChanged: widget.onDueRelativeTimeChanged,
      notificationRelativeTime: widget.notificationRelativeTime,
      onNotificationRelativeTimeChanged:
          widget.onNotificationRelativeTimeChanged,
    );
  }

  @override
  void dispose() {
    disposeTimingControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return RecurringScheduleScaffold(
      keyPrefix: 'daily_fixed',
      interval: widget.interval,
      onIntervalChanged: widget.onIntervalChanged,
      unitSingular: l10n.presetDaySingular,
      unitPlural: l10n.presetDayPlural,
      startDate: widget.startDate,
      onStartDateChanged: widget.onStartDateChanged,
      helpText: l10n.repeatsEveryDayHelp(
        widget.interval,
        formatCivilDayIso(widget.startDate),
      ),
      startController: startController,
      dueController: dueController,
      notificationController: notificationController,
      showNotification: widget.showNotification,
      notificationEnabled: widget.notificationRelativeTime != null,
      onNotificationRelativeTimeChanged:
          widget.onNotificationRelativeTimeChanged,
      showMissedPolicy: widget.showMissedPolicy,
      missedOccurrencePolicy: widget.missedOccurrencePolicy,
      onMissedOccurrencePolicyChanged: widget.onMissedOccurrencePolicyChanged,
      readOnly: widget.readOnly,
      intervalController: widget.intervalController,
    );
  }
}
