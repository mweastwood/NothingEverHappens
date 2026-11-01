import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth_repository.dart';
import '../family_repository.dart';
import '../firestore_paths.dart';
import '../hive_local_data_source.dart';
import '../subscription_service.dart';
import '../task_repository.dart';
import '../task_sync_service.dart';
import 'recipe.dart';

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  final localDataSource = ref.watch(hiveLocalDataSourceProvider);
  final user = ref.watch(authStateProvider).value;
  final subState = ref.watch(subscriptionServiceProvider);
  final firestore = ref.watch(firestoreProvider);
  final familyProfile = ref.watch(familyProfileStreamProvider).value;
  final syncService = firestore != null
      ? ref.watch(taskSyncServiceProvider)
      : null;

  return RecipeRepository(
    localDataSource: localDataSource,
    firestore: firestore,
    userId: user?.uid ?? '',
    isActivePremium: subState.isActivePremium,
    familyId: familyProfile?.familyId,
    syncService: syncService,
  );
});

final recipesStreamProvider = StreamProvider<List<Recipe>>((ref) {
  final repo = ref.watch(recipeRepositoryProvider);
  return repo.watchRecipes();
});

class RecipeRepository {
  final HiveLocalDataSource _localDataSource;
  final FirebaseFirestore? _firestore;
  final String _userId;
  final bool _isActivePremium;
  String? _familyId;
  final TaskSyncService? _syncService;
  final FamilyIdFetcher _familyIdFetcher;

  RecipeRepository({
    required HiveLocalDataSource localDataSource,
    FirebaseFirestore? firestore,
    required String userId,
    required bool isActivePremium,
    String? familyId,
    TaskSyncService? syncService,
    FamilyIdFetcher? familyIdFetcher,
  }) : _localDataSource = localDataSource,
       _firestore = firestore,
       _userId = userId,
       _isActivePremium = isActivePremium,
       _familyId = familyId,
       _syncService = syncService,
       _familyIdFetcher =
           familyIdFetcher ??
           FamilyIdFetcher(firestore: firestore, userId: userId);

  Stream<List<Recipe>> watchRecipes({bool? isFamilyFilter}) {
    return _localDataSource.watchRecipes().map((recipes) {
      if (isFamilyFilter == null) return recipes;
      return recipes.where((r) => r.isFamily == isFamilyFilter).toList();
    });
  }

  List<Recipe> getRecipes({bool? isFamilyFilter}) {
    final recipes = _localDataSource.getRecipes();
    if (isFamilyFilter == null) return recipes;
    return recipes.where((r) => r.isFamily == isFamilyFilter).toList();
  }

  Recipe? getRecipeById(String id) {
    final recipes = _localDataSource.getRecipes();
    for (final r in recipes) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<String?> _getFamilyId() async {
    if (_familyId != null && _familyId!.isNotEmpty) return _familyId;
    _familyId = await _familyIdFetcher.getFamilyId();
    return _familyId;
  }

  DocumentReference<Map<String, dynamic>> _recipeDocRef(
    FirebaseFirestore firestore,
    String recipeId, {
    required bool isFamily,
    String? familyId,
  }) {
    if (isFamily && familyId != null && familyId.isNotEmpty) {
      return firestore
          .collection(FirestorePaths.families)
          .doc(familyId)
          .collection(FirestorePaths.recipes)
          .doc(recipeId);
    }
    return firestore
        .collection(FirestorePaths.users)
        .doc(_userId)
        .collection(FirestorePaths.recipes)
        .doc(recipeId);
  }

  Future<void> saveRecipe(Recipe recipe) async {
    final updatedRecipe = recipe.copyWith(
      updatedAt: DateTime.now(),
      hasPendingWrites: _isActivePremium && _userId.isNotEmpty,
    );
    await _localDataSource.saveRecipe(updatedRecipe);
    await _localDataSource.markDirty(updatedRecipe.id);

    if (!_isActivePremium || _userId.isEmpty) return;

    if (_syncService != null) {
      await _syncService.sync();
      return;
    }

    final firestore = _firestore;
    if (firestore != null) {
      try {
        final familyId = await _getFamilyId();
        final writeToFamily =
            updatedRecipe.isFamily && familyId != null && familyId.isNotEmpty;
        await _recipeDocRef(
          firestore,
          updatedRecipe.id,
          isFamily: writeToFamily,
          familyId: familyId,
        ).set(updatedRecipe.toFirestore(), SetOptions(merge: true));

        if (writeToFamily) {
          // Clean up personal copy if it was converted from personal to family
          await _recipeDocRef(
            firestore,
            updatedRecipe.id,
            isFamily: false,
          ).delete();
        } else if (familyId != null && familyId.isNotEmpty) {
          // Clean up family copy if it was converted from family to personal
          await _recipeDocRef(
            firestore,
            updatedRecipe.id,
            isFamily: true,
            familyId: familyId,
          ).delete();
        }
        await _localDataSource.clearDirty(updatedRecipe.id);
        await _localDataSource.saveRecipe(
          updatedRecipe.copyWith(hasPendingWrites: false),
        );
      } catch (e) {
        // Offline or firestore error - will remain pending in local cache
      }
    }
  }

  Future<void> deleteRecipe(String id) async {
    await _localDataSource.markDirty(id);
    await _localDataSource.deleteRecipe(id);

    if (!_isActivePremium || _userId.isEmpty) return;

    if (_syncService != null) {
      await _syncService.sync();
      return;
    }

    final firestore = _firestore;
    if (firestore != null) {
      try {
        final familyId = await _getFamilyId();
        await _recipeDocRef(firestore, id, isFamily: false).delete();
        if (familyId != null && familyId.isNotEmpty) {
          await _recipeDocRef(
            firestore,
            id,
            isFamily: true,
            familyId: familyId,
          ).delete();
        }
        await _localDataSource.clearDirty(id);
      } catch (e) {
        // Offline or firestore error
      }
    }
  }
}
