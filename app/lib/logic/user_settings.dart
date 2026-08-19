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
  final bool showTaskListSortBar;
  final bool showScheduleListSortBar;
  final bool telemetryEnabled;
  final bool crashReportingEnabled;

  const UserSettings({
    required this.hoursAvailable,
    this.showLastSpawnedDate = false,
    this.taskListSort,
    this.scheduleListSort,
    this.defaultDailyCapacity,
    this.dailyCapacityOverrides,
    this.lastCapacityConfirmedWeek,
    this.showTaskListSortBar = true,
    this.showScheduleListSortBar = true,
    this.telemetryEnabled = true,
    this.crashReportingEnabled = true,
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
      final map = Map<String, dynamic>.from(e as Map);
      return (
        column: map['column'] as String,
        ascending: map['ascending'] as bool,
      );
    }).toList();

    final scheduleListSortJson = json['scheduleListSort'] as List<dynamic>?;
    final scheduleListSort = scheduleListSortJson?.map((e) {
      final map = Map<String, dynamic>.from(e as Map);
      return (
        column: map['column'] as String,
        ascending: map['ascending'] as bool,
      );
    }).toList();

    final defaultDailyCapacityRaw = json['defaultDailyCapacity'] as Map?;
    final defaultDailyCapacity = defaultDailyCapacityRaw != null
        ? Map<String, dynamic>.from(
            defaultDailyCapacityRaw,
          ).map((k, v) => MapEntry(k.toString(), (v as num).toDouble()))
        : null;

    final dailyCapacityOverridesRaw = json['dailyCapacityOverrides'] as Map?;
    final parsedOverrides = dailyCapacityOverridesRaw != null
        ? Map<String, dynamic>.from(
            dailyCapacityOverridesRaw,
          ).map((k, v) => MapEntry(k.toString(), (v as num).toDouble()))
        : null;
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
      showTaskListSortBar: json['showTaskListSortBar'] as bool? ?? true,
      showScheduleListSortBar: json['showScheduleListSortBar'] as bool? ?? true,
      telemetryEnabled: json['telemetryEnabled'] as bool? ?? true,
      crashReportingEnabled: json['crashReportingEnabled'] as bool? ?? true,
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
      'dailyCapacityOverrides': ?prunedOverrides,
      if (lastCapacityConfirmedWeek != null)
        'lastCapacityConfirmedWeek': lastCapacityConfirmedWeek,
      'showTaskListSortBar': showTaskListSortBar,
      'showScheduleListSortBar': showScheduleListSortBar,
      'telemetryEnabled': telemetryEnabled,
      'crashReportingEnabled': crashReportingEnabled,
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
    bool? showTaskListSortBar,
    bool? showScheduleListSortBar,
    bool? telemetryEnabled,
    bool? crashReportingEnabled,
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
      showTaskListSortBar: showTaskListSortBar ?? this.showTaskListSortBar,
      showScheduleListSortBar:
          showScheduleListSortBar ?? this.showScheduleListSortBar,
      telemetryEnabled: telemetryEnabled ?? this.telemetryEnabled,
      crashReportingEnabled:
          crashReportingEnabled ?? this.crashReportingEnabled,
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
        lastCapacityConfirmedWeek == other.lastCapacityConfirmedWeek &&
        showTaskListSortBar == other.showTaskListSortBar &&
        showScheduleListSortBar == other.showScheduleListSortBar &&
        telemetryEnabled == other.telemetryEnabled &&
        crashReportingEnabled == other.crashReportingEnabled;
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
    showTaskListSortBar,
    showScheduleListSortBar,
    telemetryEnabled,
    crashReportingEnabled,
  );
}
