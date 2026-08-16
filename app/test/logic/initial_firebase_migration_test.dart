// ignore_for_file: subtype_of_sealed_class

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nothing_ever_happens/logic/initial_firebase_migration_service.dart';
import 'package:nothing_ever_happens/logic/hive_local_data_source.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
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

  test(
    'Migration bounds instances to 90-day cutoffDate for personal and family instances',
    () async {
      final now = DateTime(2026, 8, 15, 12, 0);
      AppClock.setMockTime(now);
      addTearDown(AppClock.reset);

      await firestore.collection('users').doc('user1').set({
        'familyId': 'fam1',
      });

      // Personal tasks
      await firestore
          .collection('users')
          .doc('user1')
          .collection('tasks')
          .doc('S-1')
          .set({
            'id': 'S-1',
            'title': 'User Task',
            'updatedAt': now.toIso8601String(),
          });

      // Personal instances: 10 days old (within 90d) and 100 days old (outside 90d)
      await firestore
          .collection('users')
          .doc('user1')
          .collection('instances')
          .doc('I-recent')
          .set({
            'id': 'I-recent',
            'scheduleId': 'S-1',
            'title': 'Recent Personal Instance',
            'updatedAt': now.subtract(const Duration(days: 10)),
          });

      await firestore
          .collection('users')
          .doc('user1')
          .collection('instances')
          .doc('I-old')
          .set({
            'id': 'I-old',
            'scheduleId': 'S-1',
            'title': 'Old Personal Instance',
            'updatedAt': now.subtract(const Duration(days: 100)),
          });

      // Family instances: 20 days old (within 90d) and 120 days old (outside 90d)
      await firestore
          .collection('families')
          .doc('fam1')
          .collection('instances')
          .doc('I-fam-recent')
          .set({
            'id': 'I-fam-recent',
            'scheduleId': 'S-1',
            'title': 'Recent Family Instance',
            'updatedAt': now.subtract(const Duration(days: 20)),
          });

      await firestore
          .collection('families')
          .doc('fam1')
          .collection('instances')
          .doc('I-fam-old')
          .set({
            'id': 'I-fam-old',
            'scheduleId': 'S-1',
            'title': 'Old Family Instance',
            'updatedAt': now.subtract(const Duration(days: 120)),
          });

      final service = InitialFirebaseMigrationService(
        firestore: firestore,
        localDataSource: localDataSource,
        userId: 'user1',
      );

      await service.migrateIfNeeded();

      final instances = localDataSource.getInstances();
      final instanceIds = instances.map((i) => i.id).toSet();

      expect(instanceIds, contains('I-recent'));
      expect(instanceIds, contains('I-fam-recent'));
      expect(instanceIds, isNot(contains('I-old')));
      expect(instanceIds, isNot(contains('I-fam-old')));
    },
  );

  test(
    'Migration falls back to limit(300) when cutoffDate query fails on personal and family instances',
    () async {
      final failingFirestore = _FailingWhereFirestore();
      final logger = AppLogger(capacity: 20);

      await failingFirestore.collection('users').doc('user1').set({
        'familyId': 'fam1',
      });

      await failingFirestore
          .collection('users')
          .doc('user1')
          .collection('tasks')
          .doc('S-1')
          .set({
            'id': 'S-1',
            'title': 'Personal Task',
            'updatedAt': DateTime.now().toIso8601String(),
          });

      await failingFirestore
          .collection('users')
          .doc('user1')
          .collection('instances')
          .doc('I-personal-fallback')
          .set({
            'id': 'I-personal-fallback',
            'scheduleId': 'S-1',
            'title': 'Fallback Personal Instance',
            'updatedAt': DateTime.now().toIso8601String(),
          });

      await failingFirestore
          .collection('families')
          .doc('fam1')
          .collection('tasks')
          .doc('S-fam-1')
          .set({
            'id': 'S-fam-1',
            'title': 'Family Task',
            'updatedAt': DateTime.now().toIso8601String(),
          });

      await failingFirestore
          .collection('families')
          .doc('fam1')
          .collection('instances')
          .doc('I-family-fallback')
          .set({
            'id': 'I-family-fallback',
            'scheduleId': 'S-fam-1',
            'title': 'Fallback Family Instance',
            'updatedAt': DateTime.now().toIso8601String(),
          });

      final service = InitialFirebaseMigrationService(
        firestore: failingFirestore,
        localDataSource: localDataSource,
        userId: 'user1',
        logger: logger,
      );

      await service.migrateIfNeeded();

      expect(localDataSource.isMigrationCompleted(), true);

      final instances = localDataSource.getInstances();
      final instanceIds = instances.map((i) => i.id).toSet();
      expect(instanceIds, contains('I-personal-fallback'));
      expect(instanceIds, contains('I-family-fallback'));

      final warningMessages = logger
          .getEvents()
          .where((e) => e.level == LogLevel.warning)
          .map((e) => e.message)
          .toList();

      expect(
        warningMessages,
        contains(
          'Failed to query instances with cutoffDate, falling back to limit(300)',
        ),
      );
      expect(
        warningMessages,
        contains(
          'Failed to query family instances with cutoffDate, falling back to limit(300)',
        ),
      );
    },
  );
}

class _FailingWhereFirestore extends FakeFirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return _FailingWhereCollectionReference(super.collection(collectionPath));
  }
}

class _FailingWhereCollectionReference extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final CollectionReference<Map<String, dynamic>> _delegate;
  _FailingWhereCollectionReference(this._delegate);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return _FailingWhereDocumentReference(_delegate.doc(path));
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) =>
      _delegate.get(options);

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => _delegate.snapshots(
    includeMetadataChanges: includeMetadataChanges,
    source: source,
  );

  @override
  Query<Map<String, dynamic>> limit(int limit) => _delegate.limit(limit);

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    if (field == 'updatedAt') {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'failed-precondition',
        message: 'The query requires an index.',
      );
    }
    return _delegate.where(
      field,
      isEqualTo: isEqualTo,
      isNotEqualTo: isNotEqualTo,
      isLessThan: isLessThan,
      isLessThanOrEqualTo: isLessThanOrEqualTo,
      isGreaterThan: isGreaterThan,
      isGreaterThanOrEqualTo: isGreaterThanOrEqualTo,
      arrayContains: arrayContains,
      arrayContainsAny: arrayContainsAny,
      whereIn: whereIn,
      whereNotIn: whereNotIn,
      isNull: isNull,
    );
  }
}

class _FailingWhereDocumentReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  final DocumentReference<Map<String, dynamic>> _delegate;
  _FailingWhereDocumentReference(this._delegate);

  @override
  String get id => _delegate.id;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return _FailingWhereCollectionReference(
      _delegate.collection(collectionPath),
    );
  }

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) =>
      _delegate.get(options);

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => _delegate.snapshots(
    includeMetadataChanges: includeMetadataChanges,
    source: source,
  );

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) =>
      _delegate.set(data, options);
}
