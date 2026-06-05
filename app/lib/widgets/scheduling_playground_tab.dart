import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../logic/task.dart';
import '../logic/civil_day.dart';
import '../logic/relative_time.dart';
import '../logic/l10n_extension.dart';
import 'one_off_scheduling_widget.dart';
import 'daily_scheduling_widget.dart';
import 'weekly_scheduling_widget.dart';
import 'monthly_scheduling_widget.dart';
import 'yearly_scheduling_widget.dart';

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
  late ValueNotifier<List<DailyOccurrenceTime>> _dailyTimesController;
  late TextEditingController _intervalController;
  late Set<int> _selectedWeekdays;
  late ValueNotifier<String> _monthlyRuleTypeController;
  late TextEditingController _monthlyDayOfMonthController;
  late ValueNotifier<int> _monthlyNthOccurrenceController;
  late ValueNotifier<int> _monthlyDayOfWeekController;
  late ValueNotifier<int> _yearlyMonthController;
  late TextEditingController _yearlyDayController;

  List<CivilDay> _occurrences = [];
  String? _validationError;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _dueDateTimeController = ValueNotifier<DateTime>(
      _startDate.add(const Duration(hours: 17)),
    );
    _startDateTimeController = ValueNotifier<DateTime>(
      _startDate.add(const Duration(hours: 9)),
    );
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

    // Add listeners to trigger recalculation on changes
    _dueDateTimeController.addListener(_recalculate);
    _startDateTimeController.addListener(_recalculate);
    _dailyTimesController.addListener(_recalculate);
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
        TaskSchedule schedule;

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
            schedule = DailySchedule(startDate: startCivil, interval: interval);
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
              );
            } else {
              schedule = MonthlySchedule(
                startDate: startCivil,
                interval: interval,
                dayOfWeek: _monthlyDayOfWeekController.value,
                occurrence: _monthlyNthOccurrenceController.value,
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
              _validationError = 'Day is required';
              return;
            }
            final yDay = int.tryParse(yDayText);

            int maxDays = 31;
            if (yMonth == 2)
              maxDays = 29;
            else if ([4, 6, 9, 11].contains(yMonth))
              maxDays = 30;

            if (yDay == null || yDay < 1 || yDay > maxDays) {
              _validationError = 'Day must be between 1 and $maxDays';
              return;
            }

            schedule = YearlySchedule(
              startDate: startCivil,
              interval: interval,
              month: yMonth,
              day: yDay,
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
            current = schedule.nextOccurrenceAfter(current);
            if (occurrences.isNotEmpty && occurrences.last == current) {
              break;
            }
            occurrences.add(current);
            count++;
          }
        }

        _occurrences = occurrences;
      } catch (e) {
        _validationError = 'Calculation error: $e';
      }
    });
  }

  List<String> _getMonthNames(BuildContext context) {
    if (Localizations.localeOf(context).languageCode == 'es') {
      return [
        'Enero',
        'Febrero',
        'Marzo',
        'Abril',
        'Mayo',
        'Junio',
        'Julio',
        'Agosto',
        'Septiembre',
        'Octubre',
        'Noviembre',
        'Diciembre',
      ];
    }
    return [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
  }

  List<String> _getWeekdayNames(BuildContext context) {
    if (Localizations.localeOf(context).languageCode == 'es') {
      return [
        'Lunes',
        'Martes',
        'Miércoles',
        'Jueves',
        'Viernes',
        'Sábado',
        'Domingo',
      ];
    }
    return [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
  }

  String _formatCivilDay(BuildContext context, CivilDay day) {
    final dt = day.toDateTime();
    final weekdayStr = _getWeekdayNames(context)[dt.weekday - 1];
    final monthStr = _getMonthNames(context)[day.month - 1];
    return '$weekdayStr, $monthStr ${day.day}, ${day.year}';
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: MarkdownBody(
                  data: context.l10n.schedulingPlaygroundHelpContent,
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
                      // Segmented Button
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<RecurrenceType>(
                          segments: [
                            ButtonSegment<RecurrenceType>(
                              value: RecurrenceType.oneOff,
                              label: Text(context.l10n.oneOffLabel),
                            ),
                            ButtonSegment<RecurrenceType>(
                              value: RecurrenceType.daily,
                              label: Text(context.l10n.dailyLabel),
                            ),
                            ButtonSegment<RecurrenceType>(
                              value: RecurrenceType.weekly,
                              label: Text(context.l10n.weeklyLabel),
                            ),
                            ButtonSegment<RecurrenceType>(
                              value: RecurrenceType.monthly,
                              label: Text(context.l10n.monthlyLabel),
                            ),
                            ButtonSegment<RecurrenceType>(
                              value: RecurrenceType.yearly,
                              label: Text(context.l10n.yearlyLabel),
                            ),
                          ],
                          selected: <RecurrenceType>{_scheduleType},
                          onSelectionChanged: (newSelection) {
                            setState(() {
                              _scheduleType = newSelection.first;
                              _recalculate();
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Reused Scheduling Widget
                      if (_scheduleType == RecurrenceType.oneOff)
                        OneOffSchedulingWidget(
                          dueDateTime: _dueDateTimeController,
                          startDateTime: _startDateTimeController,
                        )
                      else if (_scheduleType == RecurrenceType.daily)
                        DailySchedulingWidget(
                          startDate: _startDate,
                          onStartDateChanged: (date) {
                            setState(() {
                              _startDate = date;
                              _recalculate();
                            });
                          },
                          dailyTimesController: _dailyTimesController,
                          intervalController: _intervalController,
                        )
                      else if (_scheduleType == RecurrenceType.weekly)
                        WeeklySchedulingWidget(
                          startDate: _startDate,
                          onStartDateChanged: (date) {
                            setState(() {
                              _startDate = date;
                              _recalculate();
                            });
                          },
                          dailyTimesController: _dailyTimesController,
                          intervalController: _intervalController,
                          selectedWeekdays: _selectedWeekdays,
                          onWeekdaysChanged: (days) {
                            setState(() {
                              _selectedWeekdays = days;
                              _recalculate();
                            });
                          },
                        )
                      else if (_scheduleType == RecurrenceType.monthly)
                        MonthlySchedulingWidget(
                          startDate: _startDate,
                          onStartDateChanged: (date) {
                            setState(() {
                              _startDate = date;
                              _recalculate();
                            });
                          },
                          dailyTimesController: _dailyTimesController,
                          intervalController: _intervalController,
                          ruleTypeController: _monthlyRuleTypeController,
                          dayOfMonthController: _monthlyDayOfMonthController,
                          nthOccurrenceController:
                              _monthlyNthOccurrenceController,
                          dayOfWeekController: _monthlyDayOfWeekController,
                        )
                      else if (_scheduleType == RecurrenceType.yearly)
                        YearlySchedulingWidget(
                          startDate: _startDate,
                          onStartDateChanged: (date) {
                            setState(() {
                              _startDate = date;
                              _recalculate();
                            });
                          },
                          dailyTimesController: _dailyTimesController,
                          intervalController: _intervalController,
                          monthController: _yearlyMonthController,
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
                'Visual Calendar Grid',
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
                      startDate: startCivil,
                    ),
                    const SizedBox(width: 16),
                    MonthGrid(
                      year: month2Year,
                      month: month2Month,
                      highlightedDays: Set.from(_occurrences),
                      startDate: startCivil,
                    ),
                    const SizedBox(width: 16),
                    MonthGrid(
                      year: month3Year,
                      month: month3Month,
                      highlightedDays: Set.from(_occurrences),
                      startDate: startCivil,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Occurrences Title
              Text(
                context.l10n.occurrencesHeader,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              if (_occurrences.isEmpty)
                Text(
                  context.l10n.noOccurrencesPlaceholder,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _occurrences.length,
                  itemBuilder: (context, index) {
                    final occurrence = _occurrences[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      elevation: 1,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          _formatCivilDay(context, occurrence),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class MonthGrid extends StatelessWidget {
  final int year;
  final int month;
  final Set<CivilDay> highlightedDays;
  final CivilDay startDate;

  const MonthGrid({
    super.key,
    required this.year,
    required this.month,
    required this.highlightedDays,
    required this.startDate,
  });

  List<String> _getMonthNames(BuildContext context) {
    if (Localizations.localeOf(context).languageCode == 'es') {
      return [
        'Enero',
        'Febrero',
        'Marzo',
        'Abril',
        'Mayo',
        'Junio',
        'Julio',
        'Agosto',
        'Septiembre',
        'Octubre',
        'Noviembre',
        'Diciembre',
      ];
    }
    return [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
  }

  List<String> _getWeekdayHeaders(BuildContext context) {
    if (Localizations.localeOf(context).languageCode == 'es') {
      return ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    }
    return ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstDay = DateTime.utc(year, month, 1);
    final totalDays = DateTime.utc(year, month + 1, 0).day;
    final firstWeekday = firstDay.weekday; // 1 = Mon, 7 = Sun

    final monthName = _getMonthNames(context)[month - 1];
    final weekdayLabels = _getWeekdayHeaders(context);

    return Container(
      width: 250,
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$monthName $year',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // Weekday headers
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: 7,
            itemBuilder: (context, index) {
              return Center(
                child: Text(
                  weekdayLabels[index],
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            },
          ),
          const Divider(height: 8),
          // Days grid
          GridView.builder(
            key: Key('month_${year}_$month'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: (firstWeekday - 1) + totalDays,
            itemBuilder: (context, index) {
              if (index < firstWeekday - 1) {
                return const SizedBox.shrink();
              }
              final day = index - (firstWeekday - 1) + 1;
              final currentDay = CivilDay(year: year, month: month, day: day);
              final isHighlighted = highlightedDays.contains(currentDay);
              final isStart = currentDay == startDate;

              BoxDecoration? boxDecoration;
              TextStyle? textStyle = theme.textTheme.bodyMedium;

              if (isHighlighted) {
                boxDecoration = BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                );
                textStyle = TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                );
              } else if (isStart) {
                boxDecoration = BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                  shape: BoxShape.circle,
                );
                textStyle = TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                );
              }

              return Center(
                child: Container(
                  key: Key('day_${year}_${month}_$day'),
                  width: 28,
                  height: 28,
                  decoration: boxDecoration,
                  child: Center(child: Text('$day', style: textStyle)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
