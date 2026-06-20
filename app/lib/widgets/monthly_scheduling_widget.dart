import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../logic/civil_day.dart';
import '../logic/relative_time.dart';
import '../logic/scheduling_policy.dart';
import '../logic/missed_occurrence_policy.dart';
import '../logic/l10n_extension.dart';
import 'relative_timing_widget.dart';
import 'missed_occurrence_policy_selector.dart';

class MonthlySchedulingWidget extends StatefulWidget {
  final CivilDay startDate;
  final ValueChanged<CivilDay> onStartDateChanged;
  final int interval;
  final ValueChanged<int> onIntervalChanged;
  final SchedulingPolicy schedulingPolicy;
  final ValueChanged<SchedulingPolicy> onSchedulingPolicyChanged;
  final String ruleType; // 'dayOfMonth' or 'nthDayOfWeek'
  final ValueChanged<String> onRuleTypeChanged;
  final int? dayOfMonth;
  final ValueChanged<int?> onDayOfMonthChanged;
  final int? occurrence;
  final ValueChanged<int?> onOccurrenceChanged;
  final int? dayOfWeek;
  final ValueChanged<int?> onDayOfWeekChanged;

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

  const MonthlySchedulingWidget({
    super.key,
    required this.startDate,
    required this.onStartDateChanged,
    required this.interval,
    required this.onIntervalChanged,
    required this.schedulingPolicy,
    required this.onSchedulingPolicyChanged,
    required this.ruleType,
    required this.onRuleTypeChanged,
    required this.dayOfMonth,
    required this.onDayOfMonthChanged,
    required this.occurrence,
    required this.onOccurrenceChanged,
    required this.dayOfWeek,
    required this.onDayOfWeekChanged,
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
  State<MonthlySchedulingWidget> createState() =>
      _MonthlySchedulingWidgetState();
}

class _MonthlySchedulingWidgetState extends State<MonthlySchedulingWidget> {
  late TextEditingController _intervalController;
  late TextEditingController _dayOfMonthController;
  bool _isIntervalExpanded = false;

  @override
  void initState() {
    super.initState();
    _intervalController =
        widget.intervalController ??
        TextEditingController(text: widget.interval.toString());
    _dayOfMonthController =
        widget.dayOfMonthController ??
        TextEditingController(text: widget.dayOfMonth?.toString() ?? '1');
  }

  @override
  void didUpdateWidget(MonthlySchedulingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.intervalController == null) {
      if (oldWidget.interval != widget.interval) {
        if (_intervalController.text != widget.interval.toString()) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _intervalController.text = widget.interval.toString();
            }
          });
        }
      }
    }
    if (widget.dayOfMonthController == null) {
      if (oldWidget.dayOfMonth != widget.dayOfMonth) {
        final newText = widget.dayOfMonth?.toString() ?? '1';
        if (_dayOfMonthController.text != newText) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _dayOfMonthController.text = newText;
            }
          });
        }
      }
    }
  }

  @override
  void dispose() {
    if (widget.intervalController == null) {
      _intervalController.dispose();
    }
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

    final isCompletionRelative =
        widget.schedulingPolicy is CompletionRelativePolicy;

    final summaryText = isCompletionRelative
        ? l10n.everyNMonthsSinceLastCompletion(widget.interval)
        : l10n.everyNMonthsSinceLastScheduled(widget.interval);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Start Recurrence Date
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              key: const Key('monthly_start_recurrence_date_tile'),
              dense: true,
              title: Text(
                l10n.startRecurrenceDateLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              subtitle: Text(
                '${widget.startDate.year}-${widget.startDate.month.toString().padLeft(2, '0')}-${widget.startDate.day.toString().padLeft(2, '0')}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              trailing: Icon(
                Icons.calendar_today,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              onTap: widget.readOnly
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dt,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 365),
                        ),
                        lastDate: DateTime.now().add(
                          const Duration(days: 365 * 5),
                        ),
                      );
                      if (picked != null) {
                        widget.onStartDateChanged(
                          CivilDay(
                            year: picked.year,
                            month: picked.month,
                            day: picked.day,
                          ),
                        );
                      }
                    },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Interval expandable card/tile
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          color: Colors.transparent,
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                key: const Key('monthly_interval_expansion_tile'),
                dense: true,
                title: Text(
                  l10n.intervalLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                subtitle: Text(
                  summaryText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: Icon(
                  _isIntervalExpanded ? Icons.expand_less : Icons.expand_more,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                onTap: () {
                  setState(() {
                    _isIntervalExpanded = !_isIntervalExpanded;
                  });
                },
              ),
              if (_isIntervalExpanded) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      TextFormField(
                        key: const Key('monthly_interval_field'),
                        controller: _intervalController,
                        enabled: !widget.readOnly,
                        decoration: InputDecoration(
                          labelText: l10n.monthsIntervalLabel,
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Interval is required';
                          }
                          final interval = int.tryParse(val);
                          if (interval == null || interval <= 0) {
                            return 'Please enter a positive number';
                          }
                          return null;
                        },
                        onChanged: (val) {
                          final newInterval = int.tryParse(val);
                          if (newInterval != null && newInterval > 0) {
                            widget.onIntervalChanged(newInterval);
                            if (isCompletionRelative) {
                              widget.onSchedulingPolicyChanged(
                                CompletionRelativePolicy(
                                  interval: Duration(days: newInterval * 30),
                                  targetTime: widget.startRelativeTime.time,
                                ),
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<SchedulingType>(
                        key: const Key('monthly_interval_type_dropdown'),
                        initialValue: widget.schedulingPolicy.type,
                        decoration: InputDecoration(
                          labelText: l10n.intervalTypeLabel,
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: SchedulingType.fixedCalendar,
                            child: Text(l10n.sinceLastScheduledLabel),
                          ),
                          DropdownMenuItem(
                            value: SchedulingType.completionRelative,
                            child: Text(l10n.sinceLastCompletionLabel),
                          ),
                        ],
                        onChanged: widget.readOnly
                            ? null
                            : (type) {
                                if (type == SchedulingType.completionRelative) {
                                  widget.onSchedulingPolicyChanged(
                                    CompletionRelativePolicy(
                                      interval: Duration(
                                        days: widget.interval * 30,
                                      ),
                                      targetTime: widget.startRelativeTime.time,
                                    ),
                                  );
                                } else {
                                  widget.onSchedulingPolicyChanged(
                                    const FixedCalendarPolicy(),
                                  );
                                }
                              },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Monthly Recurrence Rule
        DropdownButtonFormField<String>(
          key: const Key('monthly_rule_type_dropdown'),
          initialValue: widget.ruleType,
          decoration: InputDecoration(
            labelText: l10n.monthlyRecurrenceTypeLabel,
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(
              value: 'dayOfMonth',
              child: Text(l10n.dayOfMonthLabel),
            ),
            DropdownMenuItem(
              value: 'nthDayOfWeek',
              child: Text(l10n.nthDayOfWeekLabel),
            ),
          ],
          onChanged: widget.readOnly
              ? null
              : (value) {
                  if (value != null) {
                    widget.onRuleTypeChanged(value);
                  }
                },
        ),
        const SizedBox(height: 16),

        // Recurrence Rule Options
        if (widget.ruleType == 'dayOfMonth')
          TextFormField(
            key: const Key('monthly_day_of_month_field'),
            controller: _dayOfMonthController,
            enabled: !widget.readOnly,
            decoration: InputDecoration(
              labelText: l10n.dayOfMonthFieldLabel,
              border: const OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.dayOfMonthValidationError;
              }
              final val = int.tryParse(value.trim());
              if (val == null || val == 0 || val.abs() > 28) {
                return l10n.dayOfMonthValidationError;
              }
              return null;
            },
            onChanged: (val) {
              final value = int.tryParse(val.trim());
              if (value != null && value != 0 && value.abs() <= 28) {
                widget.onDayOfMonthChanged(value);
              }
            },
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: const Key('monthly_occurrence_dropdown'),
                  initialValue: widget.occurrence ?? 1,
                  decoration: InputDecoration(
                    labelText: l10n.nthOccurrenceLabel,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 1,
                      child: Text(l10n.firstOccurrence),
                    ),
                    DropdownMenuItem(
                      value: 2,
                      child: Text(l10n.secondOccurrence),
                    ),
                    DropdownMenuItem(
                      value: 3,
                      child: Text(l10n.thirdOccurrence),
                    ),
                    DropdownMenuItem(
                      value: 4,
                      child: Text(l10n.fourthOccurrence),
                    ),
                    DropdownMenuItem(
                      value: -1,
                      child: Text(l10n.lastOccurrence),
                    ),
                  ],
                  onChanged: widget.readOnly
                      ? null
                      : (value) {
                          if (value != null) {
                            widget.onOccurrenceChanged(value);
                          }
                        },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: const Key('monthly_day_of_week_dropdown'),
                  initialValue: widget.dayOfWeek ?? 1,
                  decoration: InputDecoration(
                    labelText: l10n.dayOfWeekLabel,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(value: 1, child: Text(l10n.weekdayMonday)),
                    DropdownMenuItem(
                      value: 2,
                      child: Text(l10n.weekdayTuesday),
                    ),
                    DropdownMenuItem(
                      value: 3,
                      child: Text(l10n.weekdayWednesday),
                    ),
                    DropdownMenuItem(
                      value: 4,
                      child: Text(l10n.weekdayThursday),
                    ),
                    DropdownMenuItem(value: 5, child: Text(l10n.weekdayFriday)),
                    DropdownMenuItem(
                      value: 6,
                      child: Text(l10n.weekdaySaturday),
                    ),
                    DropdownMenuItem(value: 7, child: Text(l10n.weekdaySunday)),
                  ],
                  onChanged: widget.readOnly
                      ? null
                      : (value) {
                          if (value != null) {
                            widget.onDayOfWeekChanged(value);
                          }
                        },
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),

        // Start & Due relative selectors (and notification reminder if showNotification is true)
        RelativeTimingWidget(
          key: const Key('monthly_relative_timing'),
          startRelativeTime: widget.startRelativeTime,
          dueRelativeTime: widget.dueRelativeTime,
          notificationRelativeTime: widget.notificationRelativeTime,
          onStartChanged: widget.onStartRelativeTimeChanged,
          onDueChanged: widget.onDueRelativeTimeChanged,
          onNotificationChanged: widget.onNotificationRelativeTimeChanged,
          showNotification: widget.showNotification,
        ),

        // Missed occurrence policy selector
        if (widget.showMissedPolicy &&
            widget.missedOccurrencePolicy != null &&
            widget.onMissedOccurrencePolicyChanged != null) ...[
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          MissedOccurrencePolicySelector(
            key: const Key('monthly_missed_policy'),
            policy: widget.missedOccurrencePolicy!,
            onChanged: widget.onMissedOccurrencePolicyChanged!,
          ),
        ],
      ],
    );
  }
}
