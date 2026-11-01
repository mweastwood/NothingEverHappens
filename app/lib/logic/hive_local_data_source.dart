import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
  static const String _notificationIdsBoxName = 'notificationIdsBox';

  final ErrorHandler? errorHandler;
  final AppLogger? logger;

  Box<Map>? _tasksBox;
  Box<Map>? _instancesBox;
  Box<Map>? _syncMetaBox;
  Box<Map>? _settingsBox;
  Box<Map>? _recipesBox;
  Box<dynamic>? _notificationIdsBox;

  final List<StreamSubscription<BoxEvent>> _boxWatchSubscriptions = [];

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

  Future<Box<T>?> _openBoxSafely<T>(String boxName) async {
    try {
      return await Hive.openBox<T>(boxName);
    } catch (e, st) {
      errorHandler?.report(e, stackTrace: st);
      logger?.error(
        'hive',
        'Box "$boxName" opening failed on app upgrade. Re-creating clean box.',
        error: e,
        stackTrace: st,
      );
      try {
        await Hive.deleteBoxFromDisk(boxName);
        return await Hive.openBox<T>(boxName);
      } catch (err, stack) {
        errorHandler?.report(err, stackTrace: stack);
        logger?.error(
          'hive',
          'Failed to recreate box "$boxName"',
          error: err,
          stackTrace: stack,
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
        _openBoxSafely<Map>(_tasksBoxName),
        _openBoxSafely<Map>(_instancesBoxName),
        _openBoxSafely<Map>(_syncMetaBoxName),
        _openBoxSafely<Map>(_settingsBoxName),
        _openBoxSafely<Map>(_recipesBoxName),
        _openBoxSafely<dynamic>(_notificationIdsBoxName),
      ]);
      _tasksBox = results[0] as Box<Map>?;
      _instancesBox = results[1] as Box<Map>?;
      _syncMetaBox = results[2] as Box<Map>?;
      _settingsBox = results[3] as Box<Map>?;
      _recipesBox = results[4] as Box<Map>?;
      _notificationIdsBox = results[5];
    } catch (e, st) {
      isFallbackInMemoryMode = true;
      errorHandler?.report(e, stackTrace: st);
      logger?.error(
        'hive',
        'Hive storage failed to initialize. Falling back to in-memory mode',
        error: e,
        stackTrace: st,
      );
    }

    _loadFromBoxes();

    _emitTasks();
    _emitInstances();
    _emitRecipes();
    _emitSettings();
    _emitSyncMeta();

    await _setupBoxWatchers();
  }

  void _loadEntityBox<T>({
    required Box<Map>? box,
    required Map<String, T> targetMap,
    required T Function(Map<String, dynamic>) fromJson,
    required String Function(T) idOf,
    required String entityName,
  }) {
    targetMap.clear();
    if (box == null || !box.isOpen) return;
    for (final map in box.values) {
      try {
        final data = Map<String, dynamic>.from(map);
        final entity = fromJson(data);
        targetMap[idOf(entity)] = entity;
      } catch (e, st) {
        errorHandler?.report(e, stackTrace: st);
        logger?.error(
          'hive',
          'Failed to parse $entityName from Hive',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  void _loadFromBoxes() {
    _loadEntityBox<TaskSchedule>(
      box: _tasksBox,
      targetMap: _memTasks,
      fromJson: _taskScheduleFromJson,
      idOf: (t) => t.id,
      entityName: 'task schedule',
    );
    _loadEntityBox<TaskInstance>(
      box: _instancesBox,
      targetMap: _memInstances,
      fromJson: _taskInstanceFromJson,
      idOf: (i) => i.id,
      entityName: 'task instance',
    );
    _loadEntityBox<Recipe>(
      box: _recipesBox,
      targetMap: _memRecipes,
      fromJson: _recipeFromJson,
      idOf: (r) => r.id,
      entityName: 'recipe',
    );

    if (_settingsBox != null && _settingsBox!.isOpen) {
      try {
        final raw = _settingsBox!.get('agile');
        if (raw != null) {
          final data = Map<String, dynamic>.from(raw);
          _memSettings = UserSettings.fromJson(data);
        }
      } catch (e, st) {
        errorHandler?.report(e, stackTrace: st);
        logger?.error(
          'hive',
          'Failed to parse settings from Hive',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  void _watchEntityBox<T>({
    required Box<Map>? box,
    required Map<String, T> targetMap,
    required T Function(Map<String, dynamic>) fromJson,
    required String Function(T) idOf,
    required String entityName,
    required VoidCallback onEmit,
  }) {
    if (box == null || !box.isOpen) return;
    _boxWatchSubscriptions.add(
      box.watch().listen((event) {
        if (_isWritingInternally) return;
        if (event.deleted) {
          targetMap.remove(event.key.toString());
        } else if (event.value != null) {
          try {
            final data = Map<String, dynamic>.from(event.value as Map);
            final entity = fromJson(data);
            targetMap[idOf(entity)] = entity;
          } catch (e, st) {
            targetMap.remove(event.key.toString());
            errorHandler?.report(e, stackTrace: st);
            logger?.error(
              'hive',
              'Failed to parse $entityName from box watcher',
              error: e,
              stackTrace: st,
            );
          }
        }
        onEmit();
      }),
    );
  }

  Future<void> _setupBoxWatchers() async {
    await _cancelBoxWatchers();

    _watchEntityBox<TaskSchedule>(
      box: _tasksBox,
      targetMap: _memTasks,
      fromJson: _taskScheduleFromJson,
      idOf: (t) => t.id,
      entityName: 'task schedule',
      onEmit: _emitTasks,
    );
    _watchEntityBox<TaskInstance>(
      box: _instancesBox,
      targetMap: _memInstances,
      fromJson: _taskInstanceFromJson,
      idOf: (i) => i.id,
      entityName: 'task instance',
      onEmit: _emitInstances,
    );
    _watchEntityBox<Recipe>(
      box: _recipesBox,
      targetMap: _memRecipes,
      fromJson: _recipeFromJson,
      idOf: (r) => r.id,
      entityName: 'recipe',
      onEmit: _emitRecipes,
    );

    if (_settingsBox != null && _settingsBox!.isOpen) {
      _boxWatchSubscriptions.add(
        _settingsBox!.watch().listen((event) {
          if (_isWritingInternally) return;
          if (event.value != null && event.key == 'agile') {
            try {
              final data = Map<String, dynamic>.from(event.value as Map);
              _memSettings = UserSettings.fromJson(data);
            } catch (e, st) {
              errorHandler?.report(e, stackTrace: st);
              logger?.error(
                'hive',
                'Failed to parse settings from box watcher',
                error: e,
                stackTrace: st,
              );
            }
          }
          _emitSettings();
        }),
      );
    }

    if (_syncMetaBox != null && _syncMetaBox!.isOpen) {
      _boxWatchSubscriptions.add(
        _syncMetaBox!.watch().listen((_) {
          if (_isWritingInternally) return;
          _emitSyncMeta();
        }),
      );
    }
  }

  Future<void> _cancelBoxWatchers() async {
    final subscriptions = List<StreamSubscription<BoxEvent>>.from(
      _boxWatchSubscriptions,
    );
    _boxWatchSubscriptions.clear();
    await Future.wait(subscriptions.map((s) => s.cancel()));
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

  Future<void> _deleteEntities<T>({
    required List<String> ids,
    required Map<String, T> memoryMap,
    required Box<Map>? box,
    required VoidCallback onEmit,
  }) async {
    if (ids.isEmpty) return;
    _isWritingInternally = true;
    try {
      for (final id in ids) {
        memoryMap.remove(id);
      }
      if (box != null && box.isOpen) {
        await box.deleteAll(ids);
      }
    } finally {
      _isWritingInternally = false;
    }
    onEmit();
  }

  Future<void> saveTask(TaskSchedule task) async {
    await saveTasks([task]);
  }

  Future<void> saveTasks(List<TaskSchedule> tasks) async {
    if (tasks.isEmpty) return;
    _isWritingInternally = true;
    try {
      final normalizedTasks = tasks.map((task) {
        if (task.updatedAt.isUtc) {
          return task;
        }
        return task.copyWith(updatedAt: task.updatedAt.toUtc());
      }).toList();

      for (final task in normalizedTasks) {
        _memTasks[task.id] = task;
      }
      if (_tasksBox != null && _tasksBox!.isOpen) {
        final entries = <String, Map<String, dynamic>>{};
        for (final task in normalizedTasks) {
          final data = task.toFirestore();
          data['id'] = task.id;
          if (data['updatedAt'] is DateTime) {
            data['updatedAt'] = (data['updatedAt'] as DateTime)
                .toUtc()
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

  Future<void> deleteTasks(List<String> ids) => _deleteEntities(
    ids: ids,
    memoryMap: _memTasks,
    box: _tasksBox,
    onEmit: _emitTasks,
  );

  Future<void> saveInstance(TaskInstance instance) async {
    await saveInstances([instance]);
  }

  Future<void> saveInstances(List<TaskInstance> instances) async {
    if (instances.isEmpty) return;
    _isWritingInternally = true;
    try {
      final normalizedInstances = instances.map((instance) {
        if (instance.updatedAt.isUtc &&
            (instance.completedAt == null || instance.completedAt!.isUtc)) {
          return instance;
        }
        return instance.copyWith(
          updatedAt: instance.updatedAt.toUtc(),
          completedAt: instance.completedAt?.toUtc(),
        );
      }).toList();

      for (final instance in normalizedInstances) {
        _memInstances[instance.id] = instance;
      }
      if (_instancesBox != null && _instancesBox!.isOpen) {
        final entries = <String, Map<String, dynamic>>{};
        for (final instance in normalizedInstances) {
          final data = instance.toFirestore();
          data['id'] = instance.id;
          if (data['updatedAt'] is DateTime) {
            data['updatedAt'] = (data['updatedAt'] as DateTime)
                .toUtc()
                .toIso8601String();
          }
          if (data['completedAt'] is DateTime) {
            data['completedAt'] = (data['completedAt'] as DateTime)
                .toUtc()
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

  Future<void> deleteInstances(List<String> ids) => _deleteEntities(
    ids: ids,
    memoryMap: _memInstances,
    box: _instancesBox,
    onEmit: _emitInstances,
  );

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

  Future<void> deleteRecipes(List<String> ids) => _deleteEntities(
    ids: ids,
    memoryMap: _memRecipes,
    box: _recipesBox,
    onEmit: _emitRecipes,
  );

  Map<dynamic, dynamic>? _getMetaEntry(String key) {
    if (_syncMetaBox != null && _syncMetaBox!.isOpen) {
      return _syncMetaBox!.get(key);
    }
    return _memMeta[key] as Map<dynamic, dynamic>?;
  }

  Future<void> _putMetaEntry(String key, Map<String, dynamic> value) async {
    if (_syncMetaBox != null && _syncMetaBox!.isOpen) {
      await _syncMetaBox!.put(key, value);
    } else {
      _memMeta[key] = value;
    }
  }

  Future<void> _deleteMetaEntry(String key) async {
    if (_syncMetaBox != null && _syncMetaBox!.isOpen) {
      await _syncMetaBox!.delete(key);
    } else {
      _memMeta.remove(key);
    }
  }

  int _getMetaCounter(String key) {
    final data = _getMetaEntry(key);
    if (data == null) return 0;
    return (data['count'] as num?)?.toInt() ?? 0;
  }

  Future<int> _incrementMetaCounter(String key) async {
    final next = _getMetaCounter(key) + 1;
    await _putMetaEntry(key, {'count': next});
    return next;
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
      await _putMetaEntry('dirty_tasks', {'list': dirtyList});
      _emitSyncMeta();
    }
  }

  List<String> getDirtyTaskIds() {
    final data = _getMetaEntry('dirty_tasks');
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
      await _putMetaEntry('dirty_tasks', {'list': dirtyList});
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

  Future<void> purgeFamilyData() async {
    final familyTaskIds = _memTasks.values
        .where((t) => t.isFamily)
        .map((t) => t.id)
        .toList();
    final familyInstanceIds = _memInstances.values
        .where((i) => i.isFamily)
        .map((i) => i.id)
        .toList();
    final familyRecipeIds = _memRecipes.values
        .where((r) => r.isFamily)
        .map((r) => r.id)
        .toList();

    await clearDirtyBatch([
      ...familyTaskIds,
      ...familyInstanceIds,
      ...familyRecipeIds,
    ]);
    await deleteTasks(familyTaskIds);
    await deleteInstances(familyInstanceIds);
    await deleteRecipes(familyRecipeIds);
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
    if (_notificationIdsBox != null && _notificationIdsBox!.isOpen) {
      await _notificationIdsBox!.clear();
    }
    _memSettings = const UserSettings(hoursAvailable: 8.0);
    _memRawSettings = {};
    _emitSettings();
  }

  String? getActiveUserId() {
    final data = _getMetaEntry('active_user_id');
    if (data == null) return null;
    return data['userId'] as String?;
  }

  Future<void> setActiveUserId(String? userId) async {
    if (userId == null) {
      await _deleteMetaEntry('active_user_id');
    } else {
      await _putMetaEntry('active_user_id', {'userId': userId});
    }
  }

  Future<void> setMigrationCompleted(bool completed) async {
    await _putMetaEntry('migration_completed', {'value': completed});
    _emitSyncMeta();
  }

  bool isMigrationCompleted() {
    final data = _getMetaEntry('migration_completed');
    if (data == null) return false;
    return data['value'] == true;
  }

  int getAppLaunchCount() => _getMetaCounter('app_launch_count');

  Future<int> incrementAppLaunchCount() =>
      _incrementMetaCounter('app_launch_count');

  int getTasksCompletedCount() => _getMetaCounter('tasks_completed_count');

  Future<int> incrementTasksCompletedCount() =>
      _incrementMetaCounter('tasks_completed_count');

  @visibleForTesting
  TaskSchedule taskScheduleFromJson(Map<String, dynamic> data) =>
      _taskScheduleFromJson(data);

  @visibleForTesting
  TaskInstance taskInstanceFromJson(Map<String, dynamic> data) =>
      _taskInstanceFromJson(data);

  TaskSchedule _taskScheduleFromJson(Map<String, dynamic> data) =>
      TaskSchedule.fromMap(data, id: data['id'] as String, isFromCache: true);

  TaskInstance _taskInstanceFromJson(Map<String, dynamic> data) =>
      TaskInstance.fromMap(data, id: data['id'] as String, isFromCache: true);

  List<Map<String, dynamic>> _exportEntityBox<T>({
    required Box<Map>? box,
    required Map<String, T> memoryMap,
    required Map<String, dynamic> Function(T) toRawMap,
    required String entityLabel,
  }) {
    final result = <Map<String, dynamic>>[];
    if (box != null && box.isOpen) {
      for (final map in box.values) {
        try {
          result.add(Map<String, dynamic>.from(map));
        } catch (e, stackTrace) {
          debugPrint('Error exporting raw $entityLabel map: $e\n$stackTrace');
        }
      }
    } else {
      for (final entity in memoryMap.values) {
        result.add(toRawMap(entity));
      }
    }
    return result;
  }

  Map<String, dynamic> exportRawState() {
    final tasksList = _exportEntityBox<TaskSchedule>(
      box: _tasksBox,
      memoryMap: _memTasks,
      toRawMap: (task) => {...task.toFirestore(), 'id': task.id},
      entityLabel: 'task',
    );

    final instancesList = _exportEntityBox<TaskInstance>(
      box: _instancesBox,
      memoryMap: _memInstances,
      toRawMap: (instance) => {...instance.toFirestore(), 'id': instance.id},
      entityLabel: 'instance',
    );

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

    final recipesList = _exportEntityBox<Recipe>(
      box: _recipesBox,
      memoryMap: _memRecipes,
      toRawMap: (recipe) => recipe.toJson(),
      entityLabel: 'recipe',
    );

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
    try {
      await _cancelBoxWatchers();
    } finally {
      await _tasksSubject.close();
      await _instancesSubject.close();
      await _recipesSubject.close();
      await _settingsSubject.close();
      await _migrationCompletedSubject.close();
      await _dirtyTaskIdsSubject.close();
    }
  }
}
