import 'package:flutter/material.dart';
import '../logic/civil_day.dart';
import '../logic/task.dart';
import '../logic/l10n_extension.dart';

class UpcomingOccurrencesPreview extends StatelessWidget {
  final TaskSchedule? schedule;
  final List<DailyOccurrenceTime> dailyTimes;
  final DateTime startDateTime;
  final DateTime dueDateTime;
  final RecurrenceType scheduleType;
  final int maxOccurrences;

  const UpcomingOccurrencesPreview({
    super.key,
    required this.schedule,
    required this.dailyTimes,
    required this.startDateTime,
    required this.dueDateTime,
    required this.scheduleType,
    this.maxOccurrences = 5,
  });

  List<CivilDay> _calculateOccurrences() {
    final sched = schedule;
    if (sched == null) return const [];

    List<CivilDay> occurrences = [];
    CivilDay current = CivilDay.fromDateTime(startDateTime);

    if (sched is OneOffSchedule) {
      occurrences.add(sched.scheduledDate);
    } else {
      if (sched.occursOn(current)) {
        occurrences.add(current);
      }

      int count = occurrences.length;
      int iterations = 0;
      while (count < maxOccurrences && iterations < 5000) {
        iterations++;
        current = sched.nextOccurrenceAfter(current);
        if (occurrences.isNotEmpty && occurrences.last == current) {
          break;
        }
        occurrences.add(current);
        count++;
      }
    }
    return occurrences;
  }

  List<String> _getMonthNames(BuildContext context) {
    final l10n = context.l10n;
    return [
      l10n.monthJanuary,
      l10n.monthFebruary,
      l10n.monthMarch,
      l10n.monthApril,
      l10n.monthMay,
      l10n.monthJune,
      l10n.monthJuly,
      l10n.monthAugust,
      l10n.monthSeptember,
      l10n.monthOctober,
      l10n.monthNovember,
      l10n.monthDecember,
    ];
  }

  List<String> _getWeekdayNames(BuildContext context) {
    final l10n = context.l10n;
    return [
      l10n.weekdayMonday,
      l10n.weekdayTuesday,
      l10n.weekdayWednesday,
      l10n.weekdayThursday,
      l10n.weekdayFriday,
      l10n.weekdaySaturday,
      l10n.weekdaySunday,
    ];
  }

  String _formatCivilDay(BuildContext context, CivilDay day) {
    final dt = day.toDateTime();
    final weekdayStr = _getWeekdayNames(context)[dt.weekday - 1];
    final monthStr = _getMonthNames(context)[day.month - 1];
    return '$weekdayStr, $monthStr ${day.day}, ${day.year}';
  }

  DateTime _combineDayAndTime(CivilDay day, TimeOfDay time) {
    return DateTime(day.year, day.month, day.day, time.hour, time.minute);
  }

  String _formatDateTime(BuildContext context, DateTime dt) {
    final weekdayStr = _getWeekdayNames(context)[dt.weekday - 1];
    final monthStr = _getMonthNames(context)[dt.month - 1];
    final timeStr = TimeOfDay.fromDateTime(dt).format(context);
    return '$weekdayStr, $monthStr ${dt.day}, ${dt.year} $timeStr';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final occurrences = _calculateOccurrences();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.occurrencesHeader,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (occurrences.isEmpty)
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
            itemCount: occurrences.length,
            itemBuilder: (context, index) {
              final occurrence = occurrences[index];

              Widget detailsWidget;
              if (scheduleType == RecurrenceType.oneOff) {
                detailsWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.visibility,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            context.l10n.occurrenceAppears(
                              _formatDateTime(context, startDateTime),
                            ),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.alarm,
                          size: 14,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            context.l10n.occurrenceDue(
                              _formatDateTime(context, dueDateTime),
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              } else {
                if (dailyTimes.isEmpty) {
                  detailsWidget = const SizedBox.shrink();
                } else {
                  detailsWidget = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      for (final slot in dailyTimes) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.visibility,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                context.l10n.occurrenceAppears(
                                  _formatDateTime(
                                    context,
                                    _combineDayAndTime(
                                      occurrence,
                                      slot.startTime,
                                    ),
                                  ),
                                ),
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.alarm,
                              size: 14,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                context.l10n.occurrenceDue(
                                  _formatDateTime(
                                    context,
                                    _combineDayAndTime(
                                      occurrence,
                                      slot.dueTime,
                                    ),
                                  ),
                                ),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (slot != dailyTimes.last) const Divider(height: 12),
                      ],
                    ],
                  );
                }
              }

              return Card(
                key: Key('occurrence_card_$index'),
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
                  subtitle: detailsWidget,
                ),
              );
            },
          ),
      ],
    );
  }
}
