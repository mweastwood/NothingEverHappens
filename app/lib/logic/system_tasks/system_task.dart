import 'package:flutter/widgets.dart';

enum SystemTaskPriority { high, medium, low }

enum SystemTaskCategory { capacity, profile, family, system }

class SystemTask {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final SystemTaskPriority priority;
  final SystemTaskCategory category;
  final String? actionLabel;
  final String? secondaryActionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onSecondaryAction;
  final VoidCallback? onTap;
  final bool isDismissible;
  final VoidCallback? onDismiss;

  const SystemTask({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.priority = SystemTaskPriority.medium,
    this.category = SystemTaskCategory.system,
    this.actionLabel,
    this.secondaryActionLabel,
    this.onAction,
    this.onSecondaryAction,
    this.onTap,
    this.isDismissible = false,
    this.onDismiss,
  });

  SystemTask copyWith({
    String? id,
    String? title,
    String? description,
    IconData? icon,
    SystemTaskPriority? priority,
    SystemTaskCategory? category,
    String? actionLabel,
    String? secondaryActionLabel,
    VoidCallback? onAction,
    VoidCallback? onSecondaryAction,
    VoidCallback? onTap,
    bool? isDismissible,
    VoidCallback? onDismiss,
  }) {
    return SystemTask(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      actionLabel: actionLabel ?? this.actionLabel,
      secondaryActionLabel: secondaryActionLabel ?? this.secondaryActionLabel,
      onAction: onAction ?? this.onAction,
      onSecondaryAction: onSecondaryAction ?? this.onSecondaryAction,
      onTap: onTap ?? this.onTap,
      isDismissible: isDismissible ?? this.isDismissible,
      onDismiss: onDismiss ?? this.onDismiss,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SystemTask &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          description == other.description &&
          icon == other.icon &&
          priority == other.priority &&
          category == other.category &&
          actionLabel == other.actionLabel &&
          secondaryActionLabel == other.secondaryActionLabel &&
          isDismissible == other.isDismissible;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      description.hashCode ^
      icon.hashCode ^
      priority.hashCode ^
      category.hashCode ^
      (actionLabel?.hashCode ?? 0) ^
      (secondaryActionLabel?.hashCode ?? 0) ^
      isDismissible.hashCode;

  @override
  String toString() =>
      'SystemTask(id: $id, title: $title, priority: $priority, category: $category)';
}
