import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'civil_day.dart';
import 'relative_time.dart';
import 'missed_policy.dart';
import 'task_priority.dart';
import 'task_schedule_rule.dart';

export 'missed_policy.dart';
export 'task_priority.dart';
export 'daily_occurrence_time.dart';
export 'task_schedule_rule.dart';

/// Result of a task update operation.
typedef TaskModification = ({
  TaskSchedule newTask,
  Map<String, dynamic> changes,
});

/// Represents a single task in the todo list.
class TaskSchedule {
  /// Unique identifier for the task.
  String id;

  /// The title of the task.
  String title;

  /// Detailed description of the task.
  String description;

  /// The list of recurrence schedules for the task.
  List<TaskScheduleRule> schedules;

  /// The index of the currently active occurrence time in [dailyTimes].
  int activeOccurrenceIndex;

  /// The estimated effort for the task (optional).
  Duration? estimatedDuration;

  /// The policy to apply when a task occurrence is missed.
  MissedPolicy missedPolicy;

  /// Whether this task represents a master/template recurring schedule.
  bool isMaster;

  /// The date up to which stack occurrences have been spawned.
  CivilDay? lastSpawnedDate;

  /// If this task is a spawned occurrence of a master task, this is the parent task's ID.
  String? parentTaskId;

  /// Whether this task is shared with the family.
  bool isFamily;

  /// The priority of the task.
  TaskPriority priority;

  /// The cycle this task is scheduled for (null if in backlog).
  String? cycleId;

  /// Map of user IDs to starring preference (true if starred).
  Map<String, bool> preferredBy;

  /// The ID of the user assigned to this task (null if unassigned).
  String? assignedUserId;

  TaskSchedule({
    required this.id,
    required this.title,
    required this.description,
    required this.schedules,
    this.activeOccurrenceIndex = 0,
    this.estimatedDuration,
    this.missedPolicy = MissedPolicy.rollover,
    this.isMaster = false,
    this.lastSpawnedDate,
    this.parentTaskId,
    this.isFamily = false,
    this.priority = TaskPriority.medium,
    this.cycleId,
    this.preferredBy = const {},
    this.assignedUserId,
  });

  /// The starting day of this occurrence.
  CivilDay get startDate {
    if (schedules.isEmpty) {
      return CivilDay.fromDateTime(AppClock.now);
    }
    final index =
        activeOccurrenceIndex >= 0 && activeOccurrenceIndex < schedules.length
        ? activeOccurrenceIndex
        : 0;
    final currentSchedule = schedules[index];
    final startDateTime = currentSchedule.startRelativeTime.referenceTo(
      currentSchedule.scheduledDate,
    );
    return CivilDay.fromDateTime(startDateTime);
  }

  factory TaskSchedule.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot, [
    SnapshotOptions? options,
  ]) {
    final data = snapshot.data();
    if (data == null) {
      throw Exception('Data is null for document ${snapshot.id}');
    }

    final missedPolicyStr = data['missedPolicy'] as String? ?? 'rollover';
    final missedPolicy = MissedPolicy.values.firstWhere(
      (e) => e.name == missedPolicyStr,
      orElse: () => MissedPolicy.rollover,
    );

    final isMaster = data['isMaster'] as bool? ?? false;
    final lastSpawnedDateRaw = data['lastSpawnedDate'] as Map<String, dynamic>?;
    final lastSpawnedDate = lastSpawnedDateRaw != null
        ? CivilDay.fromJson(lastSpawnedDateRaw)
        : null;
    final parentTaskId = data['parentTaskId'] as String?;
    final isFamily = data['isFamily'] as bool? ?? false;
    final priorityStr = data['priority'] as String? ?? 'medium';
    final priority = TaskPriority.values.firstWhere(
      (e) => e.name == priorityStr,
      orElse: () => TaskPriority.medium,
    );
    final cycleId = data['cycleId'] as String?;
    final preferredByRaw = data['preferredBy'] as Map<String, dynamic>? ?? {};
    final preferredBy = preferredByRaw.map((k, v) => MapEntry(k, v as bool));
    final assignedUserId = data['assignedUserId'] as String?;

    final schedulesRaw = data['schedules'] as List<dynamic>?;
    final schedules = schedulesRaw != null
        ? schedulesRaw
              .map(
                (item) =>
                    TaskScheduleRule.fromJson(item as Map<String, dynamic>),
              )
              .toList()
        : <TaskScheduleRule>[];

    return TaskSchedule(
      id: snapshot.id,
      title: data['title'] as String? ?? 'Untitled',
      description: data['description'] as String? ?? '',
      schedules: schedules,
      activeOccurrenceIndex: data['activeOccurrenceIndex'] as int? ?? 0,
      estimatedDuration: data['estimatedDuration'] != null
          ? Duration(minutes: data['estimatedDuration'] as int)
          : null,
      missedPolicy: missedPolicy,
      isMaster: isMaster,
      lastSpawnedDate: lastSpawnedDate,
      parentTaskId: parentTaskId,
      isFamily: isFamily,
      priority: priority,
      cycleId: cycleId,
      preferredBy: preferredBy,
      assignedUserId: assignedUserId,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'schedules': schedules.map((s) => s.toJson()).toList(),
      'activeOccurrenceIndex': activeOccurrenceIndex,
      'estimatedDuration': estimatedDuration?.inMinutes,
      'missedPolicy': missedPolicy.name,
      'isMaster': isMaster,
      if (lastSpawnedDate != null) 'lastSpawnedDate': lastSpawnedDate!.toJson(),
      if (parentTaskId != null) 'parentTaskId': parentTaskId,
      'isFamily': isFamily,
      'priority': priority.name,
      if (cycleId != null) 'cycleId': cycleId,
      'preferredBy': preferredBy,
      if (assignedUserId != null) 'assignedUserId': assignedUserId,
    };
  }

  /// Updates multiple fields of the task and returns the modified task and changes.
  TaskModification edit({
    required String newTitle,
    required String newDescription,
    required List<TaskScheduleRule> newSchedules,
    required Duration? newEstimatedDuration,
    required MissedPolicy newMissedPolicy,
    required bool newIsMaster,
    required CivilDay? newLastSpawnedDate,
    required bool newIsFamily,
    required TaskPriority newPriority,
    String? newCycleId,
    Map<String, bool>? newPreferredBy,
    String? newAssignedUserId,
  }) {
    final newTask = _copyWith(
      title: newTitle,
      description: newDescription,
      schedules: newSchedules,
      estimatedDuration: newEstimatedDuration,
      clearEstimatedDuration: newEstimatedDuration == null,
      missedPolicy: newMissedPolicy,
      isMaster: newIsMaster,
      lastSpawnedDate: newLastSpawnedDate,
      clearLastSpawnedDate: newLastSpawnedDate == null,
      isFamily: newIsFamily,
      priority: newPriority,
      cycleId: newCycleId,
      clearCycleId: newCycleId == null,
      preferredBy: newPreferredBy,
      assignedUserId: newAssignedUserId,
      clearAssignedUserId: newAssignedUserId == null,
    );

    final changes = <String, dynamic>{};
    if (newTitle != title) changes['title'] = newTitle;
    if (newDescription != description) changes['description'] = newDescription;

    final oldSchedulesJson = schedules
        .map((s) => s.toJson())
        .toList()
        .toString();
    final newSchedulesJson = newSchedules
        .map((s) => s.toJson())
        .toList()
        .toString();
    if (oldSchedulesJson != newSchedulesJson) {
      changes['schedules'] = newSchedules.map((s) => s.toJson()).toList();
    }

    if (estimatedDuration != newEstimatedDuration) {
      changes['estimatedDuration'] = newEstimatedDuration?.inMinutes;
    }

    if (missedPolicy != newMissedPolicy) {
      changes['missedPolicy'] = newMissedPolicy.name;
    }

    if (isMaster != newIsMaster) {
      changes['isMaster'] = newIsMaster;
    }

    if (lastSpawnedDate != newLastSpawnedDate) {
      changes['lastSpawnedDate'] = newLastSpawnedDate?.toJson();
    }

    if (isFamily != newIsFamily) {
      changes['isFamily'] = newIsFamily;
    }

    if (priority != newPriority) {
      changes['priority'] = newPriority.name;
    }

    if (cycleId != newCycleId) {
      changes['cycleId'] = newCycleId;
    }

    final oldPrefStr = preferredBy.toString();
    final newPrefStr = (newPreferredBy ?? preferredBy).toString();
    if (oldPrefStr != newPrefStr) {
      changes['preferredBy'] = newPreferredBy ?? preferredBy;
    }

    if (assignedUserId != newAssignedUserId) {
      changes['assignedUserId'] = newAssignedUserId;
    }

    return (newTask: newTask, changes: changes);
  }

  /// Updates the title and returns the modified task and changes.
  TaskModification updateTitle(String newTitle) {
    final newTask = _copyWith(title: newTitle);
    return (newTask: newTask, changes: {'title': newTitle});
  }

  /// Updates the description and returns the modified task and changes.
  TaskModification updateDescription(String newDescription) {
    final newTask = _copyWith(description: newDescription);
    return (newTask: newTask, changes: {'description': newDescription});
  }

  /// Updates the schedule and returns the modified task and changes.
  TaskModification reschedule(List<TaskScheduleRule> newSchedules) {
    final newTask = _copyWith(schedules: newSchedules);
    return (
      newTask: newTask,
      changes: {'schedules': newSchedules.map((s) => s.toJson()).toList()},
    );
  }

  /// Updates the start relative time and returns the modified task and changes.
  TaskModification updateStart(RelativeTime newStart) {
    if (schedules.isEmpty) {
      return (newTask: this, changes: {'schedules': []});
    }
    final updatedFirst = schedules.first.copyWithTiming(
      startRelativeTime: newStart,
    );
    final newSchedules = [updatedFirst, ...schedules.skip(1)];
    final newTask = _copyWith(schedules: newSchedules);
    return (
      newTask: newTask,
      changes: {'schedules': newSchedules.map((s) => s.toJson()).toList()},
    );
  }

  /// Updates the due relative time and returns the modified task and changes.
  TaskModification updateDue(RelativeTime newDue) {
    if (schedules.isEmpty) {
      return (newTask: this, changes: {'schedules': []});
    }
    final updatedFirst = schedules.first.copyWithTiming(
      dueRelativeTime: newDue,
    );
    final newSchedules = [updatedFirst, ...schedules.skip(1)];
    final newTask = _copyWith(schedules: newSchedules);
    return (
      newTask: newTask,
      changes: {'schedules': newSchedules.map((s) => s.toJson()).toList()},
    );
  }

  /// Updates the cycle ID and returns the modified task and changes.
  TaskModification updateCycleId(String? newCycleId) {
    final newTask = _copyWith(
      cycleId: newCycleId,
      clearCycleId: newCycleId == null,
    );
    return (newTask: newTask, changes: {'cycleId': newCycleId});
  }

  /// Updates the assigned user ID and returns the modified task and changes.
  TaskModification updateAssignedUserId(String? newAssignedUserId) {
    final newTask = _copyWith(
      assignedUserId: newAssignedUserId,
      clearAssignedUserId: newAssignedUserId == null,
    );
    return (newTask: newTask, changes: {'assignedUserId': newAssignedUserId});
  }

  /// Updates the preferredBy map and returns the modified task and changes.
  TaskModification updatePreferredBy(Map<String, bool> newPreferredBy) {
    final newTask = _copyWith(preferredBy: newPreferredBy);
    return (newTask: newTask, changes: {'preferredBy': newPreferredBy});
  }

  TaskSchedule copyWith({
    String? title,
    String? description,
    List<TaskScheduleRule>? schedules,
    int? activeOccurrenceIndex,
    Duration? estimatedDuration,
    bool clearEstimatedDuration = false,
    MissedPolicy? missedPolicy,
    bool? isMaster,
    CivilDay? lastSpawnedDate,
    bool clearLastSpawnedDate = false,
    String? parentTaskId,
    bool? isFamily,
    TaskPriority? priority,
    String? cycleId,
    bool clearCycleId = false,
    Map<String, bool>? preferredBy,
    String? assignedUserId,
    bool clearAssignedUserId = false,
  }) {
    return _copyWith(
      title: title,
      description: description,
      schedules: schedules,
      activeOccurrenceIndex: activeOccurrenceIndex,
      estimatedDuration: estimatedDuration,
      clearEstimatedDuration: clearEstimatedDuration,
      missedPolicy: missedPolicy,
      isMaster: isMaster,
      lastSpawnedDate: lastSpawnedDate,
      clearLastSpawnedDate: clearLastSpawnedDate,
      parentTaskId: parentTaskId,
      isFamily: isFamily,
      priority: priority,
      cycleId: cycleId,
      clearCycleId: clearCycleId,
      preferredBy: preferredBy,
      assignedUserId: assignedUserId,
      clearAssignedUserId: clearAssignedUserId,
    );
  }

  TaskSchedule _copyWith({
    String? title,
    String? description,
    List<TaskScheduleRule>? schedules,
    int? activeOccurrenceIndex,
    Duration? estimatedDuration,
    bool clearEstimatedDuration = false,
    MissedPolicy? missedPolicy,
    bool? isMaster,
    CivilDay? lastSpawnedDate,
    bool clearLastSpawnedDate = false,
    String? parentTaskId,
    bool? isFamily,
    TaskPriority? priority,
    String? cycleId,
    bool clearCycleId = false,
    Map<String, bool>? preferredBy,
    String? assignedUserId,
    bool clearAssignedUserId = false,
  }) {
    return TaskSchedule(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      schedules: schedules ?? this.schedules,
      activeOccurrenceIndex:
          activeOccurrenceIndex ?? this.activeOccurrenceIndex,
      estimatedDuration: clearEstimatedDuration
          ? null
          : (estimatedDuration ?? this.estimatedDuration),
      missedPolicy: missedPolicy ?? this.missedPolicy,
      isMaster: isMaster ?? this.isMaster,
      lastSpawnedDate: clearLastSpawnedDate
          ? null
          : (lastSpawnedDate ?? this.lastSpawnedDate),
      parentTaskId: parentTaskId ?? this.parentTaskId,
      isFamily: isFamily ?? this.isFamily,
      priority: priority ?? this.priority,
      cycleId: clearCycleId ? null : (cycleId ?? this.cycleId),
      preferredBy: preferredBy ?? this.preferredBy,
      assignedUserId: clearAssignedUserId
          ? null
          : (assignedUserId ?? this.assignedUserId),
    );
  }

  /// Checks if the task is overdue at [current] time.
  bool isOverdue(DateTime current) {
    if (schedules.isEmpty) return false;
    final index =
        activeOccurrenceIndex >= 0 && activeOccurrenceIndex < schedules.length
        ? activeOccurrenceIndex
        : 0;
    final currentSchedule = schedules[index];
    final dueDateTime = currentSchedule.dueRelativeTime.referenceTo(
      currentSchedule.scheduledDate,
    );
    return current.isAfter(dueDateTime);
  }
}
