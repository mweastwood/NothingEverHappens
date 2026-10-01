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
import 'package:nothing_ever_happens/logic/family_id_fetcher.dart';
import 'package:nothing_ever_happens/logic/app_logger.dart';
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
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
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
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
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
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
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
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
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
          hour: 17,
          minute: 0,
        ),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 23, minute: 0),
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
        'familyRole': 'parent',
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
        'familyRole': 'parent',
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
          hour: 17,
          minute: 0,
        ),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 23, minute: 0),
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
          hour: 17,
          minute: 0,
        ),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 23, minute: 0),
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
        'familyRole': 'parent',
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
            hour: 9,
            minute: 0,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 17,
            minute: 0,
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
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
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

  test(
    'sync() triggered before _userDocSub first event uses FamilyIdFetcher without race condition',
    () async {
      await firestore.collection('users').doc('user1').set({
        'familyId': 'fam-immediate',
      });

      final service = TaskSyncService(
        firestore: firestore,
        localDataSource: localDataSource,
        userId: 'user1',
        isActivePremium: true,
      );
      addTearDown(() => service.dispose());

      final task = TaskSchedule(
        id: 'S-fam-immediate',
        title: 'Immediate Family Task',
        description: 'Desc',
        schedules: [],
        isFamily: true,
        updatedAt: DateTime(2026, 8, 4, 10, 0),
      );
      await localDataSource.saveTask(task);
      await localDataSource.markDirty('S-fam-immediate');

      // Call sync immediately before pumping event queue for userDoc stream
      await service.sync();

      final familyDoc = await firestore
          .collection('families')
          .doc('fam-immediate')
          .collection('tasks')
          .doc('S-fam-immediate')
          .get();
      expect(familyDoc.exists, isTrue);
      expect(familyDoc.data()?['title'], 'Immediate Family Task');

      // Stream fires later with the same familyId
      await pumpEventQueue();

      final userTasksDoc = await firestore
          .collection('users')
          .doc('user1')
          .collection('tasks')
          .doc('S-fam-immediate')
          .get();
      expect(userTasksDoc.exists, isFalse);
    },
  );

  test(
    'transitions correctly when _userDocSub emits family added, changed, and removed',
    () async {
      final fetcher = FamilyIdFetcher(firestore: firestore, userId: 'user1');

      final service = TaskSyncService(
        firestore: firestore,
        localDataSource: localDataSource,
        userId: 'user1',
        isActivePremium: true,
        familyIdFetcher: fetcher,
      );
      addTearDown(() => service.dispose());

      // 1. Initial state: user has no family
      expect(await fetcher.getFamilyId(), isNull);

      // 2. Family added: user doc updated with fam-alpha
      await firestore.collection('users').doc('user1').set({
        'familyId': 'fam-alpha',
      });
      await pumpEventQueue();

      // Remote task in fam-alpha is received
      await firestore
          .collection('families')
          .doc('fam-alpha')
          .collection('tasks')
          .doc('S-alpha-1')
          .set({
            'id': 'S-alpha-1',
            'title': 'Alpha Task',
            'description': '',
            'schedules': [],
            'isFamily': true,
            'updatedAt': DateTime(2026, 8, 4, 10, 0).toIso8601String(),
          });
      await pumpEventQueue();

      expect(
        localDataSource.getTasks().any((t) => t.id == 'S-alpha-1'),
        isTrue,
      );

      // 3. Family changed: user switches to fam-beta
      await firestore.collection('users').doc('user1').set({
        'familyId': 'fam-beta',
      });
      await pumpEventQueue();

      // New task in fam-alpha is ignored since subscription cancelled
      await firestore
          .collection('families')
          .doc('fam-alpha')
          .collection('tasks')
          .doc('S-alpha-2')
          .set({
            'id': 'S-alpha-2',
            'title': 'Alpha Task 2',
            'description': '',
            'schedules': [],
            'isFamily': true,
            'updatedAt': DateTime(2026, 8, 4, 10, 0).toIso8601String(),
          });
      await pumpEventQueue();

      expect(
        localDataSource.getTasks().any((t) => t.id == 'S-alpha-2'),
        isFalse,
      );

      // Remote task in fam-beta is received
      await firestore
          .collection('families')
          .doc('fam-beta')
          .collection('tasks')
          .doc('S-beta-1')
          .set({
            'id': 'S-beta-1',
            'title': 'Beta Task 1',
            'description': '',
            'schedules': [],
            'isFamily': true,
            'updatedAt': DateTime(2026, 8, 4, 10, 0).toIso8601String(),
          });
      await pumpEventQueue();

      expect(localDataSource.getTasks().any((t) => t.id == 'S-beta-1'), isTrue);

      // 4. Family removed: user leaves family
      await firestore.collection('users').doc('user1').set({'familyId': null});
      await pumpEventQueue();

      // New task in fam-beta is ignored
      await firestore
          .collection('families')
          .doc('fam-beta')
          .collection('tasks')
          .doc('S-beta-2')
          .set({
            'id': 'S-beta-2',
            'title': 'Beta Task 2',
            'description': '',
            'schedules': [],
            'isFamily': true,
            'updatedAt': DateTime(2026, 8, 4, 10, 0).toIso8601String(),
          });
      await pumpEventQueue();

      expect(
        localDataSource.getTasks().any((t) => t.id == 'S-beta-2'),
        isFalse,
      );
    },
  );

  test(
    'TaskSyncService accepts custom FamilyIdFetcher and uses it during sync',
    () async {
      final customFetcher = _TrackingFamilyIdFetcher(
        firestore: firestore,
        userId: 'user1',
        stubbedId: 'fam-injected',
      );

      final service = TaskSyncService(
        firestore: firestore,
        localDataSource: localDataSource,
        userId: 'user1',
        isActivePremium: true,
        familyIdFetcher: customFetcher,
      );
      addTearDown(() => service.dispose());

      final task = TaskSchedule(
        id: 'S-fam-injected',
        title: 'Injected Fetcher Task',
        description: 'Desc',
        schedules: [],
        isFamily: true,
        updatedAt: DateTime(2026, 8, 4, 10, 0),
      );
      await localDataSource.saveTask(task);
      await localDataSource.markDirty('S-fam-injected');

      await service.sync();

      final familyDoc = await firestore
          .collection('families')
          .doc('fam-injected')
          .collection('tasks')
          .doc('S-fam-injected')
          .get();
      expect(familyDoc.exists, isTrue);
      expect(familyDoc.data()?['title'], 'Injected Fetcher Task');
      expect(customFetcher.getFamilyIdCalls, greaterThanOrEqualTo(1));
    },
  );

  test(
    'Disposal during in-flight sync aborts remaining item processing without throwing StateError',
    () async {
      final hookedDataSource = _HookedHiveLocalDataSource();
      await hookedDataSource.init();
      await hookedDataSource.setMigrationCompleted(true);

      final service = TaskSyncService(
        firestore: firestore,
        localDataSource: hookedDataSource,
        userId: 'user1',
        isActivePremium: true,
      );

      final task1 = TaskSchedule(
        id: 'S-1',
        title: 'Task 1',
        description: 'Desc 1',
        schedules: [],
        updatedAt: DateTime.now(),
      );
      final task2 = TaskSchedule(
        id: 'S-2',
        title: 'Task 2',
        description: 'Desc 2',
        schedules: [],
        updatedAt: DateTime.now(),
      );
      await hookedDataSource.saveTask(task1);
      await hookedDataSource.saveTask(task2);
      await hookedDataSource.markDirty('S-1');
      await hookedDataSource.markDirty('S-2');

      hookedDataSource.onClearDirty = (id) {
        if (id == 'S-1') {
          service.dispose();
        }
      };

      // Calling sync should not throw StateError when disposing mid-sync
      await service.sync();

      expect(service.isDisposed, isTrue);
      expect(service.isSyncing, isFalse);

      // S-1 was synced, but S-2 was aborted due to disposal mid-loop
      final doc1 = await firestore
          .collection('users')
          .doc('user1')
          .collection('tasks')
          .doc('S-1')
          .get();
      expect(doc1.exists, isTrue);

      final doc2 = await firestore
          .collection('users')
          .doc('user1')
          .collection('tasks')
          .doc('S-2')
          .get();
      expect(doc2.exists, isFalse);
      expect(hookedDataSource.getDirtyTaskIds(), contains('S-2'));
    },
  );

  test('sync() after dispose() is an immediate no-op', () async {
    final service = TaskSyncService(
      firestore: firestore,
      localDataSource: localDataSource,
      userId: 'user1',
      isActivePremium: true,
    );

    service.dispose();
    expect(service.isDisposed, isTrue);

    final task = TaskSchedule(
      id: 'S-disposed-noop',
      title: 'Task Disposed No-op',
      description: 'Desc',
      schedules: [],
      updatedAt: DateTime.now(),
    );
    await localDataSource.saveTask(task);
    await localDataSource.markDirty('S-disposed-noop');

    await service.sync();

    final docSnap = await firestore
        .collection('users')
        .doc('user1')
        .collection('tasks')
        .doc('S-disposed-noop')
        .get();
    expect(docSnap.exists, isFalse);
    expect(localDataSource.getDirtyTaskIds(), contains('S-disposed-noop'));
  });

  test(
    'Exception recovery resets _isSyncing to false and allows subsequent sync',
    () async {
      final intermittentDataSource = _IntermittentHiveLocalDataSource();
      await intermittentDataSource.init();
      await intermittentDataSource.setMigrationCompleted(true);

      final errorHandler = ErrorHandler();
      final service = TaskSyncService(
        firestore: firestore,
        localDataSource: intermittentDataSource,
        userId: 'user1',
        isActivePremium: true,
        errorHandler: errorHandler,
      );
      addTearDown(() => service.dispose());

      final task1 = TaskSchedule(
        id: 'S-fail-then-pass',
        title: 'Retry Task',
        description: 'Desc',
        schedules: [],
        updatedAt: DateTime.now(),
      );
      await intermittentDataSource.saveTask(task1);
      await intermittentDataSource.markDirty('S-fail-then-pass');

      intermittentDataSource.shouldFail = true;
      await service.sync();

      expect(service.isSyncing, isFalse);
      expect(errorHandler.history.isNotEmpty, isTrue);

      final docBeforeRetry = await firestore
          .collection('users')
          .doc('user1')
          .collection('tasks')
          .doc('S-fail-then-pass')
          .get();
      expect(docBeforeRetry.exists, isFalse);

      // Subsequent sync succeeds
      intermittentDataSource.shouldFail = false;
      await service.sync();

      expect(service.isSyncing, isFalse);
      final docAfterRetry = await firestore
          .collection('users')
          .doc('user1')
          .collection('tasks')
          .doc('S-fail-then-pass')
          .get();
      expect(docAfterRetry.exists, isTrue);
      expect(docAfterRetry.data()?['title'], 'Retry Task');
    },
  );

  test(
    'logs modifiedByPlatform alongside modifiedByAppVersion when remote instance changes are received',
    () async {
      final logger = AppLogger();
      final service = TaskSyncService(
        firestore: firestore,
        localDataSource: localDataSource,
        userId: 'user1',
        isActivePremium: true,
        logger: logger,
      );
      addTearDown(() => service.dispose());

      final remoteInstance = TaskInstance(
        id: 'I-remote-platform-test',
        scheduleId: 'S-platform-test',
        ruleId: 'R-platform-test',
        title: 'Platform Test Instance',
        description: '',
        scheduledDate: const CivilDay(year: 2026, month: 9, day: 2),
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
        status: TaskStatus.skipped,
        statusReason: 'scheduler_prefer_older',
        lastModifiedByUserId: 'user2',
        lastModifiedByAppVersion: 'v1.8.25 (2198dab)',
        lastModifiedByPlatform: 'android',
      );

      await firestore
          .collection('users')
          .doc('user1')
          .collection('instances')
          .doc(remoteInstance.id)
          .set(remoteInstance.toFirestore());

      await pumpEventQueue();

      final events = logger.getEvents();
      final syncEvents = events.where(
        (e) =>
            e.category == 'sync' &&
            e.message.contains(
              'Remote instance added: "Platform Test Instance"',
            ),
      );
      expect(syncEvents, isNotEmpty);
      final eventData = syncEvents.first.data;
      expect(eventData?['modifiedByAppVersion'], 'v1.8.25 (2198dab)');
      expect(eventData?['modifiedByPlatform'], 'android');
      expect(eventData?['modifiedByUserId'], 'user2');
      expect(eventData?['statusReason'], 'scheduler_prefer_older');
    },
  );

  group('Semantic Precedence Conflict Resolution (Issue #713)', () {
    test(
      'local user_dismissed or user_completed instance is preserved when incoming remote contains newer scheduler_prefer_older skip',
      () async {
        final service = TaskSyncService(
          firestore: firestore,
          localDataSource: localDataSource,
          userId: 'user1',
          isActivePremium: true,
        );
        addTearDown(() => service.dispose());

        final localTime = DateTime(2026, 9, 6, 12, 54);
        final remoteTime = DateTime(2026, 9, 7, 22, 15); // Newer timestamp

        // 1. Test local user_dismissed preserved
        final localDismissed = TaskInstance(
          id: 'I-kitchen-dismissed',
          scheduleId: 'S-kitchen',
          ruleId: 'R-kitchen',
          title: 'Kitchen Task',
          description: 'Clean Kitchen',
          scheduledDate: const CivilDay(year: 2026, month: 9, day: 6),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 9,
            minute: 0,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 17,
            minute: 0,
          ),
          status: TaskStatus.skipped,
          statusReason: 'user_dismissed',
          updatedAt: localTime,
        );
        await localDataSource.saveInstance(localDismissed);

        final remoteSchedulerSkip = localDismissed.copyWith(
          status: TaskStatus.skipped,
          statusReason: 'scheduler_prefer_older',
          updatedAt: remoteTime,
        );

        await firestore
            .collection('users')
            .doc('user1')
            .collection('instances')
            .doc('I-kitchen-dismissed')
            .set(remoteSchedulerSkip.toFirestore());

        await pumpEventQueue();

        var localInst = localDataSource.getInstances().firstWhere(
          (i) => i.id == 'I-kitchen-dismissed',
        );
        expect(localInst.statusReason, 'user_dismissed');

        // 2. Test local user_completed preserved
        final localCompleted = TaskInstance(
          id: 'I-kitchen-completed',
          scheduleId: 'S-kitchen',
          ruleId: 'R-kitchen',
          title: 'Kitchen Task Completed',
          description: 'Clean Kitchen',
          scheduledDate: const CivilDay(year: 2026, month: 9, day: 6),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 9,
            minute: 0,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 17,
            minute: 0,
          ),
          status: TaskStatus.completed,
          statusReason: 'user_completed',
          updatedAt: localTime,
        );
        await localDataSource.saveInstance(localCompleted);

        final remoteSchedulerSkip2 = localCompleted.copyWith(
          status: TaskStatus.skipped,
          statusReason: 'scheduler_prefer_older',
          updatedAt: remoteTime,
        );

        await firestore
            .collection('users')
            .doc('user1')
            .collection('instances')
            .doc('I-kitchen-completed')
            .set(remoteSchedulerSkip2.toFirestore());

        await pumpEventQueue();

        localInst = localDataSource.getInstances().firstWhere(
          (i) => i.id == 'I-kitchen-completed',
        );
        expect(localInst.status, TaskStatus.completed);
        expect(localInst.statusReason, 'user_completed');
      },
    );

    test(
      'remote user_completed instance overwrites a local newer scheduler_prefer_older skip',
      () async {
        final service = TaskSyncService(
          firestore: firestore,
          localDataSource: localDataSource,
          userId: 'user1',
          isActivePremium: true,
        );
        addTearDown(() => service.dispose());

        final localTime = DateTime(2026, 9, 7, 22, 15); // Newer local timestamp
        final remoteTime = DateTime(
          2026,
          9,
          6,
          12,
          54,
        ); // Older remote timestamp

        final localSchedulerSkip = TaskInstance(
          id: 'I-kitchen-sweep',
          scheduleId: 'S-kitchen',
          ruleId: 'R-kitchen',
          title: 'Kitchen Task',
          description: 'Clean Kitchen',
          scheduledDate: const CivilDay(year: 2026, month: 9, day: 6),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 9,
            minute: 0,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 17,
            minute: 0,
          ),
          status: TaskStatus.skipped,
          statusReason: 'scheduler_prefer_older',
          updatedAt: localTime,
        );
        await localDataSource.saveInstance(localSchedulerSkip);

        final remoteUserCompleted = localSchedulerSkip.copyWith(
          status: TaskStatus.completed,
          statusReason: 'user_completed',
          updatedAt: remoteTime,
        );

        await firestore
            .collection('users')
            .doc('user1')
            .collection('instances')
            .doc('I-kitchen-sweep')
            .set(remoteUserCompleted.toFirestore());

        await pumpEventQueue();

        final localInst = localDataSource.getInstances().firstWhere(
          (i) => i.id == 'I-kitchen-sweep',
        );
        expect(localInst.status, TaskStatus.completed);
        expect(localInst.statusReason, 'user_completed');
      },
    );

    test(
      'remote pending instance with statusReason user_dismissed does not overwrite newer local scheduler skip',
      () async {
        final service = TaskSyncService(
          firestore: firestore,
          localDataSource: localDataSource,
          userId: 'user1',
          isActivePremium: true,
        );
        addTearDown(() => service.dispose());

        final olderRemoteTime = DateTime(2026, 9, 6, 12, 0);
        final newerLocalTime = DateTime(2026, 9, 7, 10, 0);

        // Local instance is skipped by scheduler
        final localSchedulerSkip = TaskInstance(
          id: 'I-zombie-task',
          scheduleId: 'S-zombie',
          ruleId: 'R-zombie',
          title: 'Zombie Task',
          description: '',
          scheduledDate: const CivilDay(year: 2026, month: 9, day: 6),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 9,
            minute: 0,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 17,
            minute: 0,
          ),
          status: TaskStatus.skipped,
          statusReason: 'scheduler_auto_dismiss',
          updatedAt: newerLocalTime,
        );
        await localDataSource.saveInstance(localSchedulerSkip);

        // Remote instance has corrupted pending status with old user_dismissed reason
        final remoteCorruptedPending = localSchedulerSkip.copyWith(
          status: TaskStatus.pending,
          statusReason: 'user_dismissed',
          updatedAt: olderRemoteTime,
        );

        await firestore
            .collection('users')
            .doc('user1')
            .collection('instances')
            .doc(localSchedulerSkip.id)
            .set(remoteCorruptedPending.toFirestore());

        await pumpEventQueue();

        final localInst = localDataSource.getInstances().firstWhere(
          (i) => i.id == 'I-zombie-task',
        );
        // Local scheduler skip must be preserved because remote is pending
        expect(localInst.status, TaskStatus.skipped);
        expect(localInst.statusReason, 'scheduler_auto_dismiss');
      },
    );

    test('slot-level conflict resolution adheres to semantic precedence', () async {
      final service = TaskSyncService(
        firestore: firestore,
        localDataSource: localDataSource,
        userId: 'user1',
        isActivePremium: true,
      );
      addTearDown(() => service.dispose());

      final olderUserTime = DateTime(2026, 9, 6, 12, 0);
      final newerBotTime = DateTime(2026, 9, 7, 10, 0);

      // Case A: Local is user_dismissed (older), Remote is scheduler_prefer_older (newer, different UUID on same slot)
      final localSlotUser = TaskInstance(
        id: 'I-slot-local',
        scheduleId: 'S-shared',
        ruleId: 'R-shared',
        title: 'Shared Slot Task',
        description: 'Slot test',
        scheduledDate: const CivilDay(year: 2026, month: 9, day: 6),
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
        status: TaskStatus.skipped,
        statusReason: 'user_dismissed',
        updatedAt: olderUserTime,
      );
      await localDataSource.saveInstance(localSlotUser);

      final remoteSlotBot = TaskInstance(
        id: 'I-slot-remote',
        scheduleId: 'S-shared',
        ruleId: 'R-shared',
        title: 'Shared Slot Task (Remote Bot)',
        description: 'Slot test',
        scheduledDate: const CivilDay(year: 2026, month: 9, day: 6),
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
        status: TaskStatus.skipped,
        statusReason: 'scheduler_prefer_older',
        updatedAt: newerBotTime,
      );

      await firestore
          .collection('users')
          .doc('user1')
          .collection('instances')
          .doc('I-slot-remote')
          .set(remoteSlotBot.toFirestore());

      await pumpEventQueue();
      await Future<void>.delayed(Duration.zero);
      await pumpEventQueue();

      final instances = localDataSource.getInstances();
      // Local user action should win: local kept, remote duplicate not saved
      expect(instances.any((i) => i.id == 'I-slot-local'), isTrue);
      expect(instances.any((i) => i.id == 'I-slot-remote'), isFalse);
      final saved = instances.firstWhere((i) => i.id == 'I-slot-local');
      expect(saved.statusReason, 'user_dismissed');

      // Remote duplicate doc should have been deleted
      final remoteDoc = await firestore
          .collection('users')
          .doc('user1')
          .collection('instances')
          .doc('I-slot-remote')
          .get();
      expect(remoteDoc.exists, isFalse);

      // Case B: Local is scheduler_prefer_older (newer), Remote is user_completed (older, different UUID on same slot)
      final localSlotBot = TaskInstance(
        id: 'I-slot2-local',
        scheduleId: 'S-shared2',
        ruleId: 'R-shared2',
        title: 'Shared Slot Task 2',
        description: 'Slot test 2',
        scheduledDate: const CivilDay(year: 2026, month: 9, day: 7),
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
        status: TaskStatus.skipped,
        statusReason: 'scheduler_prefer_older',
        updatedAt: newerBotTime,
      );
      await localDataSource.saveInstance(localSlotBot);

      final remoteSlotUser = TaskInstance(
        id: 'I-slot2-remote',
        scheduleId: 'S-shared2',
        ruleId: 'R-shared2',
        title: 'Shared Slot Task 2 (User Completed)',
        description: 'Slot test 2',
        scheduledDate: const CivilDay(year: 2026, month: 9, day: 7),
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
        status: TaskStatus.completed,
        statusReason: 'user_completed',
        updatedAt: olderUserTime,
      );

      await firestore
          .collection('users')
          .doc('user1')
          .collection('instances')
          .doc('I-slot2-remote')
          .set(remoteSlotUser.toFirestore());

      await pumpEventQueue();
      await Future<void>.delayed(Duration.zero);
      await pumpEventQueue();

      final instances2 = localDataSource.getInstances();
      // Remote user action wins: local deleted, remote saved
      expect(instances2.any((i) => i.id == 'I-slot2-local'), isFalse);
      expect(instances2.any((i) => i.id == 'I-slot2-remote'), isTrue);
      final saved2 = instances2.firstWhere((i) => i.id == 'I-slot2-remote');
      expect(saved2.status, TaskStatus.completed);
      expect(saved2.statusReason, 'user_completed');
    });

    test(
      'waitForInitialSync resolves after receiving initial snapshots',
      () async {
        final service = TaskSyncService(
          firestore: firestore,
          localDataSource: localDataSource,
          userId: 'user1',
          isActivePremium: true,
        );
        addTearDown(() => service.dispose());

        var resolved = false;
        service.waitForInitialSync.then((_) {
          resolved = true;
        });

        await pumpEventQueue();
        expect(resolved, isTrue);
      },
    );

    test('waitForInitialSync resolves immediately for free user', () async {
      final service = TaskSyncService(
        firestore: firestore,
        localDataSource: localDataSource,
        userId: 'user1',
        isActivePremium: false,
      );
      addTearDown(() => service.dispose());

      var resolved = false;
      service.waitForInitialSync.then((_) {
        resolved = true;
      });

      await pumpEventQueue();
      expect(resolved, isTrue);
    });

    group('Firestore Write Hardening Tests', () {
      test(
        'remote task snapshot missing labelIds does not trigger writeback or self-healing',
        () async {
          final service = TaskSyncService(
            firestore: firestore,
            localDataSource: localDataSource,
            userId: 'user1',
            isActivePremium: true,
          );
          addTearDown(() => service.dispose());

          // 1. Set up local task with labelIds
          final localTask = TaskSchedule(
            id: 'S-labels-1',
            title: 'Local Task',
            description: 'Desc',
            schedules: [],
            labelIds: ['label-clean', 'label-urgent'],
            updatedAt: DateTime(2026, 9, 10, 12, 0),
          );
          await localDataSource.saveTask(localTask);

          // 2. Newer remote doc without 'labelIds' arrives
          final remoteTime = DateTime(2026, 9, 11, 12, 0);
          await firestore
              .collection('users')
              .doc('user1')
              .collection('tasks')
              .doc('S-labels-1')
              .set({
                'id': 'S-labels-1',
                'title': 'Remote Title from v1.8.36',
                'description': 'Desc',
                'schedules': [],
                'updatedAt': remoteTime.toIso8601String(),
              });

          await pumpEventQueue();

          // 3. Remote won; local task receives remote data with empty labelIds (no self-healing)
          final updatedLocal = localDataSource.getTasks().firstWhere(
            (t) => t.id == 'S-labels-1',
          );
          expect(updatedLocal.title, 'Remote Title from v1.8.36');
          expect(updatedLocal.labelIds, isEmpty);

          // 4. Remote doc in Firestore is not written back to
          final remoteDoc = await firestore
              .collection('users')
              .doc('user1')
              .collection('tasks')
              .doc('S-labels-1')
              .get();
          expect(remoteDoc.data()?['labelIds'], isNull);
        },
      );

      test(
        'remote instance snapshot missing labelIds does not trigger writeback or self-healing',
        () async {
          final service = TaskSyncService(
            firestore: firestore,
            localDataSource: localDataSource,
            userId: 'user1',
            isActivePremium: true,
          );
          addTearDown(() => service.dispose());

          final localInst = TaskInstance(
            id: 'I-inst-1',
            scheduleId: 'S-inst-1',
            ruleId: 'R-1',
            title: 'Local Inst',
            description: 'Desc',
            scheduledDate: const CivilDay(year: 2026, month: 9, day: 12),
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              hour: 9,
              minute: 0,
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              hour: 10,
              minute: 0,
            ),
            labelIds: ['label-morning'],
            updatedAt: DateTime(2026, 9, 10, 12, 0),
          );
          await localDataSource.saveInstance(localInst);

          final remoteTime = DateTime(2026, 9, 11, 12, 0);
          await firestore
              .collection('users')
              .doc('user1')
              .collection('instances')
              .doc('I-inst-1')
              .set({
                'id': 'I-inst-1',
                'scheduleId': 'S-inst-1',
                'ruleId': 'R-1',
                'title': 'Updated Remote Inst',
                'description': 'Desc',
                'scheduledDate': {'year': 2026, 'month': 9, 'day': 12},
                'startRelativeTime': {'hour': 9, 'minute': 0},
                'dueRelativeTime': {'hour': 10, 'minute': 0},
                'status': 'pending',
                'updatedAt': remoteTime.toIso8601String(),
              });

          await pumpEventQueue();

          final updatedInst = localDataSource.getInstances().firstWhere(
            (i) => i.id == 'I-inst-1',
          );
          expect(updatedInst.title, 'Updated Remote Inst');
          expect(updatedInst.labelIds, isEmpty);

          final remoteDoc = await firestore
              .collection('users')
              .doc('user1')
              .collection('instances')
              .doc('I-inst-1')
              .get();
          expect(remoteDoc.data()?['labelIds'], isNull);
        },
      );

      test(
        'remote task snapshot missing labelIds does not overwrite Firestore with older remote attributes when local task is newer',
        () async {
          final service = TaskSyncService(
            firestore: firestore,
            localDataSource: localDataSource,
            userId: 'user1',
            isActivePremium: true,
          );
          addTearDown(() => service.dispose());

          // 1. Local task is newer with updated title and labelIds
          final localTask = TaskSchedule(
            id: 'S-newer-local',
            title: 'Newer Local Title',
            description: 'Local Desc',
            schedules: [],
            labelIds: ['label-local-1'],
            updatedAt: DateTime(2026, 9, 12, 12, 0),
          );
          await localDataSource.saveTask(localTask);

          // 2. Older remote task written by older client (missing labelIds) arrives
          final remoteTime = DateTime(2026, 9, 10, 12, 0);
          await firestore
              .collection('users')
              .doc('user1')
              .collection('tasks')
              .doc('S-newer-local')
              .set({
                'id': 'S-newer-local',
                'title': 'Older Remote Title',
                'description': 'Remote Desc',
                'schedules': [],
                'updatedAt': remoteTime.toIso8601String(),
              });

          await pumpEventQueue();

          // 3. Local task should win and remain unchanged
          final preservedLocal = localDataSource.getTasks().firstWhere(
            (t) => t.id == 'S-newer-local',
          );
          expect(preservedLocal.title, 'Newer Local Title');
          expect(preservedLocal.labelIds, ['label-local-1']);

          // 4. Firestore should receive the newer local task, NOT the older remote attributes
          await pumpEventQueue();
          final remoteDoc = await firestore
              .collection('users')
              .doc('user1')
              .collection('tasks')
              .doc('S-newer-local')
              .get();
          expect(remoteDoc.data()?['title'], 'Newer Local Title');
          expect(remoteDoc.data()?['labelIds'], ['label-local-1']);
          expect(
            remoteDoc.data()?['updatedAt'],
            Timestamp.fromDate(DateTime(2026, 9, 12, 12, 0)),
          );
        },
      );

      test(
        'pushTaskToRemote and pushInstanceToRemote use merge: true and preserve unknown remote fields',
        () async {
          final service = TaskSyncService(
            firestore: firestore,
            localDataSource: localDataSource,
            userId: 'user1',
            isActivePremium: true,
          );
          addTearDown(() => service.dispose());

          // Pre-populate Firestore doc with an extra field from another version / extension
          await firestore
              .collection('users')
              .doc('user1')
              .collection('tasks')
              .doc('S-merge-test')
              .set({
                'id': 'S-merge-test',
                'title': 'Initial Title',
                'description': 'Initial Desc',
                'customServerField': 'preserve_me',
                'updatedAt': DateTime(2026, 9, 1, 12, 0).toIso8601String(),
              });
          await pumpEventQueue();

          // Save local task and push
          final localTask = TaskSchedule(
            id: 'S-merge-test',
            title: 'Updated Local Title',
            description: 'Updated Local Desc',
            schedules: [],
            labelIds: ['label-test'],
            updatedAt: DateTime(2026, 9, 10, 12, 0),
          );
          await localDataSource.saveTask(localTask);
          await localDataSource.markDirty('S-merge-test');

          await service.sync();
          await pumpEventQueue();

          // Verify updated title and labelIds were pushed, and customServerField was preserved
          final taskDoc = await firestore
              .collection('users')
              .doc('user1')
              .collection('tasks')
              .doc('S-merge-test')
              .get();
          expect(taskDoc.data()?['title'], 'Updated Local Title');
          expect(taskDoc.data()?['labelIds'], ['label-test']);
          expect(taskDoc.data()?['customServerField'], 'preserve_me');

          // Repeat for instance
          await firestore
              .collection('users')
              .doc('user1')
              .collection('instances')
              .doc('I-merge-test')
              .set({
                'id': 'I-merge-test',
                'scheduleId': 'S-merge-test',
                'ruleId': 'R-1',
                'title': 'Initial Instance',
                'customInstanceField': 'preserve_instance_field',
                'updatedAt': DateTime(2026, 9, 1, 12, 0).toIso8601String(),
              });
          await pumpEventQueue();

          final localInst = TaskInstance(
            id: 'I-merge-test',
            scheduleId: 'S-merge-test',
            ruleId: 'R-1',
            title: 'Updated Local Instance',
            description: 'Desc',
            scheduledDate: const CivilDay(year: 2026, month: 9, day: 12),
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              hour: 9,
              minute: 0,
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              hour: 10,
              minute: 0,
            ),
            labelIds: ['label-test'],
            updatedAt: DateTime(2026, 9, 10, 12, 0),
          );
          await localDataSource.saveInstance(localInst);
          await localDataSource.markDirty('I-merge-test');

          await service.sync();
          await pumpEventQueue();

          final instDoc = await firestore
              .collection('users')
              .doc('user1')
              .collection('instances')
              .doc('I-merge-test')
              .get();
          expect(instDoc.data()?['title'], 'Updated Local Instance');
          expect(instDoc.data()?['labelIds'], ['label-test']);
          expect(
            instDoc.data()?['customInstanceField'],
            'preserve_instance_field',
          );
        },
      );
    });

    group('Non-Parent Personal Task & Instance Sync (Issue #818)', () {
      test(
        'Personal Task Sync for Non-Parent does not attempt family deletion and clears hasPendingWrites',
        () async {
          await firestore.collection('users').doc('non_parent_user').set({
            'familyId': 'fam_123',
            'familyRole': 'non-parent',
          });

          final service = TaskSyncService(
            firestore: firestore,
            localDataSource: localDataSource,
            userId: 'non_parent_user',
            isActivePremium: true,
          );
          addTearDown(() => service.dispose());

          final task = TaskSchedule(
            id: 'S-pers-nonparent',
            title: 'Personal Non-Parent Task',
            description: 'Desc',
            schedules: [],
            isFamily: false,
            hasPendingWrites: true,
            updatedAt: DateTime(2026, 9, 25, 10, 0),
          );
          await localDataSource.saveTask(task);
          await localDataSource.markDirty('S-pers-nonparent');

          await service.sync();
          await pumpEventQueue();

          // 1. Task is saved in users/non_parent_user/tasks
          final userTaskDoc = await firestore
              .collection('users')
              .doc('non_parent_user')
              .collection('tasks')
              .doc('S-pers-nonparent')
              .get();
          expect(userTaskDoc.exists, isTrue);
          expect(userTaskDoc.data()?['title'], 'Personal Non-Parent Task');
          expect(userTaskDoc.data()?['isFamily'], isFalse);

          // 2. hasPendingWrites is cleared to false locally
          final localTask = localDataSource.getTasks().firstWhere(
            (t) => t.id == 'S-pers-nonparent',
          );
          expect(localTask.hasPendingWrites, isFalse);

          // 3. No document in families/fam_123/tasks
          final famTaskDoc = await firestore
              .collection('families')
              .doc('fam_123')
              .collection('tasks')
              .doc('S-pers-nonparent')
              .get();
          expect(famTaskDoc.exists, isFalse);
        },
      );

      test(
        'Personal Instance Sync for Non-Parent does not attempt family deletion and clears hasPendingWrites',
        () async {
          await firestore.collection('users').doc('non_parent_user').set({
            'familyId': 'fam_123',
            'familyRole': 'non-parent',
          });

          final service = TaskSyncService(
            firestore: firestore,
            localDataSource: localDataSource,
            userId: 'non_parent_user',
            isActivePremium: true,
          );
          addTearDown(() => service.dispose());

          final inst = TaskInstance(
            id: 'I-pers-nonparent',
            scheduleId: 'S-pers-nonparent',
            ruleId: 'R-1',
            title: 'Personal Non-Parent Instance',
            description: 'Desc',
            scheduledDate: const CivilDay(year: 2026, month: 9, day: 25),
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              hour: 9,
              minute: 0,
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              hour: 10,
              minute: 0,
            ),
            isFamily: false,
            hasPendingWrites: true,
            status: TaskStatus.pending,
            updatedAt: DateTime(2026, 9, 25, 10, 0),
          );
          await localDataSource.saveInstance(inst);
          await localDataSource.markDirty('I-pers-nonparent');

          await service.sync();
          await pumpEventQueue();

          // 1. Instance is saved in users/non_parent_user/instances
          final userInstDoc = await firestore
              .collection('users')
              .doc('non_parent_user')
              .collection('instances')
              .doc('I-pers-nonparent')
              .get();
          expect(userInstDoc.exists, isTrue);
          expect(userInstDoc.data()?['title'], 'Personal Non-Parent Instance');
          expect(userInstDoc.data()?['isFamily'], isFalse);

          // 2. hasPendingWrites is cleared to false locally
          final localInst = localDataSource.getInstances().firstWhere(
            (i) => i.id == 'I-pers-nonparent',
          );
          expect(localInst.hasPendingWrites, isFalse);

          // 3. No document in families/fam_123/instances
          final famInstDoc = await firestore
              .collection('families')
              .doc('fam_123')
              .collection('instances')
              .doc('I-pers-nonparent')
              .get();
          expect(famInstDoc.exists, isFalse);
        },
      );

      test(
        'Local Deletion of Personal Task & Instance for Non-Parent deletes from users and prevents resurrection',
        () async {
          await firestore.collection('users').doc('non_parent_user').set({
            'familyId': 'fam_123',
            'familyRole': 'non-parent',
          });

          // Seed personal task and instance remotely and locally
          await firestore
              .collection('users')
              .doc('non_parent_user')
              .collection('tasks')
              .doc('S-del-test')
              .set({
                'id': 'S-del-test',
                'title': 'Task To Delete',
                'isFamily': false,
              });
          await firestore
              .collection('users')
              .doc('non_parent_user')
              .collection('instances')
              .doc('I-del-test')
              .set({
                'id': 'I-del-test',
                'scheduleId': 'S-del-test',
                'title': 'Instance To Delete',
                'isFamily': false,
              });

          final service = TaskSyncService(
            firestore: firestore,
            localDataSource: localDataSource,
            userId: 'non_parent_user',
            isActivePremium: true,
          );
          addTearDown(() => service.dispose());
          await pumpEventQueue();

          // Verify items were loaded locally
          expect(
            localDataSource.getTasks().any((t) => t.id == 'S-del-test'),
            isTrue,
          );
          expect(
            localDataSource.getInstances().any((i) => i.id == 'I-del-test'),
            isTrue,
          );

          // Delete locally in Hive and mark dirty
          await localDataSource.deleteTask('S-del-test');
          await localDataSource.deleteInstance('I-del-test');
          await localDataSource.markDirty('S-del-test');
          await localDataSource.markDirty('I-del-test');

          await service.sync();
          await pumpEventQueue();

          // Verify document is removed from users/{userId}/tasks and users/{userId}/instances
          final userTaskDoc = await firestore
              .collection('users')
              .doc('non_parent_user')
              .collection('tasks')
              .doc('S-del-test')
              .get();
          expect(userTaskDoc.exists, isFalse);

          final userInstDoc = await firestore
              .collection('users')
              .doc('non_parent_user')
              .collection('instances')
              .doc('I-del-test')
              .get();
          expect(userInstDoc.exists, isFalse);

          // Verify not resurrected in local storage
          expect(
            localDataSource.getTasks().any((t) => t.id == 'S-del-test'),
            isFalse,
          );
          expect(
            localDataSource.getInstances().any((i) => i.id == 'I-del-test'),
            isFalse,
          );
        },
      );

      test(
        'Duplicate Instance Resolution for Non-Parent avoids unauthorized family deletion',
        () async {
          await firestore.collection('users').doc('non_parent_user').set({
            'familyId': 'fam_123',
            'familyRole': 'non-parent',
          });

          final service = TaskSyncService(
            firestore: firestore,
            localDataSource: localDataSource,
            userId: 'non_parent_user',
            isActivePremium: true,
          );
          addTearDown(() => service.dispose());

          // Local instance wins
          final localInst = TaskInstance(
            id: 'I-fam-local-win',
            scheduleId: 'S-fam-1',
            ruleId: 'R-1',
            title: 'Winning Local Family Instance',
            description: 'Desc',
            scheduledDate: const CivilDay(year: 2026, month: 9, day: 25),
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              hour: 9,
              minute: 0,
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              hour: 10,
              minute: 0,
            ),
            isFamily: true,
            status: TaskStatus.completed,
            statusReason: 'user_completed',
            updatedAt: DateTime(2026, 9, 25, 12, 0),
          );
          await localDataSource.saveInstance(localInst);

          // Remote instance with different ID for same slot (loser)
          await firestore
              .collection('families')
              .doc('fam_123')
              .collection('instances')
              .doc('I-fam-remote-loser')
              .set({
                'id': 'I-fam-remote-loser',
                'scheduleId': 'S-fam-1',
                'ruleId': 'R-1',
                'title': 'Losing Remote Family Instance',
                'scheduledDate': '2026-09-25',
                'startRelativeTime': {'dayOffset': 0, 'hour': 9, 'minute': 0},
                'dueRelativeTime': {'dayOffset': 0, 'hour': 10, 'minute': 0},
                'isFamily': true,
                'status': 'pending',
                'statusReason': 'scheduler_generated',
                'updatedAt': DateTime(2026, 9, 25, 11, 0).toIso8601String(),
              });

          // Trigger snapshot and ensure no uncaught permission exceptions
          await pumpEventQueue();

          // Local instance should be retained
          final instances = localDataSource.getInstances();
          expect(instances.any((i) => i.id == 'I-fam-local-win'), isTrue);
        },
      );

      test(
        'User doc role change without familyId change invalidates fetcher cache',
        () async {
          await firestore.collection('users').doc('user_role_change').set({
            'familyId': 'fam_role_test',
            'familyRole': 'non-parent',
          });

          final fetcher = _TrackingFamilyIdFetcher(
            firestore: firestore,
            userId: 'user_role_change',
          );

          final service = TaskSyncService(
            firestore: firestore,
            localDataSource: localDataSource,
            userId: 'user_role_change',
            isActivePremium: true,
            familyIdFetcher: fetcher,
          );
          addTearDown(() => service.dispose());
          await pumpEventQueue();

          final initialClearCalls = fetcher.clearCacheCalls;

          // Update user doc with role change while familyId remains unchanged
          await firestore.collection('users').doc('user_role_change').set({
            'familyId': 'fam_role_test',
            'familyRole': 'parent',
          });
          await pumpEventQueue();

          // Verify clearCache() was called when role changed
          expect(fetcher.clearCacheCalls, greaterThan(initialClearCalls));
        },
      );

      test(
        'Duplicate family instance resolution does not delete from user collection when familyId is null or empty',
        () async {
          await firestore.collection('users').doc('user_no_fam').set({
            'name': 'No Family User',
          });

          // Seed personal instance with same ID in user collection
          await firestore
              .collection('users')
              .doc('user_no_fam')
              .collection('instances')
              .doc('I-slot-duplicate')
              .set({
                'id': 'I-slot-duplicate',
                'scheduleId': 'S-pers-1',
                'ruleId': 'R-1',
                'title': 'User Personal Instance',
                'scheduledDate': '2026-09-25',
                'startRelativeTime': {'dayOffset': 0, 'hour': 9, 'minute': 0},
                'dueRelativeTime': {'dayOffset': 0, 'hour': 10, 'minute': 0},
                'isFamily': false,
                'status': 'pending',
                'statusReason': 'scheduler_generated',
                'updatedAt': DateTime(2026, 9, 25, 9, 0).toIso8601String(),
              });

          final service = TaskSyncService(
            firestore: firestore,
            localDataSource: localDataSource,
            userId: 'user_no_fam',
            isActivePremium: true,
          );
          addTearDown(() => service.dispose());
          await pumpEventQueue();

          final userInst = await firestore
              .collection('users')
              .doc('user_no_fam')
              .collection('instances')
              .doc('I-slot-duplicate')
              .get();
          expect(userInst.exists, isTrue);
        },
      );
    });
  });
}

class _TrackingFamilyIdFetcher extends FamilyIdFetcher {
  int getFamilyIdCalls = 0;
  int clearCacheCalls = 0;
  final String? stubbedId;

  _TrackingFamilyIdFetcher({
    required super.firestore,
    required super.userId,
    this.stubbedId,
  });

  @override
  void clearCache() {
    clearCacheCalls++;
    super.clearCache();
  }

  @override
  Future<String?> getFamilyId() async {
    getFamilyIdCalls++;
    if (stubbedId != null) return stubbedId;
    return super.getFamilyId();
  }
}

class _FailingHiveLocalDataSource extends HiveLocalDataSource {
  @override
  bool isMigrationCompleted() => true;

  @override
  List<String> getDirtyTaskIds() {
    throw Exception('Simulated local data source failure');
  }
}

class _HookedHiveLocalDataSource extends HiveLocalDataSource {
  void Function(String id)? onClearDirty;

  @override
  bool isMigrationCompleted() => true;

  @override
  Future<void> clearDirty(String id) async {
    onClearDirty?.call(id);
    await super.clearDirty(id);
  }
}

class _IntermittentHiveLocalDataSource extends HiveLocalDataSource {
  bool shouldFail = false;

  @override
  bool isMigrationCompleted() => true;

  @override
  List<TaskSchedule> getTasks() {
    if (shouldFail) {
      throw Exception('Simulated transient error during getTasks()');
    }
    return super.getTasks();
  }
}
