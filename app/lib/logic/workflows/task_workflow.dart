import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../relative_time.dart';

enum WorkflowType { standard, mealWorkflow }

enum WorkflowStage { selectMeal, shoppingList, prepDinner }

enum MealSelectionOption { recipe, leftovers, eatingOut, delivery }

class MealWorkflowConfig {
  final RelativeTime selectTime;
  final RelativeTime shopTime;
  final RelativeTime prepTime;

  const MealWorkflowConfig({
    this.selectTime = const RelativeTime(
      dayOffset: 0,
      time: TimeOfDay(hour: 10, minute: 0),
    ),
    this.shopTime = const RelativeTime(
      dayOffset: 0,
      time: TimeOfDay(hour: 16, minute: 0),
    ),
    this.prepTime = const RelativeTime(
      dayOffset: 0,
      time: TimeOfDay(hour: 18, minute: 30),
    ),
  });

  MealWorkflowConfig copyWith({
    RelativeTime? selectTime,
    RelativeTime? shopTime,
    RelativeTime? prepTime,
  }) {
    return MealWorkflowConfig(
      selectTime: selectTime ?? this.selectTime,
      shopTime: shopTime ?? this.shopTime,
      prepTime: prepTime ?? this.prepTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'selectTime': selectTime.toJson(),
      'shopTime': shopTime.toJson(),
      'prepTime': prepTime.toJson(),
    };
  }

  factory MealWorkflowConfig.fromJson(Map<String, dynamic> json) {
    return MealWorkflowConfig(
      selectTime: json['selectTime'] != null
          ? RelativeTime.fromJson(
              Map<String, dynamic>.from(json['selectTime'] as Map),
            )
          : const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 10, minute: 0),
            ),
      shopTime: json['shopTime'] != null
          ? RelativeTime.fromJson(
              Map<String, dynamic>.from(json['shopTime'] as Map),
            )
          : const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 16, minute: 0),
            ),
      prepTime: json['prepTime'] != null
          ? RelativeTime.fromJson(
              Map<String, dynamic>.from(json['prepTime'] as Map),
            )
          : const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 18, minute: 30),
            ),
    );
  }
}

class ShoppingItemPayload {
  final String id;
  final String name;
  final double quantity;
  final String unit;
  final bool isPantryOwned;
  final bool isBought;
  final bool isCustom;

  const ShoppingItemPayload({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    this.isPantryOwned = false,
    this.isBought = false,
    this.isCustom = false,
  });

  ShoppingItemPayload copyWith({
    String? id,
    String? name,
    double? quantity,
    String? unit,
    bool? isPantryOwned,
    bool? isBought,
    bool? isCustom,
  }) {
    return ShoppingItemPayload(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      isPantryOwned: isPantryOwned ?? this.isPantryOwned,
      isBought: isBought ?? this.isBought,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'isPantryOwned': isPantryOwned,
      'isBought': isBought,
      'isCustom': isCustom,
    };
  }

  factory ShoppingItemPayload.fromJson(Map<String, dynamic> json) {
    return ShoppingItemPayload(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: json['name'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: json['unit'] as String? ?? '',
      isPantryOwned: json['isPantryOwned'] as bool? ?? false,
      isBought: json['isBought'] as bool? ?? false,
      isCustom: json['isCustom'] as bool? ?? false,
    );
  }
}

class WorkflowInstancePayload {
  final String workflowType;
  final WorkflowStage stage;
  final String workflowGroupId;
  final MealSelectionOption? selectedOption;
  final String? recipeId;
  final String? recipeTitle;
  final int? targetServings;
  final List<ShoppingItemPayload> shoppingItems;
  final String? customMealNote;

  const WorkflowInstancePayload({
    required this.workflowType,
    required this.stage,
    required this.workflowGroupId,
    this.selectedOption,
    this.recipeId,
    this.recipeTitle,
    this.targetServings,
    this.shoppingItems = const [],
    this.customMealNote,
  });

  WorkflowInstancePayload copyWith({
    String? workflowType,
    WorkflowStage? stage,
    String? workflowGroupId,
    MealSelectionOption? selectedOption,
    String? recipeId,
    String? recipeTitle,
    int? targetServings,
    List<ShoppingItemPayload>? shoppingItems,
    String? customMealNote,
  }) {
    return WorkflowInstancePayload(
      workflowType: workflowType ?? this.workflowType,
      stage: stage ?? this.stage,
      workflowGroupId: workflowGroupId ?? this.workflowGroupId,
      selectedOption: selectedOption ?? this.selectedOption,
      recipeId: recipeId ?? this.recipeId,
      recipeTitle: recipeTitle ?? this.recipeTitle,
      targetServings: targetServings ?? this.targetServings,
      shoppingItems: shoppingItems ?? this.shoppingItems,
      customMealNote: customMealNote ?? this.customMealNote,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'workflowType': workflowType,
      'stage': stage.name,
      'workflowGroupId': workflowGroupId,
      if (selectedOption != null) 'selectedOption': selectedOption!.name,
      if (recipeId != null) 'recipeId': recipeId,
      if (recipeTitle != null) 'recipeTitle': recipeTitle,
      if (targetServings != null) 'targetServings': targetServings,
      if (shoppingItems.isNotEmpty)
        'shoppingItems': shoppingItems.map((i) => i.toJson()).toList(),
      if (customMealNote != null) 'customMealNote': customMealNote,
    };
  }

  factory WorkflowInstancePayload.fromJson(Map<String, dynamic> json) {
    WorkflowStage parseStage(String? val) {
      if (val == null) return WorkflowStage.selectMeal;
      for (final s in WorkflowStage.values) {
        if (s.name == val) return s;
      }
      return WorkflowStage.selectMeal;
    }

    MealSelectionOption? parseOption(String? val) {
      if (val == null) return null;
      for (final o in MealSelectionOption.values) {
        if (o.name == val) return o;
      }
      return null;
    }

    return WorkflowInstancePayload(
      workflowType: json['workflowType'] as String? ?? 'mealWorkflow',
      stage: parseStage(json['stage'] as String?),
      workflowGroupId: json['workflowGroupId'] as String? ?? '',
      selectedOption: parseOption(json['selectedOption'] as String?),
      recipeId: json['recipeId'] as String?,
      recipeTitle: json['recipeTitle'] as String?,
      targetServings: (json['targetServings'] as num?)?.toInt(),
      shoppingItems:
          (json['shoppingItems'] as List<dynamic>?)
              ?.map(
                (item) => ShoppingItemPayload.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList() ??
          const [],
      customMealNote: json['customMealNote'] as String?,
    );
  }
}
