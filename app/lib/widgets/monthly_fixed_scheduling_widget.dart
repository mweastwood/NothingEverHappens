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

class MonthlyFixedSchedulingWidget extends StatefulWidget {
  final CivilDay startDate;
  final ValueChanged<CivilDay> onStartDateChanged;
  final int interval;
  final ValueChanged<int> onIntervalChanged;
  final int? dayOfMonth;
  final ValueChanged<int?> onDayOfMonthChanged;
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

  const MonthlyFixedSchedulingWidget({
    super.key,
    required this.startDate,
    required this.onStartDateChanged,
    required this.interval,
    required this.onIntervalChanged,
    required this.dayOfMonth,
    required this.onDayOfMonthChanged,
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
  State<MonthlyFixedSchedulingWidget> createState() =>
      _MonthlyFixedSchedulingWidgetState();
}

class _MonthlyFixedSchedulingWidgetState
    extends State<MonthlyFixedSchedulingWidget> {
  late final ValueNotifier<RelativeTime> _startController;
  late final ValueNotifier<RelativeTime> _dueController;
  late final ValueNotifier<RelativeTime> _notificationController;
  late TextEditingController _dayOfMonthController;
  late bool _fromStart;

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
    final initialDay = widget.dayOfMonth ?? 1;
    _fromStart = initialDay > 0;
    _dayOfMonthController =
        widget.dayOfMonthController ??
        TextEditingController(text: initialDay.abs().toString());

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
  void didUpdateWidget(MonthlyFixedSchedulingWidget oldWidget) {
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
      if (widget.dayOfMonth != oldWidget.dayOfMonth) {
        _fromStart = (widget.dayOfMonth ?? 1) > 0;
        if (widget.dayOfMonthController == null) {
          final newText = (widget.dayOfMonth ?? 1).abs().toString();
          if (_dayOfMonthController.text != newText) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _dayOfMonthController.text = newText;
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
    if (widget.dayOfMonthController == null) {
      _dayOfMonthController.dispose();
    }
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
                key: const Key('monthly_fixed_interval_stepper'),
                interval: widget.interval,
                onIntervalChanged: widget.onIntervalChanged,
                label: l10n.intervalLabel,
                unitSingular: l10n.presetMonthSingular,
                unitPlural: l10n.presetMonthPlural,
                readOnly: widget.readOnly,
                intervalController: widget.intervalController,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DateStepper(
                key: const Key('monthly_fixed_date_stepper'),
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
                l10n.repeatsEveryMonthHelp(
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

        // Monthly Recurrence Rule
        Text(
          l10n.repeatsOnLabel,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        // Recurrence Rule Options
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: DayStepper(
                  key: const Key('monthly_day_of_month_stepper'),
                  day: (widget.dayOfMonth ?? 1).abs(),
                  maxDays: 28,
                  onDayChanged: (val) {
                    widget.onDayOfMonthChanged(_fromStart ? val : -val);
                  },
                  label: l10n.dayOfMonthStepperLabel,
                  textFieldKey: const Key('day_text_field'),
                  rangeErrorText: 'Enter 1-28',
                  suffixBuilder: getOrdinalDaySuffix,
                  readOnly: widget.readOnly,
                  controller: _dayOfMonthController,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _DirectionSelector(
                  key: const Key('monthly_direction_selector'),
                  fromStart: _fromStart,
                  onChanged: widget.readOnly
                      ? null
                      : (val) {
                          setState(() {
                            _fromStart = val;
                          });
                          final currentAbsVal = (widget.dayOfMonth ?? 1).abs();
                          widget.onDayOfMonthChanged(
                            val ? currentAbsVal : -currentAbsVal,
                          );
                        },
                  readOnly: widget.readOnly,
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
                _fromStart
                    ? l10n.repeatsOnDayOfMonthHelp(
                        _formatDayText((widget.dayOfMonth ?? 1).abs()),
                      )
                    : (() {
                        final val = widget.dayOfMonth ?? -1;
                        if (val == -1) {
                          return 'Repeats on the last day of the month.';
                        } else if (val == -2) {
                          return 'Repeats on the 2nd to the last day of the month.';
                        } else {
                          return 'Repeats ${val.abs() - 1} days before the last day of the month.';
                        }
                      })(),
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
          keyPrefix: 'monthly_fixed',
        ),
        NotificationConfigSection(
          showNotification: widget.showNotification,
          notificationEnabled: notificationEnabled,
          readOnly: widget.readOnly,
          notificationController: _notificationController,
          onNotificationRelativeTimeChanged:
              widget.onNotificationRelativeTimeChanged,
          keyPrefix: 'monthly_fixed',
        ),
        MissedOccurrencePolicySection(
          showMissedPolicy: widget.showMissedPolicy,
          missedOccurrencePolicy: widget.missedOccurrencePolicy,
          onMissedOccurrencePolicyChanged:
              widget.onMissedOccurrencePolicyChanged,
          keyPrefix: 'monthly_fixed',
        ),
      ],
    );
  }
}

String _formatDayText(int val) => '${val.abs()}${getOrdinalDaySuffix(val)}';

class _DirectionSelector extends StatelessWidget {
  final bool fromStart;
  final ValueChanged<bool>? onChanged;
  final bool readOnly;

  const _DirectionSelector({
    super.key,
    required this.fromStart,
    required this.onChanged,
    required this.readOnly,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    final options = [
      (true, l10n.monthlyFromStart),
      (false, l10n.monthlyFromEnd),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: options.map((option) {
        final value = option.$1;
        final label = option.$2;
        final isSelected = fromStart == value;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Material(
              color: isSelected
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                key: Key('monthly_direction_chip_${value ? 'start' : 'end'}'),
                onTap: readOnly || onChanged == null
                    ? null
                    : () {
                        if (!isSelected) {
                          onChanged!(value);
                        }
                      },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurface,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
