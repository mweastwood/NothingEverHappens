import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import '../logic/task_schedule.dart';
import '../logic/civil_day.dart';
import '../logic/relative_time.dart';
import '../logic/task_repository.dart';
import '../logic/error_handler.dart';
import '../logic/l10n_extension.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Type;
import '../logic/family_repository.dart';
import '../logic/undo_notifier.dart';
import '../widgets/undo_snackbar.dart';

import '../widgets/upcoming_occurrences_preview.dart';
import '../widgets/standard_choice_chip.dart';
import '../widgets/schedule_config_card.dart';

class CreateTaskScreen extends ConsumerStatefulWidget {
  static Duration saveTimeout = const Duration(seconds: 10);
  static bool debugDisableAnimations = false;

  final TaskSchedule? taskToEdit;

  const CreateTaskScreen({super.key, this.taskToEdit});

  @override
  ConsumerState<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class SaveIntent extends Intent {
  const SaveIntent();
}

class DiscardIntent extends Intent {
  const DiscardIntent();
}

class _CreateTaskScreenState extends ConsumerState<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _descriptionController = TextEditingController();
  final _estimatedDurationController = TextEditingController();

  List<TaskScheduleRule> _schedules = [];
  int? _expandedScheduleIndex;
  MissedPolicy _missedPolicy = MissedPolicy.rollover;

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
      _schedules = List.from(task.schedules);
      if (_schedules.isNotEmpty) {
        _expandedScheduleIndex = 0;
      }
    } else {
      final now = AppClock.now;
      final tomorrow = now.add(const Duration(days: 1));
      final civilTomorrow = CivilDay.fromDateTime(tomorrow);

      final startMidnight = DateTime.utc(now.year, now.month, now.day);
      final dueMidnight = DateTime.utc(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
      );
      final diff = startMidnight.difference(dueMidnight).inDays;

      _schedules = [
        OneOffSchedule(
          date: civilTomorrow,
          startRelativeTime: RelativeTime(
            dayOffset: diff,
            time: TimeOfDay.fromDateTime(now),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
        ),
      ];
      _expandedScheduleIndex = 0;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocusNode.dispose();
    _descriptionController.dispose();
    _estimatedDurationController.dispose();
    super.dispose();
  }

  Future<void> _saveTask() async {
    if (_formKey.currentState!.validate()) {
      if (_schedules.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('At least one schedule is required.')),
        );
        return;
      }

      setState(() {
        _isSaving = true;
      });

      try {
        final minutesText = _estimatedDurationController.text.trim();
        final minutes = minutesText.isNotEmpty
            ? int.tryParse(minutesText)
            : null;
        final estimatedDuration = minutes != null
            ? Duration(minutes: minutes)
            : null;

        final hasRepeating = _schedules.any((s) => s is! OneOffSchedule);

        final newTask = TaskSchedule(
          id: AppClock.now.millisecondsSinceEpoch.toString(),
          title: _titleController.text,
          description: _descriptionController.text,
          schedules: _schedules,
          estimatedDuration: estimatedDuration,
          missedPolicy: hasRepeating ? _missedPolicy : MissedPolicy.rollover,
          isMaster: hasRepeating && _missedPolicy == MissedPolicy.stack,
          lastSpawnedDate: hasRepeating && _missedPolicy == MissedPolicy.stack
              ? CivilDay.fromDateTime(AppClock.now).addDays(-1)
              : null,
          isFamily: _isFamily,
          priority: _priority,
          cycleId: _cycleId,
          preferredBy: _preferredBy,
          assignedUserId: _assignedUserId,
        );

        final repository = ref.read(taskRepositoryProvider);
        if (repository != null) {
          if (widget.taskToEdit != null) {
            final previousSchedule = widget.taskToEdit!;
            final modification = widget.taskToEdit!.edit(
              newTitle: _titleController.text,
              newDescription: _descriptionController.text,
              newSchedules: _schedules,
              newEstimatedDuration: estimatedDuration,
              newMissedPolicy: hasRepeating
                  ? _missedPolicy
                  : MissedPolicy.rollover,
              newIsMaster: hasRepeating && _missedPolicy == MissedPolicy.stack,
              newLastSpawnedDate:
                  widget.taskToEdit!.lastSpawnedDate ??
                  (hasRepeating && _missedPolicy == MissedPolicy.stack
                      ? CivilDay.fromDateTime(AppClock.now).addDays(-1)
                      : null),
              newIsFamily: _isFamily,
              newPriority: _priority,
              newCycleId: _cycleId,
              newPreferredBy: _preferredBy,
              newAssignedUserId: _assignedUserId,
            );
            await repository
                .updateTaskSchedule(modification)
                .timeout(
                  CreateTaskScreen.saveTimeout,
                  onTimeout: () => throw Exception(
                    'Save operation timed out. This may be due to a connectivity issue or a failure to sync with the database.',
                  ),
                );
            if (mounted) {
              UndoSnackBar.show(
                context: context,
                ref: ref,
                action: UndoEditTaskScheduleAction(
                  message: context.l10n.taskEditsSaved(previousSchedule.title),
                  previousSchedule: previousSchedule,
                  currentSchedule: modification.newTask,
                ),
                repository: repository,
                undoneLabel: context.l10n.editsReverted(previousSchedule.title),
              );
              Navigator.pop(context);
            }
          } else {
            await repository
                .addTaskSchedule(newTask)
                .timeout(
                  CreateTaskScreen.saveTimeout,
                  onTimeout: () => throw Exception(
                    'Save operation timed out. This may be due to a connectivity issue or a failure to sync with the database.',
                  ),
                );
            if (mounted) {
              Navigator.pop(context);
            }
          }
        }
      } catch (e, stackTrace) {
        if (mounted) {
          final errorHandler = ref.read(errorHandlerProvider);
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

  Widget _buildTitleField(BuildContext context, bool readOnly) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: _titleController,
      focusNode: _titleFocusNode,
      autofocus: !readOnly,
      enabled: !readOnly,
      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: context.l10n.titleFieldLabel,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.all(16),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return context.l10n.titleRequiredError;
        }
        return null;
      },
    );
  }

  Widget _buildDescriptionField(BuildContext context, bool readOnly) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: _descriptionController,
      enabled: !readOnly,
      decoration: InputDecoration(
        labelText: context.l10n.descriptionFieldLabel,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.all(16),
      ),
      style: theme.textTheme.bodyMedium,
      maxLines: 3,
    );
  }

  Widget _buildDetailsCard(BuildContext context, bool readOnly) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTitleField(context, readOnly),
            const SizedBox(height: 16),
            _buildDescriptionField(context, readOnly),
          ],
        ),
      ),
    );
  }

  Widget _buildEffortAndPriorityCard(
    BuildContext context,
    bool readOnly,
    bool isWide,
  ) {
    final theme = Theme.of(context);

    final metadataWidgets = [
      Expanded(
        flex: isWide ? 2 : 0,
        child: TextFormField(
          key: const Key('estimated_effort_field'),
          controller: _estimatedDurationController,
          enabled: !readOnly,
          decoration: InputDecoration(
            labelText: context.l10n.estimatedEffortFieldLabel,
            helperText: isWide ? null : context.l10n.estimatedEffortHelper,
            border: const OutlineInputBorder(),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
          ),
          style: theme.textTheme.bodyMedium,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              final val = int.tryParse(value);
              if (val == null || val <= 0) {
                return context.l10n.estimatedEffortValidationError;
              }
            }
            return null;
          },
        ),
      ),
      if (isWide) const SizedBox(width: 16) else const SizedBox(height: 16),
      Expanded(
        flex: isWide ? 3 : 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.taskPriorityLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              key: const Key('task_priority_dropdown'),
              spacing: 6.0,
              runSpacing: 6.0,
              children: TaskPriority.values.map((priority) {
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
                return StandardChoiceChip(
                  key: Key('priority_chip_${priority.name}'),
                  label: label,
                  selected: _priority == priority,
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
          ],
        ),
      ),
    ];

    Widget content;
    if (isWide) {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: metadataWidgets,
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: metadataWidgets.map((w) {
          if (w is Expanded) return w.child;
          return w;
        }).toList(),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Effort and Priority",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyCard(BuildContext context, bool readOnly) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Family",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            StandardChoiceChip(
              key: const Key('is_family_toggle'),
              label: _isFamily
                  ? 'Family TaskSchedule'
                  : 'Personal TaskSchedule',
              selected: _isFamily,
              onSelected: readOnly
                  ? null
                  : (selected) {
                      setState(() {
                        _isFamily = selected;
                      });
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCard(BuildContext context, bool readOnly) {
    final theme = Theme.of(context);
    final hasRepeating = _schedules.any((s) => s is! OneOffSchedule);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.scheduleHeader,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            AbsorbPointer(
              absorbing: readOnly,
              child: Opacity(
                opacity: readOnly ? 0.6 : 1.0,
                child: Column(
                  children: [
                    for (int i = 0; i < _schedules.length; i++)
                      ScheduleConfigCard(
                        key: ValueKey('schedule_card_$i'),
                        schedule: _schedules[i],
                        onChanged: (newSchedule) {
                          setState(() {
                            _schedules[i] = newSchedule;
                          });
                        },
                        onDelete: _schedules.length > 1
                            ? () {
                                setState(() {
                                  _schedules.removeAt(i);
                                  if (_expandedScheduleIndex == i) {
                                    _expandedScheduleIndex = null;
                                  } else if (_expandedScheduleIndex != null &&
                                      _expandedScheduleIndex! > i) {
                                    _expandedScheduleIndex =
                                        _expandedScheduleIndex! - 1;
                                  }
                                });
                              }
                            : null,
                        isExpanded: _expandedScheduleIndex == i,
                        onExpansionChanged: (expanded) {
                          setState(() {
                            _expandedScheduleIndex = expanded ? i : null;
                          });
                        },
                      ),
                    if (!readOnly) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        key: const Key('add_schedule_button'),
                        onPressed: () {
                          setState(() {
                            final now = AppClock.now;
                            final tomorrow = now.add(const Duration(days: 1));
                            final civilTomorrow = CivilDay.fromDateTime(
                              tomorrow,
                            );

                            final startMidnight = DateTime.utc(
                              now.year,
                              now.month,
                              now.day,
                            );
                            final dueMidnight = DateTime.utc(
                              tomorrow.year,
                              tomorrow.month,
                              tomorrow.day,
                            );
                            final diff = startMidnight
                                .difference(dueMidnight)
                                .inDays;

                            _schedules.add(
                              OneOffSchedule(
                                date: civilTomorrow,
                                startRelativeTime: RelativeTime(
                                  dayOffset: diff,
                                  time: TimeOfDay.fromDateTime(now),
                                ),
                                dueRelativeTime: const RelativeTime(
                                  dayOffset: 0,
                                  time: TimeOfDay(hour: 17, minute: 0),
                                ),
                              ),
                            );
                            _expandedScheduleIndex = _schedules.length - 1;
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Schedule'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (hasRepeating) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                context.l10n.missedPolicyHeader,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                key: const Key('missed_policy_dropdown'),
                spacing: 8.0,
                runSpacing: 8.0,
                children: MissedPolicy.values.map((policy) {
                  final String label;
                  switch (policy) {
                    case MissedPolicy.rollover:
                      label = context.l10n.rolloverLabel;
                      break;
                    case MissedPolicy.skip:
                      label = context.l10n.skipLabel;
                      break;
                    case MissedPolicy.shift:
                      label = context.l10n.shiftLabel;
                      break;
                    case MissedPolicy.stack:
                      label = context.l10n.stackLabel;
                      break;
                  }
                  return StandardChoiceChip(
                    key: Key('missed_policy_chip_${policy.name}'),
                    label: label,
                    selected: _missedPolicy == policy,
                    onSelected: readOnly
                        ? null
                        : (selected) {
                            if (selected) {
                              setState(() {
                                _missedPolicy = policy;
                              });
                            }
                          },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.missedPolicyHelper,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _getMissedPolicyDescription(context, _missedPolicy),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
            if (_schedules.any((s) => s is! OneOffSchedule)) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              UpcomingOccurrencesPreview(
                schedules: _schedules,
                maxOccurrences: 10,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final familyRepo = ref.watch(familyRepositoryProvider);
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
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth >= 800;

                        final detailsCard = _buildDetailsCard(
                          context,
                          readOnly,
                        );
                        final scheduleCard = _buildScheduleCard(
                          context,
                          readOnly,
                        );
                        final effortAndPriorityCard =
                            _buildEffortAndPriorityCard(
                              context,
                              readOnly,
                              isDesktop,
                            );
                        final familyCard = _buildFamilyCard(context, readOnly);

                        if (isDesktop) {
                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(16.0),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  detailsCard,
                                  const SizedBox(height: 16),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: scheduleCard),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            effortAndPriorityCard,
                                            if (inFamily) ...[
                                              const SizedBox(height: 16),
                                              familyCard,
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        } else {
                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(16.0),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  detailsCard,
                                  const SizedBox(height: 16),
                                  scheduleCard,
                                  const SizedBox(height: 16),
                                  effortAndPriorityCard,
                                  if (inFamily) ...[
                                    const SizedBox(height: 16),
                                    familyCard,
                                  ],
                                ],
                              ),
                            ),
                          );
                        }
                      },
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
