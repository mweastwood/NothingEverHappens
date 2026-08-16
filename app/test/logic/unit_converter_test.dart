import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/recipes/recipe.dart';
import 'package:nothing_ever_happens/logic/recipes/unit_converter.dart';

void main() {
  group('UnitConverter Tests', () {
    test('formatQuantity formats integers and fractions cleanly', () {
      expect(UnitConverter.formatQuantity(2.0), '2');
      expect(UnitConverter.formatQuantity(0.5), '½');
      expect(UnitConverter.formatQuantity(1.5), '1 ½');
      expect(UnitConverter.formatQuantity(0.25), '¼');
      expect(UnitConverter.formatQuantity(0.75), '¾');
      expect(UnitConverter.formatQuantity(0.333), '⅓');
      expect(UnitConverter.formatQuantity(2.25), '2 ¼');
    });

    test(
      'scale properly multiplies ingredient quantities according to servings',
      () {
        const ingredient = RecipeIngredient(
          id: '1',
          name: 'Flour',
          quantity: 2.0,
          unit: 'cups',
        );

        final scaledFor6 = UnitConverter.scale(
          ingredient: ingredient,
          originalServings: 4,
          targetServings: 6,
        );
        expect(scaledFor6.quantity, 3.0);

        final scaledFor2 = UnitConverter.scale(
          ingredient: ingredient,
          originalServings: 4,
          targetServings: 2,
        );
        expect(scaledFor2.quantity, 1.0);
      },
    );

    test('convert converts volume from metric to imperial and vice versa', () {
      // 1 cup to ml
      final metric = UnitConverter.convert(
        quantity: 1.0,
        unit: 'cup',
        targetSystem: UnitSystem.metric,
      );
      expect(metric.unit, 'ml');
      expect((metric.quantity - 236.588).abs() < 0.1, isTrue);

      // 500 ml to cups
      final imperial = UnitConverter.convert(
        quantity: 500.0,
        unit: 'ml',
        targetSystem: UnitSystem.imperial,
      );
      expect(imperial.unit, 'cups');
      expect((imperial.quantity - 2.11).abs() < 0.1, isTrue);
    });

    test('convert converts mass from metric to imperial and vice versa', () {
      // 1 lb to grams
      final metric = UnitConverter.convert(
        quantity: 1.0,
        unit: 'lb',
        targetSystem: UnitSystem.metric,
      );
      expect(metric.unit, 'g');
      expect((metric.quantity - 453.592).abs() < 0.1, isTrue);

      // 1000 g to lbs
      final imperial = UnitConverter.convert(
        quantity: 1000.0,
        unit: 'g',
        targetSystem: UnitSystem.imperial,
      );
      expect(imperial.unit, 'lbs');
      expect((imperial.quantity - 2.20).abs() < 0.1, isTrue);
    });

    test('convert leaves non-convertible units untouched', () {
      final res = UnitConverter.convert(
        quantity: 3.0,
        unit: 'cloves',
        targetSystem: UnitSystem.metric,
      );
      expect(res.quantity, 3.0);
      expect(res.unit, 'cloves');
    });
  });
}
