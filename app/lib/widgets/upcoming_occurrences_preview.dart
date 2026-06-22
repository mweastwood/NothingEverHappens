import 'package:flutter/material.dart';
import '../logic/civil_day.dart';
import '../logic/relative_time.dart';
import '../logic/task_schedule.dart';
import '../logic/l10n_extension.dart';
import '../logic/app_clock.dart';

class OccurrenceInfo {
  final CivilDay date;
  final TaskScheduleRule schedule;

  OccurrenceInfo(this.date, this.schedule);
}

class UpcomingOccurrencesPreview extends StatelessWidget {
  final List<TaskScheduleRule>? schedules;
  final TaskScheduleRule? schedule;
  final List<DailyOccurrenceTime> dailyTimes;
  final DateTime? startDateTime;
  final DateTime? dueDateTime;
  final RecurrenceType? scheduleType;
  final int maxOccurrences;

  const UpcomingOccurrencesPreview({
    super.key,
    this.schedules,
    this.schedule,
    this.dailyTimes = const [],
    this.startDateTime,
    this.dueDateTime,
    this.scheduleType,
    this.maxOccurrences = 10,
  });

  List<TaskScheduleRule> get effectiveSchedules {
    if (schedules != null) {
      return schedules!;
    }
    final s = schedule;
    if (s == null) return const [];

    final start = startDateTime != null
        ? RelativeTime(
            dayOffset: 0,
            time: TimeOfDay.fromDateTime(startDateTime!),
          )
        : s.startRelativeTime;

    final due = dueDateTime != null
        ? RelativeTime(dayOffset: 0, time: TimeOfDay.fromDateTime(dueDateTime!))
        : s.dueRelativeTime;

    if (dailyTimes.isNotEmpty) {
      return dailyTimes.map((dt) {
        return s.copyWithTiming(
          startRelativeTime: RelativeTime(dayOffset: 0, time: dt.startTime),
          dueRelativeTime: RelativeTime(dayOffset: 0, time: dt.dueTime),
          notificationRelativeTimes: dt.notificationTime != null
              ? [RelativeTime(dayOffset: 0, time: dt.notificationTime!)]
              : const [],
        );
      }).toList();
    } else {
      return [s.copyWithTiming(startRelativeTime: start, dueRelativeTime: due)];
    }
  }

  List<OccurrenceInfo> _calculateOccurrences() {
    final list = effectiveSchedules;
    if (list.isEmpty) return const [];

    final List<OccurrenceInfo> allOccurrences = [];
    final now = AppClock.now;
    final today = CivilDay.fromDateTime(now);

    for (final sched in list) {
      if (sched is OneOffSchedule) {
        allOccurrences.add(OccurrenceInfo(sched.scheduledDate, sched));
      } else {
        try {
          final CivilDay startDay = startDateTime != null
              ? CivilDay.fromDateTime(startDateTime!)
              : (sched.scheduledDate.isBefore(today)
                    ? today
                    : sched.scheduledDate);

          CivilDay current = startDay;
          if (sched.occursOn(current)) {
            allOccurrences.add(OccurrenceInfo(current, sched));
          }

          int count = sched.occursOn(current) ? 1 : 0;
          int iterations = 0;
          while (count < maxOccurrences && iterations < 1000) {
            iterations++;
            final next = sched.nextOccurrenceAfter(current);
            if (next == null) {
              break;
            }
            current = next;
            if (allOccurrences.any(
              (o) => o.schedule == sched && o.date == current,
            )) {
              break;
            }
            allOccurrences.add(OccurrenceInfo(current, sched));
            count++;
          }
        } catch (e) {
          // Gracefully ignore calculation errors for transient/invalid configurations
          debugPrint('Error calculating occurrences: $e');
        }
      }
    }

    allOccurrences.sort((a, b) {
      if (a.date.isBefore(b.date)) return -1;
      if (b.date.isBefore(a.date)) return 1;
      final timeA = a.schedule.startRelativeTime.time;
      final timeB = b.schedule.startRelativeTime.time;
      if (timeA.hour != timeB.hour) return timeA.hour.compareTo(timeB.hour);
      return timeA.minute.compareTo(timeB.minute);
    });

    if (allOccurrences.length > maxOccurrences) {
      return allOccurrences.sublist(0, maxOccurrences);
    }
    return allOccurrences;
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
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: occurrences.length,
            itemBuilder: (context, index) {
              final occurrenceInfo = occurrences[index];
              final occurrence = occurrenceInfo.date;
              final sched = occurrenceInfo.schedule;
              final startAbs = sched.startRelativeTime.referenceTo(occurrence);
              final dueAbs = sched.dueRelativeTime.referenceTo(occurrence);

              final detailsWidget = Column(
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
                            _formatDateTime(context, startAbs),
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
                            _formatDateTime(context, dueAbs),
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
