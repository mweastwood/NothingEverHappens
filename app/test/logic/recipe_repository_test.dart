import 'dart:io';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nothing_ever_happens/logic/hive_local_data_source.dart';
import 'package:nothing_ever_happens/logic/recipes/recipe.dart';
import 'package:nothing_ever_happens/logic/recipes/recipe_repository.dart';

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
}
