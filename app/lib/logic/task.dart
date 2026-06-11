import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'civil_day.dart';
import 'relative_time.dart';
import 'task_delta.dart';

import 'missed_policy.dart';
import 'task_priority.dart';
import 'daily_occurrence_time.dart';
import 'task_schedule.dart';

export 'missed_policy.dart';
export 'task_priority.dart';
export 'daily_occurrence_time.dart';
export 'task_schedule.dart';

/// Result of a task update operation.
typedef TaskModification = ({Task newTask, TaskDelta delta});

/// Represents a single task in the todo list.
class Task {
  /// Unique identifier for the task.
  String id;

  /// The title of the task.
  String title;

  /// Detailed description of the task.
  String description;

  /// The start relative time.
  RelativeTime startRelativeTime;

  /// The due relative time.
  RelativeTime dueRelativeTime;

  /// The recurrence schedule for the task.
  TaskSchedule schedule;

  /// The list of daily occurrence times for tasks scheduled multiple times per day.
  List<DailyOccurrenceTime> dailyTimes;

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

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.startRelativeTime,
    required this.dueRelativeTime,
    required this.schedule,
    this.dailyTimes = const [],
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
    final startDateTime = startRelativeTime.referenceTo(schedule.scheduledDate);
    return CivilDay.fromDateTime(startDateTime);
  }

  factory Task.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot, [
    SnapshotOptions? options,
  ]) {
    final data = snapshot.data();
    if (data == null) {
      throw Exception('Data is null for document ${snapshot.id}');
    }
    final dailyTimesRaw = data['dailyTimes'] as List<dynamic>?;
    final dailyTimes = dailyTimesRaw != null
        ? dailyTimesRaw
              .map(
                (item) =>
                    DailyOccurrenceTime.fromJson(item as Map<String, dynamic>),
              )
              .toList()
        : <DailyOccurrenceTime>[];

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

    return Task(
      id: snapshot.id,
      title: data['title'] as String? ?? 'Untitled',
      description: data['description'] as String? ?? '',
      startRelativeTime: RelativeTime.fromJson(
        data['startRelativeTime'] as Map<String, dynamic>,
      ),
      dueRelativeTime: RelativeTime.fromJson(
        data['dueRelativeTime'] as Map<String, dynamic>,
      ),
      schedule: TaskSchedule.fromJson(data['schedule'] as Map<String, dynamic>),
      dailyTimes: dailyTimes,
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
      'startRelativeTime': startRelativeTime.toJson(),
      'dueRelativeTime': dueRelativeTime.toJson(),
      'schedule': schedule.toJson(),
      'dailyTimes': dailyTimes.map((t) => t.toJson()).toList(),
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

  static final _uuid = Uuid();

  /// Updates multiple fields of the task and returns the modified task and delta.
  TaskModification edit({
    required String newTitle,
    required String newDescription,
    required RelativeTime newStartRelativeTime,
    required RelativeTime newDueRelativeTime,
    required TaskSchedule newSchedule,
    required List<DailyOccurrenceTime> newDailyTimes,
    required Duration? newEstimatedDuration,
    required String userId,
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
      startRelativeTime: newStartRelativeTime,
      dueRelativeTime: newDueRelativeTime,
      schedule: newSchedule,
      dailyTimes: newDailyTimes,
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
    if (newStartRelativeTime != startRelativeTime) {
      changes['startRelativeTime'] = newStartRelativeTime.toJson();
    }
    if (newDueRelativeTime != dueRelativeTime) {
      changes['dueRelativeTime'] = newDueRelativeTime.toJson();
    }

    final oldScheduleJson = schedule.toJson();
    final newScheduleJson = newSchedule.toJson();
    if (oldScheduleJson.toString() != newScheduleJson.toString()) {
      changes['schedule'] = newScheduleJson;
    }

    final oldDailyTimesJson = dailyTimes
        .map((t) => t.toJson())
        .toList()
        .toString();
    final newDailyTimesJson = newDailyTimes
        .map((t) => t.toJson())
        .toList()
        .toString();
    if (oldDailyTimesJson != newDailyTimesJson) {
      changes['dailyTimes'] = newDailyTimes.map((t) => t.toJson()).toList();
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

    final now = AppClock.now;
    final delta = TaskDelta(
      id: _uuid.v4(),
      taskId: id,
      timestamp: now,
      expiresAt: now.add(const Duration(days: 90)),
      operation: 'update',
      changedFields: changes,
      userId: userId,
    );

    return (newTask: newTask, delta: delta);
  }

  /// Updates the title and returns the modified task and delta.
  TaskModification updateTitle(String newTitle, String userId) {
    final newTask = _copyWith(title: newTitle);
    final delta = _createUpdateDelta(
      field: 'title',
      newValue: newTitle,
      userId: userId,
    );
    return (newTask: newTask, delta: delta);
  }

  /// Updates the description and returns the modified task and delta.
  TaskModification updateDescription(String newDescription, String userId) {
    final newTask = _copyWith(description: newDescription);
    final delta = _createUpdateDelta(
      field: 'description',
      newValue: newDescription,
      userId: userId,
    );
    return (newTask: newTask, delta: delta);
  }

  /// Updates the schedule and returns the modified task and delta.
  TaskModification reschedule(TaskSchedule newSchedule, String userId) {
    final newTask = _copyWith(schedule: newSchedule);
    final delta = _createUpdateDelta(
      field: 'schedule',
      newValue: newSchedule.toJson(),
      userId: userId,
    );
    return (newTask: newTask, delta: delta);
  }

  /// Updates the start relative time and returns the modified task and delta.
  TaskModification updateStart(RelativeTime newStart, String userId) {
    final newTask = _copyWith(startRelativeTime: newStart);
    final delta = _createUpdateDelta(
      field: 'startRelativeTime',
      newValue: newStart.toJson(),
      userId: userId,
    );
    return (newTask: newTask, delta: delta);
  }

  /// Updates the due relative time and returns the modified task and delta.
  TaskModification updateDue(RelativeTime newDue, String userId) {
    final newTask = _copyWith(dueRelativeTime: newDue);
    final delta = _createUpdateDelta(
      field: 'dueRelativeTime',
      newValue: newDue.toJson(),
      userId: userId,
    );
    return (newTask: newTask, delta: delta);
  }

  /// Updates the cycle ID and returns the modified task and delta.
  TaskModification updateCycleId(String? newCycleId, String userId) {
    final newTask = _copyWith(
      cycleId: newCycleId,
      clearCycleId: newCycleId == null,
    );
    final delta = _createUpdateDelta(
      field: 'cycleId',
      newValue: newCycleId,
      userId: userId,
    );
    return (newTask: newTask, delta: delta);
  }

  /// Updates the assigned user ID and returns the modified task and delta.
  TaskModification updateAssignedUserId(
    String? newAssignedUserId,
    String userId,
  ) {
    final newTask = _copyWith(
      assignedUserId: newAssignedUserId,
      clearAssignedUserId: newAssignedUserId == null,
    );
    final delta = _createUpdateDelta(
      field: 'assignedUserId',
      newValue: newAssignedUserId,
      userId: userId,
    );
    return (newTask: newTask, delta: delta);
  }

  /// Updates the preferredBy map and returns the modified task and delta.
  TaskModification updatePreferredBy(
    Map<String, bool> newPreferredBy,
    String userId,
  ) {
    final newTask = _copyWith(preferredBy: newPreferredBy);
    final delta = _createUpdateDelta(
      field: 'preferredBy',
      newValue: newPreferredBy,
      userId: userId,
    );
    return (newTask: newTask, delta: delta);
  }

  Task _copyWith({
    String? title,
    String? description,
    RelativeTime? startRelativeTime,
    RelativeTime? dueRelativeTime,
    TaskSchedule? schedule,
    List<DailyOccurrenceTime>? dailyTimes,
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
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      startRelativeTime: startRelativeTime ?? this.startRelativeTime,
      dueRelativeTime: dueRelativeTime ?? this.dueRelativeTime,
      schedule: schedule ?? this.schedule,
      dailyTimes: dailyTimes ?? this.dailyTimes,
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

  TaskDelta _createUpdateDelta({
    required String field,
    required dynamic newValue,
    required String userId,
  }) {
    final now = AppClock.now;
    return TaskDelta(
      id: _uuid.v4(),
      taskId: id,
      timestamp: now,
      expiresAt: now.add(const Duration(days: 90)),
      operation: 'update',
      changedFields: {field: newValue},
      userId: userId,
    );
  }

  /// Checks if the task is overdue at [current] time.
  bool isOverdue(DateTime current) {
    final dueDateTime = dueRelativeTime.referenceTo(schedule.scheduledDate);
    return current.isAfter(dueDateTime);
  }
}
