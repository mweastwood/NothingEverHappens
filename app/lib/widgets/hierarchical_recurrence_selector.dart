import 'package:flutter/material.dart';
import '../logic/task_schedule_rule.dart';

class HierarchicalRecurrenceSelector extends StatefulWidget {
  final HierarchicalRecurrenceKind selectedValue;
  final ValueChanged<HierarchicalRecurrenceKind> onSelected;
  final bool readOnly;

  const HierarchicalRecurrenceSelector({
    super.key,
    required this.selectedValue,
    required this.onSelected,
    this.readOnly = false,
  });

  @override
  State<HierarchicalRecurrenceSelector> createState() =>
      _HierarchicalRecurrenceSelectorState();
}

enum _Cadence { daily, weekly, monthly, yearly }

class _HierarchicalRecurrenceSelectorState
    extends State<HierarchicalRecurrenceSelector> {
  late HierarchicalRecurrenceKind _lastRepeatingValue;

  @override
  void initState() {
    super.initState();
    _lastRepeatingValue =
        widget.selectedValue == HierarchicalRecurrenceKind.oneOff
        ? HierarchicalRecurrenceKind.dailyFixed
        : widget.selectedValue;
  }

  @override
  void didUpdateWidget(HierarchicalRecurrenceSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedValue != HierarchicalRecurrenceKind.oneOff &&
        widget.selectedValue != oldWidget.selectedValue) {
      setState(() {
        _lastRepeatingValue = widget.selectedValue;
      });
    }
  }

  _Cadence _getCadence(HierarchicalRecurrenceKind kind) {
    switch (kind) {
      case HierarchicalRecurrenceKind.oneOff:
      case HierarchicalRecurrenceKind.dailyFixed:
      case HierarchicalRecurrenceKind.dailyCompletionRelative:
        return _Cadence.daily;
      case HierarchicalRecurrenceKind.weeklyFixed:
      case HierarchicalRecurrenceKind.weeklyCompletionRelative:
        return _Cadence.weekly;
      case HierarchicalRecurrenceKind.monthlyFixedDay:
      case HierarchicalRecurrenceKind.monthlyNthWeekday:
      case HierarchicalRecurrenceKind.monthlyCompletionRelative:
        return _Cadence.monthly;
      case HierarchicalRecurrenceKind.yearlyFixed:
      case HierarchicalRecurrenceKind.yearlyCompletionRelative:
        return _Cadence.yearly;
    }
  }

  List<_SpecializationOption> _getOptions(_Cadence cadence) {
    switch (cadence) {
      case _Cadence.daily:
        return [
          const _SpecializationOption(
            kind: HierarchicalRecurrenceKind.dailyFixed,
            icon: Icons.calendar_today,
            title: 'On a fixed schedule',
            subtitle:
                'Repeats every N days since last scheduled (e.g. every 3 days)',
          ),
          const _SpecializationOption(
            kind: HierarchicalRecurrenceKind.dailyCompletionRelative,
            icon: Icons.replay,
            title: 'Based on when last completed',
            subtitle:
                'Repeats N days after you finish it (e.g. 3 days after completed)',
          ),
        ];
      case _Cadence.weekly:
        return [
          const _SpecializationOption(
            kind: HierarchicalRecurrenceKind.weeklyFixed,
            icon: Icons.calendar_view_week,
            title: 'On fixed days of the week',
            subtitle:
                'Repeats on specific weekdays (e.g. every Monday & Friday)',
          ),
          const _SpecializationOption(
            kind: HierarchicalRecurrenceKind.weeklyCompletionRelative,
            icon: Icons.replay,
            title: 'Based on when last completed',
            subtitle:
                'Repeats N weeks after you finish it (e.g. 2 weeks after completed)',
          ),
        ];
      case _Cadence.monthly:
        return [
          const _SpecializationOption(
            kind: HierarchicalRecurrenceKind.monthlyFixedDay,
            icon: Icons.calendar_view_month,
            title: 'On a fixed day of the month',
            subtitle:
                'Repeats on a specific calendar day (e.g. on the 15th of the month)',
          ),
          const _SpecializationOption(
            kind: HierarchicalRecurrenceKind.monthlyNthWeekday,
            icon: Icons.format_list_numbered,
            title: 'On a specific weekday of the month',
            subtitle:
                'Repeats on a relative weekday (e.g. on the second Tuesday)',
          ),
          const _SpecializationOption(
            kind: HierarchicalRecurrenceKind.monthlyCompletionRelative,
            icon: Icons.replay,
            title: 'Based on when last completed',
            subtitle:
                'Repeats N months after you finish it (e.g. 1 month after completed)',
          ),
        ];
      case _Cadence.yearly:
        return [
          const _SpecializationOption(
            kind: HierarchicalRecurrenceKind.yearlyFixed,
            icon: Icons.calendar_today,
            title: 'On a fixed date of the year',
            subtitle:
                'Repeats on a specific calendar date (e.g. every October 12th)',
          ),
          const _SpecializationOption(
            kind: HierarchicalRecurrenceKind.yearlyCompletionRelative,
            icon: Icons.replay,
            title: 'Based on when last completed',
            subtitle:
                'Repeats N years after you finish it (e.g. 1 year after completed)',
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOneOff = widget.selectedValue == HierarchicalRecurrenceKind.oneOff;
    final currentRepeatingKind = isOneOff
        ? _lastRepeatingValue
        : widget.selectedValue;
    final activeCadence = _getCadence(currentRepeatingKind);
    final options = _getOptions(activeCadence);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. One-off vs Repeating Segmented Button
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment<bool>(
              value: true,
              icon: Icon(Icons.event),
              label: Text('One-off'),
            ),
            ButtonSegment<bool>(
              value: false,
              icon: Icon(Icons.replay),
              label: Text('Repeating'),
            ),
          ],
          selected: {isOneOff},
          onSelectionChanged: widget.readOnly
              ? null
              : (Set<bool> selection) {
                  if (selection.isNotEmpty) {
                    final val = selection.first;
                    if (val) {
                      widget.onSelected(HierarchicalRecurrenceKind.oneOff);
                    } else {
                      widget.onSelected(_lastRepeatingValue);
                    }
                  }
                },
        ),

        // If Repeating is selected, show progressive disclosure
        if (!isOneOff) ...[
          const SizedBox(height: 16),

          // 2. Cadence Chips
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: _Cadence.values.map((cadence) {
              final isSelected = activeCadence == cadence;
              final String label;
              switch (cadence) {
                case _Cadence.daily:
                  label = 'Daily';
                  break;
                case _Cadence.weekly:
                  label = 'Weekly';
                  break;
                case _Cadence.monthly:
                  label = 'Monthly';
                  break;
                case _Cadence.yearly:
                  label = 'Yearly';
                  break;
              }

              return ChoiceChip(
                key: Key('recurrence_chip_${cadence.name}'),
                label: Text(label),
                selected: isSelected,
                onSelected: widget.readOnly
                    ? null
                    : (selected) {
                        if (selected) {
                          // Pick the first specialization of the new cadence as default
                          final newOptions = _getOptions(cadence);
                          widget.onSelected(newOptions.first.kind);
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
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                side: BorderSide(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),

          // 3. Nested Well for Cadence Specializations
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16.0,
                    top: 12.0,
                    bottom: 4.0,
                  ),
                  child: Text(
                    'RECURRENCE TYPE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.8,
                      ),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: options.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.3,
                    ),
                  ),
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final isOptionSelected =
                        widget.selectedValue == option.kind;

                    return InkWell(
                      onTap: widget.readOnly
                          ? null
                          : () {
                              widget.onSelected(option.kind);
                            },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 12.0,
                        ),
                        decoration: BoxDecoration(
                          color: isOptionSelected
                              ? theme.colorScheme.primaryContainer.withValues(
                                  alpha: 0.25,
                                )
                              : Colors.transparent,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 2.0,
                                right: 12.0,
                              ),
                              child: Icon(
                                option.icon,
                                size: 20,
                                color: isOptionSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    option.title,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: isOptionSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isOptionSelected
                                          ? theme.colorScheme.onPrimaryContainer
                                          : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    option.subtitle,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isOptionSelected)
                              Icon(
                                Icons.check_circle,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SpecializationOption {
  final HierarchicalRecurrenceKind kind;
  final IconData icon;
  final String title;
  final String subtitle;

  const _SpecializationOption({
    required this.kind,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
