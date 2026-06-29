import 'package:flutter/material.dart';
import '../logic/civil_day.dart';
import '../logic/task_schedule.dart';
import '../logic/task_instance.dart';
import '../logic/scheduler_engine.dart';
import '../logic/l10n_extension.dart';

class SpawnedFutureInstancesList extends StatelessWidget {
  final TaskSchedule task;
  final List<TaskInstance> dbInstances;
  final DateTime now;

  const SpawnedFutureInstancesList({
    super.key,
    required this.task,
    required this.dbInstances,
    required this.now,
  });

  List<TaskInstance> _calculateFutureInstances() {
    final action = SchedulerEngine.evaluate(
      task,
      dbInstances,
      now,
      futureInstancesCount: task.futureInstancesCount,
    );

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
    final instances = _calculateFutureInstances();

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
        if (instances.isEmpty)
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
            itemCount: instances.length,
            itemBuilder: (context, index) {
              final inst = instances[index];
              final occurrence = inst.scheduledDate;
              final startAbs = inst.startRelativeTime.referenceTo(occurrence);
              final dueAbs = inst.dueRelativeTime.referenceTo(occurrence);

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
