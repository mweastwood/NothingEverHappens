import 'package:flutter/material.dart';
import '../logic/civil_day.dart';
import '../logic/l10n_extension.dart';
import '../logic/relative_time.dart';
import '../logic/task_instance.dart';

/// Returns the localized full month names (January..December) for [context].
List<String> getLocalizedMonthNames(BuildContext context) =>
    context.l10n.monthNames;

/// Returns the localized full weekday names (Monday..Sunday) for [context].
List<String> getLocalizedWeekdayNames(BuildContext context) =>
    context.l10n.weekdayNames;

/// Formats a [CivilDay] as `<Weekday>, <Month> <day>, <year>`.
String formatLocalizedCivilDay(BuildContext context, CivilDay day) {
  final dt = day.toDateTime();
  final weekdayStr = getLocalizedWeekdayNames(context)[dt.weekday - 1];
  final monthStr = getLocalizedMonthNames(context)[day.month - 1];
  return '$weekdayStr, $monthStr ${day.day}, ${day.year}';
}

/// Formats a [DateTime] as `<Weekday>, <Month> <day>, <year> <localized time>`.
String formatLocalizedDateTime(BuildContext context, DateTime dt) {
  final weekdayStr = getLocalizedWeekdayNames(context)[dt.weekday - 1];
  final monthStr = getLocalizedMonthNames(context)[dt.month - 1];
  final timeStr = TimeOfDay.fromDateTime(dt).format(context);
  return '$weekdayStr, $monthStr ${dt.day}, ${dt.year} $timeStr';
}

/// Card displaying a numbered upcoming/future task occurrence with its
/// appearance (start) and due timestamps.
class FutureOccurrenceCard extends StatelessWidget {
  final CivilDay occurrence;
  final RelativeTime startRelativeTime;
  final RelativeTime dueRelativeTime;
  final int index;
  final String cardKeyPrefix;

  FutureOccurrenceCard({
    super.key,
    required TaskInstance instance,
    required this.index,
    this.cardKeyPrefix = 'spawned_occurrence_card',
  }) : occurrence = instance.scheduledDate,
       startRelativeTime = instance.startRelativeTime,
       dueRelativeTime = instance.dueRelativeTime;

  const FutureOccurrenceCard.fromRule({
    super.key,
    required this.occurrence,
    required this.startRelativeTime,
    required this.dueRelativeTime,
    required this.index,
    this.cardKeyPrefix = 'occurrence_card',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final startAbs = startRelativeTime.referenceTo(occurrence);
    final dueAbs = dueRelativeTime.referenceTo(occurrence);

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
                  formatLocalizedDateTime(context, startAbs),
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
                  formatLocalizedDateTime(context, dueAbs),
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
      key: Key('${cardKeyPrefix}_$index'),
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
          formatLocalizedCivilDay(context, occurrence),
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: detailsWidget,
      ),
    );
  }
}

/// Card displaying a past or currently active task occurrence with its
/// resolution or due status.
class PastOccurrenceCard extends StatelessWidget {
  final TaskInstance instance;
  final int index;
  final DateTime now;
  final String keyPrefix;

  const PastOccurrenceCard({
    super.key,
    required this.instance,
    required this.index,
    required this.now,
    this.keyPrefix = 'past',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final occurrence = instance.scheduledDate;
    final dueAbs = instance.dueRelativeTime.referenceTo(occurrence);

    final String statusText;
    final IconData iconData;
    final Color color;

    if (instance.status == TaskStatus.completed) {
      final formattedCompletedAt = instance.completedAt != null
          ? formatLocalizedDateTime(context, instance.completedAt!.toLocal())
          : '';
      statusText = context.l10n.occurrenceCompleted(formattedCompletedAt);
      iconData = Icons.check_circle;
      color = Colors.green;
    } else if (instance.status == TaskStatus.skipped) {
      statusText = context.l10n.occurrenceSkipped;
      iconData = Icons.skip_next;
      color = theme.colorScheme.onSurfaceVariant;
    } else {
      final formattedDueAbs = formatLocalizedDateTime(context, dueAbs);
      if (now.isBefore(dueAbs)) {
        statusText = context.l10n.occurrenceActive(formattedDueAbs);
        iconData = Icons.play_circle_outline;
        color = theme.colorScheme.primary;
      } else {
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
      key: Key('${keyPrefix}_occurrence_card_$index'),
      margin: const EdgeInsets.only(bottom: 8.0),
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(iconData, color: color),
        ),
        title: Text(
          formatLocalizedCivilDay(context, occurrence),
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: detailsWidget,
      ),
    );
  }
}
