import 'package:flutter/material.dart';
import '../logic/task.dart';
import '../logic/civil_day.dart';
import '../widgets/relative_time_widget.dart';

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

  // Time fields
  // Time fields
  final _startController = ValueNotifier(const Duration(hours: 9, minutes: 0));
  final _dueController = ValueNotifier(const Duration(hours: 17, minutes: 0));

  // Schedule fields
  RecurrenceType _scheduleType = RecurrenceType.oneOff;
  DateTime _selectedDate = DateTime.now(); // For One-off or Start Date
  int _interval = 1;
  final Set<int> _selectedWeekdays = {};

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _intervalController.dispose();
    _startController.dispose();
    _dueController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveTask() {
    if (_formKey.currentState!.validate()) {
      final civilDate = CivilDay.fromDateTime(_selectedDate);
      TaskSchedule schedule;

      switch (_scheduleType) {
        case RecurrenceType.oneOff:
          schedule = OneOffSchedule(date: civilDate);
          break;
        case RecurrenceType.daily:
          schedule = DailySchedule(startDate: civilDate, interval: _interval);
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
          schedule = WeeklySchedule(
            startDate: civilDate,
            interval: _interval,
            daysOfWeek: Set.from(_selectedWeekdays),
          );
          break;
      }

      final newTask = Task(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text,
        description: _descriptionController.text,
        startFromMidnight: _startController.value,
        dueFromMidnight: _dueController.value,
        schedule: schedule,
      );
      Navigator.pop(context, newTask);
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
                              width: 320,
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
                            const Text(
                              'Times',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Start Time'),
                                RelativeTimeWidget(
                                  controller: _startController,
                                  constraint:
                                      RelativeTimeConstraint.dayOfOrAfter,
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Due Time'),
                                RelativeTimeWidget(
                                  controller: _dueController,
                                  constraint:
                                      RelativeTimeConstraint.dayOfOrAfter,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ListTile(
                              title: Text(
                                _scheduleType == RecurrenceType.oneOff
                                    ? 'Date'
                                    : 'Start Date',
                              ),
                              subtitle: Text(
                                '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                              ),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: () => _selectDate(context),
                              shape: RoundedRectangleBorder(
                                side: BorderSide(
                                  color: Theme.of(context).dividerColor,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            if (_scheduleType != RecurrenceType.oneOff) ...[
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _intervalController,
                                decoration: InputDecoration(
                                  labelText:
                                      _scheduleType == RecurrenceType.daily
                                      ? 'Days Interval'
                                      : 'Weeks Interval',
                                  border: const OutlineInputBorder(),
                                  helperText:
                                      _scheduleType == RecurrenceType.daily
                                      ? 'E.g., 1 for every day, 2 for every other day'
                                      : 'E.g., 1 for every week',
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (val) {
                                  setState(
                                    () => _interval = int.tryParse(val) ?? 1,
                                  );
                                },
                              ),
                            ],
                            if (_scheduleType == RecurrenceType.weekly) ...[
                              const SizedBox(height: 16),
                              const Text('Repeats on'),
                              Wrap(
                                spacing: 8.0,
                                children: List.generate(7, (index) {
                                  final dayIndex = index + 1; // 1 = Monday
                                  final labels = [
                                    'M',
                                    'T',
                                    'W',
                                    'T',
                                    'F',
                                    'S',
                                    'S',
                                  ];
                                  return FilterChip(
                                    label: Text(labels[index]),
                                    selected: _selectedWeekdays.contains(
                                      dayIndex,
                                    ),
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          _selectedWeekdays.add(dayIndex);
                                        } else {
                                          _selectedWeekdays.remove(dayIndex);
                                        }
                                      });
                                    },
                                  );
                                }),
                              ),
                            ],
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
