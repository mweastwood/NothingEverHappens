import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../logic/task_delta.dart';

class TaskDeltaWidget extends StatelessWidget {
  final TaskDelta delta;

  const TaskDeltaWidget({super.key, required this.delta});

  @override
  Widget build(BuildContext context) {
    final title = 'Operation: ${delta.operation}';

    // Formatting the description
    final buffer = StringBuffer();
    buffer.writeln('**TaskSchedule ID:** ${delta.taskId}');
    buffer.writeln();
    buffer.writeln('**Timestamp:** ${delta.timestamp.toIso8601String()}');
    buffer.writeln();
    buffer.writeln('**User ID:** ${delta.userId}');
    buffer.writeln();

    if (delta.changedFields.isNotEmpty) {
      buffer.writeln('**Changes:**');
      delta.changedFields.forEach((key, value) {
        buffer.writeln('- $key: $value');
      });
    } else {
      buffer.writeln('No fields changed.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SelectableText(title, style: Theme.of(context).textTheme.titleMedium),
        MarkdownBody(data: buffer.toString(), selectable: true),
      ],
    );
  }
}
