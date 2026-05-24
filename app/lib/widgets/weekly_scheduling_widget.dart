import 'package:flutter/material.dart';
import '../logic/relative_time.dart';
import 'relative_time_widget.dart';

class WeeklySchedulingWidget extends StatefulWidget {
  final DateTime startDate;
  final ValueChanged<DateTime> onStartDateChanged;
  final ValueNotifier<RelativeTime> startTimeController;
  final ValueNotifier<RelativeTime> dueTimeController;
  final TextEditingController intervalController;
  final Set<int> selectedWeekdays;
  final ValueChanged<Set<int>> onWeekdaysChanged;

  const WeeklySchedulingWidget({
    super.key,
    required this.startDate,
    required this.onStartDateChanged,
    required this.startTimeController,
    required this.dueTimeController,
    required this.intervalController,
    required this.selectedWeekdays,
    required this.onWeekdaysChanged,
  });

  @override
  State<WeeklySchedulingWidget> createState() => _WeeklySchedulingWidgetState();
}

class _WeeklySchedulingWidgetState extends State<WeeklySchedulingWidget> {
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      widget.onStartDateChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Times',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Start Time'),
            RelativeTimeWidget(
              controller: widget.startTimeController,
              constraint: RelativeTimeConstraint.dayOfOrAfter,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Due Time'),
            RelativeTimeWidget(
              controller: widget.dueTimeController,
              constraint: RelativeTimeConstraint.dayOfOrAfter,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Material(
          color: Colors.transparent,
          child: ListTile(
            title: const Text('Start Date'),
            subtitle: Text(
              '${widget.startDate.year}-${widget.startDate.month.toString().padLeft(2, '0')}-${widget.startDate.day.toString().padLeft(2, '0')}',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickDate,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: widget.intervalController,
          decoration: const InputDecoration(
            labelText: 'Weeks Interval',
            border: OutlineInputBorder(),
            helperText: 'E.g., 1 for every week',
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        const Text('Repeats on'),
        Wrap(
          spacing: 8.0,
          children: List.generate(7, (index) {
            final dayIndex = index + 1; // 1 = Monday
            final labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
            return FilterChip(
              label: Text(labels[index]),
              selected: widget.selectedWeekdays.contains(dayIndex),
              onSelected: (selected) {
                final newSet = Set<int>.from(widget.selectedWeekdays);
                if (selected) {
                  newSet.add(dayIndex);
                } else {
                  newSet.remove(dayIndex);
                }
                widget.onWeekdaysChanged(newSet);
              },
            );
          }),
        ),
      ],
    );
  }
}
