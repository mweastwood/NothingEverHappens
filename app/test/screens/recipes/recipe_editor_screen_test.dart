import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/recipes/recipe.dart';
import 'package:nothing_ever_happens/logic/recipes/recipe_repository.dart';
import 'package:nothing_ever_happens/screens/recipes/recipe_editor_screen.dart';

class _FakeRecipeRepository extends Fake implements RecipeRepository {
  final List<Recipe> _recipes = [];

  @override
  List<Recipe> getRecipes({bool? isFamilyFilter}) =>
      List.unmodifiable(_recipes);

  @override
  Future<void> saveRecipe(Recipe recipe) async {
    final idx = _recipes.indexWhere((r) => r.id == recipe.id);
    if (idx >= 0) {
      _recipes[idx] = recipe;
    } else {
      _recipes.add(recipe);
    }
  }
}

void main() {
  testWidgets(
    'RecipeEditorScreen preserves second ingredient and step after deleting first',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeRepo = _FakeRecipeRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [recipeRepositoryProvider.overrideWithValue(fakeRepo)],
          child: const MaterialApp(home: RecipeEditorScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('recipe_title_field')),
        'Test Recipe',
      );

      // Add a second ingredient and a second prep step
      await tester.tap(find.text('Add Ingredient'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Step').first);
      await tester.pumpAndSettle();

      // Verify unique unit field keys across rows
      expect(find.byKey(const Key('ingredient_unit_field')), findsOneWidget);
      expect(find.byKey(const Key('ingredient_unit_field_1')), findsOneWidget);

      final ingredientNameFields = find.widgetWithText(
        TextFormField,
        'Ingredient Name',
      );
      expect(ingredientNameFields, findsNWidgets(2));
      await tester.enterText(ingredientNameFields.at(0), 'First Ingredient');
      await tester.enterText(ingredientNameFields.at(1), 'Second Ingredient');

      final step1Fields = find.widgetWithText(
        TextFormField,
        'Step 1 Instructions',
      );
      final step2Fields = find.widgetWithText(
        TextFormField,
        'Step 2 Instructions',
      );
      await tester.enterText(step1Fields.first, 'First Step');
      await tester.enterText(step2Fields.first, 'Second Step');
      await tester.pumpAndSettle();

      // Delete first ingredient (first delete icon)
      final deleteButtons = find.byIcon(Icons.delete_outline);
      await tester.tap(deleteButtons.at(0));
      await tester.pumpAndSettle();

      // Delete first prep step (now at index 1 among delete buttons, after 1 remaining ingredient)
      await tester.tap(find.byIcon(Icons.delete_outline).at(1));
      await tester.pumpAndSettle();

      // UI should display the second ingredient and second step, not the deleted first ones
      expect(find.text('First Ingredient'), findsNothing);
      expect(find.text('Second Ingredient'), findsOneWidget);
      expect(find.text('First Step'), findsNothing);
      expect(find.text('Second Step'), findsOneWidget);

      // Save recipe and verify persisted data
      await tester.tap(find.byKey(const Key('save_recipe_button')));
      await tester.pumpAndSettle();

      expect(fakeRepo.getRecipes(), hasLength(1));
      final saved = fakeRepo.getRecipes().single;
      expect(saved.ingredients.map((i) => i.name).toList(), [
        'Second Ingredient',
      ]);
      expect(saved.prepSteps.map((s) => s.instruction).toList(), [
        'Second Step',
      ]);
    },
  );
}
