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

    test('convert leaves non-convertible units untouched but pluralizes properly', () {
      final res3 = UnitConverter.convert(
        quantity: 3.0,
        unit: 'clove',
        targetSystem: UnitSystem.metric,
      );
      expect(res3.quantity, 3.0);
      expect(res3.unit, 'cloves');

      final res1 = UnitConverter.convert(
        quantity: 1.0,
        unit: 'cloves',
        targetSystem: UnitSystem.metric,
      );
      expect(res1.quantity, 1.0);
      expect(res1.unit, 'clove');
    });

    test('formatUnit handles singular vs plural for standard countable units', () {
      // cup / cups
      expect(UnitConverter.formatUnit('cup', 1.0), 'cup');
      expect(UnitConverter.formatUnit('cups', 1.0), 'cup');
      expect(UnitConverter.formatUnit('cup', 2.0), 'cups');
      expect(UnitConverter.formatUnit('cups', 2.0), 'cups');
      expect(UnitConverter.formatUnit('cup', 0.5), 'cups');
      expect(UnitConverter.formatUnit('cup', 0.0), 'cups');

      // clove / cloves
      expect(UnitConverter.formatUnit('clove', 1.0), 'clove');
      expect(UnitConverter.formatUnit('cloves', 1.0), 'clove');
      expect(UnitConverter.formatUnit('clove', 3.0), 'cloves');
      expect(UnitConverter.formatUnit('cloves', 3.0), 'cloves');

      // piece / pieces
      expect(UnitConverter.formatUnit('piece', 1.0), 'piece');
      expect(UnitConverter.formatUnit('pieces', 1.0), 'piece');
      expect(UnitConverter.formatUnit('piece', 4.0), 'pieces');
      expect(UnitConverter.formatUnit('pieces', 4.0), 'pieces');

      // pinch / pinches
      expect(UnitConverter.formatUnit('pinch', 1.0), 'pinch');
      expect(UnitConverter.formatUnit('pinches', 1.0), 'pinch');
      expect(UnitConverter.formatUnit('pinch', 2.0), 'pinches');
      expect(UnitConverter.formatUnit('pinches', 2.0), 'pinches');

      // can / cans
      expect(UnitConverter.formatUnit('can', 1.0), 'can');
      expect(UnitConverter.formatUnit('can', 2.0), 'cans');

      // slice / slices
      expect(UnitConverter.formatUnit('slice', 1.0), 'slice');
      expect(UnitConverter.formatUnit('slice', 2.0), 'slices');

      // pound / pounds
      expect(UnitConverter.formatUnit('pound', 1.0), 'pound');
      expect(UnitConverter.formatUnit('pound', 2.0), 'pounds');

      // lb / lbs
      expect(UnitConverter.formatUnit('lb', 1.0), 'lb');
      expect(UnitConverter.formatUnit('lbs', 1.0), 'lb');
      expect(UnitConverter.formatUnit('lb', 2.0), 'lbs');
      expect(UnitConverter.formatUnit('lbs', 2.0), 'lbs');
      expect(UnitConverter.formatUnit('lb', 0.5), 'lbs');

      // pkg / pkgs
      expect(UnitConverter.formatUnit('pkg', 1.0), 'pkg');
      expect(UnitConverter.formatUnit('pkg', 2.0), 'pkgs');
    });

    test('formatUnit preserves invariant units and metric symbols', () {
      for (final qty in [1.0, 2.0, 0.5]) {
        expect(UnitConverter.formatUnit('g', qty), 'g');
        expect(UnitConverter.formatUnit('kg', qty), 'kg');
        expect(UnitConverter.formatUnit('ml', qty), 'ml');
        expect(UnitConverter.formatUnit('l', qty), 'l');
        expect(UnitConverter.formatUnit('tbsp', qty), 'tbsp');
        expect(UnitConverter.formatUnit('tsp', qty), 'tsp');
        expect(UnitConverter.formatUnit('oz', qty), 'oz');
      }
    });

    test('formatUnit handles custom user fallback heuristics', () {
      expect(UnitConverter.formatUnit('box', 1.0), 'box');
      expect(UnitConverter.formatUnit('box', 2.0), 'boxes');
      expect(UnitConverter.formatUnit('boxes', 1.0), 'box');
      expect(UnitConverter.formatUnit('bag', 1.0), 'bag');
      expect(UnitConverter.formatUnit('bag', 2.0), 'bags');
      expect(UnitConverter.formatUnit('bags', 1.0), 'bag');
    });

    test('formatQuantityAndUnit formats combination cleanly', () {
      expect(UnitConverter.formatQuantityAndUnit(1.0, 'cup'), '1 cup');
      expect(UnitConverter.formatQuantityAndUnit(2.0, 'cup'), '2 cups');
      expect(UnitConverter.formatQuantityAndUnit(0.5, 'cup'), '½ cups');
      expect(UnitConverter.formatQuantityAndUnit(1.0, 'clove'), '1 clove');
      expect(UnitConverter.formatQuantityAndUnit(3.0, 'clove'), '3 cloves');
      expect(UnitConverter.formatQuantityAndUnit(500, 'g'), '500 g');
      expect(UnitConverter.formatQuantityAndUnit(1.0, 'lb'), '1 lb');
      expect(UnitConverter.formatQuantityAndUnit(2.0, 'lb'), '2 lbs');
      expect(UnitConverter.formatQuantityAndUnit(2.0, 'tbsp'), '2 tbsp');
      expect(UnitConverter.formatQuantityAndUnit(1.0, ''), '1');
    });
  });
}
