import 'package:flutter/foundation.dart';
import 'app_clock.dart';

class UserSettings {
  final double hoursAvailable;
  final bool showLastSpawnedDate;
  final List<({String column, bool ascending})>? taskListSort;
  final List<({String column, bool ascending})>? scheduleListSort;
  final Map<String, double>? defaultDailyCapacity;
  final Map<String, double>? dailyCapacityOverrides;
  final String? lastCapacityConfirmedWeek;

  const UserSettings({
    required this.hoursAvailable,
    this.showLastSpawnedDate = false,
    this.taskListSort,
    this.scheduleListSort,
    this.defaultDailyCapacity,
    this.dailyCapacityOverrides,
    this.lastCapacityConfirmedWeek,
  });

  double getCapacityForDate(DateTime date) {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    if (dailyCapacityOverrides != null &&
        dailyCapacityOverrides!.containsKey(dateStr)) {
      return dailyCapacityOverrides![dateStr]!;
    }
    final weekdayStr = date.weekday.toString();
    if (defaultDailyCapacity != null &&
        defaultDailyCapacity!.containsKey(weekdayStr)) {
      return defaultDailyCapacity![weekdayStr]!;
    }
    return hoursAvailable;
  }

  static Map<String, double>? _pruneOverrides(
    Map<String, double>? overrides,
    DateTime now,
  ) {
    if (overrides == null || overrides.isEmpty) return overrides;

    final cutoffDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 90));
    final cutoffStr =
        '${cutoffDate.year}-${cutoffDate.month.toString().padLeft(2, '0')}-${cutoffDate.day.toString().padLeft(2, '0')}';

    final pruned = <String, double>{};
    for (final entry in overrides.entries) {
      if (entry.key.compareTo(cutoffStr) >= 0) {
        pruned[entry.key] = entry.value;
      }
    }
    return pruned;
  }

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    final taskListSortJson = json['taskListSort'] as List<dynamic>?;
    final taskListSort = taskListSortJson?.map((e) {
      final map = e as Map<String, dynamic>;
      return (
        column: map['column'] as String,
        ascending: map['ascending'] as bool,
      );
    }).toList();

    final scheduleListSortJson = json['scheduleListSort'] as List<dynamic>?;
    final scheduleListSort = scheduleListSortJson?.map((e) {
      final map = e as Map<String, dynamic>;
      return (
        column: map['column'] as String,
        ascending: map['ascending'] as bool,
      );
    }).toList();

    final defaultDailyCapacityJson =
        json['defaultDailyCapacity'] as Map<String, dynamic>?;
    final defaultDailyCapacity = defaultDailyCapacityJson?.map(
      (k, v) => MapEntry(k, (v as num).toDouble()),
    );

    final dailyCapacityOverridesJson =
        json['dailyCapacityOverrides'] as Map<String, dynamic>?;
    final parsedOverrides = dailyCapacityOverridesJson?.map(
      (k, v) => MapEntry(k, (v as num).toDouble()),
    );
    final dailyCapacityOverrides = _pruneOverrides(
      parsedOverrides,
      AppClock.now,
    );

    return UserSettings(
      hoursAvailable: (json['hoursAvailable'] as num?)?.toDouble() ?? 8.0,
      showLastSpawnedDate: json['showLastSpawnedDate'] as bool? ?? false,
      taskListSort: taskListSort,
      scheduleListSort: scheduleListSort,
      defaultDailyCapacity: defaultDailyCapacity,
      dailyCapacityOverrides: dailyCapacityOverrides,
      lastCapacityConfirmedWeek: json['lastCapacityConfirmedWeek'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final prunedOverrides = _pruneOverrides(
      dailyCapacityOverrides,
      AppClock.now,
    );
    return {
      'hoursAvailable': hoursAvailable,
      'showLastSpawnedDate': showLastSpawnedDate,
      if (taskListSort != null)
        'taskListSort': taskListSort!
            .map((e) => {'column': e.column, 'ascending': e.ascending})
            .toList(),
      if (scheduleListSort != null)
        'scheduleListSort': scheduleListSort!
            .map((e) => {'column': e.column, 'ascending': e.ascending})
            .toList(),
      if (defaultDailyCapacity != null)
        'defaultDailyCapacity': defaultDailyCapacity,
      if (prunedOverrides != null) 'dailyCapacityOverrides': prunedOverrides,
      if (lastCapacityConfirmedWeek != null)
        'lastCapacityConfirmedWeek': lastCapacityConfirmedWeek,
    };
  }

  UserSettings copyWith({
    double? hoursAvailable,
    bool? showLastSpawnedDate,
    List<({String column, bool ascending})>? taskListSort,
    List<({String column, bool ascending})>? scheduleListSort,
    Map<String, double>? defaultDailyCapacity,
    Map<String, double>? dailyCapacityOverrides,
    String? lastCapacityConfirmedWeek,
  }) {
    return UserSettings(
      hoursAvailable: hoursAvailable ?? this.hoursAvailable,
      showLastSpawnedDate: showLastSpawnedDate ?? this.showLastSpawnedDate,
      taskListSort: taskListSort ?? this.taskListSort,
      scheduleListSort: scheduleListSort ?? this.scheduleListSort,
      defaultDailyCapacity: defaultDailyCapacity ?? this.defaultDailyCapacity,
      dailyCapacityOverrides: _pruneOverrides(
        dailyCapacityOverrides ?? this.dailyCapacityOverrides,
        AppClock.now,
      ),
      lastCapacityConfirmedWeek:
          lastCapacityConfirmedWeek ?? this.lastCapacityConfirmedWeek,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! UserSettings) return false;
    if (runtimeType != other.runtimeType) return false;
    return hoursAvailable == other.hoursAvailable &&
        showLastSpawnedDate == other.showLastSpawnedDate &&
        listEquals(taskListSort, other.taskListSort) &&
        listEquals(scheduleListSort, other.scheduleListSort) &&
        mapEquals(defaultDailyCapacity, other.defaultDailyCapacity) &&
        mapEquals(dailyCapacityOverrides, other.dailyCapacityOverrides) &&
        lastCapacityConfirmedWeek == other.lastCapacityConfirmedWeek;
  }

  @override
  int get hashCode => Object.hash(
    hoursAvailable,
    showLastSpawnedDate,
    taskListSort != null ? Object.hashAll(taskListSort!) : null,
    scheduleListSort != null ? Object.hashAll(scheduleListSort!) : null,
    defaultDailyCapacity?.hashCode,
    dailyCapacityOverrides?.hashCode,
    lastCapacityConfirmedWeek,
  );
}
