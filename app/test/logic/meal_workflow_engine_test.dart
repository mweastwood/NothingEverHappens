import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
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

    TaskInstance createSelectInstance() {
      final config = schedule.mealWorkflowConfig ?? const MealWorkflowConfig();
      return TaskInstance(
        id: 'I-select-test',
        scheduleId: schedule.id,
        ruleId: 'R-meal-select',
        scheduledDate: testDay,
        title: '${schedule.title} (Select Meal)',
        description: 'Choose what we are having for this meal.',
        startRelativeTime: config.selectTime,
        dueRelativeTime: config.selectTime,
        isFamily: schedule.isFamily,
        priority: schedule.priority,
        workflowPayload: const WorkflowInstancePayload(
          workflowType: 'mealWorkflow',
          stage: WorkflowStage.selectMeal,
          workflowGroupId: 'W-group-1',
        ),
      );
    }

    test(
      'processMealSelection for Recipe spawns Stage 2 Shopping and Stage 3 Prep',
      () {
        final selectInstance = createSelectInstance();

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
        final selectInstance = createSelectInstance();

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
      final selectInstance = createSelectInstance();

      final results = MealWorkflowEngine.processMealSelection(
        schedule: schedule,
        selectInstance: selectInstance,
        selectedOption: MealSelectionOption.eatingOut,
      );

      expect(results.isEmpty, isTrue);
    });
  });
}
