import 'dart:io';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nothing_ever_happens/logic/hive_local_data_source.dart';
import 'package:nothing_ever_happens/logic/recipes/recipe.dart';
import 'package:nothing_ever_happens/logic/recipes/recipe_repository.dart';
import 'package:nothing_ever_happens/logic/remote_snapshot_reconciler.dart';
import 'package:nothing_ever_happens/logic/task_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebaseFirestore firestore;
  late HiveLocalDataSource localDataSource;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('recipe_repo_test');

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

  test('saveRecipe saves personal recipe to users/{userId}/recipes', () async {
    final repo = RecipeRepository(
      localDataSource: localDataSource,
      firestore: firestore,
      userId: 'user1',
      isActivePremium: true,
      familyId: 'fam1',
    );

    final recipe = Recipe(
      id: 'R-1',
      title: 'Personal Pasta',
      description: 'Quick dinner',
      servings: 2,
      isFamily: false,
    );

    await repo.saveRecipe(recipe);

    // Verify local storage
    final localRecipe = repo.getRecipeById('R-1');
    expect(localRecipe, isNotNull);
    expect(localRecipe!.title, 'Personal Pasta');
    expect(localRecipe.hasPendingWrites, isFalse);

    // Verify written to users/user1/recipes
    final userDoc = await firestore
        .collection('users')
        .doc('user1')
        .collection('recipes')
        .doc('R-1')
        .get();
    expect(userDoc.exists, isTrue);
    expect(userDoc.data()?['title'], 'Personal Pasta');
    expect(userDoc.data()?['isFamily'], isFalse);

    // Verify NOT written to families/fam1/recipes
    final famDoc = await firestore
        .collection('families')
        .doc('fam1')
        .collection('recipes')
        .doc('R-1')
        .get();
    expect(famDoc.exists, isFalse);
  });

  test(
    'saveRecipe saves family recipe to families/{familyId}/recipes',
    () async {
      final repo = RecipeRepository(
        localDataSource: localDataSource,
        firestore: firestore,
        userId: 'user1',
        isActivePremium: true,
        familyId: 'fam1',
      );

      final recipe = Recipe(
        id: 'R-fam1',
        title: 'Family Stew',
        description: 'Slow cooker stew for everyone',
        servings: 6,
        isFamily: true,
      );

      await repo.saveRecipe(recipe);

      // Verify local storage
      final localRecipe = repo.getRecipeById('R-fam1');
      expect(localRecipe, isNotNull);
      expect(localRecipe!.title, 'Family Stew');
      expect(localRecipe.hasPendingWrites, isFalse);

      // Verify written to families/fam1/recipes
      final famDoc = await firestore
          .collection('families')
          .doc('fam1')
          .collection('recipes')
          .doc('R-fam1')
          .get();
      expect(famDoc.exists, isTrue);
      expect(famDoc.data()?['title'], 'Family Stew');
      expect(famDoc.data()?['isFamily'], isTrue);

      // Verify NOT in users/user1/recipes
      final userDoc = await firestore
          .collection('users')
          .doc('user1')
          .collection('recipes')
          .doc('R-fam1')
          .get();
      expect(userDoc.exists, isFalse);
    },
  );

  test(
    'saveRecipe resolves familyId dynamically from Firestore user doc if not passed in constructor',
    () async {
      await firestore.collection('users').doc('user1').set({
        'familyId': 'fam-dynamic',
      });

      final repo = RecipeRepository(
        localDataSource: localDataSource,
        firestore: firestore,
        userId: 'user1',
        isActivePremium: true,
      );

      final recipe = Recipe(
        id: 'R-dyn',
        title: 'Dynamic Family Recipe',
        isFamily: true,
      );

      await repo.saveRecipe(recipe);

      final famDoc = await firestore
          .collection('families')
          .doc('fam-dynamic')
          .collection('recipes')
          .doc('R-dyn')
          .get();
      expect(famDoc.exists, isTrue);
      expect(famDoc.data()?['title'], 'Dynamic Family Recipe');
    },
  );

  test(
    'Converting personal recipe to family moves remote document to families/{familyId}',
    () async {
      final repo = RecipeRepository(
        localDataSource: localDataSource,
        firestore: firestore,
        userId: 'user1',
        isActivePremium: true,
        familyId: 'fam1',
      );

      // 1. Save as personal recipe
      final personalRecipe = Recipe(
        id: 'R-conv',
        title: 'Original Personal Recipe',
        isFamily: false,
      );
      await repo.saveRecipe(personalRecipe);

      final userDoc1 = await firestore
          .collection('users')
          .doc('user1')
          .collection('recipes')
          .doc('R-conv')
          .get();
      expect(userDoc1.exists, isTrue);

      // 2. Update to family recipe
      final familyRecipe = personalRecipe.copyWith(
        title: 'Now Family Recipe',
        isFamily: true,
      );
      await repo.saveRecipe(familyRecipe);

      // Should now exist in families/fam1/recipes
      final famDoc = await firestore
          .collection('families')
          .doc('fam1')
          .collection('recipes')
          .doc('R-conv')
          .get();
      expect(famDoc.exists, isTrue);
      expect(famDoc.data()?['title'], 'Now Family Recipe');
      expect(famDoc.data()?['isFamily'], isTrue);

      // Should be deleted from users/user1/recipes
      final userDoc2 = await firestore
          .collection('users')
          .doc('user1')
          .collection('recipes')
          .doc('R-conv')
          .get();
      expect(userDoc2.exists, isFalse);
    },
  );

  test(
    'Converting family recipe to personal moves remote document to users/{userId}',
    () async {
      final repo = RecipeRepository(
        localDataSource: localDataSource,
        firestore: firestore,
        userId: 'user1',
        isActivePremium: true,
        familyId: 'fam1',
      );

      // 1. Save as family recipe
      final familyRecipe = Recipe(
        id: 'R-conv2',
        title: 'Original Family Recipe',
        isFamily: true,
      );
      await repo.saveRecipe(familyRecipe);

      final famDoc1 = await firestore
          .collection('families')
          .doc('fam1')
          .collection('recipes')
          .doc('R-conv2')
          .get();
      expect(famDoc1.exists, isTrue);

      // 2. Update to personal recipe
      final personalRecipe = familyRecipe.copyWith(
        title: 'Now Personal Recipe',
        isFamily: false,
      );
      await repo.saveRecipe(personalRecipe);

      // Should now exist in users/user1/recipes
      final userDoc = await firestore
          .collection('users')
          .doc('user1')
          .collection('recipes')
          .doc('R-conv2')
          .get();
      expect(userDoc.exists, isTrue);
      expect(userDoc.data()?['title'], 'Now Personal Recipe');
      expect(userDoc.data()?['isFamily'], isFalse);

      // Should be deleted from families/fam1/recipes
      final famDoc2 = await firestore
          .collection('families')
          .doc('fam1')
          .collection('recipes')
          .doc('R-conv2')
          .get();
      expect(famDoc2.exists, isFalse);
    },
  );

  test(
    'deleteRecipe deletes family recipe from families/{familyId}/recipes and local storage',
    () async {
      final repo = RecipeRepository(
        localDataSource: localDataSource,
        firestore: firestore,
        userId: 'user1',
        isActivePremium: true,
        familyId: 'fam1',
      );

      final familyRecipe = Recipe(
        id: 'R-fam-del',
        title: 'Family Recipe To Delete',
        isFamily: true,
      );
      await repo.saveRecipe(familyRecipe);

      expect(repo.getRecipeById('R-fam-del'), isNotNull);
      final famDoc1 = await firestore
          .collection('families')
          .doc('fam1')
          .collection('recipes')
          .doc('R-fam-del')
          .get();
      expect(famDoc1.exists, isTrue);

      await repo.deleteRecipe('R-fam-del');

      expect(repo.getRecipeById('R-fam-del'), isNull);
      final famDoc2 = await firestore
          .collection('families')
          .doc('fam1')
          .collection('recipes')
          .doc('R-fam-del')
          .get();
      expect(famDoc2.exists, isFalse);
    },
  );

  test(
    'deleteRecipe deletes personal recipe from users/{userId}/recipes and local storage',
    () async {
      final repo = RecipeRepository(
        localDataSource: localDataSource,
        firestore: firestore,
        userId: 'user1',
        isActivePremium: true,
        familyId: 'fam1',
      );

      final personalRecipe = Recipe(
        id: 'R-pers-del',
        title: 'Personal Recipe To Delete',
        isFamily: false,
      );
      await repo.saveRecipe(personalRecipe);

      expect(repo.getRecipeById('R-pers-del'), isNotNull);
      final userDoc1 = await firestore
          .collection('users')
          .doc('user1')
          .collection('recipes')
          .doc('R-pers-del')
          .get();
      expect(userDoc1.exists, isTrue);

      await repo.deleteRecipe('R-pers-del');

      expect(repo.getRecipeById('R-pers-del'), isNull);
      final userDoc2 = await firestore
          .collection('users')
          .doc('user1')
          .collection('recipes')
          .doc('R-pers-del')
          .get();
      expect(userDoc2.exists, isFalse);
    },
  );

  test(
    'Free user saves only to local storage and does not write to remote Firestore',
    () async {
      final repo = RecipeRepository(
        localDataSource: localDataSource,
        firestore: firestore,
        userId: 'user1',
        isActivePremium: false,
        familyId: 'fam1',
      );

      final familyRecipe = Recipe(
        id: 'R-free',
        title: 'Free User Recipe',
        isFamily: true,
      );
      await repo.saveRecipe(familyRecipe);

      expect(repo.getRecipeById('R-free'), isNotNull);
      expect(repo.getRecipeById('R-free')!.hasPendingWrites, isFalse);

      final famDoc = await firestore
          .collection('families')
          .doc('fam1')
          .collection('recipes')
          .doc('R-free')
          .get();
      expect(famDoc.exists, isFalse);

      final userDoc = await firestore
          .collection('users')
          .doc('user1')
          .collection('recipes')
          .doc('R-free')
          .get();
      expect(userDoc.exists, isFalse);
    },
  );

  test('Recipe.toJson and Recipe.fromJson round-trip hasPendingWrites', () {
    final pendingRecipe = Recipe(
      id: 'R-pending',
      title: 'Offline Pasta',
      hasPendingWrites: true,
    );
    final json = pendingRecipe.toJson();
    expect(json['hasPendingWrites'], isTrue);
    final restored = Recipe.fromJson(json);
    expect(restored.hasPendingWrites, isTrue);

    final cleanRecipe = pendingRecipe.copyWith(hasPendingWrites: false);
    final cleanJson = cleanRecipe.toJson();
    expect(cleanJson['hasPendingWrites'], isFalse);
    final restoredClean = Recipe.fromJson(cleanJson);
    expect(restoredClean.hasPendingWrites, isFalse);
  });

  test(
    'RemoteSnapshotReconciler.handleRemoteRecipesSnapshot does not overwrite or delete local recipes with hasPendingWrites: true when an older remote snapshot arrives',
    () async {
      final reconciler = RemoteSnapshotReconciler(
        firestore: firestore,
        localDataSource: localDataSource,
        userId: 'user1',
        getFamilyId: () async => 'fam1',
        isFamilyParent: () async => true,
        pushTaskToRemote: (_) async => true,
        pushInstanceToRemote: (_) async => true,
      );

      final localDirtyRecipe = Recipe(
        id: 'R-dirty',
        title: 'Local Offline Edit',
        updatedAt: DateTime.utc(2026, 10, 31, 12, 0),
        hasPendingWrites: true,
      );
      await localDataSource.saveRecipe(localDirtyRecipe);
      await localDataSource.markDirty('R-dirty');

      // Older remote version arrives in snapshot
      final olderRemoteRecipe = Recipe(
        id: 'R-dirty',
        title: 'Stale Remote Version',
        updatedAt: DateTime.utc(2026, 10, 31, 10, 0),
      );
      final col = firestore
          .collection('users')
          .doc('user1')
          .collection('recipes');
      await col.doc('R-dirty').set(olderRemoteRecipe.toFirestore());

      final snapshot = await col.get();
      await reconciler.handleRemoteRecipesSnapshot(snapshot, isFamily: false);

      final stored = localDataSource.getRecipes().singleWhere(
        (r) => r.id == 'R-dirty',
      );
      expect(stored.title, 'Local Offline Edit');
      expect(stored.hasPendingWrites, isTrue);

      // Simulate a removed docChange while local recipe still has pending writes
      final streamQueue = col.snapshots().take(2).toList();
      await col.doc('R-dirty').delete();
      final snapshots = await streamQueue;
      for (final snap in snapshots) {
        await reconciler.handleRemoteRecipesSnapshot(snap, isFamily: false);
      }

      final storedAfterRemove = localDataSource.getRecipes().singleWhere(
        (r) => r.id == 'R-dirty',
      );
      expect(storedAfterRemove.title, 'Local Offline Edit');
      expect(storedAfterRemove.hasPendingWrites, isTrue);
    },
  );

  test(
    'TaskSyncService.sync() pushes dirty local recipes (R-...) to Firestore and clears hasPendingWrites and dirty_tasks',
    () async {
      // Save a recipe while offline (firestore: null)
      final offlineRepo = RecipeRepository(
        localDataSource: localDataSource,
        firestore: null,
        userId: 'user1',
        isActivePremium: true,
        familyId: 'fam1',
      );

      final offlinePersonalRecipe = Recipe(
        id: 'R-offline-1',
        title: 'Offline Risotto',
        isFamily: false,
      );
      final offlineFamilyRecipe = Recipe(
        id: 'R-offline-fam',
        title: 'Offline Family Pizza',
        isFamily: true,
      );
      await offlineRepo.saveRecipe(offlinePersonalRecipe);
      await offlineRepo.saveRecipe(offlineFamilyRecipe);

      expect(
        offlineRepo.getRecipeById('R-offline-1')!.hasPendingWrites,
        isTrue,
      );
      expect(
        offlineRepo.getRecipeById('R-offline-fam')!.hasPendingWrites,
        isTrue,
      );
      expect(
        localDataSource.getDirtyTaskIds(),
        containsAll(['R-offline-1', 'R-offline-fam']),
      );

      await firestore.collection('users').doc('user1').set({
        'familyId': 'fam1',
      });

      final syncService = TaskSyncService(
        firestore: firestore,
        localDataSource: localDataSource,
        userId: 'user1',
        isActivePremium: true,
      );
      addTearDown(syncService.dispose);

      await syncService.sync();

      // Verify pushed to Firestore
      final userDoc = await firestore
          .collection('users')
          .doc('user1')
          .collection('recipes')
          .doc('R-offline-1')
          .get();
      expect(userDoc.exists, isTrue);
      expect(userDoc.data()?['title'], 'Offline Risotto');

      final famDoc = await firestore
          .collection('families')
          .doc('fam1')
          .collection('recipes')
          .doc('R-offline-fam')
          .get();
      expect(famDoc.exists, isTrue);
      expect(famDoc.data()?['title'], 'Offline Family Pizza');

      // Verify hasPendingWrites and dirty_tasks cleared
      expect(
        offlineRepo.getRecipeById('R-offline-1')!.hasPendingWrites,
        isFalse,
      );
      expect(
        offlineRepo.getRecipeById('R-offline-fam')!.hasPendingWrites,
        isFalse,
      );
      expect(localDataSource.getDirtyTaskIds(), isEmpty);

      // Also verify offline delete is synced on reconnect
      await offlineRepo.deleteRecipe('R-offline-1');
      expect(offlineRepo.getRecipeById('R-offline-1'), isNull);
      expect(localDataSource.getDirtyTaskIds(), contains('R-offline-1'));

      await syncService.sync();

      final userDocAfterDelete = await firestore
          .collection('users')
          .doc('user1')
          .collection('recipes')
          .doc('R-offline-1')
          .get();
      expect(userDocAfterDelete.exists, isFalse);
      expect(localDataSource.getDirtyTaskIds(), isEmpty);
    },
  );
}
