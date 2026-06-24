import 'package:flutter/material.dart';
import '../logic/civil_day.dart';
import '../logic/relative_time.dart';
import '../logic/task_schedule_rule.dart';
import '../logic/app_clock.dart';
import '../logic/l10n_extension.dart';
import 'daily_scheduling_widget.dart';
import 'weekly_scheduling_widget.dart';
import 'monthly_scheduling_widget.dart';
import 'yearly_scheduling_widget.dart';
import 'one_off_scheduling_widget.dart';
import 'hierarchical_recurrence_selector.dart';
import 'notification_list_widget.dart';
import 'missed_occurrence_policy_selector.dart';

class ScheduleRuleConfigWidget extends StatefulWidget {
  final TaskScheduleRule schedule;
  final ValueChanged<TaskScheduleRule> onChanged;
  final ValueChanged<String?>? onValidationError;
  final bool showNotification;
  final bool showMissedPolicy;
  final bool readOnly;

  const ScheduleRuleConfigWidget({
    super.key,
    required this.schedule,
    required this.onChanged,
    this.onValidationError,
    this.showNotification = true,
    this.showMissedPolicy = true,
    this.readOnly = false,
  });

  @override
  State<ScheduleRuleConfigWidget> createState() =>
      _ScheduleRuleConfigWidgetState();
}

class _ScheduleRuleConfigWidgetState extends State<ScheduleRuleConfigWidget> {
  late TextEditingController _intervalController;
  late TextEditingController _monthlyDayOfMonthController;
  late TextEditingController _yearlyDayController;

  late ValueNotifier<DateTime> _oneOffStartController;
  late ValueNotifier<DateTime> _oneOffDueController;
  late ValueNotifier<TimeOfDay?> _oneOffNotificationController;
  bool _ignoreControllerEvents = false;

  String? _lastReportedError;
  bool _hasReportedError = false;

  @override
  void initState() {
    super.initState();
    final intervalText = _getIntervalText(widget.schedule);
    final initialFormattedText = widget.schedule is DailySchedule
        ? (intervalText == '1' ? '1 day' : '$intervalText days')
        : intervalText;
    _intervalController = TextEditingController(text: initialFormattedText);
    _monthlyDayOfMonthController = TextEditingController(
      text: _getMonthlyDayOfMonthText(widget.schedule),
    );
    _yearlyDayController = TextEditingController(
      text: _getYearlyDayText(widget.schedule),
    );

    final s = widget.schedule;
    final initialStart = s is OneOffSchedule
        ? _relativeToAbsolute(s.date, s.startRelativeTime)
        : AppClock.now;
    final initialDue = s is OneOffSchedule
        ? _relativeToAbsolute(s.date, s.dueRelativeTime)
        : AppClock.now;
    final initialNotif =
        s is OneOffSchedule && s.notificationRelativeTimes.isNotEmpty
        ? s.notificationRelativeTimes.first.time
        : null;

    _oneOffStartController = ValueNotifier<DateTime>(initialStart);
    _oneOffDueController = ValueNotifier<DateTime>(initialDue);
    _oneOffNotificationController = ValueNotifier<TimeOfDay?>(initialNotif);

    _oneOffStartController.addListener(_onOneOffControllersChanged);
    _oneOffDueController.addListener(_onOneOffControllersChanged);
    _oneOffNotificationController.addListener(_onOneOffControllersChanged);

    _intervalController.addListener(_validateInputs);
    _monthlyDayOfMonthController.addListener(_validateInputs);
    _yearlyDayController.addListener(_validateInputs);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _validateInputs();
    });
  }

  void _validateInputs() {
    if (!mounted) return;
    final s = widget.schedule;
    String? error;
    final l10n = context.l10n;

    if (s is! OneOffSchedule) {
      final intervalText = _intervalController.text.replaceAll(
        RegExp(r'\D'),
        '',
      );
      final interval = int.tryParse(intervalText);
      if (interval == null || interval <= 0) {
        error = l10n.invalidIntervalError;
      }
    }

    if (s is MonthlySchedule && s.dayOfMonth != null) {
      final domText = _monthlyDayOfMonthController.text.trim();
      final dom = int.tryParse(domText);
      if (dom == null || dom == 0 || dom.abs() > 28) {
        error = l10n.dayOfMonthValidationError;
      }
    }

    if (s is YearlySchedule) {
      final yMonth = s.month;
      final yDayText = _yearlyDayController.text.trim();
      final yDay = int.tryParse(yDayText);

      int maxDays = 31;
      if (yMonth == 2) {
        maxDays = 29;
      } else if ([4, 6, 9, 11].contains(yMonth)) {
        maxDays = 30;
      }

      if (yDay == null || yDay < 1 || yDay > maxDays) {
        error = l10n.dayMustBeBetweenError(maxDays);
      }
    }

    if (!_hasReportedError || _lastReportedError != error) {
      _lastReportedError = error;
      _hasReportedError = true;
      widget.onValidationError?.call(error);
    }
  }

  void _onOneOffControllersChanged() {
    if (_ignoreControllerEvents) return;
    final s = widget.schedule;
    if (s is OneOffSchedule) {
      final startAbs = _oneOffStartController.value;
      final dueAbs = _oneOffDueController.value;

      final newDate = CivilDay.fromDateTime(dueAbs);
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
  }

  @override
  void dispose() {
    _intervalController.removeListener(_validateInputs);
    _monthlyDayOfMonthController.removeListener(_validateInputs);
    _yearlyDayController.removeListener(_validateInputs);
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
  void didUpdateWidget(ScheduleRuleConfigWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final typeChanged =
        oldWidget.schedule.runtimeType != widget.schedule.runtimeType;

    final oldIntervalText = _getIntervalText(oldWidget.schedule);
    final newIntervalText = _getIntervalText(widget.schedule);
    if (typeChanged || oldIntervalText != newIntervalText) {
      final formattedText = widget.schedule is DailySchedule
          ? (newIntervalText == '1' ? '1 day' : '$newIntervalText days')
          : newIntervalText;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _intervalController.text = formattedText;
        }
      });
    }
    final oldMonthlyDayText = _getMonthlyDayOfMonthText(oldWidget.schedule);
    final newMonthlyDayText = _getMonthlyDayOfMonthText(widget.schedule);
    if (typeChanged || oldMonthlyDayText != newMonthlyDayText) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _monthlyDayOfMonthController.text = newMonthlyDayText;
        }
      });
    }
    final oldYearlyDayText = _getYearlyDayText(oldWidget.schedule);
    final newYearlyDayText = _getYearlyDayText(widget.schedule);
    if (typeChanged || oldYearlyDayText != newYearlyDayText) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _yearlyDayController.text = newYearlyDayText;
        }
      });
    }
    if (widget.schedule is OneOffSchedule) {
      final s = widget.schedule as OneOffSchedule;
      final startAbs = _relativeToAbsolute(s.date, s.startRelativeTime);
      final dueAbs = _relativeToAbsolute(s.date, s.dueRelativeTime);
      final notifTime = s.notificationRelativeTimes.isNotEmpty
          ? s.notificationRelativeTimes.first.time
          : null;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _validateInputs();
    });
  }

  String _getIntervalText(TaskScheduleRule s) {
    if (s is DailySchedule) return s.interval.toString();
    if (s is WeeklySchedule) return s.interval.toString();
    if (s is MonthlySchedule) return s.interval.toString();
    if (s is YearlySchedule) return s.interval.toString();
    return '1';
  }

  String _getMonthlyDayOfMonthText(TaskScheduleRule s) {
    if (s is MonthlySchedule && s.dayOfMonth != null) {
      return s.dayOfMonth!.abs().toString();
    }
    return '1';
  }

  String _getYearlyDayText(TaskScheduleRule s) {
    if (s is YearlySchedule) {
      return s.day.toString();
    }
    return '1';
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

  @override
  Widget build(BuildContext context) {
    final s = widget.schedule;
    final hierarchicalKind = s.hierarchicalKind;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HierarchicalRecurrenceSelector(
          selectedValue: hierarchicalKind,
          readOnly: widget.readOnly,
          onSelected: (kind) {
            final updatedRule = convertRuleToKind(s, kind);
            widget.onChanged(updatedRule);
          },
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
                  id: s.id,
                  scheduleId: s.scheduleId,
                  startDate: s.startDate,
                  interval: val,
                  startRelativeTime: s.startRelativeTime,
                  dueRelativeTime: s.dueRelativeTime,
                  notificationRelativeTimes: s.notificationRelativeTimes,
                  schedulingPolicy: s.schedulingPolicy,
                  missedOccurrencePolicy: s.missedOccurrencePolicy,
                ),
              );
            },
            schedulingPolicy: s.schedulingPolicy,
            onSchedulingPolicyChanged: (policy) {
              widget.onChanged(s.copyWithTiming(schedulingPolicy: policy));
            },
            startRelativeTime: s.startRelativeTime,
            onStartRelativeTimeChanged: (start) {
              widget.onChanged(s.copyWithTiming(startRelativeTime: start));
            },
            dueRelativeTime: s.dueRelativeTime,
            onDueRelativeTimeChanged: (due) {
              widget.onChanged(s.copyWithTiming(dueRelativeTime: due));
            },
            notificationRelativeTime: null,
            onNotificationRelativeTimeChanged: (_) {},
            missedOccurrencePolicy: s.missedOccurrencePolicy,
            onMissedOccurrencePolicyChanged: (policy) {
              widget.onChanged(
                s.copyWithTiming(missedOccurrencePolicy: policy),
              );
            },
            showNotification: false,
            showMissedPolicy: false,
            readOnly: widget.readOnly,
            intervalController: _intervalController,
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
                  id: s.id,
                  scheduleId: s.scheduleId,
                  startDate: s.startDate,
                  interval: val,
                  daysOfWeek: s.daysOfWeek,
                  startRelativeTime: s.startRelativeTime,
                  dueRelativeTime: s.dueRelativeTime,
                  notificationRelativeTimes: s.notificationRelativeTimes,
                  schedulingPolicy: s.schedulingPolicy,
                  missedOccurrencePolicy: s.missedOccurrencePolicy,
                ),
              );
            },
            schedulingPolicy: s.schedulingPolicy,
            onSchedulingPolicyChanged: (policy) {
              widget.onChanged(s.copyWithTiming(schedulingPolicy: policy));
            },
            selectedWeekdays: s.daysOfWeek,
            onWeekdaysChanged: (days) {
              widget.onChanged(
                WeeklySchedule(
                  id: s.id,
                  scheduleId: s.scheduleId,
                  startDate: s.startDate,
                  interval: s.interval,
                  daysOfWeek: days,
                  startRelativeTime: s.startRelativeTime,
                  dueRelativeTime: s.dueRelativeTime,
                  notificationRelativeTimes: s.notificationRelativeTimes,
                  schedulingPolicy: s.schedulingPolicy,
                  missedOccurrencePolicy: s.missedOccurrencePolicy,
                ),
              );
            },
            startRelativeTime: s.startRelativeTime,
            onStartRelativeTimeChanged: (start) {
              widget.onChanged(s.copyWithTiming(startRelativeTime: start));
            },
            dueRelativeTime: s.dueRelativeTime,
            onDueRelativeTimeChanged: (due) {
              widget.onChanged(s.copyWithTiming(dueRelativeTime: due));
            },
            notificationRelativeTime: null,
            onNotificationRelativeTimeChanged: (_) {},
            missedOccurrencePolicy: s.missedOccurrencePolicy,
            onMissedOccurrencePolicyChanged: (policy) {
              widget.onChanged(
                s.copyWithTiming(missedOccurrencePolicy: policy),
              );
            },
            showNotification: false,
            showMissedPolicy: false,
            readOnly: widget.readOnly,
            intervalController: _intervalController,
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
                  id: s.id,
                  scheduleId: s.scheduleId,
                  startDate: s.startDate,
                  interval: val,
                  dayOfMonth: s.dayOfMonth,
                  dayOfWeek: s.dayOfWeek,
                  occurrence: s.occurrence,
                  startRelativeTime: s.startRelativeTime,
                  dueRelativeTime: s.dueRelativeTime,
                  notificationRelativeTimes: s.notificationRelativeTimes,
                  schedulingPolicy: s.schedulingPolicy,
                  missedOccurrencePolicy: s.missedOccurrencePolicy,
                ),
              );
            },
            schedulingPolicy: s.schedulingPolicy,
            onSchedulingPolicyChanged: (policy) {
              widget.onChanged(s.copyWithTiming(schedulingPolicy: policy));
            },
            ruleType: s.dayOfMonth != null ? 'dayOfMonth' : 'nthDayOfWeek',
            onRuleTypeChanged: (type) {
              if (type == 'dayOfMonth') {
                widget.onChanged(
                  MonthlySchedule(
                    id: s.id,
                    scheduleId: s.scheduleId,
                    startDate: s.startDate,
                    interval: s.interval,
                    dayOfMonth: s.startDate.day <= 28 ? s.startDate.day : 28,
                    startRelativeTime: s.startRelativeTime,
                    dueRelativeTime: s.dueRelativeTime,
                    notificationRelativeTimes: s.notificationRelativeTimes,
                    schedulingPolicy: s.schedulingPolicy,
                    missedOccurrencePolicy: s.missedOccurrencePolicy,
                  ),
                );
              } else {
                widget.onChanged(
                  MonthlySchedule(
                    id: s.id,
                    scheduleId: s.scheduleId,
                    startDate: s.startDate,
                    interval: s.interval,
                    dayOfWeek: s.startDate.toUtcDateTime().weekday,
                    occurrence: 1,
                    startRelativeTime: s.startRelativeTime,
                    dueRelativeTime: s.dueRelativeTime,
                    notificationRelativeTimes: s.notificationRelativeTimes,
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
                  id: s.id,
                  scheduleId: s.scheduleId,
                  startDate: s.startDate,
                  interval: s.interval,
                  dayOfMonth: val,
                  startRelativeTime: s.startRelativeTime,
                  dueRelativeTime: s.dueRelativeTime,
                  notificationRelativeTimes: s.notificationRelativeTimes,
                  schedulingPolicy: s.schedulingPolicy,
                  missedOccurrencePolicy: s.missedOccurrencePolicy,
                ),
              );
            },
            occurrence: s.occurrence,
            onOccurrenceChanged: (val) {
              widget.onChanged(
                MonthlySchedule(
                  id: s.id,
                  scheduleId: s.scheduleId,
                  startDate: s.startDate,
                  interval: s.interval,
                  dayOfWeek: s.dayOfWeek,
                  occurrence: val,
                  startRelativeTime: s.startRelativeTime,
                  dueRelativeTime: s.dueRelativeTime,
                  notificationRelativeTimes: s.notificationRelativeTimes,
                  schedulingPolicy: s.schedulingPolicy,
                  missedOccurrencePolicy: s.missedOccurrencePolicy,
                ),
              );
            },
            dayOfWeek: s.dayOfWeek,
            onDayOfWeekChanged: (val) {
              widget.onChanged(
                MonthlySchedule(
                  id: s.id,
                  scheduleId: s.scheduleId,
                  startDate: s.startDate,
                  interval: s.interval,
                  dayOfWeek: val,
                  occurrence: s.occurrence,
                  startRelativeTime: s.startRelativeTime,
                  dueRelativeTime: s.dueRelativeTime,
                  notificationRelativeTimes: s.notificationRelativeTimes,
                  schedulingPolicy: s.schedulingPolicy,
                  missedOccurrencePolicy: s.missedOccurrencePolicy,
                ),
              );
            },
            startRelativeTime: s.startRelativeTime,
            onStartRelativeTimeChanged: (start) {
              widget.onChanged(s.copyWithTiming(startRelativeTime: start));
            },
            dueRelativeTime: s.dueRelativeTime,
            onDueRelativeTimeChanged: (due) {
              widget.onChanged(s.copyWithTiming(dueRelativeTime: due));
            },
            notificationRelativeTime: null,
            onNotificationRelativeTimeChanged: (_) {},
            missedOccurrencePolicy: s.missedOccurrencePolicy,
            onMissedOccurrencePolicyChanged: (policy) {
              widget.onChanged(
                s.copyWithTiming(missedOccurrencePolicy: policy),
              );
            },
            showNotification: false,
            showMissedPolicy: false,
            readOnly: widget.readOnly,
            intervalController: _intervalController,
            dayOfMonthController: _monthlyDayOfMonthController,
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
                  id: s.id,
                  scheduleId: s.scheduleId,
                  startDate: s.startDate,
                  interval: val,
                  month: s.month,
                  day: s.day,
                  startRelativeTime: s.startRelativeTime,
                  dueRelativeTime: s.dueRelativeTime,
                  notificationRelativeTimes: s.notificationRelativeTimes,
                  schedulingPolicy: s.schedulingPolicy,
                  missedOccurrencePolicy: s.missedOccurrencePolicy,
                ),
              );
            },
            schedulingPolicy: s.schedulingPolicy,
            onSchedulingPolicyChanged: (policy) {
              widget.onChanged(s.copyWithTiming(schedulingPolicy: policy));
            },
            month: s.month,
            onMonthChanged: (val) {
              widget.onChanged(
                YearlySchedule(
                  id: s.id,
                  scheduleId: s.scheduleId,
                  startDate: s.startDate,
                  interval: s.interval,
                  month: val,
                  day: s.day,
                  startRelativeTime: s.startRelativeTime,
                  dueRelativeTime: s.dueRelativeTime,
                  notificationRelativeTimes: s.notificationRelativeTimes,
                  schedulingPolicy: s.schedulingPolicy,
                  missedOccurrencePolicy: s.missedOccurrencePolicy,
                ),
              );
            },
            day: s.day,
            onDayChanged: (val) {
              widget.onChanged(
                YearlySchedule(
                  id: s.id,
                  scheduleId: s.scheduleId,
                  startDate: s.startDate,
                  interval: s.interval,
                  month: s.month,
                  day: val,
                  startRelativeTime: s.startRelativeTime,
                  dueRelativeTime: s.dueRelativeTime,
                  notificationRelativeTimes: s.notificationRelativeTimes,
                  schedulingPolicy: s.schedulingPolicy,
                  missedOccurrencePolicy: s.missedOccurrencePolicy,
                ),
              );
            },
            startRelativeTime: s.startRelativeTime,
            onStartRelativeTimeChanged: (start) {
              widget.onChanged(s.copyWithTiming(startRelativeTime: start));
            },
            dueRelativeTime: s.dueRelativeTime,
            onDueRelativeTimeChanged: (due) {
              widget.onChanged(s.copyWithTiming(dueRelativeTime: due));
            },
            notificationRelativeTime: null,
            onNotificationRelativeTimeChanged: (_) {},
            missedOccurrencePolicy: s.missedOccurrencePolicy,
            onMissedOccurrencePolicyChanged: (policy) {
              widget.onChanged(
                s.copyWithTiming(missedOccurrencePolicy: policy),
              );
            },
            showNotification: false,
            showMissedPolicy: false,
            readOnly: widget.readOnly,
            intervalController: _intervalController,
            dayController: _yearlyDayController,
          ),
        ] else if (s is OneOffSchedule) ...[
          OneOffSchedulingWidget(
            dueDateTime: _oneOffDueController,
            notificationTimeController: _oneOffNotificationController,
            showNotification: false,
          ),
        ],
        if (widget.showNotification) ...[
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          NotificationListWidget(
            notifications: s.notificationRelativeTimes,
            onChanged: (newNotifs) {
              widget.onChanged(
                s.copyWithTiming(notificationRelativeTimes: newNotifs),
              );
            },
            referenceDate: s is OneOffSchedule ? s.scheduledDate : null,
            readOnly: widget.readOnly,
          ),
        ],
        if (widget.showMissedPolicy && s is! OneOffSchedule) ...[
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          MissedOccurrencePolicySelector(
            policy: s.missedOccurrencePolicy,
            onChanged: (policy) {
              widget.onChanged(
                s.copyWithTiming(missedOccurrencePolicy: policy),
              );
            },
            readOnly: widget.readOnly,
          ),
        ],
      ],
    );
  }
}
