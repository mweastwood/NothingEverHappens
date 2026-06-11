import 'package:flutter/material.dart';
import '../logic/task.dart';
import 'daily_time_list_widget.dart';
import '../logic/l10n_extension.dart';

class WeeklySchedulingWidget extends StatefulWidget {
  final DateTime startDate;
  final ValueChanged<DateTime> onStartDateChanged;
  final ValueNotifier<List<DailyOccurrenceTime>> dailyTimesController;
  final TextEditingController intervalController;
  final Set<int> selectedWeekdays;
  final ValueChanged<Set<int>> onWeekdaysChanged;

  const WeeklySchedulingWidget({
    super.key,
    required this.startDate,
    required this.onStartDateChanged,
    required this.dailyTimesController,
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
        DailyTimeListWidget(controller: widget.dailyTimesController),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              title: Text(
                context.l10n.startDateLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              subtitle: Text(
                '${widget.startDate.year}-${widget.startDate.month.toString().padLeft(2, '0')}-${widget.startDate.day.toString().padLeft(2, '0')}',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              trailing: Icon(
                Icons.calendar_today,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              onTap: _pickDate,
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: widget.intervalController,
          decoration: InputDecoration(
            labelText: context.l10n.weeksIntervalLabel,
            border: const OutlineInputBorder(),
            helperText: context.l10n.weeksIntervalHelper,
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        Text(context.l10n.repeatsOnLabel),
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
