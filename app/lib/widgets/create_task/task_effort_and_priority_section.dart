import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../logic/l10n_extension.dart';
import '../../logic/task_priority.dart';
import '../standard_choice_chip.dart';

/// Section widget for task effort duration, priority selection, and capacity settings in CreateTaskScreen.
class TaskEffortAndPrioritySection extends StatelessWidget {
  final TextEditingController estimatedDurationController;
  final TaskPriority priority;
  final ValueChanged<TaskPriority>? onPriorityChanged;
  final bool skipIfNoCapacity;
  final ValueChanged<bool>? onSkipIfNoCapacityChanged;
  final bool readOnly;
  final bool isWide;

  const TaskEffortAndPrioritySection({
    super.key,
    required this.estimatedDurationController,
    required this.priority,
    this.onPriorityChanged,
    required this.skipIfNoCapacity,
    this.onSkipIfNoCapacityChanged,
    this.readOnly = false,
    this.isWide = false,
  });

  String _getHumanizedDuration(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    final minutes = int.tryParse(trimmed);
    if (minutes == null || minutes <= 0) return '';

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (hours > 0) {
      final hourStr = hours == 1 ? '1 hr' : '$hours hrs';
      final minStr = remainingMinutes > 0 ? '$remainingMinutes min' : '';
      return minStr.isEmpty ? '($hourStr)' : '($hourStr $minStr)';
    } else {
      return '($minutes min)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final presets = [
      (label: '5 min', minutes: 5),
      (label: '15 min', minutes: 15),
      (label: '30 min', minutes: 30),
      (label: '1 hour', minutes: 60),
      (label: '2 hours', minutes: 120),
    ];

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
              Text(
                context.l10n.effortAndPriorityLabel,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            key: const Key('estimated_effort_decrement_button'),
                            icon: const Icon(Icons.remove),
                            onPressed: readOnly
                                ? null
                                : () {
                                    final current =
                                        int.tryParse(
                                          estimatedDurationController.text
                                              .trim(),
                                        ) ??
                                        0;
                                    if (current > 1) {
                                      final val = current - 5;
                                      final newValue = val < 1 ? 1 : val;
                                      estimatedDurationController.text =
                                          newValue.toString();
                                    }
                                  },
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            constraints: const BoxConstraints(),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ValueListenableBuilder<TextEditingValue>(
                                    valueListenable:
                                        estimatedDurationController,
                                    builder: (context, value, _) {
                                      final humanized = _getHumanizedDuration(
                                        value.text,
                                      );
                                      return Text(
                                        humanized.isNotEmpty
                                            ? '${context.l10n.estimatedEffortFieldLabel} $humanized'
                                            : context
                                                  .l10n
                                                  .estimatedEffortFieldLabel,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              height: 1.1,
                                            ),
                                        textAlign: TextAlign.center,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 4),
                                  TextFormField(
                                    key: const Key('estimated_effort_field'),
                                    controller: estimatedDurationController,
                                    enabled: !readOnly,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      height: 1.2,
                                    ),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    validator: (value) {
                                      if (value != null && value.isNotEmpty) {
                                        final val = int.tryParse(value);
                                        if (val == null || val <= 0) {
                                          return context
                                              .l10n
                                              .estimatedEffortValidationError;
                                        }
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            key: const Key('estimated_effort_increment_button'),
                            icon: const Icon(Icons.add),
                            onPressed: readOnly
                                ? null
                                : () {
                                    final current =
                                        int.tryParse(
                                          estimatedDurationController.text
                                              .trim(),
                                        ) ??
                                        0;
                                    final newValue = current == 0
                                        ? 5
                                        : current + 5;
                                    estimatedDurationController.text = newValue
                                        .toString();
                                  },
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: estimatedDurationController,
                      builder: (context, value, _) {
                        return Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: presets.map((preset) {
                            final isSelected =
                                value.text.trim() == preset.minutes.toString();
                            return StandardChoiceChip(
                              key: Key('preset_chip_${preset.minutes}'),
                              label: preset.label,
                              selected: isSelected,
                              onSelected: readOnly
                                  ? null
                                  : (selected) {
                                      if (selected) {
                                        estimatedDurationController.text =
                                            preset.minutes.toString();
                                      } else {
                                        estimatedDurationController.clear();
                                      }
                                    },
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.estimatedEffortHelper,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.taskPriorityLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    key: const Key('task_priority_dropdown'),
                    spacing: 6.0,
                    runSpacing: 6.0,
                    children: TaskPriority.values.map((p) {
                      final String label;
                      switch (p) {
                        case TaskPriority.low:
                          label = context.l10n.priorityLow;
                          break;
                        case TaskPriority.medium:
                          label = context.l10n.priorityMedium;
                          break;
                        case TaskPriority.high:
                          label = context.l10n.priorityHigh;
                          break;
                      }
                      return StandardChoiceChip(
                        key: Key('priority_chip_${p.name}'),
                        label: label,
                        selected: priority == p,
                        onSelected: readOnly
                            ? null
                            : (selected) {
                                if (selected) {
                                  onPriorityChanged?.call(p);
                                }
                              },
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                key: const Key('skip_if_no_capacity_checkbox'),
                title: Text(
                  context.l10n.skipIfNoCapacityLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  context.l10n.skipIfNoCapacityHelper,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                value: skipIfNoCapacity,
                onChanged: readOnly
                    ? null
                    : (val) {
                        onSkipIfNoCapacityChanged?.call(val ?? false);
                      },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
