import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import '../logic/task.dart';
import '../logic/civil_day.dart';
import '../logic/relative_time.dart';
import '../logic/task_repository.dart';
import '../logic/error_handler.dart';

import '../widgets/one_off_scheduling_widget.dart';
import '../widgets/daily_scheduling_widget.dart';
import '../widgets/weekly_scheduling_widget.dart';

class CreateTaskScreen extends StatefulWidget {
  static Duration saveTimeout = const Duration(seconds: 10);
  static bool debugDisableAnimations = false;

  final Task? taskToEdit;

  const CreateTaskScreen({super.key, this.taskToEdit});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class SaveIntent extends Intent {
  const SaveIntent();
}

class DiscardIntent extends Intent {
  const DiscardIntent();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _descriptionController = TextEditingController();
  final _intervalController = TextEditingController(text: '1');
  final _estimatedDurationController = TextEditingController();

  // Daily/Weekly multiple times
  final _dailyTimesController = ValueNotifier<List<DailyOccurrenceTime>>([
    const DailyOccurrenceTime(
      startTime: TimeOfDay(hour: 9, minute: 0),
      dueTime: TimeOfDay(hour: 17, minute: 0),
    ),
  ]);

  // Absolute Time fields (for One-off)
  // Default to tomorrow 5pm for due, tomorrow 9am for start (snooze)
  final _dueDateTimeController = ValueNotifier(
    AppClock.now
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
    AppClock.now
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
  DateTime _startDate = AppClock.now; // For Daily/Weekly start date
  Set<int> _selectedWeekdays = {};

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.taskToEdit != null) {
      final task = widget.taskToEdit!;
      _titleController.text = task.title;
      _descriptionController.text = task.description;
      if (task.estimatedDuration != null) {
        _estimatedDurationController.text = task.estimatedDuration!.inMinutes
            .toString();
      }

      if (task.schedule is OneOffSchedule) {
        _scheduleType = RecurrenceType.oneOff;
        final oneOff = task.schedule as OneOffSchedule;

        final dueTime = task.dueRelativeTime.time;
        _dueDateTimeController.value = DateTime(
          oneOff.date.year,
          oneOff.date.month,
          oneOff.date.day,
          dueTime.hour,
          dueTime.minute,
        );

        final dueDateTime = _dueDateTimeController.value;
        final startMidnight = DateTime(
          dueDateTime.year,
          dueDateTime.month,
          dueDateTime.day,
        ).add(Duration(days: task.startRelativeTime.dayOffset));

        final startTime = task.startRelativeTime.time;
        _startDateTimeController.value = DateTime(
          startMidnight.year,
          startMidnight.month,
          startMidnight.day,
          startTime.hour,
          startTime.minute,
        );
      } else if (task.schedule is DailySchedule) {
        _scheduleType = RecurrenceType.daily;
        final daily = task.schedule as DailySchedule;
        _startDate = DateTime(
          daily.startDate.year,
          daily.startDate.month,
          daily.startDate.day,
        );
        _intervalController.text = daily.interval.toString();
        _dailyTimesController.value = List.from(task.dailyTimes);
      } else if (task.schedule is WeeklySchedule) {
        _scheduleType = RecurrenceType.weekly;
        final weekly = task.schedule as WeeklySchedule;
        _startDate = DateTime(
          weekly.startDate.year,
          weekly.startDate.month,
          weekly.startDate.day,
        );
        _intervalController.text = weekly.interval.toString();
        _selectedWeekdays = Set.from(weekly.daysOfWeek);
        _dailyTimesController.value = List.from(task.dailyTimes);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocusNode.dispose();
    _descriptionController.dispose();
    _intervalController.dispose();
    _dailyTimesController.dispose();
    _dueDateTimeController.dispose();
    _startDateTimeController.dispose();
    _estimatedDurationController.dispose();
    super.dispose();
  }

  Future<void> _saveTask() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      try {
        TaskSchedule schedule;
        RelativeTime startRelative;
        RelativeTime dueRelative;

        switch (_scheduleType) {
          case RecurrenceType.oneOff:
            final dueDateTime = _dueDateTimeController.value;
            final startDateTime = _startDateTimeController.value;

            // CivilDay for the schedule is the Due Date's day.
            final civilDate = CivilDay.fromDateTime(dueDateTime);
            schedule = OneOffSchedule(date: civilDate);

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

            // Calculate offset in days using UTC midnights for DST safety.
            final startMidnightUtc = DateTime.utc(
              startDateTime.year,
              startDateTime.month,
              startDateTime.day,
            );
            final dueMidnightUtc = DateTime.utc(
              dueDateTime.year,
              dueDateTime.month,
              dueDateTime.day,
            );
            final diff = startMidnightUtc.difference(dueMidnightUtc).inDays;

            startRelative = RelativeTime(
              dayOffset: diff,
              time: TimeOfDay.fromDateTime(startDateTime),
            );
            break;

          case RecurrenceType.daily:
            final civilDate = CivilDay.fromDateTime(_startDate);
            final interval = int.tryParse(_intervalController.text) ?? 1;
            schedule = DailySchedule(startDate: civilDate, interval: interval);
            final firstSlot = _dailyTimesController.value.first;
            startRelative = RelativeTime(
              dayOffset: 0,
              time: firstSlot.startTime,
            );
            dueRelative = RelativeTime(dayOffset: 0, time: firstSlot.dueTime);
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
            final firstSlot = _dailyTimesController.value.first;
            startRelative = RelativeTime(
              dayOffset: 0,
              time: firstSlot.startTime,
            );
            dueRelative = RelativeTime(dayOffset: 0, time: firstSlot.dueTime);
            break;
        }

        final minutesText = _estimatedDurationController.text.trim();
        final minutes = minutesText.isNotEmpty
            ? int.tryParse(minutesText)
            : null;
        final estimatedDuration = minutes != null
            ? Duration(minutes: minutes)
            : null;

        final newTask = Task(
          id: AppClock.now.millisecondsSinceEpoch.toString(),
          title: _titleController.text,
          description: _descriptionController.text,
          startRelativeTime: startRelative,
          dueRelativeTime: dueRelative,
          schedule: schedule,
          dailyTimes: _scheduleType == RecurrenceType.oneOff
              ? const []
              : _dailyTimesController.value,
          activeOccurrenceIndex: 0,
          estimatedDuration: estimatedDuration,
        );

        final repository = context.read<TaskRepository?>();
        if (repository != null) {
          if (widget.taskToEdit != null) {
            final modification = widget.taskToEdit!.edit(
              newTitle: _titleController.text,
              newDescription: _descriptionController.text,
              newStartRelativeTime: startRelative,
              newDueRelativeTime: dueRelative,
              newSchedule: schedule,
              newDailyTimes: _scheduleType == RecurrenceType.oneOff
                  ? const []
                  : _dailyTimesController.value,
              newEstimatedDuration: estimatedDuration,
              userId: repository.userId,
            );
            await repository
                .updateTask(modification)
                .timeout(
                  CreateTaskScreen.saveTimeout,
                  onTimeout: () => throw Exception(
                    'Save operation timed out. This may be due to a connectivity issue or a failure to sync with the database.',
                  ),
                );
          } else {
            await repository
                .addTask(newTask)
                .timeout(
                  CreateTaskScreen.saveTimeout,
                  onTimeout: () => throw Exception(
                    'Save operation timed out. This may be due to a connectivity issue or a failure to sync with the database.',
                  ),
                );
          }
        }

        if (mounted) {
          Navigator.pop(context); // Don't return the task
        }
      } catch (e, stackTrace) {
        if (mounted) {
          final errorHandler = context.read<ErrorHandler>();
          final report = errorHandler.report(e, stackTrace: stackTrace);
          errorHandler.showErrorDialog(context, report);
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.enter): const SaveIntent(),
        const SingleActivator(LogicalKeyboardKey.escape): const DiscardIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          SaveIntent: CallbackAction<SaveIntent>(
            onInvoke: (intent) {
              if (_titleFocusNode.hasFocus) {
                _saveTask();
              }
              return null;
            },
          ),
          DiscardIntent: CallbackAction<DiscardIntent>(
            onInvoke: (intent) => Navigator.pop(context),
          ),
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.taskToEdit != null ? 'Edit Task' : 'New Task'),
          ),
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
                                  focusNode: _titleFocusNode,
                                  autofocus: true,
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
                                const SizedBox(height: 16),
                                TextFormField(
                                  key: const Key('estimated_effort_field'),
                                  controller: _estimatedDurationController,
                                  decoration: const InputDecoration(
                                    labelText: 'Estimated Effort (Minutes)',
                                    border: OutlineInputBorder(),
                                    helperText:
                                        'Optional. Enter the estimated time in minutes.',
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  validator: (value) {
                                    if (value != null && value.isNotEmpty) {
                                      final val = int.tryParse(value);
                                      if (val == null || val <= 0) {
                                        return 'Please enter a positive number of minutes';
                                      }
                                    }
                                    return null;
                                  },
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
                                    dailyTimesController: _dailyTimesController,
                                    intervalController: _intervalController,
                                  )
                                else if (_scheduleType == RecurrenceType.weekly)
                                  WeeklySchedulingWidget(
                                    startDate: _startDate,
                                    onStartDateChanged: (date) {
                                      setState(() => _startDate = date);
                                    },
                                    dailyTimesController: _dailyTimesController,
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
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Discard'),
                    ),
                    const SizedBox(width: 16),
                    FilledButton(
                      key: const Key('save_task_button'),
                      onPressed: _isSaving ? null : _saveTask,
                      child: _isSaving
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                value: CreateTaskScreen.debugDisableAnimations
                                    ? 0.8
                                    : null,
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
