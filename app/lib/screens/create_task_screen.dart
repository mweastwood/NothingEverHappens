import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/app_clock.dart';
import '../logic/auth_repository.dart';
import '../logic/civil_day.dart';
import '../logic/create_task_form_notifier.dart';
import '../logic/error_handler.dart';
import '../logic/family.dart';
import '../logic/family_repository.dart';
import '../logic/l10n_extension.dart';
import '../logic/relative_time.dart';
import '../logic/task_instance.dart';
import '../logic/task_repository.dart';
import '../logic/task_schedule.dart';
import '../logic/undo_notifier.dart';
import '../widgets/create_task/task_basic_info_section.dart';
import '../widgets/create_task/task_effort_and_priority_section.dart';
import '../widgets/create_task/task_experimental_workflow_section.dart';
import '../widgets/create_task/task_family_assignment_section.dart';
import '../widgets/create_task/task_schedule_list_section.dart';
import '../widgets/spawned_instances_list.dart';
import '../widgets/undo_snackbar.dart';
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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (widget.taskToEdit != null) {
      final task = widget.taskToEdit!;
      _titleController.text = task.title;
      _descriptionController.text = task.description;
      if (task.estimatedDuration != null) {
        _estimatedDurationController.text = task.estimatedDuration!.inMinutes
            .toString();
      }
    } else if (widget.taskToDuplicate != null) {
      final task = widget.taskToDuplicate!;
      _titleController.text = task.title;
      _descriptionController.text = task.description;
      if (task.estimatedDuration != null) {
        _estimatedDurationController.text = task.estimatedDuration!.inMinutes
            .toString();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _showTitleInAppBar.dispose();
    _titleController.dispose();
    _titleFocusNode.dispose();
    _descriptionController.dispose();
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

  Future<void> _saveTask(
    CreateTaskFormState formState,
    CreateTaskFormNotifier formNotifier,
  ) async {
    final l10n = context.l10n;
    if (_formKey.currentState!.validate()) {
      if (formState.schedules.isEmpty) {
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

      if (formState.skipIfNoCapacity && estimatedDuration == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.capacityDependentEffortRequiredError)),
        );
        return;
      }

      formNotifier.setIsSaving(true);

      try {
        final hasRepeating = formState.schedules.any(
          (s) => s is! OneOffSchedule,
        );
        final firstRepeating =
            formState.schedules
                .where((s) => s is! OneOffSchedule)
                .firstOrNull ??
            (formState.schedules.isNotEmpty ? formState.schedules.first : null);
        final firstLegacyPolicy =
            firstRepeating?.missedOccurrencePolicy.policy ?? MissedPolicy.stack;

        final mealWorkflowConfig = formState.isMealWorkflow
            ? MealWorkflowConfig(
                selectTime: RelativeTime(
                  dayOffset: 0,
                  time: formState.selectTime,
                ),
                shopTime: RelativeTime(dayOffset: 0, time: formState.shopTime),
                prepTime: RelativeTime(dayOffset: 0, time: formState.prepTime),
              )
            : null;

        final newTask = TaskSchedule(
          id: formState.taskScheduleId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          schedules: formState.schedules,
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
          isFamily: formState.isFamily,
          familyCompletionMode: formState.familyCompletionMode,
          priority: formState.priority,
          cycleId: formState.cycleId,
          preferredBy: formState.preferredBy,
          assignedUserId: formState.assignedUserId,
          skipIfNoCapacity: formState.skipIfNoCapacity,
          workflowType: formState.isMealWorkflow ? 'mealWorkflow' : null,
          mealWorkflowConfig: mealWorkflowConfig,
        );

        final repository = ref.read(taskRepositoryProvider);
        if (repository != null) {
          if (widget.taskToEdit != null) {
            final previousSchedule = widget.taskToEdit!;
            final modification = widget.taskToEdit!.edit(
              newTitle: _titleController.text.trim(),
              newDescription: _descriptionController.text.trim(),
              newSchedules: formState.schedules,
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
              newIsFamily: formState.isFamily,
              newFamilyCompletionMode: formState.familyCompletionMode,
              newPriority: formState.priority,
              newCycleId: formState.cycleId,
              newPreferredBy: formState.preferredBy,
              newAssignedUserId: formState.assignedUserId,
              newWorkflowType: formState.isMealWorkflow ? 'mealWorkflow' : null,
              newMealWorkflowConfig: mealWorkflowConfig,
              newSkipIfNoCapacity: formState.skipIfNoCapacity,
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
          formNotifier.setIsSaving(false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = CreateTaskFormArgs(
      taskToEdit: widget.taskToEdit,
      taskToDuplicate: widget.taskToDuplicate,
      defaultToRepeating: widget.defaultToRepeating,
    );
    final formState = ref.watch(createTaskFormNotifierProvider(args));
    final formNotifier = ref.read(
      createTaskFormNotifierProvider(args).notifier,
    );

    final currentUserId = ref.watch(authStateProvider).value?.uid;
    final familyRepo = ref.watch(familyRepositoryProvider);
    final instancesVal = ref.watch(taskInstancesProvider);
    final dbInstances =
        instancesVal.value
            ?.where((inst) => inst.scheduleId == formState.taskScheduleId)
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
            (familyAsync?.value?.members.values.toList() ?? <FamilyMember>[])
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
                    _saveTask(formState, formNotifier);
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

                  final detailsCard = TaskBasicInfoSection(
                    titleFieldKey: _titleFieldKey,
                    titleController: _titleController,
                    descriptionController: _descriptionController,
                    titleFocusNode: _titleFocusNode,
                    readOnly: readOnly,
                  );
                  final experimentalFeaturesCard =
                      TaskExperimentalWorkflowSection(
                        isExperimentalExpanded:
                            formState.isExperimentalExpanded,
                        onToggleExperimentalExpanded:
                            formNotifier.toggleExperimentalExpanded,
                        isMealWorkflow: formState.isMealWorkflow,
                        onMealWorkflowToggled: (isMeal) {
                          formNotifier.setIsMealWorkflow(isMeal);
                          if (isMeal && _titleController.text.trim().isEmpty) {
                            _titleController.text = 'Dinner';
                          }
                        },
                        selectTime: formState.selectTime,
                        onSelectTimeChanged: formNotifier.setSelectTime,
                        shopTime: formState.shopTime,
                        onShopTimeChanged: formNotifier.setShopTime,
                        prepTime: formState.prepTime,
                        onPrepTimeChanged: formNotifier.setPrepTime,
                        readOnly: readOnly,
                      );
                  final scheduleSection = TaskScheduleListSection(
                    schedules: formState.schedules,
                    expandedScheduleIndex: formState.expandedScheduleIndex,
                    onScheduleChanged: formNotifier.updateSchedule,
                    onScheduleDeleted: formNotifier.removeSchedule,
                    onExpansionChanged: (index, expanded) => formNotifier
                        .setExpandedScheduleIndex(expanded ? index : null),
                    onAddSchedule: formNotifier.addSchedule,
                    readOnly: readOnly,
                  );
                  final effortAndPriorityCard = TaskEffortAndPrioritySection(
                    estimatedDurationController: _estimatedDurationController,
                    priority: formState.priority,
                    onPriorityChanged: formNotifier.setPriority,
                    skipIfNoCapacity: formState.skipIfNoCapacity,
                    onSkipIfNoCapacityChanged: formNotifier.setSkipIfNoCapacity,
                    readOnly: readOnly,
                    isWide: isDesktop,
                  );
                  final familyCard = TaskFamilyAssignmentSection(
                    isFamily: formState.isFamily,
                    familyCompletionMode: formState.familyCompletionMode,
                    readOnly: readOnly,
                    members: members,
                    assignedUserId: formState.assignedUserId,
                    currentUserId: currentUserId,
                    onAssignedUserChanged: formNotifier.setAssignedUserId,
                    onFamilyToggled: formNotifier.setFamilyToggled,
                    onFamilyCompletionModeChanged:
                        formNotifier.setFamilyCompletionMode,
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
                                      if (formState.schedules.isNotEmpty) ...[
                                        const SizedBox(height: 24),
                                        SpawnedInstancesList(
                                          task: TaskSchedule(
                                            id: formState.taskScheduleId,
                                            title: _titleController.text.isEmpty
                                                ? 'Untitled'
                                                : _titleController.text,
                                            description:
                                                _descriptionController.text,
                                            schedules: formState.schedules,
                                            isFamily: formState.isFamily,
                                            priority: formState.priority,
                                            cycleId: formState.cycleId,
                                            assignedUserId:
                                                formState.assignedUserId,
                                          ),
                                          dbInstances: dbInstances,
                                          now: AppClock.now,
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
                                      if (formState.schedules.isNotEmpty) ...[
                                        const SizedBox(height: 24),
                                        SpawnedInstancesList(
                                          task: TaskSchedule(
                                            id: formState.taskScheduleId,
                                            title: _titleController.text.isEmpty
                                                ? 'Untitled'
                                                : _titleController.text,
                                            description:
                                                _descriptionController.text,
                                            schedules: formState.schedules,
                                            isFamily: formState.isFamily,
                                            priority: formState.priority,
                                            cycleId: formState.cycleId,
                                            assignedUserId:
                                                formState.assignedUserId,
                                          ),
                                          dbInstances: dbInstances,
                                          now: AppClock.now,
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
                                onPressed: formState.isSaving
                                    ? null
                                    : () => Navigator.pop(context),
                                child: Text(context.l10n.discardButton),
                              ),
                              const SizedBox(width: 16),
                              FilledButton(
                                key: const Key('save_task_button'),
                                onPressed: (formState.isSaving || readOnly)
                                    ? null
                                    : () => _saveTask(formState, formNotifier),
                                child: formState.isSaving
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
