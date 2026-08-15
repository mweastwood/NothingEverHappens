import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nothing_ever_happens/logic/initial_firebase_migration_service.dart';
import 'package:nothing_ever_happens/logic/hive_local_data_source.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
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

  test('Migration of pre-existing user tasks from Firestore', () async {
    await firestore.collection('users').doc('user1').set({'familyId': 'fam1'});

    await firestore
        .collection('users')
        .doc('user1')
        .collection('tasks')
        .doc('S-1')
        .set({
          'id': 'S-1',
          'title': 'User Task',
          'updatedAt': DateTime.now().toIso8601String(),
        });

    await firestore
        .collection('users')
        .doc('user1')
        .collection('instances')
        .doc('I-1')
        .set({
          'id': 'I-1',
          'scheduleId': 'S-1',
          'title': 'User Instance',
          'updatedAt': DateTime.now().toIso8601String(),
        });

    final service = InitialFirebaseMigrationService(
      firestore: firestore,
      localDataSource: localDataSource,
      userId: 'user1',
    );

    expect(localDataSource.isMigrationCompleted(), false);

    await service.migrateIfNeeded();

    expect(localDataSource.isMigrationCompleted(), true);

    final tasks = localDataSource.getTasks();
    expect(tasks.length, 1);
    expect(tasks.first.id, 'S-1');

    final instances = localDataSource.getInstances();
    expect(instances.length, 1);
    expect(instances.first.id, 'I-1');
  });

  test('Migration does not run if migration_completed is true', () async {
    await firestore
        .collection('users')
        .doc('user1')
        .collection('tasks')
        .doc('S-1')
        .set({
          'id': 'S-1',
          'title': 'User Task',
          'updatedAt': DateTime.now().toIso8601String(),
        });

    await localDataSource.setMigrationCompleted(true);

    final service = InitialFirebaseMigrationService(
      firestore: firestore,
      localDataSource: localDataSource,
      userId: 'user1',
    );

    await service.migrateIfNeeded();

    final tasks = localDataSource.getTasks();
    expect(tasks.isEmpty, true); // Since migration was skipped
  });

  test(
    'Migration performs clean slate wipe of stale local data before saving',
    () async {
      // 1. Pre-populate local storage with stale offline artifacts and dirty queue
      final staleTask = TaskSchedule(
        id: 'S-stale',
        title: 'Stale Local Task',
        description: 'Stale',
        schedules: [],
        updatedAt: DateTime.now(),
      );
      final staleInstance = TaskInstance(
        id: 'I-stale',
        scheduleId: 'S-stale',
        ruleId: 'rule1',
        title: 'Stale Inst',
        description: 'Stale',
        scheduledDate: CivilDay(year: 2026, month: 8, day: 1),
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
      await localDataSource.saveTask(staleTask);
      await localDataSource.saveInstance(staleInstance);
      await localDataSource.markDirty('S-stale');
      await localDataSource.markDirty('I-stale');

      expect(localDataSource.getTasks().length, 1);
      expect(localDataSource.getInstances().length, 1);
      expect(localDataSource.getDirtyTaskIds().length, 2);

      // 2. Set up clean cloud data
      await firestore
          .collection('users')
          .doc('user1')
          .collection('tasks')
          .doc('S-clean')
          .set({
            'id': 'S-clean',
            'title': 'Clean Cloud Task',
            'updatedAt': DateTime.now().toIso8601String(),
          });

      final service = InitialFirebaseMigrationService(
        firestore: firestore,
        localDataSource: localDataSource,
        userId: 'user1',
      );

      await service.migrateIfNeeded();

      // 3. Stale items and dirty queue should be wiped, replaced by clean cloud task
      final tasks = localDataSource.getTasks();
      expect(tasks.length, 1);
      expect(tasks.first.id, 'S-clean');
      expect(localDataSource.getInstances().isEmpty, true);
      expect(localDataSource.getDirtyTaskIds().isEmpty, true);
      expect(localDataSource.isMigrationCompleted(), true);
    },
  );

  test('Concurrent migrateIfNeeded calls are deduplicated in-flight', () async {
    await firestore
        .collection('users')
        .doc('user1')
        .collection('tasks')
        .doc('S-1')
        .set({
          'id': 'S-1',
          'title': 'User Task',
          'updatedAt': DateTime.now().toIso8601String(),
        });

    final service1 = InitialFirebaseMigrationService(
      firestore: firestore,
      localDataSource: localDataSource,
      userId: 'user1',
    );
    final service2 = InitialFirebaseMigrationService(
      firestore: firestore,
      localDataSource: localDataSource,
      userId: 'user1',
    );

    // Call concurrently
    await Future.wait([service1.migrateIfNeeded(), service2.migrateIfNeeded()]);

    expect(localDataSource.isMigrationCompleted(), true);
    expect(localDataSource.getTasks().length, 1);
  });

  test(
    'migrateIfNeeded with force: true runs even when isMigrationCompleted is true',
    () async {
      await firestore
          .collection('users')
          .doc('user1')
          .collection('tasks')
          .doc('S-fresh')
          .set({
            'id': 'S-fresh',
            'title': 'Fresh Cloud Task',
            'updatedAt': DateTime.now().toIso8601String(),
          });

      await localDataSource.setMigrationCompleted(true);

      final service = InitialFirebaseMigrationService(
        firestore: firestore,
        localDataSource: localDataSource,
        userId: 'user1',
      );

      await service.migrateIfNeeded(force: true);

      final tasks = localDataSource.getTasks();
      expect(tasks.length, 1);
      expect(tasks.first.id, 'S-fresh');
    },
  );
}
