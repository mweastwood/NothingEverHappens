import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nothing_ever_happens/logic/hive_local_data_source.dart';
import 'package:nothing_ever_happens/logic/initial_firebase_migration_service.dart';
import 'package:nothing_ever_happens/logic/unified_task_repository.dart';
import 'package:nothing_ever_happens/logic/task_sync_service.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late HiveLocalDataSource localDataSource;
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('startup_regression_test_');

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
    fakeFirestore = FakeFirebaseFirestore();
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('App Startup & Initial Migration Regression Tests', () {
    test(
      'Initial launch with unmigrated Firestore tasks automatically migrates data into Hive in background without blocking repository initialization',
      () async {
        // Populate pre-existing user data in Firestore
        final userTaskRef = fakeFirestore
            .collection('users')
            .doc('migrating-user')
            .collection('tasks')
            .doc('S-legacy-task');

        await userTaskRef.set({
          'id': 'S-legacy-task',
          'title': 'Legacy Task from Firebase',
          'description': 'Existed before Hive update',
          'isFamily': false,
          'priority': 'medium',
          'schedules': [
            {
              'type': 'oneOff',
              'date': {'year': 2026, 'month': 8, 'day': 4},
              'schedulingPolicy': {'type': 'fixedCalendar'},
              'missedOccurrencePolicy': {'type': 'keepAround'},
              'notificationRelativeTimes': [],
            },
          ],
          'updatedAt': DateTime.now().toIso8601String(),
        });

        final userInstanceRef = fakeFirestore
            .collection('users')
            .doc('migrating-user')
            .collection('instances')
            .doc('I-legacy-inst');

        await userInstanceRef.set({
          'id': 'I-legacy-inst',
          'scheduleId': 'S-legacy-task',
          'ruleId': 'rule-1',
          'title': 'Legacy Task from Firebase',
          'description': 'Existed before Hive update',
          'scheduledDate': {'year': 2026, 'month': 8, 'day': 4},
          'status': 'pending',
          'isFamily': false,
          'priority': 'medium',
          'updatedAt': DateTime.now().toIso8601String(),
        });

        expect(localDataSource.isMigrationCompleted(), isFalse);

        final syncService = TaskSyncService(
          firestore: fakeFirestore,
          localDataSource: localDataSource,
          userId: 'migrating-user',
          isActivePremium: false,
        );

        final migrationService = InitialFirebaseMigrationService(
          firestore: fakeFirestore,
          localDataSource: localDataSource,
          userId: 'migrating-user',
        );

        final repo = UnifiedTaskRepository(
          localDataSource: localDataSource,
          syncService: syncService,
          userId: 'migrating-user',
          firestore: fakeFirestore,
        );
        expect(repo, isNotNull);

        await migrationService.migrateIfNeeded();

        expect(localDataSource.isMigrationCompleted(), isTrue);

        final migratedTasks = localDataSource.getTasks();
        expect(migratedTasks.any((t) => t.id == 'S-legacy-task'), isTrue);

        final migratedInstances = localDataSource.getInstances();
        expect(migratedInstances.any((i) => i.id == 'I-legacy-inst'), isTrue);

        syncService.dispose();
      },
    );

    test(
      'Subsequent app launch skips migration and loads instantly from Hive',
      () async {
        await localDataSource.setMigrationCompleted(true);

        final existingTask = TaskSchedule(
          id: 'S-hive-local-task',
          title: 'Existing Hive Task',
          description: '',
          isFamily: false,
          schedules: const [],
          updatedAt: DateTime.now(),
        );
        await localDataSource.saveTask(existingTask);

        final syncService = TaskSyncService(
          firestore: fakeFirestore,
          localDataSource: localDataSource,
          userId: 'migrating-user',
          isActivePremium: false,
        );

        final migrationService = InitialFirebaseMigrationService(
          firestore: fakeFirestore,
          localDataSource: localDataSource,
          userId: 'migrating-user',
        );

        await migrationService.migrateIfNeeded();

        final tasks = localDataSource.getTasks();
        expect(tasks.length, equals(1));
        expect(tasks.first.id, equals('S-hive-local-task'));

        syncService.dispose();
      },
    );
  });
}
