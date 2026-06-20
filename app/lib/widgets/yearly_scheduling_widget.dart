import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../logic/civil_day.dart';
import '../logic/relative_time.dart';
import '../logic/scheduling_policy.dart';
import '../logic/missed_occurrence_policy.dart';
import '../logic/l10n_extension.dart';
import 'relative_timing_widget.dart';
import 'missed_occurrence_policy_selector.dart';
import 'absolute_date_widget.dart';

class YearlySchedulingWidget extends StatefulWidget {
  final CivilDay startDate;
  final ValueChanged<CivilDay> onStartDateChanged;
  final int interval;
  final ValueChanged<int> onIntervalChanged;
  final SchedulingPolicy schedulingPolicy;
  final ValueChanged<SchedulingPolicy> onSchedulingPolicyChanged;
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

  const YearlySchedulingWidget({
    super.key,
    required this.startDate,
    required this.onStartDateChanged,
    required this.interval,
    required this.onIntervalChanged,
    required this.schedulingPolicy,
    required this.onSchedulingPolicyChanged,
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
  State<YearlySchedulingWidget> createState() => _YearlySchedulingWidgetState();
}

class _YearlySchedulingWidgetState extends State<YearlySchedulingWidget> {
  late TextEditingController _intervalController;
  late TextEditingController _dayController;
  bool _isIntervalExpanded = false;

  @override
  void initState() {
    super.initState();
    _intervalController =
        widget.intervalController ??
        TextEditingController(text: widget.interval.toString());
    _dayController =
        widget.dayController ??
        TextEditingController(text: widget.day.toString());
  }

  @override
  void didUpdateWidget(YearlySchedulingWidget oldWidget) {
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
  }

  @override
  void dispose() {
    if (widget.intervalController == null) {
      _intervalController.dispose();
    }
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

    final isCompletionRelative =
        widget.schedulingPolicy is CompletionRelativePolicy;

    final summaryText = isCompletionRelative
        ? l10n.everyNYearsSinceLastCompletion(widget.interval)
        : l10n.everyNYearsSinceLastScheduled(widget.interval);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Start Recurrence Date
        AbsoluteDateWidget(
          key: const Key('yearly_start_recurrence_date_tile'),
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
          label: l10n.startRecurrenceDateLabel,
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
                key: const Key('yearly_interval_expansion_tile'),
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
                        key: const Key('yearly_interval_field'),
                        controller: _intervalController,
                        enabled: !widget.readOnly,
                        decoration: InputDecoration(
                          labelText: l10n.yearsIntervalLabel,
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
                                  interval: Duration(days: newInterval * 365),
                                  targetTime: widget.startRelativeTime.time,
                                ),
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<SchedulingType>(
                        key: const Key('yearly_interval_type_dropdown'),
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
                                        days: widget.interval * 365,
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

        // Month and Day selection row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<int>(
                key: const Key('yearly_month_dropdown'),
                initialValue: widget.month,
                decoration: InputDecoration(
                  labelText: l10n.monthLabel,
                  border: const OutlineInputBorder(),
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
                  DropdownMenuItem(value: 9, child: Text(l10n.monthSeptember)),
                  DropdownMenuItem(value: 10, child: Text(l10n.monthOctober)),
                  DropdownMenuItem(value: 11, child: Text(l10n.monthNovember)),
                  DropdownMenuItem(value: 12, child: Text(l10n.monthDecember)),
                ],
                onChanged: widget.readOnly
                    ? null
                    : (value) {
                        if (value != null) {
                          widget.onMonthChanged(value);
                        }
                      },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 1,
              child: TextFormField(
                key: const Key('yearly_day_field'),
                controller: _dayController,
                enabled: !widget.readOnly,
                decoration: InputDecoration(
                  labelText: l10n.dayLabel,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Required';
                  }
                  final dayVal = int.tryParse(value.trim());
                  final maxDays = _maxDaysInMonth(widget.month);
                  if (dayVal == null || dayVal < 1 || dayVal > maxDays) {
                    return '1-$maxDays';
                  }
                  return null;
                },
                onChanged: (val) {
                  final dayVal = int.tryParse(val.trim());
                  final maxDays = _maxDaysInMonth(widget.month);
                  if (dayVal != null && dayVal >= 1 && dayVal <= maxDays) {
                    widget.onDayChanged(dayVal);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Start & Due relative selectors (and notification reminder if showNotification is true)
        RelativeTimingWidget(
          key: const Key('yearly_relative_timing'),
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
            key: const Key('yearly_missed_policy'),
            policy: widget.missedOccurrencePolicy!,
            onChanged: widget.onMissedOccurrencePolicyChanged!,
          ),
        ],
      ],
    );
  }
}
