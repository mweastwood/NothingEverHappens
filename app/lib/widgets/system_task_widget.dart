import 'package:flutter/material.dart';
import '../logic/system_tasks/system_task.dart';

enum SystemTaskWidgetVariant { card, banner }

class SystemTaskWidget extends StatelessWidget {
  final SystemTask task;
  final SystemTaskWidgetVariant variant;
  final Key? actionButtonKey;

  const SystemTaskWidget({
    super.key,
    required this.task,
    this.variant = SystemTaskWidgetVariant.card,
    this.actionButtonKey,
  });

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case SystemTaskWidgetVariant.card:
        return SystemTaskCard(task: task, actionButtonKey: actionButtonKey);
      case SystemTaskWidgetVariant.banner:
        return SystemTaskBanner(task: task);
    }
  }
}

class SystemTaskCard extends StatelessWidget {
  final SystemTask task;
  final Key? actionButtonKey;

  const SystemTaskCard({super.key, required this.task, this.actionButtonKey});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.primaryContainer,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(task.icon, color: theme.colorScheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                if (task.isDismissible && task.onDismiss != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: task.onDismiss,
                    color: theme.colorScheme.onPrimaryContainer,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                task.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer.withValues(
                    alpha: 0.8,
                  ),
                ),
              ),
            ],
            if (task.actionLabel != null ||
                task.secondaryActionLabel != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (task.secondaryActionLabel != null)
                    TextButton(
                      onPressed: task.onSecondaryAction,
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.onPrimaryContainer,
                      ),
                      child: Text(task.secondaryActionLabel!),
                    ),
                  if (task.secondaryActionLabel != null &&
                      task.actionLabel != null)
                    const SizedBox(width: 8),
                  if (task.actionLabel != null)
                    FilledButton(
                      key: actionButtonKey,
                      onPressed: task.onAction,
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.onPrimaryContainer,
                        foregroundColor: theme.colorScheme.primaryContainer,
                      ),
                      child: Text(task.actionLabel!),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SystemTaskBanner extends StatelessWidget {
  final SystemTask task;

  const SystemTaskBanner({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.primaryContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: ListTile(
        leading: Icon(task.icon, color: theme.colorScheme.onPrimaryContainer),
        title: Text(
          task.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        subtitle: task.description.isNotEmpty
            ? Text(
                task.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer.withValues(
                    alpha: 0.8,
                  ),
                ),
              )
            : null,
        trailing: Icon(
          Icons.chevron_right,
          color: theme.colorScheme.onPrimaryContainer,
        ),
        onTap: task.onTap,
      ),
    );
  }
}
