import 'package:meta/meta.dart';

/// Summary of schedule evaluation for a single family.
@immutable
class FamilyScheduleSummary {
  final String familyId;
  final int tasksEvaluated;
  final int instancesSpawned;
  final int instancesUpdated;
  final int instancesDeleted;
  final int schedulesUpdated;
  final String? error;

  const FamilyScheduleSummary({
    required this.familyId,
    this.tasksEvaluated = 0,
    this.instancesSpawned = 0,
    this.instancesUpdated = 0,
    this.instancesDeleted = 0,
    this.schedulesUpdated = 0,
    this.error,
  });

  Map<String, dynamic> toJson() => {
        'familyId': familyId,
        'tasksEvaluated': tasksEvaluated,
        'instancesSpawned': instancesSpawned,
        'instancesUpdated': instancesUpdated,
        'instancesDeleted': instancesDeleted,
        'schedulesUpdated': schedulesUpdated,
        if (error != null) 'error': error,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FamilyScheduleSummary &&
        other.familyId == familyId &&
        other.tasksEvaluated == tasksEvaluated &&
        other.instancesSpawned == instancesSpawned &&
        other.instancesUpdated == instancesUpdated &&
        other.instancesDeleted == instancesDeleted &&
        other.schedulesUpdated == schedulesUpdated &&
        other.error == error;
  }

  @override
  int get hashCode => Object.hash(
        familyId,
        tasksEvaluated,
        instancesSpawned,
        instancesUpdated,
        instancesDeleted,
        schedulesUpdated,
        error,
      );
}

/// Aggregated result of processing family scheduling across multiple families.
@immutable
class FamilySchedulerResult {
  final bool success;
  final int familiesProcessed;
  final int totalTasksEvaluated;
  final int totalInstancesSpawned;
  final int totalInstancesUpdated;
  final int totalInstancesDeleted;
  final int totalSchedulesUpdated;
  final int durationMs;
  final List<FamilyScheduleSummary> familySummaries;

  const FamilySchedulerResult({
    required this.success,
    required this.familiesProcessed,
    required this.totalTasksEvaluated,
    required this.totalInstancesSpawned,
    required this.totalInstancesUpdated,
    required this.totalInstancesDeleted,
    required this.totalSchedulesUpdated,
    required this.durationMs,
    required this.familySummaries,
  });

  Map<String, dynamic> toJson() => {
        'success': success,
        'familiesProcessed': familiesProcessed,
        'totalTasksEvaluated': totalTasksEvaluated,
        'totalInstancesSpawned': totalInstancesSpawned,
        'totalInstancesUpdated': totalInstancesUpdated,
        'totalInstancesDeleted': totalInstancesDeleted,
        'totalSchedulesUpdated': totalSchedulesUpdated,
        'durationMs': durationMs,
        'familySummaries': familySummaries.map((s) => s.toJson()).toList(),
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FamilySchedulerResult &&
        other.success == success &&
        other.familiesProcessed == familiesProcessed &&
        other.totalTasksEvaluated == totalTasksEvaluated &&
        other.totalInstancesSpawned == totalInstancesSpawned &&
        other.totalInstancesUpdated == totalInstancesUpdated &&
        other.totalInstancesDeleted == totalInstancesDeleted &&
        other.totalSchedulesUpdated == totalSchedulesUpdated &&
        other.durationMs == durationMs;
  }

  @override
  int get hashCode => Object.hash(
        success,
        familiesProcessed,
        totalTasksEvaluated,
        totalInstancesSpawned,
        totalInstancesUpdated,
        totalInstancesDeleted,
        totalSchedulesUpdated,
        durationMs,
      );
}
