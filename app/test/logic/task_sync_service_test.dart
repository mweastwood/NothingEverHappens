import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nothing_ever_happens/logic/task_sync_service.dart';
import 'package:nothing_ever_happens/logic/hive_local_data_source.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
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
  List<String> getDirtyTaskIds() {
    throw Exception('Simulated local data source failure');
  }
}
