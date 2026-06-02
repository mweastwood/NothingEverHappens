import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../logic/task.dart';
import 'daily_time_list_widget.dart';
import '../logic/l10n_extension.dart';

class MonthlySchedulingWidget extends StatefulWidget {
  final DateTime startDate;
  final ValueChanged<DateTime> onStartDateChanged;
  final ValueNotifier<List<DailyOccurrenceTime>> dailyTimesController;
  final TextEditingController intervalController;
  final ValueNotifier<String> ruleTypeController;
  final TextEditingController dayOfMonthController;
  final ValueNotifier<int> nthOccurrenceController;
  final ValueNotifier<int> dayOfWeekController;

  const MonthlySchedulingWidget({
    super.key,
    required this.startDate,
    required this.onStartDateChanged,
    required this.dailyTimesController,
    required this.intervalController,
    required this.ruleTypeController,
    required this.dayOfMonthController,
    required this.nthOccurrenceController,
    required this.dayOfWeekController,
  });

  @override
  State<MonthlySchedulingWidget> createState() =>
      _MonthlySchedulingWidgetState();
}

class _MonthlySchedulingWidgetState extends State<MonthlySchedulingWidget> {
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
            labelText: context.l10n.monthsIntervalLabel,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder<String>(
          valueListenable: widget.ruleTypeController,
          builder: (context, ruleType, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: ruleType,
                  decoration: InputDecoration(
                    labelText: context.l10n.monthlyRecurrenceTypeLabel,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'dayOfMonth',
                      child: Text(context.l10n.dayOfMonthLabel),
                    ),
                    DropdownMenuItem(
                      value: 'nthDayOfWeek',
                      child: Text(context.l10n.nthDayOfWeekLabel),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      widget.ruleTypeController.value = value;
                    }
                  },
                ),
                const SizedBox(height: 16),
                if (ruleType == 'dayOfMonth')
                  TextFormField(
                    controller: widget.dayOfMonthController,
                    decoration: InputDecoration(
                      labelText: context.l10n.dayOfMonthFieldLabel,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return context.l10n.dayOfMonthValidationError;
                      }
                      final val = int.tryParse(value.trim());
                      if (val == null || val == 0 || val.abs() > 28) {
                        return context.l10n.dayOfMonthValidationError;
                      }
                      return null;
                    },
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: ValueListenableBuilder<int>(
                          valueListenable: widget.nthOccurrenceController,
                          builder: (context, occurrence, _) {
                            return DropdownButtonFormField<int>(
                              value: occurrence,
                              decoration: InputDecoration(
                                labelText: context.l10n.nthOccurrenceLabel,
                                border: const OutlineInputBorder(),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 1,
                                  child: Text(context.l10n.firstOccurrence),
                                ),
                                DropdownMenuItem(
                                  value: 2,
                                  child: Text(context.l10n.secondOccurrence),
                                ),
                                DropdownMenuItem(
                                  value: 3,
                                  child: Text(context.l10n.thirdOccurrence),
                                ),
                                DropdownMenuItem(
                                  value: 4,
                                  child: Text(context.l10n.fourthOccurrence),
                                ),
                                DropdownMenuItem(
                                  value: -1,
                                  child: Text(context.l10n.lastOccurrence),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  widget.nthOccurrenceController.value = value;
                                }
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ValueListenableBuilder<int>(
                          valueListenable: widget.dayOfWeekController,
                          builder: (context, dayOfWeek, _) {
                            return DropdownButtonFormField<int>(
                              value: dayOfWeek,
                              decoration: InputDecoration(
                                labelText: context.l10n.dayOfWeekLabel,
                                border: const OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 1,
                                  child: Text('Monday'),
                                ),
                                DropdownMenuItem(
                                  value: 2,
                                  child: Text('Tuesday'),
                                ),
                                DropdownMenuItem(
                                  value: 3,
                                  child: Text('Wednesday'),
                                ),
                                DropdownMenuItem(
                                  value: 4,
                                  child: Text('Thursday'),
                                ),
                                DropdownMenuItem(
                                  value: 5,
                                  child: Text('Friday'),
                                ),
                                DropdownMenuItem(
                                  value: 6,
                                  child: Text('Saturday'),
                                ),
                                DropdownMenuItem(
                                  value: 7,
                                  child: Text('Sunday'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  widget.dayOfWeekController.value = value;
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
