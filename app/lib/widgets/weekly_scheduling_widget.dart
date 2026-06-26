import 'package:flutter/material.dart';
import '../logic/civil_day.dart';
import '../logic/relative_time.dart';
import '../logic/scheduling_policy.dart';
import '../logic/missed_occurrence_policy.dart';
import '../logic/l10n_extension.dart';
import 'interval_stepper.dart';
import 'date_stepper.dart';
import 'relative_time_widget.dart';
import 'missed_occurrence_policy_selector.dart';
import 'day_of_week_selector.dart';

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
    extends State<WeeklyFixedSchedulingWidget> {
  late final ValueNotifier<RelativeTime> _startController;
  late final ValueNotifier<RelativeTime> _dueController;
  late final ValueNotifier<RelativeTime> _notificationController;

  bool _ignoreEvents = false;

  @override
  void initState() {
    super.initState();
    _startController = ValueNotifier(widget.startRelativeTime);
    _dueController = ValueNotifier(widget.dueRelativeTime);
    _notificationController = ValueNotifier(
      widget.notificationRelativeTime ??
          const RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 9, minute: 0)),
    );

    _startController.addListener(_onStartChanged);
    _dueController.addListener(_onDueChanged);
    _notificationController.addListener(_onNotificationChanged);
  }

  void _onStartChanged() {
    if (_ignoreEvents) return;
    widget.onStartRelativeTimeChanged(_startController.value);
  }

  void _onDueChanged() {
    if (_ignoreEvents) return;
    widget.onDueRelativeTimeChanged(_dueController.value);
  }

  void _onNotificationChanged() {
    if (_ignoreEvents) return;
    if (widget.notificationRelativeTime != null) {
      widget.onNotificationRelativeTimeChanged(_notificationController.value);
    }
  }

  @override
  void didUpdateWidget(WeeklyFixedSchedulingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ignoreEvents = true;
    try {
      if (_startController.value != widget.startRelativeTime) {
        _startController.value = widget.startRelativeTime;
      }
      if (_dueController.value != widget.dueRelativeTime) {
        _dueController.value = widget.dueRelativeTime;
      }
      if (widget.notificationRelativeTime != null &&
          _notificationController.value != widget.notificationRelativeTime) {
        _notificationController.value = widget.notificationRelativeTime!;
      }
    } finally {
      _ignoreEvents = false;
    }
  }

  @override
  void dispose() {
    _startController.removeListener(_onStartChanged);
    _dueController.removeListener(_onDueChanged);
    _notificationController.removeListener(_onNotificationChanged);
    _startController.dispose();
    _dueController.dispose();
    _notificationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final dt = DateTime(
      widget.startDate.year,
      widget.startDate.month,
      widget.startDate.day,
    );
    final notificationEnabled = widget.notificationRelativeTime != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1 & 2. Interval and Start Recurrence Date side-by-side
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: IntervalStepper(
                key: const Key('weekly_fixed_interval_stepper'),
                interval: widget.interval,
                onIntervalChanged: widget.onIntervalChanged,
                label: l10n.intervalLabel,
                unitSingular: l10n.presetWeekSingular,
                unitPlural: l10n.presetWeekPlural,
                readOnly: widget.readOnly,
                intervalController: widget.intervalController,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DateStepper(
                key: const Key('weekly_fixed_date_stepper'),
                date: dt,
                onDateChanged: widget.readOnly
                    ? null
                    : (picked) {
                        widget.onStartDateChanged(
                          CivilDay(
                            year: picked.year,
                            month: picked.month,
                            day: picked.day,
                          ),
                        );
                      },
                label: l10n.startDateLabel,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Shared help text for the combination
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.help_outline,
              size: 14,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.repeatsEveryWeekHelp(
                  widget.interval,
                  '${widget.startDate.year}-${widget.startDate.month.toString().padLeft(2, '0')}-${widget.startDate.day.toString().padLeft(2, '0')}',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Repeats on weekdays section
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
        const SizedBox(height: 20),

        // 3. Start Window & help text
        Text(
          l10n.startLabel,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        RelativeTimeWidget(
          key: const Key('weekly_fixed_start_relative_time_picker'),
          constraint: RelativeTimeConstraint.unconstrained,
          controller: _startController,
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.help_outline,
              size: 14,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.taskAppearanceHelpText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 4. Due Window & help text
        Text(
          l10n.dueWithoutColon,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        RelativeTimeWidget(
          key: const Key('weekly_fixed_due_relative_time_picker'),
          constraint: RelativeTimeConstraint.unconstrained,
          controller: _dueController,
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.help_outline,
              size: 14,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.dueDescription,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),

        // 5. Notifications
        if (widget.showNotification) ...[
          const SizedBox(height: 16),
          const Divider(),
          CheckboxListTile(
            key: const Key('weekly_fixed_notification_checkbox'),
            title: Text(
              l10n.enableNotificationReminderLabel,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            value: notificationEnabled,
            onChanged: widget.readOnly
                ? null
                : (enabled) {
                    if (enabled == true) {
                      widget.onNotificationRelativeTimeChanged(
                        _notificationController.value,
                      );
                    } else {
                      widget.onNotificationRelativeTimeChanged(null);
                    }
                  },
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          if (notificationEnabled) ...[
            Text(
              l10n.notificationWindowLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            RelativeTimeWidget(
              key: const Key('weekly_fixed_notification_relative_time_picker'),
              constraint: RelativeTimeConstraint.unconstrained,
              controller: _notificationController,
            ),
          ],
        ],

        // 6. Missed occurrence policy selector
        if (widget.showMissedPolicy &&
            widget.missedOccurrencePolicy != null &&
            widget.onMissedOccurrencePolicyChanged != null) ...[
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          MissedOccurrencePolicySelector(
            key: const Key('weekly_fixed_missed_policy'),
            policy: widget.missedOccurrencePolicy!,
            onChanged: widget.onMissedOccurrencePolicyChanged!,
          ),
        ],
      ],
    );
  }
}

class WeeklyCompletionRelativeSchedulingWidget extends StatefulWidget {
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
  State<WeeklyCompletionRelativeSchedulingWidget> createState() =>
      _WeeklyCompletionRelativeSchedulingWidgetState();
}

class _WeeklyCompletionRelativeSchedulingWidgetState
    extends State<WeeklyCompletionRelativeSchedulingWidget> {
  late final ValueNotifier<RelativeTime> _startController;
  late final ValueNotifier<RelativeTime> _dueController;
  late final ValueNotifier<RelativeTime> _notificationController;

  bool _ignoreEvents = false;

  @override
  void initState() {
    super.initState();
    _startController = ValueNotifier(widget.startRelativeTime);
    _dueController = ValueNotifier(widget.dueRelativeTime);
    _notificationController = ValueNotifier(
      widget.notificationRelativeTime ??
          const RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 9, minute: 0)),
    );

    _startController.addListener(_onStartChanged);
    _dueController.addListener(_onDueChanged);
    _notificationController.addListener(_onNotificationChanged);
  }

  void _onStartChanged() {
    if (_ignoreEvents) return;
    widget.onStartRelativeTimeChanged(_startController.value);
  }

  void _onDueChanged() {
    if (_ignoreEvents) return;
    widget.onDueRelativeTimeChanged(_dueController.value);
  }

  void _onNotificationChanged() {
    if (_ignoreEvents) return;
    if (widget.notificationRelativeTime != null) {
      widget.onNotificationRelativeTimeChanged(_notificationController.value);
    }
  }

  @override
  void didUpdateWidget(WeeklyCompletionRelativeSchedulingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ignoreEvents = true;
    try {
      if (_startController.value != widget.startRelativeTime) {
        _startController.value = widget.startRelativeTime;
      }
      if (_dueController.value != widget.dueRelativeTime) {
        _dueController.value = widget.dueRelativeTime;
      }
      if (widget.notificationRelativeTime != null &&
          _notificationController.value != widget.notificationRelativeTime) {
        _notificationController.value = widget.notificationRelativeTime!;
      }
    } finally {
      _ignoreEvents = false;
    }
  }

  @override
  void dispose() {
    _startController.removeListener(_onStartChanged);
    _dueController.removeListener(_onDueChanged);
    _notificationController.removeListener(_onNotificationChanged);
    _startController.dispose();
    _dueController.dispose();
    _notificationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final notificationEnabled = widget.notificationRelativeTime != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Interval
        IntervalStepper(
          key: const Key('weekly_completion_interval_stepper'),
          interval: widget.interval,
          onIntervalChanged: widget.onIntervalChanged,
          label: l10n.intervalLabel,
          unitSingular: l10n.presetWeekSingular,
          unitPlural: l10n.presetWeekPlural,
          readOnly: widget.readOnly,
          intervalController: widget.intervalController,
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.help_outline,
              size: 14,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.completionRelativeHelpWeekly(widget.interval),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 2. Start
        Text(
          l10n.startLabel,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        RelativeTimeWidget(
          key: const Key('weekly_completion_start_relative_time_picker'),
          constraint: RelativeTimeConstraint.unconstrained,
          controller: _startController,
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.help_outline,
              size: 14,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.taskAppearanceHelpText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 3. Due
        Text(
          l10n.dueWithoutColon,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        RelativeTimeWidget(
          key: const Key('weekly_completion_due_relative_time_picker'),
          constraint: RelativeTimeConstraint.unconstrained,
          controller: _dueController,
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.help_outline,
              size: 14,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.dueDescription,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),

        // 4. Notifications
        if (widget.showNotification) ...[
          const SizedBox(height: 16),
          const Divider(),
          CheckboxListTile(
            key: const Key('weekly_completion_notification_checkbox'),
            title: Text(
              l10n.enableNotificationReminderLabel,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            value: notificationEnabled,
            onChanged: widget.readOnly
                ? null
                : (enabled) {
                    if (enabled == true) {
                      widget.onNotificationRelativeTimeChanged(
                        _notificationController.value,
                      );
                    } else {
                      widget.onNotificationRelativeTimeChanged(null);
                    }
                  },
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          if (notificationEnabled) ...[
            Text(
              l10n.notificationWindowLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            RelativeTimeWidget(
              key: const Key(
                'weekly_completion_notification_relative_time_picker',
              ),
              constraint: RelativeTimeConstraint.unconstrained,
              controller: _notificationController,
            ),
          ],
        ],
      ],
    );
  }
}
