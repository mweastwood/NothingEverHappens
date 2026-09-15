import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logic/l10n_extension.dart';
import '../../logic/label_repository.dart';
import '../../logic/task_label.dart';
import '../../screens/labels_screen.dart';

/// Section widget for assigning labels to a task in CreateTaskScreen.
class TaskLabelsSection extends ConsumerWidget {
  final bool isFamily;
  final List<String> selectedLabelIds;
  final ValueChanged<String> onToggleLabel;
  final bool readOnly;

  const TaskLabelsSection({
    super.key,
    required this.isFamily,
    required this.selectedLabelIds,
    required this.onToggleLabel,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final canEditFamily = ref.watch(canEditFamilyLabelsProvider);
    final canManage = !readOnly && (!isFamily || canEditFamily);
    final labelsAsync = isFamily
        ? ref.watch(familyLabelsStreamProvider)
        : ref.watch(personalLabelsStreamProvider);

    return SizedBox(
      width: double.infinity,
      child: Card(
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.l10n.labelsTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (canManage)
                    IconButton(
                      key: const Key('manage_labels_button'),
                      icon: const Icon(Icons.settings_outlined, size: 18),
                      tooltip: context.l10n.manageLabelsTooltip,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LabelsScreen(),
                          ),
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              labelsAsync.when(
                data: (labels) {
                  if (labels.isEmpty) {
                    final emptyText = isFamily
                        ? (canManage
                              ? context.l10n.noFamilyLabels
                              : context.l10n.noFamilyLabelsNonParent)
                        : context.l10n.noPersonalLabels;

                    return Row(
                      children: [
                        Expanded(
                          child: Text(
                            emptyText,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (canManage)
                          TextButton.icon(
                            key: const Key('empty_manage_labels_button'),
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(context.l10n.addLabelButton),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LabelsScreen(),
                                ),
                              );
                            },
                          ),
                      ],
                    );
                  }

                  return Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: [
                      for (final label in labels)
                        Builder(
                          builder: (context) {
                            final isSelected = selectedLabelIds.contains(
                              label.id,
                            );
                            final color = LabelPalette.getColor(
                              label.colorKey,
                              context,
                            );
                            return FilterChip(
                              key: Key('label_chip_${label.id}'),
                              avatar: Icon(
                                LabelIcons.getIcon(label.iconKey),
                                size: 18,
                                color: isSelected
                                    ? color
                                    : color.withValues(alpha: 0.8),
                              ),
                              label: Text(label.name),
                              selected: isSelected,
                              selectedColor: color.withValues(alpha: 0.2),
                              checkmarkColor: color,
                              side: BorderSide(
                                color: isSelected
                                    ? color
                                    : theme.colorScheme.outlineVariant,
                              ),
                              onSelected: readOnly
                                  ? null
                                  : (_) => onToggleLabel(label.id),
                            );
                          },
                        ),
                    ],
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                error: (error, _) => Text(
                  context.l10n.errorLoadingLabels(error.toString()),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
