import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../logic/task_schedule.dart';
import '../logic/task_instance.dart';
import '../logic/civil_day.dart';
import '../logic/relative_time.dart';
import '../logic/task_repository.dart';
import '../logic/l10n_extension.dart';
import '../logic/scheduler_engine.dart';
import 'missed_occurrence_policy_selector.dart';
import 'playground_fake_task_repository.dart';
import 'task_widget.dart';

enum SimulationPreset { daily, weekly }

class MissedPoliciesPlaygroundTab extends StatefulWidget {
  const MissedPoliciesPlaygroundTab({super.key});

  @override
  State<MissedPoliciesPlaygroundTab> createState() =>
      _MissedPoliciesPlaygroundTabState();
}

class _MissedPoliciesPlaygroundTabState
    extends State<MissedPoliciesPlaygroundTab> {
  late SimulationPreset _preset;
  late MissedOccurrencePolicy _missedOccurrencePolicy;
  late DateTime _simulatedNow;
  late TaskSchedule _taskSchedule;
  late List<TaskInstance> _taskInstances;
  late List<String> _historyLog;
  late PlaygroundFakeTaskRepository _fakeRepository;

  @override
  void initState() {
    super.initState();
    _preset = SimulationPreset.daily;
    _missedOccurrencePolicy = const MissedOccurrencePolicy.stack();
    _fakeRepository = PlaygroundFakeTaskRepository(
      onComplete: _handleCompleteTask,
      onDismiss: _handleDeleteTask,
    );
    _reset();
  }

  void _reset() {
    setState(() {
      _simulatedNow = DateTime(
        2026,
        6,
        1,
        9,
        0,
      ); // Start June 1, 2026 @ 9:00 AM
      _taskInstances = [];

      final policy = _missedOccurrencePolicy;
      final scheduleId = _preset == SimulationPreset.daily
          ? 'S-simulated-task-daily'
          : 'S-simulated-task-weekly';
      final title = _preset == SimulationPreset.daily
          ? 'Feed the Pets'
          : 'Mow the Lawn & Weed Gardens';
      final desc = _preset == SimulationPreset.daily
          ? 'Give them fresh water and quality kibble.'
          : 'Trim borders, empty the grass bag, and weed gardens.';

      final rule = _preset == SimulationPreset.daily
          ? DailySchedule(
              id: 'R-simulated-rule-daily',
              scheduleId: scheduleId,
              startDate: const CivilDay(year: 2026, month: 6, day: 1),
              interval: 1,
              startRelativeTime: const RelativeTime(
                dayOffset: 0,
                hour: 9,
                minute: 0,
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 0,
                hour: 17,
                minute: 0,
              ),
              missedOccurrencePolicy: policy,
            )
          : WeeklySchedule(
              id: 'R-simulated-rule-weekly',
              scheduleId: scheduleId,
              startDate: const CivilDay(year: 2026, month: 6, day: 1),
              interval: 1,
              daysOfWeek: {3, 6}, // Wednesday and Saturday
              startRelativeTime: const RelativeTime(
                dayOffset: 0,
                hour: 9,
                minute: 0,
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 0,
                hour: 18,
                minute: 0,
              ),
              missedOccurrencePolicy: policy,
            );

      _taskSchedule = TaskSchedule(
        id: scheduleId,
        title: title,
        description: desc,
        schedules: [rule],
        activeOccurrenceIndex: 0,
        isMaster: false,
      );

      final presetStr = _preset == SimulationPreset.daily ? "Daily" : "Weekly";
      final policyStr = _getPolicyLabel(policy.policy);
      _historyLog = [
        "Simulation started at ${_formatDateTimeLog(_simulatedNow)}.",
        "Configured: $presetStr task with $policyStr policy.",
      ];
    });

    _runEvaluation(logChanges: false);
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
    }
  }

  void _runEvaluation({bool logChanges = true}) {
    final oldStatuses = {
      for (final inst in _taskInstances) inst.id: inst.status,
    };

    final Map<CivilDay, double> dayPlannedHours = {};
    for (final inst in _taskInstances) {
      if (inst.status != TaskStatus.skipped &&
          inst.status != TaskStatus.failed) {
        if (_taskSchedule.estimatedDuration != null) {
          final hours = _taskSchedule.estimatedDuration!.inMinutes / 60.0;
          dayPlannedHours[inst.scheduledDate] =
              (dayPlannedHours[inst.scheduledDate] ?? 0.0) + hours;
        }
      }
    }

    final action = const SchedulerEngine().evaluate(
      _taskSchedule,
      _taskInstances,
      _simulatedNow,
      dayPlannedHours: dayPlannedHours,
    );

    setState(() {
      if (action.updatedSchedule != null) {
        _taskSchedule = action.updatedSchedule!;
      }

      for (final spawned in action.instancesToSpawn) {
        _taskInstances.removeWhere((x) => x.id == spawned.id);
        _taskInstances.add(spawned);
      }

      for (final updated in action.instancesToUpdate) {
        final idx = _taskInstances.indexWhere((x) => x.id == updated.id);
        if (idx != -1) {
          _taskInstances[idx] = updated;
        }
      }

      for (final deletedId in action.instancesToDelete) {
        _taskInstances.removeWhere((x) => x.id == deletedId);
      }

      if (logChanges) {
        final timeStr = _formatDateTimeLog(_simulatedNow);
        for (final inst in _taskInstances) {
          final oldStatus = oldStatuses[inst.id];
          final dateStr = _formatDate(inst.scheduledDate);
          if (oldStatus == null) {
            _historyLog.add(
              "$timeStr: Spawned task instance for $dateStr (status: ${inst.status}).",
            );
          } else if (oldStatus != inst.status) {
            _historyLog.add(
              "$timeStr: Task for $dateStr status changed from $oldStatus to ${inst.status}.",
            );
          }
        }

        final currentIds = _taskInstances.map((x) => x.id).toSet();
        for (final oldId in oldStatuses.keys) {
          if (!currentIds.contains(oldId)) {
            _historyLog.add("$timeStr: Removed task instance from queue.");
          }
        }
      }
    });
  }

  void _advanceTime(Duration duration) {
    setState(() {
      _simulatedNow = _simulatedNow.add(duration);
    });
    _runEvaluation();
  }

  Future<void> _resolveTaskInstance(
    String instanceId, {
    required TaskStatus status,
    required String actionVerb,
  }) async {
    if (!mounted) return;
    setState(() {
      int idx = _taskInstances.indexWhere((t) => t.id == instanceId);
      if (idx == -1) {
        final stripped = instanceId.startsWith('I-')
            ? instanceId.substring(2)
            : instanceId;
        idx = _taskInstances.indexWhere((t) => t.id == stripped);
      }
      if (idx == -1) return;
      final taskInst = _taskInstances[idx];
      _taskInstances[idx] = taskInst.copyWith(
        status: status,
        completedAt: _simulatedNow,
      );
      _historyLog.add(
        "${_formatDateTimeLog(_simulatedNow)}: $actionVerb task scheduled for ${_formatDate(taskInst.scheduledDate)}.",
      );
    });
    _runEvaluation();
  }

  Future<void> _handleCompleteTask(String instanceId) => _resolveTaskInstance(
    instanceId,
    status: TaskStatus.completed,
    actionVerb: 'Completed',
  );

  Future<void> _handleDeleteTask(String instanceId) => _resolveTaskInstance(
    instanceId,
    status: TaskStatus.skipped,
    actionVerb: 'Dismissed',
  );

  String _formatDate(CivilDay day) {
    return "${context.l10n.monthNames[day.month - 1]} ${day.day}";
  }

  String _format12HourTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  String _formatDateTimeLog(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return "${months[dt.month - 1]} ${dt.day} @ ${_format12HourTime(dt)}";
  }

  String _formatDateTimeLabel(DateTime dt) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return "${months[dt.month - 1]} ${dt.day}, ${_format12HourTime(dt)}";
  }

  String _getTipText() {
    switch (_missedOccurrencePolicy.policy) {
      case MissedPolicy.preferNewer:
        return """### Prefer Newer Policy

**Behavior:** Only the newest task remains pending; older unresolved instances are skipped.

**Try this:**
1. Advance the simulation by **24 Hours** once or twice to let the task go overdue.
2. Notice that the older task is automatically marked as skipped in history, and only the newest day's task remains active.""";
      case MissedPolicy.preferOlder:
        return """### Prefer Older Policy

**Behavior:** Only the oldest unresolved instance remains pending; newer instances are skipped until it is resolved.

**Try this:**
1. Advance the simulation by **24 Hours** once or twice.
2. Notice that the task for the first day remains pending, while the newer days are automatically skipped in history.
3. Tap the checkbox to complete it.
4. Notice the next scheduled occurrence starts after today, with zero catch-up required.""";
      case MissedPolicy.stack:
        return """### Stack Policy

**Behavior:** Missed occurrences remain active and spawn a separate task instance for each day, letting multiple instances stack up.

**Try this:**
1. Advance the simulation by **24 Hours** 3 times.
2. Notice that 3 separate tasks appear on your list (one for each missed day).
3. Complete or dismiss them individually to clear the backlog.""";
      case MissedPolicy.autoDismiss:
        final durationStr = _preset == SimulationPreset.daily
            ? context.l10n.autoDismissPolicyHours(2)
            : context.l10n.autoDismissPolicyHours(9);
        return """### Auto-Dismiss Policy

**Behavior:** Missed occurrences stack, but each instance automatically expires and is skipped after a configurable grace period (e.g., $durationStr).

**Try this:**
1. Configured preset has a due time. Notice when you advance time past the task's due time + grace period, the task automatically expires and is marked as skipped in history, keeping your active list clean.""";
    }
  }

  Widget _buildAdvanceTimeButton(
    ThemeData theme, {
    required Duration duration,
    required String label,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: ElevatedButton.icon(
          onPressed: () => _advanceTime(duration),
          icon: const Icon(Icons.fast_forward, size: 16),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    final pendingInstances =
        _taskInstances
            .where((inst) => inst.status == TaskStatus.pending)
            .toList()
          ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

    return Scaffold(
      body: ProviderScope(
        overrides: [taskRepositoryProvider.overrideWithValue(_fakeRepository)],
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Missed occurrence policy simulator with introduction.
              SizedBox(
                width: double.infinity,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: MarkdownBody(data: l10n.missedPoliciesIntro),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 2. Missed occurrence policy selector
              MissedOccurrencePolicySelector(
                policy: _missedOccurrencePolicy,
                onChanged: (policy) {
                  setState(() {
                    _missedOccurrencePolicy = policy;
                    _reset();
                  });
                },
              ),
              const SizedBox(height: 20),

              // 3. Card explaining the policy.
              SizedBox(
                width: double.infinity,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: MarkdownBody(data: _getTipText()),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 4. Task type selector (use chips instead of a segmented button)
              Text(
                l10n.taskTypeLabel,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(l10n.simulationPresetDaily),
                    selected: _preset == SimulationPreset.daily,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _preset = SimulationPreset.daily;
                          _reset();
                        });
                      }
                    },
                  ),
                  ChoiceChip(
                    label: Text(l10n.simulationPresetWeekly),
                    selected: _preset == SimulationPreset.weekly,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _preset = SimulationPreset.weekly;
                          _reset();
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 5. Simulation controls
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.simulatedTimeLabel(
                            _formatDateTimeLabel(_simulatedNow),
                          ),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
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
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildAdvanceTimeButton(
                          theme,
                          duration: const Duration(hours: 1),
                          label: l10n.simulationOneHour,
                        ),
                        _buildAdvanceTimeButton(
                          theme,
                          duration: const Duration(hours: 6),
                          label: l10n.simulationSixHours,
                        ),
                        _buildAdvanceTimeButton(
                          theme,
                          duration: const Duration(hours: 24),
                          label: l10n.simulationTwentyFourHours,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 6. Simulated tasks
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.activeTasksHeader(pendingInstances.length),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (pendingInstances.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32.0),
                    child: Text(
                      l10n.noActivePlaygroundTasks,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                )
              else
                ...pendingInstances.map((inst) {
                  return TaskWidget(
                    key: ValueKey(inst.id),
                    instance: inst,
                    schedule: _taskSchedule,
                    showEditOption: false,
                    referenceTime: _simulatedNow,
                  );
                }),
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
