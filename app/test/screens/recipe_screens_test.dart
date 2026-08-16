import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/recipes/recipe.dart';
import 'package:nothing_ever_happens/logic/recipes/recipe_repository.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/screens/recipes/recipe_list_screen.dart';
import 'package:nothing_ever_happens/screens/recipes/recipe_editor_screen.dart';
import 'package:nothing_ever_happens/screens/recipes/recipe_detail_screen.dart';
import 'package:nothing_ever_happens/screens/recipes/cooking_mode_screen.dart';
import 'package:nothing_ever_happens/screens/workflows/meal_selection_dialog.dart';
import 'package:nothing_ever_happens/screens/workflows/shopping_checklist_screen.dart';

class _FakeRecipeRepository extends Fake implements RecipeRepository {
  final List<Recipe> _recipes = [];

  _FakeRecipeRepository([List<Recipe>? initial]) {
    if (initial != null) _recipes.addAll(initial);
  }

  @override
  List<Recipe> getRecipes({bool? isFamilyFilter}) =>
      List.unmodifiable(_recipes);

  @override
  Stream<List<Recipe>> watchRecipes({bool? isFamilyFilter}) =>
      Stream.value(_recipes);

  @override
  Recipe? getRecipeById(String id) =>
      _recipes.where((r) => r.id == id).firstOrNull;

  @override
  Future<void> saveRecipe(Recipe recipe) async {
    final idx = _recipes.indexWhere((r) => r.id == recipe.id);
    if (idx >= 0) {
      _recipes[idx] = recipe;
    } else {
      _recipes.add(recipe);
    }
  }

  @override
  Future<void> deleteRecipe(String id) async {
    _recipes.removeWhere((r) => r.id == id);
  }
}

class _FakeTaskRepository extends Fake implements TaskRepository {
  final List<TaskInstance> savedInstances = [];
  final List<String> completedInstanceIds = [];

  @override
  Future<void> saveTaskInstance(TaskInstance instance) async {
    final idx = savedInstances.indexWhere((i) => i.id == instance.id);
    if (idx >= 0) {
      savedInstances[idx] = instance;
    } else {
      savedInstances.add(instance);
    }
  }

  @override
  Future<TaskInstance?> completeTaskInstance(String id) async {
    completedInstanceIds.add(id);
    return null;
  }
}

void main() {
  final sampleRecipe = Recipe(
    id: 'rec-1',
    title: 'Spaghetti Bolognese',
    description: 'Classic rich meat sauce',
    servings: 4,
    ingredients: const [
      RecipeIngredient(id: '1', name: 'Ground Beef', quantity: 500, unit: 'g'),
      RecipeIngredient(
        id: '2',
        name: 'Crushed Tomatoes',
        quantity: 2,
        unit: 'can',
      ),
      RecipeIngredient(id: '3', name: 'Olive Oil', quantity: 2, unit: 'tbsp'),
    ],
    prepSteps: const [
      RecipeStep(
        stepNumber: 1,
        instruction: 'Dice the onions and garlic.',
        estimatedMinutes: 5,
      ),
    ],
    cookSteps: const [
      RecipeStep(
        stepNumber: 1,
        instruction: 'Brown the beef in olive oil.',
        estimatedMinutes: 10,
      ),
      RecipeStep(
        stepNumber: 2,
        instruction: 'Simmer sauce on low heat.',
        estimatedMinutes: 30,
      ),
    ],
  );

  group('Recipe UI Tests', () {
    testWidgets('RecipeListScreen renders recipes and allows searching', (
      tester,
    ) async {
      final fakeRepo = _FakeRecipeRepository([sampleRecipe]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recipeRepositoryProvider.overrideWithValue(fakeRepo),
            recipesStreamProvider.overrideWith(
              (ref) => fakeRepo.watchRecipes(),
            ),
          ],
          child: const MaterialApp(home: RecipeListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Recipe Library'), findsOneWidget);
      expect(find.text('Spaghetti Bolognese'), findsOneWidget);
      expect(find.text('4 servings'), findsOneWidget);

      // Search for non-existent recipe
      await tester.enterText(find.byType(TextField), 'Pancakes');
      await tester.pumpAndSettle();

      expect(find.text('No recipes match your search'), findsOneWidget);
      expect(find.text('Spaghetti Bolognese'), findsNothing);
    });

    testWidgets(
      'RecipeEditorScreen allows adding new recipe with ingredients and steps',
      (tester) async {
        final fakeRepo = _FakeRecipeRepository([]);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [recipeRepositoryProvider.overrideWithValue(fakeRepo)],
            child: const MaterialApp(home: RecipeEditorScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Add Recipe'), findsOneWidget);

        // Fill in title
        await tester.enterText(
          find.byKey(const Key('recipe_title_field')),
          'Tacos',
        );
        await tester.enterText(
          find.byKey(const Key('recipe_description_field')),
          'Quick weeknight tacos',
        );

        // Tap save
        await tester.tap(find.byKey(const Key('save_recipe_button')));
        await tester.pumpAndSettle();

        expect(fakeRepo.getRecipes().length, 1);
        expect(fakeRepo.getRecipes().first.title, 'Tacos');
        expect(
          fakeRepo.getRecipes().first.description,
          'Quick weeknight tacos',
        );
      },
    );

    testWidgets('RecipeDetailScreen scales servings and converts units', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recipeRepositoryProvider.overrideWithValue(
              _FakeRecipeRepository([sampleRecipe]),
            ),
          ],
          child: MaterialApp(home: RecipeDetailScreen(recipe: sampleRecipe)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Spaghetti Bolognese'), findsAtLeastNWidgets(1));

      // Switch to Metric button
      await tester.tap(find.text('Metric'));
      await tester.pumpAndSettle();

      expect(find.text('500 g'), findsOneWidget); // Ground beef at 4 servings

      // Scale to 5 servings (+ button)
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();

      // At 5 servings (4 -> 5)
      expect(find.text('625 g'), findsOneWidget);

      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('start_cooking_button')), findsOneWidget);
    });

    testWidgets(
      'CookingModeScreen progresses through steps and starts countdown timer',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: CookingModeScreen(recipe: sampleRecipe, servings: 4),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Cooking Mode (4 Servings)'), findsOneWidget);
        expect(find.text('Dice the onions and garlic.'), findsOneWidget);
        expect(find.text('Step 1 of 3'), findsOneWidget);

        // Step has 5 min timer -> 05:00
        expect(find.text('05:00'), findsOneWidget);

        // Start timer
        await tester.tap(find.text('Start'));
        await tester.pump(const Duration(seconds: 2));

        expect(find.text('04:58'), findsOneWidget);

        // Next step
        await tester.tap(find.text('Next Step'));
        await tester.pumpAndSettle();

        expect(find.text('Brown the beef in olive oil.'), findsOneWidget);
        expect(find.text('Step 2 of 3'), findsOneWidget);
      },
    );
  });

  group('Meal Workflow UI Tests', () {
    testWidgets(
      'MealSelectionDialog confirms recipe choice and creates shopping/prep tasks',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeRecipeRepo = _FakeRecipeRepository([sampleRecipe]);
        final fakeTaskRepo = _FakeTaskRepository();

        final selectInstance = TaskInstance(
          id: 'dinner_2026-08-16_0',
          scheduleId: 'dinner_schedule',
          ruleId: 'rule-1',
          title: 'Dinner - Select Meal',
          description: 'Select meal',
          scheduledDate: const CivilDay(year: 2026, month: 8, day: 16),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 10, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 10, minute: 0),
          ),
          workflowPayload: const WorkflowInstancePayload(
            workflowType: 'mealWorkflow',
            stage: WorkflowStage.selectMeal,
            workflowGroupId: 'dinner_2026-08-16',
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              recipeRepositoryProvider.overrideWithValue(fakeRecipeRepo),
              recipesStreamProvider.overrideWith(
                (ref) => fakeRecipeRepo.watchRecipes(),
              ),
              taskRepositoryProvider.overrideWithValue(fakeTaskRepo),
            ],
            child: MaterialApp(
              home: MealSelectionDialog(instance: selectInstance),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Plan Today\'s Dinner'), findsOneWidget);
        expect(find.text('Cook a Recipe'), findsOneWidget);

        // Select recipe
        await tester.tap(find.text('Spaghetti Bolognese'));
        await tester.pumpAndSettle();

        // Confirm
        await tester.tap(
          find.byKey(const Key('confirm_meal_selection_button')),
        );
        await tester.pumpAndSettle();

        // Verified Stage 2 and Stage 3 tasks spawned and Stage 1 completed
        expect(fakeTaskRepo.savedInstances.length, 2);
        expect(fakeTaskRepo.completedInstanceIds, contains(selectInstance.id));

        final shopTask = fakeTaskRepo.savedInstances.firstWhere(
          (i) => i.workflowPayload?.stage == WorkflowStage.shoppingList,
        );
        expect(shopTask.title, contains('Shop: Spaghetti Bolognese'));
        expect(shopTask.workflowPayload?.shoppingItems.length, 3);
      },
    );

    testWidgets(
      'ShoppingChecklistScreen supports Pantry Check and Store Checklist',
      (tester) async {
        final fakeTaskRepo = _FakeTaskRepository();

        final shopInstance = TaskInstance(
          id: 'dinner_2026-08-16_shop',
          scheduleId: 'dinner_schedule',
          ruleId: 'rule-1',
          title: 'Shop: Spaghetti Bolognese',
          description: 'Shop items',
          scheduledDate: const CivilDay(year: 2026, month: 8, day: 16),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 16, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 16, minute: 0),
          ),
          workflowPayload: const WorkflowInstancePayload(
            workflowType: 'mealWorkflow',
            stage: WorkflowStage.shoppingList,
            workflowGroupId: 'dinner_2026-08-16',
            recipeTitle: 'Spaghetti Bolognese',
            shoppingItems: [
              ShoppingItemPayload(
                id: '1',
                name: 'Ground Beef',
                quantity: 500,
                unit: 'g',
              ),
              ShoppingItemPayload(
                id: '2',
                name: 'Crushed Tomatoes',
                quantity: 2,
                unit: 'can',
              ),
            ],
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [taskRepositoryProvider.overrideWithValue(fakeTaskRepo)],
            child: MaterialApp(
              home: ShoppingChecklistScreen(instance: shopInstance),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Shopping: Spaghetti Bolognese'), findsOneWidget);
        expect(find.text('1. Pantry Check'), findsOneWidget);
        expect(find.text('Ground Beef'), findsOneWidget);

        // Check off ground beef in pantry check
        await tester.tap(find.text('Ground Beef'));
        await tester.pumpAndSettle();

        // Proceed to store checklist
        await tester.tap(find.text('Proceed to Store Checklist'));
        await tester.pumpAndSettle();

        expect(
          find.text('1 items marked as already in pantry'),
          findsOneWidget,
        );
        expect(find.text('Crushed Tomatoes'), findsOneWidget);

        // Complete shopping task
        await tester.tap(find.byKey(const Key('done_shopping_button')));
        await tester.pumpAndSettle();

        expect(fakeTaskRepo.completedInstanceIds, contains(shopInstance.id));
      },
    );
  });
}
