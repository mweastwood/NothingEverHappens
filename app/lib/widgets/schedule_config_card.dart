import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../logic/civil_day.dart';
import '../logic/relative_time.dart';
import '../logic/task_schedule_rule.dart';
import 'relative_timing_widget.dart';

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

  @override
  void initState() {
    super.initState();
    _intervalController = TextEditingController(text: _getIntervalText());
    _monthlyDayOfMonthController = TextEditingController(
      text: _getMonthlyDayOfMonthText(),
    );
    _yearlyDayController = TextEditingController(text: _getYearlyDayText());
  }

  @override
  void dispose() {
    _intervalController.dispose();
    _monthlyDayOfMonthController.dispose();
    _yearlyDayController.dispose();
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

  String _getSummaryText(TaskScheduleRule schedule) {
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
      margin: const EdgeInsets.only(bottom: 12),
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
                  DropdownButtonFormField<RecurrenceType>(
                    initialValue: recurrenceType,
                    decoration: const InputDecoration(
                      labelText: 'Recurrence Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: RecurrenceType.oneOff,
                        child: Text('One-off'),
                      ),
                      DropdownMenuItem(
                        value: RecurrenceType.daily,
                        child: Text('Daily'),
                      ),
                      DropdownMenuItem(
                        value: RecurrenceType.weekly,
                        child: Text('Weekly'),
                      ),
                      DropdownMenuItem(
                        value: RecurrenceType.monthly,
                        child: Text('Monthly'),
                      ),
                      DropdownMenuItem(
                        value: RecurrenceType.yearly,
                        child: Text('Yearly'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) _changeRecurrenceType(val);
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildRecurrenceConfigForm(s),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  if (s is OneOffSchedule)
                    _buildOneOffTimingPicker(s)
                  else
                    RelativeTimingWidget(
                      startRelativeTime: s.startRelativeTime,
                      dueRelativeTime: s.dueRelativeTime,
                      notificationRelativeTime: s.notificationRelativeTime,
                      onStartChanged: (start) {
                        widget.onChanged(
                          s.copyWithTiming(startRelativeTime: start),
                        );
                      },
                      onDueChanged: (due) {
                        widget.onChanged(
                          s.copyWithTiming(dueRelativeTime: due),
                        );
                      },
                      onNotificationChanged: (notif) {
                        widget.onChanged(
                          s.copyWithTiming(
                            notificationRelativeTime: notif,
                            clearNotification: notif == null,
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecurrenceConfigForm(TaskScheduleRule s) {
    if (s is OneOffSchedule) {
      return _buildStartDateTile(
        label: 'Occurrence Date',
        date: s.date,
        onDateChanged: (d) {
          widget.onChanged(
            OneOffSchedule(
              date: d,
              startRelativeTime: s.startRelativeTime,
              dueRelativeTime: s.dueRelativeTime,
              notificationRelativeTime: s.notificationRelativeTime,
            ),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStartDateTile(
          label: 'Start Recurrence Date',
          date: s.scheduledDate,
          onDateChanged: (d) {
            widget.onChanged(s.copyWithStartDate(d));
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _intervalController,
          decoration: InputDecoration(
            labelText: s is DailySchedule
                ? 'Days Interval'
                : s is WeeklySchedule
                ? 'Weeks Interval'
                : s is MonthlySchedule
                ? 'Months Interval'
                : 'Years Interval',
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
            final interval = int.tryParse(val) ?? 1;
            if (s is DailySchedule) {
              widget.onChanged(
                DailySchedule(
                  startDate: s.startDate,
                  interval: interval,
                  startRelativeTime: s.startRelativeTime,
                  dueRelativeTime: s.dueRelativeTime,
                  notificationRelativeTime: s.notificationRelativeTime,
                ),
              );
            } else if (s is WeeklySchedule) {
              widget.onChanged(
                WeeklySchedule(
                  startDate: s.startDate,
                  interval: interval,
                  daysOfWeek: s.daysOfWeek,
                  startRelativeTime: s.startRelativeTime,
                  dueRelativeTime: s.dueRelativeTime,
                  notificationRelativeTime: s.notificationRelativeTime,
                ),
              );
            } else if (s is MonthlySchedule) {
              widget.onChanged(
                MonthlySchedule(
                  startDate: s.startDate,
                  interval: interval,
                  dayOfMonth: s.dayOfMonth,
                  dayOfWeek: s.dayOfWeek,
                  occurrence: s.occurrence,
                  startRelativeTime: s.startRelativeTime,
                  dueRelativeTime: s.dueRelativeTime,
                  notificationRelativeTime: s.notificationRelativeTime,
                ),
              );
            } else if (s is YearlySchedule) {
              widget.onChanged(
                YearlySchedule(
                  startDate: s.startDate,
                  interval: interval,
                  month: s.month,
                  day: s.day,
                  startRelativeTime: s.startRelativeTime,
                  dueRelativeTime: s.dueRelativeTime,
                  notificationRelativeTime: s.notificationRelativeTime,
                ),
              );
            }
          },
        ),
        if (s is WeeklySchedule) ...[
          const SizedBox(height: 16),
          const Text('Repeats on'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            children: List.generate(7, (index) {
              final dayIndex = index + 1;
              final labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
              final isSelected = s.daysOfWeek.contains(dayIndex);
              return FilterChip(
                label: Text(labels[index]),
                selected: isSelected,
                onSelected: (selected) {
                  final newSet = Set<int>.from(s.daysOfWeek);
                  if (selected) {
                    newSet.add(dayIndex);
                  } else {
                    newSet.remove(dayIndex);
                  }
                  widget.onChanged(
                    WeeklySchedule(
                      startDate: s.startDate,
                      interval: s.interval,
                      daysOfWeek: newSet,
                      startRelativeTime: s.startRelativeTime,
                      dueRelativeTime: s.dueRelativeTime,
                      notificationRelativeTime: s.notificationRelativeTime,
                    ),
                  );
                },
              );
            }),
          ),
        ],
        if (s is MonthlySchedule) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: s.dayOfMonth != null ? 'dayOfMonth' : 'nthDayOfWeek',
            decoration: const InputDecoration(
              labelText: 'Monthly Recurrence Rule',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'dayOfMonth',
                child: Text('Day of Month'),
              ),
              DropdownMenuItem(
                value: 'nthDayOfWeek',
                child: Text('Nth Day of Week'),
              ),
            ],
            onChanged: (value) {
              if (value == 'dayOfMonth') {
                widget.onChanged(
                  MonthlySchedule(
                    startDate: s.startDate,
                    interval: s.interval,
                    dayOfMonth: 1,
                    startRelativeTime: s.startRelativeTime,
                    dueRelativeTime: s.dueRelativeTime,
                    notificationRelativeTime: s.notificationRelativeTime,
                  ),
                );
              } else {
                widget.onChanged(
                  MonthlySchedule(
                    startDate: s.startDate,
                    interval: s.interval,
                    dayOfWeek: 1,
                    occurrence: 1,
                    startRelativeTime: s.startRelativeTime,
                    dueRelativeTime: s.dueRelativeTime,
                    notificationRelativeTime: s.notificationRelativeTime,
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 16),
          if (s.dayOfMonth != null)
            TextFormField(
              controller: _monthlyDayOfMonthController,
              decoration: const InputDecoration(
                labelText:
                    'Day of Month (1-28, or negative -1 to -28 from end)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Day of month is required';
                }
                final dom = int.tryParse(val);
                if (dom == null || dom == 0 || dom.abs() > 28) {
                  return 'Please enter a valid day number: 1 to 28, or -1 to -28';
                }
                return null;
              },
              onChanged: (val) {
                final dom = int.tryParse(val) ?? 1;
                if (dom != 0 && dom.abs() <= 28) {
                  widget.onChanged(
                    MonthlySchedule(
                      startDate: s.startDate,
                      interval: s.interval,
                      dayOfMonth: dom,
                      startRelativeTime: s.startRelativeTime,
                      dueRelativeTime: s.dueRelativeTime,
                      notificationRelativeTime: s.notificationRelativeTime,
                    ),
                  );
                }
              },
            )
          else ...[
            DropdownButtonFormField<int>(
              initialValue: s.occurrence,
              decoration: const InputDecoration(
                labelText: 'Occurrence',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 1, child: Text('First')),
                DropdownMenuItem(value: 2, child: Text('Second')),
                DropdownMenuItem(value: 3, child: Text('Third')),
                DropdownMenuItem(value: 4, child: Text('Fourth')),
                DropdownMenuItem(value: -1, child: Text('Last')),
              ],
              onChanged: (val) {
                if (val != null) {
                  widget.onChanged(
                    MonthlySchedule(
                      startDate: s.startDate,
                      interval: s.interval,
                      dayOfWeek: s.dayOfWeek,
                      occurrence: val,
                      startRelativeTime: s.startRelativeTime,
                      dueRelativeTime: s.dueRelativeTime,
                      notificationRelativeTime: s.notificationRelativeTime,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: s.dayOfWeek,
              decoration: const InputDecoration(
                labelText: 'Day of Week',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 1, child: Text('Monday')),
                DropdownMenuItem(value: 2, child: Text('Tuesday')),
                DropdownMenuItem(value: 3, child: Text('Wednesday')),
                DropdownMenuItem(value: 4, child: Text('Thursday')),
                DropdownMenuItem(value: 5, child: Text('Friday')),
                DropdownMenuItem(value: 6, child: Text('Saturday')),
                DropdownMenuItem(value: 7, child: Text('Sunday')),
              ],
              onChanged: (val) {
                if (val != null) {
                  widget.onChanged(
                    MonthlySchedule(
                      startDate: s.startDate,
                      interval: s.interval,
                      dayOfWeek: val,
                      occurrence: s.occurrence,
                      startRelativeTime: s.startRelativeTime,
                      dueRelativeTime: s.dueRelativeTime,
                      notificationRelativeTime: s.notificationRelativeTime,
                    ),
                  );
                }
              },
            ),
          ],
        ],
        if (s is YearlySchedule) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: s.month,
            decoration: const InputDecoration(
              labelText: 'Month',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 1, child: Text('January')),
              DropdownMenuItem(value: 2, child: Text('February')),
              DropdownMenuItem(value: 3, child: Text('March')),
              DropdownMenuItem(value: 4, child: Text('April')),
              DropdownMenuItem(value: 5, child: Text('May')),
              DropdownMenuItem(value: 6, child: Text('June')),
              DropdownMenuItem(value: 7, child: Text('July')),
              DropdownMenuItem(value: 8, child: Text('August')),
              DropdownMenuItem(value: 9, child: Text('September')),
              DropdownMenuItem(value: 10, child: Text('October')),
              DropdownMenuItem(value: 11, child: Text('November')),
              DropdownMenuItem(value: 12, child: Text('December')),
            ],
            onChanged: (val) {
              if (val != null) {
                widget.onChanged(
                  YearlySchedule(
                    startDate: s.startDate,
                    interval: s.interval,
                    month: val,
                    day: s.day,
                    startRelativeTime: s.startRelativeTime,
                    dueRelativeTime: s.dueRelativeTime,
                    notificationRelativeTime: s.notificationRelativeTime,
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _yearlyDayController,
            decoration: const InputDecoration(
              labelText: 'Day of Month',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Day is required';
              }
              final d = int.tryParse(val);
              if (d == null) return 'Please enter a valid number';
              final month = s.month;
              int maxDays = 31;
              if (month == 2) {
                maxDays = 29;
              } else if ([4, 6, 9, 11].contains(month)) {
                maxDays = 30;
              }
              if (d < 1 || d > maxDays) {
                return 'Day must be between 1 and $maxDays';
              }
              return null;
            },
            onChanged: (val) {
              final d = int.tryParse(val) ?? 1;
              if (d >= 1 && d <= 31) {
                widget.onChanged(
                  YearlySchedule(
                    startDate: s.startDate,
                    interval: s.interval,
                    month: s.month,
                    day: d,
                    startRelativeTime: s.startRelativeTime,
                    dueRelativeTime: s.dueRelativeTime,
                    notificationRelativeTime: s.notificationRelativeTime,
                  ),
                );
              }
            },
          ),
        ],
      ],
    );
  }

  Widget _buildStartDateTile({
    required String label,
    required CivilDay date,
    required ValueChanged<CivilDay> onDateChanged,
  }) {
    final theme = Theme.of(context);
    final dt = DateTime(date.year, date.month, date.day);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          title: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          subtitle: Text(
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          trailing: Icon(
            Icons.calendar_today,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: dt,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
            );
            if (picked != null) {
              onDateChanged(
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
    );
  }

  Widget _buildOneOffTimingPicker(OneOffSchedule s) {
    final theme = Theme.of(context);
    final startAbs = _relativeToAbsolute(s.date, s.startRelativeTime);
    final dueAbs = _relativeToAbsolute(s.date, s.dueRelativeTime);
    final notificationEnabled = s.notificationRelativeTime != null;
    final notifAbs = notificationEnabled
        ? _relativeToAbsolute(s.date, s.notificationRelativeTime!)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Absolute Timing (One-Off)',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildAbsoluteDateTimePicker(
          label: 'Start Date & Time',
          value: startAbs,
          onChanged: (dt) {
            widget.onChanged(
              s.copyWithTiming(
                startRelativeTime: _absoluteToRelative(s.date, dt),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildAbsoluteDateTimePicker(
          label: 'Due Date & Time',
          value: dueAbs,
          onChanged: (dt) {
            widget.onChanged(
              s.copyWithTiming(
                dueRelativeTime: _absoluteToRelative(s.date, dt),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          title: Text(
            'Enable notification reminder',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          value: notificationEnabled,
          onChanged: (enabled) {
            if (enabled == true) {
              widget.onChanged(
                s.copyWithTiming(
                  notificationRelativeTime: const RelativeTime(
                    dayOffset: 0,
                    time: TimeOfDay(hour: 9, minute: 0),
                  ),
                ),
              );
            } else {
              widget.onChanged(
                s.copyWithTiming(
                  notificationRelativeTime: null,
                  clearNotification: true,
                ),
              );
            }
          },
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        if (notificationEnabled && notifAbs != null) ...[
          const SizedBox(height: 8),
          _buildAbsoluteDateTimePicker(
            label: 'Notification Date & Time',
            value: notifAbs,
            onChanged: (dt) {
              widget.onChanged(
                s.copyWithTiming(
                  notificationRelativeTime: _absoluteToRelative(s.date, dt),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildAbsoluteDateTimePicker({
    required String label,
    required DateTime value,
    required ValueChanged<DateTime> onChanged,
  }) {
    final theme = Theme.of(context);
    final timeOfDay = TimeOfDay(hour: value.hour, minute: value.minute);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} @ ${timeOfDay.format(context)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.calendar_today,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: value,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDate: DateTime.now().add(
                        const Duration(days: 365 * 5),
                      ),
                    );
                    if (picked != null) {
                      onChanged(
                        DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          value.hour,
                          value.minute,
                        ),
                      );
                    }
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.access_time,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: timeOfDay,
                    );
                    if (picked != null) {
                      onChanged(
                        DateTime(
                          value.year,
                          value.month,
                          value.day,
                          picked.hour,
                          picked.minute,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
