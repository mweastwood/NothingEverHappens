import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:rxdart/rxdart.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:nothing_ever_happens/logic/user_settings.dart';

final hiveLocalDataSourceProvider = Provider<HiveLocalDataSource>((ref) {
  final ds = HiveLocalDataSource();
  ref.onDispose(() => ds.dispose());
  return ds;
});

class HiveLocalDataSource {
  static const String _tasksBoxName = 'tasksBox';
  static const String _instancesBoxName = 'instancesBox';
  static const String _syncMetaBoxName = 'syncMetaBox';
  static const String _settingsBoxName = 'settingsBox';

  Box<Map>? _tasksBox;
  Box<Map>? _instancesBox;
  Box<Map>? _syncMetaBox;
  Box<Map>? _settingsBox;

  final Map<String, TaskSchedule> _memTasks = {};
  final Map<String, TaskInstance> _memInstances = {};
  final Map<String, dynamic> _memMeta = {};
  UserSettings _memSettings = const UserSettings(hoursAvailable: 8.0);

  final _tasksSubject = BehaviorSubject<List<TaskSchedule>>.seeded(const []);
  final _instancesSubject = BehaviorSubject<List<TaskInstance>>.seeded(
    const [],
  );
  final _settingsSubject = BehaviorSubject<UserSettings>.seeded(
    const UserSettings(hoursAvailable: 8.0),
  );

  bool isFallbackInMemoryMode = false;

  Future<Box<Map>?> _openBoxSafely(String boxName) async {
    try {
      return await Hive.openBox<Map>(boxName);
    } catch (e, st) {
      // ignore: avoid_print
      print(
        '⚠️ [HIVE_UPGRADE_RECOVERY] Box "$boxName" opening failed on app upgrade: $e\n$st. Re-creating clean box.',
      );
      try {
        await Hive.deleteBoxFromDisk(boxName);
        return await Hive.openBox<Map>(boxName);
      } catch (err, stack) {
        // ignore: avoid_print
        print(
          '⚠️ [HIVE_UPGRADE_RECOVERY_FAILED] Failed to recreate box "$boxName": $err\n$stack',
        );
        return null;
      }
    }
  }

  Future<void> init() async {
    try {
      await Hive.initFlutter();
      _tasksBox = await _openBoxSafely(_tasksBoxName);
      _instancesBox = await _openBoxSafely(_instancesBoxName);
      _syncMetaBox = await _openBoxSafely(_syncMetaBoxName);
      _settingsBox = await _openBoxSafely(_settingsBoxName);
    } catch (e, st) {
      isFallbackInMemoryMode = true;
      // ignore: avoid_print
      print(
        '⚠️ [HIVE_STORAGE_FALLBACK] Hive storage failed to initialize. '
        'Falling back to in-memory mode: $e\n$st',
      );
    }

    _emitTasks();
    _emitInstances();
    _emitSettings();

    _tasksBox?.watch().listen((_) => _emitTasks());
    _instancesBox?.watch().listen((_) => _emitInstances());
    _settingsBox?.watch().listen((_) => _emitSettings());
  }

  void _emitTasks() {
    _tasksSubject.add(getTasks());
  }

  void _emitInstances() {
    _instancesSubject.add(getInstances());
  }

  void _emitSettings() {
    _settingsSubject.add(getSettings());
  }

  Stream<List<TaskSchedule>> watchTasks() => _tasksSubject.stream;
  Stream<List<TaskInstance>> watchInstances() => _instancesSubject.stream;
  Stream<UserSettings> watchSettings() => _settingsSubject.stream;

  UserSettings getSettings() {
    if (_settingsBox != null && _settingsBox!.isOpen) {
      try {
        final raw = _settingsBox!.get('agile');
        if (raw != null) {
          final data = Map<String, dynamic>.from(raw);
          return UserSettings.fromJson(data);
        }
      } catch (e, st) {
        // ignore: avoid_print
        print(
          '⚠️ [HIVE_SETTINGS_PARSE_ERROR] Failed to parse settings from Hive: $e\n$st',
        );
      }
    }
    return _memSettings;
  }

  Future<void> saveSettings(UserSettings settings) async {
    _memSettings = settings;
    if (_settingsBox != null && _settingsBox!.isOpen) {
      await _settingsBox!.put('agile', settings.toJson());
    }
    _emitSettings();
  }

  List<TaskSchedule> getTasks() {
    if (_tasksBox != null && _tasksBox!.isOpen) {
      final list = <TaskSchedule>[];
      for (final map in _tasksBox!.values) {
        try {
          final data = Map<String, dynamic>.from(map);
          list.add(_taskScheduleFromJson(data));
        } catch (e, st) {
          // ignore: avoid_print
          print(
            '⚠️ [HIVE_TASK_PARSE_ERROR] Failed to parse task schedule from Hive: $e\n$st',
          );
        }
      }
      return list;
    }
    return _memTasks.values.toList();
  }

  List<TaskInstance> getInstances() {
    if (_instancesBox != null && _instancesBox!.isOpen) {
      final list = <TaskInstance>[];
      for (final map in _instancesBox!.values) {
        try {
          final data = Map<String, dynamic>.from(map);
          list.add(_taskInstanceFromJson(data));
        } catch (e, st) {
          // ignore: avoid_print
          print(
            '⚠️ [HIVE_INSTANCE_PARSE_ERROR] Failed to parse task instance from Hive: $e\n$st',
          );
        }
      }
      return list;
    }
    return _memInstances.values.toList();
  }

  Future<void> saveTask(TaskSchedule task) async {
    _memTasks[task.id] = task;
    if (_tasksBox != null && _tasksBox!.isOpen) {
      final data = task.toFirestore();
      data['id'] = task.id;
      if (data['updatedAt'] is DateTime) {
        data['updatedAt'] = (data['updatedAt'] as DateTime).toIso8601String();
      }
      await _tasksBox!.put(task.id, data);
    }
    _emitTasks();
  }

  Future<void> deleteTask(String id) async {
    _memTasks.remove(id);
    if (_tasksBox != null && _tasksBox!.isOpen) {
      await _tasksBox!.delete(id);
    }
    _emitTasks();
  }

  Future<void> saveInstance(TaskInstance instance) async {
    _memInstances[instance.id] = instance;
    if (_instancesBox != null && _instancesBox!.isOpen) {
      final data = instance.toFirestore();
      data['id'] = instance.id;
      if (data['updatedAt'] is DateTime) {
        data['updatedAt'] = (data['updatedAt'] as DateTime).toIso8601String();
      }
      if (data['completedAt'] is DateTime) {
        data['completedAt'] = (data['completedAt'] as DateTime)
            .toIso8601String();
      }
      await _instancesBox!.put(instance.id, data);
    }
    _emitInstances();
  }

  Future<void> deleteInstance(String id) async {
    _memInstances.remove(id);
    if (_instancesBox != null && _instancesBox!.isOpen) {
      await _instancesBox!.delete(id);
    }
    _emitInstances();
  }

  Future<void> markDirty(String id) async {
    final dirtyList = getDirtyTaskIds();
    if (!dirtyList.contains(id)) {
      dirtyList.add(id);
      if (_syncMetaBox != null && _syncMetaBox!.isOpen) {
        await _syncMetaBox!.put('dirty_tasks', {'list': dirtyList});
      } else {
        _memMeta['dirty_tasks'] = {'list': dirtyList};
      }
    }
  }

  List<String> getDirtyTaskIds() {
    final data = _syncMetaBox != null && _syncMetaBox!.isOpen
        ? _syncMetaBox!.get('dirty_tasks')
        : _memMeta['dirty_tasks'];
    if (data == null) return [];
    return List<String>.from(data['list'] ?? []);
  }

  Future<void> clearDirty(String id) async {
    final dirtyList = getDirtyTaskIds();
    if (dirtyList.remove(id)) {
      if (_syncMetaBox != null && _syncMetaBox!.isOpen) {
        await _syncMetaBox!.put('dirty_tasks', {'list': dirtyList});
      } else {
        _memMeta['dirty_tasks'] = {'list': dirtyList};
      }
    }
  }

  Future<void> setMigrationCompleted(bool completed) async {
    if (_syncMetaBox != null && _syncMetaBox!.isOpen) {
      await _syncMetaBox!.put('migration_completed', {'value': completed});
    } else {
      _memMeta['migration_completed'] = {'value': completed};
    }
  }

  bool isMigrationCompleted() {
    final data = _syncMetaBox != null && _syncMetaBox!.isOpen
        ? _syncMetaBox!.get('migration_completed')
        : _memMeta['migration_completed'];
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

  Map<String, dynamic> exportRawState() {
    final tasksList = <Map<String, dynamic>>[];
    if (_tasksBox != null && _tasksBox!.isOpen) {
      for (final map in _tasksBox!.values) {
        try {
          tasksList.add(Map<String, dynamic>.from(map));
        } catch (_) {}
      }
    } else {
      for (final task in _memTasks.values) {
        final data = task.toFirestore();
        data['id'] = task.id;
        tasksList.add(data);
      }
    }

    final instancesList = <Map<String, dynamic>>[];
    if (_instancesBox != null && _instancesBox!.isOpen) {
      for (final map in _instancesBox!.values) {
        try {
          instancesList.add(Map<String, dynamic>.from(map));
        } catch (_) {}
      }
    } else {
      for (final instance in _memInstances.values) {
        final data = instance.toFirestore();
        data['id'] = instance.id;
        instancesList.add(data);
      }
    }

    Map<String, dynamic> settingsMap = {};
    if (_settingsBox != null && _settingsBox!.isOpen) {
      try {
        final raw = _settingsBox!.get('agile');
        if (raw != null) {
          settingsMap = Map<String, dynamic>.from(raw);
        } else {
          settingsMap = _memSettings.toJson();
        }
      } catch (_) {
        settingsMap = _memSettings.toJson();
      }
    } else {
      settingsMap = _memSettings.toJson();
    }

    return {
      'inMemoryFallback': isFallbackInMemoryMode,
      'tasks': tasksList,
      'instances': instancesList,
      'syncMeta': {
        'dirty_tasks': getDirtyTaskIds(),
        'migration_completed': isMigrationCompleted(),
      },
      'settings': settingsMap,
    };
  }

  Future<void> dispose() async {
    await _tasksSubject.close();
    await _instancesSubject.close();
    await _settingsSubject.close();
  }
}

