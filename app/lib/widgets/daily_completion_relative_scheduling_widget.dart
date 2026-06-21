import 'package:flutter/material.dart';
import '../logic/relative_time.dart';
import '../logic/l10n_extension.dart';
import 'interval_stepper.dart';
import 'relative_time_widget.dart';

class DailyCompletionRelativeSchedulingWidget extends StatefulWidget {
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

  const DailyCompletionRelativeSchedulingWidget({
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
  State<DailyCompletionRelativeSchedulingWidget> createState() =>
      _DailyCompletionRelativeSchedulingWidgetState();
}

class _DailyCompletionRelativeSchedulingWidgetState
    extends State<DailyCompletionRelativeSchedulingWidget> {
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
  void didUpdateWidget(DailyCompletionRelativeSchedulingWidget oldWidget) {
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
          key: const Key('daily_completion_interval_stepper'),
          interval: widget.interval,
          onIntervalChanged: widget.onIntervalChanged,
          label: 'Interval',
          helperText: l10n.everyNDaysSinceLastCompletion(widget.interval),
          readOnly: widget.readOnly,
          intervalController: widget.intervalController,
        ),
        const SizedBox(height: 20),

        // 2. Start
        Text(
          'Start',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        RelativeTimeWidget(
          key: const Key('daily_completion_start_relative_time_picker'),
          constraint: RelativeTimeConstraint.unconstrained,
          controller: _startController,
        ),
        const SizedBox(height: 16),

        // 3. Due
        Text(
          'Due',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        RelativeTimeWidget(
          key: const Key('daily_completion_due_relative_time_picker'),
          constraint: RelativeTimeConstraint.unconstrained,
          controller: _dueController,
        ),

        // 4. Notifications
        if (widget.showNotification) ...[
          const SizedBox(height: 16),
          const Divider(),
          CheckboxListTile(
            key: const Key('daily_completion_notification_checkbox'),
            title: Text(
              'Enable notification reminder',
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
              'Notification window',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            RelativeTimeWidget(
              key: const Key(
                'daily_completion_notification_relative_time_picker',
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
