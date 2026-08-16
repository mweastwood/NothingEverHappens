import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth_repository.dart';
import '../hive_local_data_source.dart';
import '../subscription_service.dart';
import '../task_repository.dart';
import 'recipe.dart';

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  final localDataSource = ref.watch(hiveLocalDataSourceProvider);
  final user = ref.watch(authStateProvider).value;
  final subState = ref.watch(subscriptionServiceProvider);
  final firestore = ref.watch(firestoreProvider);

  return RecipeRepository(
    localDataSource: localDataSource,
    firestore: firestore,
    userId: user?.uid ?? '',
    isActivePremium: subState.isActivePremium,
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

  RecipeRepository({
    required HiveLocalDataSource localDataSource,
    FirebaseFirestore? firestore,
    required String userId,
    required bool isActivePremium,
  }) : _localDataSource = localDataSource,
       _firestore = firestore,
       _userId = userId,
       _isActivePremium = isActivePremium;

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

  Future<void> saveRecipe(Recipe recipe) async {
    final updatedRecipe = recipe.copyWith(
      updatedAt: DateTime.now(),
      hasPendingWrites: _isActivePremium && _userId.isNotEmpty,
    );
    await _localDataSource.saveRecipe(updatedRecipe);

    if (_isActivePremium && _userId.isNotEmpty && _firestore != null) {
      try {
        final docRef = _firestore
            .collection('users')
            .doc(_userId)
            .collection('recipes')
            .doc(updatedRecipe.id);
        await docRef.set(updatedRecipe.toFirestore(), SetOptions(merge: true));
        await _localDataSource.saveRecipe(
          updatedRecipe.copyWith(hasPendingWrites: false),
        );
      } catch (e) {
        // Offline or firestore error - will remain pending in local cache
      }
    }
  }

  Future<void> deleteRecipe(String id) async {
    await _localDataSource.deleteRecipe(id);

    if (_isActivePremium && _userId.isNotEmpty && _firestore != null) {
      try {
        final docRef = _firestore
            .collection('users')
            .doc(_userId)
            .collection('recipes')
            .doc(id);
        await docRef.delete();
      } catch (e) {
        // Offline or firestore error
      }
    }
  }
}
