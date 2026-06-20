import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../logic/civil_day.dart';
import '../logic/relative_time.dart';
import '../logic/scheduling_policy.dart';
import '../logic/missed_occurrence_policy.dart';
import '../logic/l10n_extension.dart';
import 'relative_timing_widget.dart';
import 'missed_occurrence_policy_selector.dart';

class DailySchedulingWidget extends StatefulWidget {
  final CivilDay startDate;
  final ValueChanged<CivilDay> onStartDateChanged;
  final int interval;
  final ValueChanged<int> onIntervalChanged;
  final SchedulingPolicy schedulingPolicy;
  final ValueChanged<SchedulingPolicy> onSchedulingPolicyChanged;
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

  const DailySchedulingWidget({
    super.key,
    required this.startDate,
    required this.onStartDateChanged,
    required this.interval,
    required this.onIntervalChanged,
    required this.schedulingPolicy,
    required this.onSchedulingPolicyChanged,
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
  State<DailySchedulingWidget> createState() => _DailySchedulingWidgetState();
}

class _DailySchedulingWidgetState extends State<DailySchedulingWidget> {
  late TextEditingController _intervalController;
  bool _isIntervalExpanded = false;

  @override
  void initState() {
    super.initState();
    _intervalController =
        widget.intervalController ??
        TextEditingController(text: widget.interval.toString());
  }

  @override
  void didUpdateWidget(DailySchedulingWidget oldWidget) {
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
  }

  @override
  void dispose() {
    if (widget.intervalController == null) {
      _intervalController.dispose();
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
        ? l10n.everyNDaysSinceLastCompletion(widget.interval)
        : l10n.everyNDaysSinceLastScheduled(widget.interval);

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
              key: const Key('start_recurrence_date_tile'),
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
                key: const Key('daily_interval_expansion_tile'),
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
                        key: const Key('daily_interval_field'),
                        controller: _intervalController,
                        enabled: !widget.readOnly,
                        decoration: InputDecoration(
                          labelText: l10n.daysIntervalLabel,
                          border: const OutlineInputBorder(),
                          helperText: l10n.daysIntervalHelper,
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
                                  interval: Duration(days: newInterval),
                                  targetTime: widget.startRelativeTime.time,
                                ),
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<SchedulingType>(
                        key: const Key('daily_interval_type_dropdown'),
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
                                      interval: Duration(days: widget.interval),
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

        // Start & Due relative selectors (and notification reminder if showNotification is true)
        RelativeTimingWidget(
          key: const Key('daily_relative_timing'),
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
            key: const Key('daily_missed_policy'),
            policy: widget.missedOccurrencePolicy!,
            onChanged: widget.onMissedOccurrencePolicyChanged!,
          ),
        ],
      ],
    );
  }
}
