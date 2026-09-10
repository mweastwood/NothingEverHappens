import 'package:core/core.dart';
import 'package:meta/meta.dart';
import '../interop/firebase_admin.dart';
import '../interop/node_interop.dart';

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

/// Service that evaluates and spawns shared family tasks in Firestore using [SchedulerEngine].
class FamilySchedulerService {
  final FirestoreDatabase db;
  final SchedulerEngine engine;

  const FamilySchedulerService(
    this.db, {
    SchedulerEngine? engine,
  }) : engine = engine ??
            const SchedulerEngine(
              platform: 'cloud_functions',
              appVersion: 'backend',
            );

  /// Evaluates and applies scheduling actions for all tasks within a single [familyId].
  Future<FamilyScheduleSummary> processFamily(
    String familyId, {
    DateTime? now,
    int? futureInstancesCount,
  }) async {
    final effectiveNow = now ?? DateTime.now().toUtc();
    final familyRef = db.collection('families').doc(familyId);

    try {
      // 1. Fetch family tasks
      final tasksSnap = await familyRef.collection('tasks').get();
      final tasks = <TaskSchedule>[];
      for (final doc in tasksSnap.docs) {
        final data = doc.data();
        if (data != null) {
          tasks.add(TaskSchedule.fromMap(data, id: doc.id));
        }
      }

      if (tasks.isEmpty) {
        return FamilyScheduleSummary(
          familyId: familyId,
          tasksEvaluated: 0,
        );
      }

      // Filter tasks to only family tasks
      final familyTasks = tasks.where((t) => t.isFamily).toList();
      if (familyTasks.isEmpty) {
        return FamilyScheduleSummary(
          familyId: familyId,
          tasksEvaluated: 0,
        );
      }

      // 2. Fetch all existing instances for this family
      final instancesSnap = await familyRef.collection('instances').get();
      final instances = <TaskInstance>[];
      for (final doc in instancesSnap.docs) {
        final data = doc.data();
        if (data != null) {
          instances.add(TaskInstance.fromMap(data, id: doc.id));
        }
      }

      // Group instances by scheduleId
      final instancesByScheduleId = <String, List<TaskInstance>>{};
      for (final instance in instances) {
        instancesByScheduleId
            .putIfAbsent(instance.scheduleId, () => [])
            .add(instance);
      }

      var spawnedCount = 0;
      var updatedCount = 0;
      var deletedCount = 0;
      var schedulesUpdatedCount = 0;

      WriteBatch batch = db.batch();
      var batchOps = 0;

      Future<void> commitBatchIfNeeded() async {
        if (batchOps >= 400) {
          await batch.commit();
          batch = db.batch();
          batchOps = 0;
        }
      }

      // 3. Evaluate each family task using SchedulerEngine
      for (final task in familyTasks) {
        final taskInstances = instancesByScheduleId[task.id] ?? const [];
        final action = engine.evaluate(
          task,
          taskInstances,
          effectiveNow,
          applyCapacityLimits: false,
          userId: 'cloud_scheduler',
          futureInstancesCount: futureInstancesCount,
        );

        for (final spawned in action.instancesToSpawn) {
          final docRef = familyRef.collection('instances').doc(spawned.id);
          batch.set(docRef, spawned.toFirestore());
          batchOps++;
          spawnedCount++;
          await commitBatchIfNeeded();
        }

        for (final updated in action.instancesToUpdate) {
          final docRef = familyRef.collection('instances').doc(updated.id);
          batch.set(docRef, updated.toFirestore());
          batchOps++;
          updatedCount++;
          await commitBatchIfNeeded();
        }

        for (final deleteId in action.instancesToDelete) {
          final docRef = familyRef.collection('instances').doc(deleteId);
          batch.delete(docRef);
          batchOps++;
          deletedCount++;
          await commitBatchIfNeeded();
        }

        if (action.updatedSchedule != null) {
          final docRef = familyRef.collection('tasks').doc(task.id);
          batch.set(docRef, action.updatedSchedule!.toFirestore());
          batchOps++;
          schedulesUpdatedCount++;
          await commitBatchIfNeeded();
        }
      }

      if (batchOps > 0) {
        await batch.commit();
      }

      return FamilyScheduleSummary(
        familyId: familyId,
        tasksEvaluated: familyTasks.length,
        instancesSpawned: spawnedCount,
        instancesUpdated: updatedCount,
        instancesDeleted: deletedCount,
        schedulesUpdated: schedulesUpdatedCount,
      );
    } catch (error) {
      logError(
          'Error evaluating family schedule for familyId=$familyId:', error);
      return FamilyScheduleSummary(
        familyId: familyId,
        error: error.toString(),
      );
    }
  }

  /// Processes all families found in the `families` collection.
  Future<FamilySchedulerResult> processAllFamilies({
    DateTime? now,
    int? familyLimit,
    int? futureInstancesCount,
  }) async {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    final effectiveNow = now ?? DateTime.now().toUtc();

    Query query = db.collection('families');
    if (familyLimit != null && familyLimit > 0) {
      query = query.limit(familyLimit);
    }

    final familiesSnap = await query.get();
    final summaries = <FamilyScheduleSummary>[];

    var totalTasks = 0;
    var totalSpawned = 0;
    var totalUpdated = 0;
    var totalDeleted = 0;
    var totalSchedulesUpdated = 0;

    for (final doc in familiesSnap.docs) {
      final summary = await processFamily(
        doc.id,
        now: effectiveNow,
        futureInstancesCount: futureInstancesCount,
      );
      summaries.add(summary);

      totalTasks += summary.tasksEvaluated;
      totalSpawned += summary.instancesSpawned;
      totalUpdated += summary.instancesUpdated;
      totalDeleted += summary.instancesDeleted;
      totalSchedulesUpdated += summary.schedulesUpdated;
    }

    final durationMs = DateTime.now().millisecondsSinceEpoch - startTime;
    return FamilySchedulerResult(
      success: true,
      familiesProcessed: summaries.length,
      totalTasksEvaluated: totalTasks,
      totalInstancesSpawned: totalSpawned,
      totalInstancesUpdated: totalUpdated,
      totalInstancesDeleted: totalDeleted,
      totalSchedulesUpdated: totalSchedulesUpdated,
      durationMs: durationMs,
      familySummaries: summaries,
    );
  }
}
