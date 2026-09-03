import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'civil_day.dart';
import 'relative_time.dart';
import 'task_priority.dart';
import 'task_status.dart';
import 'workflows/task_workflow.dart';
import 'family_task_completion_mode.dart';
export 'task_status.dart';
export 'workflows/task_workflow.dart';
export 'family_task_completion_mode.dart';

class TaskInstance {
  static String generateId() => 'I-${const Uuid().v4()}';

  final String id;
  final String scheduleId;
  final String ruleId;
  final String title;
  final String description;
  final CivilDay scheduledDate;
  final RelativeTime startRelativeTime;
  final RelativeTime dueRelativeTime;
  final List<RelativeTime> notificationRelativeTimes;
  final bool isFamily;
  final FamilyCompletionMode familyCompletionMode;
  final TaskPriority priority;
  final String? cycleId;
  final String? assignedUserId;
  final String? completedByUserId;
  final List<String> completedByUserIds;
  final DateTime? completedAt;
  final TaskStatus status;
  final WorkflowInstancePayload? workflowPayload;
  final String? lastModifiedByUserId;
  final String? lastModifiedByAppVersion;
  final String? lastModifiedByPlatform;
  final String? statusReason;

  /// Whether this instance document has pending local writes that have not yet synced to Firestore server.
  final bool hasPendingWrites;

  /// Whether this instance document was retrieved from local offline cache.
  final bool isFromCache;

  /// Timestamp of the last update for sync conflict resolution.
  final DateTime updatedAt;

  TaskInstance({
    String? id,
    required this.scheduleId,
    required this.ruleId,
    required String title,
    required String description,
    required this.scheduledDate,
    required this.startRelativeTime,
    required this.dueRelativeTime,
    List<RelativeTime>? notificationRelativeTimes,
    this.isFamily = false,
    this.familyCompletionMode = FamilyCompletionMode.anyone,
    this.priority = TaskPriority.medium,
    this.cycleId,
    this.assignedUserId,
    this.completedByUserId,
    List<String>? completedByUserIds,
    this.completedAt,
    this.status = TaskStatus.pending,
    this.workflowPayload,
    this.lastModifiedByUserId,
    this.lastModifiedByAppVersion,
    this.lastModifiedByPlatform,
    this.statusReason,
    this.hasPendingWrites = false,
    this.isFromCache = false,
    DateTime? updatedAt,
  }) : id = id ?? TaskInstance.generateId(),
       title = title.trim(),
       description = description.trim(),
       updatedAt = updatedAt ?? DateTime.now(),
       completedByUserIds = completedByUserIds ?? const [],
       notificationRelativeTimes = notificationRelativeTimes ?? const [];

  bool isCompletedForUser(String userId) {
    if (familyCompletionMode == FamilyCompletionMode.individual) {
      return completedByUserIds.contains(userId);
    }
    return status == TaskStatus.completed;
  }

  /// Whether this task was completed after its due date and time.
  bool get isCompletedOverdue {
    if (status != TaskStatus.completed) return false;
    if (completedAt == null) return false;
    final dueDateTime = dueRelativeTime.referenceTo(scheduledDate);
    return completedAt!.isAfter(dueDateTime);
  }

  /// Whether this task was completed more than 24 hours after its due date and time.
  bool get isCompletedOverdueByMoreThan24Hours {
    if (status != TaskStatus.completed) return false;
    if (completedAt == null) return false;
    final dueDateTime = dueRelativeTime.referenceTo(scheduledDate);
    return completedAt!.difference(dueDateTime) > const Duration(hours: 24);
  }

  factory TaskInstance.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot, [
    SnapshotOptions? options,
  ]) {
    final data = snapshot.data();
    if (data == null) {
      throw Exception('Data is null for document ${snapshot.id}');
    }

    final scheduleId = data['scheduleId'] as String? ?? '';
    final ruleId = data['ruleId'] as String? ?? '';
    final title = data['title'] as String? ?? 'Untitled';
    final description = data['description'] as String? ?? '';

    final scheduledDateRaw = data['scheduledDate'] as Map?;
    final scheduledDate = scheduledDateRaw != null
        ? CivilDay.fromJson(Map<String, dynamic>.from(scheduledDateRaw))
        : CivilDay.fromDateTime(DateTime.now());

    final startRelativeTimeRaw = data['startRelativeTime'] as Map?;
    final startRelativeTime = startRelativeTimeRaw != null
        ? RelativeTime.fromJson(Map<String, dynamic>.from(startRelativeTimeRaw))
        : const RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 9, minute: 0));

    final dueRelativeTimeRaw = data['dueRelativeTime'] as Map?;
    final dueRelativeTime = dueRelativeTimeRaw != null
        ? RelativeTime.fromJson(Map<String, dynamic>.from(dueRelativeTimeRaw))
        : const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          );

    List<RelativeTime> notificationRelativeTimes = [];
    if (data['notificationRelativeTimes'] != null) {
      final list = data['notificationRelativeTimes'] as List;
      notificationRelativeTimes = list
          .map(
            (item) =>
                RelativeTime.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } else if (data['notificationRelativeTime'] != null) {
      final notifRaw = data['notificationRelativeTime'] as Map;
      notificationRelativeTimes = [
        RelativeTime.fromJson(Map<String, dynamic>.from(notifRaw)),
      ];
    }

    final isFamily = data['isFamily'] as bool? ?? false;
    final familyCompletionModeStr = data['familyCompletionMode'] as String?;
    final familyCompletionMode = FamilyCompletionMode.fromString(
      familyCompletionModeStr,
    );

    final priorityStr = data['priority'] as String? ?? 'medium';
    final priority = TaskPriority.values.firstWhere(
      (e) => e.name == priorityStr,
      orElse: () => TaskPriority.medium,
    );

    final cycleId = data['cycleId'] as String?;
    final assignedUserId = data['assignedUserId'] as String?;
    final completedByUserId = data['completedByUserId'] as String?;
    final completedByUserIdsRaw =
        data['completedByUserIds'] as List<dynamic>? ?? [];
    final completedByUserIds = completedByUserIdsRaw
        .map((e) => e.toString())
        .toList();

    final completedAtRaw = data['completedAt'];
    DateTime? completedAt;
    if (completedAtRaw != null) {
      if (completedAtRaw is Timestamp) {
        completedAt = completedAtRaw.toDate();
      } else if (completedAtRaw is String) {
        completedAt = DateTime.parse(completedAtRaw);
      } else if (completedAtRaw is int) {
        completedAt = DateTime.fromMillisecondsSinceEpoch(completedAtRaw);
      }
    }

    final statusRaw = data['status'];
    final status = statusRaw is TaskStatus
        ? statusRaw
        : TaskStatus.fromString(statusRaw as String?);

    final updatedAtRaw = data['updatedAt'];
    DateTime? updatedAt;
    if (updatedAtRaw != null) {
      if (updatedAtRaw is Timestamp) {
        updatedAt = updatedAtRaw.toDate();
      } else if (updatedAtRaw is String) {
        updatedAt = DateTime.parse(updatedAtRaw);
      } else if (updatedAtRaw is int) {
        updatedAt = DateTime.fromMillisecondsSinceEpoch(updatedAtRaw);
      } else if (updatedAtRaw is DateTime) {
        updatedAt = updatedAtRaw;
      }
    }

    final workflowPayloadRaw = data['workflowPayload'] as Map?;
    final workflowPayload = workflowPayloadRaw != null
        ? WorkflowInstancePayload.fromJson(
            Map<String, dynamic>.from(workflowPayloadRaw),
          )
        : null;

    final lastModifiedByUserId = data['lastModifiedByUserId'] as String?;
    final lastModifiedByAppVersion =
        data['lastModifiedByAppVersion'] as String?;
    final lastModifiedByPlatform = data['lastModifiedByPlatform'] as String?;
    final statusReason = data['statusReason'] as String?;

    return TaskInstance(
      id: snapshot.id,
      scheduleId: scheduleId,
      ruleId: ruleId,
      title: title,
      description: description,
      scheduledDate: scheduledDate,
      startRelativeTime: startRelativeTime,
      dueRelativeTime: dueRelativeTime,
      notificationRelativeTimes: notificationRelativeTimes,
      isFamily: isFamily,
      familyCompletionMode: familyCompletionMode,
      priority: priority,
      cycleId: cycleId,
      assignedUserId: assignedUserId,
      completedByUserId: completedByUserId,
      completedByUserIds: completedByUserIds,
      completedAt: completedAt,
      status: status,
      workflowPayload: workflowPayload,
      lastModifiedByUserId: lastModifiedByUserId,
      lastModifiedByAppVersion: lastModifiedByAppVersion,
      lastModifiedByPlatform: lastModifiedByPlatform,
      statusReason: statusReason,
      hasPendingWrites: snapshot.metadata.hasPendingWrites,
      isFromCache: snapshot.metadata.isFromCache,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'scheduleId': scheduleId,
      'ruleId': ruleId,
      'title': title,
      'description': description,
      'scheduledDate': scheduledDate.toJson(),
      'startRelativeTime': startRelativeTime.toJson(),
      'dueRelativeTime': dueRelativeTime.toJson(),
      if (notificationRelativeTimes.isNotEmpty)
        'notificationRelativeTimes': notificationRelativeTimes
            .map((t) => t.toJson())
            .toList(),
      'isFamily': isFamily,
      'familyCompletionMode': familyCompletionMode.name,
      'priority': priority.name,
      if (cycleId != null) 'cycleId': cycleId,
      if (assignedUserId != null) 'assignedUserId': assignedUserId,
      if (completedByUserId != null) 'completedByUserId': completedByUserId,
      if (completedByUserIds.isNotEmpty)
        'completedByUserIds': completedByUserIds,
      if (completedAt != null) 'completedAt': completedAt,
      if (workflowPayload != null) 'workflowPayload': workflowPayload!.toJson(),
      if (lastModifiedByUserId != null)
        'lastModifiedByUserId': lastModifiedByUserId,
      if (lastModifiedByAppVersion != null)
        'lastModifiedByAppVersion': lastModifiedByAppVersion,
      if (lastModifiedByPlatform != null)
        'lastModifiedByPlatform': lastModifiedByPlatform,
      if (statusReason != null) 'statusReason': statusReason,
      'status': status.toJson(),
      'updatedAt': updatedAt,
    };
  }

  TaskInstance copyWith({
    String? title,
    String? description,
    CivilDay? scheduledDate,
    RelativeTime? startRelativeTime,
    RelativeTime? dueRelativeTime,
    List<RelativeTime>? notificationRelativeTimes,
    bool clearNotificationRelativeTimes = false,
    bool? isFamily,
    FamilyCompletionMode? familyCompletionMode,
    TaskPriority? priority,
    String? cycleId,
    bool clearCycleId = false,
    String? assignedUserId,
    bool clearAssignedUserId = false,
    String? completedByUserId,
    bool clearCompletedByUserId = false,
    List<String>? completedByUserIds,
    bool clearCompletedByUserIds = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    TaskStatus? status,
    WorkflowInstancePayload? workflowPayload,
    bool clearWorkflowPayload = false,
    String? lastModifiedByUserId,
    bool clearLastModifiedByUserId = false,
    String? lastModifiedByAppVersion,
    bool clearLastModifiedByAppVersion = false,
    String? lastModifiedByPlatform,
    bool clearLastModifiedByPlatform = false,
    String? statusReason,
    bool clearStatusReason = false,
    bool? hasPendingWrites,
    bool? isFromCache,
    DateTime? updatedAt,
  }) {
    return TaskInstance(
      id: id,
      scheduleId: scheduleId,
      ruleId: ruleId,
      title: title?.trim() ?? this.title,
      description: description?.trim() ?? this.description,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      startRelativeTime: startRelativeTime ?? this.startRelativeTime,
      dueRelativeTime: dueRelativeTime ?? this.dueRelativeTime,
      notificationRelativeTimes: clearNotificationRelativeTimes
          ? const []
          : (notificationRelativeTimes ?? this.notificationRelativeTimes),
      isFamily: isFamily ?? this.isFamily,
      familyCompletionMode: familyCompletionMode ?? this.familyCompletionMode,
      priority: priority ?? this.priority,
      cycleId: clearCycleId ? null : (cycleId ?? this.cycleId),
      assignedUserId: clearAssignedUserId
          ? null
          : (assignedUserId ?? this.assignedUserId),
      completedByUserId: clearCompletedByUserId
          ? null
          : (completedByUserId ?? this.completedByUserId),
      completedByUserIds: clearCompletedByUserIds
          ? const []
          : (completedByUserIds ?? this.completedByUserIds),
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      status: status ?? this.status,
      workflowPayload: clearWorkflowPayload
          ? null
          : (workflowPayload ?? this.workflowPayload),
      lastModifiedByUserId: clearLastModifiedByUserId
          ? null
          : (lastModifiedByUserId ?? this.lastModifiedByUserId),
      lastModifiedByAppVersion: clearLastModifiedByAppVersion
          ? null
          : (lastModifiedByAppVersion ?? this.lastModifiedByAppVersion),
      lastModifiedByPlatform: clearLastModifiedByPlatform
          ? null
          : (lastModifiedByPlatform ?? this.lastModifiedByPlatform),
      statusReason: clearStatusReason
          ? null
          : (statusReason ?? this.statusReason),
      hasPendingWrites: hasPendingWrites ?? this.hasPendingWrites,
      isFromCache: isFromCache ?? this.isFromCache,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
