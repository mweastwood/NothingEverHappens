import 'package:flutter/material.dart';
import '../../logic/l10n_extension.dart';
import '../../logic/schedule_rules/task_schedule_rule.dart';
import '../schedule_config_card.dart';

/// Section widget for list of schedule configuration cards and add schedule action in CreateTaskScreen.
class TaskScheduleListSection extends StatelessWidget {
  final List<TaskScheduleRule> schedules;
  final int? expandedScheduleIndex;
  final Function(int index, TaskScheduleRule newSchedule)? onScheduleChanged;
  final Function(int index)? onScheduleDeleted;
  final Function(int index, bool expanded)? onExpansionChanged;
  final VoidCallback? onAddSchedule;
  final bool readOnly;

  const TaskScheduleListSection({
    super.key,
    required this.schedules,
    this.expandedScheduleIndex,
    this.onScheduleChanged,
    this.onScheduleDeleted,
    this.onExpansionChanged,
    this.onAddSchedule,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AbsorbPointer(
          absorbing: readOnly,
          child: Opacity(
            opacity: readOnly ? 0.6 : 1.0,
            child: Column(
              children: [
                for (int i = 0; i < schedules.length; i++)
                  ScheduleConfigCard(
                    key: ValueKey(schedules[i].id),
                    schedule: schedules[i],
                    onChanged: (newSchedule) {
                      onScheduleChanged?.call(i, newSchedule);
                    },
                    onDelete: schedules.length > 1
                        ? () {
                            onScheduleDeleted?.call(i);
                          }
                        : null,
                    isExpanded: expandedScheduleIndex == i,
                    onExpansionChanged: (expanded) {
                      onExpansionChanged?.call(i, expanded);
                    },
                  ),
                if (!readOnly) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('add_schedule_button'),
                    onPressed: onAddSchedule,
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n.addScheduleButton),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
