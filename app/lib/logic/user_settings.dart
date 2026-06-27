import 'package:flutter/foundation.dart';

class UserSettings {
  final double hoursAvailable;
  final bool showPendingTasks;
  final bool showLastSpawnedDate;
  final int futureInstancesCount;
  final List<({String column, bool ascending})>? taskListSort;
  final List<({String column, bool ascending})>? scheduleListSort;

  const UserSettings({
    required this.hoursAvailable,
    this.showPendingTasks = false,
    this.showLastSpawnedDate = false,
    this.futureInstancesCount = 1,
    this.taskListSort,
    this.scheduleListSort,
  });

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

    return UserSettings(
      hoursAvailable: (json['hoursAvailable'] as num?)?.toDouble() ?? 8.0,
      showPendingTasks: json['showPendingTasks'] as bool? ?? false,
      showLastSpawnedDate: json['showLastSpawnedDate'] as bool? ?? false,
      futureInstancesCount: json['futureInstancesCount'] as int? ?? 1,
      taskListSort: taskListSort,
      scheduleListSort: scheduleListSort,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hoursAvailable': hoursAvailable,
      'showPendingTasks': showPendingTasks,
      'showLastSpawnedDate': showLastSpawnedDate,
      'futureInstancesCount': futureInstancesCount,
      if (taskListSort != null)
        'taskListSort': taskListSort!
            .map((e) => {'column': e.column, 'ascending': e.ascending})
            .toList(),
      if (scheduleListSort != null)
        'scheduleListSort': scheduleListSort!
            .map((e) => {'column': e.column, 'ascending': e.ascending})
            .toList(),
    };
  }

  UserSettings copyWith({
    double? hoursAvailable,
    bool? showPendingTasks,
    bool? showLastSpawnedDate,
    int? futureInstancesCount,
    List<({String column, bool ascending})>? taskListSort,
    List<({String column, bool ascending})>? scheduleListSort,
  }) {
    return UserSettings(
      hoursAvailable: hoursAvailable ?? this.hoursAvailable,
      showPendingTasks: showPendingTasks ?? this.showPendingTasks,
      showLastSpawnedDate: showLastSpawnedDate ?? this.showLastSpawnedDate,
      futureInstancesCount: futureInstancesCount ?? this.futureInstancesCount,
      taskListSort: taskListSort ?? this.taskListSort,
      scheduleListSort: scheduleListSort ?? this.scheduleListSort,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! UserSettings) return false;
    if (runtimeType != other.runtimeType) return false;
    return hoursAvailable == other.hoursAvailable &&
        showPendingTasks == other.showPendingTasks &&
        showLastSpawnedDate == other.showLastSpawnedDate &&
        futureInstancesCount == other.futureInstancesCount &&
        listEquals(taskListSort, other.taskListSort) &&
        listEquals(scheduleListSort, other.scheduleListSort);
  }

  @override
  int get hashCode => Object.hash(
    hoursAvailable,
    showPendingTasks,
    showLastSpawnedDate,
    futureInstancesCount,
    taskListSort != null ? Object.hashAll(taskListSort!) : null,
    scheduleListSort != null ? Object.hashAll(scheduleListSort!) : null,
  );
}
