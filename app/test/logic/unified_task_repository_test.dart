import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nothing_ever_happens/logic/task_sync_service.dart';
import 'package:nothing_ever_happens/logic/hive_local_data_source.dart';
import 'package:nothing_ever_happens/logic/unified_task_repository.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/user_settings.dart';
import 'package:nothing_ever_happens/logic/telemetry_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'dart:io';

import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebaseFirestore firestore;
  late HiveLocalDataSource localDataSource;
  late TaskSyncService syncService;
  late UnifiedTaskRepository repository;
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

    localDataSource = HiveLocalDataSource();
    await localDataSource.init();
    await localDataSource.setMigrationCompleted(true);
    firestore = FakeFirebaseFirestore();

    syncService = TaskSyncService(
      firestore: firestore,
      localDataSource: localDataSource,
      userId: 'user1',
      isActivePremium: false,
    );

    repository = UnifiedTaskRepository(
      localDataSource: localDataSource,
      syncService: syncService,
      firestore: firestore,
      userId: 'user1',
    );
  });

  tearDown(() async {
    syncService.dispose();
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('addTaskSchedule, getTasks, completeTaskInstance', () async {
    final task = TaskSchedule(
      id: 'S-1',
      title: 'Test Task',
      description: 'Desc 1',
      schedules: [],
      updatedAt: DateTime.now(),
    );

    await repository.addTaskSchedule(task);

    final tasksStream = repository.getTasks();
    final tasks = await tasksStream.first;
    expect(tasks.any((t) => t.id == 'S-1'), true);

    // Dirty flag should be set for sync
    final dirtyList = localDataSource.getDirtyTaskIds();
    expect(dirtyList.contains('S-1'), true);

    final instance = TaskInstance(
      id: 'I-1',
      scheduleId: 'S-1',
      ruleId: 'R-1',
      title: 'Test Instance',
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
      status: TaskStatus.pending,
    );
    await localDataSource.saveInstance(instance);

    await repository.completeTaskInstance('I-1');

    final insts = localDataSource.getInstances();
    final updatedInst = insts.firstWhere((i) => i.id == 'I-1');
    expect(updatedInst.status, TaskStatus.completed);
  });

  test('deleteTaskSchedule and updateTaskSchedule', () async {
    final task = TaskSchedule(
      id: 'S-2',
      title: 'Delete Task',
      description: 'Desc 2',
      schedules: [],
      updatedAt: DateTime.now(),
    );
    await repository.addTaskSchedule(task);

    await repository.deleteTaskSchedule('S-2');

    final tasks = localDataSource.getTasks();
    expect(tasks.any((t) => t.id == 'S-2'), false);
  });

  test(
    'coalesces concurrent missed-policy triggers on UnifiedTaskRepository',
    () async {
      final task1 = TaskSchedule(
        id: 'U-queue-1',
        title: 'Unified Daily Task 1',
        description: 'Unified queue check 1',
        schedules: [
          DailySchedule(
            startDate: const CivilDay(year: 2026, month: 8, day: 10),
            interval: 1,
          ),
        ],
        updatedAt: DateTime.now(),
      );

      final task2 = TaskSchedule(
        id: 'U-queue-2',
        title: 'Unified Daily Task 2',
        description: 'Unified queue check 2',
        schedules: [
          DailySchedule(
            startDate: const CivilDay(year: 2026, month: 8, day: 10),
            interval: 1,
          ),
        ],
        updatedAt: DateTime.now(),
      );

      final task3 = TaskSchedule(
        id: 'U-queue-3',
        title: 'Unified Daily Task 3',
        description: 'Unified queue check 3',
        schedules: [
          DailySchedule(
            startDate: const CivilDay(year: 2026, month: 8, day: 10),
            interval: 1,
          ),
        ],
        updatedAt: DateTime.now(),
      );

      // Trigger multiple concurrent operations that call
      // triggerMissedPolicyProcessing
      final future1 = repository.addTaskSchedule(task1);
      final future2 = repository.addTaskSchedule(task2);
      final future3 = repository.addTaskSchedule(task3);
      final future4 = repository.triggerMissedPolicyProcessing();

      await Future.wait([future1, future2, future3, future4]);

      final savedTasks = localDataSource.getTasks();
      final taskIds = savedTasks.map((t) => t.id).toSet();

      expect(
        taskIds,
        containsAll(['S-U-queue-1', 'S-U-queue-2', 'S-U-queue-3']),
      );

      // Verify policy processing spawned instances for each task
      final instances = localDataSource.getInstances();
      final instanceTaskIds = instances.map((i) => i.scheduleId).toSet();
      expect(
        instanceTaskIds,
        containsAll(['S-U-queue-1', 'S-U-queue-2', 'S-U-queue-3']),
      );
    },
  );

  test('awaiting triggerMissedPolicyProcessing while in-flight completes after '
      'processing finishes', () async {
    final task = TaskSchedule(
      id: 'U-queue-4',
      title: 'Unified Task 4',
      description: 'In-flight check',
      schedules: [
        DailySchedule(
          startDate: const CivilDay(year: 2026, month: 8, day: 10),
          interval: 1,
        ),
      ],
      updatedAt: DateTime.now(),
    );

    await localDataSource.saveTask(task);

    // Launch triggerMissedPolicyProcessing concurrently
    final triggerFuture1 = repository.triggerMissedPolicyProcessing();
    final triggerFuture2 = repository.triggerMissedPolicyProcessing();

    await Future.wait([triggerFuture1, triggerFuture2]);

    final instances = localDataSource.getInstances();
    expect(instances.any((i) => i.scheduleId == 'S-U-queue-4'), isTrue);
  });

  test('updateTaskSchedule with non-schedule update (estimatedDuration) '
      're-evaluates capacity and policies', () async {
    final mockTime = DateTime(2026, 8, 10, 8, 0, 0);
    AppClock.setMockTime(mockTime);

    final taskA = TaskSchedule(
      id: 'U-task-a',
      title: 'Unified Task A',
      description: 'High priority task',
      priority: TaskPriority.high,
      estimatedDuration: const Duration(hours: 6),
      schedules: [
        DailySchedule(
          startDate: const CivilDay(year: 2026, month: 8, day: 10),
          interval: 1,
        ),
      ],
      updatedAt: DateTime.now(),
    );

    final taskB = TaskSchedule(
      id: 'U-task-b',
      title: 'Unified Task B',
      description: 'Low priority capacity task',
      priority: TaskPriority.low,
      skipIfNoCapacity: true,
      estimatedDuration: const Duration(hours: 4),
      schedules: [
        DailySchedule(
          startDate: const CivilDay(year: 2026, month: 8, day: 10),
          interval: 1,
        ),
      ],
      updatedAt: DateTime.now(),
    );

    await repository.addTaskSchedule(taskA);
    await repository.addTaskSchedule(taskB);

    final instsBefore = localDataSource.getInstances();
    final instBBefore = instsBefore.firstWhere(
      (i) => i.scheduleId == 'S-U-task-b',
    );
    expect(instBBefore.status, TaskStatus.skipped);

    // Update Task A duration from 6h to 2h (non-schedule change)
    final modA = taskA.edit(
      newTitle: taskA.title,
      newDescription: taskA.description,
      newSchedules: taskA.schedules,
      newEstimatedDuration: const Duration(hours: 2),
      newMissedPolicy: taskA.missedPolicy,
      newIsMaster: taskA.isMaster,
      newLastSpawnedDate: taskA.lastSpawnedDate,
      newIsFamily: taskA.isFamily,
      newPriority: taskA.priority,
    );

    await repository.updateTaskSchedule(modA);

    final instsAfter = localDataSource.getInstances();
    final instBAfter = instsAfter.firstWhere(
      (i) => i.scheduleId == 'S-U-task-b',
    );
    expect(instBAfter.status, TaskStatus.pending);

    AppClock.reset();
  });

  test(
    'deleteTaskSchedule triggers missed policy processing and re-evaluates capacity for remaining tasks',
    () async {
      final mockTime = DateTime(2026, 8, 10, 8, 0, 0);
      AppClock.setMockTime(mockTime);

      final taskA = TaskSchedule(
        id: 'U-del-a',
        title: 'Unified Task A to delete',
        description: 'High priority task consuming capacity',
        priority: TaskPriority.high,
        estimatedDuration: const Duration(hours: 6),
        schedules: [
          DailySchedule(
            startDate: const CivilDay(year: 2026, month: 8, day: 10),
            interval: 1,
          ),
        ],
        updatedAt: DateTime.now(),
      );

      final taskB = TaskSchedule(
        id: 'U-del-b',
        title: 'Unified Task B remaining',
        description: 'Low priority capacity task initially skipped',
        priority: TaskPriority.low,
        skipIfNoCapacity: true,
        estimatedDuration: const Duration(hours: 4),
        schedules: [
          DailySchedule(
            startDate: const CivilDay(year: 2026, month: 8, day: 10),
            interval: 1,
          ),
        ],
        updatedAt: DateTime.now(),
      );

      await repository.addTaskSchedule(taskA);
      await repository.addTaskSchedule(taskB);

      final instsBefore = localDataSource.getInstances();
      final instBBefore = instsBefore.firstWhere(
        (i) => i.scheduleId == 'S-U-del-b',
      );
      expect(instBBefore.status, TaskStatus.skipped);

      // Delete Task A, freeing up schedule capacity
      await repository.deleteTaskSchedule('S-U-del-a');

      final instsAfter = localDataSource.getInstances();
      final instBAfter = instsAfter.firstWhere(
        (i) => i.scheduleId == 'S-U-del-b',
      );
      expect(instBAfter.status, TaskStatus.pending);

      AppClock.reset();
    },
  );

  test(
    'addTaskSchedule awaits missed policy processing completion before returning',
    () async {
      final mockTime = DateTime(2026, 8, 10, 8, 0, 0);
      AppClock.setMockTime(mockTime);

      final task = TaskSchedule(
        id: 'U-await-test',
        title: 'Await Task',
        description: 'Await task description',
        schedules: [
          DailySchedule(
            startDate: const CivilDay(year: 2026, month: 8, day: 10),
            interval: 1,
          ),
        ],
        updatedAt: DateTime.now(),
      );

      await repository.addTaskSchedule(task);

      // Verify missed-policy processing completed and spawned instances
      // immediately upon addTaskSchedule completion.
      final instances = localDataSource.getInstances();
      expect(instances.any((i) => i.scheduleId == 'S-U-await-test'), isTrue);

      AppClock.reset();
    },
  );

  test(
    'triggerMissedPolicyProcessing executes all postProcess callbacks under concurrent invocation',
    () async {
      final executedCallbacks = <int>[];

      Future<void> postProcess1() async {
        await Future.delayed(const Duration(milliseconds: 10));
        executedCallbacks.add(1);
      }

      Future<void> postProcess2() async {
        await Future.delayed(const Duration(milliseconds: 10));
        executedCallbacks.add(2);
      }

      Future<void> postProcess3() async {
        await Future.delayed(const Duration(milliseconds: 10));
        executedCallbacks.add(3);
      }

      final f1 = repository.triggerMissedPolicyProcessing(
        postProcess: postProcess1,
      );
      final f2 = repository.triggerMissedPolicyProcessing(
        postProcess: postProcess2,
      );
      final f3 = repository.triggerMissedPolicyProcessing(
        postProcess: postProcess3,
      );

      await Future.wait([f1, f2, f3]);

      expect(executedCallbacks, containsAll([1, 2, 3]));
      expect(executedCallbacks.length, equals(3));
    },
  );

  test(
    'concurrent addTaskSchedule calls in UnifiedTaskRepository preserve all tasks and execute processing',
    () async {
      final mockTime = DateTime(2026, 8, 10, 8, 0, 0);
      AppClock.setMockTime(mockTime);

      final task1 = TaskSchedule(
        id: 'U-concurrent-1',
        title: 'Task 1',
        description: 'Task 1',
        schedules: [
          DailySchedule(
            startDate: const CivilDay(year: 2026, month: 8, day: 10),
            interval: 1,
          ),
        ],
        updatedAt: DateTime.now(),
      );

      final task2 = TaskSchedule(
        id: 'U-concurrent-2',
        title: 'Task 2',
        description: 'Task 2',
        schedules: [
          DailySchedule(
            startDate: const CivilDay(year: 2026, month: 8, day: 10),
            interval: 1,
          ),
        ],
        updatedAt: DateTime.now(),
      );

      await Future.wait([
        repository.addTaskSchedule(task1),
        repository.addTaskSchedule(task2),
      ]);

      final tasks = localDataSource.getTasks();
      expect(tasks.any((t) => t.id == 'S-U-concurrent-1'), isTrue);
      expect(tasks.any((t) => t.id == 'S-U-concurrent-2'), isTrue);

      final instances = localDataSource.getInstances();
      expect(instances.any((i) => i.scheduleId == 'S-U-concurrent-1'), isTrue);
      expect(instances.any((i) => i.scheduleId == 'S-U-concurrent-2'), isTrue);

      AppClock.reset();
    },
  );

  test('uses local user settings during missed policy processing', () async {
    await localDataSource.saveSettings(const UserSettings(hoursAvailable: 4.0));
    final currentSettings = localDataSource.getSettings();
    expect(currentSettings.hoursAvailable, equals(4.0));

    await repository.triggerMissedPolicyProcessing();
    expect(localDataSource.getSettings().hoursAvailable, equals(4.0));
  });

  test(
    'completing a recurring task instance does not create duplicate occurrences across evaluation passes',
    () async {
      final mockTime = DateTime(2026, 8, 15, 10, 0, 0);
      AppClock.setMockTime(mockTime);

      final task = TaskSchedule(
        id: 'U-recurring-test',
        title: 'Weigh myself',
        description: 'Daily recurring schedule',
        schedules: [
          DailySchedule(
            startDate: const CivilDay(year: 2026, month: 8, day: 15),
            interval: 1,
          ),
        ],
        updatedAt: DateTime.now(),
      );

      await repository.addTaskSchedule(task);

      // Initial state: 1 today + 10 future instances = 11 pending instances
      var instances = localDataSource
          .getInstances()
          .where((i) => i.scheduleId == 'S-U-recurring-test')
          .toList();
      expect(instances.length, equals(11));

      final todayInstance = instances.firstWhere(
        (i) => i.scheduledDate == const CivilDay(year: 2026, month: 8, day: 15),
      );

      // Complete today's instance
      await repository.completeTaskInstance(todayInstance.id);

      // Trigger missed policy processing evaluation passes
      await repository.triggerMissedPolicyProcessing();
      await repository.triggerMissedPolicyProcessing();

      instances = localDataSource
          .getInstances()
          .where((i) => i.scheduleId == 'S-U-recurring-test')
          .toList();

      final pendingInstances = instances
          .where((i) => i.status == TaskStatus.pending)
          .toList();
      final completedInstances = instances
          .where((i) => i.status == TaskStatus.completed)
          .toList();

      expect(completedInstances.length, equals(1));
      expect(pendingInstances.length, equals(10));

      // Verify no duplicate scheduledDate entries across all instances
      final dateSet = <CivilDay>{};
      for (final inst in instances) {
        expect(
          dateSet.contains(inst.scheduledDate),
          isFalse,
          reason: 'Duplicate instance found for date: ${inst.scheduledDate}',
        );
        dateSet.add(inst.scheduledDate);
      }

      AppClock.reset();
    },
  );

  test(
    'resetLocalDataAndResync clears stale local data and re-migrates from cloud',
    () async {
      // 1. Populate Firestore with cloud task
      await firestore
          .collection('users')
          .doc('user1')
          .collection('tasks')
          .doc('S-remote')
          .set({
            'id': 'S-remote',
            'title': 'Remote Cloud Task',
            'updatedAt': DateTime.now().toIso8601String(),
          });

      // 2. Put stale local task and dirty task in local storage
      final staleTask = TaskSchedule(
        id: 'S-stale',
        title: 'Stale Local Task',
        description: 'Stale',
        schedules: [],
        updatedAt: DateTime.now(),
      );
      await localDataSource.saveTask(staleTask);
      await localDataSource.markDirty('S-stale');

      expect(localDataSource.getTasks().any((t) => t.id == 'S-stale'), isTrue);
      expect(localDataSource.getDirtyTaskIds(), contains('S-stale'));

      // 3. Trigger reset & resync
      await repository.resetLocalDataAndResync();

      // 4. Verify local DB now has remote task and no stale/dirty artifacts
      final tasks = localDataSource.getTasks();
      expect(tasks.any((t) => t.id == 'S-stale'), isFalse);
      expect(tasks.any((t) => t.id == 'S-remote'), isTrue);
      expect(localDataSource.getDirtyTaskIds().isEmpty, isTrue);
      expect(localDataSource.isMigrationCompleted(), isTrue);
    },
  );

  test(
    'completeTaskInstance increments completed count and triggers telemetry',
    () async {
      String? loggedTaskId;
      String? loggedScheduleId;
      int? loggedCompletedCount;

      final fakeTelemetry = _TestTelemetryService(
        onTaskCompleted: ({scheduleId, taskId, totalCompletedCount}) async {
          loggedTaskId = taskId;
          loggedScheduleId = scheduleId;
          loggedCompletedCount = totalCompletedCount;
        },
      );

      final repoWithTelemetry = UnifiedTaskRepository(
        localDataSource: localDataSource,
        syncService: syncService,
        firestore: firestore,
        userId: 'user1',
        telemetryService: fakeTelemetry,
      );

      final instance = TaskInstance(
        id: 'I-telem-1',
        scheduleId: 'S-telem-1',
        ruleId: 'R-1',
        title: 'Telemetry Task',
        description: 'Testing telemetry on completion',
        scheduledDate: CivilDay(year: 2026, month: 8, day: 10),
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        updatedAt: DateTime.now(),
        status: TaskStatus.pending,
      );
      await localDataSource.saveInstance(instance);

      final initialCount = localDataSource.getTasksCompletedCount();
      await repoWithTelemetry.completeTaskInstance('I-telem-1');

      expect(localDataSource.getTasksCompletedCount(), initialCount + 1);
      expect(loggedTaskId, 'I-telem-1');
      expect(loggedScheduleId, 'S-telem-1');
      expect(loggedCompletedCount, initialCount + 1);
    },
  );
}

class _TestTelemetryService extends NoOpTelemetryService {
  final Future<void> Function({
    String? taskId,
    String? scheduleId,
    int? totalCompletedCount,
  })?
  onTaskCompleted;

  _TestTelemetryService({this.onTaskCompleted});

  @override
  Future<void> logTaskCompleted({
    String? taskId,
    String? scheduleId,
    int? totalCompletedCount,
  }) async {
    if (onTaskCompleted != null) {
      await onTaskCompleted!(
        taskId: taskId,
        scheduleId: scheduleId,
        totalCompletedCount: totalCompletedCount,
      );
    }
  }
}
