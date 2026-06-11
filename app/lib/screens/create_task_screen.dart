import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import '../logic/task.dart';
import '../logic/civil_day.dart';
import '../logic/relative_time.dart';
import '../logic/task_repository.dart';
import '../logic/error_handler.dart';
import '../logic/l10n_extension.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../logic/family_repository.dart';

import '../widgets/one_off_scheduling_widget.dart';
import '../widgets/daily_scheduling_widget.dart';
import '../widgets/weekly_scheduling_widget.dart';
import '../widgets/monthly_scheduling_widget.dart';
import '../widgets/yearly_scheduling_widget.dart';
import '../widgets/recurrence_type_selector.dart';
import '../widgets/upcoming_occurrences_preview.dart';

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

  // Monthly / Yearly controllers
  final _monthlyRuleTypeController = ValueNotifier<String>('dayOfMonth');
  final _monthlyDayOfMonthController = TextEditingController();
  final _monthlyNthOccurrenceController = ValueNotifier<int>(1);
  final _monthlyDayOfWeekController = ValueNotifier<int>(1);
  final _yearlyMonthController = ValueNotifier<int>(1);
  final _yearlyDayController = TextEditingController();

  // Daily/Weekly multiple times
  final _dailyTimesController = ValueNotifier<List<DailyOccurrenceTime>>([
    const DailyOccurrenceTime(
      startTime: TimeOfDay(hour: 9, minute: 0),
      dueTime: TimeOfDay(hour: 17, minute: 0),
    ),
  ]);

  // Absolute Time fields (for One-off)
  // Default to tomorrow 5pm for due, today (now) for start (no snooze)
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
    AppClock.now.copyWith(second: 0, millisecond: 0, microsecond: 0),
  );

  // Schedule fields
  RecurrenceType _scheduleType = RecurrenceType.oneOff;
  DateTime _startDate = AppClock.now; // For Daily/Weekly start date
  Set<int> _selectedWeekdays = {};
  MissedPolicy _missedPolicy = MissedPolicy.rollover;
  final _oneOffNotificationController = ValueNotifier<TimeOfDay?>(null);

  bool _isSaving = false;

  // New Agile and Scoping variables
  bool _isFamily = false;
  TaskPriority _priority = TaskPriority.medium;
  String? _cycleId;
  Map<String, bool> _preferredBy = const {};
  String? _assignedUserId;

  @override
  void initState() {
    super.initState();
    if (widget.taskToEdit != null) {
      final task = widget.taskToEdit!;
      _titleController.text = task.title;
      _descriptionController.text = task.description;
      _missedPolicy = task.missedPolicy;
      _isFamily = task.isFamily;
      _priority = task.priority;
      _cycleId = task.cycleId;
      _preferredBy = Map<String, bool>.from(task.preferredBy);
      _assignedUserId = task.assignedUserId;
      if (task.estimatedDuration != null) {
        _estimatedDurationController.text = task.estimatedDuration!.inMinutes
            .toString();
      }

      if (task.schedule is OneOffSchedule) {
        _scheduleType = RecurrenceType.oneOff;
        final oneOff = task.schedule as OneOffSchedule;

        if (task.dailyTimes.isNotEmpty) {
          _oneOffNotificationController.value =
              task.dailyTimes.first.notificationTime;
        }

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
      } else if (task.schedule is MonthlySchedule) {
        _scheduleType = RecurrenceType.monthly;
        final monthly = task.schedule as MonthlySchedule;
        _startDate = DateTime(
          monthly.startDate.year,
          monthly.startDate.month,
          monthly.startDate.day,
        );
        _intervalController.text = monthly.interval.toString();
        _dailyTimesController.value = List.from(task.dailyTimes);
        if (monthly.dayOfMonth != null) {
          _monthlyRuleTypeController.value = 'dayOfMonth';
          _monthlyDayOfMonthController.text = monthly.dayOfMonth.toString();
        } else {
          _monthlyRuleTypeController.value = 'nthDayOfWeek';
          _monthlyNthOccurrenceController.value = monthly.occurrence!;
          _monthlyDayOfWeekController.value = monthly.dayOfWeek!;
        }
      } else if (task.schedule is YearlySchedule) {
        _scheduleType = RecurrenceType.yearly;
        final yearly = task.schedule as YearlySchedule;
        _startDate = DateTime(
          yearly.startDate.year,
          yearly.startDate.month,
          yearly.startDate.day,
        );
        _intervalController.text = yearly.interval.toString();
        _dailyTimesController.value = List.from(task.dailyTimes);
        _yearlyMonthController.value = yearly.month;
        _yearlyDayController.text = yearly.day.toString();
      }
    }

    _intervalController.addListener(_updatePreview);
    _monthlyDayOfMonthController.addListener(_updatePreview);
    _yearlyDayController.addListener(_updatePreview);
    _dueDateTimeController.addListener(_updatePreview);
    _startDateTimeController.addListener(_updatePreview);
    _dailyTimesController.addListener(_updatePreview);
    _oneOffNotificationController.addListener(_updatePreview);
    _monthlyRuleTypeController.addListener(_updatePreview);
    _monthlyNthOccurrenceController.addListener(_updatePreview);
    _monthlyDayOfWeekController.addListener(_updatePreview);
    _yearlyMonthController.addListener(_updatePreview);
  }

  void _updatePreview() {
    if (mounted) {
      setState(() {});
    }
  }

  TaskSchedule? _buildSchedule() {
    try {
      final civilDate = CivilDay.fromDateTime(_startDate);
      final interval = int.tryParse(_intervalController.text) ?? 1;
      if (interval <= 0) return null;

      switch (_scheduleType) {
        case RecurrenceType.oneOff:
          final dueDateTime = _dueDateTimeController.value;
          final civilDue = CivilDay.fromDateTime(dueDateTime);
          return OneOffSchedule(date: civilDue);

        case RecurrenceType.daily:
          return DailySchedule(startDate: civilDate, interval: interval);

        case RecurrenceType.weekly:
          if (_selectedWeekdays.isEmpty) return null;
          return WeeklySchedule(
            startDate: civilDate,
            interval: interval,
            daysOfWeek: Set.from(_selectedWeekdays),
          );

        case RecurrenceType.monthly:
          if (_monthlyRuleTypeController.value == 'dayOfMonth') {
            final dom = int.tryParse(_monthlyDayOfMonthController.text) ?? 1;
            if (dom.abs() > 28 || dom == 0) return null;
            return MonthlySchedule(
              startDate: civilDate,
              interval: interval,
              dayOfMonth: dom,
            );
          } else {
            return MonthlySchedule(
              startDate: civilDate,
              interval: interval,
              dayOfWeek: _monthlyDayOfWeekController.value,
              occurrence: _monthlyNthOccurrenceController.value,
            );
          }

        case RecurrenceType.yearly:
          final yMonth = _yearlyMonthController.value;
          final yDay = int.tryParse(_yearlyDayController.text) ?? 1;
          int maxDays = 31;
          if (yMonth == 2) {
            maxDays = 29;
          } else if ([4, 6, 9, 11].contains(yMonth)) {
            maxDays = 30;
          }
          if (yDay < 1 || yDay > maxDays) return null;

          return YearlySchedule(
            startDate: civilDate,
            interval: interval,
            month: yMonth,
            day: yDay,
          );
      }
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _intervalController.removeListener(_updatePreview);
    _monthlyDayOfMonthController.removeListener(_updatePreview);
    _yearlyDayController.removeListener(_updatePreview);
    _dueDateTimeController.removeListener(_updatePreview);
    _startDateTimeController.removeListener(_updatePreview);
    _dailyTimesController.removeListener(_updatePreview);
    _oneOffNotificationController.removeListener(_updatePreview);
    _monthlyRuleTypeController.removeListener(_updatePreview);
    _monthlyNthOccurrenceController.removeListener(_updatePreview);
    _monthlyDayOfWeekController.removeListener(_updatePreview);
    _yearlyMonthController.removeListener(_updatePreview);

    _titleController.dispose();
    _titleFocusNode.dispose();
    _descriptionController.dispose();
    _intervalController.dispose();
    _dailyTimesController.dispose();
    _dueDateTimeController.dispose();
    _startDateTimeController.dispose();
    _estimatedDurationController.dispose();
    _monthlyRuleTypeController.dispose();
    _monthlyDayOfMonthController.dispose();
    _monthlyNthOccurrenceController.dispose();
    _monthlyDayOfWeekController.dispose();
    _yearlyMonthController.dispose();
    _yearlyDayController.dispose();
    _oneOffNotificationController.dispose();
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
                SnackBar(content: Text(context.l10n.selectAtLeastOneDayError)),
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

          case RecurrenceType.monthly:
            final civilDate = CivilDay.fromDateTime(_startDate);
            final interval = int.tryParse(_intervalController.text) ?? 1;
            if (_monthlyRuleTypeController.value == 'dayOfMonth') {
              final dom = int.tryParse(_monthlyDayOfMonthController.text) ?? 1;
              schedule = MonthlySchedule(
                startDate: civilDate,
                interval: interval,
                dayOfMonth: dom,
              );
            } else {
              schedule = MonthlySchedule(
                startDate: civilDate,
                interval: interval,
                dayOfWeek: _monthlyDayOfWeekController.value,
                occurrence: _monthlyNthOccurrenceController.value,
              );
            }
            final firstSlot = _dailyTimesController.value.first;
            startRelative = RelativeTime(
              dayOffset: 0,
              time: firstSlot.startTime,
            );
            dueRelative = RelativeTime(dayOffset: 0, time: firstSlot.dueTime);
            break;

          case RecurrenceType.yearly:
            final civilDate = CivilDay.fromDateTime(_startDate);
            final interval = int.tryParse(_intervalController.text) ?? 1;
            final yMonth = _yearlyMonthController.value;
            final yDay = int.tryParse(_yearlyDayController.text) ?? 1;
            schedule = YearlySchedule(
              startDate: civilDate,
              interval: interval,
              month: yMonth,
              day: yDay,
            );
            final firstSlot = _dailyTimesController.value.first;
            startRelative = RelativeTime(
              dayOffset: 0,
              time: firstSlot.startTime,
            );
            dueRelative = RelativeTime(dayOffset: 0, time: firstSlot.dueTime);
            break;
        }

        final dueDateTime = _dueDateTimeController.value;
        final startDateTime = _startDateTimeController.value;
        final oneOffNotification = _oneOffNotificationController.value;
        final oneOffDailyTimes = oneOffNotification != null
            ? [
                DailyOccurrenceTime(
                  startTime: TimeOfDay.fromDateTime(startDateTime),
                  dueTime: TimeOfDay.fromDateTime(dueDateTime),
                  notificationTime: oneOffNotification,
                ),
              ]
            : const <DailyOccurrenceTime>[];

        final savedDailyTimes = _scheduleType == RecurrenceType.oneOff
            ? oneOffDailyTimes
            : _dailyTimesController.value;

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
          dailyTimes: savedDailyTimes,
          activeOccurrenceIndex: 0,
          estimatedDuration: estimatedDuration,
          missedPolicy: _scheduleType == RecurrenceType.oneOff
              ? MissedPolicy.rollover
              : _missedPolicy,
          isMaster:
              _scheduleType != RecurrenceType.oneOff &&
              _missedPolicy == MissedPolicy.stack,
          lastSpawnedDate:
              _scheduleType != RecurrenceType.oneOff &&
                  _missedPolicy == MissedPolicy.stack
              ? CivilDay.fromDateTime(AppClock.now).addDays(-1)
              : null,
          isFamily: _isFamily,
          priority: _priority,
          cycleId: _cycleId,
          preferredBy: _preferredBy,
          assignedUserId: _assignedUserId,
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
              newDailyTimes: savedDailyTimes,
              newEstimatedDuration: estimatedDuration,
              userId: repository.userId,
              newMissedPolicy: _scheduleType == RecurrenceType.oneOff
                  ? MissedPolicy.rollover
                  : _missedPolicy,
              newIsMaster:
                  _scheduleType != RecurrenceType.oneOff &&
                  _missedPolicy == MissedPolicy.stack,
              newLastSpawnedDate:
                  widget.taskToEdit!.lastSpawnedDate ??
                  (_scheduleType != RecurrenceType.oneOff &&
                          _missedPolicy == MissedPolicy.stack
                      ? CivilDay.fromDateTime(AppClock.now).addDays(-1)
                      : null),
              newIsFamily: _isFamily,
              newPriority: _priority,
              newCycleId: _cycleId,
              newPreferredBy: _preferredBy,
              newAssignedUserId: _assignedUserId,
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

  Widget _buildCustomChip({
    required Key key,
    required String label,
    required bool isSelected,
    required ValueChanged<bool>? onSelected,
  }) {
    final theme = Theme.of(context);
    return ChoiceChip(
      key: key,
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      selectedColor: theme.colorScheme.primaryContainer,
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      labelStyle: TextStyle(
        fontSize: 13,
        color: isSelected
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.outlineVariant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final familyRepo = Provider.of<FamilyRepository?>(context);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: familyRepo?.getProfile() ?? const Stream.empty(),
      builder: (context, snapshot) {
        final profileData = snapshot.data?.data() ?? {};
        final familyId = profileData['familyId'] as String? ?? '';
        final familyRole = profileData['familyRole'] as String? ?? '';
        final inFamily = familyId.isNotEmpty;
        final isParent = familyRole == 'parent';

        final isEditingFamilyTask = widget.taskToEdit?.isFamily ?? false;
        final hasEditPermission = !isEditingFamilyTask || isParent;
        final readOnly = !hasEditPermission;

        return Shortcuts(
          shortcuts: <ShortcutActivator, Intent>{
            const SingleActivator(LogicalKeyboardKey.enter): const SaveIntent(),
            const SingleActivator(LogicalKeyboardKey.escape):
                const DiscardIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              SaveIntent: CallbackAction<SaveIntent>(
                onInvoke: (intent) {
                  if (_titleFocusNode.hasFocus && !readOnly) {
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
                title: Text(
                  readOnly
                      ? context.l10n.viewTaskTitle
                      : (widget.taskToEdit != null
                            ? context.l10n.editTaskTitle
                            : context.l10n.newTaskTitle),
                ),
              ),
              body: Column(
                children: [
                  if (readOnly)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Text(
                        context.l10n.onlyParentsCanEditFamilyTasks,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
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
                                      autofocus: !readOnly,
                                      enabled: !readOnly,
                                      decoration: InputDecoration(
                                        labelText: context.l10n.titleFieldLabel,
                                        border: const OutlineInputBorder(),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return context
                                              .l10n
                                              .titleRequiredError;
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _descriptionController,
                                      enabled: !readOnly,
                                      decoration: InputDecoration(
                                        labelText:
                                            context.l10n.descriptionFieldLabel,
                                        border: const OutlineInputBorder(),
                                      ),
                                      maxLines: 3,
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      key: const Key('estimated_effort_field'),
                                      controller: _estimatedDurationController,
                                      enabled: !readOnly,
                                      decoration: InputDecoration(
                                        labelText: context
                                            .l10n
                                            .estimatedEffortFieldLabel,
                                        border: const OutlineInputBorder(),
                                        helperText:
                                            context.l10n.estimatedEffortHelper,
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      validator: (value) {
                                        if (value != null && value.isNotEmpty) {
                                          final val = int.tryParse(value);
                                          if (val == null || val <= 0) {
                                            return context
                                                .l10n
                                                .estimatedEffortValidationError;
                                          }
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      context.l10n.taskPriorityLabel,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      key: const Key('task_priority_dropdown'),
                                      spacing: 8.0,
                                      runSpacing: 8.0,
                                      children: TaskPriority.values.map((
                                        priority,
                                      ) {
                                        final String label;
                                        switch (priority) {
                                          case TaskPriority.low:
                                            label = context.l10n.priorityLow;
                                            break;
                                          case TaskPriority.medium:
                                            label = context.l10n.priorityMedium;
                                            break;
                                          case TaskPriority.high:
                                            label = context.l10n.priorityHigh;
                                            break;
                                        }

                                        return _buildCustomChip(
                                          key: Key(
                                            'priority_chip_${priority.name}',
                                          ),
                                          label: label,
                                          isSelected: _priority == priority,
                                          onSelected: readOnly
                                              ? null
                                              : (selected) {
                                                  if (selected) {
                                                    setState(() {
                                                      _priority = priority;
                                                    });
                                                  }
                                                },
                                        );
                                      }).toList(),
                                    ),
                                    if (inFamily) ...[
                                      const SizedBox(height: 16),
                                      SwitchListTile(
                                        key: const Key('is_family_toggle'),
                                        title: Text(
                                          context.l10n.familyTaskLabel,
                                        ),
                                        subtitle: Text(
                                          context.l10n.familyTaskHelper,
                                        ),
                                        value: _isFamily,
                                        onChanged: readOnly
                                            ? null
                                            : (value) {
                                                setState(
                                                  () => _isFamily = value,
                                                );
                                              },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            AbsorbPointer(
                              absorbing: readOnly,
                              child: Opacity(
                                opacity: readOnly ? 0.6 : 1.0,
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          context.l10n.scheduleHeader,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        RecurrenceTypeSelector(
                                          selectedValue: _scheduleType,
                                          onSelected: (newType) {
                                            setState(() {
                                              _scheduleType = newType;
                                            });
                                          },
                                        ),
                                        const SizedBox(height: 24),
                                        if (_scheduleType ==
                                            RecurrenceType.oneOff)
                                          OneOffSchedulingWidget(
                                            dueDateTime: _dueDateTimeController,
                                            startDateTime:
                                                _startDateTimeController,
                                            notificationTimeController:
                                                _oneOffNotificationController,
                                          )
                                        else if (_scheduleType ==
                                            RecurrenceType.daily)
                                          DailySchedulingWidget(
                                            startDate: _startDate,
                                            onStartDateChanged: (date) {
                                              setState(() => _startDate = date);
                                            },
                                            dailyTimesController:
                                                _dailyTimesController,
                                            intervalController:
                                                _intervalController,
                                          )
                                        else if (_scheduleType ==
                                            RecurrenceType.weekly)
                                          WeeklySchedulingWidget(
                                            startDate: _startDate,
                                            onStartDateChanged: (date) {
                                              setState(() => _startDate = date);
                                            },
                                            dailyTimesController:
                                                _dailyTimesController,
                                            intervalController:
                                                _intervalController,
                                            selectedWeekdays: _selectedWeekdays,
                                            onWeekdaysChanged: (days) {
                                              setState(
                                                () => _selectedWeekdays = days,
                                              );
                                            },
                                          )
                                        else if (_scheduleType ==
                                            RecurrenceType.monthly)
                                          MonthlySchedulingWidget(
                                            startDate: _startDate,
                                            onStartDateChanged: (date) {
                                              setState(() => _startDate = date);
                                            },
                                            dailyTimesController:
                                                _dailyTimesController,
                                            intervalController:
                                                _intervalController,
                                            ruleTypeController:
                                                _monthlyRuleTypeController,
                                            dayOfMonthController:
                                                _monthlyDayOfMonthController,
                                            nthOccurrenceController:
                                                _monthlyNthOccurrenceController,
                                            dayOfWeekController:
                                                _monthlyDayOfWeekController,
                                          )
                                        else if (_scheduleType ==
                                            RecurrenceType.yearly)
                                          YearlySchedulingWidget(
                                            startDate: _startDate,
                                            onStartDateChanged: (date) {
                                              setState(() => _startDate = date);
                                            },
                                            dailyTimesController:
                                                _dailyTimesController,
                                            intervalController:
                                                _intervalController,
                                            monthController:
                                                _yearlyMonthController,
                                            dayController: _yearlyDayController,
                                          ),
                                        if (_scheduleType !=
                                            RecurrenceType.oneOff) ...[
                                          const Divider(height: 32),
                                          Text(
                                            context.l10n.missedPolicyHeader,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            key: const Key(
                                              'missed_policy_dropdown',
                                            ),
                                            spacing: 8.0,
                                            runSpacing: 8.0,
                                            children: MissedPolicy.values.map((
                                              policy,
                                            ) {
                                              final String label;
                                              switch (policy) {
                                                case MissedPolicy.rollover:
                                                  label = context
                                                      .l10n
                                                      .rolloverLabel;
                                                  break;
                                                case MissedPolicy.skip:
                                                  label =
                                                      context.l10n.skipLabel;
                                                  break;
                                                case MissedPolicy.shift:
                                                  label =
                                                      context.l10n.shiftLabel;
                                                  break;
                                                case MissedPolicy.stack:
                                                  label =
                                                      context.l10n.stackLabel;
                                                  break;
                                              }

                                              return _buildCustomChip(
                                                key: Key(
                                                  'missed_policy_chip_${policy.name}',
                                                ),
                                                label: label,
                                                isSelected:
                                                    _missedPolicy == policy,
                                                onSelected: readOnly
                                                    ? null
                                                    : (selected) {
                                                        if (selected) {
                                                          setState(() {
                                                            _missedPolicy =
                                                                policy;
                                                          });
                                                        }
                                                      },
                                              );
                                            }).toList(),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            context.l10n.missedPolicyHelper,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.outline,
                                                ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            _getMissedPolicyDescription(
                                              context,
                                              _missedPolicy,
                                            ),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.outline,
                                                ),
                                          ),
                                        ],
                                        const Divider(height: 32),
                                        UpcomingOccurrencesPreview(
                                          schedule: _buildSchedule(),
                                          dailyTimes:
                                              _scheduleType ==
                                                  RecurrenceType.oneOff
                                              ? (_oneOffNotificationController
                                                            .value !=
                                                        null
                                                    ? [
                                                        DailyOccurrenceTime(
                                                          startTime:
                                                              TimeOfDay.fromDateTime(
                                                                _startDateTimeController
                                                                    .value,
                                                              ),
                                                          dueTime:
                                                              TimeOfDay.fromDateTime(
                                                                _dueDateTimeController
                                                                    .value,
                                                              ),
                                                          notificationTime:
                                                              _oneOffNotificationController
                                                                  .value,
                                                        ),
                                                      ]
                                                    : const <
                                                        DailyOccurrenceTime
                                                      >[])
                                              : _dailyTimesController.value,
                                          startDateTime:
                                              _startDateTimeController.value,
                                          dueDateTime:
                                              _dueDateTimeController.value,
                                          scheduleType: _scheduleType,
                                          maxOccurrences: 10,
                                        ),
                                      ],
                                    ),
                                  ),
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
                          child: Text(context.l10n.discardButton),
                        ),
                        const SizedBox(width: 16),
                        FilledButton(
                          key: const Key('save_task_button'),
                          onPressed: (_isSaving || readOnly) ? null : _saveTask,
                          child: _isSaving
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    value:
                                        CreateTaskScreen.debugDisableAnimations
                                        ? 0.8
                                        : null,
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(context.l10n.saveButton),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getMissedPolicyDescription(
    BuildContext context,
    MissedPolicy policy,
  ) {
    switch (policy) {
      case MissedPolicy.rollover:
        return context.l10n.rolloverDescription;
      case MissedPolicy.skip:
        return context.l10n.skipDescription;
      case MissedPolicy.shift:
        return context.l10n.shiftDescription;
      case MissedPolicy.stack:
        return context.l10n.stackDescription;
    }
  }
}
