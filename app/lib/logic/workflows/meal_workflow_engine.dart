import '../civil_day.dart';
import '../task_schedule.dart';
import '../task_instance.dart';
import '../recipes/recipe.dart';
import '../recipes/unit_converter.dart';

class MealWorkflowEngine {
  /// Resolves the Stage 1 task instance for a given schedule and date.
  static TaskInstance createInitialSelectInstance({
    required TaskSchedule schedule,
    required CivilDay scheduledDate,
    String? ruleId,
  }) {
    final config = schedule.mealWorkflowConfig ?? const MealWorkflowConfig();
    final groupId =
        '${schedule.id}-${scheduledDate.year}-${scheduledDate.month}-${scheduledDate.day}';

    return TaskInstance(
      id: TaskInstance.generateId(),
      scheduleId: schedule.id,
      ruleId:
          ruleId ??
          (schedule.schedules.isNotEmpty
              ? schedule.schedules.first.id
              : 'R-initial'),
      title: schedule.title.isNotEmpty ? schedule.title : 'Select Dinner',
      description: 'Choose what to cook or eat for dinner tonight.',
      scheduledDate: scheduledDate,
      startRelativeTime: config.selectTime,
      dueRelativeTime: config.selectTime,
      isFamily: schedule.isFamily,
      familyCompletionMode: schedule.familyCompletionMode,
      priority: schedule.priority,
      cycleId: schedule.cycleId,
      assignedUserId: schedule.assignedUserId,
      workflowPayload: WorkflowInstancePayload(
        workflowType: 'mealWorkflow',
        stage: WorkflowStage.selectMeal,
        workflowGroupId: groupId,
      ),
    );
  }

  /// Processes the completion of Stage 1 (Select Meal) and produces subsequent tasks (Shop, Prep).
  static List<TaskInstance> processMealSelection({
    required TaskSchedule schedule,
    required TaskInstance selectInstance,
    required MealSelectionOption selectedOption,
    Recipe? recipe,
    int? targetServings,
    String? customNote,
  }) {
    final config = schedule.mealWorkflowConfig ?? const MealWorkflowConfig();
    final groupId =
        selectInstance.workflowPayload?.workflowGroupId ??
        '${schedule.id}-${selectInstance.scheduledDate.year}-${selectInstance.scheduledDate.month}-${selectInstance.scheduledDate.day}';

    final resultingInstances = <TaskInstance>[];

    switch (selectedOption) {
      case MealSelectionOption.recipe:
        if (recipe != null) {
          final servings = targetServings ?? recipe.servings;
          // Build shopping items from scaled ingredients
          final shoppingItems = recipe.ingredients.map((ing) {
            final scaled = UnitConverter.scale(
              ingredient: ing,
              originalServings: recipe.servings,
              targetServings: servings,
            );
            return ShoppingItemPayload(
              id: ing.id,
              name: ing.name,
              quantity: scaled.quantity,
              unit: scaled.unit,
              isPantryOwned: false,
              isBought: false,
              isCustom: false,
            );
          }).toList();

          // Stage 2: Shopping List
          final shopInstance = TaskInstance(
            id: TaskInstance.generateId(),
            scheduleId: schedule.id,
            ruleId: selectInstance.ruleId,
            title: 'Shop: ${recipe.title}',
            description:
                'Buy ingredients for ${recipe.title} ($servings servings)',
            scheduledDate: selectInstance.scheduledDate,
            startRelativeTime: config.shopTime,
            dueRelativeTime: config.shopTime,
            isFamily: schedule.isFamily,
            familyCompletionMode: schedule.familyCompletionMode,
            priority: schedule.priority,
            cycleId: schedule.cycleId,
            assignedUserId: schedule.assignedUserId,
            workflowPayload: WorkflowInstancePayload(
              workflowType: 'mealWorkflow',
              stage: WorkflowStage.shoppingList,
              workflowGroupId: groupId,
              selectedOption: MealSelectionOption.recipe,
              recipeId: recipe.id,
              recipeTitle: recipe.title,
              targetServings: servings,
              shoppingItems: shoppingItems,
            ),
          );
          resultingInstances.add(shopInstance);

          // Stage 3: Prep & Cook
          final prepInstance = TaskInstance(
            id: TaskInstance.generateId(),
            scheduleId: schedule.id,
            ruleId: selectInstance.ruleId,
            title: 'Prep & Cook: ${recipe.title}',
            description:
                'Follow recipe instructions to prepare and cook ${recipe.title}',
            scheduledDate: selectInstance.scheduledDate,
            startRelativeTime: config.prepTime,
            dueRelativeTime: config.prepTime,
            isFamily: schedule.isFamily,
            familyCompletionMode: schedule.familyCompletionMode,
            priority: schedule.priority,
            cycleId: schedule.cycleId,
            assignedUserId: schedule.assignedUserId,
            workflowPayload: WorkflowInstancePayload(
              workflowType: 'mealWorkflow',
              stage: WorkflowStage.prepDinner,
              workflowGroupId: groupId,
              selectedOption: MealSelectionOption.recipe,
              recipeId: recipe.id,
              recipeTitle: recipe.title,
              targetServings: servings,
            ),
          );
          resultingInstances.add(prepInstance);
        }
        break;

      case MealSelectionOption.leftovers:
        // Stage 3: Reheat Leftovers (Skip shopping)
        final prepInstance = TaskInstance(
          id: TaskInstance.generateId(),
          scheduleId: schedule.id,
          ruleId: selectInstance.ruleId,
          title: 'Reheat Leftovers',
          description: customNote?.isNotEmpty == true
              ? customNote!
              : 'Reheat and enjoy leftovers for dinner.',
          scheduledDate: selectInstance.scheduledDate,
          startRelativeTime: config.prepTime,
          dueRelativeTime: config.prepTime,
          isFamily: schedule.isFamily,
          familyCompletionMode: schedule.familyCompletionMode,
          priority: schedule.priority,
          cycleId: schedule.cycleId,
          assignedUserId: schedule.assignedUserId,
          workflowPayload: WorkflowInstancePayload(
            workflowType: 'mealWorkflow',
            stage: WorkflowStage.prepDinner,
            workflowGroupId: groupId,
            selectedOption: MealSelectionOption.leftovers,
            customMealNote: customNote,
          ),
        );
        resultingInstances.add(prepInstance);
        break;

      case MealSelectionOption.delivery:
        // Stage 3: Order Delivery (Skip shopping)
        final prepInstance = TaskInstance(
          id: TaskInstance.generateId(),
          scheduleId: schedule.id,
          ruleId: selectInstance.ruleId,
          title: 'Order Delivery',
          description: customNote?.isNotEmpty == true
              ? 'Order dinner delivery ($customNote)'
              : 'Place an order for dinner delivery.',
          scheduledDate: selectInstance.scheduledDate,
          startRelativeTime: config.prepTime,
          dueRelativeTime: config.prepTime,
          isFamily: schedule.isFamily,
          familyCompletionMode: schedule.familyCompletionMode,
          priority: schedule.priority,
          cycleId: schedule.cycleId,
          assignedUserId: schedule.assignedUserId,
          workflowPayload: WorkflowInstancePayload(
            workflowType: 'mealWorkflow',
            stage: WorkflowStage.prepDinner,
            workflowGroupId: groupId,
            selectedOption: MealSelectionOption.delivery,
            customMealNote: customNote,
          ),
        );
        resultingInstances.add(prepInstance);
        break;

      case MealSelectionOption.eatingOut:
        // Eating out: No shopping or prep needed.
        break;
    }

    return resultingInstances;
  }
}
