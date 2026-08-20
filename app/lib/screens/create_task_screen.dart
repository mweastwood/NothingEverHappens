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
import '../logic/family_repository.dart';
import '../logic/family.dart';
import '../logic/auth_repository.dart';
import '../logic/undo_notifier.dart';
import '../widgets/undo_snackbar.dart';

import '../widgets/standard_choice_chip.dart';
import '../widgets/schedule_config_card.dart';

import '../widgets/create_task/task_basic_info_section.dart';
import '../widgets/create_task/task_family_assignment_section.dart';
import '../widgets/spawned_instances_list.dart';
import '../logic/task_instance.dart';
import 'help_screen.dart';

class CreateTaskScreen extends ConsumerStatefulWidget {
  static Duration saveTimeout = const Duration(seconds: 10);
  static bool debugDisableAnimations = false;

  final TaskSchedule? taskToEdit;
  final TaskSchedule? taskToDuplicate;
  final bool defaultToRepeating;
  final bool isPracticeTask;

  const CreateTaskScreen({
    super.key,
    this.taskToEdit,
    this.taskToDuplicate,
    this.defaultToRepeating = false,
    this.isPracticeTask = false,
  });

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

  final _scrollController = ScrollController();
  final _titleFieldKey = GlobalKey();
  final _showTitleInAppBar = ValueNotifier<bool>(false);

  List<TaskScheduleRule> _schedules = [];
  int? _expandedScheduleIndex;
  late final String _taskScheduleId;

  bool _isSaving = false;

  // New Agile and Scoping variables
  bool _isFamily = false;
  FamilyCompletionMode _familyCompletionMode = FamilyCompletionMode.anyone;
  TaskPriority _priority = TaskPriority.medium;
  String? _cycleId;
  Map<String, bool> _preferredBy = const {};
  String? _assignedUserId;
  bool _skipIfNoCapacity = false;

  // Workflow properties
  bool _isExperimentalExpanded = false;
  bool _isMealWorkflow = false;
  TimeOfDay _selectTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _shopTime = const TimeOfDay(hour: 16, minute: 0);
  TimeOfDay _prepTime = const TimeOfDay(hour: 18, minute: 30);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (widget.taskToEdit != null) {
      final task = widget.taskToEdit!;
      _taskScheduleId = task.id;
      _titleController.text = task.title;
      _descriptionController.text = task.description;
      _isFamily = task.isFamily;
      _familyCompletionMode = task.familyCompletionMode;
      _priority = task.priority;
      _cycleId = task.cycleId;
      _preferredBy = Map<String, bool>.from(task.preferredBy);
      _assignedUserId = task.assignedUserId;
      _skipIfNoCapacity = task.skipIfNoCapacity;
      _isMealWorkflow = task.workflowType == 'mealWorkflow';
      if (task.mealWorkflowConfig != null) {
        _selectTime = task.mealWorkflowConfig!.selectTime.time;
        _shopTime = task.mealWorkflowConfig!.shopTime.time;
        _prepTime = task.mealWorkflowConfig!.prepTime.time;
      }
      if (task.estimatedDuration != null) {
        _estimatedDurationController.text = task.estimatedDuration!.inMinutes
            .toString();
      }
      _schedules = List.from(task.schedules);
      if (_schedules.isNotEmpty) {
        _expandedScheduleIndex = 0;
      }
    } else if (widget.taskToDuplicate != null) {
      final task = widget.taskToDuplicate!;
      _taskScheduleId = TaskSchedule.generateId();
      _titleController.text = task.title;
      _descriptionController.text = task.description;
      _isFamily = task.isFamily;
      _familyCompletionMode = task.familyCompletionMode;
      _priority = task.priority;
      _cycleId = task.cycleId;
      _preferredBy = Map<String, bool>.from(task.preferredBy);
      _assignedUserId = task.assignedUserId;
      _skipIfNoCapacity = task.skipIfNoCapacity;
      if (task.estimatedDuration != null) {
        _estimatedDurationController.text = task.estimatedDuration!.inMinutes
            .toString();
      }
      _schedules = task.schedules
          .map(
            (s) => s.copyWithTiming(
              id: TaskScheduleRule.generateId(),
              scheduleId: _taskScheduleId,
            ),
          )
          .toList();
      if (_schedules.isNotEmpty) {
        _expandedScheduleIndex = 0;
      }
    } else {
      _taskScheduleId = TaskSchedule.generateId();
      if (widget.defaultToRepeating) {
        final now = AppClock.now;
        _schedules = [
          DailySchedule(
            id: TaskScheduleRule.generateId(),
            scheduleId: _taskScheduleId,
            startDate: CivilDay.fromDateTime(now),
            interval: 1,
            startRelativeTime: RelativeTime(
              dayOffset: 0,
              time: TimeOfDay.fromDateTime(now),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            schedulingPolicy: const FixedCalendarPolicy(),
          ),
        ];
      } else {
        _schedules = [_createDefaultOneOffSchedule()];
      }
      _expandedScheduleIndex = 0;
    }
    _estimatedDurationController.addListener(_onEstimatedDurationChanged);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _showTitleInAppBar.dispose();
    _titleController.dispose();
    _titleFocusNode.dispose();
    _descriptionController.dispose();
    _estimatedDurationController.removeListener(_onEstimatedDurationChanged);
    _estimatedDurationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    final context = _titleFieldKey.currentContext;
    if (context == null) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final position = box.localToGlobal(Offset.zero);

    double appBarHeight = 56.0;
    try {
      appBarHeight = Scaffold.of(this.context).appBarMaxHeight ?? 56.0;
    } catch (_) {}

    final isTitleObscured = position.dy <= appBarHeight;
    if (_showTitleInAppBar.value != isTitleObscured) {
      _showTitleInAppBar.value = isTitleObscured;
    }
  }

  void _onEstimatedDurationChanged() {
    setState(() {});
  }

  OneOffSchedule _createDefaultOneOffSchedule() {
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

    return OneOffSchedule(
      id: TaskScheduleRule.generateId(),
      scheduleId: _taskScheduleId,
      date: civilTomorrow,
      startRelativeTime: RelativeTime(
        dayOffset: diff,
        time: TimeOfDay.fromDateTime(now),
      ),
      dueRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 17, minute: 0),
      ),
    );
  }

  Future<void> _saveTask() async {
    final l10n = context.l10n;
    if (_formKey.currentState!.validate()) {
      if (_schedules.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.scheduleRequiredError)));
        return;
      }

      final minutesText = _estimatedDurationController.text.trim();
      final minutes = minutesText.isNotEmpty ? int.tryParse(minutesText) : null;
      final estimatedDuration = minutes != null
          ? Duration(minutes: minutes)
          : null;

      if (_skipIfNoCapacity && estimatedDuration == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.capacityDependentEffortRequiredError)),
        );
        return;
      }

      setState(() {
        _isSaving = true;
      });

      try {
        final hasRepeating = _schedules.any((s) => s is! OneOffSchedule);
        final firstRepeating =
            _schedules.where((s) => s is! OneOffSchedule).firstOrNull ??
            (_schedules.isNotEmpty ? _schedules.first : null);
        final firstLegacyPolicy =
            firstRepeating?.missedOccurrencePolicy.policy ?? MissedPolicy.stack;

        final mealWorkflowConfig = _isMealWorkflow
            ? MealWorkflowConfig(
                selectTime: RelativeTime(dayOffset: 0, time: _selectTime),
                shopTime: RelativeTime(dayOffset: 0, time: _shopTime),
                prepTime: RelativeTime(dayOffset: 0, time: _prepTime),
              )
            : null;

        final newTask = TaskSchedule(
          id: _taskScheduleId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          schedules: _schedules,
          estimatedDuration: estimatedDuration,
          isMaster:
              hasRepeating &&
              (firstLegacyPolicy == MissedPolicy.stack ||
                  firstLegacyPolicy == MissedPolicy.autoDismiss),
          lastSpawnedDate:
              hasRepeating &&
                  (firstLegacyPolicy == MissedPolicy.stack ||
                      firstLegacyPolicy == MissedPolicy.autoDismiss)
              ? CivilDay.fromDateTime(AppClock.now).addDays(-1)
              : null,
          isFamily: _isFamily,
          familyCompletionMode: _familyCompletionMode,
          priority: _priority,
          cycleId: _cycleId,
          preferredBy: _preferredBy,
          assignedUserId: _assignedUserId,
          skipIfNoCapacity: _skipIfNoCapacity,
          workflowType: _isMealWorkflow ? 'mealWorkflow' : null,
          mealWorkflowConfig: mealWorkflowConfig,
        );

        final repository = ref.read(taskRepositoryProvider);
        if (repository != null) {
          if (widget.taskToEdit != null) {
            final previousSchedule = widget.taskToEdit!;
            final modification = widget.taskToEdit!.edit(
              newTitle: _titleController.text.trim(),
              newDescription: _descriptionController.text.trim(),
              newSchedules: _schedules,
              newEstimatedDuration: estimatedDuration,
              newMissedPolicy: hasRepeating
                  ? firstLegacyPolicy
                  : MissedPolicy.stack,
              newIsMaster:
                  hasRepeating &&
                  (firstLegacyPolicy == MissedPolicy.stack ||
                      firstLegacyPolicy == MissedPolicy.autoDismiss),
              newLastSpawnedDate:
                  widget.taskToEdit!.lastSpawnedDate ??
                  (hasRepeating &&
                          (firstLegacyPolicy == MissedPolicy.stack ||
                              firstLegacyPolicy == MissedPolicy.autoDismiss)
                      ? CivilDay.fromDateTime(AppClock.now).addDays(-1)
                      : null),
              newIsFamily: _isFamily,
              newFamilyCompletionMode: _familyCompletionMode,
              newPriority: _priority,
              newCycleId: _cycleId,
              newPreferredBy: _preferredBy,
              newAssignedUserId: _assignedUserId,
              newWorkflowType: _isMealWorkflow ? 'mealWorkflow' : null,
              newMealWorkflowConfig: mealWorkflowConfig,
              newSkipIfNoCapacity: _skipIfNoCapacity,
            );
            await repository
                .updateTaskSchedule(modification)
                .timeout(
                  CreateTaskScreen.saveTimeout,
                  onTimeout: () => throw Exception(l10n.saveTimeoutError),
                );
            if (mounted) {
              UndoSnackBar.show(
                context: context,
                ref: ref,
                action: UndoEditTaskScheduleAction(
                  message: l10n.taskEditsSaved(previousSchedule.title),
                  previousSchedule: previousSchedule,
                  currentSchedule: modification.newTask,
                ),
                repository: repository,
                undoneLabel: l10n.editsReverted(previousSchedule.title),
              );
              Navigator.pop(context);
            }
          } else {
            await repository
                .addTaskSchedule(newTask)
                .timeout(
                  CreateTaskScreen.saveTimeout,
                  onTimeout: () => throw Exception(l10n.saveTimeoutError),
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

  Widget _buildDetailsCard(BuildContext context, bool readOnly) {
    return TaskBasicInfoSection(
      titleFieldKey: _titleFieldKey,
      titleController: _titleController,
      descriptionController: _descriptionController,
      titleFocusNode: _titleFocusNode,
      readOnly: readOnly,
    );
  }

  String _getHumanizedDuration() {
    final text = _estimatedDurationController.text.trim();
    if (text.isEmpty) return '';
    final minutes = int.tryParse(text);
    if (minutes == null || minutes <= 0) return '';

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (hours > 0) {
      final hourStr = hours == 1 ? '1 hr' : '$hours hrs';
      final minStr = remainingMinutes > 0 ? '$remainingMinutes min' : '';
      return minStr.isEmpty ? '($hourStr)' : '($hourStr $minStr)';
    } else {
      return '($minutes min)';
    }
  }

  Widget _buildEffortAndPriorityCard(
    BuildContext context,
    bool readOnly,
    bool isWide,
  ) {
    final theme = Theme.of(context);

    final presets = [
      (label: '5 min', minutes: 5),
      (label: '15 min', minutes: 15),
      (label: '30 min', minutes: 30),
      (label: '1 hour', minutes: 60),
      (label: '2 hours', minutes: 120),
    ];

    return SizedBox(
      width: double.infinity,
      child: Card(
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
                context.l10n.effortAndPriorityLabel,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            key: const Key('estimated_effort_decrement_button'),
                            icon: const Icon(Icons.remove),
                            onPressed: readOnly
                                ? null
                                : () {
                                    final current =
                                        int.tryParse(
                                          _estimatedDurationController.text
                                              .trim(),
                                        ) ??
                                        0;
                                    if (current > 1) {
                                      final val = current - 5;
                                      final newValue = val < 1 ? 1 : val;
                                      _estimatedDurationController.text =
                                          newValue.toString();
                                    }
                                  },
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            constraints: const BoxConstraints(),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _getHumanizedDuration().isNotEmpty
                                        ? '${context.l10n.estimatedEffortFieldLabel} ${_getHumanizedDuration()}'
                                        : context
                                              .l10n
                                              .estimatedEffortFieldLabel,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      height: 1.1,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 4),
                                  TextFormField(
                                    key: const Key('estimated_effort_field'),
                                    controller: _estimatedDurationController,
                                    enabled: !readOnly,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      height: 1.2,
                                    ),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
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
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            key: const Key('estimated_effort_increment_button'),
                            icon: const Icon(Icons.add),
                            onPressed: readOnly
                                ? null
                                : () {
                                    final current =
                                        int.tryParse(
                                          _estimatedDurationController.text
                                              .trim(),
                                        ) ??
                                        0;
                                    final newValue = current == 0
                                        ? 5
                                        : current + 5;
                                    _estimatedDurationController.text = newValue
                                        .toString();
                                  },
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: presets.map((preset) {
                        final isSelected =
                            _estimatedDurationController.text.trim() ==
                            preset.minutes.toString();
                        return StandardChoiceChip(
                          key: Key('preset_chip_${preset.minutes}'),
                          label: preset.label,
                          selected: isSelected,
                          onSelected: readOnly
                              ? null
                              : (selected) {
                                  if (selected) {
                                    _estimatedDurationController.text = preset
                                        .minutes
                                        .toString();
                                  } else {
                                    _estimatedDurationController.clear();
                                  }
                                },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.estimatedEffortHelper,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.taskPriorityLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
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
              const SizedBox(height: 16),
              CheckboxListTile(
                key: const Key('skip_if_no_capacity_checkbox'),
                title: Text(
                  context.l10n.skipIfNoCapacityLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  context.l10n.skipIfNoCapacityHelper,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                value: _skipIfNoCapacity,
                onChanged: readOnly
                    ? null
                    : (val) {
                        setState(() {
                          _skipIfNoCapacity = val ?? false;
                        });
                      },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFamilyCard(
    BuildContext context,
    bool readOnly,
    List<FamilyMember> members,
    String? currentUserId,
  ) {
    return TaskFamilyAssignmentSection(
      isFamily: _isFamily,
      familyCompletionMode: _familyCompletionMode,
      readOnly: readOnly,
      members: members,
      assignedUserId: _assignedUserId,
      currentUserId: currentUserId,
      onAssignedUserChanged: (userId) {
        setState(() {
          _assignedUserId = userId;
        });
      },
      onFamilyToggled: (selected) {
        setState(() {
          _isFamily = selected;
          if (!selected) {
            _assignedUserId = null;
          }
        });
      },
      onFamilyCompletionModeChanged: (mode) {
        setState(() {
          _familyCompletionMode = mode;
        });
      },
    );
  }

  Widget _buildExperimentalFeaturesCard(BuildContext context, bool readOnly) {
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      child: Card(
        key: const Key('experimental_features_card'),
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
              InkWell(
                key: const Key('experimental_features_header'),
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() {
                    _isExperimentalExpanded = !_isExperimentalExpanded;
                  });
                },
                child: Row(
                  children: [
                    Icon(
                      Icons.science_outlined,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Experimental Features',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Icon(
                      _isExperimentalExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
              if (_isExperimentalExpanded) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Task Workflow',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: [
                    StandardChoiceChip(
                      key: const Key('workflow_standard_chip'),
                      label: 'Standard Task',
                      selected: !_isMealWorkflow,
                      onSelected: readOnly
                          ? null
                          : (selected) {
                              if (selected) {
                                setState(() => _isMealWorkflow = false);
                              }
                            },
                    ),
                    StandardChoiceChip(
                      key: const Key('workflow_meal_chip'),
                      label: 'Meal Planning Workflow',
                      selected: _isMealWorkflow,
                      onSelected: readOnly
                          ? null
                          : (selected) {
                              if (selected) {
                                setState(() {
                                  _isMealWorkflow = true;
                                  if (_titleController.text.trim().isEmpty) {
                                    _titleController.text = 'Dinner';
                                  }
                                });
                              }
                            },
                    ),
                  ],
                ),
                if (_isMealWorkflow) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Coordinates dinner across 3 stages: selecting a recipe, checking shopping list, and cooking instructions.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Stage Target Times',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: readOnly
                              ? null
                              : () async {
                                  final t = await showTimePicker(
                                    context: context,
                                    initialTime: _selectTime,
                                  );
                                  if (t != null) {
                                    setState(() => _selectTime = t);
                                  }
                                },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '1. Select',
                                style: TextStyle(fontSize: 10),
                              ),
                              Text(
                                _selectTime.format(context),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: readOnly
                              ? null
                              : () async {
                                  final t = await showTimePicker(
                                    context: context,
                                    initialTime: _shopTime,
                                  );
                                  if (t != null) {
                                    setState(() => _shopTime = t);
                                  }
                                },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '2. Shop',
                                style: TextStyle(fontSize: 10),
                              ),
                              Text(
                                _shopTime.format(context),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: readOnly
                              ? null
                              : () async {
                                  final t = await showTimePicker(
                                    context: context,
                                    initialTime: _prepTime,
                                  );
                                  if (t != null) {
                                    setState(() => _prepTime = t);
                                  }
                                },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '3. Prep',
                                style: TextStyle(fontSize: 10),
                              ),
                              Text(
                                _prepTime.format(context),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleSection(
    BuildContext context,
    bool readOnly,
    List<TaskInstance> dbInstances,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                        _schedules.add(_createDefaultOneOffSchedule());
                        _expandedScheduleIndex = _schedules.length - 1;
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n.addScheduleButton),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpawnedInstancesList(
    BuildContext context,
    List<TaskInstance> dbInstances,
  ) {
    return SpawnedInstancesList(
      task: TaskSchedule(
        id: _taskScheduleId,
        title: _titleController.text.isEmpty
            ? 'Untitled'
            : _titleController.text,
        description: _descriptionController.text,
        schedules: _schedules,
        isFamily: _isFamily,
        priority: _priority,
        cycleId: _cycleId,
        assignedUserId: _assignedUserId,
      ),
      dbInstances: dbInstances,
      now: AppClock.now,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authStateProvider).valueOrNull?.uid;
    final familyRepo = ref.watch(familyRepositoryProvider);
    final instancesVal = ref.watch(taskInstancesProvider);
    final dbInstances =
        instancesVal.value
            ?.where((inst) => inst.scheduleId == _taskScheduleId)
            .toList() ??
        const <TaskInstance>[];
    return StreamBuilder<FamilyProfile>(
      stream: familyRepo?.getProfile() ?? const Stream.empty(),
      builder: (context, snapshot) {
        final profile =
            snapshot.data ?? const FamilyProfile(familyId: '', familyRole: '');
        final familyId = profile.familyId;
        final familyRole = profile.familyRole;
        final inFamily = familyId.isNotEmpty;
        final isParent = familyRole == FamilyRole.parent.value;

        final familyAsync = inFamily
            ? ref.watch(familyStreamProvider(familyId))
            : null;
        final members =
            (familyAsync?.valueOrNull?.members.values.toList() ??
                  <FamilyMember>[])
              ..sort(
                (a, b) => a.displayName.toLowerCase().compareTo(
                  b.displayName.toLowerCase(),
                ),
              );

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
                title: AnimatedBuilder(
                  animation: Listenable.merge([
                    _titleController,
                    _showTitleInAppBar,
                  ]),
                  builder: (context, _) {
                    final currentTitle = _titleController.text;
                    final showTitle = _showTitleInAppBar.value;
                    final String displayTitle;
                    final Key textKey;
                    if (showTitle && currentTitle.isNotEmpty) {
                      displayTitle = currentTitle;
                      textKey = const ValueKey('scrolled_title');
                    } else {
                      textKey = const ValueKey('default_title');
                      if (readOnly) {
                        displayTitle = context.l10n.viewTaskTitle;
                      } else if (widget.taskToEdit != null) {
                        displayTitle = context.l10n.editTaskTitle;
                      } else {
                        displayTitle = context.l10n.newTaskTitle;
                      }
                    }
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                            final isDefault =
                                child.key == const ValueKey('default_title');
                            final beginOffset = isDefault
                                ? const Offset(0.0, -0.2)
                                : const Offset(0.0, 0.2);
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: beginOffset,
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                      child: Text(
                        displayTitle,
                        key: textKey,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.help_outline),
                    tooltip: context.l10n.helpTooltip,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const HelpScreen(initialIndex: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
              body: LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth >= 800;

                  final detailsCard = _buildDetailsCard(context, readOnly);
                  final experimentalFeaturesCard =
                      _buildExperimentalFeaturesCard(context, readOnly);
                  final scheduleSection = _buildScheduleSection(
                    context,
                    readOnly,
                    dbInstances,
                  );
                  final effortAndPriorityCard = _buildEffortAndPriorityCard(
                    context,
                    readOnly,
                    isDesktop,
                  );
                  final familyCard = _buildFamilyCard(
                    context,
                    readOnly,
                    members,
                    currentUserId,
                  );

                  return Column(
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
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.all(16.0),
                          child: Form(
                            key: _formKey,
                            child: isDesktop
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      detailsCard,
                                      const SizedBox(height: 16),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(child: scheduleSection),
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
                                                const SizedBox(height: 16),
                                                experimentalFeaturesCard,
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_schedules.isNotEmpty) ...[
                                        const SizedBox(height: 24),
                                        _buildSpawnedInstancesList(
                                          context,
                                          dbInstances,
                                        ),
                                      ],
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      detailsCard,
                                      const SizedBox(height: 16),
                                      scheduleSection,
                                      const SizedBox(height: 16),
                                      effortAndPriorityCard,
                                      if (inFamily) ...[
                                        const SizedBox(height: 16),
                                        familyCard,
                                      ],
                                      const SizedBox(height: 16),
                                      experimentalFeaturesCard,
                                      if (_schedules.isNotEmpty) ...[
                                        const SizedBox(height: 24),
                                        _buildSpawnedInstancesList(
                                          context,
                                          dbInstances,
                                        ),
                                      ],
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
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
                                onPressed: (_isSaving || readOnly)
                                    ? null
                                    : _saveTask,
                                child: _isSaving
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          value:
                                              CreateTaskScreen
                                                  .debugDisableAnimations
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
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
