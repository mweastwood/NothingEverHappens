import 'package:flutter/material.dart';
import '../logic/civil_day.dart';
import '../logic/relative_time.dart';
import '../logic/missed_occurrence_policy.dart';
import '../logic/l10n_extension.dart';
import 'interval_stepper.dart';
import 'date_stepper.dart';
import 'missed_occurrence_policy_section.dart';
import 'notification_config_section.dart';
import 'schedule_timing_section.dart';

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

class _DailyFixedSchedulingWidgetState
    extends State<DailyFixedSchedulingWidget> {
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
          const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
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
  void didUpdateWidget(DailyFixedSchedulingWidget oldWidget) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1 & 2. Interval and Start Recurrence Date side-by-side
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: IntervalStepper(
                key: const Key('daily_fixed_interval_stepper'),
                interval: widget.interval,
                onIntervalChanged: widget.onIntervalChanged,
                label: l10n.intervalLabel,
                unitSingular: l10n.presetDaySingular,
                unitPlural: l10n.presetDayPlural,
                readOnly: widget.readOnly,
                intervalController: widget.intervalController,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DateStepper(
                key: const Key('daily_fixed_date_stepper'),
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
                l10n.repeatsEveryDayHelp(
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

        // 3 & 4. Start & Due Windows
        ScheduleTimingSection(
          keyPrefix: 'daily_fixed',
          startController: _startController,
          dueController: _dueController,
        ),

        // 5. Notifications
        NotificationConfigSection(
          keyPrefix: 'daily_fixed',
          showNotification: widget.showNotification,
          notificationEnabled: widget.notificationRelativeTime != null,
          onNotificationRelativeTimeChanged:
              widget.onNotificationRelativeTimeChanged,
          notificationController: _notificationController,
          readOnly: widget.readOnly,
        ),

        // 6. Missed occurrence policy selector
        MissedOccurrencePolicySection(
          keyPrefix: 'daily_fixed',
          showMissedPolicy: widget.showMissedPolicy,
          missedOccurrencePolicy: widget.missedOccurrencePolicy,
          onMissedOccurrencePolicyChanged:
              widget.onMissedOccurrencePolicyChanged,
        ),
      ],
    );
  }
}
