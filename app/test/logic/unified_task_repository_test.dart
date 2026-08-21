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
    'restoreTaskSchedule restores task and pending instances to localDataSource and marks dirty',
    () async {
      final task = TaskSchedule(
        id: 'S-restore',
        title: 'Restore Task',
        description: 'Desc restore',
        schedules: [],
        updatedAt: DateTime.now(),
      );
      final instance = TaskInstance(
        id: 'I-restore',
        scheduleId: 'S-restore',
        ruleId: 'R-restore',
        title: 'Restore Instance',
        description: 'Desc',
        scheduledDate: const CivilDay(year: 2026, month: 8, day: 16),
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        status: TaskStatus.pending,
        updatedAt: DateTime.now(),
      );

      await repository.restoreTaskSchedule(task, [instance]);

      final tasks = localDataSource.getTasks();
      expect(tasks.any((t) => t.id == 'S-restore'), true);
      final instances = localDataSource.getInstances();
      expect(instances.any((i) => i.id == 'I-restore'), true);
      final dirty = localDataSource.getDirtyTaskIds();
      expect(dirty.contains('S-restore'), true);
      expect(dirty.contains('I-restore'), true);
    },
  );

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

  test(
    'Account switch: initializing repository for different user clears old user tasks and loads new user tasks',
    () async {
      // 1. Setup User 1 tasks locally
      final user1Task = TaskSchedule(
        id: 'S-user1-task',
        title: 'User 1 Secret Task',
        description: 'User 1 Private Info',
        schedules: [],
        updatedAt: DateTime.now(),
      );
      await localDataSource.saveTask(user1Task);
      await localDataSource.setActiveUserId('user1');
      await localDataSource.setMigrationCompleted(true);

      expect(
        localDataSource.getTasks().any((t) => t.id == 'S-user1-task'),
        true,
      );

      // 2. Setup User 2 tasks in Firestore
      await firestore
          .collection('users')
          .doc('user2')
          .collection('tasks')
          .doc('S-user2-task')
          .set({
            'id': 'S-user2-task',
            'title': 'User 2 Fresh Task',
            'updatedAt': DateTime.now().toIso8601String(),
          });

      final syncServiceUser2 = TaskSyncService(
        firestore: firestore,
        localDataSource: localDataSource,
        userId: 'user2',
        isActivePremium: false,
      );

      // 3. Initialize repository for User 2
      final repoUser2 = UnifiedTaskRepository(
        localDataSource: localDataSource,
        syncService: syncServiceUser2,
        firestore: firestore,
        userId: 'user2',
      );

      // Wait for initial migration to complete
      await Future.delayed(const Duration(milliseconds: 100));

      final tasksStream = repoUser2.getTasks();
      final tasks = await tasksStream.first;

      // User 1 tasks MUST NOT be present
      expect(tasks.any((t) => t.id == 'S-user1-task'), false);

      // User 2 tasks MUST be present
      expect(tasks.any((t) => t.id == 'S-user2-task'), true);
      expect(localDataSource.getActiveUserId(), 'user2');

      syncServiceUser2.dispose();
    },
  );

  test(
    'orphan pending task instances with non-existent scheduleId are swept on missed policy processing',
    () async {
      final orphanInstance = TaskInstance(
        id: 'orphan-inst-1',
        scheduleId: 'non-existent-schedule-id',
        ruleId: 'rule-1',
        title: 'Orphan Task Instance',
        description: 'No schedule attached',
        scheduledDate: CivilDay(year: 2026, month: 8, day: 19),
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        status: TaskStatus.pending,
        updatedAt: DateTime(2026, 8, 19, 9, 0),
      );

      await localDataSource.saveInstance(orphanInstance);
      expect(
        localDataSource.getInstances().any((i) => i.id == 'orphan-inst-1'),
        true,
      );

      await repository.triggerMissedPolicyProcessing();

      expect(
        localDataSource.getInstances().any((i) => i.id == 'orphan-inst-1'),
        false,
      );
      expect(localDataSource.getDirtyTaskIds().contains('orphan-inst-1'), true);
    },
  );

  test(
    'orphan completed or skipped task instances with non-existent scheduleId are preserved',
    () async {
      final completedOrphan = TaskInstance(
        id: 'orphan-completed-1',
        scheduleId: 'non-existent-schedule-id',
        ruleId: 'rule-1',
        title: 'Completed Orphan Instance',
        description: 'Completed history preserved',
        scheduledDate: CivilDay(year: 2026, month: 8, day: 19),
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        status: TaskStatus.completed,
        completedAt: DateTime(2026, 8, 19, 10, 0),
        updatedAt: DateTime(2026, 8, 19, 10, 0),
      );

      final skippedOrphan = TaskInstance(
        id: 'orphan-skipped-1',
        scheduleId: 'non-existent-schedule-id',
        ruleId: 'rule-1',
        title: 'Skipped Orphan Instance',
        description: 'Skipped history preserved',
        scheduledDate: CivilDay(year: 2026, month: 8, day: 19),
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        status: TaskStatus.skipped,
        updatedAt: DateTime(2026, 8, 19, 10, 0),
      );

      await localDataSource.saveInstance(completedOrphan);
      await localDataSource.saveInstance(skippedOrphan);

      await repository.triggerMissedPolicyProcessing();

      final instances = localDataSource.getInstances();
      expect(instances.any((i) => i.id == 'orphan-completed-1'), true);
      expect(instances.any((i) => i.id == 'orphan-skipped-1'), true);
    },
  );

  test(
    'UnifiedTaskRepository handles individual family task completion and undo correctly',
    () async {
      const familyId = 'fam-unified';
      const user1 = 'user1';
      const user2 = 'user2';

      await firestore.collection('families').doc(familyId).set({
        'name': 'Unified Fam',
        'members': {
          user1: {'role': 'parent', 'displayName': 'User 1'},
          user2: {'role': 'child', 'displayName': 'User 2'},
        },
      });
      await firestore.collection('users').doc(user1).set({
        'familyId': familyId,
      });

      final task = TaskSchedule(
        id: 'U-indiv-fam',
        title: 'Walk the dog',
        description: 'Everyone walks the dog once',
        isFamily: true,
        familyCompletionMode: FamilyCompletionMode.individual,
      );
      await repository.addTaskSchedule(task);

      final instance = TaskInstance(
        id: 'I-indiv-fam-1',
        scheduleId: 'S-U-indiv-fam',
        ruleId: 'R-1',
        title: task.title,
        description: task.description,
        scheduledDate: const CivilDay(year: 2026, month: 8, day: 19),
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 8, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 20, minute: 0),
        ),
        isFamily: true,
        familyCompletionMode: FamilyCompletionMode.individual,
        status: TaskStatus.pending,
      );
      await localDataSource.saveInstance(instance);

      // User 1 completes
      final result1 = await repository.completeTaskInstance(instance.id);
      expect(result1?.status, TaskStatus.pending);
      expect(result1?.completedByUserIds, [user1]);

      var savedInst = localDataSource.getInstances().firstWhere(
        (i) => i.id == instance.id,
      );
      expect(savedInst.status, TaskStatus.pending);
      expect(savedInst.completedByUserIds, [user1]);

      // Undo user 1 completion
      await repository.undoResolveTaskInstance(savedInst);
      savedInst = localDataSource.getInstances().firstWhere(
        (i) => i.id == instance.id,
      );
      expect(savedInst.status, TaskStatus.pending);
      expect(savedInst.completedByUserIds, isEmpty);
    },
  );

  test(
    'missed policy processing batches instance persistence and dirty marking',
    () async {
      final trackingDataSource = _TrackingHiveLocalDataSource();
      await trackingDataSource.init();
      await trackingDataSource.setMigrationCompleted(true);

      final trackingSync = TaskSyncService(
        firestore: firestore,
        localDataSource: trackingDataSource,
        userId: 'user1',
        isActivePremium: false,
      );

      final trackingRepo = UnifiedTaskRepository(
        localDataSource: trackingDataSource,
        syncService: trackingSync,
        firestore: firestore,
        userId: 'user1',
      );

      try {
        final now = AppClock.now;
        final today = CivilDay.fromDateTime(now);

        // Add two task schedules that each spawn instances
        final task1 = TaskSchedule(
          id: 'S-Batch-1',
          title: 'Batch Task 1',
          description: 'Batch Desc 1',
          schedules: [DailySchedule(startDate: today, interval: 1)],
          updatedAt: now,
        );

        final task2 = TaskSchedule(
          id: 'S-Batch-2',
          title: 'Batch Task 2',
          description: 'Batch Desc 2',
          schedules: [DailySchedule(startDate: today, interval: 1)],
          updatedAt: now,
        );

        // Also add an orphan instance to test batched deletion sweep
        final orphanInstance = TaskInstance(
          id: 'I-Orphan',
          scheduleId: 'NonExistentSchedule',
          ruleId: 'R-Orphan',
          title: 'Orphan',
          description: 'Orphan Desc',
          scheduledDate: today,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 7, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 8, minute: 0),
          ),
          status: TaskStatus.pending,
        );
        await trackingDataSource.saveInstance(orphanInstance);
        await trackingDataSource.saveTasks([task1, task2]);

        // Reset tracking counters before running triggerMissedPolicyProcessing
        trackingDataSource.resetCounts();

        await trackingRepo.triggerMissedPolicyProcessing();

        // Verify batch methods were called at most once per operation type
        expect(trackingDataSource.saveInstanceCallCount, 0);
        expect(trackingDataSource.deleteInstanceCallCount, 0);
        expect(trackingDataSource.markDirtyCallCount, 0);

        expect(trackingDataSource.saveInstancesCallCount, 1);
        expect(trackingDataSource.deleteInstancesCallCount, 1);
        expect(trackingDataSource.markDirtyBatchCallCount, 1);

        // Verify instances were saved and orphan was deleted
        final instances = trackingDataSource.getInstances();
        expect(instances.any((i) => i.id == 'I-Orphan'), false);
        expect(instances.any((i) => i.scheduleId == 'S-Batch-1'), true);
        expect(instances.any((i) => i.scheduleId == 'S-Batch-2'), true);
      } finally {
        trackingSync.dispose();
        trackingDataSource.dispose();
      }
    },
  );
}

class _TrackingHiveLocalDataSource extends HiveLocalDataSource {
  int saveInstancesCallCount = 0;
  int deleteInstancesCallCount = 0;
  int saveTasksCallCount = 0;
  int markDirtyBatchCallCount = 0;
  int saveInstanceCallCount = 0;
  int deleteInstanceCallCount = 0;
  int markDirtyCallCount = 0;

  void resetCounts() {
    saveInstancesCallCount = 0;
    deleteInstancesCallCount = 0;
    saveTasksCallCount = 0;
    markDirtyBatchCallCount = 0;
    saveInstanceCallCount = 0;
    deleteInstanceCallCount = 0;
    markDirtyCallCount = 0;
  }

  @override
  Future<void> saveInstances(List<TaskInstance> instances) async {
    saveInstancesCallCount++;
    await super.saveInstances(instances);
  }

  @override
  Future<void> saveInstance(TaskInstance instance) async {
    saveInstanceCallCount++;
    await super.saveInstance(instance);
  }

  @override
  Future<void> deleteInstances(List<String> ids) async {
    deleteInstancesCallCount++;
    await super.deleteInstances(ids);
  }

  @override
  Future<void> deleteInstance(String id) async {
    deleteInstanceCallCount++;
    await super.deleteInstance(id);
  }

  @override
  Future<void> saveTasks(List<TaskSchedule> tasks) async {
    saveTasksCallCount++;
    await super.saveTasks(tasks);
  }

  @override
  Future<void> markDirtyBatch(List<String> ids) async {
    markDirtyBatchCallCount++;
    await super.markDirtyBatch(ids);
  }

  @override
  Future<void> markDirty(String id) async {
    markDirtyCallCount++;
    await super.markDirty(id);
  }
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
