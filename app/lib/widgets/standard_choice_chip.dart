import 'package:flutter/material.dart';

class StandardChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  const StandardChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      selectedColor: theme.colorScheme.primaryContainer,
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      labelStyle: TextStyle(
        fontSize: 13,
        color: selected
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurface,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: selected
            ? theme.colorScheme.primary
            : theme.colorScheme.outlineVariant,
      ),
    );
  }
}
