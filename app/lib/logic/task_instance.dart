import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'civil_day.dart';
import 'relative_time.dart';
import 'task_priority.dart';

class TaskInstance {
  final String id;
  final String scheduleId;
  final String title;
  final String description;
  final CivilDay scheduledDate;
  final RelativeTime startRelativeTime;
  final RelativeTime dueRelativeTime;
  final List<RelativeTime> notificationRelativeTimes;
  final bool isFamily;
  final TaskPriority priority;
  final String? cycleId;
  final String? assignedUserId;
  final String? completedByUserId;
  final DateTime? completedAt;
  final String status;

  TaskInstance({
    required this.id,
    required this.scheduleId,
    required this.title,
    required this.description,
    required this.scheduledDate,
    required this.startRelativeTime,
    required this.dueRelativeTime,
    List<RelativeTime>? notificationRelativeTimes,
    this.isFamily = false,
    this.priority = TaskPriority.medium,
    this.cycleId,
    this.assignedUserId,
    this.completedByUserId,
    this.completedAt,
    this.status = 'pending',
  }) : notificationRelativeTimes = notificationRelativeTimes ?? const [];

  factory TaskInstance.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot, [
    SnapshotOptions? options,
  ]) {
    final data = snapshot.data();
    if (data == null) {
      throw Exception('Data is null for document ${snapshot.id}');
    }

    final scheduleId = data['scheduleId'] as String? ?? '';
    final title = data['title'] as String? ?? 'Untitled';
    final description = data['description'] as String? ?? '';

    final scheduledDateRaw = data['scheduledDate'] as Map<String, dynamic>?;
    final scheduledDate = scheduledDateRaw != null
        ? CivilDay.fromJson(scheduledDateRaw)
        : CivilDay.fromDateTime(DateTime.now());

    final startRelativeTimeRaw =
        data['startRelativeTime'] as Map<String, dynamic>?;
    final startRelativeTime = startRelativeTimeRaw != null
        ? RelativeTime.fromJson(startRelativeTimeRaw)
        : const RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 9, minute: 0));

    final dueRelativeTimeRaw = data['dueRelativeTime'] as Map<String, dynamic>?;
    final dueRelativeTime = dueRelativeTimeRaw != null
        ? RelativeTime.fromJson(dueRelativeTimeRaw)
        : const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          );

    List<RelativeTime> notificationRelativeTimes = [];
    if (data['notificationRelativeTimes'] != null) {
      final list = data['notificationRelativeTimes'] as List;
      notificationRelativeTimes = list
          .map((item) => RelativeTime.fromJson(item as Map<String, dynamic>))
          .toList();
    } else if (data['notificationRelativeTime'] != null) {
      final notifRaw = data['notificationRelativeTime'] as Map<String, dynamic>;
      notificationRelativeTimes = [RelativeTime.fromJson(notifRaw)];
    }

    final isFamily = data['isFamily'] as bool? ?? false;

    final priorityStr = data['priority'] as String? ?? 'medium';
    final priority = TaskPriority.values.firstWhere(
      (e) => e.name == priorityStr,
      orElse: () => TaskPriority.medium,
    );

    final cycleId = data['cycleId'] as String?;
    final assignedUserId = data['assignedUserId'] as String?;
    final completedByUserId = data['completedByUserId'] as String?;

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

    final status = data['status'] as String? ?? 'pending';

    return TaskInstance(
      id: snapshot.id,
      scheduleId: scheduleId,
      title: title,
      description: description,
      scheduledDate: scheduledDate,
      startRelativeTime: startRelativeTime,
      dueRelativeTime: dueRelativeTime,
      notificationRelativeTimes: notificationRelativeTimes,
      isFamily: isFamily,
      priority: priority,
      cycleId: cycleId,
      assignedUserId: assignedUserId,
      completedByUserId: completedByUserId,
      completedAt: completedAt,
      status: status,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'scheduleId': scheduleId,
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
      'priority': priority.name,
      if (cycleId != null) 'cycleId': cycleId,
      if (assignedUserId != null) 'assignedUserId': assignedUserId,
      if (completedByUserId != null) 'completedByUserId': completedByUserId,
      if (completedAt != null) 'completedAt': completedAt,
      'status': status,
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
    TaskPriority? priority,
    String? cycleId,
    bool clearCycleId = false,
    String? assignedUserId,
    bool clearAssignedUserId = false,
    String? completedByUserId,
    bool clearCompletedByUserId = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    String? status,
  }) {
    return TaskInstance(
      id: id,
      scheduleId: scheduleId,
      title: title ?? this.title,
      description: description ?? this.description,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      startRelativeTime: startRelativeTime ?? this.startRelativeTime,
      dueRelativeTime: dueRelativeTime ?? this.dueRelativeTime,
      notificationRelativeTimes: clearNotificationRelativeTimes
          ? const []
          : (notificationRelativeTimes ?? this.notificationRelativeTimes),
      isFamily: isFamily ?? this.isFamily,
      priority: priority ?? this.priority,
      cycleId: clearCycleId ? null : (cycleId ?? this.cycleId),
      assignedUserId: clearAssignedUserId
          ? null
          : (assignedUserId ?? this.assignedUserId),
      completedByUserId: clearCompletedByUserId
          ? null
          : (completedByUserId ?? this.completedByUserId),
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      status: status ?? this.status,
    );
  }
}
