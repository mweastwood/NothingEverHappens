import 'package:flutter/material.dart';
import 'absolute_time_widget.dart';
import '../logic/l10n_extension.dart';

class OneOffSchedulingWidget extends StatefulWidget {
  final ValueNotifier<DateTime> dueDateTime;
  final ValueNotifier<DateTime> startDateTime;

  final ValueNotifier<TimeOfDay?>? notificationTimeController;

  const OneOffSchedulingWidget({
    super.key,
    required this.dueDateTime,
    required this.startDateTime,
    this.notificationTimeController,
  });

  @override
  State<OneOffSchedulingWidget> createState() => _OneOffSchedulingWidgetState();
}

class _OneOffSchedulingWidgetState extends State<OneOffSchedulingWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.startLabel,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        AbsoluteTimeWidget(controller: widget.startDateTime),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.help_outline,
              size: 14,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                context.l10n.snoozeUntilDescription,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          context.l10n.dueWithoutColon,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        AbsoluteTimeWidget(controller: widget.dueDateTime),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.help_outline,
              size: 14,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                context.l10n.dueDescription,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
        if (widget.notificationTimeController != null) ...[
          const SizedBox(height: 20),
          ValueListenableBuilder<TimeOfDay?>(
            valueListenable: widget.notificationTimeController!,
            builder: (context, notificationTime, _) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const Key('one_off_notification_button'),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime:
                            notificationTime ??
                            TimeOfDay.fromDateTime(widget.dueDateTime.value),
                      );
                      if (picked != null) {
                        widget.notificationTimeController!.value = picked;
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  context.l10n.notificationTimeLabel,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        height: 1.1,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  notificationTime != null
                                      ? notificationTime.format(context)
                                      : context.l10n.noneLabel,
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        height: 1.2,
                                        color: notificationTime != null
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (notificationTime != null) ...[
                                IconButton(
                                  key: const Key('one_off_notification_clear'),
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    widget.notificationTimeController!.value =
                                        null;
                                  },
                                  tooltip:
                                      context.l10n.clearNotificationTimeTooltip,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Icon(
                                notificationTime != null
                                    ? Icons.notifications_active
                                    : Icons.notifications_none,
                                color: notificationTime != null
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                size: 20,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
