import 'package:flutter/material.dart';
import '../logic/scheduling_policy.dart';
import '../logic/l10n_extension.dart';

class ScheduleTypeSelector extends StatelessWidget {
  final SchedulingType selectedType;
  final ValueChanged<SchedulingType> onChanged;
  final bool readOnly;

  const ScheduleTypeSelector({
    super.key,
    required this.selectedType,
    required this.onChanged,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<SchedulingType>(
      segments: [
        ButtonSegment<SchedulingType>(
          value: SchedulingType.fixedCalendar,
          icon: const Icon(Icons.calendar_today),
          label: Text(context.l10n.fixedCalendarLabel),
        ),
        ButtonSegment<SchedulingType>(
          value: SchedulingType.completionRelative,
          icon: const Icon(Icons.replay),
          label: Text(context.l10n.completionRelativeLabel),
        ),
        ButtonSegment<SchedulingType>(
          value: SchedulingType.capacityDependent,
          icon: const Icon(Icons.bar_chart),
          label: Text(context.l10n.capacityDependentLabel),
        ),
      ],
      selected: {selectedType},
      onSelectionChanged: readOnly
          ? null
          : (Set<SchedulingType> selection) {
              if (selection.isNotEmpty) {
                onChanged(selection.first);
              }
            },
    );
  }
}
