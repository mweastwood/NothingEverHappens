import 'package:flutter/material.dart';

import '../logic/civil_day.dart';
import '../logic/relative_time.dart';
import '../logic/missed_occurrence_policy.dart';
import '../logic/l10n_extension.dart';
import 'day_stepper.dart';
import 'recurring_schedule_scaffold.dart';

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
    extends State<YearlyFixedSchedulingWidget>
    with ScheduleTimingControllersMixin {
  late TextEditingController _dayController;

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
    _dayController =
        widget.dayController ??
        TextEditingController(text: widget.day.toString());
  }

  @override
  void didUpdateWidget(YearlyFixedSchedulingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncTimingControllers(
      startRelativeTime: widget.startRelativeTime,
      onStartRelativeTimeChanged: widget.onStartRelativeTimeChanged,
      dueRelativeTime: widget.dueRelativeTime,
      onDueRelativeTimeChanged: widget.onDueRelativeTimeChanged,
      notificationRelativeTime: widget.notificationRelativeTime,
      onNotificationRelativeTimeChanged:
          widget.onNotificationRelativeTimeChanged,
      onExtraSync: () {
        if (widget.dayController == null && oldWidget.day != widget.day) {
          if (_dayController.text != widget.day.toString()) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _dayController.text = widget.day.toString();
              }
            });
          }
        }
      },
    );
  }

  @override
  void dispose() {
    disposeTimingControllers();
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

    return RecurringScheduleScaffold(
      keyPrefix: 'yearly_fixed',
      interval: widget.interval,
      onIntervalChanged: widget.onIntervalChanged,
      unitSingular: l10n.presetYearSingular,
      unitPlural: l10n.presetYearPlural,
      startDate: widget.startDate,
      onStartDateChanged: widget.onStartDateChanged,
      helpText: l10n.repeatsEveryYearHelp(
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
                      DropdownMenuItem(
                        value: 1,
                        child: Text(l10n.monthJanuary),
                      ),
                      DropdownMenuItem(
                        value: 2,
                        child: Text(l10n.monthFebruary),
                      ),
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
                      DropdownMenuItem(
                        value: 10,
                        child: Text(l10n.monthOctober),
                      ),
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
          ScheduleHelpRow(
            text: l10n.yearlyOn(
              _getMonthName(context, widget.month),
              widget.day.toString(),
            ),
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
