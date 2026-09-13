import 'package:uuid/uuid.dart';

enum TaskLabelScope {
  personal,
  family;

  static TaskLabelScope fromString(String? value) {
    if (value == null) return TaskLabelScope.personal;
    final normalized = value.toLowerCase().trim();
    return TaskLabelScope.values.firstWhere(
      (e) => e.name.toLowerCase() == normalized,
      orElse: () => TaskLabelScope.personal,
    );
  }
}

class TaskLabel {
  static String generateId() => 'L-${const Uuid().v4()}';

  final String id;
  final String name;
  final String colorKey;
  final String iconKey;
  final TaskLabelScope scope;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const TaskLabel({
    required this.id,
    required this.name,
    required this.colorKey,
    required this.iconKey,
    this.scope = TaskLabelScope.personal,
    required this.createdAt,
    this.updatedAt,
  });

  factory TaskLabel.create({
    String? id,
    required String name,
    required String colorKey,
    required String iconKey,
    TaskLabelScope scope = TaskLabelScope.personal,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaskLabel(
      id: id ?? generateId(),
      name: name.trim(),
      colorKey: colorKey,
      iconKey: iconKey,
      scope: scope,
      createdAt: createdAt ?? DateTime.now().toUtc(),
      updatedAt: updatedAt,
    );
  }

  factory TaskLabel.fromFirestore(dynamic snapshot, [dynamic options]) {
    final data = (snapshot as dynamic).data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Data is null for document ${snapshot.id}');
    }
    return TaskLabel.fromMap(data, id: snapshot.id as String);
  }

  factory TaskLabel.fromMap(Map<String, dynamic> data, {String? id}) {
    DateTime parseDate(dynamic val) {
      if (val is DateTime) return val;
      if (val is String)
        return DateTime.tryParse(val) ?? DateTime.now().toUtc();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val != null) {
        try {
          return (val as dynamic).toDate() as DateTime;
        } catch (_) {}
      }
      return DateTime.now().toUtc();
    }

    return TaskLabel(
      id: id ?? (data['id'] as String? ?? ''),
      name: data['name'] as String? ?? '',
      colorKey: data['colorKey'] as String? ?? 'coral',
      iconKey: data['iconKey'] as String? ?? 'tag',
      scope: TaskLabelScope.fromString(data['scope'] as String?),
      createdAt: parseDate(data['createdAt']),
      updatedAt:
          data['updatedAt'] != null ? parseDate(data['updatedAt']) : null,
    );
  }

  factory TaskLabel.fromJson(Map<String, dynamic> json, [String? id]) =>
      TaskLabel.fromMap(json, id: id);

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'colorKey': colorKey,
      'iconKey': iconKey,
      'scope': scope.name,
      'createdAt': createdAt.toUtc().toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      ...toMap(),
    };
  }

  Map<String, dynamic> toFirestore() => toMap();

  TaskLabel copyWith({
    String? id,
    String? name,
    String? colorKey,
    String? iconKey,
    TaskLabelScope? scope,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaskLabel(
      id: id ?? this.id,
      name: name ?? this.name,
      colorKey: colorKey ?? this.colorKey,
      iconKey: iconKey ?? this.iconKey,
      scope: scope ?? this.scope,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TaskLabel &&
        other.id == id &&
        other.name == name &&
        other.colorKey == colorKey &&
        other.iconKey == iconKey &&
        other.scope == scope &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        colorKey,
        iconKey,
        scope,
        createdAt,
        updatedAt,
      );
}
