import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:rxdart/rxdart.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final hiveLocalDataSourceProvider = Provider<HiveLocalDataSource>(
  (ref) => HiveLocalDataSource(),
);

class HiveLocalDataSource {
  static const String _tasksBoxName = 'tasksBox';
  static const String _instancesBoxName = 'instancesBox';
  static const String _syncMetaBoxName = 'syncMetaBox';

  late Box<Map> _tasksBox;
  late Box<Map> _instancesBox;
  late Box<Map> _syncMetaBox;

  final _tasksSubject = BehaviorSubject<List<TaskSchedule>>();
  final _instancesSubject = BehaviorSubject<List<TaskInstance>>();

  Future<void> init() async {
    await Hive.initFlutter();
    _tasksBox = await Hive.openBox<Map>(_tasksBoxName);
    _instancesBox = await Hive.openBox<Map>(_instancesBoxName);
    _syncMetaBox = await Hive.openBox<Map>(_syncMetaBoxName);

    _emitTasks();
    _emitInstances();

    _tasksBox.watch().listen((_) => _emitTasks());
    _instancesBox.watch().listen((_) => _emitInstances());
  }

  void _emitTasks() {
    _tasksSubject.add(getTasks());
  }

  void _emitInstances() {
    _instancesSubject.add(getInstances());
  }

  Stream<List<TaskSchedule>> watchTasks() => _tasksSubject.stream;
  Stream<List<TaskInstance>> watchInstances() => _instancesSubject.stream;

  List<TaskSchedule> getTasks() {
    return _tasksBox.values.map((map) {
      final data = Map<String, dynamic>.from(map);
      return _taskScheduleFromJson(data);
    }).toList();
  }

  List<TaskInstance> getInstances() {
    return _instancesBox.values.map((map) {
      final data = Map<String, dynamic>.from(map);
      return _taskInstanceFromJson(data);
    }).toList();
  }

  Future<void> saveTask(TaskSchedule task) async {
    final data = task.toFirestore();
    data['id'] = task.id; // Store ID in the map
    if (data['updatedAt'] is DateTime) {
      data['updatedAt'] = (data['updatedAt'] as DateTime).toIso8601String();
    }
    await _tasksBox.put(task.id, data);
    _emitTasks();
  }

  Future<void> deleteTask(String id) async {
    await _tasksBox.delete(id);
    _emitTasks();
  }

  Future<void> saveInstance(TaskInstance instance) async {
    final data = instance.toFirestore();
    data['id'] = instance.id;
    if (data['updatedAt'] is DateTime) {
      data['updatedAt'] = (data['updatedAt'] as DateTime).toIso8601String();
    }
    if (data['completedAt'] is DateTime) {
      data['completedAt'] = (data['completedAt'] as DateTime).toIso8601String();
    }
    await _instancesBox.put(instance.id, data);
    _emitInstances();
  }

  Future<void> deleteInstance(String id) async {
    await _instancesBox.delete(id);
    _emitInstances();
  }

  Future<void> markDirty(String id) async {
    final dirtyList = getDirtyTaskIds();
    if (!dirtyList.contains(id)) {
      dirtyList.add(id);
      await _syncMetaBox.put('dirty_tasks', {'list': dirtyList});
    }
  }

  List<String> getDirtyTaskIds() {
    final data = _syncMetaBox.get('dirty_tasks');
    if (data == null) return [];
    return List<String>.from(data['list'] ?? []);
  }

  Future<void> clearDirty(String id) async {
    final dirtyList = getDirtyTaskIds();
    if (dirtyList.remove(id)) {
      await _syncMetaBox.put('dirty_tasks', {'list': dirtyList});
    }
  }

  Future<void> setMigrationCompleted(bool completed) async {
    await _syncMetaBox.put('migration_completed', {'value': completed});
  }

  bool isMigrationCompleted() {
    final data = _syncMetaBox.get('migration_completed');
    if (data == null) return false;
    return data['value'] == true;
  }

  TaskSchedule _taskScheduleFromJson(Map<String, dynamic> data) {
    final schedulesRaw = data['schedules'] as List<dynamic>? ?? [];
    final schedules = schedulesRaw
        .map(
          (item) => TaskScheduleRule.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();

    final lastSpawnedDateRaw = data['lastSpawnedDate'] as Map?;
    final lastSpawnedDate = lastSpawnedDateRaw != null
        ? CivilDay.fromJson(Map<String, dynamic>.from(lastSpawnedDateRaw))
        : null;

    final preferredByRaw = data['preferredBy'] as Map? ?? {};
    final preferredBy = preferredByRaw.map(
      (k, v) => MapEntry(k.toString(), v as bool),
    );

    final priorityStr = data['priority'] as String? ?? 'medium';
    final priority = TaskPriority.values.firstWhere(
      (e) => e.name == priorityStr,
      orElse: () => TaskPriority.medium,
    );

    final updatedAtRaw = data['updatedAt'];
    DateTime? updatedAt;
    if (updatedAtRaw != null) {
      if (updatedAtRaw is String) {
        updatedAt = DateTime.parse(updatedAtRaw);
      } else if (updatedAtRaw is int) {
        updatedAt = DateTime.fromMillisecondsSinceEpoch(updatedAtRaw);
      } else if (updatedAtRaw is Timestamp) {
        updatedAt = updatedAtRaw.toDate();
      }
    }

    return TaskSchedule(
      id: data['id'] as String,
      title: data['title'] as String? ?? 'Untitled',
      description: data['description'] as String? ?? '',
      schedules: schedules,
      activeOccurrenceIndex: data['activeOccurrenceIndex'] as int? ?? 0,
      estimatedDuration: data['estimatedDuration'] != null
          ? Duration(minutes: data['estimatedDuration'] as int)
          : null,
      isMaster: data['isMaster'] as bool? ?? false,
      lastSpawnedDate: lastSpawnedDate,
      parentTaskId: data['parentTaskId'] as String?,
      isFamily: data['isFamily'] as bool? ?? false,
      priority: priority,
      cycleId: data['cycleId'] as String?,
      preferredBy: preferredBy,
      assignedUserId: data['assignedUserId'] as String?,
      skipIfNoCapacity: data['skipIfNoCapacity'] as bool? ?? false,
      hasPendingWrites: false,
      isFromCache: true,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  TaskInstance _taskInstanceFromJson(Map<String, dynamic> data) {
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
          .map((item) => RelativeTime.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } else if (data['notificationRelativeTime'] != null) {
      final notifRaw = data['notificationRelativeTime'] as Map;
      notificationRelativeTimes = [
        RelativeTime.fromJson(Map<String, dynamic>.from(notifRaw)),
      ];
    }

    final priorityStr = data['priority'] as String? ?? 'medium';
    final priority = TaskPriority.values.firstWhere(
      (e) => e.name == priorityStr,
      orElse: () => TaskPriority.medium,
    );

    final completedAtRaw = data['completedAt'];
    DateTime? completedAt;
    if (completedAtRaw != null) {
      if (completedAtRaw is String) {
        completedAt = DateTime.parse(completedAtRaw);
      } else if (completedAtRaw is int) {
        completedAt = DateTime.fromMillisecondsSinceEpoch(completedAtRaw);
      } else if (completedAtRaw is Timestamp) {
        completedAt = completedAtRaw.toDate();
      }
    }

    final updatedAtRaw = data['updatedAt'];
    DateTime? updatedAt;
    if (updatedAtRaw != null) {
      if (updatedAtRaw is String) {
        updatedAt = DateTime.parse(updatedAtRaw);
      } else if (updatedAtRaw is int) {
        updatedAt = DateTime.fromMillisecondsSinceEpoch(updatedAtRaw);
      } else if (updatedAtRaw is Timestamp) {
        updatedAt = updatedAtRaw.toDate();
      }
    }

    return TaskInstance(
      id: data['id'] as String,
      scheduleId: data['scheduleId'] as String? ?? '',
      ruleId: data['ruleId'] as String? ?? '',
      title: data['title'] as String? ?? 'Untitled',
      description: data['description'] as String? ?? '',
      scheduledDate: scheduledDate,
      startRelativeTime: startRelativeTime,
      dueRelativeTime: dueRelativeTime,
      notificationRelativeTimes: notificationRelativeTimes,
      isFamily: data['isFamily'] as bool? ?? false,
      priority: priority,
      cycleId: data['cycleId'] as String?,
      assignedUserId: data['assignedUserId'] as String?,
      completedByUserId: data['completedByUserId'] as String?,
      completedAt: completedAt,
      status: data['status'] as String? ?? 'pending',
      hasPendingWrites: false,
      isFromCache: true,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
