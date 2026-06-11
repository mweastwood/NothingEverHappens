import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'civil_day.dart';
import 'relative_time.dart';
import 'task_delta.dart';
import 'package:flutter/material.dart';

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

  /// The list of recurrence schedules for the task.
  List<TaskSchedule> schedules;

  /// Backwards compatibility getters for start/due relative times
  RelativeTime get startRelativeTime => schedules.isNotEmpty
      ? schedules[activeOccurrenceIndex < schedules.length
                ? activeOccurrenceIndex
                : 0]
            .startRelativeTime
      : const RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 9, minute: 0));

  RelativeTime get dueRelativeTime => schedules.isNotEmpty
      ? schedules[activeOccurrenceIndex < schedules.length
                ? activeOccurrenceIndex
                : 0]
            .dueRelativeTime
      : const RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 17, minute: 0));

  /// Backwards compatibility getter for schedule
  TaskSchedule get schedule => schedules.isNotEmpty
      ? schedules[activeOccurrenceIndex < schedules.length
            ? activeOccurrenceIndex
            : 0]
      : OneOffSchedule(
          date: CivilDay.fromDateTime(DateTime.now()),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
        );

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
    List<TaskSchedule>? schedules,
    // Deprecated compatibility arguments
    RelativeTime? startRelativeTime,
    RelativeTime? dueRelativeTime,
    TaskSchedule? schedule,
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
  }) : schedules =
           schedules ??
           _migrateSchedules(
             schedule: schedule,
             dailyTimes: dailyTimes,
             startRelativeTime: startRelativeTime,
             dueRelativeTime: dueRelativeTime,
           );

  static List<TaskSchedule> _migrateSchedules({
    TaskSchedule? schedule,
    List<DailyOccurrenceTime> dailyTimes = const [],
    RelativeTime? startRelativeTime,
    RelativeTime? dueRelativeTime,
  }) {
    if (schedule != null) {
      final start = startRelativeTime ?? schedule.startRelativeTime;
      final due = dueRelativeTime ?? schedule.dueRelativeTime;
      if (dailyTimes.isNotEmpty) {
        return dailyTimes.map((dt) {
          return schedule.copyWithTiming(
            startRelativeTime: RelativeTime(dayOffset: 0, time: dt.startTime),
            dueRelativeTime: RelativeTime(dayOffset: 0, time: dt.dueTime),
            notificationRelativeTime: dt.notificationTime != null
                ? RelativeTime(dayOffset: 0, time: dt.notificationTime!)
                : null,
          );
        }).toList();
      } else {
        return [
          schedule.copyWithTiming(
            startRelativeTime: start,
            dueRelativeTime: due,
          ),
        ];
      }
    }
    return [
      OneOffSchedule(
        date: CivilDay.fromDateTime(DateTime.now()),
        startRelativeTime:
            startRelativeTime ??
            const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
        dueRelativeTime:
            dueRelativeTime ??
            const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
      ),
    ];
  }

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

    // Load schedules or migrate
    final List<TaskSchedule> schedules;
    final schedulesRaw = data['schedules'] as List<dynamic>?;
    if (schedulesRaw != null) {
      schedules = schedulesRaw
          .map((item) => TaskSchedule.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      // Migrate from single schedule
      final singleScheduleJson = data['schedule'] as Map<String, dynamic>?;
      if (singleScheduleJson != null) {
        final startRel = data['startRelativeTime'] != null
            ? RelativeTime.fromJson(
                data['startRelativeTime'] as Map<String, dynamic>,
              )
            : const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 9, minute: 0),
              );
        final dueRel = data['dueRelativeTime'] != null
            ? RelativeTime.fromJson(
                data['dueRelativeTime'] as Map<String, dynamic>,
              )
            : const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 17, minute: 0),
              );

        if (dailyTimes.isNotEmpty) {
          schedules = [];
          for (final dailyTime in dailyTimes) {
            final scheduleJson = Map<String, dynamic>.from(singleScheduleJson);
            scheduleJson['startRelativeTime'] = RelativeTime(
              dayOffset: 0,
              time: dailyTime.startTime,
            ).toJson();
            scheduleJson['dueRelativeTime'] = RelativeTime(
              dayOffset: 0,
              time: dailyTime.dueTime,
            ).toJson();
            if (dailyTime.notificationTime != null) {
              scheduleJson['notificationRelativeTime'] = RelativeTime(
                dayOffset: 0,
                time: dailyTime.notificationTime!,
              ).toJson();
            }
            schedules.add(TaskSchedule.fromJson(scheduleJson));
          }
        } else {
          final scheduleJson = Map<String, dynamic>.from(singleScheduleJson);
          scheduleJson['startRelativeTime'] = startRel.toJson();
          scheduleJson['dueRelativeTime'] = dueRel.toJson();
          schedules = [TaskSchedule.fromJson(scheduleJson)];
        }
      } else {
        schedules = [
          OneOffSchedule(
            date: CivilDay.fromDateTime(DateTime.now()),
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
          ),
        ];
      }
    }

    return Task(
      id: snapshot.id,
      title: data['title'] as String? ?? 'Untitled',
      description: data['description'] as String? ?? '',
      schedules: schedules,
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
      'schedules': schedules.map((s) => s.toJson()).toList(),
      // Backwards compatibility fields
      'schedule': schedule.toJson(),
      'startRelativeTime': startRelativeTime.toJson(),
      'dueRelativeTime': dueRelativeTime.toJson(),
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
    List<TaskSchedule>? newSchedules,
    // Deprecated params for compatibility
    TaskSchedule? newSchedule,
    List<DailyOccurrenceTime>? newDailyTimes,
    RelativeTime? newStartRelativeTime,
    RelativeTime? newDueRelativeTime,
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
    final finalSchedules =
        newSchedules ??
        (newSchedule != null
            ? [
                newSchedule.copyWithTiming(
                  startRelativeTime:
                      newStartRelativeTime ?? newSchedule.startRelativeTime,
                  dueRelativeTime:
                      newDueRelativeTime ?? newSchedule.dueRelativeTime,
                ),
              ]
            : schedules);

    final newTask = _copyWith(
      title: newTitle,
      description: newDescription,
      schedules: finalSchedules,
      dailyTimes: newDailyTimes ?? dailyTimes,
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
    final newSchedulesJson = finalSchedules
        .map((s) => s.toJson())
        .toList()
        .toString();
    if (oldSchedulesJson != newSchedulesJson) {
      changes['schedules'] = finalSchedules.map((s) => s.toJson()).toList();
    }

    if (newStartRelativeTime != null &&
        newStartRelativeTime != startRelativeTime) {
      changes['startRelativeTime'] = newStartRelativeTime.toJson();
    }
    if (newDueRelativeTime != null && newDueRelativeTime != dueRelativeTime) {
      changes['dueRelativeTime'] = newDueRelativeTime.toJson();
    }
    if (newSchedule != null) {
      final oldScheduleJson = schedule.toJson();
      final newScheduleJson = newSchedule.toJson();
      if (oldScheduleJson.toString() != newScheduleJson.toString()) {
        changes['schedule'] = newScheduleJson;
      }
    }
    if (newDailyTimes != null) {
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
  TaskModification reschedule(List<TaskSchedule> newSchedules, String userId) {
    final newTask = _copyWith(schedules: newSchedules);
    final delta = _createUpdateDelta(
      field: 'schedules',
      newValue: newSchedules.map((s) => s.toJson()).toList(),
      userId: userId,
    );
    return (newTask: newTask, delta: delta);
  }

  /// Updates the start relative time and returns the modified task and delta.
  TaskModification updateStart(RelativeTime newStart, String userId) {
    if (schedules.isEmpty) {
      return (
        newTask: this,
        delta: _createUpdateDelta(
          field: 'schedules',
          newValue: [],
          userId: userId,
        ),
      );
    }
    final updatedFirst = schedules.first.copyWithTiming(
      startRelativeTime: newStart,
    );
    final newSchedules = [updatedFirst, ...schedules.skip(1)];
    final newTask = _copyWith(schedules: newSchedules);
    final delta = _createUpdateDelta(
      field: 'schedules',
      newValue: newSchedules.map((s) => s.toJson()).toList(),
      userId: userId,
    );
    return (newTask: newTask, delta: delta);
  }

  /// Updates the due relative time and returns the modified task and delta.
  TaskModification updateDue(RelativeTime newDue, String userId) {
    if (schedules.isEmpty) {
      return (
        newTask: this,
        delta: _createUpdateDelta(
          field: 'schedules',
          newValue: [],
          userId: userId,
        ),
      );
    }
    final updatedFirst = schedules.first.copyWithTiming(
      dueRelativeTime: newDue,
    );
    final newSchedules = [updatedFirst, ...schedules.skip(1)];
    final newTask = _copyWith(schedules: newSchedules);
    final delta = _createUpdateDelta(
      field: 'schedules',
      newValue: newSchedules.map((s) => s.toJson()).toList(),
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
    List<TaskSchedule>? schedules,
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
      schedules: schedules ?? this.schedules,
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
