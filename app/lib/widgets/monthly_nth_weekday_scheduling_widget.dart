import 'package:flutter/material.dart';

import '../logic/civil_day.dart';
import '../logic/relative_time.dart';
import '../logic/missed_occurrence_policy.dart';
import '../logic/l10n_extension.dart';
import 'day_of_week_selector.dart';
import 'recurring_schedule_scaffold.dart';

class MonthlyNthWeekdaySchedulingWidget extends StatefulWidget {
  final CivilDay startDate;
  final ValueChanged<CivilDay> onStartDateChanged;
  final int interval;
  final ValueChanged<int> onIntervalChanged;
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

  const MonthlyNthWeekdaySchedulingWidget({
    super.key,
    required this.startDate,
    required this.onStartDateChanged,
    required this.interval,
    required this.onIntervalChanged,
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
  });

  @override
  State<MonthlyNthWeekdaySchedulingWidget> createState() =>
      _MonthlyNthWeekdaySchedulingWidgetState();
}

class _MonthlyNthWeekdaySchedulingWidgetState
    extends State<MonthlyNthWeekdaySchedulingWidget>
    with ScheduleTimingControllersMixin {
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
  }

  @override
  void didUpdateWidget(MonthlyNthWeekdaySchedulingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncTimingControllers(
      startRelativeTime: widget.startRelativeTime,
      onStartRelativeTimeChanged: widget.onStartRelativeTimeChanged,
      dueRelativeTime: widget.dueRelativeTime,
      onDueRelativeTimeChanged: widget.onDueRelativeTimeChanged,
      notificationRelativeTime: widget.notificationRelativeTime,
      onNotificationRelativeTimeChanged:
          widget.onNotificationRelativeTimeChanged,
    );
  }

  @override
  void dispose() {
    disposeTimingControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return RecurringScheduleScaffold(
      keyPrefix: 'monthly_fixed',
      headerKeyPrefix: 'monthly_nth_weekday',
      interval: widget.interval,
      onIntervalChanged: widget.onIntervalChanged,
      unitSingular: l10n.presetMonthSingular,
      unitPlural: l10n.presetMonthPlural,
      startDate: widget.startDate,
      onStartDateChanged: widget.onStartDateChanged,
      helpText: l10n.repeatsEveryMonthHelp(
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
          _OccurrenceSelector(
            key: const Key('monthly_occurrence_selector'),
            selectedOccurrence: widget.occurrence ?? 1,
            onChanged: (val) {
              widget.onOccurrenceChanged(val);
            },
            readOnly: widget.readOnly,
          ),
          const SizedBox(height: 12),
          DayOfWeekSelector(
            key: const Key('monthly_nth_weekday_day_selector'),
            selectedWeekdays: {widget.dayOfWeek ?? 1},
            onChanged: (days) {
              if (days.isNotEmpty) {
                widget.onDayOfWeekChanged(days.first);
              }
            },
            readOnly: widget.readOnly,
            multiSelect: false,
          ),
          const SizedBox(height: 8),
          ScheduleHelpRow(
            text: l10n.repeatsOnNthWeekdayHelp(
              _getDayOfWeekString(context, widget.dayOfWeek ?? 1),
              _getOccurrenceString(
                context,
                widget.occurrence ?? 1,
              ).toLowerCase(),
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

String _getOccurrenceString(BuildContext context, int occurrence) {
  final l10n = context.l10n;
  switch (occurrence) {
    case 1:
      return l10n.firstOccurrence;
    case 2:
      return l10n.secondOccurrence;
    case 3:
      return l10n.thirdOccurrence;
    case 4:
      return l10n.fourthOccurrence;
    case -1:
      return l10n.lastOccurrence;
    default:
      return '';
  }
}

String _getDayOfWeekString(BuildContext context, int dayOfWeek) {
  final l10n = context.l10n;
  switch (dayOfWeek) {
    case 1:
      return l10n.weekdayMonday;
    case 2:
      return l10n.weekdayTuesday;
    case 3:
      return l10n.weekdayWednesday;
    case 4:
      return l10n.weekdayThursday;
    case 5:
      return l10n.weekdayFriday;
    case 6:
      return l10n.weekdaySaturday;
    case 7:
      return l10n.weekdaySunday;
    default:
      return '';
  }
}

class _OccurrenceSelector extends StatelessWidget {
  final int selectedOccurrence;
  final ValueChanged<int> onChanged;
  final bool readOnly;

  const _OccurrenceSelector({
    super.key,
    required this.selectedOccurrence,
    required this.onChanged,
    required this.readOnly,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    final options = [
      (1, l10n.firstOccurrence),
      (2, l10n.secondOccurrence),
      (3, l10n.thirdOccurrence),
      (4, l10n.fourthOccurrence),
      (-1, l10n.lastOccurrence),
    ];

    return Row(
      children: options.map((option) {
        final value = option.$1;
        final label = option.$2;
        final isSelected = selectedOccurrence == value;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Material(
              color: isSelected
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: readOnly
                    ? null
                    : () {
                        if (!isSelected) {
                          onChanged(value);
                        }
                      },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
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
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurface,
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
