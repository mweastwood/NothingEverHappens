import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/recipes/recipe.dart';
import 'package:nothing_ever_happens/logic/workflows/meal_workflow_engine.dart';

void main() {
  group('MealWorkflowEngine Tests', () {
    final schedule = TaskSchedule(
      id: 'S-dinner-1',
      title: 'Plan Dinner',
      description: 'Daily dinner workflow',
      workflowType: 'mealWorkflow',
      mealWorkflowConfig: const MealWorkflowConfig(),
    );

    final testDay = CivilDay(year: 2026, month: 8, day: 16);

    test('createInitialSelectInstance sets up Stage 1 task correctly', () {
      final instance = MealWorkflowEngine.createInitialSelectInstance(
        schedule: schedule,
        scheduledDate: testDay,
      );

      expect(instance.scheduleId, schedule.id);
      expect(instance.scheduledDate, testDay);
      expect(instance.workflowPayload?.workflowType, 'mealWorkflow');
      expect(instance.workflowPayload?.stage, WorkflowStage.selectMeal);
    });

    test(
      'processMealSelection for Recipe spawns Stage 2 Shopping and Stage 3 Prep',
      () {
        final selectInstance = MealWorkflowEngine.createInitialSelectInstance(
          schedule: schedule,
          scheduledDate: testDay,
        );

        final recipe = Recipe(
          id: 'R-pasta',
          title: 'Tomato Basil Pasta',
          servings: 4,
          ingredients: [
            const RecipeIngredient(
              id: 'i1',
              name: 'Pasta',
              quantity: 400,
              unit: 'g',
            ),
            const RecipeIngredient(
              id: 'i2',
              name: 'Tomato Sauce',
              quantity: 2,
              unit: 'cups',
            ),
          ],
          prepSteps: [
            const RecipeStep(
              stepNumber: 1,
              instruction: 'Chop basil',
              estimatedMinutes: 5,
            ),
          ],
          cookSteps: [
            const RecipeStep(
              stepNumber: 1,
              instruction: 'Boil pasta',
              estimatedMinutes: 10,
            ),
          ],
        );

        // Scale to 6 servings
        final results = MealWorkflowEngine.processMealSelection(
          schedule: schedule,
          selectInstance: selectInstance,
          selectedOption: MealSelectionOption.recipe,
          recipe: recipe,
          targetServings: 6,
        );

        expect(results.length, 2);

        // Verify Stage 2: Shopping
        final shop = results.firstWhere(
          (i) => i.workflowPayload?.stage == WorkflowStage.shoppingList,
        );
        expect(shop.title, 'Shop: Tomato Basil Pasta');
        expect(shop.workflowPayload?.shoppingItems.length, 2);
        // Scaled 400g * (6/4) = 600g
        expect(shop.workflowPayload?.shoppingItems.first.quantity, 600.0);

        // Verify Stage 3: Prep
        final prep = results.firstWhere(
          (i) => i.workflowPayload?.stage == WorkflowStage.prepDinner,
        );
        expect(prep.title, 'Prep & Cook: Tomato Basil Pasta');
        expect(prep.workflowPayload?.recipeId, 'R-pasta');
      },
    );

    test(
      'processMealSelection for Leftovers spawns Stage 3 Reheat and skips Shopping',
      () {
        final selectInstance = MealWorkflowEngine.createInitialSelectInstance(
          schedule: schedule,
          scheduledDate: testDay,
        );

        final results = MealWorkflowEngine.processMealSelection(
          schedule: schedule,
          selectInstance: selectInstance,
          selectedOption: MealSelectionOption.leftovers,
          customNote: 'Lasagna in fridge',
        );

        expect(results.length, 1);
        final prep = results.first;
        expect(prep.workflowPayload?.stage, WorkflowStage.prepDinner);
        expect(prep.title, 'Reheat Leftovers');
        expect(prep.description, 'Lasagna in fridge');
      },
    );

    test('processMealSelection for EatingOut returns no tasks', () {
      final selectInstance = MealWorkflowEngine.createInitialSelectInstance(
        schedule: schedule,
        scheduledDate: testDay,
      );

      final results = MealWorkflowEngine.processMealSelection(
        schedule: schedule,
        selectInstance: selectInstance,
        selectedOption: MealSelectionOption.eatingOut,
      );

      expect(results.isEmpty, isTrue);
    });
  });
}
