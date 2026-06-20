import 'package:flutter/material.dart';
import '../logic/scheduling_policy.dart';

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
      segments: const [
        ButtonSegment<SchedulingType>(
          value: SchedulingType.fixedCalendar,
          icon: Icon(Icons.calendar_today),
          label: Text('Fixed Calendar'),
        ),
        ButtonSegment<SchedulingType>(
          value: SchedulingType.completionRelative,
          icon: Icon(Icons.replay),
          label: Text('Completion-Relative'),
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
