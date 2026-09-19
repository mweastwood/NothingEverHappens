import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/l10n_extension.dart';
import '../logic/label_repository.dart';
import '../logic/task_filter.dart';
import '../logic/task_instance.dart';
import '../logic/task_label.dart';

class TaskFilterBottomSheet extends ConsumerWidget {
  const TaskFilterBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    final container = ProviderScope.containerOf(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return UncontrolledProviderScope(
          container: container,
          child: const TaskFilterBottomSheet(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final filterState = ref.watch(taskFilterProvider);
    final labelsMap = ref.watch(allLabelsMapProvider);
    final labels = labelsMap.values.toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Text(
                    context.l10n.filtersTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (filterState.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        ref.read(taskFilterProvider.notifier).state =
                            const TaskFilterState();
                      },
                      child: Text(context.l10n.filterReset),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Urgency Section
              _buildSectionTitle(context, context.l10n.filterUrgencySection),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: [
                  FilterChip(
                    avatar: const Icon(Icons.alarm_off, size: 16),
                    label: Text(context.l10n.filterOverdue),
                    selected: filterState.selectedUrgencies.contains(
                      TaskUrgencyFilter.overdue,
                    ),
                    onSelected: (_) {
                      ref.read(taskFilterProvider.notifier).state = filterState
                          .toggleUrgency(TaskUrgencyFilter.overdue);
                    },
                  ),
                  FilterChip(
                    avatar: const Icon(Icons.today, size: 16),
                    label: Text(context.l10n.filterDueToday),
                    selected: filterState.selectedUrgencies.contains(
                      TaskUrgencyFilter.dueToday,
                    ),
                    onSelected: (_) {
                      ref.read(taskFilterProvider.notifier).state = filterState
                          .toggleUrgency(TaskUrgencyFilter.dueToday);
                    },
                  ),
                  FilterChip(
                    avatar: const Icon(Icons.event, size: 16),
                    label: Text(context.l10n.filterUpcoming),
                    selected: filterState.selectedUrgencies.contains(
                      TaskUrgencyFilter.upcoming,
                    ),
                    onSelected: (_) {
                      ref.read(taskFilterProvider.notifier).state = filterState
                          .toggleUrgency(TaskUrgencyFilter.upcoming);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Priority Section
              _buildSectionTitle(context, context.l10n.filterPrioritySection),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: [
                  FilterChip(
                    avatar: const Icon(
                      Icons.priority_high,
                      size: 16,
                      color: Colors.red,
                    ),
                    label: Text(context.l10n.priorityHigh),
                    selected: filterState.selectedPriorities.contains(
                      TaskPriority.high,
                    ),
                    onSelected: (_) {
                      ref.read(taskFilterProvider.notifier).state = filterState
                          .togglePriority(TaskPriority.high);
                    },
                  ),
                  FilterChip(
                    avatar: const Icon(
                      Icons.remove,
                      size: 16,
                      color: Colors.orange,
                    ),
                    label: Text(context.l10n.priorityMedium),
                    selected: filterState.selectedPriorities.contains(
                      TaskPriority.medium,
                    ),
                    onSelected: (_) {
                      ref.read(taskFilterProvider.notifier).state = filterState
                          .togglePriority(TaskPriority.medium);
                    },
                  ),
                  FilterChip(
                    avatar: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: Colors.blue,
                    ),
                    label: Text(context.l10n.priorityLow),
                    selected: filterState.selectedPriorities.contains(
                      TaskPriority.low,
                    ),
                    onSelected: (_) {
                      ref.read(taskFilterProvider.notifier).state = filterState
                          .togglePriority(TaskPriority.low);
                    },
                  ),
                ],
              ),

              // Labels Section
              if (labels.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildSectionTitle(context, context.l10n.filterLabelsSection),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: [
                    for (final label in labels)
                      FilterChip(
                        avatar: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: LabelPalette.getColor(
                              label.colorKey,
                              context,
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (label.iconKey.isNotEmpty) ...[
                              Icon(
                                LabelIcons.getIcon(label.iconKey),
                                size: 14,
                                color: LabelPalette.getColor(
                                  label.colorKey,
                                  context,
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(label.name),
                          ],
                        ),
                        selected: filterState.selectedLabelIds.contains(
                          label.id,
                        ),
                        onSelected: (_) {
                          ref.read(taskFilterProvider.notifier).state =
                              filterState.toggleLabel(label.id);
                        },
                      ),
                  ],
                ),
              ],

              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.filterApply),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
