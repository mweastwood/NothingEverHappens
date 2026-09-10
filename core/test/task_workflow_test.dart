import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('TaskWorkflow Tests', () {
    group('MealWorkflowConfig', () {
      test('default values are initialized correctly', () {
        const config = MealWorkflowConfig();

        expect(config.selectTime.dayOffset, equals(0));
        expect(config.selectTime.hour, equals(10));
        expect(config.selectTime.minute, equals(0));

        expect(config.shopTime.dayOffset, equals(0));
        expect(config.shopTime.hour, equals(16));
        expect(config.shopTime.minute, equals(0));

        expect(config.prepTime.dayOffset, equals(0));
        expect(config.prepTime.hour, equals(18));
        expect(config.prepTime.minute, equals(30));
      });

      test('toJson and fromJson round-trip with default values', () {
        const config = MealWorkflowConfig();
        final json = config.toJson();
        final deserialized = MealWorkflowConfig.fromJson(json);

        expect(deserialized.selectTime, equals(config.selectTime));
        expect(deserialized.shopTime, equals(config.shopTime));
        expect(deserialized.prepTime, equals(config.prepTime));
      });

      test(
          'toJson and fromJson round-trip with custom RelativeTime configurations',
          () {
        const config = MealWorkflowConfig(
          selectTime: RelativeTime(dayOffset: -1, hour: 20, minute: 0),
          shopTime: RelativeTime(dayOffset: 0, hour: 12, minute: 15),
          prepTime: RelativeTime(dayOffset: 0, hour: 19, minute: 45),
        );

        final json = config.toJson();
        final deserialized = MealWorkflowConfig.fromJson(json);

        expect(deserialized.selectTime, equals(config.selectTime));
        expect(deserialized.shopTime, equals(config.shopTime));
        expect(deserialized.prepTime, equals(config.prepTime));
      });

      test('copyWith selectively updates timing attributes', () {
        const config = MealWorkflowConfig();
        final updated = config.copyWith(
          prepTime: const RelativeTime(dayOffset: 0, hour: 19, minute: 0),
        );

        expect(updated.selectTime, equals(config.selectTime));
        expect(updated.shopTime, equals(config.shopTime));
        expect(updated.prepTime.hour, equals(19));
        expect(updated.prepTime.minute, equals(0));
      });
    });

    group('ShoppingItemPayload', () {
      test('constructs and serializes to/from JSON correctly', () {
        const item = ShoppingItemPayload(
          id: 'item-123',
          name: 'Tomatoes',
          quantity: 3.5,
          unit: 'kg',
          isPantryOwned: false,
          isBought: true,
          isCustom: true,
        );

        final json = item.toJson();
        expect(json['id'], equals('item-123'));
        expect(json['name'], equals('Tomatoes'));
        expect(json['quantity'], equals(3.5));
        expect(json['unit'], equals('kg'));
        expect(json['isPantryOwned'], isFalse);
        expect(json['isBought'], isTrue);
        expect(json['isCustom'], isTrue);

        final deserialized = ShoppingItemPayload.fromJson(json);
        expect(deserialized.id, equals(item.id));
        expect(deserialized.name, equals(item.name));
        expect(deserialized.quantity, equals(item.quantity));
        expect(deserialized.unit, equals(item.unit));
        expect(deserialized.isPantryOwned, equals(item.isPantryOwned));
        expect(deserialized.isBought, equals(item.isBought));
        expect(deserialized.isCustom, equals(item.isCustom));
      });

      test('copyWith updates specified fields only', () {
        const original = ShoppingItemPayload(
          id: 'i1',
          name: 'Garlic',
          quantity: 1.0,
          unit: 'clove',
        );

        final updated = original.copyWith(quantity: 4.0, isBought: true);
        expect(updated.id, equals('i1'));
        expect(updated.name, equals('Garlic'));
        expect(updated.quantity, equals(4.0));
        expect(updated.isBought, isTrue);
        expect(updated.isPantryOwned, isFalse);
      });
    });

    group('WorkflowInstancePayload', () {
      test('constructs default payload correctly', () {
        const payload = WorkflowInstancePayload(
          workflowType: 'mealWorkflow',
          stage: WorkflowStage.selectMeal,
          workflowGroupId: 'wf-grp-1',
        );

        expect(payload.workflowType, equals('mealWorkflow'));
        expect(payload.stage, equals(WorkflowStage.selectMeal));
        expect(payload.workflowGroupId, equals('wf-grp-1'));
        expect(payload.selectedOption, isNull);
        expect(payload.recipeId, isNull);
        expect(payload.shoppingItems, isEmpty);
      });

      test('toJson and fromJson round-trip with full payload', () {
        const payload = WorkflowInstancePayload(
          workflowType: 'mealWorkflow',
          stage: WorkflowStage.shoppingList,
          workflowGroupId: 'wf-grp-2',
          selectedOption: MealSelectionOption.recipe,
          recipeId: 'rec-1',
          recipeTitle: 'Pasta Carbonara',
          targetServings: 4,
          shoppingItems: [
            ShoppingItemPayload(
              id: 'sp-1',
              name: 'Eggs',
              quantity: 4.0,
              unit: 'pcs',
              isBought: true,
            ),
          ],
          customMealNote: 'Use guanciale if available',
        );

        final json = payload.toJson();
        expect(json['workflowType'], equals('mealWorkflow'));
        expect(json['stage'], equals('shoppingList'));
        expect(json['workflowGroupId'], equals('wf-grp-2'));
        expect(json['selectedOption'], equals('recipe'));
        expect(json['recipeId'], equals('rec-1'));
        expect(json['recipeTitle'], equals('Pasta Carbonara'));
        expect(json['targetServings'], equals(4));
        expect((json['shoppingItems'] as List).length, equals(1));
        expect(json['customMealNote'], equals('Use guanciale if available'));

        final deserialized = WorkflowInstancePayload.fromJson(json);
        expect(deserialized.stage, equals(WorkflowStage.shoppingList));
        expect(deserialized.selectedOption, equals(MealSelectionOption.recipe));
        expect(deserialized.recipeTitle, equals('Pasta Carbonara'));
        expect(deserialized.targetServings, equals(4));
        expect(deserialized.shoppingItems.first.name, equals('Eggs'));
        expect(
            deserialized.customMealNote, equals('Use guanciale if available'));
      });

      test('copyWith updates fields as intended', () {
        const original = WorkflowInstancePayload(
          workflowType: 'mealWorkflow',
          stage: WorkflowStage.selectMeal,
          workflowGroupId: 'grp-1',
        );

        final updated = original.copyWith(
          stage: WorkflowStage.prepDinner,
          selectedOption: MealSelectionOption.delivery,
        );

        expect(updated.stage, equals(WorkflowStage.prepDinner));
        expect(updated.selectedOption, equals(MealSelectionOption.delivery));
        expect(updated.workflowGroupId, equals('grp-1'));
      });
    });
  });
}
