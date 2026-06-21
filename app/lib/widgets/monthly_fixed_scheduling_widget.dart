import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../logic/civil_day.dart';
import '../logic/relative_time.dart';
import '../logic/missed_occurrence_policy.dart';
import '../logic/l10n_extension.dart';
import 'interval_stepper.dart';
import 'date_stepper.dart';
import 'relative_time_widget.dart';
import 'missed_occurrence_policy_selector.dart';

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
          const RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 9, minute: 0)),
    );
    final initialDay = widget.dayOfMonth ?? 1;
    _fromStart = initialDay > 0;
    _dayOfMonthController =
        widget.dayOfMonthController ??
        TextEditingController(text: _formatDayText(initialDay.abs()));

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
          final newText = _formatDayText((widget.dayOfMonth ?? 1).abs());
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
                label: 'Interval',
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
                label: 'Start Date',
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
                widget.interval == 1
                    ? 'Repeats every month starting ${widget.startDate.year}-${widget.startDate.month.toString().padLeft(2, '0')}-${widget.startDate.day.toString().padLeft(2, '0')}.'
                    : 'Repeats every ${widget.interval} months starting ${widget.startDate.year}-${widget.startDate.month.toString().padLeft(2, '0')}-${widget.startDate.day.toString().padLeft(2, '0')}.',
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Direction',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<bool>(
                    key: const Key('monthly_direction_segmented_button'),
                    segments: [
                      ButtonSegment<bool>(
                        value: true,
                        label: Text(
                          l10n.monthlyFromStart,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      ButtonSegment<bool>(
                        value: false,
                        label: Text(
                          l10n.monthlyFromEnd,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                    selected: {_fromStart},
                    onSelectionChanged: widget.readOnly
                        ? null
                        : (Set<bool> selection) {
                            if (selection.isNotEmpty) {
                              final fromStart = selection.first;
                              setState(() {
                                _fromStart = fromStart;
                              });
                              final currentAbsVal = (widget.dayOfMonth ?? 1)
                                  .abs();
                              widget.onDayOfMonthChanged(
                                fromStart ? currentAbsVal : -currentAbsVal,
                              );
                            }
                          },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 140,
              child: _DayOfMonthStepper(
                key: const Key('monthly_day_of_month_stepper'),
                day: (widget.dayOfMonth ?? 1).abs(),
                onDayChanged: (val) {
                  widget.onDayOfMonthChanged(_fromStart ? val : -val);
                },
                label: l10n.dayOfMonthStepperLabel,
                readOnly: widget.readOnly,
                controller: _dayOfMonthController,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Start
        Text(
          'Start',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        RelativeTimeWidget(
          key: const Key('monthly_fixed_start_relative_time_picker'),
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
                'When does the task appear in your list of tasks?',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Due
        Text(
          'Due',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        RelativeTimeWidget(
          key: const Key('monthly_fixed_due_relative_time_picker'),
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

        // Notifications
        if (widget.showNotification) ...[
          const SizedBox(height: 16),
          const Divider(),
          CheckboxListTile(
            key: const Key('monthly_fixed_notification_checkbox'),
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
              key: const Key('monthly_fixed_notification_relative_time_picker'),
              constraint: RelativeTimeConstraint.unconstrained,
              controller: _notificationController,
            ),
          ],
        ],

        // Missed occurrence policy selector
        if (widget.showMissedPolicy &&
            widget.missedOccurrencePolicy != null &&
            widget.onMissedOccurrencePolicyChanged != null) ...[
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          MissedOccurrencePolicySelector(
            key: const Key('monthly_fixed_missed_policy'),
            policy: widget.missedOccurrencePolicy!,
            onChanged: widget.onMissedOccurrencePolicyChanged!,
          ),
        ],
      ],
    );
  }
}

String _formatDayText(int val) {
  if (val >= 11 && val <= 13) {
    return '${val}th';
  }
  switch (val % 10) {
    case 1:
      return '${val}st';
    case 2:
      return '${val}nd';
    case 3:
      return '${val}rd';
    default:
      return '${val}th';
  }
}

class _DayOfMonthStepper extends StatefulWidget {
  final int day;
  final ValueChanged<int> onDayChanged;
  final String label;
  final bool readOnly;
  final TextEditingController? controller;

  const _DayOfMonthStepper({
    super.key,
    required this.day,
    required this.onDayChanged,
    required this.label,
    this.readOnly = false,
    this.controller,
  });

  @override
  State<_DayOfMonthStepper> createState() => _DayOfMonthStepperState();
}

class _DayOfMonthStepperState extends State<_DayOfMonthStepper> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    final initialText = _formatDayText(widget.day);
    _controller = widget.controller ?? TextEditingController(text: initialText);
    if (widget.controller == null) {
      _controller.text = initialText;
    }

    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      final digits = _controller.text.replaceAll(RegExp(r'\D'), '');
      _controller.text = digits;
    } else {
      final digits = _controller.text.replaceAll(RegExp(r'\D'), '');
      var parsed = int.tryParse(digits) ?? widget.day;
      if (parsed < 1) parsed = 1;
      if (parsed > 28) parsed = 28;
      _controller.text = _formatDayText(parsed);
      if (parsed != widget.day) {
        widget.onDayChanged(parsed);
      }
    }
  }

  @override
  void didUpdateWidget(_DayOfMonthStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.day != widget.day) {
      final expectedText = _focusNode.hasFocus
          ? widget.day.toString()
          : _formatDayText(widget.day);
      if (_controller.text != expectedText) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _controller.text != expectedText) {
            _controller.text = expectedText;
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: EdgeInsets.zero,
            child: Row(
              children: [
                IconButton(
                  key: const Key('day_decrement_button'),
                  icon: const Icon(Icons.remove),
                  onPressed: widget.readOnly || widget.day <= 1
                      ? null
                      : () {
                          final newVal = widget.day - 1;
                          _controller.text = _focusNode.hasFocus
                              ? newVal.toString()
                              : _formatDayText(newVal);
                          widget.onDayChanged(newVal);
                        },
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  constraints: const BoxConstraints(),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        TextFormField(
                          key: const Key('day_text_field'),
                          controller: _controller,
                          focusNode: _focusNode,
                          enabled: !widget.readOnly,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Required';
                            }
                            final digits = val.replaceAll(RegExp(r'\D'), '');
                            final parsed = int.tryParse(digits);
                            if (parsed == null || parsed < 1 || parsed > 28) {
                              return 'Enter 1-28';
                            }
                            return null;
                          },
                          onChanged: (val) {
                            final digits = val.replaceAll(RegExp(r'\D'), '');
                            final parsed = int.tryParse(digits);
                            if (parsed != null && parsed >= 1 && parsed <= 28) {
                              widget.onDayChanged(parsed);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('day_increment_button'),
                  icon: const Icon(Icons.add),
                  onPressed: widget.readOnly || widget.day >= 28
                      ? null
                      : () {
                          final newVal = widget.day + 1;
                          _controller.text = _focusNode.hasFocus
                              ? newVal.toString()
                              : _formatDayText(newVal);
                          widget.onDayChanged(newVal);
                        },
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
