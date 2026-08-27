import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth_repository.dart';
import '../family_repository.dart';
import '../hive_local_data_source.dart';
import '../subscription_service.dart';
import '../task_repository.dart';
import 'recipe.dart';

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  final localDataSource = ref.watch(hiveLocalDataSourceProvider);
  final user = ref.watch(authStateProvider).value;
  final subState = ref.watch(subscriptionServiceProvider);
  final firestore = ref.watch(firestoreProvider);
  final familyProfile = ref.watch(familyProfileStreamProvider).value;

  return RecipeRepository(
    localDataSource: localDataSource,
    firestore: firestore,
    userId: user?.uid ?? '',
    isActivePremium: subState.isActivePremium,
    familyId: familyProfile?.familyId,
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

  RecipeRepository({
    required HiveLocalDataSource localDataSource,
    FirebaseFirestore? firestore,
    required String userId,
    required bool isActivePremium,
    String? familyId,
  }) : _localDataSource = localDataSource,
       _firestore = firestore,
       _userId = userId,
       _isActivePremium = isActivePremium,
       _familyId = familyId;

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
    if (_userId.isEmpty || _firestore == null) return null;
    try {
      final userDoc = await _firestore.collection('users').doc(_userId).get();
      _familyId = userDoc.data()?['familyId'] as String?;
      return _familyId;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveRecipe(Recipe recipe) async {
    final updatedRecipe = recipe.copyWith(
      updatedAt: DateTime.now(),
      hasPendingWrites: _isActivePremium && _userId.isNotEmpty,
    );
    await _localDataSource.saveRecipe(updatedRecipe);

    if (_isActivePremium && _userId.isNotEmpty && _firestore != null) {
      try {
        final familyId = await _getFamilyId();
        if (updatedRecipe.isFamily && familyId != null && familyId.isNotEmpty) {
          final docRef = _firestore
              .collection('families')
              .doc(familyId)
              .collection('recipes')
              .doc(updatedRecipe.id);
          await docRef.set(
            updatedRecipe.toFirestore(),
            SetOptions(merge: true),
          );

          // Clean up personal copy if it was converted from personal to family
          await _firestore
              .collection('users')
              .doc(_userId)
              .collection('recipes')
              .doc(updatedRecipe.id)
              .delete();
        } else {
          final docRef = _firestore
              .collection('users')
              .doc(_userId)
              .collection('recipes')
              .doc(updatedRecipe.id);
          await docRef.set(
            updatedRecipe.toFirestore(),
            SetOptions(merge: true),
          );

          // Clean up family copy if it was converted from family to personal
          if (familyId != null && familyId.isNotEmpty) {
            await _firestore
                .collection('families')
                .doc(familyId)
                .collection('recipes')
                .doc(updatedRecipe.id)
                .delete();
          }
        }
        await _localDataSource.saveRecipe(
          updatedRecipe.copyWith(hasPendingWrites: false),
        );
      } catch (e) {
        // Offline or firestore error - will remain pending in local cache
      }
    }
  }

  Future<void> deleteRecipe(String id) async {
    final existingRecipe = getRecipeById(id);
    await _localDataSource.deleteRecipe(id);

    if (_isActivePremium && _userId.isNotEmpty && _firestore != null) {
      try {
        final familyId = await _getFamilyId();
        if (existingRecipe?.isFamily == true &&
            familyId != null &&
            familyId.isNotEmpty) {
          final docRef = _firestore
              .collection('families')
              .doc(familyId)
              .collection('recipes')
              .doc(id);
          await docRef.delete();

          await _firestore
              .collection('users')
              .doc(_userId)
              .collection('recipes')
              .doc(id)
              .delete();
        } else {
          final docRef = _firestore
              .collection('users')
              .doc(_userId)
              .collection('recipes')
              .doc(id);
          await docRef.delete();

          if (familyId != null && familyId.isNotEmpty) {
            await _firestore
                .collection('families')
                .doc(familyId)
                .collection('recipes')
                .doc(id)
                .delete();
          }
        }
      } catch (e) {
        // Offline or firestore error
      }
    }
  }
}
