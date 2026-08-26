import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_clock.dart';
import 'civil_day.dart';
import 'relative_time.dart';
import 'task_schedule.dart';

@immutable
class CreateTaskFormState {
  final String taskScheduleId;
  final List<TaskScheduleRule> schedules;
  final int? expandedScheduleIndex;
  final bool isFamily;
  final FamilyCompletionMode familyCompletionMode;
  final TaskPriority priority;
  final String? cycleId;
  final Map<String, bool> preferredBy;
  final String? assignedUserId;
  final bool skipIfNoCapacity;
  final bool isExperimentalExpanded;
  final bool isMealWorkflow;
  final TimeOfDay selectTime;
  final TimeOfDay shopTime;
  final TimeOfDay prepTime;
  final bool isSaving;

  const CreateTaskFormState({
    required this.taskScheduleId,
    required this.schedules,
    this.expandedScheduleIndex,
    this.isFamily = false,
    this.familyCompletionMode = FamilyCompletionMode.anyone,
    this.priority = TaskPriority.medium,
    this.cycleId,
    this.preferredBy = const {},
    this.assignedUserId,
    this.skipIfNoCapacity = false,
    this.isExperimentalExpanded = false,
    this.isMealWorkflow = false,
    this.selectTime = const TimeOfDay(hour: 10, minute: 0),
    this.shopTime = const TimeOfDay(hour: 16, minute: 0),
    this.prepTime = const TimeOfDay(hour: 18, minute: 30),
    this.isSaving = false,
  });

  factory CreateTaskFormState.initial({
    TaskSchedule? taskToEdit,
    TaskSchedule? taskToDuplicate,
    bool defaultToRepeating = false,
  }) {
    if (taskToEdit != null) {
      final task = taskToEdit;
      final isMealWorkflow = task.workflowType == 'mealWorkflow';
      TimeOfDay selectTime = const TimeOfDay(hour: 10, minute: 0);
      TimeOfDay shopTime = const TimeOfDay(hour: 16, minute: 0);
      TimeOfDay prepTime = const TimeOfDay(hour: 18, minute: 30);
      if (task.mealWorkflowConfig != null) {
        selectTime = task.mealWorkflowConfig!.selectTime.time;
        shopTime = task.mealWorkflowConfig!.shopTime.time;
        prepTime = task.mealWorkflowConfig!.prepTime.time;
      }
      final schedules = List<TaskScheduleRule>.from(task.schedules);
      return CreateTaskFormState(
        taskScheduleId: task.id,
        schedules: schedules,
        expandedScheduleIndex: schedules.isNotEmpty ? 0 : null,
        isFamily: task.isFamily,
        familyCompletionMode: task.familyCompletionMode,
        priority: task.priority,
        cycleId: task.cycleId,
        preferredBy: Map<String, bool>.from(task.preferredBy),
        assignedUserId: task.assignedUserId,
        skipIfNoCapacity: task.skipIfNoCapacity,
        isMealWorkflow: isMealWorkflow,
        selectTime: selectTime,
        shopTime: shopTime,
        prepTime: prepTime,
      );
    } else if (taskToDuplicate != null) {
      final task = taskToDuplicate;
      final taskScheduleId = TaskSchedule.generateId();
      final schedules = task.schedules
          .map(
            (s) => s.copyWithTiming(
              id: TaskScheduleRule.generateId(),
              scheduleId: taskScheduleId,
            ),
          )
          .toList();
      return CreateTaskFormState(
        taskScheduleId: taskScheduleId,
        schedules: schedules,
        expandedScheduleIndex: schedules.isNotEmpty ? 0 : null,
        isFamily: task.isFamily,
        familyCompletionMode: task.familyCompletionMode,
        priority: task.priority,
        cycleId: task.cycleId,
        preferredBy: Map<String, bool>.from(task.preferredBy),
        assignedUserId: task.assignedUserId,
        skipIfNoCapacity: task.skipIfNoCapacity,
      );
    } else {
      final taskScheduleId = TaskSchedule.generateId();
      final List<TaskScheduleRule> schedules;
      if (defaultToRepeating) {
        final now = AppClock.now;
        schedules = [
          DailySchedule(
            id: TaskScheduleRule.generateId(),
            scheduleId: taskScheduleId,
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
        schedules = [createDefaultOneOffSchedule(taskScheduleId)];
      }
      return CreateTaskFormState(
        taskScheduleId: taskScheduleId,
        schedules: schedules,
        expandedScheduleIndex: 0,
      );
    }
  }

  static OneOffSchedule createDefaultOneOffSchedule(String taskScheduleId) {
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
      scheduleId: taskScheduleId,
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

  CreateTaskFormState copyWith({
    String? taskScheduleId,
    List<TaskScheduleRule>? schedules,
    Object? expandedScheduleIndex = _undefined,
    bool? isFamily,
    FamilyCompletionMode? familyCompletionMode,
    TaskPriority? priority,
    Object? cycleId = _undefined,
    Map<String, bool>? preferredBy,
    Object? assignedUserId = _undefined,
    bool? skipIfNoCapacity,
    bool? isExperimentalExpanded,
    bool? isMealWorkflow,
    TimeOfDay? selectTime,
    TimeOfDay? shopTime,
    TimeOfDay? prepTime,
    bool? isSaving,
  }) {
    return CreateTaskFormState(
      taskScheduleId: taskScheduleId ?? this.taskScheduleId,
      schedules: schedules ?? this.schedules,
      expandedScheduleIndex: expandedScheduleIndex == _undefined
          ? this.expandedScheduleIndex
          : expandedScheduleIndex as int?,
      isFamily: isFamily ?? this.isFamily,
      familyCompletionMode: familyCompletionMode ?? this.familyCompletionMode,
      priority: priority ?? this.priority,
      cycleId: cycleId == _undefined ? this.cycleId : cycleId as String?,
      preferredBy: preferredBy ?? this.preferredBy,
      assignedUserId: assignedUserId == _undefined
          ? this.assignedUserId
          : assignedUserId as String?,
      skipIfNoCapacity: skipIfNoCapacity ?? this.skipIfNoCapacity,
      isExperimentalExpanded:
          isExperimentalExpanded ?? this.isExperimentalExpanded,
      isMealWorkflow: isMealWorkflow ?? this.isMealWorkflow,
      selectTime: selectTime ?? this.selectTime,
      shopTime: shopTime ?? this.shopTime,
      prepTime: prepTime ?? this.prepTime,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

const Object _undefined = Object();

class CreateTaskFormArgs {
  final TaskSchedule? taskToEdit;
  final TaskSchedule? taskToDuplicate;
  final bool defaultToRepeating;

  const CreateTaskFormArgs({
    this.taskToEdit,
    this.taskToDuplicate,
    this.defaultToRepeating = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateTaskFormArgs &&
          runtimeType == other.runtimeType &&
          taskToEdit?.id == other.taskToEdit?.id &&
          taskToDuplicate?.id == other.taskToDuplicate?.id &&
          defaultToRepeating == other.defaultToRepeating;

  @override
  int get hashCode =>
      Object.hash(taskToEdit?.id, taskToDuplicate?.id, defaultToRepeating);
}

class CreateTaskFormNotifier extends StateNotifier<CreateTaskFormState> {
  CreateTaskFormNotifier({
    TaskSchedule? taskToEdit,
    TaskSchedule? taskToDuplicate,
    bool defaultToRepeating = false,
  }) : super(
         CreateTaskFormState.initial(
           taskToEdit: taskToEdit,
           taskToDuplicate: taskToDuplicate,
           defaultToRepeating: defaultToRepeating,
         ),
       );

  void updateSchedule(int index, TaskScheduleRule newSchedule) {
    final updated = List<TaskScheduleRule>.from(state.schedules);
    if (index >= 0 && index < updated.length) {
      updated[index] = newSchedule;
      state = state.copyWith(schedules: updated);
    }
  }

  void removeSchedule(int index) {
    if (state.schedules.length <= 1) return;
    final updated = List<TaskScheduleRule>.from(state.schedules);
    if (index >= 0 && index < updated.length) {
      updated.removeAt(index);
      int? newExpandedIndex = state.expandedScheduleIndex;
      if (newExpandedIndex == index) {
        newExpandedIndex = null;
      } else if (newExpandedIndex != null && newExpandedIndex > index) {
        newExpandedIndex--;
      }
      state = state.copyWith(
        schedules: updated,
        expandedScheduleIndex: newExpandedIndex,
      );
    }
  }

  void addSchedule() {
    final updated = List<TaskScheduleRule>.from(state.schedules)
      ..add(
        CreateTaskFormState.createDefaultOneOffSchedule(state.taskScheduleId),
      );
    state = state.copyWith(
      schedules: updated,
      expandedScheduleIndex: updated.length - 1,
    );
  }

  void setExpandedScheduleIndex(int? index) {
    state = state.copyWith(expandedScheduleIndex: index);
  }

  void setFamilyToggled(bool isFamily) {
    state = state.copyWith(
      isFamily: isFamily,
      assignedUserId: isFamily ? state.assignedUserId : null,
    );
  }

  void setFamilyCompletionMode(FamilyCompletionMode mode) {
    state = state.copyWith(familyCompletionMode: mode);
  }

  void setAssignedUserId(String? userId) {
    state = state.copyWith(assignedUserId: userId);
  }

  void setPriority(TaskPriority priority) {
    state = state.copyWith(priority: priority);
  }

  void setSkipIfNoCapacity(bool skipIfNoCapacity) {
    state = state.copyWith(skipIfNoCapacity: skipIfNoCapacity);
  }

  void toggleExperimentalExpanded() {
    state = state.copyWith(
      isExperimentalExpanded: !state.isExperimentalExpanded,
    );
  }

  void setIsExperimentalExpanded(bool expanded) {
    state = state.copyWith(isExperimentalExpanded: expanded);
  }

  void setIsMealWorkflow(bool isMealWorkflow) {
    state = state.copyWith(isMealWorkflow: isMealWorkflow);
  }

  void setSelectTime(TimeOfDay selectTime) {
    state = state.copyWith(selectTime: selectTime);
  }

  void setShopTime(TimeOfDay shopTime) {
    state = state.copyWith(shopTime: shopTime);
  }

  void setPrepTime(TimeOfDay prepTime) {
    state = state.copyWith(prepTime: prepTime);
  }

  void setIsSaving(bool isSaving) {
    state = state.copyWith(isSaving: isSaving);
  }

  void setCycleId(String? cycleId) {
    state = state.copyWith(cycleId: cycleId);
  }

  void setPreferredBy(Map<String, bool> preferredBy) {
    state = state.copyWith(preferredBy: preferredBy);
  }
}

final createTaskFormNotifierProvider = StateNotifierProvider.autoDispose
    .family<CreateTaskFormNotifier, CreateTaskFormState, CreateTaskFormArgs>(
      (ref, args) => CreateTaskFormNotifier(
        taskToEdit: args.taskToEdit,
        taskToDuplicate: args.taskToDuplicate,
        defaultToRepeating: args.defaultToRepeating,
      ),
    );
