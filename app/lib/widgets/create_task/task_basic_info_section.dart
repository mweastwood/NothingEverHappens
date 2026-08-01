import 'package:flutter/material.dart';
import '../../logic/l10n_extension.dart';

/// Section widget for task title and description fields in CreateTaskScreen.
class TaskBasicInfoSection extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final FocusNode? titleFocusNode;
  final Key? titleFieldKey;
  final bool readOnly;

  const TaskBasicInfoSection({
    super.key,
    required this.titleController,
    required this.descriptionController,
    this.titleFocusNode,
    this.titleFieldKey,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              key: titleFieldKey,
              controller: titleController,
              focusNode: titleFocusNode,
              autofocus: !readOnly,
              enabled: !readOnly,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                labelText: context.l10n.titleFieldLabel,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.all(16),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return context.l10n.titleRequiredError;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: descriptionController,
              enabled: !readOnly,
              decoration: InputDecoration(
                labelText: context.l10n.descriptionFieldLabel,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.all(16),
              ),
              style: theme.textTheme.bodyMedium,
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }
}
