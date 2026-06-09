import 'package:flutter/material.dart';
import '../logic/task.dart';
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
    final l10n = context.l10n;
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: RecurrenceType.values.map((type) {
        final String label;
        switch (type) {
          case RecurrenceType.oneOff:
            label = l10n.oneOffLabel;
            break;
          case RecurrenceType.daily:
            label = l10n.dailyLabel;
            break;
          case RecurrenceType.weekly:
            label = l10n.weeklyLabel;
            break;
          case RecurrenceType.monthly:
            label = l10n.monthlyLabel;
            break;
          case RecurrenceType.yearly:
            label = l10n.yearlyLabel;
            break;
        }

        return ChoiceChip(
          key: Key('recurrence_chip_${type.name}'),
          label: Text(label),
          selected: selectedValue == type,
          onSelected: (selected) {
            if (selected) {
              onSelected(type);
            }
          },
        );
      }).toList(),
    );
  }
}
