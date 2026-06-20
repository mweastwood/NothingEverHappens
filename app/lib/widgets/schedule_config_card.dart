import 'package:flutter/material.dart';
import '../logic/civil_day.dart';
import '../logic/relative_time.dart';
import '../logic/task_schedule_rule.dart';
import '../logic/scheduling_policy.dart';
import 'daily_scheduling_widget.dart';
import 'weekly_scheduling_widget.dart';
import 'monthly_scheduling_widget.dart';
import 'yearly_scheduling_widget.dart';
import 'one_off_scheduling_widget.dart';
import 'recurrence_type_selector.dart';

class ScheduleConfigCard extends StatefulWidget {
  final TaskScheduleRule schedule;
  final ValueChanged<TaskScheduleRule> onChanged;
  final VoidCallback? onDelete;
  final bool isExpanded;
  final ValueChanged<bool> onExpansionChanged;

  const ScheduleConfigCard({
    super.key,
    required this.schedule,
    required this.onChanged,
    this.onDelete,
    required this.isExpanded,
    required this.onExpansionChanged,
  });

  @override
  State<ScheduleConfigCard> createState() => _ScheduleConfigCardState();
}

class _ScheduleConfigCardState extends State<ScheduleConfigCard> {
  late TextEditingController _intervalController;
  late TextEditingController _monthlyDayOfMonthController;
  late TextEditingController _yearlyDayController;

  late ValueNotifier<DateTime> _oneOffStartController;
  late ValueNotifier<DateTime> _oneOffDueController;
  late ValueNotifier<TimeOfDay?> _oneOffNotificationController;
  bool _ignoreControllerEvents = false;

  @override
  void initState() {
    super.initState();
    _intervalController = TextEditingController(text: _getIntervalText());
    _monthlyDayOfMonthController = TextEditingController(
      text: _getMonthlyDayOfMonthText(),
    );
    _yearlyDayController = TextEditingController(text: _getYearlyDayText());

    final s = widget.schedule;
    final initialStart = s is OneOffSchedule
        ? _relativeToAbsolute(s.date, s.startRelativeTime)
        : DateTime.now();
    final initialDue = s is OneOffSchedule
        ? _relativeToAbsolute(s.date, s.dueRelativeTime)
        : DateTime.now();
    final initialNotif =
        s is OneOffSchedule && s.notificationRelativeTime != null
        ? s.notificationRelativeTime!.time
        : null;

    _oneOffStartController = ValueNotifier<DateTime>(initialStart);
    _oneOffDueController = ValueNotifier<DateTime>(initialDue);
    _oneOffNotificationController = ValueNotifier<TimeOfDay?>(initialNotif);

    _oneOffStartController.addListener(_onOneOffControllersChanged);
    _oneOffDueController.addListener(_onOneOffControllersChanged);
    _oneOffNotificationController.addListener(_onOneOffControllersChanged);
  }

  void _onOneOffControllersChanged() {
    if (_ignoreControllerEvents) return;
    final s = widget.schedule;
    if (s is OneOffSchedule) {
      final startAbs = _oneOffStartController.value;
      final dueAbs = _oneOffDueController.value;
      final notifTime = _oneOffNotificationController.value;

      final newDate = CivilDay.fromDateTime(dueAbs);
      final newStartRel = _absoluteToRelative(newDate, startAbs);
      final newDueRel = _absoluteToRelative(newDate, dueAbs);
      final newNotifRel = notifTime != null
          ? _absoluteToRelative(
              newDate,
              DateTime(
                newDate.year,
                newDate.month,
                newDate.day,
                notifTime.hour,
                notifTime.minute,
              ),
            )
          : null;

      widget.onChanged(
        OneOffSchedule(
          date: newDate,
          startRelativeTime: newStartRel,
          dueRelativeTime: newDueRel,
          notificationRelativeTime: newNotifRel,
        ),
      );
    }
  }

  @override
  void dispose() {
    _intervalController.dispose();
    _monthlyDayOfMonthController.dispose();
    _yearlyDayController.dispose();
    _oneOffStartController.removeListener(_onOneOffControllersChanged);
    _oneOffDueController.removeListener(_onOneOffControllersChanged);
    _oneOffNotificationController.removeListener(_onOneOffControllersChanged);
    _oneOffStartController.dispose();
    _oneOffDueController.dispose();
    _oneOffNotificationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ScheduleConfigCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schedule.runtimeType != widget.schedule.runtimeType ||
        _getIntervalText() != _intervalController.text) {
      final intervalText = _getIntervalText();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _intervalController.text = intervalText;
        }
      });
    }
    final monthlyDayText = _getMonthlyDayOfMonthText();
    if (monthlyDayText != _monthlyDayOfMonthController.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _monthlyDayOfMonthController.text = monthlyDayText;
        }
      });
    }
    final yearlyDayText = _getYearlyDayText();
    if (yearlyDayText != _yearlyDayController.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _yearlyDayController.text = yearlyDayText;
        }
      });
    }
    if (widget.schedule is OneOffSchedule) {
      final s = widget.schedule as OneOffSchedule;
      final startAbs = _relativeToAbsolute(s.date, s.startRelativeTime);
      final dueAbs = _relativeToAbsolute(s.date, s.dueRelativeTime);
      final notifTime = s.notificationRelativeTime?.time;

      _ignoreControllerEvents = true;
      if (_oneOffStartController.value != startAbs) {
        _oneOffStartController.value = startAbs;
      }
      if (_oneOffDueController.value != dueAbs) {
        _oneOffDueController.value = dueAbs;
      }
      if (_oneOffNotificationController.value != notifTime) {
        _oneOffNotificationController.value = notifTime;
      }
      _ignoreControllerEvents = false;
    }
  }

  String _getIntervalText() {
    final s = widget.schedule;
    if (s is DailySchedule) return s.interval.toString();
    if (s is WeeklySchedule) return s.interval.toString();
    if (s is MonthlySchedule) return s.interval.toString();
    if (s is YearlySchedule) return s.interval.toString();
    return '1';
  }

  String _getMonthlyDayOfMonthText() {
    final s = widget.schedule;
    if (s is MonthlySchedule && s.dayOfMonth != null) {
      return s.dayOfMonth.toString();
    }
    return '1';
  }

  String _getYearlyDayText() {
    final s = widget.schedule;
    if (s is YearlySchedule) {
      return s.day.toString();
    }
    return '1';
  }

  (int, String) _getCompletionRelativeValueAndUnit(Duration duration) {
    if (duration.inMinutes == 0) return (0, 'day(s)');
    if (duration.inMinutes % (7 * 24 * 60) == 0) {
      return (duration.inDays ~/ 7, 'week(s)');
    }
    if (duration.inMinutes % (24 * 60) == 0) {
      return (duration.inDays, 'day(s)');
    }
    return (duration.inHours, 'hour(s)');
  }

  String _getSummaryText(TaskScheduleRule schedule) {
    if (schedule.schedulingPolicy is CompletionRelativePolicy) {
      final policy = schedule.schedulingPolicy as CompletionRelativePolicy;
      final (val, unit) = _getCompletionRelativeValueAndUnit(policy.interval);
      final timeStr = policy.targetTime.format(context);
      return 'Completion-relative: every $val $unit @ $timeStr';
    }
    if (schedule is OneOffSchedule) {
      return 'One-off on ${schedule.date.year}-${schedule.date.month.toString().padLeft(2, '0')}-${schedule.date.day.toString().padLeft(2, '0')}';
    } else if (schedule is DailySchedule) {
      return 'Daily, every ${schedule.interval} day(s)';
    } else if (schedule is WeeklySchedule) {
      final days = schedule.daysOfWeek
          .map((d) {
            final labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
            return labels[d - 1];
          })
          .join(', ');
      return 'Weekly, every ${schedule.interval} week(s) on $days';
    } else if (schedule is MonthlySchedule) {
      if (schedule.dayOfMonth != null) {
        return 'Monthly, every ${schedule.interval} month(s) on day ${schedule.dayOfMonth}';
      } else {
        final occurrenceLabel = schedule.occurrence == -1
            ? 'last'
            : 'nth ${schedule.occurrence}';
        final labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final weekdayLabel = labels[schedule.dayOfWeek! - 1];
        return 'Monthly, every ${schedule.interval} month(s) on $occurrenceLabel $weekdayLabel';
      }
    } else if (schedule is YearlySchedule) {
      final monthLabels = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return 'Yearly, every ${schedule.interval} year(s) on ${monthLabels[schedule.month - 1]} ${schedule.day}';
    }
    return 'Custom schedule';
  }

  IconData _getIcon(TaskScheduleRule schedule) {
    if (schedule.schedulingPolicy is CompletionRelativePolicy) {
      return Icons.replay;
    }
    if (schedule is OneOffSchedule) return Icons.event;
    if (schedule is DailySchedule) return Icons.today;
    if (schedule is WeeklySchedule) return Icons.calendar_view_week;
    if (schedule is MonthlySchedule) return Icons.calendar_view_month;
    if (schedule is YearlySchedule) return Icons.calendar_today;
    return Icons.schedule;
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
    return RelativeTime(
      dayOffset: offset,
      time: TimeOfDay(hour: abs.hour, minute: abs.minute),
    );
  }

  void _changeRecurrenceType(RecurrenceType type) {
    final current = widget.schedule;

    TaskScheduleRule next;
    switch (type) {
      case RecurrenceType.oneOff:
        next = OneOffSchedule(
          date: current.scheduledDate,
          startRelativeTime: current.startRelativeTime,
          dueRelativeTime: current.dueRelativeTime,
          notificationRelativeTime: current.notificationRelativeTime,
        );
        break;
      case RecurrenceType.daily:
        next = DailySchedule(
          startDate: current.scheduledDate,
          interval: 1,
          startRelativeTime: current.startRelativeTime,
          dueRelativeTime: current.dueRelativeTime,
          notificationRelativeTime: current.notificationRelativeTime,
        );
        break;
      case RecurrenceType.weekly:
        next = WeeklySchedule(
          startDate: current.scheduledDate,
          interval: 1,
          daysOfWeek: {current.scheduledDate.toUtcDateTime().weekday},
          startRelativeTime: current.startRelativeTime,
          dueRelativeTime: current.dueRelativeTime,
          notificationRelativeTime: current.notificationRelativeTime,
        );
        break;
      case RecurrenceType.monthly:
        next = MonthlySchedule(
          startDate: current.scheduledDate,
          interval: 1,
          dayOfMonth: current.scheduledDate.day <= 28
              ? current.scheduledDate.day
              : 28,
          startRelativeTime: current.startRelativeTime,
          dueRelativeTime: current.dueRelativeTime,
          notificationRelativeTime: current.notificationRelativeTime,
        );
        break;
      case RecurrenceType.yearly:
        next = YearlySchedule(
          startDate: current.scheduledDate,
          interval: 1,
          month: current.scheduledDate.month,
          day: current.scheduledDate.day,
          startRelativeTime: current.startRelativeTime,
          dueRelativeTime: current.dueRelativeTime,
          notificationRelativeTime: current.notificationRelativeTime,
        );
        break;
    }
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = widget.schedule;
    final summary = _getSummaryText(s);
    final icon = _getIcon(s);

    final recurrenceType = s is OneOffSchedule
        ? RecurrenceType.oneOff
        : s is DailySchedule
        ? RecurrenceType.daily
        : s is WeeklySchedule
        ? RecurrenceType.weekly
        : s is MonthlySchedule
        ? RecurrenceType.monthly
        : RecurrenceType.yearly;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.only(left: 4, right: 4, bottom: 12),
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: Icon(icon, color: theme.colorScheme.primary),
            title: Text(
              summary,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.onDelete != null)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    onPressed: widget.onDelete,
                    tooltip: 'Delete Schedule',
                  ),
                IconButton(
                  icon: Icon(
                    widget.isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                  ),
                  onPressed: () =>
                      widget.onExpansionChanged(!widget.isExpanded),
                ),
              ],
            ),
          ),
          if (widget.isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RecurrenceTypeSelector(
                    selectedValue: recurrenceType,
                    onSelected: _changeRecurrenceType,
                  ),
                  const SizedBox(height: 16),
                  if (s is DailySchedule) ...[
                    DailySchedulingWidget(
                      startDate: s.startDate,
                      onStartDateChanged: (date) {
                        widget.onChanged(s.copyWithStartDate(date));
                      },
                      interval: s.interval,
                      onIntervalChanged: (val) {
                        widget.onChanged(
                          DailySchedule(
                            startDate: s.startDate,
                            interval: val,
                            startRelativeTime: s.startRelativeTime,
                            dueRelativeTime: s.dueRelativeTime,
                            notificationRelativeTime:
                                s.notificationRelativeTime,
                            schedulingPolicy: s.schedulingPolicy,
                            missedOccurrencePolicy: s.missedOccurrencePolicy,
                          ),
                        );
                      },
                      schedulingPolicy: s.schedulingPolicy,
                      onSchedulingPolicyChanged: (policy) {
                        widget.onChanged(
                          s.copyWithTiming(schedulingPolicy: policy),
                        );
                      },
                      startRelativeTime: s.startRelativeTime,
                      onStartRelativeTimeChanged: (start) {
                        widget.onChanged(
                          s.copyWithTiming(startRelativeTime: start),
                        );
                      },
                      dueRelativeTime: s.dueRelativeTime,
                      onDueRelativeTimeChanged: (due) {
                        widget.onChanged(
                          s.copyWithTiming(dueRelativeTime: due),
                        );
                      },
                      notificationRelativeTime: s.notificationRelativeTime,
                      onNotificationRelativeTimeChanged: (notif) {
                        widget.onChanged(
                          s.copyWithTiming(
                            notificationRelativeTime: notif,
                            clearNotification: notif == null,
                          ),
                        );
                      },
                      missedOccurrencePolicy: s.missedOccurrencePolicy,
                      onMissedOccurrencePolicyChanged: (policy) {
                        widget.onChanged(
                          s.copyWithTiming(missedOccurrencePolicy: policy),
                        );
                      },
                      showNotification: true,
                      showMissedPolicy: true,
                    ),
                  ] else if (s is WeeklySchedule) ...[
                    WeeklySchedulingWidget(
                      startDate: s.startDate,
                      onStartDateChanged: (date) {
                        widget.onChanged(s.copyWithStartDate(date));
                      },
                      interval: s.interval,
                      onIntervalChanged: (val) {
                        widget.onChanged(
                          WeeklySchedule(
                            startDate: s.startDate,
                            interval: val,
                            daysOfWeek: s.daysOfWeek,
                            startRelativeTime: s.startRelativeTime,
                            dueRelativeTime: s.dueRelativeTime,
                            notificationRelativeTime:
                                s.notificationRelativeTime,
                            schedulingPolicy: s.schedulingPolicy,
                            missedOccurrencePolicy: s.missedOccurrencePolicy,
                          ),
                        );
                      },
                      schedulingPolicy: s.schedulingPolicy,
                      onSchedulingPolicyChanged: (policy) {
                        widget.onChanged(
                          s.copyWithTiming(schedulingPolicy: policy),
                        );
                      },
                      selectedWeekdays: s.daysOfWeek,
                      onWeekdaysChanged: (days) {
                        widget.onChanged(
                          WeeklySchedule(
                            startDate: s.startDate,
                            interval: s.interval,
                            daysOfWeek: days,
                            startRelativeTime: s.startRelativeTime,
                            dueRelativeTime: s.dueRelativeTime,
                            notificationRelativeTime:
                                s.notificationRelativeTime,
                            schedulingPolicy: s.schedulingPolicy,
                            missedOccurrencePolicy: s.missedOccurrencePolicy,
                          ),
                        );
                      },
                      startRelativeTime: s.startRelativeTime,
                      onStartRelativeTimeChanged: (start) {
                        widget.onChanged(
                          s.copyWithTiming(startRelativeTime: start),
                        );
                      },
                      dueRelativeTime: s.dueRelativeTime,
                      onDueRelativeTimeChanged: (due) {
                        widget.onChanged(
                          s.copyWithTiming(dueRelativeTime: due),
                        );
                      },
                      notificationRelativeTime: s.notificationRelativeTime,
                      onNotificationRelativeTimeChanged: (notif) {
                        widget.onChanged(
                          s.copyWithTiming(
                            notificationRelativeTime: notif,
                            clearNotification: notif == null,
                          ),
                        );
                      },
                      missedOccurrencePolicy: s.missedOccurrencePolicy,
                      onMissedOccurrencePolicyChanged: (policy) {
                        widget.onChanged(
                          s.copyWithTiming(missedOccurrencePolicy: policy),
                        );
                      },
                      showNotification: true,
                      showMissedPolicy: true,
                    ),
                  ] else if (s is MonthlySchedule) ...[
                    MonthlySchedulingWidget(
                      startDate: s.startDate,
                      onStartDateChanged: (date) {
                        widget.onChanged(s.copyWithStartDate(date));
                      },
                      interval: s.interval,
                      onIntervalChanged: (val) {
                        widget.onChanged(
                          MonthlySchedule(
                            startDate: s.startDate,
                            interval: val,
                            dayOfMonth: s.dayOfMonth,
                            dayOfWeek: s.dayOfWeek,
                            occurrence: s.occurrence,
                            startRelativeTime: s.startRelativeTime,
                            dueRelativeTime: s.dueRelativeTime,
                            notificationRelativeTime:
                                s.notificationRelativeTime,
                            schedulingPolicy: s.schedulingPolicy,
                            missedOccurrencePolicy: s.missedOccurrencePolicy,
                          ),
                        );
                      },
                      schedulingPolicy: s.schedulingPolicy,
                      onSchedulingPolicyChanged: (policy) {
                        widget.onChanged(
                          s.copyWithTiming(schedulingPolicy: policy),
                        );
                      },
                      ruleType: s.dayOfMonth != null
                          ? 'dayOfMonth'
                          : 'nthDayOfWeek',
                      onRuleTypeChanged: (type) {
                        if (type == 'dayOfMonth') {
                          widget.onChanged(
                            MonthlySchedule(
                              startDate: s.startDate,
                              interval: s.interval,
                              dayOfMonth: s.startDate.day <= 28
                                  ? s.startDate.day
                                  : 28,
                              startRelativeTime: s.startRelativeTime,
                              dueRelativeTime: s.dueRelativeTime,
                              notificationRelativeTime:
                                  s.notificationRelativeTime,
                              schedulingPolicy: s.schedulingPolicy,
                              missedOccurrencePolicy: s.missedOccurrencePolicy,
                            ),
                          );
                        } else {
                          widget.onChanged(
                            MonthlySchedule(
                              startDate: s.startDate,
                              interval: s.interval,
                              dayOfWeek: s.startDate.toUtcDateTime().weekday,
                              occurrence: 1,
                              startRelativeTime: s.startRelativeTime,
                              dueRelativeTime: s.dueRelativeTime,
                              notificationRelativeTime:
                                  s.notificationRelativeTime,
                              schedulingPolicy: s.schedulingPolicy,
                              missedOccurrencePolicy: s.missedOccurrencePolicy,
                            ),
                          );
                        }
                      },
                      dayOfMonth: s.dayOfMonth,
                      onDayOfMonthChanged: (val) {
                        widget.onChanged(
                          MonthlySchedule(
                            startDate: s.startDate,
                            interval: s.interval,
                            dayOfMonth: val,
                            startRelativeTime: s.startRelativeTime,
                            dueRelativeTime: s.dueRelativeTime,
                            notificationRelativeTime:
                                s.notificationRelativeTime,
                            schedulingPolicy: s.schedulingPolicy,
                            missedOccurrencePolicy: s.missedOccurrencePolicy,
                          ),
                        );
                      },
                      occurrence: s.occurrence,
                      onOccurrenceChanged: (val) {
                        widget.onChanged(
                          MonthlySchedule(
                            startDate: s.startDate,
                            interval: s.interval,
                            dayOfWeek: s.dayOfWeek,
                            occurrence: val,
                            startRelativeTime: s.startRelativeTime,
                            dueRelativeTime: s.dueRelativeTime,
                            notificationRelativeTime:
                                s.notificationRelativeTime,
                            schedulingPolicy: s.schedulingPolicy,
                            missedOccurrencePolicy: s.missedOccurrencePolicy,
                          ),
                        );
                      },
                      dayOfWeek: s.dayOfWeek,
                      onDayOfWeekChanged: (val) {
                        widget.onChanged(
                          MonthlySchedule(
                            startDate: s.startDate,
                            interval: s.interval,
                            dayOfWeek: val,
                            occurrence: s.occurrence,
                            startRelativeTime: s.startRelativeTime,
                            dueRelativeTime: s.dueRelativeTime,
                            notificationRelativeTime:
                                s.notificationRelativeTime,
                            schedulingPolicy: s.schedulingPolicy,
                            missedOccurrencePolicy: s.missedOccurrencePolicy,
                          ),
                        );
                      },
                      startRelativeTime: s.startRelativeTime,
                      onStartRelativeTimeChanged: (start) {
                        widget.onChanged(
                          s.copyWithTiming(startRelativeTime: start),
                        );
                      },
                      dueRelativeTime: s.dueRelativeTime,
                      onDueRelativeTimeChanged: (due) {
                        widget.onChanged(
                          s.copyWithTiming(dueRelativeTime: due),
                        );
                      },
                      notificationRelativeTime: s.notificationRelativeTime,
                      onNotificationRelativeTimeChanged: (notif) {
                        widget.onChanged(
                          s.copyWithTiming(
                            notificationRelativeTime: notif,
                            clearNotification: notif == null,
                          ),
                        );
                      },
                      missedOccurrencePolicy: s.missedOccurrencePolicy,
                      onMissedOccurrencePolicyChanged: (policy) {
                        widget.onChanged(
                          s.copyWithTiming(missedOccurrencePolicy: policy),
                        );
                      },
                      showNotification: true,
                      showMissedPolicy: true,
                    ),
                  ] else if (s is YearlySchedule) ...[
                    YearlySchedulingWidget(
                      startDate: s.startDate,
                      onStartDateChanged: (date) {
                        widget.onChanged(s.copyWithStartDate(date));
                      },
                      interval: s.interval,
                      onIntervalChanged: (val) {
                        widget.onChanged(
                          YearlySchedule(
                            startDate: s.startDate,
                            interval: val,
                            month: s.month,
                            day: s.day,
                            startRelativeTime: s.startRelativeTime,
                            dueRelativeTime: s.dueRelativeTime,
                            notificationRelativeTime:
                                s.notificationRelativeTime,
                            schedulingPolicy: s.schedulingPolicy,
                            missedOccurrencePolicy: s.missedOccurrencePolicy,
                          ),
                        );
                      },
                      schedulingPolicy: s.schedulingPolicy,
                      onSchedulingPolicyChanged: (policy) {
                        widget.onChanged(
                          s.copyWithTiming(schedulingPolicy: policy),
                        );
                      },
                      month: s.month,
                      onMonthChanged: (val) {
                        widget.onChanged(
                          YearlySchedule(
                            startDate: s.startDate,
                            interval: s.interval,
                            month: val,
                            day: s.day,
                            startRelativeTime: s.startRelativeTime,
                            dueRelativeTime: s.dueRelativeTime,
                            notificationRelativeTime:
                                s.notificationRelativeTime,
                            schedulingPolicy: s.schedulingPolicy,
                            missedOccurrencePolicy: s.missedOccurrencePolicy,
                          ),
                        );
                      },
                      day: s.day,
                      onDayChanged: (val) {
                        widget.onChanged(
                          YearlySchedule(
                            startDate: s.startDate,
                            interval: s.interval,
                            month: s.month,
                            day: val,
                            startRelativeTime: s.startRelativeTime,
                            dueRelativeTime: s.dueRelativeTime,
                            notificationRelativeTime:
                                s.notificationRelativeTime,
                            schedulingPolicy: s.schedulingPolicy,
                            missedOccurrencePolicy: s.missedOccurrencePolicy,
                          ),
                        );
                      },
                      startRelativeTime: s.startRelativeTime,
                      onStartRelativeTimeChanged: (start) {
                        widget.onChanged(
                          s.copyWithTiming(startRelativeTime: start),
                        );
                      },
                      dueRelativeTime: s.dueRelativeTime,
                      onDueRelativeTimeChanged: (due) {
                        widget.onChanged(
                          s.copyWithTiming(dueRelativeTime: due),
                        );
                      },
                      notificationRelativeTime: s.notificationRelativeTime,
                      onNotificationRelativeTimeChanged: (notif) {
                        widget.onChanged(
                          s.copyWithTiming(
                            notificationRelativeTime: notif,
                            clearNotification: notif == null,
                          ),
                        );
                      },
                      missedOccurrencePolicy: s.missedOccurrencePolicy,
                      onMissedOccurrencePolicyChanged: (policy) {
                        widget.onChanged(
                          s.copyWithTiming(missedOccurrencePolicy: policy),
                        );
                      },
                      showNotification: true,
                      showMissedPolicy: true,
                      intervalController: _intervalController,
                      dayController: _yearlyDayController,
                    ),
                  ] else if (s is OneOffSchedule) ...[
                    OneOffSchedulingWidget(
                      startDateTime: _oneOffStartController,
                      dueDateTime: _oneOffDueController,
                      notificationTimeController: _oneOffNotificationController,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
