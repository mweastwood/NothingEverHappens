import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nothing_ever_happens/logic/task_sync_service.dart';
import 'package:nothing_ever_happens/logic/hive_local_data_source.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/recipes/recipe.dart';
import 'package:nothing_ever_happens/logic/error_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebaseFirestore firestore;
  late HiveLocalDataSource localDataSource;
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
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('Free User (isActivePremium == false) does not sync', () async {
    final service = TaskSyncService(
      firestore: firestore,
      localDataSource: localDataSource,
      userId: 'user1',
      isActivePremium: false,
    );
    addTearDown(() => service.dispose());
    addTearDown(() => service.dispose());

    final task = TaskSchedule(
      id: 'S-1',
      title: 'Task 1',
      description: 'Desc 1',
      schedules: [],
      updatedAt: DateTime.now(),
    );
    await localDataSource.saveTask(task);
    await localDataSource.markDirty('S-1');

    await service.sync();

    final docSnap = await firestore
        .collection('users')
        .doc('user1')
        .collection('tasks')
        .doc('S-1')
        .get();
    expect(docSnap.exists, false);
  });

  test(
    'Unmigrated user (isMigrationCompleted == false) does not sync to remote',
    () async {
      await localDataSource.setMigrationCompleted(false);
      final service = TaskSyncService(
        firestore: firestore,
        localDataSource: localDataSource,
        userId: 'user1',
        isActivePremium: true,
      );
      addTearDown(() => service.dispose());

      final task = TaskSchedule(
        id: 'S-unmigrated',
        title: 'Unmigrated Task',
        description: 'Desc',
        schedules: [],
        updatedAt: DateTime.now(),
      );
      await localDataSource.saveTask(task);
      await localDataSource.markDirty('S-unmigrated');

      await service.sync();

      final docSnap = await firestore
          .collection('users')
          .doc('user1')
          .collection('tasks')
          .doc('S-unmigrated')
          .get();
      expect(docSnap.exists, false);
    },
  );

  test(
    'startListeningToRemote does not attach listeners when isMigrationCompleted is false',
    () async {
      await localDataSource.setMigrationCompleted(false);
      final service = TaskSyncService(
        firestore: firestore,
        localDataSource: localDataSource,
        userId: 'user1',
        isActivePremium: true,
      );
      addTearDown(() => service.dispose());

      service.startListeningToRemote();

      // Remote update in Firestore should not be copied to Hive because listeners are not active
      final remoteTask = TaskSchedule(
        id: 'S-remote-unmigrated',
        title: 'Remote Task',
        description: 'Desc',
        schedules: [],
        updatedAt: DateTime(2026, 8, 4, 10, 0),
      );
      await firestore
          .collection('users')
          .doc('user1')
          .collection('tasks')
          .doc('S-remote-unmigrated')
          .set(remoteTask.toFirestore());

      // Flush event queue to process any stream events if active
      await pumpEventQueue();

      final localTask = localDataSource
          .getTasks()
          .where((t) => t.id == 'S-remote-unmigrated')
          .firstOrNull;
      expect(localTask, isNull);
    },
  );

  test('Subscribed User bi-directional sync', () async {
    final service = TaskSyncService(
      firestore: firestore,
      localDataSource: localDataSource,
      userId: 'user1',
      isActivePremium: true,
    );
    addTearDown(() => service.dispose());

    // Sync Hive to Firestore
    final localTime = DateTime(2026, 8, 4, 10, 0);
    final task = TaskSchedule(
      id: 'S-1',
      title: 'Task 1',
      description: 'Desc 1',
      schedules: [],
      updatedAt: localTime,
    );
    await localDataSource.saveTask(task);
    await localDataSource.markDirty('S-1');

    await service.sync();

    var docSnap = await firestore
        .collection('users')
        .doc('user1')
        .collection('tasks')
        .doc('S-1')
        .get();
    expect(docSnap.exists, true);
    expect(docSnap.data()?['title'], 'Task 1');

    // Sync Firestore to Hive
    final remoteTime = DateTime(2026, 8, 4, 11, 0);
    await firestore
        .collection('users')
        .doc('user1')
        .collection('tasks')
        .doc('S-2')
        .set({
          'id': 'S-2',
          'title': 'Remote Task',
          'description': 'Desc 2',
          'updatedAt': remoteTime.toIso8601String(),
        });

    await pumpEventQueue();

    final tasks = localDataSource.getTasks();
    expect(tasks.any((t) => t.id == 'S-2'), true);
  });

  test('Conflict Resolution Strategy: Local wins', () async {
    final service = TaskSyncService(
      firestore: firestore,
      localDataSource: localDataSource,
      userId: 'user1',
      isActivePremium: true,
    );
    addTearDown(() => service.dispose());
    // Ignore unused warning
    expect(service, isNotNull);

    final localTime = DateTime(2026, 8, 4, 12, 0);
    final remoteTime = DateTime(2026, 8, 4, 10, 0);

    final task = TaskSchedule(
      id: 'S-1',
      title: 'Local Title',
      description: 'Desc 1',
      schedules: [],
      updatedAt: localTime,
    );
    await localDataSource.saveTask(task);

    await firestore
        .collection('users')
        .doc('user1')
        .collection('tasks')
        .doc('S-1')
        .set({
          'id': 'S-1',
          'title': 'Remote Title',
          'description': 'Desc 1',
          'updatedAt': remoteTime.toIso8601String(),
        });

    await pumpEventQueue();

    final docSnap = await firestore
        .collection('users')
        .doc('user1')
        .collection('tasks')
        .doc('S-1')
        .get();
    expect(docSnap.data()?['title'], 'Local Title');
  });

  test('Conflict Resolution Strategy: Remote wins', () async {
    final service = TaskSyncService(
      firestore: firestore,
      localDataSource: localDataSource,
      userId: 'user1',
      isActivePremium: true,
    );
    addTearDown(() => service.dispose());
    expect(service, isNotNull);

    final localTime = DateTime(2026, 8, 4, 10, 0);
    final remoteTime = DateTime(2026, 8, 4, 12, 0);

    final task = TaskSchedule(
      id: 'S-1',
      title: 'Local Title',
      description: 'Desc 1',
      schedules: [],
      updatedAt: localTime,
    );
    await localDataSource.saveTask(task);

    await firestore
        .collection('users')
        .doc('user1')
        .collection('tasks')
        .doc('S-1')
        .set({
          'id': 'S-1',
          'title': 'Remote Title',
          'description': 'Desc 1',
          'updatedAt': remoteTime.toIso8601String(),
        });

    await pumpEventQueue();

    final localTask = localDataSource.getTasks().firstWhere(
      (t) => t.id == 'S-1',
    );
    expect(localTask.title, 'Remote Title');
  });

  test(
    'resolves remote instance with different UUID on the same slot based on updatedAt',
    () async {
      final service = TaskSyncService(
        firestore: firestore,
        localDataSource: localDataSource,
        userId: 'user1',
        isActivePremium: true,
      );
      addTearDown(() => service.dispose());

      final t1 = DateTime(2026, 8, 15, 10, 0);
      final t2 = DateTime(2026, 8, 15, 12, 0);

      final localInst = TaskInstance(
        id: 'I-1',
        scheduleId: 'S-100',
        ruleId: 'R-100',
        title: 'Local Instance',
        description: 'Local desc',
        scheduledDate: const CivilDay(year: 2026, month: 8, day: 15),
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        status: TaskStatus.pending,
        updatedAt: t1,
      );
      await localDataSource.saveInstance(localInst);

      final remoteInst = TaskInstance(
        id: 'I-2',
        scheduleId: 'S-100',
        ruleId: 'R-100',
        title: 'Remote Instance (Newer)',
        description: 'Remote desc',
        scheduledDate: const CivilDay(year: 2026, month: 8, day: 15),
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        status: TaskStatus.completed,
        updatedAt: t2,
      );

      await firestore
          .collection('users')
          .doc('user1')
          .collection('instances')
          .doc('I-2')
          .set(remoteInst.toFirestore());

      await pumpEventQueue();

      final instances = localDataSource.getInstances();
      expect(instances.any((i) => i.id == 'I-1'), isFalse);
      expect(instances.any((i) => i.id == 'I-2'), isTrue);
      final savedRemote = instances.firstWhere((i) => i.id == 'I-2');
      expect(savedRemote.title, 'Remote Instance (Newer)');
      expect(savedRemote.status, TaskStatus.completed);
    },
  );

  test(
    'pushes local winner and deletes remote loser when local updatedAt is newer',
    () async {
      final service = TaskSyncService(
        firestore: firestore,
        localDataSource: localDataSource,
        userId: 'user1',
        isActivePremium: true,
      );
      addTearDown(() => service.dispose());

      final t1 = DateTime(2026, 8, 15, 10, 0);
      final t2 = DateTime(2026, 8, 15, 12, 0);

      final localInst = TaskInstance(
        id: 'I-1',
        scheduleId: 'S-100',
        ruleId: 'R-100',
        title: 'Local Instance (Newer)',
        description: 'Local desc',
        scheduledDate: const CivilDay(year: 2026, month: 8, day: 15),
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        status: TaskStatus.completed,
        updatedAt: t2,
      );
      await localDataSource.saveInstance(localInst);

      final remoteInst = TaskInstance(
        id: 'I-2',
        scheduleId: 'S-100',
        ruleId: 'R-100',
        title: 'Remote Instance (Older)',
        description: 'Remote desc',
        scheduledDate: const CivilDay(year: 2026, month: 8, day: 15),
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        status: TaskStatus.pending,
        updatedAt: t1,
      );

      await firestore
          .collection('users')
          .doc('user1')
          .collection('instances')
          .doc('I-2')
          .set(remoteInst.toFirestore());

      await pumpEventQueue();

      final instances = localDataSource.getInstances();
      expect(instances.any((i) => i.id == 'I-1'), isTrue);
      expect(instances.any((i) => i.id == 'I-2'), isFalse);

      final dirtyIds = localDataSource.getDirtyTaskIds();
      expect(dirtyIds, contains('I-1'));

      final remoteLoserSnap = await firestore
          .collection('users')
          .doc('user1')
          .collection('instances')
          .doc('I-2')
          .get();
      expect(remoteLoserSnap.exists, isFalse);

      final remoteWinnerSnap = await firestore
          .collection('users')
          .doc('user1')
          .collection('instances')
          .doc('I-1')
          .get();
      expect(remoteWinnerSnap.exists, isTrue);
      expect(remoteWinnerSnap.data()?['title'], 'Local Instance (Newer)');
    },
  );

  test(
    'TaskSyncService reports errors to ErrorHandler during failed sync',
    () async {
      final errorHandler = ErrorHandler();
      final failingLocalDataSource = _FailingHiveLocalDataSource();
      final service = TaskSyncService(
        firestore: firestore,
        localDataSource: failingLocalDataSource,
        userId: 'user1',
        isActivePremium: true,
        errorHandler: errorHandler,
      );
      addTearDown(() => service.dispose());

      await service.sync();

      expect(errorHandler.history.isNotEmpty, true);
      expect(
        errorHandler.history.first.error.toString(),
        contains('Simulated local data source failure'),
      );
    },
  );

  test(
    'Family tasks and instances are pushed to families/{familyId} collection',
    () async {
      await firestore.collection('users').doc('user1').set({
        'familyId': 'fam1',
      });

      final service = TaskSyncService(
        firestore: firestore,
        localDataSource: localDataSource,
        userId: 'user1',
        isActivePremium: true,
      );
      addTearDown(() => service.dispose());

      final familyTask = TaskSchedule(
        id: 'S-fam1',
        title: 'Family Task',
        description: 'Clean Kitchen',
        isFamily: true,
        schedules: [],
        updatedAt: DateTime.now(),
      );

      final familyInstance = TaskInstance(
        id: 'I-fam1',
        scheduleId: 'S-fam1',
        ruleId: 'R-1',
        title: 'Family Task',
        description: 'Clean Kitchen',
        scheduledDate: CivilDay(year: 2026, month: 8, day: 16),
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 23, minute: 0),
        ),
        isFamily: true,
        updatedAt: DateTime.now(),
      );

      await localDataSource.saveTask(familyTask);
      await localDataSource.saveInstance(familyInstance);
      await localDataSource.markDirty('S-fam1');
      await localDataSource.markDirty('I-fam1');

      await service.sync();

      // Should be in families/fam1/tasks and families/fam1/instances
      final familyTaskDoc = await firestore
          .collection('families')
          .doc('fam1')
          .collection('tasks')
          .doc('S-fam1')
          .get();
      expect(familyTaskDoc.exists, isTrue);
      expect(familyTaskDoc.data()?['title'], 'Family Task');
      expect(familyTaskDoc.data()?['isFamily'], isTrue);

      final familyInstDoc = await firestore
          .collection('families')
          .doc('fam1')
          .collection('instances')
          .doc('I-fam1')
          .get();
      expect(familyInstDoc.exists, isTrue);
      expect(familyInstDoc.data()?['title'], 'Family Task');
      expect(familyInstDoc.data()?['isFamily'], isTrue);
      expect(familyInstDoc.data()?['updatedAt'], isNotNull);

      // Should NOT be in users/user1/tasks or users/user1/instances
      final userTaskDoc = await firestore
          .collection('users')
          .doc('user1')
          .collection('tasks')
          .doc('S-fam1')
          .get();
      expect(userTaskDoc.exists, isFalse);

      final userInstDoc = await firestore
          .collection('users')
          .doc('user1')
          .collection('instances')
          .doc('I-fam1')
          .get();
      expect(userInstDoc.exists, isFalse);
    },
  );

  test(
    'Remote family updates are received by TaskSyncService listeners',
    () async {
      await firestore.collection('users').doc('user1').set({
        'familyId': 'fam1',
      });

      final service = TaskSyncService(
        firestore: firestore,
        localDataSource: localDataSource,
        userId: 'user1',
        isActivePremium: true,
      );
      addTearDown(() => service.dispose());

      // Wait a microtask for listener attachment
      await pumpEventQueue();

      // Push remote family task
      await firestore
          .collection('families')
          .doc('fam1')
          .collection('tasks')
          .doc('S-fam-remote')
          .set({
            'id': 'S-fam-remote',
            'title': 'Remote Family Task',
            'isFamily': true,
            'updatedAt': DateTime.now().toIso8601String(),
          });

      // Push remote family instance
      await firestore
          .collection('families')
          .doc('fam1')
          .collection('instances')
          .doc('I-fam-remote')
          .set({
            'id': 'I-fam-remote',
            'scheduleId': 'S-fam-remote',
            'title': 'Remote Family Instance',
            'isFamily': true,
            'updatedAt': DateTime.now().toIso8601String(),
          });

      await pumpEventQueue();

      final localTasks = localDataSource.getTasks();
      expect(localTasks.any((t) => t.id == 'S-fam-remote'), isTrue);

      final localInstances = localDataSource.getInstances();
      expect(localInstances.any((i) => i.id == 'I-fam-remote'), isTrue);
    },
  );

  test(
    'Deleting a family task or instance deletes from families/{familyId}',
    () async {
      await firestore.collection('users').doc('user1').set({
        'familyId': 'fam1',
      });

      final service = TaskSyncService(
        firestore: firestore,
        localDataSource: localDataSource,
        userId: 'user1',
        isActivePremium: true,
      );
      addTearDown(() => service.dispose());

      // Prepopulate remote family task and instance
      await firestore
          .collection('families')
          .doc('fam1')
          .collection('tasks')
          .doc('S-to-delete')
          .set({
            'id': 'S-to-delete',
            'title': 'Task To Delete',
            'isFamily': true,
          });

      await firestore
          .collection('families')
          .doc('fam1')
          .collection('instances')
          .doc('I-to-delete')
          .set({
            'id': 'I-to-delete',
            'scheduleId': 'S-to-delete',
            'title': 'Instance To Delete',
            'isFamily': true,
          });

      // Wait for remote listener to receive and save
      await pumpEventQueue();

      // Now delete locally and mark dirty (simulating user deleting task)
      await localDataSource.deleteTask('S-to-delete');
      await localDataSource.deleteInstance('I-to-delete');
      await localDataSource.markDirty('S-to-delete');
      await localDataSource.markDirty('I-to-delete');

      await service.sync();

      final taskDoc = await firestore
          .collection('families')
          .doc('fam1')
          .collection('tasks')
          .doc('S-to-delete')
          .get();
      expect(taskDoc.exists, isFalse);

      final instDoc = await firestore
          .collection('families')
          .doc('fam1')
          .collection('instances')
          .doc('I-to-delete')
          .get();
      expect(instDoc.exists, isFalse);
    },
  );

  test(
    'Converting family task to personal deletes from families/{familyId} and sets in users/{userId}',
    () async {
      await firestore.collection('users').doc('user1').set({
        'familyId': 'fam1',
      });

      final service = TaskSyncService(
        firestore: firestore,
        localDataSource: localDataSource,
        userId: 'user1',
        isActivePremium: true,
      );
      addTearDown(() => service.dispose());

      // Start with a family task and instance in remote
      await firestore
          .collection('families')
          .doc('fam1')
          .collection('tasks')
          .doc('S-fam-to-pers')
          .set({
            'id': 'S-fam-to-pers',
            'title': 'Family Task',
            'isFamily': true,
            'updatedAt': DateTime(2026, 8, 1, 10, 0).toIso8601String(),
          });
      await firestore
          .collection('families')
          .doc('fam1')
          .collection('instances')
          .doc('I-fam-to-pers')
          .set({
            'id': 'I-fam-to-pers',
            'scheduleId': 'S-fam-to-pers',
            'title': 'Family Task Instance',
            'isFamily': true,
            'updatedAt': DateTime(2026, 8, 1, 10, 0).toIso8601String(),
          });

      // Allow listeners to catch up
      await pumpEventQueue();

      // Parent user changes task and instance to personal (isFamily = false)
      final updatedTask = TaskSchedule(
        id: 'S-fam-to-pers',
        title: 'Now Personal Task',
        description: 'Desc',
        isFamily: false,
        schedules: [],
        updatedAt: DateTime(2026, 8, 16, 11, 0),
      );
      final updatedInst = TaskInstance(
        id: 'I-fam-to-pers',
        scheduleId: 'S-fam-to-pers',
        ruleId: 'R-1',
        title: 'Now Personal Task Instance',
        description: 'Desc',
        scheduledDate: const CivilDay(year: 2026, month: 8, day: 16),
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 23, minute: 0),
        ),
        isFamily: false,
        status: TaskStatus.pending,
        updatedAt: DateTime(2026, 8, 16, 11, 0),
      );

      await localDataSource.saveTask(updatedTask);
      await localDataSource.saveInstance(updatedInst);
      await localDataSource.markDirty('S-fam-to-pers');
      await localDataSource.markDirty('I-fam-to-pers');

      await service.sync();

      // Verify task and instance exist in user collection
      final userTaskDoc = await firestore
          .collection('users')
          .doc('user1')
          .collection('tasks')
          .doc('S-fam-to-pers')
          .get();
      expect(userTaskDoc.exists, isTrue);
      expect(userTaskDoc.data()?['isFamily'], isFalse);
      expect(userTaskDoc.data()?['title'], 'Now Personal Task');

      final userInstDoc = await firestore
          .collection('users')
          .doc('user1')
          .collection('instances')
          .doc('I-fam-to-pers')
          .get();
      expect(userInstDoc.exists, isTrue);
      expect(userInstDoc.data()?['isFamily'], isFalse);

      // Verify task and instance are DELETED from family collection
      final famTaskDoc = await firestore
          .collection('families')
          .doc('fam1')
          .collection('tasks')
          .doc('S-fam-to-pers')
          .get();
      expect(famTaskDoc.exists, isFalse);

      final famInstDoc = await firestore
          .collection('families')
          .doc('fam1')
          .collection('instances')
          .doc('I-fam-to-pers')
          .get();
      expect(famInstDoc.exists, isFalse);
    },
  );

  test(
    'Converting personal task to family deletes from users/{userId} and sets in families/{familyId}',
    () async {
      await firestore.collection('users').doc('user1').set({
        'familyId': 'fam1',
      });

      final service = TaskSyncService(
        firestore: firestore,
        localDataSource: localDataSource,
        userId: 'user1',
        isActivePremium: true,
      );
      addTearDown(() => service.dispose());

      // Start with a personal task and instance in remote
      await firestore
          .collection('users')
          .doc('user1')
          .collection('tasks')
          .doc('S-pers-to-fam')
          .set({
            'id': 'S-pers-to-fam',
            'title': 'Personal Task',
            'isFamily': false,
            'updatedAt': DateTime(2026, 8, 1, 10, 0).toIso8601String(),
          });
      await firestore
          .collection('users')
          .doc('user1')
          .collection('instances')
          .doc('I-pers-to-fam')
          .set({
            'id': 'I-pers-to-fam',
            'scheduleId': 'S-pers-to-fam',
            'title': 'Personal Task Instance',
            'isFamily': false,
            'updatedAt': DateTime(2026, 8, 1, 10, 0).toIso8601String(),
          });

      // Allow listeners to catch up
      await pumpEventQueue();

      // User changes task and instance to family (isFamily = true)
      final updatedTask = TaskSchedule(
        id: 'S-pers-to-fam',
        title: 'Now Family Task',
        description: 'Desc',
        isFamily: true,
        schedules: [],
        updatedAt: DateTime(2026, 8, 16, 11, 0),
      );
      final updatedInst = TaskInstance(
        id: 'I-pers-to-fam',
        scheduleId: 'S-pers-to-fam',
        ruleId: 'R-1',
        title: 'Now Family Task Instance',
        description: 'Desc',
        scheduledDate: const CivilDay(year: 2026, month: 8, day: 16),
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 23, minute: 0),
        ),
        isFamily: true,
        status: TaskStatus.pending,
        updatedAt: DateTime(2026, 8, 16, 11, 0),
      );

      await localDataSource.saveTask(updatedTask);
      await localDataSource.saveInstance(updatedInst);
      await localDataSource.markDirty('S-pers-to-fam');
      await localDataSource.markDirty('I-pers-to-fam');

      await service.sync();

      // Verify task and instance exist in family collection
      final famTaskDoc = await firestore
          .collection('families')
          .doc('fam1')
          .collection('tasks')
          .doc('S-pers-to-fam')
          .get();
      expect(famTaskDoc.exists, isTrue);
      expect(famTaskDoc.data()?['isFamily'], isTrue);
      expect(famTaskDoc.data()?['title'], 'Now Family Task');

      final famInstDoc = await firestore
          .collection('families')
          .doc('fam1')
          .collection('instances')
          .doc('I-pers-to-fam')
          .get();
      expect(famInstDoc.exists, isTrue);
      expect(famInstDoc.data()?['isFamily'], isTrue);

      // Verify task and instance are DELETED from user collection
      final userTaskDoc = await firestore
          .collection('users')
          .doc('user1')
          .collection('tasks')
          .doc('S-pers-to-fam')
          .get();
      expect(userTaskDoc.exists, isFalse);

      final userInstDoc = await firestore
          .collection('users')
          .doc('user1')
          .collection('instances')
          .doc('I-pers-to-fam')
          .get();
      expect(userInstDoc.exists, isFalse);
    },
  );

  test(
    'Parent listener does not delete local personal task when family doc is removed',
    () async {
      await firestore.collection('users').doc('user1').set({
        'familyId': 'fam1',
      });

      final service = TaskSyncService(
        firestore: firestore,
        localDataSource: localDataSource,
        userId: 'user1',
        isActivePremium: true,
      );
      addTearDown(() => service.dispose());

      // Prepopulate a family task in remote
      await firestore
          .collection('families')
          .doc('fam1')
          .collection('tasks')
          .doc('S-kitchen')
          .set({
            'id': 'S-kitchen',
            'title': 'Clean the Kitchen',
            'isFamily': true,
            'updatedAt': DateTime(2026, 8, 1, 10, 0).toIso8601String(),
          });

      await pumpEventQueue();
      expect(
        localDataSource.getTasks().any((t) => t.id == 'S-kitchen'),
        isTrue,
      );

      // Parent converts Clean the Kitchen to personal locally
      final convertedTask = TaskSchedule(
        id: 'S-kitchen',
        title: 'Clean the Kitchen',
        description: 'Personal now',
        isFamily: false,
        schedules: [],
        updatedAt: DateTime(2026, 8, 16, 11, 35),
      );
      await localDataSource.saveTask(convertedTask);
      await localDataSource.markDirty('S-kitchen');

      // Parent syncs: pushes to users/user1/tasks and deletes from families/fam1/tasks
      await service.sync();

      // Allow listeners to process the remote family deletion
      await pumpEventQueue();

      // Parent still retains the task locally as personal
      expect(
        localDataSource.getTasks().any((t) => t.id == 'S-kitchen'),
        isTrue,
      );
      expect(
        localDataSource
            .getTasks()
            .firstWhere((t) => t.id == 'S-kitchen')
            .isFamily,
        isFalse,
      );
    },
  );

  test(
    'Member listener deletes local family task when family doc is removed',
    () async {
      await firestore.collection('users').doc('user2').set({
        'familyId': 'fam1',
        'familyRole': 'non-parent',
      });

      final service = TaskSyncService(
        firestore: firestore,
        localDataSource: localDataSource,
        userId: 'user2',
        isActivePremium: true,
      );
      addTearDown(() => service.dispose());

      // Prepopulate a family task in remote
      await firestore
          .collection('families')
          .doc('fam1')
          .collection('tasks')
          .doc('S-kitchen-fam')
          .set({
            'id': 'S-kitchen-fam',
            'title': 'Clean the Kitchen',
            'isFamily': true,
            'updatedAt': DateTime(2026, 8, 1, 10, 0).toIso8601String(),
          });

      await pumpEventQueue();
      expect(
        localDataSource.getTasks().any((t) => t.id == 'S-kitchen-fam'),
        isTrue,
      );
      expect(
        localDataSource
            .getTasks()
            .firstWhere((t) => t.id == 'S-kitchen-fam')
            .isFamily,
        isTrue,
      );

      // Now simulate the family task being deleted from remote (e.g. parent converted it to personal)
      await firestore
          .collection('families')
          .doc('fam1')
          .collection('tasks')
          .doc('S-kitchen-fam')
          .delete();

      // Allow member listener to process the remote family deletion
      await pumpEventQueue();

      // Member should have had the task removed from local storage
      expect(
        localDataSource.getTasks().any((t) => t.id == 'S-kitchen-fam'),
        isFalse,
      );
    },
  );

  test(
    'Changing or clearing familyId cancels _familyRecipesSub and prevents syncing recipes from old family',
    () async {
      await firestore.collection('users').doc('user1').set({
        'familyId': 'fam1',
      });

      final service = TaskSyncService(
        firestore: firestore,
        localDataSource: localDataSource,
        userId: 'user1',
        isActivePremium: true,
      );
      addTearDown(() => service.dispose());

      await pumpEventQueue();

      // Add a recipe in fam1
      await firestore
          .collection('families')
          .doc('fam1')
          .collection('recipes')
          .doc('R-1')
          .set({
            'title': 'Recipe 1',
            'description': 'Family Recipe 1',
            'servings': 4,
            'isFamily': true,
            'updatedAt': DateTime.now().toIso8601String(),
          });

      await pumpEventQueue();
      expect(localDataSource.getRecipes().any((r) => r.id == 'R-1'), isTrue);

      // Now user leaves family (familyId becomes null)
      await firestore.collection('users').doc('user1').set({'familyId': null});

      await pumpEventQueue();

      // Add another recipe to old family fam1
      await firestore
          .collection('families')
          .doc('fam1')
          .collection('recipes')
          .doc('R-2')
          .set({
            'title': 'Recipe 2',
            'description': 'Family Recipe 2',
            'servings': 4,
            'isFamily': true,
            'updatedAt': DateTime.now().toIso8601String(),
          });

      await pumpEventQueue();

      // R-2 should NOT be synced to local data source because stream was cancelled
      expect(localDataSource.getRecipes().any((r) => r.id == 'R-2'), isFalse);
    },
  );

  test(
    'Fast batch ingestion of large snapshot (200 instances) works correctly',
    () async {
      final service = TaskSyncService(
        firestore: firestore,
        localDataSource: localDataSource,
        userId: 'user1',
        isActivePremium: true,
      );
      addTearDown(() => service.dispose());

      for (int i = 0; i < 200; i++) {
        final inst = TaskInstance(
          id: 'I-large-$i',
          scheduleId: 'S-large',
          ruleId: 'rule_$i',
          title: 'Large Inst $i',
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
          status: TaskStatus.pending,
          isFamily: false,
          updatedAt: DateTime.now(),
        );
        await firestore
            .collection('users')
            .doc('user1')
            .collection('instances')
            .doc(inst.id)
            .set(inst.toFirestore());
      }

      await pumpEventQueue();
      expect(localDataSource.getInstances().length, 200);
    },
  );

  test(
    'Remote snapshot marks local cached tasks, instances, and recipes as isFromCache == false',
    () async {
      // 1. Prepopulate local data source with items loaded from cache
      final cachedTask = TaskSchedule(
        id: 'S-cached-1',
        title: 'Cached Task',
        description: 'Desc',
        schedules: [],
        isFromCache: true,
        updatedAt: DateTime(2026, 8, 20, 10, 0),
      );
      final cachedInstance = TaskInstance(
        id: 'I-cached-1',
        scheduleId: 'S-cached-1',
        ruleId: 'R-1',
        title: 'Cached Task',
        description: 'Desc',
        scheduledDate: const CivilDay(year: 2026, month: 8, day: 21),
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        isFromCache: true,
        updatedAt: DateTime(2026, 8, 20, 10, 0),
      );
      final cachedRecipe = Recipe(
        id: 'R-cached-1',
        title: 'Cached Recipe',
        description: 'Desc',
        isFromCache: true,
        updatedAt: DateTime(2026, 8, 20, 10, 0),
      );

      await localDataSource.saveTask(cachedTask);
      await localDataSource.saveInstance(cachedInstance);
      await localDataSource.saveRecipe(cachedRecipe);

      expect(localDataSource.getTasks().first.isFromCache, isTrue);
      expect(localDataSource.getInstances().first.isFromCache, isTrue);
      expect(localDataSource.getRecipes().first.isFromCache, isTrue);

      // 2. Start sync service and populate Firestore
      final service = TaskSyncService(
        firestore: firestore,
        localDataSource: localDataSource,
        userId: 'user1',
        isActivePremium: true,
      );
      addTearDown(() => service.dispose());

      await firestore
          .collection('users')
          .doc('user1')
          .collection('tasks')
          .doc(cachedTask.id)
          .set(cachedTask.toFirestore());
      await firestore
          .collection('users')
          .doc('user1')
          .collection('instances')
          .doc(cachedInstance.id)
          .set(cachedInstance.toFirestore());
      await firestore
          .collection('users')
          .doc('user1')
          .collection('recipes')
          .doc(cachedRecipe.id)
          .set(cachedRecipe.toFirestore());

      // Allow stream to process
      await pumpEventQueue();

      // Local tasks, instances, and recipes should now have isFromCache == false
      final updatedTask = localDataSource.getTasks().firstWhere(
        (t) => t.id == 'S-cached-1',
      );
      final updatedInstance = localDataSource.getInstances().firstWhere(
        (i) => i.id == 'I-cached-1',
      );
      final updatedRecipe = localDataSource.getRecipes().firstWhere(
        (r) => r.id == 'R-cached-1',
      );

      expect(updatedTask.isFromCache, isFalse);
      expect(updatedInstance.isFromCache, isFalse);
      expect(updatedRecipe.isFromCache, isFalse);
    },
  );

  test(
    'updates family member client metadata when familyId is resolved via user doc stream',
    () async {
      await firestore.collection('families').doc('fam-123').set({
        'name': 'The Smiths',
        'members': {
          'user1': {'role': 'member'},
        },
      });

      final service = TaskSyncService(
        firestore: firestore,
        localDataSource: localDataSource,
        userId: 'user1',
        isActivePremium: true,
      );
      addTearDown(() => service.dispose());

      await firestore.collection('users').doc('user1').set({
        'familyId': 'fam-123',
      }, SetOptions(merge: true));

      await pumpEventQueue();

      final familyDoc = await firestore
          .collection('families')
          .doc('fam-123')
          .get();
      final memberData =
          familyDoc.data()?['members']?['user1'] as Map<String, dynamic>?;

      expect(memberData, isNotNull);
      expect(memberData?['appVersion'], isNotNull);
      expect(memberData?['platform'], isNotNull);
      expect(memberData?['lastSeenAt'], isNotNull);
    },
  );
}

class _FailingHiveLocalDataSource extends HiveLocalDataSource {
  @override
  bool isMigrationCompleted() => true;

  @override
  List<String> getDirtyTaskIds() {
    throw Exception('Simulated local data source failure');
  }
}
