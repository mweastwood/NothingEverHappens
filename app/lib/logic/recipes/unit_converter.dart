import 'recipe.dart';

enum UnitSystem { metric, imperial }

class ConvertedQuantity {
  final double quantity;
  final String unit;

  const ConvertedQuantity({required this.quantity, required this.unit});
}

class UnitConverter {
  // Volume to ml
  static const Map<String, double> _volumeToMl = {
    'ml': 1.0,
    'milliliter': 1.0,
    'milliliters': 1.0,
    'l': 1000.0,
    'liter': 1000.0,
    'liters': 1000.0,
    'tsp': 4.92892,
    'teaspoon': 4.92892,
    'teaspoons': 4.92892,
    'tbsp': 14.7868,
    'tablespoon': 14.7868,
    'tablespoons': 14.7868,
    'fl oz': 29.5735,
    'fluid ounce': 29.5735,
    'fluid ounces': 29.5735,
    'cup': 236.588,
    'cups': 236.588,
    'pt': 473.176,
    'pint': 473.176,
    'pints': 473.176,
    'qt': 946.353,
    'quart': 946.353,
    'quarts': 946.353,
    'gal': 3785.41,
    'gallon': 3785.41,
    'gallons': 3785.41,
  };

  // Mass to grams
  static const Map<String, double> _massToGrams = {
    'g': 1.0,
    'gram': 1.0,
    'grams': 1.0,
    'kg': 1000.0,
    'kilogram': 1000.0,
    'kilograms': 1000.0,
    'oz': 28.3495,
    'ounce': 28.3495,
    'ounces': 28.3495,
    'lb': 453.592,
    'lbs': 453.592,
    'pound': 453.592,
    'pounds': 453.592,
  };

  static bool isVolume(String unit) =>
      _volumeToMl.containsKey(unit.toLowerCase().trim());

  static bool isMass(String unit) =>
      _massToGrams.containsKey(unit.toLowerCase().trim());

  static UnitSystem? getUnitSystem(String unit) {
    final u = unit.toLowerCase().trim();
    if ([
      'ml',
      'milliliter',
      'milliliters',
      'l',
      'liter',
      'liters',
      'g',
      'gram',
      'grams',
      'kg',
      'kilogram',
      'kilograms',
    ].contains(u)) {
      return UnitSystem.metric;
    }
    if ([
      'tsp',
      'teaspoon',
      'teaspoons',
      'tbsp',
      'tablespoon',
      'tablespoons',
      'fl oz',
      'fluid ounce',
      'cup',
      'cups',
      'pt',
      'pint',
      'qt',
      'quart',
      'gal',
      'gallon',
      'oz',
      'ounce',
      'ounces',
      'lb',
      'lbs',
      'pound',
      'pounds',
    ].contains(u)) {
      return UnitSystem.imperial;
    }
    return null;
  }

  /// Converts a quantity and unit to the target unit system.
  static ConvertedQuantity convert({
    required double quantity,
    required String unit,
    required UnitSystem targetSystem,
  }) {
    final cleanUnit = unit.toLowerCase().trim();

    if (isVolume(cleanUnit)) {
      final ml = quantity * _volumeToMl[cleanUnit]!;
      if (targetSystem == UnitSystem.metric) {
        if (ml >= 1000) {
          return ConvertedQuantity(quantity: ml / 1000.0, unit: 'l');
        }
        return ConvertedQuantity(quantity: ml, unit: 'ml');
      } else {
        // Imperial
        if (ml < 15) {
          final tsps = ml / _volumeToMl['tsp']!;
          return ConvertedQuantity(
            quantity: tsps,
            unit: tsps == 1 ? 'tsp' : 'tsps',
          );
        } else if (ml < 60) {
          final tbsps = ml / _volumeToMl['tbsp']!;
          return ConvertedQuantity(
            quantity: tbsps,
            unit: tbsps == 1 ? 'tbsp' : 'tbsps',
          );
        } else {
          final cups = ml / _volumeToMl['cup']!;
          return ConvertedQuantity(
            quantity: cups,
            unit: cups == 1 ? 'cup' : 'cups',
          );
        }
      }
    } else if (isMass(cleanUnit)) {
      final grams = quantity * _massToGrams[cleanUnit]!;
      if (targetSystem == UnitSystem.metric) {
        if (grams >= 1000) {
          return ConvertedQuantity(quantity: grams / 1000.0, unit: 'kg');
        }
        return ConvertedQuantity(quantity: grams, unit: 'g');
      } else {
        // Imperial
        if (grams >= 453.592) {
          final lbs = grams / _massToGrams['lb']!;
          return ConvertedQuantity(
            quantity: lbs,
            unit: lbs == 1 ? 'lb' : 'lbs',
          );
        } else {
          final oz = grams / _massToGrams['oz']!;
          return ConvertedQuantity(quantity: oz, unit: oz == 1 ? 'oz' : 'oz');
        }
      }
    }

    // Unconvertible (e.g. piece, clove, pinch)
    return ConvertedQuantity(quantity: quantity, unit: unit);
  }

  /// Scales an ingredient for target servings.
  static RecipeIngredient scale({
    required RecipeIngredient ingredient,
    required int originalServings,
    required int targetServings,
  }) {
    if (originalServings <= 0 ||
        targetServings <= 0 ||
        originalServings == targetServings) {
      return ingredient;
    }
    final factor = targetServings / originalServings.toDouble();
    return ingredient.copyWith(quantity: ingredient.quantity * factor);
  }

  /// Formats quantity nicely (fractions or decimals).
  static String formatQuantity(double quantity) {
    if (quantity <= 0) return '';
    if (quantity == quantity.roundToDouble()) {
      return quantity.toInt().toString();
    }

    final intPart = quantity.floor();
    final fracPart = quantity - intPart;

    String fracString = '';
    const tolerance = 0.04;

    if ((fracPart - 0.5).abs() < tolerance) {
      fracString = '½';
    } else if ((fracPart - 0.25).abs() < tolerance) {
      fracString = '¼';
    } else if ((fracPart - 0.75).abs() < tolerance) {
      fracString = '¾';
    } else if ((fracPart - 0.333).abs() < tolerance) {
      fracString = '⅓';
    } else if ((fracPart - 0.667).abs() < tolerance) {
      fracString = '⅔';
    } else if ((fracPart - 0.125).abs() < tolerance) {
      fracString = '⅛';
    } else if ((fracPart - 0.375).abs() < tolerance) {
      fracString = '⅜';
    } else if ((fracPart - 0.625).abs() < tolerance) {
      fracString = '⅝';
    } else if ((fracPart - 0.875).abs() < tolerance) {
      fracString = '⅞';
    }

    if (fracString.isNotEmpty) {
      return intPart > 0 ? '$intPart $fracString' : fracString;
    }

    // Default rounded decimal
    final rounded = (quantity * 100).round() / 100;
    return rounded.toString();
  }
}
