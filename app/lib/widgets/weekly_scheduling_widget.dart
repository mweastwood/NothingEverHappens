import 'package:flutter/material.dart';

import '../logic/civil_day.dart';
import '../logic/relative_time.dart';
import '../logic/scheduling_policy.dart';
import '../logic/missed_occurrence_policy.dart';
import '../logic/l10n_extension.dart';
import 'day_of_week_selector.dart';
import 'completion_relative_scheduling_widget.dart';
import 'recurring_schedule_scaffold.dart';

class WeeklySchedulingWidget extends StatelessWidget {
  final CivilDay startDate;
  final ValueChanged<CivilDay> onStartDateChanged;
  final int interval;
  final ValueChanged<int> onIntervalChanged;
  final SchedulingPolicy schedulingPolicy;
  final ValueChanged<SchedulingPolicy> onSchedulingPolicyChanged;
  final Set<int> selectedWeekdays;
  final ValueChanged<Set<int>> onWeekdaysChanged;
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

  const WeeklySchedulingWidget({
    super.key,
    required this.startDate,
    required this.onStartDateChanged,
    required this.interval,
    required this.onIntervalChanged,
    required this.schedulingPolicy,
    required this.onSchedulingPolicyChanged,
    required this.selectedWeekdays,
    required this.onWeekdaysChanged,
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
  Widget build(BuildContext context) {
    if (schedulingPolicy is CompletionRelativePolicy) {
      return WeeklyCompletionRelativeSchedulingWidget(
        key: const Key('weekly_completion_relative_scheduling_widget'),
        interval: interval,
        onIntervalChanged: onIntervalChanged,
        selectedWeekdays: selectedWeekdays,
        onWeekdaysChanged: onWeekdaysChanged,
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
      return WeeklyFixedSchedulingWidget(
        key: const Key('weekly_fixed_scheduling_widget'),
        startDate: startDate,
        onStartDateChanged: onStartDateChanged,
        interval: interval,
        onIntervalChanged: onIntervalChanged,
        selectedWeekdays: selectedWeekdays,
        onWeekdaysChanged: onWeekdaysChanged,
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

class WeeklyFixedSchedulingWidget extends StatefulWidget {
  final CivilDay startDate;
  final ValueChanged<CivilDay> onStartDateChanged;
  final int interval;
  final ValueChanged<int> onIntervalChanged;
  final Set<int> selectedWeekdays;
  final ValueChanged<Set<int>> onWeekdaysChanged;
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

  const WeeklyFixedSchedulingWidget({
    super.key,
    required this.startDate,
    required this.onStartDateChanged,
    required this.interval,
    required this.onIntervalChanged,
    required this.selectedWeekdays,
    required this.onWeekdaysChanged,
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
  State<WeeklyFixedSchedulingWidget> createState() =>
      _WeeklyFixedSchedulingWidgetState();
}

class _WeeklyFixedSchedulingWidgetState
    extends State<WeeklyFixedSchedulingWidget>
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
  void didUpdateWidget(WeeklyFixedSchedulingWidget oldWidget) {
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
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return RecurringScheduleScaffold(
      keyPrefix: 'weekly_fixed',
      interval: widget.interval,
      onIntervalChanged: widget.onIntervalChanged,
      unitSingular: l10n.presetWeekSingular,
      unitPlural: l10n.presetWeekPlural,
      startDate: widget.startDate,
      onStartDateChanged: widget.onStartDateChanged,
      helpText: l10n.repeatsEveryWeekHelp(
        widget.interval,
        formatCivilDayIso(widget.startDate),
      ),
      customSection: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.repeatsOnLabel,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          DayOfWeekSelector(
            selectedWeekdays: widget.selectedWeekdays,
            onChanged: widget.onWeekdaysChanged,
            readOnly: widget.readOnly,
          ),
        ],
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

class WeeklyCompletionRelativeSchedulingWidget extends StatelessWidget {
  final int interval;
  final ValueChanged<int> onIntervalChanged;
  final Set<int> selectedWeekdays;
  final ValueChanged<Set<int>> onWeekdaysChanged;
  final RelativeTime startRelativeTime;
  final ValueChanged<RelativeTime> onStartRelativeTimeChanged;
  final RelativeTime dueRelativeTime;
  final ValueChanged<RelativeTime> onDueRelativeTimeChanged;
  final RelativeTime? notificationRelativeTime;
  final ValueChanged<RelativeTime?> onNotificationRelativeTimeChanged;

  final bool showNotification;
  final bool readOnly;
  final TextEditingController? intervalController;

  const WeeklyCompletionRelativeSchedulingWidget({
    super.key,
    required this.interval,
    required this.onIntervalChanged,
    required this.selectedWeekdays,
    required this.onWeekdaysChanged,
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
      unitSingular: l10n.presetWeekSingular,
      unitPlural: l10n.presetWeekPlural,
      helpText: l10n.completionRelativeHelpWeekly(interval),
      keyPrefix: 'weekly_completion',
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
