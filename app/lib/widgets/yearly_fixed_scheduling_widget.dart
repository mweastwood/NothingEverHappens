import 'package:flutter/material.dart';
import '../logic/civil_day.dart';
import '../logic/relative_time.dart';
import '../logic/missed_occurrence_policy.dart';
import '../logic/l10n_extension.dart';
import 'interval_stepper.dart';
import 'date_stepper.dart';
import 'day_stepper.dart';

import 'schedule_timing_section.dart';
import 'notification_config_section.dart';
import 'missed_occurrence_policy_section.dart';

class YearlyFixedSchedulingWidget extends StatefulWidget {
  final CivilDay startDate;
  final ValueChanged<CivilDay> onStartDateChanged;
  final int interval;
  final ValueChanged<int> onIntervalChanged;
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

  const YearlyFixedSchedulingWidget({
    super.key,
    required this.startDate,
    required this.onStartDateChanged,
    required this.interval,
    required this.onIntervalChanged,
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
  State<YearlyFixedSchedulingWidget> createState() =>
      _YearlyFixedSchedulingWidgetState();
}

class _YearlyFixedSchedulingWidgetState
    extends State<YearlyFixedSchedulingWidget> {
  late final ValueNotifier<RelativeTime> _startController;
  late final ValueNotifier<RelativeTime> _dueController;
  late final ValueNotifier<RelativeTime> _notificationController;
  late TextEditingController _dayController;

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
    _dayController =
        widget.dayController ??
        TextEditingController(text: widget.day.toString());

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
  void didUpdateWidget(YearlyFixedSchedulingWidget oldWidget) {
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
      if (widget.dayController == null) {
        if (oldWidget.day != widget.day) {
          if (_dayController.text != widget.day.toString()) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _dayController.text = widget.day.toString();
              }
            });
          }
        }
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
    if (widget.dayController == null) {
      _dayController.dispose();
    }
    super.dispose();
  }

  int _maxDaysInMonth(int month) {
    switch (month) {
      case 2:
        return 29; // Allow 29 for leap years
      case 4:
      case 6:
      case 9:
      case 11:
        return 30;
      default:
        return 31;
    }
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
                key: const Key('yearly_fixed_interval_stepper'),
                interval: widget.interval,
                onIntervalChanged: widget.onIntervalChanged,
                label: l10n.intervalLabel,
                unitSingular: l10n.presetYearSingular,
                unitPlural: l10n.presetYearPlural,
                readOnly: widget.readOnly,
                intervalController: widget.intervalController,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DateStepper(
                key: const Key('yearly_fixed_date_stepper'),
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
                l10n.repeatsEveryYearHelp(
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

        // Repeats on Section Header
        Text(
          l10n.repeatsOnLabel,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        // Month and Day selection row
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<int>(
                  key: const Key('yearly_month_dropdown'),
                  initialValue: widget.month,
                  decoration: InputDecoration(
                    labelText: l10n.monthLabel,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: [
                    DropdownMenuItem(value: 1, child: Text(l10n.monthJanuary)),
                    DropdownMenuItem(value: 2, child: Text(l10n.monthFebruary)),
                    DropdownMenuItem(value: 3, child: Text(l10n.monthMarch)),
                    DropdownMenuItem(value: 4, child: Text(l10n.monthApril)),
                    DropdownMenuItem(value: 5, child: Text(l10n.monthMay)),
                    DropdownMenuItem(value: 6, child: Text(l10n.monthJune)),
                    DropdownMenuItem(value: 7, child: Text(l10n.monthJuly)),
                    DropdownMenuItem(value: 8, child: Text(l10n.monthAugust)),
                    DropdownMenuItem(
                      value: 9,
                      child: Text(l10n.monthSeptember),
                    ),
                    DropdownMenuItem(value: 10, child: Text(l10n.monthOctober)),
                    DropdownMenuItem(
                      value: 11,
                      child: Text(l10n.monthNovember),
                    ),
                    DropdownMenuItem(
                      value: 12,
                      child: Text(l10n.monthDecember),
                    ),
                  ],
                  onChanged: widget.readOnly
                      ? null
                      : (value) {
                          if (value != null) {
                            final maxDays = _maxDaysInMonth(value);
                            if (widget.day > maxDays) {
                              _dayController.text = maxDays.toString();
                              widget.onDayChanged(maxDays);
                            }
                            widget.onMonthChanged(value);
                          }
                        },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: DayStepper(
                  key: const Key('yearly_day_stepper'),
                  day: widget.day,
                  maxDays: _maxDaysInMonth(widget.month),
                  onDayChanged: widget.onDayChanged,
                  label: l10n.dayLabel,
                  textFieldKey: const Key('yearly_day_field'),
                  rangeErrorText: '1-${_maxDaysInMonth(widget.month)}',
                  readOnly: widget.readOnly,
                  controller: _dayController,
                ),
              ),
            ],
          ),
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
                l10n.yearlyOn(
                  _getMonthName(context, widget.month),
                  widget.day.toString(),
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

        ScheduleTimingSection(
          startController: _startController,
          dueController: _dueController,
          keyPrefix: 'yearly_fixed',
        ),
        NotificationConfigSection(
          showNotification: widget.showNotification,
          notificationEnabled: notificationEnabled,
          readOnly: widget.readOnly,
          notificationController: _notificationController,
          onNotificationRelativeTimeChanged:
              widget.onNotificationRelativeTimeChanged,
          keyPrefix: 'yearly_fixed',
        ),
        MissedOccurrencePolicySection(
          showMissedPolicy: widget.showMissedPolicy,
          missedOccurrencePolicy: widget.missedOccurrencePolicy,
          onMissedOccurrencePolicyChanged:
              widget.onMissedOccurrencePolicyChanged,
          keyPrefix: 'yearly_fixed',
        ),
      ],
    );
  }
}

String _getMonthName(BuildContext context, int month) {
  final l10n = context.l10n;
  switch (month) {
    case 1:
      return l10n.monthJanuary;
    case 2:
      return l10n.monthFebruary;
    case 3:
      return l10n.monthMarch;
    case 4:
      return l10n.monthApril;
    case 5:
      return l10n.monthMay;
    case 6:
      return l10n.monthJune;
    case 7:
      return l10n.monthJuly;
    case 8:
      return l10n.monthAugust;
    case 9:
      return l10n.monthSeptember;
    case 10:
      return l10n.monthOctober;
    case 11:
      return l10n.monthNovember;
    case 12:
      return l10n.monthDecember;
    default:
      return '';
  }
}
