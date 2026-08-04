import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/task_schedule.dart';
import '../logic/l10n_extension.dart';
import '../logic/civil_day.dart';
import '../logic/relative_time.dart';
import '../logic/subscription_service.dart';

class ScheduleCard extends ConsumerWidget {
  final TaskSchedule task;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ScheduleCard({
    super.key,
    required this.task,
    required this.onEdit,
    required this.onDelete,
  });

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedule = task.schedules.isNotEmpty
        ? task.schedules[task.activeOccurrenceIndex < task.schedules.length
              ? task.activeOccurrenceIndex
              : 0]
        : OneOffSchedule(
            id: 'R-fallback-${task.id}',
            scheduleId: task.id,
            date: CivilDay.fromDateTime(DateTime.now()),
            startRelativeTime: RelativeTime(
              dayOffset: 0,
              time: const TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: RelativeTime(
              dayOffset: 0,
              time: const TimeOfDay(hour: 17, minute: 0),
            ),
          );

    String intervalStr = '';
    String startStr = '';
    String daysStr = '';

    if (schedule is DailySchedule) {
      final ds = schedule;
      intervalStr = ds.interval == 1
          ? context.l10n.everyDay
          : context.l10n.everyNDays(ds.interval);
      final dateStr =
          '${ds.startDate.year}-${ds.startDate.month.toString().padLeft(2, '0')}-${ds.startDate.day.toString().padLeft(2, '0')}';
      startStr = context.l10n.startingDate(dateStr);
    } else if (schedule is WeeklySchedule) {
      final ws = schedule;
      intervalStr = ws.interval == 1
          ? context.l10n.everyWeek
          : context.l10n.everyNWeeks(ws.interval);
      final dateStr =
          '${ws.startDate.year}-${ws.startDate.month.toString().padLeft(2, '0')}-${ws.startDate.day.toString().padLeft(2, '0')}';
      startStr = context.l10n.startingDate(dateStr);

      final dayNames = {
        1: 'Mon',
        2: 'Tue',
        3: 'Wed',
        4: 'Thu',
        5: 'Fri',
        6: 'Sat',
        7: 'Sun',
      };
      final selectedDays = ws.daysOfWeek.toList()..sort();
      final joinedDays = selectedDays.map((d) => dayNames[d]).join(', ');
      daysStr = context.l10n.onDaysOfWeek(joinedDays);
    } else if (schedule is MonthlySchedule) {
      final ms = schedule;
      intervalStr = ms.interval == 1
          ? context.l10n.everyMonth
          : context.l10n.everyNMonths(ms.interval);
      final dateStr =
          '${ms.startDate.year}-${ms.startDate.month.toString().padLeft(2, '0')}-${ms.startDate.day.toString().padLeft(2, '0')}';
      startStr = context.l10n.startingDate(dateStr);

      if (ms.dayOfMonth != null) {
        if (ms.dayOfMonth! > 0) {
          daysStr = context.l10n.dayOfMonthOnDay(ms.dayOfMonth!);
        } else {
          daysStr = context.l10n.dayOfMonthFromEnd(ms.dayOfMonth!.abs());
        }
      } else {
        final occurrenceNames = {
          1: context.l10n.firstOccurrence,
          2: context.l10n.secondOccurrence,
          3: context.l10n.thirdOccurrence,
          4: context.l10n.fourthOccurrence,
          -1: context.l10n.lastOccurrence,
        };
        final dayOfWeekNames = {
          1: 'Monday',
          2: 'Tuesday',
          3: 'Wednesday',
          4: 'Thursday',
          5: 'Friday',
          6: 'Saturday',
          7: 'Sunday',
        };
        final occStr = occurrenceNames[ms.occurrence] ?? '';
        final dowStr = dayOfWeekNames[ms.dayOfWeek] ?? '';
        daysStr = context.l10n.nthDayOfWeekOccurrence(occStr, dowStr);
      }
    } else if (schedule is YearlySchedule) {
      final ys = schedule;
      intervalStr = ys.interval == 1
          ? context.l10n.everyYear
          : context.l10n.everyNYears(ys.interval);
      final dateStr =
          '${ys.startDate.year}-${ys.startDate.month.toString().padLeft(2, '0')}-${ys.startDate.day.toString().padLeft(2, '0')}';
      startStr = context.l10n.startingDate(dateStr);

      final monthNames = {
        1: 'January',
        2: 'February',
        3: 'March',
        4: 'April',
        5: 'May',
        6: 'June',
        7: 'July',
        8: 'August',
        9: 'September',
        10: 'October',
        11: 'November',
        12: 'December',
      };
      final mStr = monthNames[ys.month] ?? '';
      daysStr = context.l10n.yearlyOn(mStr, ys.day);
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          task.title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (ref
                              .watch(subscriptionServiceProvider)
                              .isActivePremium &&
                          task.hasPendingWrites) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'Saved locally (pending Cloud sync)',
                          child: Icon(
                            Icons.cloud_sync_outlined,
                            size: 20,
                            color: Colors.amber.shade800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: Key('edit_schedule_button_${task.id}'),
                      icon: const Icon(Icons.edit_calendar),
                      tooltip: context.l10n.editScheduleTooltip,
                      onPressed: onEdit,
                    ),
                    IconButton(
                      key: Key('delete_schedule_button_${task.id}'),
                      icon: Icon(
                        Icons.delete,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      tooltip: context.l10n.deleteTaskTooltip,
                      onPressed: onDelete,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        schedule is DailySchedule
                            ? context.l10n.dailyRecurrence
                            : schedule is WeeklySchedule
                            ? context.l10n.weeklyRecurrence
                            : schedule is MonthlySchedule
                            ? context.l10n.monthlyLabel
                            : context.l10n.yearlyLabel,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (ref
                            .watch(subscriptionServiceProvider)
                            .isActivePremium &&
                        task.hasPendingWrites) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade800),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.cloud_sync_outlined,
                              size: 14,
                              color: Colors.amber.shade900,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Saved locally (pending Cloud sync)',
                              style: TextStyle(
                                color: Colors.amber.shade900,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              MarkdownBody(data: task.description, selectable: true),
            ],
            const Divider(height: 24),
            Row(
              children: [
                Icon(
                  Icons.repeat,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  intervalStr,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (schedule is WeeklySchedule ||
                schedule is MonthlySchedule ||
                schedule is YearlySchedule) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    schedule is WeeklySchedule
                        ? Icons.calendar_view_week
                        : schedule is MonthlySchedule
                        ? Icons.calendar_view_month
                        : Icons.calendar_today,
                    size: 16,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    daysStr,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.play_arrow_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                const SizedBox(width: 8),
                Text(
                  startStr,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.dailyOccurrencesHeader,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 6),
            if (task.schedules.isNotEmpty)
              ...task.schedules.map(
                (s) => Padding(
                  padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_formatTimeOfDay(s.startRelativeTime.time)} - ${_formatTimeOfDay(s.dueRelativeTime.time)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, size: 14, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      '${_formatTimeOfDay(schedule.startRelativeTime.time)} - ${_formatTimeOfDay(schedule.dueRelativeTime.time)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
