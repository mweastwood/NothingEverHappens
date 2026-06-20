import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../logic/task_schedule.dart';
import '../logic/civil_day.dart';
import '../logic/app_clock.dart';
import '../logic/l10n_extension.dart';
import '../logic/relative_time.dart';
import 'one_off_scheduling_widget.dart';
import 'daily_scheduling_widget.dart';
import 'weekly_scheduling_widget.dart';
import 'monthly_scheduling_widget.dart';
import 'yearly_scheduling_widget.dart';
import 'recurrence_type_selector.dart';
import 'month_grid.dart';
import 'upcoming_occurrences_preview.dart';

class SchedulingPlaygroundTab extends StatefulWidget {
  const SchedulingPlaygroundTab({super.key});

  @override
  State<SchedulingPlaygroundTab> createState() =>
      _SchedulingPlaygroundTabState();
}

class _SchedulingPlaygroundTabState extends State<SchedulingPlaygroundTab> {
  final _formKey = GlobalKey<FormState>();

  RecurrenceType _scheduleType = RecurrenceType.oneOff;

  // State & Controllers
  late DateTime _startDate;
  late ValueNotifier<DateTime> _dueDateTimeController;
  late ValueNotifier<DateTime> _startDateTimeController;
  late ValueNotifier<TimeOfDay?> _oneOffNotificationController;
  late ValueNotifier<List<DailyOccurrenceTime>> _dailyTimesController;
  late TextEditingController _intervalController;
  late Set<int> _selectedWeekdays;
  late ValueNotifier<String> _monthlyRuleTypeController;
  late TextEditingController _monthlyDayOfMonthController;
  late ValueNotifier<int> _monthlyNthOccurrenceController;
  late ValueNotifier<int> _monthlyDayOfWeekController;
  late ValueNotifier<int> _yearlyMonthController;
  late TextEditingController _yearlyDayController;

  // For Daily redesigned widget
  late RelativeTime _startRelativeTime;
  late RelativeTime _dueRelativeTime;
  late RelativeTime? _notificationRelativeTime;
  late SchedulingPolicy _schedulingPolicy;

  List<CivilDay> _occurrences = [];
  Set<CivilDay> _startDays = {};
  Set<CivilDay> _dueDays = {};
  Set<CivilDay> _rangeDays = {};
  String? _validationError;
  TaskScheduleRule? _schedule;

  @override
  void initState() {
    super.initState();
    final now = AppClock.now;
    _startDate = DateTime(now.year, now.month, now.day);
    _dueDateTimeController = ValueNotifier<DateTime>(
      _startDate.add(const Duration(hours: 17)),
    );
    _startDateTimeController = ValueNotifier<DateTime>(
      _startDate.add(const Duration(hours: 9)),
    );
    _oneOffNotificationController = ValueNotifier<TimeOfDay?>(null);
    _dailyTimesController = ValueNotifier<List<DailyOccurrenceTime>>([
      DailyOccurrenceTime(
        startTime: const TimeOfDay(hour: 9, minute: 0),
        dueTime: const TimeOfDay(hour: 17, minute: 0),
      ),
    ]);
    _intervalController = TextEditingController(text: '1');
    _selectedWeekdays = {1}; // Monday
    _monthlyRuleTypeController = ValueNotifier<String>('dayOfMonth');
    _monthlyDayOfMonthController = TextEditingController(text: '1');
    _monthlyNthOccurrenceController = ValueNotifier<int>(1);
    _monthlyDayOfWeekController = ValueNotifier<int>(1);
    _yearlyMonthController = ValueNotifier<int>(1);
    _yearlyDayController = TextEditingController(text: '1');

    _startRelativeTime = const RelativeTime(
      dayOffset: 0,
      time: TimeOfDay(hour: 9, minute: 0),
    );
    _dueRelativeTime = const RelativeTime(
      dayOffset: 0,
      time: TimeOfDay(hour: 17, minute: 0),
    );
    _notificationRelativeTime = null;
    _schedulingPolicy = const FixedCalendarPolicy();

    // Add listeners to trigger recalculation on changes
    _dueDateTimeController.addListener(_recalculate);
    _startDateTimeController.addListener(_recalculate);
    _dailyTimesController.addListener(_recalculate);
    _oneOffNotificationController.addListener(_recalculate);
    _intervalController.addListener(_recalculate);
    _monthlyRuleTypeController.addListener(_recalculate);
    _monthlyDayOfMonthController.addListener(_recalculate);
    _monthlyNthOccurrenceController.addListener(_recalculate);
    _monthlyDayOfWeekController.addListener(_recalculate);
    _yearlyMonthController.addListener(_recalculate);
    _yearlyDayController.addListener(_recalculate);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recalculate();
    });
  }

  @override
  void dispose() {
    _dueDateTimeController.removeListener(_recalculate);
    _startDateTimeController.removeListener(_recalculate);
    _oneOffNotificationController.removeListener(_recalculate);
    _dailyTimesController.removeListener(_recalculate);
    _intervalController.removeListener(_recalculate);
    _monthlyRuleTypeController.removeListener(_recalculate);
    _monthlyDayOfMonthController.removeListener(_recalculate);
    _monthlyNthOccurrenceController.removeListener(_recalculate);
    _monthlyDayOfWeekController.removeListener(_recalculate);
    _yearlyMonthController.removeListener(_recalculate);
    _yearlyDayController.removeListener(_recalculate);

    _dueDateTimeController.dispose();
    _startDateTimeController.dispose();
    _oneOffNotificationController.dispose();
    _dailyTimesController.dispose();
    _intervalController.dispose();
    _monthlyDayOfMonthController.dispose();
    _yearlyDayController.dispose();
    super.dispose();
  }

  void _recalculate() {
    if (!mounted) return;
    setState(() {
      _validationError = null;
      _occurrences = [];

      // Run validators to highlight form fields if needed
      _formKey.currentState?.validate();

      try {
        final startCivil = CivilDay.fromDateTime(_startDate);
        TaskScheduleRule schedule;

        switch (_scheduleType) {
          case RecurrenceType.oneOff:
            final dueDateTime = _dueDateTimeController.value;
            final civilDate = CivilDay.fromDateTime(dueDateTime);
            schedule = OneOffSchedule(date: civilDate);
            break;

          case RecurrenceType.daily:
            final intervalText = _intervalController.text.trim();
            if (intervalText.isEmpty) {
              _validationError = context.l10n.invalidIntervalError;
              return;
            }
            final interval = int.tryParse(intervalText);
            if (interval == null || interval <= 0) {
              _validationError = context.l10n.invalidIntervalError;
              return;
            }
            schedule = DailySchedule(
              startDate: startCivil,
              interval: interval,
              startRelativeTime: _startRelativeTime,
              dueRelativeTime: _dueRelativeTime,
              notificationRelativeTime: _notificationRelativeTime,
              schedulingPolicy: _schedulingPolicy,
            );
            break;

          case RecurrenceType.weekly:
            final intervalText = _intervalController.text.trim();
            if (intervalText.isEmpty) {
              _validationError = context.l10n.invalidIntervalError;
              return;
            }
            final interval = int.tryParse(intervalText);
            if (interval == null || interval <= 0) {
              _validationError = context.l10n.invalidIntervalError;
              return;
            }
            if (_selectedWeekdays.isEmpty) {
              _validationError = context.l10n.selectAtLeastOneDayError;
              return;
            }
            schedule = WeeklySchedule(
              startDate: startCivil,
              interval: interval,
              daysOfWeek: Set.from(_selectedWeekdays),
              startRelativeTime: _startRelativeTime,
              dueRelativeTime: _dueRelativeTime,
              notificationRelativeTime: _notificationRelativeTime,
              schedulingPolicy: _schedulingPolicy,
            );
            break;

          case RecurrenceType.monthly:
            final intervalText = _intervalController.text.trim();
            if (intervalText.isEmpty) {
              _validationError = context.l10n.invalidIntervalError;
              return;
            }
            final interval = int.tryParse(intervalText);
            if (interval == null || interval <= 0) {
              _validationError = context.l10n.invalidIntervalError;
              return;
            }

            if (_monthlyRuleTypeController.value == 'dayOfMonth') {
              final domText = _monthlyDayOfMonthController.text.trim();
              if (domText.isEmpty) {
                _validationError = context.l10n.dayOfMonthValidationError;
                return;
              }
              final dom = int.tryParse(domText);
              if (dom == null || dom == 0 || dom.abs() > 28) {
                _validationError = context.l10n.dayOfMonthValidationError;
                return;
              }
              schedule = MonthlySchedule(
                startDate: startCivil,
                interval: interval,
                dayOfMonth: dom,
                startRelativeTime: _startRelativeTime,
                dueRelativeTime: _dueRelativeTime,
                notificationRelativeTime: _notificationRelativeTime,
                schedulingPolicy: _schedulingPolicy,
              );
            } else {
              schedule = MonthlySchedule(
                startDate: startCivil,
                interval: interval,
                dayOfWeek: _monthlyDayOfWeekController.value,
                occurrence: _monthlyNthOccurrenceController.value,
                startRelativeTime: _startRelativeTime,
                dueRelativeTime: _dueRelativeTime,
                notificationRelativeTime: _notificationRelativeTime,
                schedulingPolicy: _schedulingPolicy,
              );
            }
            break;

          case RecurrenceType.yearly:
            final intervalText = _intervalController.text.trim();
            if (intervalText.isEmpty) {
              _validationError = context.l10n.invalidIntervalError;
              return;
            }
            final interval = int.tryParse(intervalText);
            if (interval == null || interval <= 0) {
              _validationError = context.l10n.invalidIntervalError;
              return;
            }
            final yMonth = _yearlyMonthController.value;
            final yDayText = _yearlyDayController.text.trim();
            if (yDayText.isEmpty) {
              _validationError = context.l10n.dayIsRequiredError;
              return;
            }
            final yDay = int.tryParse(yDayText);

            int maxDays = 31;
            if (yMonth == 2) {
              maxDays = 29;
            } else if ([4, 6, 9, 11].contains(yMonth)) {
              maxDays = 30;
            }

            if (yDay == null || yDay < 1 || yDay > maxDays) {
              _validationError = context.l10n.dayMustBeBetweenError(maxDays);
              return;
            }

            schedule = YearlySchedule(
              startDate: startCivil,
              interval: interval,
              month: yMonth,
              day: yDay,
              startRelativeTime: _startRelativeTime,
              dueRelativeTime: _dueRelativeTime,
              notificationRelativeTime: _notificationRelativeTime,
              schedulingPolicy: _schedulingPolicy,
            );
            break;
        }

        // Calculate up to 10 occurrences
        List<CivilDay> occurrences = [];
        CivilDay current = CivilDay.fromDateTime(_startDate);

        if (schedule is OneOffSchedule) {
          occurrences.add(schedule.scheduledDate);
        } else {
          if (schedule.occursOn(current)) {
            occurrences.add(current);
          }

          int count = occurrences.length;
          // Guard to prevent any possible infinite loop
          int iterations = 0;
          while (count < 10 && iterations < 5000) {
            iterations++;
            final next = schedule.nextOccurrenceAfter(current);
            if (next == null) {
              break;
            }
            current = next;
            if (occurrences.isNotEmpty && occurrences.last == current) {
              break;
            }
            occurrences.add(current);
            count++;
          }
        }

        _occurrences = occurrences;

        final Set<CivilDay> startDays = {};
        final Set<CivilDay> dueDays = {};
        final Set<CivilDay> rangeDays = {};

        for (final occurrence in occurrences) {
          if (schedule is OneOffSchedule) {
            final startCivil = CivilDay.fromDateTime(
              _startDateTimeController.value,
            );
            final dueCivil = CivilDay.fromDateTime(
              _dueDateTimeController.value,
            );

            startDays.add(startCivil);
            dueDays.add(dueCivil);

            if (startCivil == dueCivil) {
              rangeDays.add(startCivil);
            } else if (startCivil.isBefore(dueCivil)) {
              CivilDay currentDay = startCivil;
              while (currentDay.isBefore(dueCivil) || currentDay == dueCivil) {
                rangeDays.add(currentDay);
                currentDay = currentDay.addDays(1);
              }
            } else {
              rangeDays.add(startCivil);
              rangeDays.add(dueCivil);
            }
          } else {
            startDays.add(occurrence);
            dueDays.add(occurrence);
            rangeDays.add(occurrence);
          }
        }

        _startDays = startDays;
        _dueDays = dueDays;
        _rangeDays = rangeDays;
        _schedule = schedule;
      } catch (e) {
        _validationError = context.l10n.calculationError(e.toString());
        _schedule = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Calculate 3 consecutive months starting from the start date's month
    final startCivil = CivilDay.fromDateTime(_startDate);
    final month1Year = startCivil.year;
    final month1Month = startCivil.month;

    int month2Year = month1Year;
    int month2Month = month1Month + 1;
    if (month2Month > 12) {
      month2Month = 1;
      month2Year += 1;
    }

    int month3Year = month2Year;
    int month3Month = month2Month + 1;
    if (month3Month > 12) {
      month3Month = 1;
      month3Year += 1;
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions
            SizedBox(
              width: double.infinity,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: MarkdownBody(
                    data: context.l10n.schedulingPlaygroundHelpContent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Form editor
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.scheduleHeader,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      RecurrenceTypeSelector(
                        selectedValue: _scheduleType,
                        onSelected: (type) {
                          setState(() {
                            _scheduleType = type;
                            _recalculate();
                          });
                        },
                      ),
                      const SizedBox(height: 24),

                      // Reused Scheduling Widget
                      if (_scheduleType == RecurrenceType.oneOff)
                        OneOffSchedulingWidget(
                          dueDateTime: _dueDateTimeController,
                          startDateTime: _startDateTimeController,
                          notificationTimeController:
                              _oneOffNotificationController,
                        )
                      else if (_scheduleType == RecurrenceType.daily)
                        DailySchedulingWidget(
                          startDate: CivilDay.fromDateTime(_startDate),
                          onStartDateChanged: (date) {
                            setState(() {
                              _startDate = DateTime(
                                date.year,
                                date.month,
                                date.day,
                              );
                              _recalculate();
                            });
                          },
                          interval: int.tryParse(_intervalController.text) ?? 1,
                          onIntervalChanged: (val) {
                            setState(() {
                              _intervalController.text = val.toString();
                              _recalculate();
                            });
                          },
                          schedulingPolicy: _schedulingPolicy,
                          onSchedulingPolicyChanged: (policy) {
                            setState(() {
                              _schedulingPolicy = policy;
                              _recalculate();
                            });
                          },
                          startRelativeTime: _startRelativeTime,
                          onStartRelativeTimeChanged: (val) {
                            setState(() {
                              _startRelativeTime = val;
                              _recalculate();
                            });
                          },
                          dueRelativeTime: _dueRelativeTime,
                          onDueRelativeTimeChanged: (val) {
                            setState(() {
                              _dueRelativeTime = val;
                              _recalculate();
                            });
                          },
                          notificationRelativeTime: _notificationRelativeTime,
                          onNotificationRelativeTimeChanged: (val) {
                            setState(() {
                              _notificationRelativeTime = val;
                              _recalculate();
                            });
                          },
                          showNotification: false,
                          showMissedPolicy: false,
                          intervalController: _intervalController,
                        )
                      else if (_scheduleType == RecurrenceType.weekly)
                        WeeklySchedulingWidget(
                          startDate: CivilDay.fromDateTime(_startDate),
                          onStartDateChanged: (date) {
                            setState(() {
                              _startDate = DateTime(
                                date.year,
                                date.month,
                                date.day,
                              );
                              _recalculate();
                            });
                          },
                          interval: int.tryParse(_intervalController.text) ?? 1,
                          onIntervalChanged: (val) {
                            setState(() {
                              _intervalController.text = val.toString();
                              _recalculate();
                            });
                          },
                          schedulingPolicy: _schedulingPolicy,
                          onSchedulingPolicyChanged: (policy) {
                            setState(() {
                              _schedulingPolicy = policy;
                              _recalculate();
                            });
                          },
                          selectedWeekdays: _selectedWeekdays,
                          onWeekdaysChanged: (days) {
                            setState(() {
                              _selectedWeekdays = days;
                              _recalculate();
                            });
                          },
                          startRelativeTime: _startRelativeTime,
                          onStartRelativeTimeChanged: (val) {
                            setState(() {
                              _startRelativeTime = val;
                              _recalculate();
                            });
                          },
                          dueRelativeTime: _dueRelativeTime,
                          onDueRelativeTimeChanged: (val) {
                            setState(() {
                              _dueRelativeTime = val;
                              _recalculate();
                            });
                          },
                          notificationRelativeTime: _notificationRelativeTime,
                          onNotificationRelativeTimeChanged: (val) {
                            setState(() {
                              _notificationRelativeTime = val;
                              _recalculate();
                            });
                          },
                          showNotification: false,
                          showMissedPolicy: false,
                          intervalController: _intervalController,
                        )
                      else if (_scheduleType == RecurrenceType.monthly)
                        MonthlySchedulingWidget(
                          startDate: CivilDay.fromDateTime(_startDate),
                          onStartDateChanged: (date) {
                            setState(() {
                              _startDate = DateTime(
                                date.year,
                                date.month,
                                date.day,
                              );
                              _recalculate();
                            });
                          },
                          interval: int.tryParse(_intervalController.text) ?? 1,
                          onIntervalChanged: (val) {
                            setState(() {
                              _intervalController.text = val.toString();
                              _recalculate();
                            });
                          },
                          schedulingPolicy: _schedulingPolicy,
                          onSchedulingPolicyChanged: (policy) {
                            setState(() {
                              _schedulingPolicy = policy;
                              _recalculate();
                            });
                          },
                          ruleType: _monthlyRuleTypeController.value,
                          onRuleTypeChanged: (type) {
                            setState(() {
                              _monthlyRuleTypeController.value = type;
                              _recalculate();
                            });
                          },
                          dayOfMonth: int.tryParse(
                            _monthlyDayOfMonthController.text,
                          ),
                          onDayOfMonthChanged: (val) {
                            setState(() {
                              _monthlyDayOfMonthController.text =
                                  val?.toString() ?? '';
                              _recalculate();
                            });
                          },
                          occurrence: _monthlyNthOccurrenceController.value,
                          onOccurrenceChanged: (val) {
                            setState(() {
                              _monthlyNthOccurrenceController.value = val ?? 1;
                              _recalculate();
                            });
                          },
                          dayOfWeek: _monthlyDayOfWeekController.value,
                          onDayOfWeekChanged: (val) {
                            setState(() {
                              _monthlyDayOfWeekController.value = val ?? 1;
                              _recalculate();
                            });
                          },
                          startRelativeTime: _startRelativeTime,
                          onStartRelativeTimeChanged: (val) {
                            setState(() {
                              _startRelativeTime = val;
                              _recalculate();
                            });
                          },
                          dueRelativeTime: _dueRelativeTime,
                          onDueRelativeTimeChanged: (val) {
                            setState(() {
                              _dueRelativeTime = val;
                              _recalculate();
                            });
                          },
                          notificationRelativeTime: _notificationRelativeTime,
                          onNotificationRelativeTimeChanged: (val) {
                            setState(() {
                              _notificationRelativeTime = val;
                              _recalculate();
                            });
                          },
                          showNotification: false,
                          showMissedPolicy: false,
                          intervalController: _intervalController,
                          dayOfMonthController: _monthlyDayOfMonthController,
                        )
                      else if (_scheduleType == RecurrenceType.yearly)
                        YearlySchedulingWidget(
                          startDate: CivilDay.fromDateTime(_startDate),
                          onStartDateChanged: (date) {
                            setState(() {
                              _startDate = DateTime(
                                date.year,
                                date.month,
                                date.day,
                              );
                              _recalculate();
                            });
                          },
                          interval: int.tryParse(_intervalController.text) ?? 1,
                          onIntervalChanged: (val) {
                            setState(() {
                              _intervalController.text = val.toString();
                              _recalculate();
                            });
                          },
                          schedulingPolicy: _schedulingPolicy,
                          onSchedulingPolicyChanged: (policy) {
                            setState(() {
                              _schedulingPolicy = policy;
                              _recalculate();
                            });
                          },
                          month: _yearlyMonthController.value,
                          onMonthChanged: (val) {
                            setState(() {
                              _yearlyMonthController.value = val;
                              _recalculate();
                            });
                          },
                          day: int.tryParse(_yearlyDayController.text) ?? 1,
                          onDayChanged: (val) {
                            setState(() {
                              _yearlyDayController.text = val.toString();
                              _recalculate();
                            });
                          },
                          startRelativeTime: _startRelativeTime,
                          onStartRelativeTimeChanged: (val) {
                            setState(() {
                              _startRelativeTime = val;
                              _recalculate();
                            });
                          },
                          dueRelativeTime: _dueRelativeTime,
                          onDueRelativeTimeChanged: (val) {
                            setState(() {
                              _dueRelativeTime = val;
                              _recalculate();
                            });
                          },
                          notificationRelativeTime: _notificationRelativeTime,
                          onNotificationRelativeTimeChanged: (val) {
                            setState(() {
                              _notificationRelativeTime = val;
                              _recalculate();
                            });
                          },
                          showNotification: false,
                          showMissedPolicy: false,
                          intervalController: _intervalController,
                          dayController: _yearlyDayController,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Validation error or Results
            if (_validationError != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: theme.colorScheme.error),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _validationError!,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              // Calendar Title
              Text(
                context.l10n.visualCalendarGridHeader,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Calendar wrap (responsive side-by-side or scrollable stack)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MonthGrid(
                      year: month1Year,
                      month: month1Month,
                      highlightedDays: Set.from(_occurrences),
                      startDays: _startDays,
                      dueDays: _dueDays,
                      rangeDays: _rangeDays,
                      startDate: startCivil,
                    ),
                    const SizedBox(width: 16),
                    MonthGrid(
                      year: month2Year,
                      month: month2Month,
                      highlightedDays: Set.from(_occurrences),
                      startDays: _startDays,
                      dueDays: _dueDays,
                      rangeDays: _rangeDays,
                      startDate: startCivil,
                    ),
                    const SizedBox(width: 16),
                    MonthGrid(
                      year: month3Year,
                      month: month3Month,
                      highlightedDays: Set.from(_occurrences),
                      startDays: _startDays,
                      dueDays: _dueDays,
                      rangeDays: _rangeDays,
                      startDate: startCivil,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              UpcomingOccurrencesPreview(
                schedule: _schedule,
                dailyTimes:
                    (_scheduleType == RecurrenceType.daily ||
                        _scheduleType == RecurrenceType.weekly)
                    ? const []
                    : _dailyTimesController.value,
                startDateTime: _scheduleType == RecurrenceType.oneOff
                    ? _startDateTimeController.value
                    : null,
                dueDateTime: _scheduleType == RecurrenceType.oneOff
                    ? _dueDateTimeController.value
                    : null,
                scheduleType: _scheduleType,
                maxOccurrences: 10,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
