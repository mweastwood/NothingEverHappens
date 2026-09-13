import 'package:flutter/material.dart';
export 'package:core/core.dart' show TaskLabel, TaskLabelScope;

/// Represents a single color entry in the 8-color label palette.
class LabelColorItem {
  final String key;
  final String name;
  final Color lightColor;
  final Color darkColor;

  const LabelColorItem({
    required this.key,
    required this.name,
    required this.lightColor,
    required this.darkColor,
  });

  Color getColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkColor : lightColor;
  }
}

/// The curated 8-color palette for task labels.
abstract final class LabelPalette {
  static const coral = LabelColorItem(
    key: 'coral',
    name: 'Coral',
    lightColor: Color(0xFFE53935),
    darkColor: Color(0xFFEF5350),
  );

  static const tangerine = LabelColorItem(
    key: 'tangerine',
    name: 'Tangerine',
    lightColor: Color(0xFFFB8C00),
    darkColor: Color(0xFFFFA726),
  );

  static const sunflower = LabelColorItem(
    key: 'sunflower',
    name: 'Sunflower',
    lightColor: Color(0xFFFBC02D),
    darkColor: Color(0xFFFFEE58),
  );

  static const emerald = LabelColorItem(
    key: 'emerald',
    name: 'Emerald',
    lightColor: Color(0xFF43A047),
    darkColor: Color(0xFF66BB6A),
  );

  static const teal = LabelColorItem(
    key: 'teal',
    name: 'Teal',
    lightColor: Color(0xFF00897B),
    darkColor: Color(0xFF26A69A),
  );

  static const cobalt = LabelColorItem(
    key: 'cobalt',
    name: 'Cobalt',
    lightColor: Color(0xFF1E88E5),
    darkColor: Color(0xFF42A5F5),
  );

  static const grape = LabelColorItem(
    key: 'grape',
    name: 'Grape',
    lightColor: Color(0xFF8E24AA),
    darkColor: Color(0xFFAB47BC),
  );

  static const rose = LabelColorItem(
    key: 'rose',
    name: 'Rose',
    lightColor: Color(0xFFD81B60),
    darkColor: Color(0xFFEC407A),
  );

  static const List<LabelColorItem> all = [
    coral,
    tangerine,
    sunflower,
    emerald,
    teal,
    cobalt,
    grape,
    rose,
  ];

  static LabelColorItem getItem(String? key) {
    if (key == null) return coral;
    final normalized = key.toLowerCase().trim();
    return all.firstWhere((c) => c.key == normalized, orElse: () => coral);
  }

  static Color getColor(String? key, BuildContext context) {
    return getItem(key).getColor(context);
  }
}

/// Represents an icon available for task labels.
class LabelIconItem {
  final String key;
  final String name;
  final IconData icon;

  const LabelIconItem({
    required this.key,
    required this.name,
    required this.icon,
  });
}

/// The curated set of 18 high-utility icons for task labels.
abstract final class LabelIcons {
  static const List<LabelIconItem> all = [
    LabelIconItem(key: 'tag', name: 'Label', icon: Icons.label_outlined),
    LabelIconItem(
      key: 'cleaning',
      name: 'Cleaning',
      icon: Icons.cleaning_services_outlined,
    ),
    LabelIconItem(
      key: 'shopping',
      name: 'Shopping',
      icon: Icons.shopping_cart_outlined,
    ),
    LabelIconItem(
      key: 'restaurant',
      name: 'Meals',
      icon: Icons.restaurant_outlined,
    ),
    LabelIconItem(key: 'home', name: 'Home', icon: Icons.home_outlined),
    LabelIconItem(
      key: 'car',
      name: 'Vehicle',
      icon: Icons.directions_car_outlined,
    ),
    LabelIconItem(key: 'pets', name: 'Pets', icon: Icons.pets_outlined),
    LabelIconItem(key: 'child', name: 'Kids', icon: Icons.child_care_outlined),
    LabelIconItem(key: 'work', name: 'Work', icon: Icons.work_outline),
    LabelIconItem(key: 'school', name: 'School', icon: Icons.school_outlined),
    LabelIconItem(
      key: 'medication',
      name: 'Health',
      icon: Icons.medication_outlined,
    ),
    LabelIconItem(
      key: 'payments',
      name: 'Finances',
      icon: Icons.payments_outlined,
    ),
    LabelIconItem(key: 'yard', name: 'Garden', icon: Icons.yard_outlined),
    LabelIconItem(key: 'build', name: 'Repairs', icon: Icons.build_outlined),
    LabelIconItem(
      key: 'fitness',
      name: 'Fitness',
      icon: Icons.fitness_center_outlined,
    ),
    LabelIconItem(key: 'bolt', name: 'Urgent', icon: Icons.bolt_outlined),
    LabelIconItem(key: 'star', name: 'Special', icon: Icons.star_outline),
    LabelIconItem(key: 'palette', name: 'Hobby', icon: Icons.palette_outlined),
  ];

  static LabelIconItem getItem(String? key) {
    if (key == null) return all.first;
    final normalized = key.toLowerCase().trim();
    return all.firstWhere((i) => i.key == normalized, orElse: () => all.first);
  }

  static IconData getIcon(String? key) {
    return getItem(key).icon;
  }
}
