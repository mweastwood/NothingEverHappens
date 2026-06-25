import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../logic/task_schedule.dart';
import '../logic/civil_day.dart';
import '../logic/app_clock.dart';
import '../logic/l10n_extension.dart';
import '../logic/relative_time.dart';
import 'schedule_rule_config_widget.dart';
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

  late DateTime _startDate;
  late TaskScheduleRule _schedule;

  List<CivilDay> _occurrences = [];
  Set<CivilDay> _startDays = {};
  Set<CivilDay> _dueDays = {};
  Set<CivilDay> _rangeDays = {};
  String? _inputValidationError;
  String? _calculationError;
  String? get _validationError => _inputValidationError ?? _calculationError;

  @override
  void initState() {
    super.initState();
    final now = AppClock.now;
    _startDate = DateTime(now.year, now.month, now.day);
    final civilToday = CivilDay.fromDateTime(_startDate);

    _schedule = OneOffSchedule(
      id: TaskScheduleRule.generateId(),
      scheduleId: 'S-playground-task',
      date: civilToday,
      startRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 9, minute: 0),
      ),
      dueRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 17, minute: 0),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recalculate();
    });
  }

  void _recalculate() {
    if (!mounted) return;
    setState(() {
      _occurrences = [];
      _startDays = {};
      _dueDays = {};
      _rangeDays = {};
      _calculationError = null;

      if (_inputValidationError != null) {
        return;
      }

      try {
        final schedule = _schedule;

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
            final startAbs = schedule.startRelativeTime.referenceTo(
              schedule.scheduledDate,
            );
            final dueAbs = schedule.dueRelativeTime.referenceTo(
              schedule.scheduledDate,
            );
            final startCivil = CivilDay.fromDateTime(startAbs);
            final dueCivil = CivilDay.fromDateTime(dueAbs);

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
      } catch (e) {
        _calculationError = context.l10n.calculationError(e.toString());
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
                      ScheduleRuleConfigWidget(
                        schedule: _schedule,
                        onChanged: (newSchedule) {
                          setState(() {
                            _schedule = newSchedule;
                          });
                          _recalculate();
                        },
                        onValidationError: (error) {
                          setState(() {
                            _inputValidationError = error;
                          });
                          _recalculate();
                        },
                        showNotification: false,
                        showMissedPolicy: false,
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
                schedules: [_schedule],
                maxOccurrences: 10,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
