import 'package:flutter/material.dart';
import '../logic/civil_day.dart';
import '../logic/relative_time.dart';
import '../logic/task_schedule_rule.dart';
import '../logic/scheduling_policy.dart';
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

typedef _ScheduleWidgetBuilder =
    Widget Function(
      BuildContext context,
      _ScheduleRuleConfigWidgetState state,
      TaskScheduleRule s,
    );

SchedulingPolicy _scaleCompletionRelativeInterval(
  SchedulingPolicy policy,
  int intervalUnits,
  int daysPerUnit,
) {
  if (policy is CompletionRelativePolicy) {
    return CompletionRelativePolicy(
      interval: Duration(days: intervalUnits * daysPerUnit),
      targetHour: policy.targetHour,
      targetMinute: policy.targetMinute,
    );
  }
  return policy;
}

DailySchedule _updateDaily(DailySchedule rule, {required int interval}) {
  return DailySchedule(
    id: rule.id,
    scheduleId: rule.scheduleId,
    startDate: rule.startDate,
    interval: interval,
    startRelativeTime: rule.startRelativeTime,
    dueRelativeTime: rule.dueRelativeTime,
    notificationRelativeTimes: rule.notificationRelativeTimes,
    schedulingPolicy: _scaleCompletionRelativeInterval(
      rule.schedulingPolicy,
      interval,
      1,
    ),
    missedOccurrencePolicy: rule.missedOccurrencePolicy,
  );
}

WeeklySchedule _updateWeekly(
  WeeklySchedule rule, {
  int? interval,
  Set<int>? daysOfWeek,
}) {
  final nextInterval = interval ?? rule.interval;
  return WeeklySchedule(
    id: rule.id,
    scheduleId: rule.scheduleId,
    startDate: rule.startDate,
    interval: nextInterval,
    daysOfWeek: daysOfWeek ?? rule.daysOfWeek,
    startRelativeTime: rule.startRelativeTime,
    dueRelativeTime: rule.dueRelativeTime,
    notificationRelativeTimes: rule.notificationRelativeTimes,
    schedulingPolicy: interval != null
        ? _scaleCompletionRelativeInterval(rule.schedulingPolicy, interval, 7)
        : rule.schedulingPolicy,
    missedOccurrencePolicy: rule.missedOccurrencePolicy,
  );
}

MonthlySchedule _updateMonthly(
  MonthlySchedule rule, {
  int? interval,
  int? dayOfMonth,
  int? dayOfWeek,
  int? occurrence,
  bool clearDayOfMonth = false,
  bool clearNthWeekday = false,
}) {
  final nextInterval = interval ?? rule.interval;
  return MonthlySchedule(
    id: rule.id,
    scheduleId: rule.scheduleId,
    startDate: rule.startDate,
    interval: nextInterval,
    dayOfMonth: clearDayOfMonth ? null : (dayOfMonth ?? rule.dayOfMonth),
    dayOfWeek: clearNthWeekday ? null : (dayOfWeek ?? rule.dayOfWeek),
    occurrence: clearNthWeekday ? null : (occurrence ?? rule.occurrence),
    startRelativeTime: rule.startRelativeTime,
    dueRelativeTime: rule.dueRelativeTime,
    notificationRelativeTimes: rule.notificationRelativeTimes,
    schedulingPolicy: interval != null
        ? _scaleCompletionRelativeInterval(rule.schedulingPolicy, interval, 30)
        : rule.schedulingPolicy,
    missedOccurrencePolicy: rule.missedOccurrencePolicy,
  );
}

YearlySchedule _updateYearly(
  YearlySchedule rule, {
  int? interval,
  int? month,
  int? day,
}) {
  final nextInterval = interval ?? rule.interval;
  return YearlySchedule(
    id: rule.id,
    scheduleId: rule.scheduleId,
    startDate: rule.startDate,
    interval: nextInterval,
    month: month ?? rule.month,
    day: day ?? rule.day,
    startRelativeTime: rule.startRelativeTime,
    dueRelativeTime: rule.dueRelativeTime,
    notificationRelativeTimes: rule.notificationRelativeTimes,
    schedulingPolicy: interval != null
        ? _scaleCompletionRelativeInterval(rule.schedulingPolicy, interval, 365)
        : rule.schedulingPolicy,
    missedOccurrencePolicy: rule.missedOccurrencePolicy,
  );
}

final Map<Type, _ScheduleWidgetBuilder> _configBuilders = {
  DailySchedule: (context, state, s) {
    final rule = s as DailySchedule;
    return DailySchedulingWidget(
      startDate: rule.startDate,
      onStartDateChanged: (date) => state._emit(rule.copyWithStartDate(date)),
      interval: rule.interval,
      onIntervalChanged: (val) =>
          state._emit(_updateDaily(rule, interval: val)),
      schedulingPolicy: rule.schedulingPolicy,
      onSchedulingPolicyChanged: (policy) =>
          state._emit(rule.copyWithTiming(schedulingPolicy: policy)),
      startRelativeTime: rule.startRelativeTime,
      onStartRelativeTimeChanged: (start) =>
          state._emit(rule.copyWithTiming(startRelativeTime: start)),
      dueRelativeTime: rule.dueRelativeTime,
      onDueRelativeTimeChanged: (due) =>
          state._emit(rule.copyWithTiming(dueRelativeTime: due)),
      notificationRelativeTime: null,
      onNotificationRelativeTimeChanged: (_) {},
      missedOccurrencePolicy: rule.missedOccurrencePolicy,
      onMissedOccurrencePolicyChanged: (policy) =>
          state._emit(rule.copyWithTiming(missedOccurrencePolicy: policy)),
      showNotification: false,
      showMissedPolicy: false,
      readOnly: state.widget.readOnly,
      intervalController: state._intervalController,
    );
  },
  WeeklySchedule: (context, state, s) {
    final rule = s as WeeklySchedule;
    return WeeklySchedulingWidget(
      startDate: rule.startDate,
      onStartDateChanged: (date) => state._emit(rule.copyWithStartDate(date)),
      interval: rule.interval,
      onIntervalChanged: (val) =>
          state._emit(_updateWeekly(rule, interval: val)),
      schedulingPolicy: rule.schedulingPolicy,
      onSchedulingPolicyChanged: (policy) =>
          state._emit(rule.copyWithTiming(schedulingPolicy: policy)),
      selectedWeekdays: rule.daysOfWeek,
      onWeekdaysChanged: (days) =>
          state._emit(_updateWeekly(rule, daysOfWeek: days)),
      startRelativeTime: rule.startRelativeTime,
      onStartRelativeTimeChanged: (start) =>
          state._emit(rule.copyWithTiming(startRelativeTime: start)),
      dueRelativeTime: rule.dueRelativeTime,
      onDueRelativeTimeChanged: (due) =>
          state._emit(rule.copyWithTiming(dueRelativeTime: due)),
      notificationRelativeTime: null,
      onNotificationRelativeTimeChanged: (_) {},
      missedOccurrencePolicy: rule.missedOccurrencePolicy,
      onMissedOccurrencePolicyChanged: (policy) =>
          state._emit(rule.copyWithTiming(missedOccurrencePolicy: policy)),
      showNotification: false,
      showMissedPolicy: false,
      readOnly: state.widget.readOnly,
      intervalController: state._intervalController,
    );
  },
  MonthlySchedule: (context, state, s) {
    final rule = s as MonthlySchedule;
    return MonthlySchedulingWidget(
      startDate: rule.startDate,
      onStartDateChanged: (date) => state._emit(rule.copyWithStartDate(date)),
      interval: rule.interval,
      onIntervalChanged: (val) =>
          state._emit(_updateMonthly(rule, interval: val)),
      schedulingPolicy: rule.schedulingPolicy,
      onSchedulingPolicyChanged: (policy) =>
          state._emit(rule.copyWithTiming(schedulingPolicy: policy)),
      ruleType: rule.dayOfMonth != null ? 'dayOfMonth' : 'nthDayOfWeek',
      onRuleTypeChanged: (type) {
        if (type == 'dayOfMonth') {
          state._emit(
            _updateMonthly(
              rule,
              dayOfMonth: rule.startDate.day <= 28 ? rule.startDate.day : 28,
              clearNthWeekday: true,
            ),
          );
        } else {
          state._emit(
            _updateMonthly(
              rule,
              dayOfWeek: rule.startDate.toUtcDateTime().weekday,
              occurrence: 1,
              clearDayOfMonth: true,
            ),
          );
        }
      },
      dayOfMonth: rule.dayOfMonth,
      onDayOfMonthChanged: (val) => state._emit(
        _updateMonthly(rule, dayOfMonth: val, clearNthWeekday: true),
      ),
      occurrence: rule.occurrence,
      onOccurrenceChanged: (val) => state._emit(
        _updateMonthly(rule, occurrence: val, clearDayOfMonth: true),
      ),
      dayOfWeek: rule.dayOfWeek,
      onDayOfWeekChanged: (val) => state._emit(
        _updateMonthly(rule, dayOfWeek: val, clearDayOfMonth: true),
      ),
      startRelativeTime: rule.startRelativeTime,
      onStartRelativeTimeChanged: (start) =>
          state._emit(rule.copyWithTiming(startRelativeTime: start)),
      dueRelativeTime: rule.dueRelativeTime,
      onDueRelativeTimeChanged: (due) =>
          state._emit(rule.copyWithTiming(dueRelativeTime: due)),
      notificationRelativeTime: null,
      onNotificationRelativeTimeChanged: (_) {},
      missedOccurrencePolicy: rule.missedOccurrencePolicy,
      onMissedOccurrencePolicyChanged: (policy) =>
          state._emit(rule.copyWithTiming(missedOccurrencePolicy: policy)),
      showNotification: false,
      showMissedPolicy: false,
      readOnly: state.widget.readOnly,
      intervalController: state._intervalController,
      dayOfMonthController: state._monthlyDayOfMonthController,
    );
  },
  YearlySchedule: (context, state, s) {
    final rule = s as YearlySchedule;
    return YearlySchedulingWidget(
      startDate: rule.startDate,
      onStartDateChanged: (date) => state._emit(rule.copyWithStartDate(date)),
      interval: rule.interval,
      onIntervalChanged: (val) =>
          state._emit(_updateYearly(rule, interval: val)),
      schedulingPolicy: rule.schedulingPolicy,
      onSchedulingPolicyChanged: (policy) =>
          state._emit(rule.copyWithTiming(schedulingPolicy: policy)),
      month: rule.month,
      onMonthChanged: (val) => state._emit(_updateYearly(rule, month: val)),
      day: rule.day,
      onDayChanged: (val) => state._emit(_updateYearly(rule, day: val)),
      startRelativeTime: rule.startRelativeTime,
      onStartRelativeTimeChanged: (start) =>
          state._emit(rule.copyWithTiming(startRelativeTime: start)),
      dueRelativeTime: rule.dueRelativeTime,
      onDueRelativeTimeChanged: (due) =>
          state._emit(rule.copyWithTiming(dueRelativeTime: due)),
      notificationRelativeTime: null,
      onNotificationRelativeTimeChanged: (_) {},
      missedOccurrencePolicy: rule.missedOccurrencePolicy,
      onMissedOccurrencePolicyChanged: (policy) =>
          state._emit(rule.copyWithTiming(missedOccurrencePolicy: policy)),
      showNotification: false,
      showMissedPolicy: false,
      readOnly: state.widget.readOnly,
      intervalController: state._intervalController,
      dayController: state._yearlyDayController,
    );
  },
  OneOffSchedule: (context, state, s) {
    return OneOffSchedulingWidget(
      dueDateTime: state._oneOffDueController,
      notificationTimeController: state._oneOffNotificationController,
      showNotification: false,
    );
  },
};

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
  bool _didInit = false;

  void _emit(TaskScheduleRule rule) {
    widget.onChanged(rule);
  }

  @override
  void initState() {
    super.initState();
    _intervalController = TextEditingController();
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

    final isCompletionRelative = s.schedulingPolicy is CompletionRelativePolicy;

    if (!isCompletionRelative && s is MonthlySchedule && s.dayOfMonth != null) {
      final domText = _monthlyDayOfMonthController.text.trim();
      final dom = int.tryParse(domText);
      if (dom == null || dom == 0 || dom.abs() > 28) {
        error = l10n.dayOfMonthValidationError;
      }
    }

    if (!isCompletionRelative && s is YearlySchedule) {
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

  String _formatIntervalControllerText(TaskScheduleRule s) {
    final l10n = context.l10n;
    final intervalText = _getIntervalText(s);
    if (s is DailySchedule) {
      return intervalText == '1'
          ? '1 ${l10n.presetDaySingular}'
          : '$intervalText ${l10n.presetDayPlural}';
    }
    return intervalText;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      final initialFormattedText = _formatIntervalControllerText(
        widget.schedule,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _intervalController.text = initialFormattedText;
        }
      });
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
      final formattedText = _formatIntervalControllerText(widget.schedule);
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
    return RelativeTime(dayOffset: offset, hour: abs.hour, minute: abs.minute);
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
        if (_configBuilders.containsKey(s.runtimeType))
          _configBuilders[s.runtimeType]!(context, this, s),
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
        if (widget.showMissedPolicy &&
            s is! OneOffSchedule &&
            s.schedulingPolicy is! CompletionRelativePolicy) ...[
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
