class UserSettings {
  final double hoursAvailable;
  final bool showPendingTasks;
  final bool showLastSpawnedDate;

  const UserSettings({
    required this.hoursAvailable,
    this.showPendingTasks = false,
    this.showLastSpawnedDate = false,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      hoursAvailable: (json['hoursAvailable'] as num?)?.toDouble() ?? 8.0,
      showPendingTasks: json['showPendingTasks'] as bool? ?? false,
      showLastSpawnedDate: json['showLastSpawnedDate'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hoursAvailable': hoursAvailable,
      'showPendingTasks': showPendingTasks,
      'showLastSpawnedDate': showLastSpawnedDate,
    };
  }

  UserSettings copyWith({
    double? hoursAvailable,
    bool? showPendingTasks,
    bool? showLastSpawnedDate,
  }) {
    return UserSettings(
      hoursAvailable: hoursAvailable ?? this.hoursAvailable,
      showPendingTasks: showPendingTasks ?? this.showPendingTasks,
      showLastSpawnedDate: showLastSpawnedDate ?? this.showLastSpawnedDate,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSettings &&
          runtimeType == other.runtimeType &&
          hoursAvailable == other.hoursAvailable &&
          showPendingTasks == other.showPendingTasks &&
          showLastSpawnedDate == other.showLastSpawnedDate;

  @override
  int get hashCode =>
      hoursAvailable.hashCode ^
      showPendingTasks.hashCode ^
      showLastSpawnedDate.hashCode;
}
