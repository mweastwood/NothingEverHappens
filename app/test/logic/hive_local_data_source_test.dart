import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nothing_ever_happens/logic/hive_local_data_source.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/user_settings.dart';
import 'package:nothing_ever_happens/logic/error_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HiveLocalDataSource dataSource;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getApplicationDocumentsDirectory') {
              return tempDir.path;
            }
            return null;
          },
        );

    dataSource = HiveLocalDataSource();
    await dataSource.init();
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('Test CRUD operations on tasksBox', () async {
    final task = TaskSchedule(
      id: 'S-task1',
      title: 'Task 1',
      description: 'Desc 1',
      schedules: [],
      activeOccurrenceIndex: 0,
      updatedAt: DateTime.now(),
    );

    await dataSource.saveTask(task);

    final tasks = dataSource.getTasks();
    expect(tasks.length, 1);
    expect(tasks.first.id, 'S-task1');
    expect(tasks.first.title, 'Task 1');

    await dataSource.deleteTask('S-task1');
    final afterDelete = dataSource.getTasks();
    expect(afterDelete.isEmpty, true);
  });

  test('persists and deserializes TaskSchedule appLaunchUrl properly', () async {
    final rawMap = {
      'id': 'S-task-url',
      'title': 'Duolingo Daily',
      'description': 'Practice languages',
      'appLaunchUrl': 'duolingo://app',
      'schedules': <dynamic>[],
      'updatedAt': DateTime.now().toIso8601String(),
    };

    final deserialized = dataSource.taskScheduleFromJson(rawMap);
    expect(deserialized.id, 'S-task-url');
    expect(deserialized.appLaunchUrl, 'duolingo://app');

    final taskWithUrl = TaskSchedule(
      id: 'S-task-url',
      title: 'Duolingo Daily',
      description: 'Practice languages',
      appLaunchUrl: 'duolingo://app',
      schedules: [],
      updatedAt: DateTime.now(),
    );

    await dataSource.saveTask(taskWithUrl);

    // Reinitialize a secondary dataSource instance to load from the persisted box and exercise _taskScheduleFromJson
    final secondDataSource = HiveLocalDataSource();
    await secondDataSource.init();
    final tasks = secondDataSource.getTasks();
    final retrieved = tasks.firstWhere((t) => t.id == 'S-task-url');
    expect(retrieved.appLaunchUrl, 'duolingo://app');
    await secondDataSource.dispose();
  });

  test('Test CRUD operations on instancesBox', () async {
    final instance = TaskInstance(
      id: 'I-inst1',
      scheduleId: 'S-task1',
      ruleId: 'rule1',
      title: 'Inst 1',
      description: 'Desc 1',
      scheduledDate: CivilDay(year: 2026, month: 8, day: 4),
      startRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 9, minute: 0),
      ),
      dueRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 17, minute: 0),
      ),
      updatedAt: DateTime.now(),
    );

    await dataSource.saveInstance(instance);

    final instances = dataSource.getInstances();
    expect(instances.length, 1);
    expect(instances.first.id, 'I-inst1');

    await dataSource.deleteInstance('I-inst1');
    final afterDelete = dataSource.getInstances();
    expect(afterDelete.isEmpty, true);
  });

  test('Test stream emissions from watchTasks() and watchInstances()', () async {
    final task = TaskSchedule(
      id: 'S-task2',
      title: 'Task 2',
      description: 'Desc 2',
      schedules: [],
      updatedAt: DateTime.now(),
    );
    final instance = TaskInstance(
      id: 'I-inst2',
      scheduleId: 'S-task2',
      ruleId: 'rule1',
      title: 'Inst 2',
      description: 'Desc 2',
      scheduledDate: CivilDay(year: 2026, month: 8, day: 4),
      startRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 9, minute: 0),
      ),
      dueRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 17, minute: 0),
      ),
      updatedAt: DateTime.now(),
    );

    bool taskEmitted = false;
    bool instanceEmitted = false;

    final tSub = dataSource.watchTasks().listen((tasks) {
      if (tasks.any((t) => t.id == 'S-task2')) taskEmitted = true;
    });
    final iSub = dataSource.watchInstances().listen((instances) {
      if (instances.any((i) => i.id == 'I-inst2')) instanceEmitted = true;
    });

    await dataSource.saveTask(task);
    await dataSource.saveInstance(instance);

    await Future.delayed(const Duration(milliseconds: 200));

    expect(taskEmitted, true);

    // Check if it's in the box directly
    final directInstances = dataSource.getInstances();
    expect(
      directInstances.any((i) => i.id == 'I-inst2'),
      true,
      reason:
          'Instance not found in box directly. Instances: ${directInstances.map((i) => i.id).toList()}',
    );

    expect(instanceEmitted, true, reason: 'Stream did not emit instance');

    await tSub.cancel();
    await iSub.cancel();
  });

  test('Test dirty tracking', () async {
    await dataSource.markDirty('task3');
    final dirtyList1 = dataSource.getDirtyTaskIds();
    expect(dirtyList1, contains('task3'));

    await dataSource.markDirty('inst3');
    final dirtyList2 = dataSource.getDirtyTaskIds();
    expect(dirtyList2, contains('task3'));
    expect(dirtyList2, contains('inst3'));

    await dataSource.clearDirty('task3');
    final dirtyList3 = dataSource.getDirtyTaskIds();
    expect(dirtyList3, isNot(contains('task3')));
    expect(dirtyList3, contains('inst3'));
  });

  test(
    'Test taskScheduleFromJson handles non-boolean preferredBy values safely',
    () async {
      final rawTaskMap = {
        'id': 'task-non-bool',
        'title': 'Non-bool preferredBy Task',
        'description': 'Testing type safety',
        'schedules': <dynamic>[],
        'preferredBy': {
          'user1': true,
          'user2': false,
          'user3': null,
          'user4': 'invalid',
          'user5': 123,
        },
        'updatedAt': DateTime.now().toIso8601String(),
      };

      final task = dataSource.taskScheduleFromJson(rawTaskMap);
      expect(task.id, 'S-task-non-bool');
      expect(task.preferredBy['user1'], true);
      expect(task.preferredBy['user2'], false);
      expect(task.preferredBy['user3'], false);
      expect(task.preferredBy['user4'], false);
      expect(task.preferredBy['user5'], false);
    },
  );

  test('HiveLocalDataSource reports parsing errors to ErrorHandler', () async {
    final errorHandler = ErrorHandler();
    final customDataSource = HiveLocalDataSource(errorHandler: errorHandler);
    await customDataSource.init();

    // 1. Corrupt settings in settingsBox
    final settingsBox = Hive.box<Map>('settingsBox');
    await settingsBox.put('agile', {'hoursAvailable': 'invalid_double'});
    final settings = customDataSource.getSettings();
    expect(settings.hoursAvailable, 8.0);
    expect(errorHandler.history.isNotEmpty, true);

    // 2. Corrupt task in tasksBox
    final tasksBox = Hive.box<Map>('tasksBox');
    await tasksBox.put('corrupt-task', {'id': 123, 'schedules': 'invalid'});
    final tasks = customDataSource.getTasks();
    expect(tasks.isEmpty, true);
    expect(errorHandler.history.length >= 2, true);

    // 3. Corrupt instance in instancesBox
    final instancesBox = Hive.box<Map>('instancesBox');
    await instancesBox.put('corrupt-inst', {
      'id': 456,
      'scheduledDate': 'invalid',
    });
    final instances = customDataSource.getInstances();
    expect(instances.isEmpty, true);
    expect(errorHandler.history.length >= 3, true);
  });

  test(
    'clearAllTasksAndInstances, clearAllDirty, and resetAllData work correctly',
    () async {
      final task = TaskSchedule(
        id: 'S-clear-test',
        title: 'Clear Test',
        description: 'Desc',
        schedules: [],
        updatedAt: DateTime.now(),
      );
      final instance = TaskInstance(
        id: 'I-clear-test',
        scheduleId: 'S-clear-test',
        ruleId: 'rule1',
        title: 'Clear Inst',
        description: 'Desc',
        scheduledDate: CivilDay(year: 2026, month: 8, day: 15),
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        updatedAt: DateTime.now(),
      );

      await dataSource.saveTask(task);
      await dataSource.saveInstance(instance);
      await dataSource.markDirty('S-clear-test');
      await dataSource.setMigrationCompleted(true);

      expect(dataSource.getTasks().length, 1);
      expect(dataSource.getInstances().length, 1);
      expect(dataSource.getDirtyTaskIds().length, 1);
      expect(dataSource.isMigrationCompleted(), true);

      await dataSource.clearAllTasksAndInstances();
      expect(dataSource.getTasks().isEmpty, true);
      expect(dataSource.getInstances().isEmpty, true);
      expect(dataSource.getDirtyTaskIds().length, 1);

      await dataSource.clearAllDirty();
      expect(dataSource.getDirtyTaskIds().isEmpty, true);

      await dataSource.saveTask(task);
      await dataSource.markDirty('S-clear-test');
      await dataSource.setActiveUserId('user-abc');
      await dataSource.saveSettings(const UserSettings(hoursAvailable: 4.5));
      expect(dataSource.getTasks().length, 1);
      expect(dataSource.getActiveUserId(), 'user-abc');
      expect(dataSource.getSettings().hoursAvailable, 4.5);

      await dataSource.resetAllData();
      expect(dataSource.getTasks().isEmpty, true);
      expect(dataSource.getInstances().isEmpty, true);
      expect(dataSource.getDirtyTaskIds().isEmpty, true);
      expect(dataSource.isMigrationCompleted(), false);
      expect(dataSource.getActiveUserId(), isNull);
      expect(dataSource.getSettings().hoursAvailable, 8.0);
    },
  );

  test(
    'getActiveUserId and setActiveUserId persist and clear correctly',
    () async {
      expect(dataSource.getActiveUserId(), isNull);

      await dataSource.setActiveUserId('user-123');
      expect(dataSource.getActiveUserId(), 'user-123');

      await dataSource.setActiveUserId('user-456');
      expect(dataSource.getActiveUserId(), 'user-456');

      await dataSource.setActiveUserId(null);
      expect(dataSource.getActiveUserId(), isNull);
    },
  );

  test('watchMigrationCompleted emits reactive updates', () async {
    final emissions = <bool>[];
    final sub = dataSource.watchMigrationCompleted().listen(emissions.add);

    await dataSource.setMigrationCompleted(true);
    await dataSource.setMigrationCompleted(false);
    await dataSource.setMigrationCompleted(true);

    await Future.delayed(const Duration(milliseconds: 100));

    expect(emissions, containsAllInOrder([false, true, false, true]));
    await sub.cancel();
  });

  test('dispose closes all streams and stream controllers', () async {
    bool tasksDone = false;
    bool instancesDone = false;
    bool settingsDone = false;
    bool migrationDone = false;

    dataSource.watchTasks().listen(null, onDone: () => tasksDone = true);
    dataSource.watchInstances().listen(
      null,
      onDone: () => instancesDone = true,
    );
    dataSource.watchSettings().listen(null, onDone: () => settingsDone = true);
    dataSource.watchMigrationCompleted().listen(
      null,
      onDone: () => migrationDone = true,
    );

    await dataSource.dispose();
    await pumpEventQueue();

    expect(tasksDone, isTrue);
    expect(instancesDone, isTrue);
    expect(settingsDone, isTrue);
    expect(migrationDone, isTrue);
  });

  test(
    'init() concurrently opens all 5 boxes and initializes state cleanly',
    () async {
      final customDataSource = HiveLocalDataSource();
      await customDataSource.init();

      expect(customDataSource.isFallbackInMemoryMode, isFalse);
      expect(Hive.isBoxOpen('tasksBox'), isTrue);
      expect(Hive.isBoxOpen('instancesBox'), isTrue);
      expect(Hive.isBoxOpen('syncMetaBox'), isTrue);
      expect(Hive.isBoxOpen('settingsBox'), isTrue);
      expect(Hive.isBoxOpen('recipesBox'), isTrue);

      await customDataSource.dispose();
    },
  );

  test(
    'Batch operations saveInstances, deleteInstances, markDirtyBatch, clearDirtyBatch work efficiently',
    () async {
      final instances = List.generate(
        100,
        (i) => TaskInstance(
          id: 'I-batch-$i',
          scheduleId: 'S-batch',
          ruleId: 'rule1',
          title: 'Batch Inst $i',
          description: 'Desc',
          scheduledDate: CivilDay(year: 2026, month: 8, day: 19),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          updatedAt: DateTime.now(),
        ),
      );

      // Save batch
      await dataSource.saveInstances(instances);
      expect(dataSource.getInstances().length, 100);

      // Mark dirty batch
      final dirtyIds = instances.map((i) => i.id).toList();
      await dataSource.markDirtyBatch(dirtyIds);
      expect(dataSource.getDirtyTaskIds().length, 100);

      // Clear dirty batch
      await dataSource.clearDirtyBatch(dirtyIds.sublist(0, 50));
      expect(dataSource.getDirtyTaskIds().length, 50);

      // Delete instances batch
      final deleteIds = instances.sublist(0, 50).map((i) => i.id).toList();
      await dataSource.deleteInstances(deleteIds);
      expect(dataSource.getInstances().length, 50);
    },
  );

  test('cancels box watch subscriptions on dispose', () async {
    final ds = HiveLocalDataSource();
    await ds.init();

    await ds.dispose();

    final tasksBox = await Hive.openBox<Map>('tasksBox');
    await tasksBox.put('S-post-dispose', {
      'id': 'S-post-dispose',
      'title': 'Post dispose task',
      'description': 'Desc',
      'schedules': <dynamic>[],
      'updatedAt': DateTime.now().toIso8601String(),
    });

    final instancesBox = await Hive.openBox<Map>('instancesBox');
    await instancesBox.put('I-post-dispose', {
      'id': 'I-post-dispose',
      'taskId': 'S-post-dispose',
      'civilDay': 20260826,
      'due': DateTime.now().toIso8601String(),
      'status': 'pending',
      'updatedAt': DateTime.now().toIso8601String(),
    });

    final recipesBox = await Hive.openBox<Map>('recipesBox');
    await recipesBox.put('R-post-dispose', {
      'id': 'R-post-dispose',
      'title': 'Post dispose recipe',
      'servings': 2,
      'ingredients': <dynamic>[],
      'steps': <dynamic>[],
      'updatedAt': DateTime.now().toIso8601String(),
    });

    final settingsBox = await Hive.openBox<Map>('settingsBox');
    await settingsBox.put('agile', {
      'workingHoursStart': 9,
      'workingHoursEnd': 17,
    });

    final syncMetaBox = await Hive.openBox<Map>('syncMetaBox');
    await syncMetaBox.put('dirty_tasks', {
      'list': ['S-post-dispose'],
    });
  });
}
