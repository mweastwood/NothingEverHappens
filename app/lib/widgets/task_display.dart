import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class TaskDisplay extends StatelessWidget {
  final String title;
  final String description;

  const TaskDisplay({
    super.key,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(title, style: Theme.of(context).textTheme.titleMedium),
        MarkdownBody(data: description, selectable: true),
      ],
    );
  }
}
