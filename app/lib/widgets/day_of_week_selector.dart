import 'package:flutter/material.dart';
import '../logic/l10n_extension.dart';

class DayOfWeekSelector extends StatelessWidget {
  final Set<int> selectedWeekdays;
  final ValueChanged<Set<int>> onChanged;
  final bool readOnly;
  final bool multiSelect;

  const DayOfWeekSelector({
    super.key,
    required this.selectedWeekdays,
    required this.onChanged,
    this.readOnly = false,
    this.multiSelect = true,
  });

  String _getShortDayName(BuildContext context, int dayIndex) {
    final l10n = context.l10n;
    final String fullName;
    switch (dayIndex) {
      case 1:
        fullName = l10n.weekdayMonday;
        break;
      case 2:
        fullName = l10n.weekdayTuesday;
        break;
      case 3:
        fullName = l10n.weekdayWednesday;
        break;
      case 4:
        fullName = l10n.weekdayThursday;
        break;
      case 5:
        fullName = l10n.weekdayFriday;
        break;
      case 6:
        fullName = l10n.weekdaySaturday;
        break;
      case 7:
        fullName = l10n.weekdaySunday;
        break;
      default:
        fullName = '';
    }
    if (fullName.length <= 3) return fullName;
    return fullName.substring(0, 3);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(7, (index) {
            final dayIndex = index + 1; // 1 = Monday, 7 = Sunday
            final isSelected = selectedWeekdays.contains(dayIndex);
            final dayName = _getShortDayName(context, dayIndex);

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: Material(
                  color: isSelected
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    key: Key('weekly_weekday_chip_$dayIndex'),
                    onTap: readOnly
                        ? null
                        : () {
                            if (multiSelect) {
                              final newSet = Set<int>.from(selectedWeekdays);
                              if (isSelected) {
                                newSet.remove(dayIndex);
                              } else {
                                newSet.add(dayIndex);
                              }
                              onChanged(newSet);
                            } else {
                              if (!isSelected) {
                                onChanged({dayIndex});
                              }
                            }
                          },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          dayName,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        if (multiSelect) ...[
          const SizedBox(height: 8),
          // Presets Row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _PresetButton(
                key: const Key('preset_weekdays_button'),
                label: l10n.presetWeekdays,
                readOnly: readOnly,
                onPressed: () => onChanged({1, 2, 3, 4, 5}),
              ),
              const SizedBox(width: 8),
              _PresetButton(
                key: const Key('preset_weekends_button'),
                label: l10n.presetWeekends,
                readOnly: readOnly,
                onPressed: () => onChanged({6, 7}),
              ),
              const SizedBox(width: 8),
              _PresetButton(
                key: const Key('preset_all_button'),
                label: l10n.presetAll,
                readOnly: readOnly,
                onPressed: () => onChanged({1, 2, 3, 4, 5, 6, 7}),
              ),
              const SizedBox(width: 8),
              _PresetButton(
                key: const Key('preset_clear_button'),
                label: l10n.presetClear,
                readOnly: readOnly,
                onPressed: () => onChanged({}),
              ),
            ],
          ),
          if (selectedWeekdays.isEmpty) ...[
            const SizedBox(height: 6),
            Text(
              l10n.selectAtLeastOneDayError,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _PresetButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool readOnly;

  const _PresetButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.readOnly,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: readOnly ? null : onPressed,
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: readOnly
              ? theme.colorScheme.onSurface.withValues(alpha: 0.38)
              : theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
