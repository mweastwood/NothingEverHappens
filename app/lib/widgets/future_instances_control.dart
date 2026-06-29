import 'package:flutter/material.dart';
import '../logic/l10n_extension.dart';

class FutureInstancesControl extends StatelessWidget {
  final int futureInstancesCount;
  final ValueChanged<int>? onChanged;

  const FutureInstancesControl({
    super.key,
    required this.futureInstancesCount,
    this.onChanged,
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.futureOccurrencesLabel,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.preCreatedFutureTasksHelper,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  key: const Key('remove_future_instances_button'),
                  icon: const Icon(Icons.remove),
                  onPressed: onChanged != null && futureInstancesCount > 1
                      ? () => onChanged!(futureInstancesCount - 1)
                      : null,
                ),
                Text(
                  '$futureInstancesCount',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  key: const Key('add_future_instances_button'),
                  icon: const Icon(Icons.add),
                  onPressed: onChanged != null && futureInstancesCount < 10
                      ? () => onChanged!(futureInstancesCount + 1)
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
