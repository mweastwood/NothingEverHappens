import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/recipes/recipe.dart';

void main() {
  group('RecipeIngredient', () {
    test('constructs instance with all properties', () {
      const ingredient = RecipeIngredient(
        id: 'ing-1',
        name: 'Flour',
        quantity: 2.5,
        unit: 'cups',
        notes: 'Sifted',
      );

      expect(ingredient.id, 'ing-1');
      expect(ingredient.name, 'Flour');
      expect(ingredient.quantity, 2.5);
      expect(ingredient.unit, 'cups');
      expect(ingredient.notes, 'Sifted');
    });

    test('constructs instance with null notes', () {
      const ingredient = RecipeIngredient(
        id: 'ing-2',
        name: 'Sugar',
        quantity: 1.0,
        unit: 'tbsp',
      );

      expect(ingredient.notes, isNull);
    });

    test('toJson includes notes when present', () {
      const ingredient = RecipeIngredient(
        id: 'ing-1',
        name: 'Flour',
        quantity: 2.5,
        unit: 'cups',
        notes: 'Organic',
      );

      final json = ingredient.toJson();
      expect(json, {
        'id': 'ing-1',
        'name': 'Flour',
        'quantity': 2.5,
        'unit': 'cups',
        'notes': 'Organic',
      });
    });

    test('toJson omits notes when null', () {
      const ingredient = RecipeIngredient(
        id: 'ing-2',
        name: 'Sugar',
        quantity: 1.0,
        unit: 'tbsp',
      );

      final json = ingredient.toJson();
      expect(json, {
        'id': 'ing-2',
        'name': 'Sugar',
        'quantity': 1.0,
        'unit': 'tbsp',
      });
      expect(json.containsKey('notes'), isFalse);
    });

    test('fromJson parses complete payload', () {
      final json = {
        'id': 'ing-3',
        'name': 'Salt',
        'quantity': 0.5,
        'unit': 'tsp',
        'notes': 'Sea salt',
      };

      final ingredient = RecipeIngredient.fromJson(json);
      expect(ingredient.id, 'ing-3');
      expect(ingredient.name, 'Salt');
      expect(ingredient.quantity, 0.5);
      expect(ingredient.unit, 'tsp');
      expect(ingredient.notes, 'Sea salt');
    });

    test('fromJson handles int quantity conversion to double', () {
      final json = {
        'id': 'ing-4',
        'name': 'Eggs',
        'quantity': 2,
        'unit': 'pcs',
      };

      final ingredient = RecipeIngredient.fromJson(json);
      expect(ingredient.quantity, 2.0);
    });

    test('fromJson applies fallback defaults when fields are missing', () {
      final ingredient = RecipeIngredient.fromJson({});

      expect(ingredient.id, isNotEmpty);
      expect(ingredient.name, '');
      expect(ingredient.quantity, 0.0);
      expect(ingredient.unit, '');
      expect(ingredient.notes, isNull);
    });

    test(
      'copyWith mutates specified fields and preserves unmutated fields',
      () {
        const original = RecipeIngredient(
          id: 'ing-1',
          name: 'Flour',
          quantity: 2.0,
          unit: 'cups',
          notes: 'White',
        );

        final copied = original.copyWith(
          name: 'Whole Wheat Flour',
          quantity: 3.0,
        );

        expect(copied.id, 'ing-1');
        expect(copied.name, 'Whole Wheat Flour');
        expect(copied.quantity, 3.0);
        expect(copied.unit, 'cups');
        expect(copied.notes, 'White');

        final copyAll = original.copyWith(
          id: 'ing-new',
          name: 'Almond Flour',
          quantity: 1.5,
          unit: 'grams',
          notes: 'Finely ground',
        );
        expect(copyAll.id, 'ing-new');
        expect(copyAll.name, 'Almond Flour');
        expect(copyAll.quantity, 1.5);
        expect(copyAll.unit, 'grams');
        expect(copyAll.notes, 'Finely ground');

        final unchanged = original.copyWith();
        expect(unchanged.id, original.id);
        expect(unchanged.name, original.name);
        expect(unchanged.quantity, original.quantity);
        expect(unchanged.unit, original.unit);
        expect(unchanged.notes, original.notes);
      },
    );
  });

  group('RecipeStep', () {
    test('constructs instance with default optional fields', () {
      const step = RecipeStep(
        stepNumber: 1,
        instruction: 'Preheat oven to 350F',
      );

      expect(step.stepNumber, 1);
      expect(step.instruction, 'Preheat oven to 350F');
      expect(step.estimatedMinutes, 0);
      expect(step.timerDurationSeconds, 0);
    });

    test('constructs instance with explicit parameters', () {
      const step = RecipeStep(
        stepNumber: 2,
        instruction: 'Bake cookies',
        estimatedMinutes: 15,
        timerDurationSeconds: 900,
      );

      expect(step.stepNumber, 2);
      expect(step.instruction, 'Bake cookies');
      expect(step.estimatedMinutes, 15);
      expect(step.timerDurationSeconds, 900);
    });

    test('toJson serializes all fields correctly', () {
      const step = RecipeStep(
        stepNumber: 3,
        instruction: 'Let cool on rack',
        estimatedMinutes: 10,
        timerDurationSeconds: 600,
      );

      final json = step.toJson();
      expect(json, {
        'stepNumber': 3,
        'instruction': 'Let cool on rack',
        'estimatedMinutes': 10,
        'timerDurationSeconds': 600,
      });
    });

    test('fromJson parses complete payload', () {
      final json = {
        'stepNumber': 2,
        'instruction': 'Mix dry ingredients',
        'estimatedMinutes': 5,
        'timerDurationSeconds': 300,
      };

      final step = RecipeStep.fromJson(json);
      expect(step.stepNumber, 2);
      expect(step.instruction, 'Mix dry ingredients');
      expect(step.estimatedMinutes, 5);
      expect(step.timerDurationSeconds, 300);
    });

    test('fromJson falls back to defaults when fields are missing', () {
      final step = RecipeStep.fromJson({});
      expect(step.stepNumber, 1);
      expect(step.instruction, '');
      expect(step.estimatedMinutes, 0);
      expect(step.timerDurationSeconds, 0);
    });

    test(
      'copyWith mutates specified fields and preserves unmodified fields',
      () {
        const step = RecipeStep(
          stepNumber: 1,
          instruction: 'Chop onions',
          estimatedMinutes: 5,
          timerDurationSeconds: 0,
        );

        final updated = step.copyWith(
          instruction: 'Dice onions finely',
          timerDurationSeconds: 120,
        );

        expect(updated.stepNumber, 1);
        expect(updated.instruction, 'Dice onions finely');
        expect(updated.estimatedMinutes, 5);
        expect(updated.timerDurationSeconds, 120);

        final updatedAll = step.copyWith(
          stepNumber: 2,
          instruction: 'Saute onions',
          estimatedMinutes: 8,
          timerDurationSeconds: 480,
        );
        expect(updatedAll.stepNumber, 2);
        expect(updatedAll.instruction, 'Saute onions');
        expect(updatedAll.estimatedMinutes, 8);
        expect(updatedAll.timerDurationSeconds, 480);

        final unchanged = step.copyWith();
        expect(unchanged.stepNumber, step.stepNumber);
        expect(unchanged.instruction, step.instruction);
        expect(unchanged.estimatedMinutes, step.estimatedMinutes);
        expect(unchanged.timerDurationSeconds, step.timerDurationSeconds);
      },
    );
  });

  group('Recipe', () {
    test('generateId creates valid ID starting with R- prefix', () {
      final id = Recipe.generateId();
      expect(id.startsWith('R-'), isTrue);
      // Valid UUID format has 36 characters, so with 'R-' it should be 38 chars
      expect(id.length, 38);
      final uuidPart = id.substring(2);
      final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );
      expect(uuidRegex.hasMatch(uuidPart), isTrue);
    });

    test('constructor applies correct default values', () {
      final recipe = Recipe(title: 'Pancakes');

      expect(recipe.id.startsWith('R-'), isTrue);
      expect(recipe.title, 'Pancakes');
      expect(recipe.description, '');
      expect(recipe.servings, 4);
      expect(recipe.ingredients, isEmpty);
      expect(recipe.prepSteps, isEmpty);
      expect(recipe.cookSteps, isEmpty);
      expect(recipe.isFamily, isFalse);
      expect(recipe.hasPendingWrites, isFalse);
      expect(recipe.isFromCache, isFalse);
      expect(recipe.createdAt, isNotNull);
      expect(recipe.updatedAt, isNotNull);
    });

    test('constructor accepts all explicit values', () {
      final created = DateTime(2026, 1, 1, 10, 0);
      final updated = DateTime(2026, 1, 2, 12, 0);
      const ingredient = RecipeIngredient(
        id: 'i1',
        name: 'Milk',
        quantity: 1,
        unit: 'cup',
      );
      const prep = RecipeStep(
        stepNumber: 1,
        instruction: 'Measure milk',
        estimatedMinutes: 2,
      );
      const cook = RecipeStep(
        stepNumber: 2,
        instruction: 'Simmer',
        estimatedMinutes: 10,
      );

      final recipe = Recipe(
        id: 'R-custom',
        title: 'Hot Chocolate',
        description: 'Cozy winter drink',
        servings: 2,
        ingredients: [ingredient],
        prepSteps: [prep],
        cookSteps: [cook],
        isFamily: true,
        createdAt: created,
        updatedAt: updated,
        hasPendingWrites: true,
        isFromCache: true,
      );

      expect(recipe.id, 'R-custom');
      expect(recipe.title, 'Hot Chocolate');
      expect(recipe.description, 'Cozy winter drink');
      expect(recipe.servings, 2);
      expect(recipe.ingredients.length, 1);
      expect(recipe.prepSteps.length, 1);
      expect(recipe.cookSteps.length, 1);
      expect(recipe.isFamily, isTrue);
      expect(recipe.createdAt, created);
      expect(recipe.updatedAt, updated);
      expect(recipe.hasPendingWrites, isTrue);
      expect(recipe.isFromCache, isTrue);
    });

    test(
      'duration computations sum prep, cook, and total minutes correctly',
      () {
        final recipe = Recipe(
          title: 'Roasted Chicken',
          prepSteps: const [
            RecipeStep(
              stepNumber: 1,
              instruction: 'Season chicken',
              estimatedMinutes: 15,
            ),
            RecipeStep(
              stepNumber: 2,
              instruction: 'Chop vegetables',
              estimatedMinutes: 10,
            ),
          ],
          cookSteps: const [
            RecipeStep(
              stepNumber: 3,
              instruction: 'Roast in oven',
              estimatedMinutes: 60,
            ),
            RecipeStep(
              stepNumber: 4,
              instruction: 'Rest meat',
              estimatedMinutes: 10,
            ),
          ],
        );

        expect(recipe.totalPrepMinutes, 25);
        expect(recipe.totalCookMinutes, 70);
        expect(recipe.totalMinutes, 95);
      },
    );

    test('duration computations return 0 when step lists are empty', () {
      final recipe = Recipe(title: 'Simple Toast');

      expect(recipe.totalPrepMinutes, 0);
      expect(recipe.totalCookMinutes, 0);
      expect(recipe.totalMinutes, 0);
    });

    test('copyWith updates individual and multiple properties correctly', () {
      final initialCreated = DateTime(2026, 1, 1);
      final initialUpdated = DateTime(2026, 1, 2);
      final original = Recipe(
        id: 'R-orig',
        title: 'Original Recipe',
        description: 'Original Description',
        servings: 4,
        ingredients: const [
          RecipeIngredient(id: 'i1', name: 'Item', quantity: 1, unit: 'pcs'),
        ],
        prepSteps: const [
          RecipeStep(stepNumber: 1, instruction: 'Prep', estimatedMinutes: 5),
        ],
        cookSteps: const [
          RecipeStep(stepNumber: 2, instruction: 'Cook', estimatedMinutes: 15),
        ],
        isFamily: false,
        createdAt: initialCreated,
        updatedAt: initialUpdated,
        hasPendingWrites: false,
        isFromCache: false,
      );

      final newCreated = DateTime(2026, 2, 1);
      final newUpdated = DateTime(2026, 2, 2);
      final newIngredients = [
        const RecipeIngredient(
          id: 'i2',
          name: 'New Item',
          quantity: 2,
          unit: 'kg',
        ),
      ];
      final newPrep = [
        const RecipeStep(
          stepNumber: 1,
          instruction: 'New Prep',
          estimatedMinutes: 8,
        ),
      ];
      final newCook = [
        const RecipeStep(
          stepNumber: 2,
          instruction: 'New Cook',
          estimatedMinutes: 20,
        ),
      ];

      final fullyUpdated = original.copyWith(
        id: 'R-new',
        title: 'Updated Recipe',
        description: 'Updated Description',
        servings: 6,
        ingredients: newIngredients,
        prepSteps: newPrep,
        cookSteps: newCook,
        isFamily: true,
        createdAt: newCreated,
        updatedAt: newUpdated,
        hasPendingWrites: true,
        isFromCache: true,
      );

      expect(fullyUpdated.id, 'R-new');
      expect(fullyUpdated.title, 'Updated Recipe');
      expect(fullyUpdated.description, 'Updated Description');
      expect(fullyUpdated.servings, 6);
      expect(fullyUpdated.ingredients, newIngredients);
      expect(fullyUpdated.prepSteps, newPrep);
      expect(fullyUpdated.cookSteps, newCook);
      expect(fullyUpdated.isFamily, isTrue);
      expect(fullyUpdated.createdAt, newCreated);
      expect(fullyUpdated.updatedAt, newUpdated);
      expect(fullyUpdated.hasPendingWrites, isTrue);
      expect(fullyUpdated.isFromCache, isTrue);

      final partiallyUpdated = original.copyWith(servings: 10);
      expect(partiallyUpdated.id, original.id);
      expect(partiallyUpdated.title, original.title);
      expect(partiallyUpdated.description, original.description);
      expect(partiallyUpdated.servings, 10);
      expect(partiallyUpdated.ingredients, original.ingredients);
      expect(partiallyUpdated.prepSteps, original.prepSteps);
      expect(partiallyUpdated.cookSteps, original.cookSteps);
      expect(partiallyUpdated.isFamily, original.isFamily);
      expect(partiallyUpdated.createdAt, original.createdAt);
      expect(partiallyUpdated.updatedAt, original.updatedAt);
      expect(partiallyUpdated.hasPendingWrites, original.hasPendingWrites);
      expect(partiallyUpdated.isFromCache, original.isFromCache);

      final unchanged = original.copyWith();
      expect(unchanged.id, original.id);
      expect(unchanged.title, original.title);
      expect(unchanged.description, original.description);
      expect(unchanged.servings, original.servings);
      expect(unchanged.ingredients, original.ingredients);
      expect(unchanged.prepSteps, original.prepSteps);
      expect(unchanged.cookSteps, original.cookSteps);
      expect(unchanged.isFamily, original.isFamily);
      expect(unchanged.createdAt, original.createdAt);
      expect(unchanged.updatedAt, original.updatedAt);
      expect(unchanged.hasPendingWrites, original.hasPendingWrites);
      expect(unchanged.isFromCache, original.isFromCache);
    });

    test('toJson and fromJson perform complete round-trip', () {
      final recipe = Recipe(
        id: 'R-trip',
        title: 'Lasagna',
        description: 'Classic beef lasagna',
        servings: 8,
        ingredients: const [
          RecipeIngredient(
            id: 'i-beef',
            name: 'Ground Beef',
            quantity: 500,
            unit: 'grams',
            notes: 'Lean',
          ),
        ],
        prepSteps: const [
          RecipeStep(
            stepNumber: 1,
            instruction: 'Brown the beef',
            estimatedMinutes: 10,
            timerDurationSeconds: 600,
          ),
        ],
        cookSteps: const [
          RecipeStep(
            stepNumber: 2,
            instruction: 'Bake in oven',
            estimatedMinutes: 45,
            timerDurationSeconds: 2700,
          ),
        ],
        isFamily: true,
        createdAt: DateTime.parse('2026-03-01T12:00:00.000Z'),
        updatedAt: DateTime.parse('2026-03-01T14:30:00.000Z'),
      );

      final json = recipe.toJson();
      expect(json['id'], 'R-trip');
      expect(json['title'], 'Lasagna');
      expect(json['description'], 'Classic beef lasagna');
      expect(json['servings'], 8);
      expect(json['isFamily'], isTrue);
      expect(json['createdAt'], '2026-03-01T12:00:00.000Z');
      expect(json['updatedAt'], '2026-03-01T14:30:00.000Z');

      final deserialized = Recipe.fromJson(json);
      expect(deserialized.id, recipe.id);
      expect(deserialized.title, recipe.title);
      expect(deserialized.description, recipe.description);
      expect(deserialized.servings, recipe.servings);
      expect(deserialized.isFamily, recipe.isFamily);
      expect(deserialized.ingredients.length, 1);
      expect(deserialized.ingredients.first.name, 'Ground Beef');
      expect(deserialized.prepSteps.length, 1);
      expect(deserialized.prepSteps.first.instruction, 'Brown the beef');
      expect(deserialized.cookSteps.length, 1);
      expect(deserialized.cookSteps.first.instruction, 'Bake in oven');
      expect(deserialized.createdAt, recipe.createdAt);
      expect(deserialized.updatedAt, recipe.updatedAt);
    });

    test('fromJson handles diverse parseDate variations and fallbacks', () {
      final now = DateTime.now();
      final timestamp = Timestamp.fromDate(DateTime(2026, 5, 10, 15, 30));
      final dateTime = DateTime(2026, 6, 12, 8, 45);

      final jsonFromString = {
        'title': 'Test 1',
        'createdAt': '2026-04-01T08:00:00.000Z',
        'updatedAt': 'invalid-date-string',
      };
      final recipeFromString = Recipe.fromJson(jsonFromString);
      expect(
        recipeFromString.createdAt,
        DateTime.parse('2026-04-01T08:00:00.000Z'),
      );
      expect(
        recipeFromString.updatedAt.isAfter(
          now.subtract(const Duration(seconds: 5)),
        ),
        isTrue,
      );

      final jsonFromTimestamp = {
        'title': 'Test 2',
        'createdAt': timestamp,
        'updatedAt': dateTime,
      };
      final recipeFromTimestamp = Recipe.fromJson(jsonFromTimestamp);
      expect(recipeFromTimestamp.createdAt, timestamp.toDate());
      expect(recipeFromTimestamp.updatedAt, dateTime);

      final jsonFromUnsupported = {
        'title': 'Test 3',
        'createdAt': 12345678,
        'updatedAt': null,
      };
      final recipeFromUnsupported = Recipe.fromJson(jsonFromUnsupported);
      expect(
        recipeFromUnsupported.createdAt.isAfter(
          now.subtract(const Duration(seconds: 5)),
        ),
        isTrue,
      );
      expect(
        recipeFromUnsupported.updatedAt.isAfter(
          now.subtract(const Duration(seconds: 5)),
        ),
        isTrue,
      );
    });

    test('fromJson applies fallback defaults when json payload is empty', () {
      final recipe = Recipe.fromJson({});

      expect(recipe.id.startsWith('R-'), isTrue);
      expect(recipe.title, '');
      expect(recipe.description, '');
      expect(recipe.servings, 4);
      expect(recipe.ingredients, isEmpty);
      expect(recipe.prepSteps, isEmpty);
      expect(recipe.cookSteps, isEmpty);
      expect(recipe.isFamily, isFalse);
    });

    test(
      'toFirestore serializes dates to Timestamp and ingredients/steps to json',
      () {
        final created = DateTime(2026, 7, 1, 10, 0);
        final updated = DateTime(2026, 7, 1, 11, 0);
        final recipe = Recipe(
          id: 'R-fs-1',
          title: 'Tacos',
          description: 'Tuesday tacos',
          servings: 3,
          ingredients: const [
            RecipeIngredient(
              id: 'i1',
              name: 'Tortillas',
              quantity: 6,
              unit: 'pcs',
            ),
          ],
          prepSteps: const [
            RecipeStep(
              stepNumber: 1,
              instruction: 'Warm tortillas',
              estimatedMinutes: 2,
            ),
          ],
          cookSteps: const [
            RecipeStep(
              stepNumber: 2,
              instruction: 'Assemble tacos',
              estimatedMinutes: 5,
            ),
          ],
          isFamily: true,
          createdAt: created,
          updatedAt: updated,
        );

        final data = recipe.toFirestore();
        expect(data['title'], 'Tacos');
        expect(data['description'], 'Tuesday tacos');
        expect(data['servings'], 3);
        expect(data['isFamily'], isTrue);
        expect(data['createdAt'], Timestamp.fromDate(created));
        expect(data['updatedAt'], Timestamp.fromDate(updated));
        expect(data['ingredients'], isA<List>());
        expect(data['prepSteps'], isA<List>());
        expect(data['cookSteps'], isA<List>());
        // Document id should not be present in payload map
        expect(data.containsKey('id'), isFalse);
      },
    );

    test(
      'fromFirestore deserializes Firestore DocumentSnapshot accurately',
      () async {
        final firestore = FakeFirebaseFirestore();
        final created = DateTime(2026, 8, 1, 9, 0);
        final updated = DateTime(2026, 8, 1, 9, 30);

        final docRef = firestore.collection('recipes').doc('R-fs-doc');
        await docRef.set({
          'title': 'Salad',
          'description': 'Fresh garden salad',
          'servings': 2,
          'ingredients': [
            {
              'id': 'i-lettuce',
              'name': 'Lettuce',
              'quantity': 1,
              'unit': 'head',
            },
          ],
          'prepSteps': [
            {
              'stepNumber': 1,
              'instruction': 'Chop lettuce',
              'estimatedMinutes': 3,
            },
          ],
          'cookSteps': [
            {
              'stepNumber': 2,
              'instruction': 'Toss salad',
              'estimatedMinutes': 2,
            },
          ],
          'isFamily': false,
          'createdAt': Timestamp.fromDate(created),
          'updatedAt': Timestamp.fromDate(updated),
        });

        final snapshot = await docRef.get();
        final recipe = Recipe.fromFirestore(snapshot);

        expect(recipe.id, 'R-fs-doc');
        expect(recipe.title, 'Salad');
        expect(recipe.description, 'Fresh garden salad');
        expect(recipe.servings, 2);
        expect(recipe.ingredients.length, 1);
        expect(recipe.ingredients.first.name, 'Lettuce');
        expect(recipe.prepSteps.length, 1);
        expect(recipe.prepSteps.first.instruction, 'Chop lettuce');
        expect(recipe.cookSteps.length, 1);
        expect(recipe.cookSteps.first.instruction, 'Toss salad');
        expect(recipe.isFamily, isFalse);
        expect(recipe.createdAt, created);
        expect(recipe.updatedAt, updated);
        expect(recipe.hasPendingWrites, snapshot.metadata.hasPendingWrites);
        expect(recipe.isFromCache, snapshot.metadata.isFromCache);
      },
    );

    test(
      'fromFirestore handles String, DateTime, and fallback dates in Firestore data',
      () async {
        final firestore = FakeFirebaseFirestore();
        final docRef = firestore.collection('recipes').doc('R-dates');
        await docRef.set({
          'title': 'Date Test Recipe',
          'createdAt': '2026-08-15T12:00:00.000Z',
          'updatedAt': DateTime(2026, 8, 16, 14, 0),
        });

        final snapshot = await docRef.get();
        final recipe = Recipe.fromFirestore(snapshot);

        expect(recipe.createdAt, DateTime.parse('2026-08-15T12:00:00.000Z'));
        expect(recipe.updatedAt, DateTime(2026, 8, 16, 14, 0));

        final docRef2 = firestore.collection('recipes').doc('R-dates-fallback');
        await docRef2.set({
          'title': 'Fallback Dates',
          'createdAt': 'invalid-date',
          'updatedAt': 987654,
        });

        final snapshot2 = await docRef2.get();
        final now = DateTime.now();
        final recipe2 = Recipe.fromFirestore(snapshot2);
        expect(
          recipe2.createdAt.isAfter(now.subtract(const Duration(seconds: 5))),
          isTrue,
        );
        expect(
          recipe2.updatedAt.isAfter(now.subtract(const Duration(seconds: 5))),
          isTrue,
        );
      },
    );

    test(
      'fromFirestore applies defaults when optional fields are omitted in Firestore doc',
      () async {
        final firestore = FakeFirebaseFirestore();
        final docRef = firestore.collection('recipes').doc('R-minimal');
        await docRef.set({});

        final snapshot = await docRef.get();
        final recipe = Recipe.fromFirestore(snapshot);

        expect(recipe.id, 'R-minimal');
        expect(recipe.title, '');
        expect(recipe.description, '');
        expect(recipe.servings, 4);
        expect(recipe.ingredients, isEmpty);
        expect(recipe.prepSteps, isEmpty);
        expect(recipe.cookSteps, isEmpty);
        expect(recipe.isFamily, isFalse);
      },
    );

    test('fromFirestore throws Exception when snapshot data is null', () async {
      final firestore = FakeFirebaseFirestore();
      final nonExistentSnapshot = await firestore
          .collection('recipes')
          .doc('R-non-existent')
          .get();

      expect(
        () => Recipe.fromFirestore(nonExistentSnapshot),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Recipe data is null for document R-non-existent'),
          ),
        ),
      );
    });
  });
}
