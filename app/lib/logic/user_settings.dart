class UserSettings {
  final double hoursAvailable;
  final bool showPendingTasks;
  final bool showLastSpawnedDate;
  final bool showRecentlyResolvedTasks;

  const UserSettings({
    required this.hoursAvailable,
    this.showPendingTasks = false,
    this.showLastSpawnedDate = false,
    this.showRecentlyResolvedTasks = false,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      hoursAvailable: (json['hoursAvailable'] as num?)?.toDouble() ?? 8.0,
      showPendingTasks: json['showPendingTasks'] as bool? ?? false,
      showLastSpawnedDate: json['showLastSpawnedDate'] as bool? ?? false,
      showRecentlyResolvedTasks:
          json['showRecentlyResolvedTasks'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hoursAvailable': hoursAvailable,
      'showPendingTasks': showPendingTasks,
      'showLastSpawnedDate': showLastSpawnedDate,
      'showRecentlyResolvedTasks': showRecentlyResolvedTasks,
    };
  }

  UserSettings copyWith({
    double? hoursAvailable,
    bool? showPendingTasks,
    bool? showLastSpawnedDate,
    bool? showRecentlyResolvedTasks,
  }) {
    return UserSettings(
      hoursAvailable: hoursAvailable ?? this.hoursAvailable,
      showPendingTasks: showPendingTasks ?? this.showPendingTasks,
      showLastSpawnedDate: showLastSpawnedDate ?? this.showLastSpawnedDate,
      showRecentlyResolvedTasks:
          showRecentlyResolvedTasks ?? this.showRecentlyResolvedTasks,
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
          showRecentlyResolvedTasks == other.showRecentlyResolvedTasks;

  @override
  int get hashCode =>
      hoursAvailable.hashCode ^
      showPendingTasks.hashCode ^
      showLastSpawnedDate.hashCode ^
      showRecentlyResolvedTasks.hashCode;
}
