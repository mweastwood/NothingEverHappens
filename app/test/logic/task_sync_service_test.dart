import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nothing_ever_happens/logic/task_sync_service.dart';
import 'package:nothing_ever_happens/logic/hive_local_data_source.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
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

    // Wait a bit for the stream to process
    await Future.delayed(const Duration(milliseconds: 100));

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

    await Future.delayed(const Duration(milliseconds: 100));

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

    await Future.delayed(const Duration(milliseconds: 100));

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

      await Future.delayed(const Duration(milliseconds: 100));

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

      await Future.delayed(const Duration(milliseconds: 100));

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
}

class _FailingHiveLocalDataSource extends HiveLocalDataSource {
  @override
  bool isMigrationCompleted() => true;

  @override
  List<String> getDirtyTaskIds() {
    throw Exception('Simulated local data source failure');
  }
}
