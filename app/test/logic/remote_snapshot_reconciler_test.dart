import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/firestore_paths.dart';
import 'package:nothing_ever_happens/logic/hive_local_data_source.dart';
import 'package:nothing_ever_happens/logic/recipes/recipe.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/remote_snapshot_reconciler.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late FakeFirebaseFirestore firestore;
  late HiveLocalDataSource localDataSource;
  late List<TaskSchedule> pushedTasks;
  late List<TaskInstance> pushedInstances;
  late RemoteSnapshotReconciler reconciler;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('snapshot_reconciler_test');
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
    firestore = FakeFirebaseFirestore();
    localDataSource = HiveLocalDataSource();
    await localDataSource.init();
    await localDataSource.setMigrationCompleted(true);
    pushedTasks = [];
    pushedInstances = [];

    reconciler = RemoteSnapshotReconciler(
      firestore: firestore,
      localDataSource: localDataSource,
      userId: 'user-1',
      getFamilyId: () async => 'fam-1',
      isFamilyParent: () async => true,
      pushTaskToRemote: (task) async {
        pushedTasks.add(task);
        return true;
      },
      pushInstanceToRemote: (inst) async {
        pushedInstances.add(inst);
        return true;
      },
    );
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('RemoteSnapshotReconciler', () {
    test(
      'handleRemoteTasksSnapshot saves newer remote tasks and pushes newer local tasks',
      () async {
        final localNewer = TaskSchedule(
          id: 'S-local-wins',
          title: 'Local Newer',
          description: 'Desc',
          updatedAt: DateTime.utc(2026, 9, 16, 14, 0),
        );
        await localDataSource.saveTask(localNewer);

        final remoteOlder = TaskSchedule(
          id: 'S-local-wins',
          title: 'Remote Older',
          description: 'Desc',
          updatedAt: DateTime.utc(2026, 9, 16, 10, 0),
        );
        final remoteBrandNew = TaskSchedule(
          id: 'S-remote-new',
          title: 'Remote Brand New',
          description: 'Desc',
          updatedAt: DateTime.utc(2026, 9, 16, 12, 0),
        );

        final col = firestore
            .collection(FirestorePaths.users)
            .doc('user-1')
            .collection(FirestorePaths.tasks);
        await col.doc(remoteOlder.id).set(remoteOlder.toFirestore());
        await col.doc(remoteBrandNew.id).set(remoteBrandNew.toFirestore());

        final snapshot = await col.get();
        await reconciler.handleRemoteTasksSnapshot(snapshot, isFamily: false);

        expect(pushedTasks.map((t) => t.id), equals(['S-local-wins']));
        final stored = {for (final t in localDataSource.getTasks()) t.id: t};
        expect(stored['S-local-wins']!.title, equals('Local Newer'));
        expect(stored['S-remote-new']!.title, equals('Remote Brand New'));
      },
    );

    test(
      'handleRemoteInstancesSnapshot resolves slot duplicates and deletes losing remote duplicate',
      () async {
        const date = CivilDay(year: 2026, month: 9, day: 16);
        final localCanonical = TaskInstance(
          id: 'i-local-earlier',
          scheduleId: 's-1',
          ruleId: 'r-1',
          title: 'Daily Task',
          description: 'Desc',
          scheduledDate: date,
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
          updatedAt: DateTime.utc(2026, 9, 16, 8, 0),
        );
        await localDataSource.saveInstance(localCanonical);

        final remoteDuplicateLater = TaskInstance(
          id: 'i-remote-later',
          scheduleId: 's-1',
          ruleId: 'r-1',
          title: 'Daily Task',
          description: 'Desc',
          scheduledDate: date,
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
          updatedAt: DateTime.utc(2026, 9, 16, 9, 0),
        );

        final col = firestore
            .collection(FirestorePaths.users)
            .doc('user-1')
            .collection(FirestorePaths.instances);
        await col
            .doc(remoteDuplicateLater.id)
            .set(remoteDuplicateLater.toFirestore());

        final snapshot = await col.get();
        await reconciler.handleRemoteInstancesSnapshot(
          snapshot,
          isFamily: false,
        );

        // Earlier local canonical pending instance wins and pushes to remote; losing remote duplicate is deleted
        expect(pushedInstances.map((i) => i.id), equals(['i-local-earlier']));
        final remainingRemote = await col.doc('i-remote-later').get();
        expect(remainingRemote.exists, isFalse);
      },
    );

    test('handleRemoteRecipesSnapshot saves newer remote recipes', () async {
      final recipe = Recipe(
        id: 'r-1',
        title: 'Lemon Pasta',
        updatedAt: DateTime.utc(2026, 9, 16, 12, 0),
      );
      final col = firestore
          .collection(FirestorePaths.users)
          .doc('user-1')
          .collection(FirestorePaths.recipes);
      await col.doc(recipe.id).set(recipe.toFirestore());

      final snapshot = await col.get();
      await reconciler.handleRemoteRecipesSnapshot(snapshot, isFamily: false);

      final savedRecipes = localDataSource.getRecipes();
      expect(savedRecipes, hasLength(1));
      expect(savedRecipes.first.title, equals('Lemon Pasta'));
    });
  });
}
