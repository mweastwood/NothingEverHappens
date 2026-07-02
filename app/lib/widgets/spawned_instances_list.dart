import 'package:flutter/material.dart';
import '../logic/civil_day.dart';
import '../logic/task_schedule.dart';
import '../logic/task_instance.dart';
import '../logic/scheduler_engine.dart';
import '../logic/l10n_extension.dart';

class SpawnedInstancesList extends StatelessWidget {
  final TaskSchedule task;
  final List<TaskInstance> dbInstances;
  final DateTime now;

  const SpawnedInstancesList({
    super.key,
    required this.task,
    required this.dbInstances,
    required this.now,
  });

  List<TaskInstance> _calculateFutureInstances(
    List<TaskInstance> currentInstances,
  ) {
    final futureInstances = currentInstances.where((inst) {
      final startDateTime = inst.startRelativeTime.referenceTo(
        inst.scheduledDate,
      );
      return now.isBefore(startDateTime);
    }).toList();

    futureInstances.sort((a, b) {
      final startA = a.startRelativeTime.referenceTo(a.scheduledDate);
      final startB = b.startRelativeTime.referenceTo(b.scheduledDate);
      return startA.compareTo(startB);
    });

    return futureInstances;
  }

  List<TaskInstance> _calculatePastInstances(
    List<TaskInstance> currentInstances,
  ) {
    final pastInstances = currentInstances.where((inst) {
      final startDateTime = inst.startRelativeTime.referenceTo(
        inst.scheduledDate,
      );
      return !now.isBefore(startDateTime);
    }).toList();

    pastInstances.sort((a, b) {
      final startA = a.startRelativeTime.referenceTo(a.scheduledDate);
      final startB = b.startRelativeTime.referenceTo(b.scheduledDate);
      return startB.compareTo(startA);
    });

    if (pastInstances.length > 10) {
      return pastInstances.sublist(0, 10);
    }
    return pastInstances;
  }

  static List<String> _getMonthNames(BuildContext context) {
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

  static List<String> _getWeekdayNames(BuildContext context) {
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

  static String formatCivilDay(BuildContext context, CivilDay day) {
    final dt = day.toDateTime();
    final weekdayStr = _getWeekdayNames(context)[dt.weekday - 1];
    final monthStr = _getMonthNames(context)[day.month - 1];
    return '$weekdayStr, $monthStr ${day.day}, ${day.year}';
  }

  static String formatDateTime(BuildContext context, DateTime dt) {
    final weekdayStr = _getWeekdayNames(context)[dt.weekday - 1];
    final monthStr = _getMonthNames(context)[dt.month - 1];
    final timeStr = TimeOfDay.fromDateTime(dt).format(context);
    return '$weekdayStr, $monthStr ${dt.day}, ${dt.year} $timeStr';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final action = SchedulerEngine.evaluate(task, dbInstances, now);

    final Set<String> toDeleteIds = action.instancesToDelete.toSet();
    final Map<String, TaskInstance> toUpdateMap = {
      for (final inst in action.instancesToUpdate) inst.id: inst,
    };

    final List<TaskInstance> currentInstances = [];
    for (final inst in dbInstances) {
      if (toDeleteIds.contains(inst.id)) continue;
      if (toUpdateMap.containsKey(inst.id)) {
        currentInstances.add(toUpdateMap[inst.id]!);
      } else {
        currentInstances.add(inst);
      }
    }
    currentInstances.addAll(action.instancesToSpawn);

    final futureInstances = _calculateFutureInstances(currentInstances);
    final pastInstances = _calculatePastInstances(currentInstances);

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
        if (futureInstances.isEmpty)
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
            itemCount: futureInstances.length,
            itemBuilder: (context, index) {
              return FutureOccurrenceCard(
                instance: futureInstances[index],
                index: index,
              );
            },
          ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        Text(
          context.l10n.pastOccurrencesHeader,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (pastInstances.isEmpty)
          Text(
            context.l10n.noPastOccurrencesPlaceholder,
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
            itemCount: pastInstances.length,
            itemBuilder: (context, index) {
              return PastOccurrenceCard(
                instance: pastInstances[index],
                index: index,
                now: now,
              );
            },
          ),
      ],
    );
  }
}

class FutureOccurrenceCard extends StatelessWidget {
  final TaskInstance instance;
  final int index;

  const FutureOccurrenceCard({
    super.key,
    required this.instance,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final occurrence = instance.scheduledDate;
    final startAbs = instance.startRelativeTime.referenceTo(occurrence);
    final dueAbs = instance.dueRelativeTime.referenceTo(occurrence);

    final detailsWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.visibility, size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                context.l10n.occurrenceAppears(
                  SpawnedInstancesList.formatDateTime(context, startAbs),
                ),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.alarm, size: 14, color: theme.colorScheme.error),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                context.l10n.occurrenceDue(
                  SpawnedInstancesList.formatDateTime(context, dueAbs),
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
      key: Key('spawned_occurrence_card_$index'),
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
          SpawnedInstancesList.formatCivilDay(context, occurrence),
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: detailsWidget,
      ),
    );
  }
}

class PastOccurrenceCard extends StatelessWidget {
  final TaskInstance instance;
  final int index;
  final DateTime now;

  const PastOccurrenceCard({
    super.key,
    required this.instance,
    required this.index,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final occurrence = instance.scheduledDate;
    final dueAbs = instance.dueRelativeTime.referenceTo(occurrence);

    final String statusText;
    final IconData iconData;
    final Color color;

    if (instance.status == 'completed') {
      final formattedCompletedAt = instance.completedAt != null
          ? SpawnedInstancesList.formatDateTime(context, instance.completedAt!)
          : '';
      statusText = context.l10n.occurrenceCompleted(formattedCompletedAt);
      iconData = Icons.check_circle;
      color = Colors.green;
    } else if (instance.status == 'skipped') {
      statusText = context.l10n.occurrenceSkipped;
      iconData = Icons.skip_next;
      color = theme.colorScheme.onSurfaceVariant;
    } else {
      if (now.isBefore(dueAbs)) {
        final formattedDueAbs = SpawnedInstancesList.formatDateTime(
          context,
          dueAbs,
        );
        statusText = context.l10n.occurrenceActive(formattedDueAbs);
        iconData = Icons.play_circle_outline;
        color = theme.colorScheme.primary;
      } else {
        final formattedDueAbs = SpawnedInstancesList.formatDateTime(
          context,
          dueAbs,
        );
        statusText = context.l10n.occurrenceMissed(formattedDueAbs);
        iconData = Icons.alarm;
        color = theme.colorScheme.error;
      }
    }

    final detailsWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(iconData, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                statusText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );

    return Card(
      key: Key('past_occurrence_card_$index'),
      margin: const EdgeInsets.only(bottom: 8.0),
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(iconData, color: color),
        ),
        title: Text(
          SpawnedInstancesList.formatCivilDay(context, occurrence),
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: detailsWidget,
      ),
    );
  }
}
