class UserSettings {
  final double hoursAvailable;
  final bool showPendingTasks;
  final bool showLastSpawnedDate;
  final int futureInstancesCount;

  const UserSettings({
    required this.hoursAvailable,
    this.showPendingTasks = false,
    this.showLastSpawnedDate = false,
    this.futureInstancesCount = 1,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      hoursAvailable: (json['hoursAvailable'] as num?)?.toDouble() ?? 8.0,
      showPendingTasks: json['showPendingTasks'] as bool? ?? false,
      showLastSpawnedDate: json['showLastSpawnedDate'] as bool? ?? false,
      futureInstancesCount: json['futureInstancesCount'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hoursAvailable': hoursAvailable,
      'showPendingTasks': showPendingTasks,
      'showLastSpawnedDate': showLastSpawnedDate,
      'futureInstancesCount': futureInstancesCount,
    };
  }

  UserSettings copyWith({
    double? hoursAvailable,
    bool? showPendingTasks,
    bool? showLastSpawnedDate,
    int? futureInstancesCount,
  }) {
    return UserSettings(
      hoursAvailable: hoursAvailable ?? this.hoursAvailable,
      showPendingTasks: showPendingTasks ?? this.showPendingTasks,
      showLastSpawnedDate: showLastSpawnedDate ?? this.showLastSpawnedDate,
      futureInstancesCount: futureInstancesCount ?? this.futureInstancesCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSettings &&
          runtimeType == other.runtimeType &&
          hoursAvailable == other.hoursAvailable &&
          showPendingTasks == other.showPendingTasks &&
          showLastSpawnedDate == other.showLastSpawnedDate &&
          futureInstancesCount == other.futureInstancesCount;

  @override
  int get hashCode => Object.hash(
    hoursAvailable,
    showPendingTasks,
    showLastSpawnedDate,
    futureInstancesCount,
  );
}
