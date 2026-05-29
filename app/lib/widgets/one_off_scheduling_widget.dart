import 'package:flutter/material.dart';
import 'absolute_time_widget.dart';
import '../logic/l10n_extension.dart';

class OneOffSchedulingWidget extends StatefulWidget {
  final ValueNotifier<DateTime> dueDateTime;
  final ValueNotifier<DateTime> startDateTime;

  const OneOffSchedulingWidget({
    super.key,
    required this.dueDateTime,
    required this.startDateTime,
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
            Text(context.l10n?.dueLabel ?? 'Due: ', style: const TextStyle(fontSize: 18)),
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
                          context.l10n?.dueDescription ?? 'When does this task need to be completed before it should be considered overdue?',
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
          context.l10n?.advancedHeader ?? 'Advanced',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(context.l10n?.snoozeUntilLabel ?? 'Snooze Until: ', style: const TextStyle(fontSize: 18)),
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
                          context.l10n?.snoozeUntilDescription ?? 'The task will be hidden from your primary list of tasks until this time.',
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
      ],
    );
  }
}
