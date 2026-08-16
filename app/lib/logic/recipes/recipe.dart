import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class RecipeIngredient {
  final String id;
  final String name;
  final double quantity;
  final String unit;
  final String? notes;

  const RecipeIngredient({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    this.notes,
  });

  RecipeIngredient copyWith({
    String? id,
    String? name,
    double? quantity,
    String? unit,
    String? notes,
  }) {
    return RecipeIngredient(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      if (notes != null) 'notes': notes,
    };
  }

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: json['name'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] as String? ?? '',
      notes: json['notes'] as String?,
    );
  }
}

class RecipeStep {
  final int stepNumber;
  final String instruction;
  final int estimatedMinutes;
  final int timerDurationSeconds;

  const RecipeStep({
    required this.stepNumber,
    required this.instruction,
    this.estimatedMinutes = 0,
    this.timerDurationSeconds = 0,
  });

  RecipeStep copyWith({
    int? stepNumber,
    String? instruction,
    int? estimatedMinutes,
    int? timerDurationSeconds,
  }) {
    return RecipeStep(
      stepNumber: stepNumber ?? this.stepNumber,
      instruction: instruction ?? this.instruction,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      timerDurationSeconds: timerDurationSeconds ?? this.timerDurationSeconds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stepNumber': stepNumber,
      'instruction': instruction,
      'estimatedMinutes': estimatedMinutes,
      'timerDurationSeconds': timerDurationSeconds,
    };
  }

  factory RecipeStep.fromJson(Map<String, dynamic> json) {
    return RecipeStep(
      stepNumber: json['stepNumber'] as int? ?? 1,
      instruction: json['instruction'] as String? ?? '',
      estimatedMinutes: json['estimatedMinutes'] as int? ?? 0,
      timerDurationSeconds: json['timerDurationSeconds'] as int? ?? 0,
    );
  }
}

class Recipe {
  static String generateId() => 'R-${const Uuid().v4()}';

  final String id;
  final String title;
  final String description;
  final int servings;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> prepSteps;
  final List<RecipeStep> cookSteps;
  final bool isFamily;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool hasPendingWrites;
  final bool isFromCache;

  Recipe({
    String? id,
    required this.title,
    this.description = '',
    this.servings = 4,
    this.ingredients = const [],
    this.prepSteps = const [],
    this.cookSteps = const [],
    this.isFamily = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.hasPendingWrites = false,
    this.isFromCache = false,
  }) : id = id ?? Recipe.generateId(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  int get totalPrepMinutes =>
      prepSteps.fold(0, (total, s) => total + s.estimatedMinutes);

  int get totalCookMinutes =>
      cookSteps.fold(0, (total, s) => total + s.estimatedMinutes);

  int get totalMinutes => totalPrepMinutes + totalCookMinutes;

  Recipe copyWith({
    String? id,
    String? title,
    String? description,
    int? servings,
    List<RecipeIngredient>? ingredients,
    List<RecipeStep>? prepSteps,
    List<RecipeStep>? cookSteps,
    bool? isFamily,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? hasPendingWrites,
    bool? isFromCache,
  }) {
    return Recipe(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      servings: servings ?? this.servings,
      ingredients: ingredients ?? this.ingredients,
      prepSteps: prepSteps ?? this.prepSteps,
      cookSteps: cookSteps ?? this.cookSteps,
      isFamily: isFamily ?? this.isFamily,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      hasPendingWrites: hasPendingWrites ?? this.hasPendingWrites,
      isFromCache: isFromCache ?? this.isFromCache,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'servings': servings,
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
      'prepSteps': prepSteps.map((s) => s.toJson()).toList(),
      'cookSteps': cookSteps.map((s) => s.toJson()).toList(),
      'isFamily': isFamily,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.now();
    }

    return Recipe(
      id: json['id'] as String? ?? Recipe.generateId(),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      servings: (json['servings'] as num?)?.toInt() ?? 4,
      ingredients:
          (json['ingredients'] as List<dynamic>?)
              ?.map(
                (item) => RecipeIngredient.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList() ??
          const [],
      prepSteps:
          (json['prepSteps'] as List<dynamic>?)
              ?.map(
                (item) =>
                    RecipeStep.fromJson(Map<String, dynamic>.from(item as Map)),
              )
              .toList() ??
          const [],
      cookSteps:
          (json['cookSteps'] as List<dynamic>?)
              ?.map(
                (item) =>
                    RecipeStep.fromJson(Map<String, dynamic>.from(item as Map)),
              )
              .toList() ??
          const [],
      isFamily: json['isFamily'] as bool? ?? false,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'servings': servings,
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
      'prepSteps': prepSteps.map((s) => s.toJson()).toList(),
      'cookSteps': cookSteps.map((s) => s.toJson()).toList(),
      'isFamily': isFamily,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory Recipe.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot, [
    SnapshotOptions? options,
  ]) {
    final data = snapshot.data();
    if (data == null) {
      throw Exception('Recipe data is null for document ${snapshot.id}');
    }

    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      if (value is DateTime) return value;
      return DateTime.now();
    }

    return Recipe(
      id: snapshot.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      servings: (data['servings'] as num?)?.toInt() ?? 4,
      ingredients:
          (data['ingredients'] as List<dynamic>?)
              ?.map(
                (item) => RecipeIngredient.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList() ??
          const [],
      prepSteps:
          (data['prepSteps'] as List<dynamic>?)
              ?.map(
                (item) =>
                    RecipeStep.fromJson(Map<String, dynamic>.from(item as Map)),
              )
              .toList() ??
          const [],
      cookSteps:
          (data['cookSteps'] as List<dynamic>?)
              ?.map(
                (item) =>
                    RecipeStep.fromJson(Map<String, dynamic>.from(item as Map)),
              )
              .toList() ??
          const [],
      isFamily: data['isFamily'] as bool? ?? false,
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
      hasPendingWrites: snapshot.metadata.hasPendingWrites,
      isFromCache: snapshot.metadata.isFromCache,
    );
  }
}
