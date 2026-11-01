import 'package:flutter/material.dart';

import '../logic/civil_day.dart';
import '../logic/l10n_extension.dart';
import '../logic/relative_time.dart';
import '../logic/task_schedule_rule.dart';
import 'absolute_time_widget.dart';
import 'recurring_schedule_scaffold.dart';

class OneOffSchedulingWidget extends StatefulWidget {
  final ValueNotifier<DateTime> dueDateTime;
  final ValueNotifier<TimeOfDay?>? notificationTimeController;
  final bool showNotification;

  const OneOffSchedulingWidget({
    super.key,
    required this.dueDateTime,
    this.notificationTimeController,
    this.showNotification = true,
  });

  @override
  State<OneOffSchedulingWidget> createState() => _OneOffSchedulingWidgetState();
}

class _OneOffSchedulingWidgetState extends State<OneOffSchedulingWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.dueWithoutColon,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        AbsoluteTimeWidget(controller: widget.dueDateTime),
        const SizedBox(height: 6),
        ScheduleHelpRow(text: context.l10n.dueDescription),
        if (widget.showNotification &&
            widget.notificationTimeController != null) ...[
          const SizedBox(height: 20),
          ValueListenableBuilder<TimeOfDay?>(
            valueListenable: widget.notificationTimeController!,
            builder: (context, notificationTime, _) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const Key('one_off_notification_button'),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime:
                            notificationTime ??
                            TimeOfDay.fromDateTime(widget.dueDateTime.value),
                      );
                      if (picked != null) {
                        widget.notificationTimeController!.value = picked;
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  context.l10n.notificationTimeLabel,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        height: 1.1,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  notificationTime != null
                                      ? notificationTime.format(context)
                                      : context.l10n.noneLabel,
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        height: 1.2,
                                        color: notificationTime != null
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (notificationTime != null) ...[
                                IconButton(
                                  key: const Key('one_off_notification_clear'),
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    widget.notificationTimeController!.value =
                                        null;
                                  },
                                  tooltip:
                                      context.l10n.clearNotificationTimeTooltip,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Icon(
                                notificationTime != null
                                    ? Icons.notifications_active
                                    : Icons.notifications_none,
                                color: notificationTime != null
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                size: 20,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class OneOffScheduleRuleSection extends StatefulWidget {
  final OneOffSchedule schedule;
  final ValueChanged<OneOffSchedule> onChanged;
  final bool showNotification;

  const OneOffScheduleRuleSection({
    super.key,
    required this.schedule,
    required this.onChanged,
    this.showNotification = false,
  });

  @override
  State<OneOffScheduleRuleSection> createState() =>
      _OneOffScheduleRuleSectionState();
}

class _OneOffScheduleRuleSectionState extends State<OneOffScheduleRuleSection> {
  late final ValueNotifier<DateTime> _startController;
  late final ValueNotifier<DateTime> _dueController;
  late final ValueNotifier<TimeOfDay?> _notificationController;
  bool _ignoreControllerEvents = false;

  @override
  void initState() {
    super.initState();
    final s = widget.schedule;
    _startController = ValueNotifier<DateTime>(
      _relativeToAbsolute(s.date, s.startRelativeTime),
    );
    _dueController = ValueNotifier<DateTime>(
      _relativeToAbsolute(s.date, s.dueRelativeTime),
    );
    _notificationController = ValueNotifier<TimeOfDay?>(
      s.notificationRelativeTimes.isNotEmpty
          ? s.notificationRelativeTimes.first.time
          : null,
    );

    _startController.addListener(_onControllersChanged);
    _dueController.addListener(_onControllersChanged);
    _notificationController.addListener(_onControllersChanged);
  }

  void _onControllersChanged() {
    if (_ignoreControllerEvents) return;
    final s = widget.schedule;
    final dueAbs = _dueController.value;

    final newDate = CivilDay.fromDateTime(dueAbs);
    var startAbs = _relativeToAbsolute(newDate, s.startRelativeTime);
    if (startAbs.isAfter(dueAbs)) {
      startAbs = dueAbs;
    }
    if (_startController.value != startAbs) {
      _ignoreControllerEvents = true;
      _startController.value = startAbs;
      _ignoreControllerEvents = false;
    }

    final newStartRel = _absoluteToRelative(newDate, startAbs);
    final newDueRel = _absoluteToRelative(newDate, dueAbs);

    widget.onChanged(
      OneOffSchedule(
        id: s.id,
        scheduleId: s.scheduleId,
        date: newDate,
        startRelativeTime: newStartRel,
        dueRelativeTime: newDueRel,
        notificationRelativeTimes: s.notificationRelativeTimes,
      ),
    );
  }

  @override
  void didUpdateWidget(OneOffScheduleRuleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final s = widget.schedule;
    final startAbs = _relativeToAbsolute(s.date, s.startRelativeTime);
    final dueAbs = _relativeToAbsolute(s.date, s.dueRelativeTime);
    final notifTime = s.notificationRelativeTimes.isNotEmpty
        ? s.notificationRelativeTimes.first.time
        : null;

    _ignoreControllerEvents = true;
    try {
      if (_startController.value != startAbs) {
        _startController.value = startAbs;
      }
      if (_dueController.value != dueAbs) {
        _dueController.value = dueAbs;
      }
      if (_notificationController.value != notifTime) {
        _notificationController.value = notifTime;
      }
    } finally {
      _ignoreControllerEvents = false;
    }
  }

  @override
  void dispose() {
    _startController.removeListener(_onControllersChanged);
    _dueController.removeListener(_onControllersChanged);
    _notificationController.removeListener(_onControllersChanged);
    _startController.dispose();
    _dueController.dispose();
    _notificationController.dispose();
    super.dispose();
  }

  DateTime _relativeToAbsolute(CivilDay occurrenceDate, RelativeTime rel) {
    return rel.referenceTo(occurrenceDate);
  }

  RelativeTime _absoluteToRelative(CivilDay occurrenceDate, DateTime abs) {
    final occUtc = DateTime.utc(
      occurrenceDate.year,
      occurrenceDate.month,
      occurrenceDate.day,
    );
    final absUtc = DateTime.utc(abs.year, abs.month, abs.day);
    final offset = absUtc.difference(occUtc).inDays;
    return RelativeTime(dayOffset: offset, hour: abs.hour, minute: abs.minute);
  }

  @override
  Widget build(BuildContext context) {
    return OneOffSchedulingWidget(
      dueDateTime: _dueController,
      notificationTimeController: _notificationController,
      showNotification: widget.showNotification,
    );
  }
}
