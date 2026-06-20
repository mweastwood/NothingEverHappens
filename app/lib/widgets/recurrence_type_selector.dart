import 'package:flutter/material.dart';
import '../logic/task_schedule.dart';
import '../logic/l10n_extension.dart';

class RecurrenceTypeSelector extends StatelessWidget {
  final RecurrenceType selectedValue;
  final ValueChanged<RecurrenceType> onSelected;

  const RecurrenceTypeSelector({
    super.key,
    required this.selectedValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOneOff = selectedValue == RecurrenceType.oneOff;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SegmentedButton<bool>(
          segments: [
            ButtonSegment<bool>(
              value: true,
              icon: const Icon(Icons.event),
              label: Text(context.l10n.oneOffLabel),
            ),
            ButtonSegment<bool>(
              value: false,
              icon: const Icon(Icons.replay),
              label: Text(context.l10n.repeatingLabel),
            ),
          ],
          selected: {isOneOff},
          onSelectionChanged: (Set<bool> selection) {
            if (selection.isNotEmpty) {
              final val = selection.first;
              if (val) {
                onSelected(RecurrenceType.oneOff);
              } else {
                onSelected(RecurrenceType.daily);
              }
            }
          },
        ),
        if (!isOneOff) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children:
                [
                  RecurrenceType.daily,
                  RecurrenceType.weekly,
                  RecurrenceType.monthly,
                  RecurrenceType.yearly,
                ].map((type) {
                  final String label;
                  switch (type) {
                    case RecurrenceType.daily:
                      label = context.l10n.dailyLabel;
                      break;
                    case RecurrenceType.weekly:
                      label = context.l10n.weeklyLabel;
                      break;
                    case RecurrenceType.monthly:
                      label = context.l10n.monthlyLabel;
                      break;
                    case RecurrenceType.yearly:
                      label = context.l10n.yearlyLabel;
                      break;
                    default:
                      label = '';
                  }
                  final isSelected = selectedValue == type;
                  return ChoiceChip(
                    key: Key('recurrence_chip_${type.name}'),
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        onSelected(type);
                      }
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    selectedColor: theme.colorScheme.primaryContainer,
                    backgroundColor: theme.colorScheme.surfaceContainerLow,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      color: isSelected
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                    ),
                  );
                }).toList(),
          ),
        ],
      ],
    );
  }
}
