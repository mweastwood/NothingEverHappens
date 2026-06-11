import 'package:flutter/material.dart';
import '../logic/task.dart';
import 'daily_time_list_widget.dart';
import '../logic/l10n_extension.dart';

class DailySchedulingWidget extends StatefulWidget {
  final DateTime startDate;
  final ValueChanged<DateTime> onStartDateChanged;
  final ValueNotifier<List<DailyOccurrenceTime>> dailyTimesController;
  final TextEditingController intervalController;

  const DailySchedulingWidget({
    super.key,
    required this.startDate,
    required this.onStartDateChanged,
    required this.dailyTimesController,
    required this.intervalController,
  });

  @override
  State<DailySchedulingWidget> createState() => _DailySchedulingWidgetState();
}

class _DailySchedulingWidgetState extends State<DailySchedulingWidget> {
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
            labelText: context.l10n.daysIntervalLabel,
            border: const OutlineInputBorder(),
            helperText: context.l10n.daysIntervalHelper,
          ),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }
}
