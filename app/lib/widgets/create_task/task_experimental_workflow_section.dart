import 'package:flutter/material.dart';
import '../standard_choice_chip.dart';

/// Section widget for experimental workflow options and meal planning stage target times in CreateTaskScreen.
class TaskExperimentalWorkflowSection extends StatelessWidget {
  final bool isExperimentalExpanded;
  final VoidCallback? onToggleExperimentalExpanded;
  final bool isMealWorkflow;
  final ValueChanged<bool>? onMealWorkflowToggled;
  final TimeOfDay selectTime;
  final ValueChanged<TimeOfDay>? onSelectTimeChanged;
  final TimeOfDay shopTime;
  final ValueChanged<TimeOfDay>? onShopTimeChanged;
  final TimeOfDay prepTime;
  final ValueChanged<TimeOfDay>? onPrepTimeChanged;
  final bool readOnly;

  const TaskExperimentalWorkflowSection({
    super.key,
    required this.isExperimentalExpanded,
    this.onToggleExperimentalExpanded,
    required this.isMealWorkflow,
    this.onMealWorkflowToggled,
    required this.selectTime,
    this.onSelectTimeChanged,
    required this.shopTime,
    this.onShopTimeChanged,
    required this.prepTime,
    this.onPrepTimeChanged,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      child: Card(
        key: const Key('experimental_features_card'),
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
              InkWell(
                key: const Key('experimental_features_header'),
                borderRadius: BorderRadius.circular(8),
                onTap: onToggleExperimentalExpanded,
                child: Row(
                  children: [
                    Icon(
                      Icons.science_outlined,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Experimental Features',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Icon(
                      isExperimentalExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
              if (isExperimentalExpanded) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Task Workflow',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: [
                    StandardChoiceChip(
                      key: const Key('workflow_standard_chip'),
                      label: 'Standard Task',
                      selected: !isMealWorkflow,
                      onSelected: readOnly
                          ? null
                          : (selected) {
                              if (selected) {
                                onMealWorkflowToggled?.call(false);
                              }
                            },
                    ),
                    StandardChoiceChip(
                      key: const Key('workflow_meal_chip'),
                      label: 'Meal Planning Workflow',
                      selected: isMealWorkflow,
                      onSelected: readOnly
                          ? null
                          : (selected) {
                              if (selected) {
                                onMealWorkflowToggled?.call(true);
                              }
                            },
                    ),
                  ],
                ),
                if (isMealWorkflow) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Coordinates dinner across 3 stages: selecting a recipe, checking shopping list, and cooking instructions.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Stage Target Times',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: readOnly
                              ? null
                              : () async {
                                  final t = await showTimePicker(
                                    context: context,
                                    initialTime: selectTime,
                                  );
                                  if (t != null) {
                                    onSelectTimeChanged?.call(t);
                                  }
                                },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '1. Select',
                                style: TextStyle(fontSize: 10),
                              ),
                              Text(
                                selectTime.format(context),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: readOnly
                              ? null
                              : () async {
                                  final t = await showTimePicker(
                                    context: context,
                                    initialTime: shopTime,
                                  );
                                  if (t != null) {
                                    onShopTimeChanged?.call(t);
                                  }
                                },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '2. Shop',
                                style: TextStyle(fontSize: 10),
                              ),
                              Text(
                                shopTime.format(context),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: readOnly
                              ? null
                              : () async {
                                  final t = await showTimePicker(
                                    context: context,
                                    initialTime: prepTime,
                                  );
                                  if (t != null) {
                                    onPrepTimeChanged?.call(t);
                                  }
                                },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '3. Prep',
                                style: TextStyle(fontSize: 10),
                              ),
                              Text(
                                prepTime.format(context),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
