import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../logic/task_schedule.dart';
import '../logic/task_instance.dart';
import '../logic/civil_day.dart';
import '../logic/relative_time.dart';
import '../logic/task_repository.dart';
import '../logic/l10n_extension.dart';
import 'task_widget.dart';

class MissedPoliciesPlaygroundTab extends StatefulWidget {
  const MissedPoliciesPlaygroundTab({super.key});

  @override
  State<MissedPoliciesPlaygroundTab> createState() =>
      _MissedPoliciesPlaygroundTabState();
}

class _MissedPoliciesPlaygroundTabState
    extends State<MissedPoliciesPlaygroundTab> {
  late MissedPolicy _selectedPolicy;
  late CivilDay _simulatedToday;
  late List<TaskSchedule> _simulatedTasks;
  late List<String> _historyLog;
  late Set<CivilDay> _completedDays;
  late Set<CivilDay> _missedDays;
  late Set<CivilDay> _skippedDays;
  late FakeTaskRepository _fakeRepository;

  @override
  void initState() {
    super.initState();
    _selectedPolicy = MissedPolicy.stack;
    _fakeRepository = FakeTaskRepository(
      onComplete: _handleCompleteTask,
      onDelete: _handleDeleteTask,
    );
    _reset();
  }

  void _reset() {
    setState(() {
      _simulatedToday = const CivilDay(year: 2026, month: 6, day: 1);
      _completedDays = {};
      _missedDays = {};
      _skippedDays = {};

      final String policyName = _getPolicyLabel(_selectedPolicy);
      _historyLog = ["June 1: Simulation started with $policyName policy."];

      _simulatedTasks = [];
      _initializeTasksForCurrentPolicy();
    });
  }

  String _getPolicyLabel(MissedPolicy policy) {
    switch (policy) {
      case MissedPolicy.preferNewer:
        return "Prefer Newer";
      case MissedPolicy.preferOlder:
        return "Prefer Older";
      case MissedPolicy.stack:
        return "Stack";
      case MissedPolicy.autoDismiss:
        return "Auto-Dismiss";
      case MissedPolicy.skip:
        return "Legacy";
    }
  }

  void _initializeTasksForCurrentPolicy() {
    if (_selectedPolicy == MissedPolicy.stack ||
        _selectedPolicy == MissedPolicy.autoDismiss) {
      _simulatedTasks.add(
        _createSpawnedTask(const CivilDay(year: 2026, month: 6, day: 1)),
      );
    } else {
      _simulatedTasks.add(
        TaskSchedule(
          id: 'simulated-task-recurring',
          title: 'Water the Houseplants',
          description: 'Give them just enough water.',
          schedules: [
            DailySchedule(
              startDate: const CivilDay(year: 2026, month: 6, day: 1),
              interval: 1,
              startRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 9, minute: 0),
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 17, minute: 0),
              ),
            ),
          ],
          activeOccurrenceIndex: 0,
          missedPolicy: _selectedPolicy,
          isMaster: false,
        ),
      );
    }
  }

  TaskSchedule _createSpawnedTask(CivilDay date) {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return TaskSchedule(
      id: 'simulated-task-spawned-$dateStr',
      title: 'Water the Houseplants',
      description: 'Give them just enough water.',
      schedules: [
        OneOffSchedule(
          date: date,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
        ),
      ],
      activeOccurrenceIndex: 0,
      missedPolicy: _selectedPolicy,
      isMaster: false,
      parentTaskId: 'simulated-task-master',
    );
  }

  void _advanceDay() {
    setState(() {
      final prevDay = _simulatedToday;
      _simulatedToday = _simulatedToday.addDays(1);
      final prevDayStr = _formatDate(prevDay);
      final todayStr = _formatDate(_simulatedToday);

      switch (_selectedPolicy) {
        case MissedPolicy.preferOlder:
          bool hasOverdue = _simulatedTasks.any((t) {
            final scheduledDate = t.schedules.first.scheduledDate;
            return scheduledDate.isBefore(_simulatedToday) &&
                !_completedDays.contains(scheduledDate);
          });
          if (hasOverdue) {
            _skippedDays.add(_simulatedToday);
            _historyLog.add(
              "$todayStr: Missed task scheduled for $prevDayStr. Bypassed today's task to keep older active (Prefer Older).",
            );
          } else {
            _simulatedTasks = [_createSpawnedTask(_simulatedToday)];
          }
          break;

        case MissedPolicy.preferNewer:
          final List<TaskSchedule> toSkip = [];
          for (final t in _simulatedTasks) {
            final scheduledDate = t.schedules.first.scheduledDate;
            if (scheduledDate.isBefore(_simulatedToday)) {
              toSkip.add(t);
            }
          }

          if (toSkip.isNotEmpty) {
            for (final t in toSkip) {
              final scheduledDate = t.schedules.first.scheduledDate;
              _skippedDays.add(scheduledDate);
              _historyLog.add(
                "$todayStr: Task scheduled for ${_formatDate(scheduledDate)} was skipped in favor of the newer occurrence (Prefer Newer).",
              );
            }
          }
          _simulatedTasks = [_createSpawnedTask(_simulatedToday)];
          break;

        case MissedPolicy.stack:
          if (!_completedDays.contains(prevDay)) {
            _missedDays.add(prevDay);
            _historyLog.add(
              "$todayStr: Task scheduled for $prevDayStr was missed. New instance spawned (Stack).",
            );
          } else {
            _historyLog.add(
              "$todayStr: New instance spawned for today (Stack).",
            );
          }

          final alreadyExists = _simulatedTasks.any(
            (t) => t.schedules.first.scheduledDate == _simulatedToday,
          );
          if (!alreadyExists) {
            _simulatedTasks.add(_createSpawnedTask(_simulatedToday));
          }
          break;

        case MissedPolicy.autoDismiss:
          if (!_completedDays.contains(prevDay)) {
            _skippedDays.add(prevDay);
            _historyLog.add(
              "$todayStr: Task scheduled for $prevDayStr expired and was auto-dismissed (Auto-dismiss).",
            );
          } else {
            _historyLog.add(
              "$todayStr: New instance spawned for today (Auto-dismiss).",
            );
          }

          _simulatedTasks.removeWhere(
            (t) => t.schedules.first.scheduledDate.isBefore(_simulatedToday),
          );

          final alreadyExists = _simulatedTasks.any(
            (t) => t.schedules.first.scheduledDate == _simulatedToday,
          );
          if (!alreadyExists) {
            _simulatedTasks.add(_createSpawnedTask(_simulatedToday));
          }
          break;

        case MissedPolicy.skip:
          break;
      }
    });
  }

  Future<void> _handleCompleteTask(String id) async {
    if (!mounted) return;
    setState(() {
      final taskIndex = _simulatedTasks.indexWhere((t) => t.id == id);
      if (taskIndex == -1) return;

      final task = _simulatedTasks[taskIndex];
      final scheduledDate = task.schedules.first.scheduledDate;
      final todayStr = _formatDate(_simulatedToday);
      final scheduledStr = _formatDate(scheduledDate);

      _completedDays.add(scheduledDate);

      if (_selectedPolicy == MissedPolicy.stack ||
          _selectedPolicy == MissedPolicy.autoDismiss) {
        _simulatedTasks.removeAt(taskIndex);
        _historyLog.add(
          "$todayStr: Completed task instance scheduled for $scheduledStr.",
        );
      } else {
        final CivilDay nextDate = _simulatedToday.addDays(1);
        final logMsg =
            "$todayStr: Completed task (scheduled for $scheduledStr). Rescheduled relative to today -> ${_formatDate(nextDate)}.";

        final rescheduledTask = TaskSchedule(
          id: task.id,
          title: task.title,
          description: task.description,
          schedules: [
            DailySchedule(
              startDate: nextDate,
              interval: 1,
              startRelativeTime: task.schedules.first.startRelativeTime,
              dueRelativeTime: task.schedules.first.dueRelativeTime,
            ),
          ],
          activeOccurrenceIndex: 0,
          missedPolicy: _selectedPolicy,
          isMaster: false,
        );

        _simulatedTasks[taskIndex] = rescheduledTask;
        _historyLog.add(logMsg);
      }
    });
  }

  Future<void> _handleDeleteTask(String id) async {
    if (!mounted) return;
    setState(() {
      final taskIndex = _simulatedTasks.indexWhere((t) => t.id == id);
      if (taskIndex == -1) return;

      final task = _simulatedTasks[taskIndex];
      final scheduledDate = task.schedules.first.scheduledDate;
      final todayStr = _formatDate(_simulatedToday);
      final scheduledStr = _formatDate(scheduledDate);

      if (_selectedPolicy == MissedPolicy.stack ||
          _selectedPolicy == MissedPolicy.autoDismiss) {
        _simulatedTasks.removeAt(taskIndex);
        _historyLog.add(
          "$todayStr: Dismissed task instance scheduled for $scheduledStr.",
        );
      } else {
        final CivilDay nextDate = _simulatedToday.addDays(1);
        final oldSchedule = task.schedules.first;
        final rescheduledTask = TaskSchedule(
          id: task.id,
          title: task.title,
          description: task.description,
          schedules: [
            DailySchedule(
              startDate: nextDate,
              interval: 1,
              startRelativeTime: oldSchedule.startRelativeTime,
              dueRelativeTime: oldSchedule.dueRelativeTime,
            ),
          ],
          activeOccurrenceIndex: 0,
          missedPolicy: _selectedPolicy,
          isMaster: false,
        );

        _simulatedTasks[taskIndex] = rescheduledTask;
        _historyLog.add(
          "$todayStr: Dismissed task (scheduled for $scheduledStr). Rescheduled to ${_formatDate(nextDate)}.",
        );
      }
    });
  }

  String _formatDate(CivilDay day) {
    final l10n = context.l10n;
    final monthNames = [
      l10n.monthJanuary,
      l10n.monthFebruary,
      l10n.monthMarch,
      l10n.monthApril,
      l10n.monthMay,
      l10n.monthJune,
      l10n.monthJuly,
      l10n.monthAugust,
      l10n.monthSeptember,
      l10n.monthOctober,
      l10n.monthNovember,
      l10n.monthDecember,
    ];
    return "${monthNames[day.month - 1]} ${day.day}";
  }

  String _getTipText() {
    switch (_selectedPolicy) {
      case MissedPolicy.preferNewer:
        return """### Prefer Newer Policy

**Behavior:** Only the newest task remains pending; older unresolved instances are skipped.

**Try this:**
1. Tap **Advance 1 Day** once or twice to let the task go overdue.
2. Notice that the older task is automatically marked as skipped in history, and only the newest day's task remains active.""";
      case MissedPolicy.preferOlder:
        return """### Prefer Older Policy

**Behavior:** Only the oldest unresolved instance remains pending; newer instances are skipped until it is resolved.

**Try this:**
1. Tap **Advance 1 Day** once or twice.
2. Notice that the task for the first day remains pending, while the newer days are automatically skipped in history.
3. Tap the checkbox to complete it.
4. Notice the next scheduled occurrence starts after today, with zero catch-up required.""";
      case MissedPolicy.stack:
        return """### Stack Policy

**Behavior:** Missed occurrences remain active and spawn a separate task instance for each day, letting multiple instances stack up.

**Try this:**
1. Tap **Advance 1 Day** 3 times.
2. Notice that 3 separate tasks appear on your list (one for each missed day).
3. Complete or dismiss them individually to clear the backlog.""";
      case MissedPolicy.autoDismiss:
        return """### Auto-Dismiss Policy

**Behavior:** Missed occurrences stack, but each instance automatically expires and is skipped after a configurable grace period (e.g., 24 hours).

**Try this:**
1. Tap **Advance 1 Day**.
2. Notice the previous day's task automatically expires and is marked as skipped in history, keeping your active list clean.""";
      case MissedPolicy.skip:
        return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    final Set<CivilDay> scheduledDays = {};
    for (int d = 1; d <= 30; d++) {
      scheduledDays.add(
        CivilDay(
          year: _simulatedToday.year,
          month: _simulatedToday.month,
          day: d,
        ),
      );
    }

    return Scaffold(
      body: ProviderScope(
        overrides: [taskRepositoryProvider.overrideWithValue(_fakeRepository)],
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MarkdownBody(data: l10n.missedPoliciesIntro),
                        const Divider(height: 24),
                        MarkdownBody(data: _getTipText()),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                l10n.missedPolicyHeader,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: SegmentedButton<MissedPolicy>(
                  segments: const [
                    ButtonSegment(
                      value: MissedPolicy.preferNewer,
                      label: Text("Prefer Newer"),
                    ),
                    ButtonSegment(
                      value: MissedPolicy.preferOlder,
                      label: Text("Prefer Older"),
                    ),
                    ButtonSegment(
                      value: MissedPolicy.stack,
                      label: Text("Stack"),
                    ),
                    ButtonSegment(
                      value: MissedPolicy.autoDismiss,
                      label: Text("Auto-Dismiss"),
                    ),
                  ],
                  selected: {_selectedPolicy},
                  onSelectionChanged: (value) {
                    setState(() {
                      _selectedPolicy = value.first;
                      _reset();
                    });
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Simulator Control Panel
              Card(
                color: theme.colorScheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.simulatedTodayLabel(
                              _formatDate(_simulatedToday),
                            ),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _reset,
                            icon: const Icon(Icons.refresh),
                            label: Text(l10n.resetSimButton),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _advanceDay,
                              icon: const Icon(Icons.arrow_forward),
                              label: Text(l10n.advanceDayButton),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    theme.colorScheme.primaryContainer,
                                foregroundColor:
                                    theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Layout Wrap for Calendar Grid and Simulated Tasks Side-by-side or Stacked
              Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  // Calendar Grid
                  SimulationMonthGrid(
                    year: _simulatedToday.year,
                    month: _simulatedToday.month,
                    simulatedToday: _simulatedToday,
                    completedDays: _completedDays,
                    missedDays: _missedDays,
                    skippedDays: _skippedDays,
                    scheduledDays: scheduledDays,
                  ),

                  // Simulated Tasks List
                  Container(
                    width: 320,
                    constraints: const BoxConstraints(minHeight: 180),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.dividerColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.activeTasksHeader(_simulatedTasks.length),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_simulatedTasks.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 32.0,
                              ),
                              child: Text(
                                'No active tasks.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          )
                        else
                          ..._simulatedTasks.map((task) {
                            final scheduledDate =
                                task.schedules.first.scheduledDate;
                            final isOverdue = scheduledDate.isBefore(
                              _simulatedToday,
                            );
                            final scheduledStr = _formatDate(scheduledDate);
                            return Padding(
                              key: ValueKey(task.id),
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 4.0,
                                      bottom: 4.0,
                                    ),
                                    child: Text(
                                      isOverdue
                                          ? "Scheduled: $scheduledStr (Overdue)"
                                          : "Scheduled: $scheduledStr",
                                      style: TextStyle(
                                        color: isOverdue
                                            ? theme.colorScheme.error
                                            : theme.colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  TaskWidget(
                                    instance: TaskInstance(
                                      id: task.id,
                                      scheduleId: task.id,
                                      title: task.title,
                                      description: task.description,
                                      scheduledDate:
                                          task.schedules.first.scheduledDate,
                                      startRelativeTime: task
                                          .schedules
                                          .first
                                          .startRelativeTime,
                                      dueRelativeTime:
                                          task.schedules.first.dueRelativeTime,
                                      isFamily: task.isFamily,
                                      priority: task.priority,
                                      status: 'pending',
                                    ),
                                    schedule: task,
                                    showEditOption: false,
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Simulation Logs
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.historyLogHeader,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(height: 16),
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        itemCount: _historyLog.length,
                        itemBuilder: (context, index) {
                          // Show logs in reverse order to see latest logs first
                          final logIndex = _historyLog.length - 1 - index;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "• ",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Expanded(
                                  child: Text(
                                    _historyLog[logIndex],
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
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

class DummyFirebaseFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeTaskRepository extends TaskRepository {
  final Future<void> Function(String) onComplete;
  final Future<void> Function(String) onDelete;

  FakeTaskRepository({required this.onComplete, required this.onDelete})
    : super(
        firestore: DummyFirebaseFirestore(),
        userId: 'playground_user',
        notificationService: null,
      );

  @override
  Future<TaskInstance?> completeTaskInstance(String id) async {
    await onComplete(id);
    return null;
  }

  @override
  Future<({TaskSchedule task, List<TaskInstance> pendingInstances})?>
  deleteTaskSchedule(String id) async {
    await onDelete(id);
    return null;
  }

  @override
  Future<void> restoreTaskSchedule(
    TaskSchedule task,
    List<TaskInstance> pendingInstances,
  ) async {
    // No-op for playground
  }

  @override
  Future<TaskInstance?> dismissTaskInstance(String id) async {
    await onComplete(id);
    return null;
  }

  @override
  Future<void> undoResolveTaskInstance(TaskInstance resolvedInstance) async {
    // No-op for playground simulation
  }
}

class SimulationMonthGrid extends StatelessWidget {
  final int year;
  final int month;
  final CivilDay simulatedToday;
  final Set<CivilDay> completedDays;
  final Set<CivilDay> missedDays;
  final Set<CivilDay> skippedDays;
  final Set<CivilDay> scheduledDays;

  const SimulationMonthGrid({
    super.key,
    required this.year,
    required this.month,
    required this.simulatedToday,
    required this.completedDays,
    required this.missedDays,
    required this.skippedDays,
    required this.scheduledDays,
  });

  List<String> _getMonthNames(BuildContext context) {
    final l10n = context.l10n;
    return [
      l10n.monthJanuary,
      l10n.monthFebruary,
      l10n.monthMarch,
      l10n.monthApril,
      l10n.monthMay,
      l10n.monthJune,
      l10n.monthJuly,
      l10n.monthAugust,
      l10n.monthSeptember,
      l10n.monthOctober,
      l10n.monthNovember,
      l10n.monthDecember,
    ];
  }

  List<String> _getWeekdayHeaders(BuildContext context) {
    final l10n = context.l10n;
    return [
      l10n.weekdayHeaderMonday,
      l10n.weekdayHeaderTuesday,
      l10n.weekdayHeaderWednesday,
      l10n.weekdayHeaderThursday,
      l10n.weekdayHeaderFriday,
      l10n.weekdayHeaderSaturday,
      l10n.weekdayHeaderSunday,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstDay = DateTime.utc(year, month, 1);
    final totalDays = DateTime.utc(year, month + 1, 0).day;
    final firstWeekday = firstDay.weekday; // 1 = Mon, 7 = Sun

    final monthName = _getMonthNames(context)[month - 1];
    final weekdayLabels = _getWeekdayHeaders(context);

    return Container(
      width: 280,
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$monthName $year',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          // Weekday headers
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: 7,
            itemBuilder: (context, index) {
              return Center(
                child: Text(
                  weekdayLabels[index],
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            },
          ),
          const Divider(height: 12),
          // Days grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: (firstWeekday - 1) + totalDays,
            itemBuilder: (context, index) {
              if (index < firstWeekday - 1) {
                return const SizedBox.shrink();
              }
              final day = index - (firstWeekday - 1) + 1;
              final currentDay = CivilDay(year: year, month: month, day: day);

              final isToday = currentDay == simulatedToday;
              final isCompleted = completedDays.contains(currentDay);
              final isMissed = missedDays.contains(currentDay);
              final isSkipped = skippedDays.contains(currentDay);
              final isScheduled = scheduledDays.contains(currentDay);

              Color? bgColor;
              BoxBorder? border;
              TextStyle textStyle =
                  theme.textTheme.bodyMedium ?? const TextStyle();

              if (isToday) {
                border = Border.all(color: theme.colorScheme.primary, width: 2);
                textStyle = textStyle.copyWith(fontWeight: FontWeight.bold);
              }

              if (isCompleted) {
                bgColor = Colors.green[600];
                textStyle = textStyle.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                );
              } else if (isMissed) {
                bgColor = Colors.red[600];
                textStyle = textStyle.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                );
              } else if (isSkipped) {
                bgColor = Colors.grey[400];
                textStyle = textStyle.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                );
              }

              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: bgColor,
                      border: border,
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: Text('$day', style: textStyle)),
                  ),
                  if (isScheduled && !isCompleted && !isMissed && !isSkipped)
                    Positioned(
                      bottom: 2,
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.6,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
