import 'package:flutter/material.dart';
import '../../logic/l10n_extension.dart';
import '../standard_choice_chip.dart';

/// Section widget for family/personal task assignment toggle in CreateTaskScreen.
class TaskFamilyAssignmentSection extends StatelessWidget {
  final bool isFamily;
  final ValueChanged<bool>? onFamilyToggled;
  final bool readOnly;

  const TaskFamilyAssignmentSection({
    super.key,
    required this.isFamily,
    this.onFamilyToggled,
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
            Text(
              context.l10n.familyTab,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            StandardChoiceChip(
              key: const Key('is_family_toggle'),
              label: isFamily
                  ? context.l10n.familyTaskToggleLabel
                  : context.l10n.personalTaskToggleLabel,
              selected: isFamily,
              onSelected: readOnly
                  ? null
                  : (selected) {
                      onFamilyToggled?.call(selected);
                    },
            ),
          ],
        ),
      ),
    );
  }
}
