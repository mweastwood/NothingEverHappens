import 'package:flutter/material.dart';
import 'absolute_time_widget.dart';

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
            const Text('Due: ', style: TextStyle(fontSize: 18)),
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
                      const Expanded(
                        child: Text(
                          'When does this task need to be completed before it should be considered overdue?',
                          style: TextStyle(fontStyle: FontStyle.italic),
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
        const Text(
          'Advanced',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('Snooze Until: ', style: TextStyle(fontSize: 18)),
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
                      const Expanded(
                        child: Text(
                          'The task will be hidden from your primary list of tasks until this time.',
                          style: TextStyle(fontStyle: FontStyle.italic),
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
