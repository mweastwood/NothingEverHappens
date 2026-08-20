import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/recipes/recipe.dart';
import 'package:nothing_ever_happens/logic/user_settings.dart';
import 'package:nothing_ever_happens/logic/error_handler.dart';
import 'package:nothing_ever_happens/logic/app_logger.dart';
import 'package:rxdart/rxdart.dart';

final Provider<HiveLocalDataSource> hiveLocalDataSourceProvider =
    Provider<HiveLocalDataSource>((ref) {
      final ds = HiveLocalDataSource(
        errorHandler: ref.read(errorHandlerProvider),
        logger: ref.watch(appLoggerProvider),
      );
      ref.onDispose(() => ds.dispose());
      return ds;
    });

class HiveLocalDataSource {
  static const String _tasksBoxName = 'tasksBox';
  static const String _instancesBoxName = 'instancesBox';
  static const String _syncMetaBoxName = 'syncMetaBox';
  static const String _settingsBoxName = 'settingsBox';
  static const String _recipesBoxName = 'recipesBox';

  final ErrorHandler? errorHandler;
  final AppLogger? logger;

  Box<Map>? _tasksBox;
  Box<Map>? _instancesBox;
  Box<Map>? _syncMetaBox;
  Box<Map>? _settingsBox;
  Box<Map>? _recipesBox;

  HiveLocalDataSource({this.errorHandler, this.logger});

  final Map<String, TaskSchedule> _memTasks = {};
  final Map<String, TaskInstance> _memInstances = {};
  final Map<String, Recipe> _memRecipes = {};
  final Map<String, dynamic> _memMeta = {};
  UserSettings _memSettings = const UserSettings(hoursAvailable: 8.0);
  Map<String, dynamic> _memRawSettings = {};

  final _tasksSubject = BehaviorSubject<List<TaskSchedule>>.seeded(const []);
  final _instancesSubject = BehaviorSubject<List<TaskInstance>>.seeded(
    const [],
  );
  final _recipesSubject = BehaviorSubject<List<Recipe>>.seeded(const []);
  final _settingsSubject = BehaviorSubject<UserSettings>.seeded(
    const UserSettings(hoursAvailable: 8.0),
  );
  final _migrationCompletedSubject = BehaviorSubject<bool>.seeded(false);
  final _dirtyTaskIdsSubject = BehaviorSubject<List<String>>.seeded(const []);

  bool isFallbackInMemoryMode = false;

  Future<Box<Map>?> _openBoxSafely(String boxName) async {
    try {
      return await Hive.openBox<Map>(boxName);
    } catch (e, st) {
      errorHandler?.report(e, stackTrace: st);
      // ignore: avoid_print
      print(
        '⚠️ [HIVE_UPGRADE_RECOVERY] Box "$boxName" opening failed on app '
        'upgrade: $e\n$st. Re-creating clean box.',
      );
      try {
        await Hive.deleteBoxFromDisk(boxName);
        return await Hive.openBox<Map>(boxName);
      } catch (err, stack) {
        errorHandler?.report(err, stackTrace: stack);
        // ignore: avoid_print
        print(
          '⚠️ [HIVE_UPGRADE_RECOVERY_FAILED] Failed to recreate box '
          '"$boxName": $err\n$stack',
        );
        return null;
      }
    }
  }

  bool _isWritingInternally = false;

  Future<void> init() async {
    try {
      await Hive.initFlutter();
      final results = await Future.wait([
        _openBoxSafely(_tasksBoxName),
        _openBoxSafely(_instancesBoxName),
        _openBoxSafely(_syncMetaBoxName),
        _openBoxSafely(_settingsBoxName),
        _openBoxSafely(_recipesBoxName),
      ]);
      _tasksBox = results[0];
      _instancesBox = results[1];
      _syncMetaBox = results[2];
      _settingsBox = results[3];
      _recipesBox = results[4];
    } catch (e, st) {
      isFallbackInMemoryMode = true;
      errorHandler?.report(e, stackTrace: st);
      // ignore: avoid_print
      print(
        '⚠️ [HIVE_STORAGE_FALLBACK] Hive storage failed to initialize. '
        'Falling back to in-memory mode: $e\n$st',
      );
    }

    _loadFromBoxes();

    _emitTasks();
    _emitInstances();
    _emitRecipes();
    _emitSettings();
    _emitSyncMeta();

    _setupBoxWatchers();
  }

  void _loadFromBoxes() {
    _memTasks.clear();
    if (_tasksBox != null && _tasksBox!.isOpen) {
      for (final map in _tasksBox!.values) {
        try {
          final data = Map<String, dynamic>.from(map);
          final task = _taskScheduleFromJson(data);
          _memTasks[task.id] = task;
        } catch (e, st) {
          errorHandler?.report(e, stackTrace: st);
          // ignore: avoid_print
          print(
            '⚠️ [HIVE_TASK_PARSE_ERROR] Failed to parse task schedule from '
            'Hive: $e\n$st',
          );
        }
      }
    }

    _memInstances.clear();
    if (_instancesBox != null && _instancesBox!.isOpen) {
      for (final map in _instancesBox!.values) {
        try {
          final data = Map<String, dynamic>.from(map);
          final inst = _taskInstanceFromJson(data);
          _memInstances[inst.id] = inst;
        } catch (e, st) {
          errorHandler?.report(e, stackTrace: st);
          // ignore: avoid_print
          print(
            '⚠️ [HIVE_INSTANCE_PARSE_ERROR] Failed to parse task instance '
            'from Hive: $e\n$st',
          );
        }
      }
    }

    _memRecipes.clear();
    if (_recipesBox != null && _recipesBox!.isOpen) {
      for (final map in _recipesBox!.values) {
        try {
          final data = Map<String, dynamic>.from(map);
          final recipe = _recipeFromJson(data);
          _memRecipes[recipe.id] = recipe;
        } catch (e, st) {
          errorHandler?.report(e, stackTrace: st);
          // ignore: avoid_print
          print(
            '⚠️ [HIVE_RECIPE_PARSE_ERROR] Failed to parse recipe from '
            'Hive: $e\n$st',
          );
        }
      }
    }

    if (_settingsBox != null && _settingsBox!.isOpen) {
      try {
        final raw = _settingsBox!.get('agile');
        if (raw != null) {
          final data = Map<String, dynamic>.from(raw);
          _memSettings = UserSettings.fromJson(data);
        }
      } catch (e, st) {
        errorHandler?.report(e, stackTrace: st);
        // ignore: avoid_print
        print(
          '⚠️ [HIVE_SETTINGS_PARSE_ERROR] Failed to parse settings from '
          'Hive: $e\n$st',
        );
      }
    }
  }

  void _setupBoxWatchers() {
    _tasksBox?.watch().listen((event) {
      if (_isWritingInternally) return;
      if (event.deleted) {
        _memTasks.remove(event.key.toString());
      } else if (event.value != null) {
        try {
          final data = Map<String, dynamic>.from(event.value as Map);
          final task = _taskScheduleFromJson(data);
          _memTasks[task.id] = task;
        } catch (e, st) {
          _memTasks.remove(event.key.toString());
          errorHandler?.report(e, stackTrace: st);
        }
      }
      _emitTasks();
    });

    _instancesBox?.watch().listen((event) {
      if (_isWritingInternally) return;
      if (event.deleted) {
        _memInstances.remove(event.key.toString());
      } else if (event.value != null) {
        try {
          final data = Map<String, dynamic>.from(event.value as Map);
          final inst = _taskInstanceFromJson(data);
          _memInstances[inst.id] = inst;
        } catch (e, st) {
          _memInstances.remove(event.key.toString());
          errorHandler?.report(e, stackTrace: st);
        }
      }
      _emitInstances();
    });

    _recipesBox?.watch().listen((event) {
      if (_isWritingInternally) return;
      if (event.deleted) {
        _memRecipes.remove(event.key.toString());
      } else if (event.value != null) {
        try {
          final data = Map<String, dynamic>.from(event.value as Map);
          final recipe = _recipeFromJson(data);
          _memRecipes[recipe.id] = recipe;
        } catch (e, st) {
          _memRecipes.remove(event.key.toString());
          errorHandler?.report(e, stackTrace: st);
        }
      }
      _emitRecipes();
    });

    _settingsBox?.watch().listen((event) {
      if (_isWritingInternally) return;
      if (event.value != null && event.key == 'agile') {
        try {
          final data = Map<String, dynamic>.from(event.value as Map);
          _memSettings = UserSettings.fromJson(data);
        } catch (e, st) {
          errorHandler?.report(e, stackTrace: st);
        }
      }
      _emitSettings();
    });

    _syncMetaBox?.watch().listen((_) {
      if (_isWritingInternally) return;
      _emitSyncMeta();
    });
  }

  void _emitTasks() {
    if (!_tasksSubject.isClosed) {
      _tasksSubject.add(getTasks());
    }
  }

  void _emitInstances() {
    if (!_instancesSubject.isClosed) {
      _instancesSubject.add(getInstances());
    }
  }

  void _emitRecipes() {
    if (!_recipesSubject.isClosed) {
      _recipesSubject.add(getRecipes());
    }
  }

  void _emitSettings() {
    if (!_settingsSubject.isClosed) {
      _settingsSubject.add(getSettings());
    }
  }

  void _emitSyncMeta() {
    if (!_migrationCompletedSubject.isClosed) {
      _migrationCompletedSubject.add(isMigrationCompleted());
    }
    if (!_dirtyTaskIdsSubject.isClosed) {
      _dirtyTaskIdsSubject.add(getDirtyTaskIds());
    }
  }

  Stream<List<TaskSchedule>> watchTasks() => _tasksSubject.stream;
  Stream<List<TaskInstance>> watchInstances() => _instancesSubject.stream;
  Stream<List<Recipe>> watchRecipes() => _recipesSubject.stream;
  Stream<UserSettings> watchSettings() => _settingsSubject.stream;
  Stream<bool> watchMigrationCompleted() => _migrationCompletedSubject.stream;
  Stream<List<String>> watchDirtyTaskIds() => _dirtyTaskIdsSubject.stream;

  UserSettings getSettings() {
    return _memSettings;
  }

  Future<void> saveSettings(UserSettings settings) async {
    _isWritingInternally = true;
    try {
      _memSettings = settings;
      if (_settingsBox != null && _settingsBox!.isOpen) {
        await _settingsBox!.put('agile', settings.toJson());
      }
    } finally {
      _isWritingInternally = false;
    }
    _emitSettings();
  }

  Future<void> saveRawSettings(Map<String, dynamic> settings) async {
    _isWritingInternally = true;
    try {
      _memRawSettings = Map<String, dynamic>.from(settings);
      if (_settingsBox != null && _settingsBox!.isOpen) {
        await _settingsBox!.put('agile', settings);
      }
    } finally {
      _isWritingInternally = false;
    }
  }

  List<TaskSchedule> getTasks() {
    return _memTasks.values.toList();
  }

  List<TaskInstance> getInstances() {
    return _memInstances.values.toList();
  }

  Future<void> saveTask(TaskSchedule task) async {
    await saveTasks([task]);
  }

  Future<void> saveTasks(List<TaskSchedule> tasks) async {
    if (tasks.isEmpty) return;
    _isWritingInternally = true;
    try {
      for (final task in tasks) {
        _memTasks[task.id] = task;
      }
      if (_tasksBox != null && _tasksBox!.isOpen) {
        final entries = <String, Map<String, dynamic>>{};
        for (final task in tasks) {
          final data = task.toFirestore();
          data['id'] = task.id;
          if (data['updatedAt'] is DateTime) {
            data['updatedAt'] = (data['updatedAt'] as DateTime)
                .toIso8601String();
          }
          entries[task.id] = data;
        }
        await _tasksBox!.putAll(entries);
      }
    } finally {
      _isWritingInternally = false;
    }
    _emitTasks();
  }

  Future<void> deleteTask(String id) async {
    await deleteTasks([id]);
  }

  Future<void> deleteTasks(List<String> ids) async {
    if (ids.isEmpty) return;
    _isWritingInternally = true;
    try {
      for (final id in ids) {
        _memTasks.remove(id);
      }
      if (_tasksBox != null && _tasksBox!.isOpen) {
        await _tasksBox!.deleteAll(ids);
      }
    } finally {
      _isWritingInternally = false;
    }
    _emitTasks();
  }

  Future<void> saveInstance(TaskInstance instance) async {
    await saveInstances([instance]);
  }

  Future<void> saveInstances(List<TaskInstance> instances) async {
    if (instances.isEmpty) return;
    _isWritingInternally = true;
    try {
      for (final instance in instances) {
        _memInstances[instance.id] = instance;
      }
      if (_instancesBox != null && _instancesBox!.isOpen) {
        final entries = <String, Map<String, dynamic>>{};
        for (final instance in instances) {
          final data = instance.toFirestore();
          data['id'] = instance.id;
          if (data['updatedAt'] is DateTime) {
            data['updatedAt'] = (data['updatedAt'] as DateTime)
                .toIso8601String();
          }
          if (data['completedAt'] is DateTime) {
            data['completedAt'] = (data['completedAt'] as DateTime)
                .toIso8601String();
          }
          entries[instance.id] = data;
        }
        await _instancesBox!.putAll(entries);
      }
    } finally {
      _isWritingInternally = false;
    }
    _emitInstances();
  }

  Future<void> deleteInstance(String id) async {
    await deleteInstances([id]);
  }

  Future<void> deleteInstances(List<String> ids) async {
    if (ids.isEmpty) return;
    _isWritingInternally = true;
    try {
      for (final id in ids) {
        _memInstances.remove(id);
      }
      if (_instancesBox != null && _instancesBox!.isOpen) {
        await _instancesBox!.deleteAll(ids);
      }
    } finally {
      _isWritingInternally = false;
    }
    _emitInstances();
  }

  List<Recipe> getRecipes() {
    return _memRecipes.values.toList();
  }

  Recipe _recipeFromJson(Map<String, dynamic> data) {
    return Recipe.fromJson(data);
  }

  Future<void> saveRecipe(Recipe recipe) async {
    await saveRecipes([recipe]);
  }

  Future<void> saveRecipes(List<Recipe> recipes) async {
    if (recipes.isEmpty) return;
    _isWritingInternally = true;
    try {
      for (final recipe in recipes) {
        _memRecipes[recipe.id] = recipe;
      }
      if (_recipesBox != null && _recipesBox!.isOpen) {
        final entries = <String, Map<String, dynamic>>{};
        for (final recipe in recipes) {
          entries[recipe.id] = recipe.toJson();
        }
        await _recipesBox!.putAll(entries);
      }
    } finally {
      _isWritingInternally = false;
    }
    _emitRecipes();
  }

  Future<void> deleteRecipe(String id) async {
    await deleteRecipes([id]);
  }

  Future<void> deleteRecipes(List<String> ids) async {
    if (ids.isEmpty) return;
    _isWritingInternally = true;
    try {
      for (final id in ids) {
        _memRecipes.remove(id);
      }
      if (_recipesBox != null && _recipesBox!.isOpen) {
        await _recipesBox!.deleteAll(ids);
      }
    } finally {
      _isWritingInternally = false;
    }
    _emitRecipes();
  }

  Future<void> markDirty(String id) async {
    await markDirtyBatch([id]);
  }

  Future<void> markDirtyBatch(List<String> ids) async {
    if (ids.isEmpty) return;
    final dirtyList = getDirtyTaskIds();
    bool changed = false;
    for (final id in ids) {
      if (!dirtyList.contains(id)) {
        dirtyList.add(id);
        changed = true;
      }
    }
    if (changed) {
      if (_syncMetaBox != null && _syncMetaBox!.isOpen) {
        await _syncMetaBox!.put('dirty_tasks', {'list': dirtyList});
      } else {
        _memMeta['dirty_tasks'] = {'list': dirtyList};
      }
      _emitSyncMeta();
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
    await clearDirtyBatch([id]);
  }

  Future<void> clearDirtyBatch(List<String> ids) async {
    if (ids.isEmpty) return;
    final dirtyList = getDirtyTaskIds();
    final idSet = ids.toSet();
    final prevLength = dirtyList.length;
    dirtyList.removeWhere((id) => idSet.contains(id));
    if (dirtyList.length != prevLength) {
      if (_syncMetaBox != null && _syncMetaBox!.isOpen) {
        await _syncMetaBox!.put('dirty_tasks', {'list': dirtyList});
      } else {
        _memMeta['dirty_tasks'] = {'list': dirtyList};
      }
      _emitSyncMeta();
    }
  }

  Future<void> clearAllTasksAndInstances() async {
    _memTasks.clear();
    _memInstances.clear();
    _memRecipes.clear();
    if (_tasksBox != null && _tasksBox!.isOpen) {
      await _tasksBox!.clear();
    }
    if (_instancesBox != null && _instancesBox!.isOpen) {
      await _instancesBox!.clear();
    }
    if (_recipesBox != null && _recipesBox!.isOpen) {
      await _recipesBox!.clear();
    }
    _emitTasks();
    _emitInstances();
    _emitRecipes();
  }

  Future<void> clearAllDirty() async {
    _memMeta['dirty_tasks'] = {'list': <String>[]};
    if (_syncMetaBox != null && _syncMetaBox!.isOpen) {
      await _syncMetaBox!.put('dirty_tasks', {'list': <String>[]});
    }
    _emitSyncMeta();
  }

  Future<void> resetAllData() async {
    await clearAllTasksAndInstances();
    await clearAllDirty();
    await setMigrationCompleted(false);
    await setActiveUserId(null);
    if (_settingsBox != null && _settingsBox!.isOpen) {
      await _settingsBox!.clear();
    }
    _memSettings = const UserSettings(hoursAvailable: 8.0);
    _memRawSettings = {};
    _emitSettings();
  }

  String? getActiveUserId() {
    final data = _syncMetaBox != null && _syncMetaBox!.isOpen
        ? _syncMetaBox!.get('active_user_id')
        : _memMeta['active_user_id'];
    if (data == null) return null;
    return data['userId'] as String?;
  }

  Future<void> setActiveUserId(String? userId) async {
    if (userId == null) {
      if (_syncMetaBox != null && _syncMetaBox!.isOpen) {
        await _syncMetaBox!.delete('active_user_id');
      } else {
        _memMeta.remove('active_user_id');
      }
    } else {
      if (_syncMetaBox != null && _syncMetaBox!.isOpen) {
        await _syncMetaBox!.put('active_user_id', {'userId': userId});
      } else {
        _memMeta['active_user_id'] = {'userId': userId};
      }
    }
  }

  Future<void> setMigrationCompleted(bool completed) async {
    if (_syncMetaBox != null && _syncMetaBox!.isOpen) {
      await _syncMetaBox!.put('migration_completed', {'value': completed});
    } else {
      _memMeta['migration_completed'] = {'value': completed};
    }
    _emitSyncMeta();
  }

  bool isMigrationCompleted() {
    final data = _syncMetaBox != null && _syncMetaBox!.isOpen
        ? _syncMetaBox!.get('migration_completed')
        : _memMeta['migration_completed'];
    if (data == null) return false;
    return data['value'] == true;
  }

  int getAppLaunchCount() {
    final data = _syncMetaBox != null && _syncMetaBox!.isOpen
        ? _syncMetaBox!.get('app_launch_count')
        : _memMeta['app_launch_count'];
    if (data == null) return 0;
    return (data['count'] as num?)?.toInt() ?? 0;
  }

  Future<int> incrementAppLaunchCount() async {
    final current = getAppLaunchCount();
    final next = current + 1;
    if (_syncMetaBox != null && _syncMetaBox!.isOpen) {
      await _syncMetaBox!.put('app_launch_count', {'count': next});
    } else {
      _memMeta['app_launch_count'] = {'count': next};
    }
    return next;
  }

  int getTasksCompletedCount() {
    final data = _syncMetaBox != null && _syncMetaBox!.isOpen
        ? _syncMetaBox!.get('tasks_completed_count')
        : _memMeta['tasks_completed_count'];
    if (data == null) return 0;
    return (data['count'] as num?)?.toInt() ?? 0;
  }

  Future<int> incrementTasksCompletedCount() async {
    final current = getTasksCompletedCount();
    final next = current + 1;
    if (_syncMetaBox != null && _syncMetaBox!.isOpen) {
      await _syncMetaBox!.put('tasks_completed_count', {'count': next});
    } else {
      _memMeta['tasks_completed_count'] = {'count': next};
    }
    return next;
  }

  @visibleForTesting
  TaskSchedule taskScheduleFromJson(Map<String, dynamic> data) =>
      _taskScheduleFromJson(data);

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
      (k, v) => MapEntry(k.toString(), v == true),
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

    final workflowType = data['workflowType'] as String?;
    final mealWorkflowConfig = data['mealWorkflowConfig'] != null
        ? MealWorkflowConfig.fromJson(
            Map<String, dynamic>.from(data['mealWorkflowConfig'] as Map),
          )
        : null;

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
      familyCompletionMode: FamilyCompletionMode.fromString(
        data['familyCompletionMode'] as String?,
      ),
      priority: priority,
      cycleId: data['cycleId'] as String?,
      preferredBy: preferredBy,
      assignedUserId: data['assignedUserId'] as String?,
      workflowType: workflowType,
      mealWorkflowConfig: mealWorkflowConfig,
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

    final completedByUserIdsRaw =
        data['completedByUserIds'] as List<dynamic>? ?? [];
    final completedByUserIds = completedByUserIdsRaw
        .map((e) => e.toString())
        .toList();

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

    final workflowPayloadRaw = data['workflowPayload'] as Map?;
    final workflowPayload = workflowPayloadRaw != null
        ? WorkflowInstancePayload.fromJson(
            Map<String, dynamic>.from(workflowPayloadRaw),
          )
        : null;

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
      familyCompletionMode: FamilyCompletionMode.fromString(
        data['familyCompletionMode'] as String?,
      ),
      priority: priority,
      cycleId: data['cycleId'] as String?,
      assignedUserId: data['assignedUserId'] as String?,
      completedByUserId: data['completedByUserId'] as String?,
      completedByUserIds: completedByUserIds,
      completedAt: completedAt,
      status: TaskStatus.fromString(data['status'] as String?),
      workflowPayload: workflowPayload,
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
        } catch (e, stackTrace) {
          debugPrint('Error exporting raw task map: $e\n$stackTrace');
        }
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
        } catch (e, stackTrace) {
          debugPrint('Error exporting raw instance map: $e\n$stackTrace');
        }
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
          settingsMap = {..._memSettings.toJson(), ..._memRawSettings};
        }
      } catch (e, stackTrace) {
        debugPrint('Error exporting raw settings map: $e\n$stackTrace');
        settingsMap = {..._memSettings.toJson(), ..._memRawSettings};
      }
    } else {
      settingsMap = {..._memSettings.toJson(), ..._memRawSettings};
    }

    final recipesList = <Map<String, dynamic>>[];
    if (_recipesBox != null && _recipesBox!.isOpen) {
      for (final map in _recipesBox!.values) {
        try {
          recipesList.add(Map<String, dynamic>.from(map));
        } catch (e, stackTrace) {
          debugPrint('Error exporting raw recipe map: $e\n$stackTrace');
        }
      }
    } else {
      for (final recipe in _memRecipes.values) {
        final data = recipe.toJson();
        recipesList.add(data);
      }
    }

    return {
      'inMemoryFallback': isFallbackInMemoryMode,
      'tasks': tasksList,
      'instances': instancesList,
      'recipes': recipesList,
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
    await _recipesSubject.close();
    await _settingsSubject.close();
    await _migrationCompletedSubject.close();
    await _dirtyTaskIdsSubject.close();
  }
}
