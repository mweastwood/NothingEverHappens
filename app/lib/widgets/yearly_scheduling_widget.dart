import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../logic/task.dart';
import 'daily_time_list_widget.dart';
import '../logic/l10n_extension.dart';

class YearlySchedulingWidget extends StatefulWidget {
  final DateTime startDate;
  final ValueChanged<DateTime> onStartDateChanged;
  final ValueNotifier<List<DailyOccurrenceTime>> dailyTimesController;
  final TextEditingController intervalController;
  final ValueNotifier<int> monthController;
  final TextEditingController dayController;

  const YearlySchedulingWidget({
    super.key,
    required this.startDate,
    required this.onStartDateChanged,
    required this.dailyTimesController,
    required this.intervalController,
    required this.monthController,
    required this.dayController,
  });

  @override
  State<YearlySchedulingWidget> createState() => _YearlySchedulingWidgetState();
}

class _YearlySchedulingWidgetState extends State<YearlySchedulingWidget> {
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

  int _maxDaysInMonth(int month) {
    switch (month) {
      case 2:
        return 29; // Allow 29 for leap years
      case 4:
      case 6:
      case 9:
      case 11:
        return 30;
      default:
        return 31;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DailyTimeListWidget(controller: widget.dailyTimesController),
        const SizedBox(height: 24),
        Material(
          color: Colors.transparent,
          child: ListTile(
            title: Text(context.l10n.startDateLabel),
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
          decoration: InputDecoration(
            labelText: context.l10n.yearsIntervalLabel,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: ValueListenableBuilder<int>(
                valueListenable: widget.monthController,
                builder: (context, month, _) {
                  return DropdownButtonFormField<int>(
                    initialValue: month,
                    decoration: InputDecoration(
                      labelText: context.l10n.monthLabel,
                      border: const OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('January')),
                      DropdownMenuItem(value: 2, child: Text('February')),
                      DropdownMenuItem(value: 3, child: Text('March')),
                      DropdownMenuItem(value: 4, child: Text('April')),
                      DropdownMenuItem(value: 5, child: Text('May')),
                      DropdownMenuItem(value: 6, child: Text('June')),
                      DropdownMenuItem(value: 7, child: Text('July')),
                      DropdownMenuItem(value: 8, child: Text('August')),
                      DropdownMenuItem(value: 9, child: Text('September')),
                      DropdownMenuItem(value: 10, child: Text('October')),
                      DropdownMenuItem(value: 11, child: Text('November')),
                      DropdownMenuItem(value: 12, child: Text('December')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        widget.monthController.value = value;
                      }
                    },
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 1,
              child: TextFormField(
                controller: widget.dayController,
                decoration: InputDecoration(
                  labelText: context.l10n.dayLabel,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Required';
                  }
                  final day = int.tryParse(value.trim());
                  final maxDays = _maxDaysInMonth(widget.monthController.value);
                  if (day == null || day < 1 || day > maxDays) {
                    return '1-$maxDays';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
