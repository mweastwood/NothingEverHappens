import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/workflows/task_workflow.dart';

void main() {
  group('MealWorkflowConfig', () {
    test('default values are initialized correctly', () {
      const config = MealWorkflowConfig();

      expect(config.selectTime.dayOffset, 0);
      expect(config.selectTime.time, const TimeOfDay(hour: 10, minute: 0));

      expect(config.shopTime.dayOffset, 0);
      expect(config.shopTime.time, const TimeOfDay(hour: 16, minute: 0));

      expect(config.prepTime.dayOffset, 0);
      expect(config.prepTime.time, const TimeOfDay(hour: 18, minute: 30));
    });

    test('toJson and fromJson round-trip with default values', () {
      const config = MealWorkflowConfig();
      final json = config.toJson();
      final deserialized = MealWorkflowConfig.fromJson(json);

      expect(deserialized.selectTime, config.selectTime);
      expect(deserialized.shopTime, config.shopTime);
      expect(deserialized.prepTime, config.prepTime);
    });

    test(
      'toJson and fromJson round-trip with custom RelativeTime configurations',
      () {
        const config = MealWorkflowConfig(
          selectTime: RelativeTime(
            dayOffset: -1,
            time: TimeOfDay(hour: 20, minute: 0),
          ),
          shopTime: RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 12, minute: 15),
          ),
          prepTime: RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 19, minute: 45),
          ),
        );

        final json = config.toJson();
        final deserialized = MealWorkflowConfig.fromJson(json);

        expect(deserialized.selectTime, config.selectTime);
        expect(deserialized.shopTime, config.shopTime);
        expect(deserialized.prepTime, config.prepTime);
      },
    );

    test(
      'fromJson handles empty / missing / null map values with defaults',
      () {
        final deserialized = MealWorkflowConfig.fromJson(const {});

        expect(
          deserialized.selectTime,
          const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 10, minute: 0),
          ),
        );
        expect(
          deserialized.shopTime,
          const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 16, minute: 0),
          ),
        );
        expect(
          deserialized.prepTime,
          const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 18, minute: 30),
          ),
        );
      },
    );

    test('copyWith selectively updates properties while preserving others', () {
      const original = MealWorkflowConfig();

      final updatedSelect = original.copyWith(
        selectTime: const RelativeTime(
          dayOffset: -1,
          time: TimeOfDay(hour: 8, minute: 0),
        ),
      );
      expect(updatedSelect.selectTime.dayOffset, -1);
      expect(
        updatedSelect.selectTime.time,
        const TimeOfDay(hour: 8, minute: 0),
      );
      expect(updatedSelect.shopTime, original.shopTime);
      expect(updatedSelect.prepTime, original.prepTime);

      final updatedShop = original.copyWith(
        shopTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 14, minute: 30),
        ),
      );
      expect(updatedShop.selectTime, original.selectTime);
      expect(updatedShop.shopTime.dayOffset, 0);
      expect(updatedShop.shopTime.time, const TimeOfDay(hour: 14, minute: 30));
      expect(updatedShop.prepTime, original.prepTime);

      final updatedPrep = original.copyWith(
        prepTime: const RelativeTime(
          dayOffset: 1,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
      );
      expect(updatedPrep.selectTime, original.selectTime);
      expect(updatedPrep.shopTime, original.shopTime);
      expect(updatedPrep.prepTime.dayOffset, 1);
      expect(updatedPrep.prepTime.time, const TimeOfDay(hour: 17, minute: 0));

      final unchanged = original.copyWith();
      expect(unchanged.selectTime, original.selectTime);
      expect(unchanged.shopTime, original.shopTime);
      expect(unchanged.prepTime, original.prepTime);
    });
  });

  group('ShoppingItemPayload', () {
    test('default values are initialized correctly', () {
      const item = ShoppingItemPayload(
        id: 'item-1',
        name: 'Milk',
        quantity: 2.0,
        unit: 'liters',
      );

      expect(item.id, 'item-1');
      expect(item.name, 'Milk');
      expect(item.quantity, 2.0);
      expect(item.unit, 'liters');
      expect(item.isPantryOwned, isFalse);
      expect(item.isBought, isFalse);
      expect(item.isCustom, isFalse);
    });

    test('toJson and fromJson round-trip with all fields populated', () {
      const item = ShoppingItemPayload(
        id: 'item-custom-123',
        name: 'Garlic Cloves',
        quantity: 3.5,
        unit: 'cloves',
        isPantryOwned: true,
        isBought: true,
        isCustom: true,
      );

      final json = item.toJson();
      expect(json, {
        'id': 'item-custom-123',
        'name': 'Garlic Cloves',
        'quantity': 3.5,
        'unit': 'cloves',
        'isPantryOwned': true,
        'isBought': true,
        'isCustom': true,
      });

      final deserialized = ShoppingItemPayload.fromJson(json);
      expect(deserialized.id, item.id);
      expect(deserialized.name, item.name);
      expect(deserialized.quantity, item.quantity);
      expect(deserialized.unit, item.unit);
      expect(deserialized.isPantryOwned, isTrue);
      expect(deserialized.isBought, isTrue);
      expect(deserialized.isCustom, isTrue);
    });

    test(
      'fromJson auto-generates a fallback UUID when id is missing or null',
      () {
        final itemFromNull = ShoppingItemPayload.fromJson(const {
          'name': 'Apples',
          'quantity': 4,
          'unit': 'pcs',
        });

        expect(itemFromNull.id, isNotEmpty);
        expect(itemFromNull.id.length, greaterThanOrEqualTo(32));
        expect(itemFromNull.name, 'Apples');
        expect(itemFromNull.quantity, 4.0);
        expect(itemFromNull.unit, 'pcs');
      },
    );

    test(
      'fromJson parses int and double quantities and defaults to 1.0 when omitted',
      () {
        final itemInt = ShoppingItemPayload.fromJson(const {
          'id': '1',
          'name': 'Eggs',
          'quantity': 6,
          'unit': 'units',
        });
        expect(itemInt.quantity, 6.0);

        final itemDouble = ShoppingItemPayload.fromJson(const {
          'id': '2',
          'name': 'Flour',
          'quantity': 1.75,
          'unit': 'kg',
        });
        expect(itemDouble.quantity, 1.75);

        final itemDefaultQty = ShoppingItemPayload.fromJson(const {
          'id': '3',
          'name': 'Bread',
        });
        expect(itemDefaultQty.quantity, 1.0);
      },
    );

    test(
      'fromJson defaults missing name and unit to empty strings and booleans to false',
      () {
        final item = ShoppingItemPayload.fromJson(const {'id': 'item-empty'});

        expect(item.id, 'item-empty');
        expect(item.name, '');
        expect(item.unit, '');
        expect(item.isPantryOwned, isFalse);
        expect(item.isBought, isFalse);
        expect(item.isCustom, isFalse);
      },
    );

    test('copyWith selectively updates attributes', () {
      const original = ShoppingItemPayload(
        id: 'orig-id',
        name: 'Olive Oil',
        quantity: 1.0,
        unit: 'bottle',
        isPantryOwned: false,
        isBought: false,
        isCustom: false,
      );

      final updated = original.copyWith(
        id: 'new-id',
        name: 'Extra Virgin Olive Oil',
        quantity: 2.5,
        unit: 'bottles',
        isPantryOwned: true,
        isBought: true,
        isCustom: true,
      );

      expect(updated.id, 'new-id');
      expect(updated.name, 'Extra Virgin Olive Oil');
      expect(updated.quantity, 2.5);
      expect(updated.unit, 'bottles');
      expect(updated.isPantryOwned, isTrue);
      expect(updated.isBought, isTrue);
      expect(updated.isCustom, isTrue);

      final unchanged = original.copyWith();
      expect(unchanged.id, original.id);
      expect(unchanged.name, original.name);
      expect(unchanged.quantity, original.quantity);
      expect(unchanged.unit, original.unit);
      expect(unchanged.isPantryOwned, original.isPantryOwned);
      expect(unchanged.isBought, original.isBought);
      expect(unchanged.isCustom, original.isCustom);
    });
  });

  group('WorkflowInstancePayload', () {
    test('default values are initialized correctly', () {
      const payload = WorkflowInstancePayload(
        workflowType: 'mealWorkflow',
        stage: WorkflowStage.selectMeal,
        workflowGroupId: 'grp-123',
      );

      expect(payload.workflowType, 'mealWorkflow');
      expect(payload.stage, WorkflowStage.selectMeal);
      expect(payload.workflowGroupId, 'grp-123');
      expect(payload.selectedOption, isNull);
      expect(payload.recipeId, isNull);
      expect(payload.recipeTitle, isNull);
      expect(payload.targetServings, isNull);
      expect(payload.shoppingItems, isEmpty);
      expect(payload.customMealNote, isNull);
    });

    test('toJson and fromJson round-trip with full payload', () {
      const payload = WorkflowInstancePayload(
        workflowType: 'mealWorkflow',
        stage: WorkflowStage.shoppingList,
        workflowGroupId: 'group-456',
        selectedOption: MealSelectionOption.recipe,
        recipeId: 'rec-pasta-789',
        recipeTitle: 'Spaghetti Bolognese',
        targetServings: 4,
        shoppingItems: [
          ShoppingItemPayload(
            id: 'item-1',
            name: 'Pasta',
            quantity: 500.0,
            unit: 'g',
            isBought: true,
          ),
          ShoppingItemPayload(
            id: 'item-2',
            name: 'Beef Mince',
            quantity: 400.0,
            unit: 'g',
            isPantryOwned: false,
          ),
        ],
        customMealNote: 'Extra parmesan on side',
      );

      final json = payload.toJson();
      expect(json['workflowType'], 'mealWorkflow');
      expect(json['stage'], 'shoppingList');
      expect(json['workflowGroupId'], 'group-456');
      expect(json['selectedOption'], 'recipe');
      expect(json['recipeId'], 'rec-pasta-789');
      expect(json['recipeTitle'], 'Spaghetti Bolognese');
      expect(json['targetServings'], 4);
      expect(json['customMealNote'], 'Extra parmesan on side');
      expect((json['shoppingItems'] as List).length, 2);

      final deserialized = WorkflowInstancePayload.fromJson(json);
      expect(deserialized.workflowType, payload.workflowType);
      expect(deserialized.stage, payload.stage);
      expect(deserialized.workflowGroupId, payload.workflowGroupId);
      expect(deserialized.selectedOption, payload.selectedOption);
      expect(deserialized.recipeId, payload.recipeId);
      expect(deserialized.recipeTitle, payload.recipeTitle);
      expect(deserialized.targetServings, payload.targetServings);
      expect(deserialized.customMealNote, payload.customMealNote);
      expect(deserialized.shoppingItems.length, 2);
      expect(deserialized.shoppingItems[0].id, 'item-1');
      expect(deserialized.shoppingItems[0].name, 'Pasta');
      expect(deserialized.shoppingItems[0].isBought, isTrue);
      expect(deserialized.shoppingItems[1].id, 'item-2');
      expect(deserialized.shoppingItems[1].name, 'Beef Mince');
      expect(deserialized.shoppingItems[1].quantity, 400.0);
    });

    test('toJson omits optional fields when null or empty', () {
      const minimalPayload = WorkflowInstancePayload(
        workflowType: 'mealWorkflow',
        stage: WorkflowStage.selectMeal,
        workflowGroupId: 'group-min',
      );

      final json = minimalPayload.toJson();
      expect(json, {
        'workflowType': 'mealWorkflow',
        'stage': 'selectMeal',
        'workflowGroupId': 'group-min',
      });
      expect(json.containsKey('selectedOption'), isFalse);
      expect(json.containsKey('recipeId'), isFalse);
      expect(json.containsKey('recipeTitle'), isFalse);
      expect(json.containsKey('targetServings'), isFalse);
      expect(json.containsKey('shoppingItems'), isFalse);
      expect(json.containsKey('customMealNote'), isFalse);

      final deserialized = WorkflowInstancePayload.fromJson(json);
      expect(deserialized.workflowType, 'mealWorkflow');
      expect(deserialized.stage, WorkflowStage.selectMeal);
      expect(deserialized.workflowGroupId, 'group-min');
      expect(deserialized.selectedOption, isNull);
      expect(deserialized.recipeId, isNull);
      expect(deserialized.recipeTitle, isNull);
      expect(deserialized.targetServings, isNull);
      expect(deserialized.shoppingItems, isEmpty);
      expect(deserialized.customMealNote, isNull);
    });

    test(
      'fromJson parses all WorkflowStage values and falls back gracefully',
      () {
        for (final stage in WorkflowStage.values) {
          final payload = WorkflowInstancePayload.fromJson({
            'workflowGroupId': 'grp',
            'stage': stage.name,
          });
          expect(payload.stage, stage);
        }

        // Invalid stage fallback
        final invalidStagePayload = WorkflowInstancePayload.fromJson(const {
          'workflowGroupId': 'grp',
          'stage': 'nonExistentStage',
        });
        expect(invalidStagePayload.stage, WorkflowStage.selectMeal);

        // Null stage fallback
        final nullStagePayload = WorkflowInstancePayload.fromJson(const {
          'workflowGroupId': 'grp',
          'stage': null,
        });
        expect(nullStagePayload.stage, WorkflowStage.selectMeal);
      },
    );

    test(
      'fromJson parses all MealSelectionOption values and falls back gracefully',
      () {
        for (final option in MealSelectionOption.values) {
          final payload = WorkflowInstancePayload.fromJson({
            'workflowGroupId': 'grp',
            'selectedOption': option.name,
          });
          expect(payload.selectedOption, option);
        }

        // Invalid option fallback to null
        final invalidOptionPayload = WorkflowInstancePayload.fromJson(const {
          'workflowGroupId': 'grp',
          'selectedOption': 'unknownOption',
        });
        expect(invalidOptionPayload.selectedOption, isNull);

        // Null option fallback
        final nullOptionPayload = WorkflowInstancePayload.fromJson(const {
          'workflowGroupId': 'grp',
          'selectedOption': null,
        });
        expect(nullOptionPayload.selectedOption, isNull);
      },
    );

    test(
      'fromJson handles default fallbacks for workflowType and workflowGroupId',
      () {
        final payload = WorkflowInstancePayload.fromJson(const {});
        expect(payload.workflowType, 'mealWorkflow');
        expect(payload.workflowGroupId, '');
        expect(payload.stage, WorkflowStage.selectMeal);
        expect(payload.shoppingItems, isEmpty);
      },
    );

    test('copyWith creates updated copies and preserves unset fields', () {
      const original = WorkflowInstancePayload(
        workflowType: 'mealWorkflow',
        stage: WorkflowStage.selectMeal,
        workflowGroupId: 'group-1',
        selectedOption: MealSelectionOption.leftovers,
        recipeId: 'rec-1',
        recipeTitle: 'Leftover Chili',
        targetServings: 2,
        shoppingItems: [
          ShoppingItemPayload(
            id: 'item-1',
            name: 'Bread',
            quantity: 1,
            unit: 'loaf',
          ),
        ],
        customMealNote: 'Heat on low',
      );

      final updated = original.copyWith(
        workflowType: 'customWorkflow',
        stage: WorkflowStage.prepDinner,
        workflowGroupId: 'group-2',
        selectedOption: MealSelectionOption.delivery,
        recipeId: 'rec-2',
        recipeTitle: 'Pizza Order',
        targetServings: 6,
        shoppingItems: const [],
        customMealNote: 'Pepperoni please',
      );

      expect(updated.workflowType, 'customWorkflow');
      expect(updated.stage, WorkflowStage.prepDinner);
      expect(updated.workflowGroupId, 'group-2');
      expect(updated.selectedOption, MealSelectionOption.delivery);
      expect(updated.recipeId, 'rec-2');
      expect(updated.recipeTitle, 'Pizza Order');
      expect(updated.targetServings, 6);
      expect(updated.shoppingItems, isEmpty);
      expect(updated.customMealNote, 'Pepperoni please');

      final unchanged = original.copyWith();
      expect(unchanged.workflowType, original.workflowType);
      expect(unchanged.stage, original.stage);
      expect(unchanged.workflowGroupId, original.workflowGroupId);
      expect(unchanged.selectedOption, original.selectedOption);
      expect(unchanged.recipeId, original.recipeId);
      expect(unchanged.recipeTitle, original.recipeTitle);
      expect(unchanged.targetServings, original.targetServings);
      expect(unchanged.shoppingItems.length, original.shoppingItems.length);
      expect(unchanged.customMealNote, original.customMealNote);
    });
  });
}
