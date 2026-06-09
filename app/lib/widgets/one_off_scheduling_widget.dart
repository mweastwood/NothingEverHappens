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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(context.l10n.dueLabel, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AbsoluteTimeWidget(controller: widget.dueDateTime),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.help_outline,
                        size: 18,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.l10n.dueDescription,
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 24),
        Text(
          context.l10n.advancedHeader,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              context.l10n.snoozeUntilLabel,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AbsoluteTimeWidget(controller: widget.startDateTime),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.help_outline,
                        size: 18,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.l10n.snoozeUntilDescription,
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (widget.notificationTimeController != null) ...[
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          Text(
            context.l10n.notificationTimeLabel,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<TimeOfDay?>(
            valueListenable: widget.notificationTimeController!,
            builder: (context, notificationTime, _) {
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      notificationTime != null
                          ? 'Reminder scheduled at ${notificationTime.format(context)}'
                          : 'No reminder scheduled',
                      style: TextStyle(
                        fontSize: 15,
                        color: notificationTime != null
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (notificationTime != null) ...[
                    OutlinedButton.icon(
                      key: const Key('one_off_notification_button'),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: notificationTime,
                        );
                        if (picked != null) {
                          widget.notificationTimeController!.value = picked;
                        }
                      },
                      icon: const Icon(Icons.notifications_active),
                      label: Text(notificationTime.format(context)),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      key: const Key('one_off_notification_clear'),
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        widget.notificationTimeController!.value = null;
                      },
                      tooltip: context.l10n.clearNotificationTimeTooltip,
                    ),
                  ] else
                    OutlinedButton.icon(
                      key: const Key('one_off_notification_button'),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(
                            widget.dueDateTime.value,
                          ),
                        );
                        if (picked != null) {
                          widget.notificationTimeController!.value = picked;
                        }
                      },
                      icon: const Icon(Icons.notifications_none),
                      label: Text(context.l10n.noneLabel),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}
