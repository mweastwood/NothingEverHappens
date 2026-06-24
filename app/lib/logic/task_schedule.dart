import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:uuid/uuid.dart';
import 'civil_day.dart';
import 'relative_time.dart';
import 'task_priority.dart';
import 'task_schedule_rule.dart';
import 'scheduling_policy.dart';
import 'missed_occurrence_policy.dart';

export 'task_priority.dart';
export 'daily_occurrence_time.dart';
export 'task_schedule_rule.dart';
export 'scheduling_policy.dart';
export 'missed_occurrence_policy.dart';

/// Result of a task update operation.
typedef TaskModification = ({
  TaskSchedule newTask,
  Map<String, dynamic> changes,
});

/// Represents a single task in the todo list.
class TaskSchedule {
  static String generateId() => 'S-${const Uuid().v4()}';

  /// Unique identifier for the task.
  final String id;

  /// The title of the task.
  final String title;

  /// Detailed description of the task.
  final String description;

  /// The schedule rules associated with this task.
  final List<TaskScheduleRule> schedules;

  /// Legacy getter for schedulingPolicy
  SchedulingPolicy get schedulingPolicy {
    if (schedules.isEmpty) return const FixedCalendarPolicy();
    return schedules.first.schedulingPolicy;
  }

  /// Legacy getter for missedOccurrencePolicy
  MissedOccurrencePolicy get missedOccurrencePolicy {
    if (schedules.isEmpty) return const MissedOccurrencePolicy.stack();
    return schedules.first.missedOccurrencePolicy;
  }

  /// Legacy getter for missedPolicy
  MissedPolicy get missedPolicy {
    if (schedules.isEmpty) return MissedPolicy.stack;
    return schedules.first.missedOccurrencePolicy.policy;
  }

  /// The index of the currently active occurrence time in [dailyTimes].
  final int activeOccurrenceIndex;

  /// The estimated effort for the task (optional).
  final Duration? estimatedDuration;

  /// Whether this task represents a master/template recurring schedule.
  final bool isMaster;

  /// The date up to which stack occurrences have been spawned.
  final CivilDay? lastSpawnedDate;

  /// If this task is a spawned occurrence of a master task, this is the parent task's ID.
  final String? parentTaskId;

  /// Whether this task is shared with the family.
  final bool isFamily;

  /// The priority of the task.
  final TaskPriority priority;

  /// The cycle this task is scheduled for (null if in backlog).
  final String? cycleId;

  /// Map of user IDs to starring preference (true if starred).
  final Map<String, bool> preferredBy;

  /// The ID of the user assigned to this task (null if unassigned).
  final String? assignedUserId;

  TaskSchedule({
    required String id,
    required this.title,
    required this.description,
    List<TaskScheduleRule>? schedules,
    this.activeOccurrenceIndex = 0,
    this.estimatedDuration,
    this.isMaster = false,
    this.lastSpawnedDate,
    this.parentTaskId,
    this.isFamily = false,
    this.priority = TaskPriority.medium,
    this.cycleId,
    this.preferredBy = const {},
    this.assignedUserId,
    SchedulingPolicy? schedulingPolicy,
    MissedOccurrencePolicy? missedOccurrencePolicy,
    MissedPolicy? missedPolicy,
  }) : id = id.startsWith('S-') ? id : 'S-$id',
       schedules = (schedules ?? []).map((s) {
         final sPolicy = schedulingPolicy ?? s.schedulingPolicy;
         final mPolicy =
             missedOccurrencePolicy ??
             (missedPolicy != null
                 ? (missedPolicy == MissedPolicy.autoDismiss
                       ? const MissedOccurrencePolicy.autoDismiss(
                           gracePeriod: Duration(days: 1),
                         )
                       : MissedOccurrencePolicy(policy: missedPolicy))
                 : s.missedOccurrencePolicy);
         final resolvedId = id.startsWith('S-') ? id : 'S-$id';
         return s.copyWithTiming(
           id: s.id.startsWith('R-') ? s.id : TaskScheduleRule.generateId(),
           scheduleId: resolvedId,
           schedulingPolicy: sPolicy,
           missedOccurrencePolicy: mPolicy,
         );
       }).toList();

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

    final schedulesRaw = data['schedules'] as List<dynamic>? ?? [];
    final schedules = schedulesRaw
        .map((item) => TaskScheduleRule.fromJson(item as Map<String, dynamic>))
        .toList();

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

    return TaskSchedule(
      id: snapshot.id,
      title: data['title'] as String? ?? 'Untitled',
      description: data['description'] as String? ?? '',
      schedules: schedules,
      activeOccurrenceIndex: data['activeOccurrenceIndex'] as int? ?? 0,
      estimatedDuration: data['estimatedDuration'] != null
          ? Duration(minutes: data['estimatedDuration'] as int)
          : null,
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
    SchedulingPolicy? newSchedulingPolicy,
    MissedOccurrencePolicy? newMissedOccurrencePolicy,
  }) {
    final resolvedSchedules = newSchedules.map((s) {
      final sPolicy = newSchedulingPolicy ?? s.schedulingPolicy;
      MissedOccurrencePolicy mPolicy;
      if (newMissedOccurrencePolicy != null) {
        mPolicy = newMissedOccurrencePolicy;
      } else {
        final resolvedNewPolicy = newMissedPolicy;
        final legacyMatchesNew =
            s.missedOccurrencePolicy.policy == resolvedNewPolicy;

        if (legacyMatchesNew) {
          mPolicy = s.missedOccurrencePolicy;
        } else {
          mPolicy = newMissedPolicy == MissedPolicy.autoDismiss
              ? const MissedOccurrencePolicy.autoDismiss(
                  gracePeriod: Duration(days: 1),
                )
              : MissedOccurrencePolicy(policy: newMissedPolicy);
        }
      }
      return s.copyWithTiming(
        id: s.id.startsWith('R-') ? s.id : TaskScheduleRule.generateId(),
        scheduleId: id,
        schedulingPolicy: sPolicy,
        missedOccurrencePolicy: mPolicy,
      );
    }).toList();

    final newTask = _copyWith(
      title: newTitle,
      description: newDescription,
      schedules: resolvedSchedules,
      estimatedDuration: newEstimatedDuration,
      clearEstimatedDuration: newEstimatedDuration == null,
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
    final newSchedulesJson = resolvedSchedules
        .map((s) => s.toJson())
        .toList()
        .toString();
    if (oldSchedulesJson != newSchedulesJson) {
      changes['schedules'] = resolvedSchedules.map((s) => s.toJson()).toList();
      if (resolvedSchedules.isNotEmpty) {
        changes['schedulingPolicy'] = resolvedSchedules.first.schedulingPolicy
            .toJson();
        changes['missedOccurrencePolicy'] = resolvedSchedules
            .first
            .missedOccurrencePolicy
            .toJson();
        changes['missedPolicy'] =
            resolvedSchedules.first.missedOccurrencePolicy.policy.name;
      }
    }

    if (estimatedDuration != newEstimatedDuration) {
      changes['estimatedDuration'] = newEstimatedDuration?.inMinutes;
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
      changes: {
        'schedules': newSchedules.map((s) => s.toJson()).toList(),
        if (newSchedules.isNotEmpty)
          'schedulingPolicy': newSchedules.first.schedulingPolicy.toJson(),
      },
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
      changes: {
        'schedules': newSchedules.map((s) => s.toJson()).toList(),
        'schedulingPolicy': newTask.schedulingPolicy.toJson(),
      },
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
      changes: {
        'schedules': newSchedules.map((s) => s.toJson()).toList(),
        'schedulingPolicy': newTask.schedulingPolicy.toJson(),
      },
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
    SchedulingPolicy? schedulingPolicy,
    MissedOccurrencePolicy? missedOccurrencePolicy,
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
      schedulingPolicy: schedulingPolicy,
      missedOccurrencePolicy: missedOccurrencePolicy,
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
    SchedulingPolicy? schedulingPolicy,
    MissedOccurrencePolicy? missedOccurrencePolicy,
  }) {
    final baseSchedules = schedules ?? this.schedules;
    final resolvedSchedules = baseSchedules.map((s) {
      final sPolicy = schedulingPolicy ?? s.schedulingPolicy;
      final mPolicy =
          missedOccurrencePolicy ??
          (missedPolicy != null
              ? (missedPolicy == MissedPolicy.autoDismiss
                    ? const MissedOccurrencePolicy.autoDismiss(
                        gracePeriod: Duration(days: 1),
                      )
                    : MissedOccurrencePolicy(policy: missedPolicy))
              : s.missedOccurrencePolicy);
      return s.copyWithTiming(
        id: s.id.startsWith('R-') ? s.id : TaskScheduleRule.generateId(),
        scheduleId: id,
        schedulingPolicy: sPolicy,
        missedOccurrencePolicy: mPolicy,
      );
    }).toList();

    return TaskSchedule(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      schedules: resolvedSchedules,
      activeOccurrenceIndex:
          activeOccurrenceIndex ?? this.activeOccurrenceIndex,
      estimatedDuration: clearEstimatedDuration
          ? null
          : (estimatedDuration ?? this.estimatedDuration),
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
