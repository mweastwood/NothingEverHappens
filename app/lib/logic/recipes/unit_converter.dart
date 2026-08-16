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

  static const Map<String, String> _singularToPlural = {
    'cup': 'cups',
    'clove': 'cloves',
    'piece': 'pieces',
    'can': 'cans',
    'pinch': 'pinches',
    'slice': 'slices',
    'stalk': 'stalks',
    'bunch': 'bunches',
    'head': 'heads',
    'sprig': 'sprigs',
    'dash': 'dashes',
    'package': 'packages',
    'pkg': 'pkgs',
    'pound': 'pounds',
    'lb': 'lbs',
    'tablespoon': 'tablespoons',
    'teaspoon': 'teaspoons',
    'fluid ounce': 'fluid ounces',
    'pint': 'pints',
    'quart': 'quarts',
    'gallon': 'gallons',
    'gram': 'grams',
    'kilogram': 'kilograms',
    'milliliter': 'milliliters',
    'liter': 'liters',
    'ounce': 'ounces',
    'item': 'items',
  };

  static final Map<String, String> _pluralToSingular = {
    for (final entry in _singularToPlural.entries) entry.value: entry.key,
  };

  static const Set<String> _invariableUnits = {
    'g',
    'kg',
    'ml',
    'l',
    'tbsp',
    'tsp',
    'oz',
    'fl oz',
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
      'fluid ounces',
      'cup',
      'cups',
      'pt',
      'pint',
      'pints',
      'qt',
      'quart',
      'quarts',
      'gal',
      'gallon',
      'gallons',
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

  /// Formats a unit as singular or plural based on the quantity.
  static String formatUnit(String unit, double quantity) {
    final trimmed = unit.trim();
    if (trimmed.isEmpty) return unit;

    final lower = trimmed.toLowerCase();

    // Invariable abbreviations & metric symbols
    if (_invariableUnits.contains(lower)) {
      return trimmed;
    }

    final isPlural = quantity != 1.0;

    if (isPlural) {
      if (_singularToPlural.containsKey(lower)) {
        return _matchCase(trimmed, _singularToPlural[lower]!);
      }
      if (_pluralToSingular.containsKey(lower)) {
        return trimmed;
      }
      // Heuristic fallback for plurals
      if (lower.endsWith('s')) {
        return trimmed;
      }
      if (lower.endsWith('ch') ||
          lower.endsWith('sh') ||
          lower.endsWith('x') ||
          lower.endsWith('z')) {
        return _matchCase(trimmed, '${trimmed}es');
      }
      return _matchCase(trimmed, '${trimmed}s');
    } else {
      // Singular (quantity == 1.0)
      if (_pluralToSingular.containsKey(lower)) {
        return _matchCase(trimmed, _pluralToSingular[lower]!);
      }
      if (_singularToPlural.containsKey(lower)) {
        return trimmed;
      }
      // Heuristic fallback for singulars
      if (lower.endsWith('ches') ||
          lower.endsWith('shes') ||
          lower.endsWith('xes') ||
          lower.endsWith('zes')) {
        return trimmed.substring(0, trimmed.length - 2);
      }
      if (lower.endsWith('s') && !lower.endsWith('ss') && lower.length > 1) {
        return trimmed.substring(0, trimmed.length - 1);
      }
      return trimmed;
    }
  }

  /// Convenience helper to format quantity and unit together.
  static String formatQuantityAndUnit(double quantity, String unit) {
    final qtyStr = formatQuantity(quantity);
    final formattedUnit = formatUnit(unit, quantity);
    if (qtyStr.isEmpty) return formattedUnit;
    if (formattedUnit.isEmpty) return qtyStr;
    return '$qtyStr $formattedUnit';
  }

  static String _matchCase(String original, String target) {
    if (original.isEmpty || target.isEmpty) return target;
    if (original == original.toUpperCase()) return target.toUpperCase();
    if (original[0] == original[0].toUpperCase() &&
        original.substring(1) == original.substring(1).toLowerCase()) {
      return target[0].toUpperCase() + target.substring(1);
    }
    return target;
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
          final lVal = ml / 1000.0;
          return ConvertedQuantity(
            quantity: lVal,
            unit: formatUnit('l', lVal),
          );
        }
        return ConvertedQuantity(
          quantity: ml,
          unit: formatUnit('ml', ml),
        );
      } else {
        // Imperial
        if (ml < 15) {
          final tsps = ml / _volumeToMl['tsp']!;
          return ConvertedQuantity(
            quantity: tsps,
            unit: formatUnit('tsp', tsps),
          );
        } else if (ml < 60) {
          final tbsps = ml / _volumeToMl['tbsp']!;
          return ConvertedQuantity(
            quantity: tbsps,
            unit: formatUnit('tbsp', tbsps),
          );
        } else {
          final cups = ml / _volumeToMl['cup']!;
          return ConvertedQuantity(
            quantity: cups,
            unit: formatUnit('cup', cups),
          );
        }
      }
    } else if (isMass(cleanUnit)) {
      final grams = quantity * _massToGrams[cleanUnit]!;
      if (targetSystem == UnitSystem.metric) {
        if (grams >= 1000) {
          final kgVal = grams / 1000.0;
          return ConvertedQuantity(
            quantity: kgVal,
            unit: formatUnit('kg', kgVal),
          );
        }
        return ConvertedQuantity(
          quantity: grams,
          unit: formatUnit('g', grams),
        );
      } else {
        // Imperial
        if (grams >= 453.592) {
          final lbs = grams / _massToGrams['lb']!;
          return ConvertedQuantity(
            quantity: lbs,
            unit: formatUnit('lb', lbs),
          );
        } else {
          final oz = grams / _massToGrams['oz']!;
          return ConvertedQuantity(
            quantity: oz,
            unit: formatUnit('oz', oz),
          );
        }
      }
    }

    // Unconvertible (e.g. piece, clove, pinch)
    return ConvertedQuantity(
      quantity: quantity,
      unit: formatUnit(unit, quantity),
    );
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
