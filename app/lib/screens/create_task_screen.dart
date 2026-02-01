import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/task.dart';
import '../logic/civil_day.dart';
import '../logic/relative_time.dart';
import '../logic/task_repository.dart';

import '../widgets/one_off_scheduling_widget.dart';
import '../widgets/daily_scheduling_widget.dart';
import '../widgets/weekly_scheduling_widget.dart';

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _intervalController = TextEditingController(text: '1');

  // Relative Time fields (for Daily/Weekly)
  final _startRelativeController = ValueNotifier(
    const RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 9, minute: 0)),
  );
  final _dueRelativeController = ValueNotifier(
    const RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 17, minute: 0)),
  );

  // Absolute Time fields (for One-off)
  // Default to tomorrow 5pm for due, tomorrow 9am for start (snooze)
  final _dueDateTimeController = ValueNotifier(
    DateTime.now()
        .add(const Duration(days: 1))
        .copyWith(
          hour: 17,
          minute: 0,
          second: 0,
          millisecond: 0,
          microsecond: 0,
        ),
  );
  final _startDateTimeController = ValueNotifier(
    DateTime.now()
        .add(const Duration(days: 1))
        .copyWith(
          hour: 9,
          minute: 0,
          second: 0,
          millisecond: 0,
          microsecond: 0,
        ),
  );

  // Schedule fields
  RecurrenceType _scheduleType = RecurrenceType.oneOff;
  DateTime _startDate = DateTime.now(); // For Daily/Weekly start date
  Set<int> _selectedWeekdays = {};

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _intervalController.dispose();
    _startRelativeController.dispose();
    _dueRelativeController.dispose();
    _dueDateTimeController.dispose();
    _startDateTimeController.dispose();
    super.dispose();
  }

  void _saveTask() {
    if (_formKey.currentState!.validate()) {
      TaskSchedule schedule;
      RelativeTime startRelative;
      RelativeTime dueRelative;

      switch (_scheduleType) {
        case RecurrenceType.oneOff:
          // For One-off, we convert absolute types to "relative" to the task date (which is the due date)
          // But actually OneOffSchedule takes a date.
          // Wait, Task model uses relative times.
          // If OneOff, startRelativeTime and dueRelativeTime are usually simple.
          // Due Time for OneOff: usually Day 0, Time X.
          // But we have Absolute widget.

          final dueDateTime = _dueDateTimeController.value;
          final startDateTime = _startDateTimeController.value;

          // CivilDay for the schedule is the Due Date's day.
          final civilDate = CivilDay.fromDateTime(dueDateTime);
          schedule = OneOffSchedule(date: civilDate);

          // Relative Time: calculated relative to the due date (civilDate)
          // Actually, for One-off, the "date" in schedule IS the reference date.

          // Due time is simply the time component of dueDateTime, offset 0?
          // If dueDateTime is on civilDate, then offset is 0.
          dueRelative = RelativeTime(
            dayOffset: 0,
            time: TimeOfDay.fromDateTime(dueDateTime),
          );

          // Start time (Snooze):
          // Might be on a different day.
          // Calculate difference in days between startDateTime and dueDateTime(civilDate).
          // But strict CivilDay difference.

          // dayOffset = start - due.
          // e.g. Snooze until tomorrow, Due today? Unlikely.
          // Usually Snooze until tomorrow, Due tomorrow (or next week).

          // Wait, user provided absolute Snooze.
          // If Snooze is BEFORE Due, then Offset <= 0.

          // Calculate offset in days.
          // We can't easily do it without logic.
          // CivilDay doesn't have difference method visible here?
          // Let's assume standard calculation:
          final startMidnight = DateTime(
            startDateTime.year,
            startDateTime.month,
            startDateTime.day,
          );
          final dueMidnight = DateTime(
            dueDateTime.year,
            dueDateTime.month,
            dueDateTime.day,
          );
          final diff = startMidnight.difference(dueMidnight).inDays;

          startRelative = RelativeTime(
            dayOffset: diff,
            time: TimeOfDay.fromDateTime(startDateTime),
          );
          break;

        case RecurrenceType.daily:
          final civilDate = CivilDay.fromDateTime(_startDate);
          final interval = int.tryParse(_intervalController.text) ?? 1;
          schedule = DailySchedule(startDate: civilDate, interval: interval);
          startRelative = _startRelativeController.value;
          dueRelative = _dueRelativeController.value;
          break;

        case RecurrenceType.weekly:
          if (_selectedWeekdays.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please select at least one day of the week'),
              ),
            );
            return;
          }
          final civilDate = CivilDay.fromDateTime(_startDate);
          final interval = int.tryParse(_intervalController.text) ?? 1;
          schedule = WeeklySchedule(
            startDate: civilDate,
            interval: interval,
            daysOfWeek: Set.from(_selectedWeekdays),
          );
          startRelative = _startRelativeController.value;
          dueRelative = _dueRelativeController.value;
          break;
      }

      final newTask = Task(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text,
        description: _descriptionController.text,
        startRelativeTime: startRelative,
        dueRelativeTime: dueRelative,
        schedule: schedule,
      );

      final repository = context.read<TaskRepository?>();
      if (repository != null) {
        // Use a detached Future to avoid blocking the UI,
        // but since we pop immediately, we should probably await if we want to show error.
        // For now, fire and forget or simple await is fine.
        repository.addTask(newTask);
      }

      Navigator.pop(context); // Don't return the task
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Task')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _titleController,
                              decoration: const InputDecoration(
                                labelText: 'Title',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a title';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Schedule',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<RecurrenceType>(
                                segments: const [
                                  ButtonSegment<RecurrenceType>(
                                    value: RecurrenceType.oneOff,
                                    label: Text('One-off'),
                                  ),
                                  ButtonSegment<RecurrenceType>(
                                    value: RecurrenceType.daily,
                                    label: Text('Daily'),
                                  ),
                                  ButtonSegment<RecurrenceType>(
                                    value: RecurrenceType.weekly,
                                    label: Text('Weekly'),
                                  ),
                                ],
                                selected: <RecurrenceType>{_scheduleType},
                                onSelectionChanged:
                                    (Set<RecurrenceType> newSelection) {
                                      setState(() {
                                        _scheduleType = newSelection.first;
                                      });
                                    },
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (_scheduleType == RecurrenceType.oneOff)
                              OneOffSchedulingWidget(
                                dueDateTime: _dueDateTimeController,
                                startDateTime: _startDateTimeController,
                              )
                            else if (_scheduleType == RecurrenceType.daily)
                              DailySchedulingWidget(
                                startDate: _startDate,
                                onStartDateChanged: (date) {
                                  setState(() => _startDate = date);
                                },
                                startTimeController: _startRelativeController,
                                dueTimeController: _dueRelativeController,
                                intervalController: _intervalController,
                              )
                            else if (_scheduleType == RecurrenceType.weekly)
                              WeeklySchedulingWidget(
                                startDate: _startDate,
                                onStartDateChanged: (date) {
                                  setState(() => _startDate = date);
                                },
                                startTimeController: _startRelativeController,
                                dueTimeController: _dueRelativeController,
                                intervalController: _intervalController,
                                selectedWeekdays: _selectedWeekdays,
                                onWeekdaysChanged: (days) {
                                  setState(() => _selectedWeekdays = days);
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Discard'),
                ),
                const SizedBox(width: 16),
                FilledButton(onPressed: _saveTask, child: const Text('Save')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
