import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nothing_ever_happens/logic/app_logger.dart';
import 'package:nothing_ever_happens/logic/firestore_paths.dart';
import 'package:nothing_ever_happens/logic/hive_local_data_source.dart';
import 'package:nothing_ever_happens/logic/recipes/recipe.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_sync_conflict_resolver.dart';

/// Reconciles incoming Firestore [QuerySnapshot] diffs for tasks, instances, and recipes
/// against [HiveLocalDataSource].
class RemoteSnapshotReconciler {
  final FirebaseFirestore _firestore;
  final HiveLocalDataSource _localDataSource;
  final String _userId;
  final Future<String?> Function() _getFamilyId;
  final Future<bool> Function() _isFamilyParent;
  final Future<bool> Function(TaskSchedule task) _pushTaskToRemote;
  final Future<bool> Function(TaskInstance inst) _pushInstanceToRemote;
  final AppLogger? _logger;

  const RemoteSnapshotReconciler({
    required FirebaseFirestore firestore,
    required HiveLocalDataSource localDataSource,
    required String userId,
    required Future<String?> Function() getFamilyId,
    required Future<bool> Function() isFamilyParent,
    required Future<bool> Function(TaskSchedule task) pushTaskToRemote,
    required Future<bool> Function(TaskInstance inst) pushInstanceToRemote,
    AppLogger? logger,
  }) : _firestore = firestore,
       _localDataSource = localDataSource,
       _userId = userId,
       _getFamilyId = getFamilyId,
       _isFamilyParent = isFamilyParent,
       _pushTaskToRemote = pushTaskToRemote,
       _pushInstanceToRemote = pushInstanceToRemote,
       _logger = logger;

  Future<void> handleRemoteTasksSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    required bool isFamily,
  }) async {
    final isCache = snapshot.metadata.isFromCache;
    final localTasks = _localDataSource.getTasks();
    final localMap = {for (final t in localTasks) t.id: t};

    final toSave = <TaskSchedule>[];
    final toDelete = <String>[];
    final toPush = <TaskSchedule>[];

    for (final change in snapshot.docChanges) {
      final docId = change.doc.id;
      if (change.type == DocumentChangeType.removed) {
        final localTask = localMap[docId];
        if (localTask == null ||
            (isFamily ? localTask.isFamily : !localTask.isFamily)) {
          toDelete.add(docId);
          localMap.remove(docId);
        }
      } else if (change.type == DocumentChangeType.added ||
          change.type == DocumentChangeType.modified) {
        if (change.doc.data() != null) {
          final remoteTask = TaskSchedule.fromFirestore(change.doc);
          final localTask = localMap[remoteTask.id];

          if (localTask != null) {
            if (TaskSyncConflictResolver.isStrictlyNewer(
              localTask.updatedAt,
              remoteTask.updatedAt,
            )) {
              toPush.add(localTask);
            } else {
              toSave.add(remoteTask);
              localMap[remoteTask.id] = remoteTask;
            }
          } else {
            toSave.add(remoteTask);
            localMap[remoteTask.id] = remoteTask;
          }
        }
      }
    }

    if (!isCache) {
      for (final localTask in localMap.values) {
        if ((isFamily ? localTask.isFamily : !localTask.isFamily) &&
            localTask.isFromCache) {
          final updated = localTask.copyWith(isFromCache: false);
          toSave.add(updated);
          localMap[localTask.id] = updated;
        }
      }
    }

    if (toDelete.isNotEmpty) {
      await _localDataSource.deleteTasks(toDelete);
      await _localDataSource.clearDirtyBatch(toDelete);
    }
    if (toSave.isNotEmpty) {
      await _localDataSource.saveTasks(toSave);
      await _localDataSource.clearDirtyBatch(toSave.map((t) => t.id).toList());
    }

    final pushedTaskIds = <String>{};
    for (final task in toPush) {
      if (!pushedTaskIds.add(task.id)) continue;
      await _localDataSource.markDirty(task.id);
      try {
        final canClearDirty = await _pushTaskToRemote(task);
        if (canClearDirty) {
          await _localDataSource.clearDirty(task.id);
        }
      } catch (e, st) {
        // Keep dirty flag so the next sync retries pushing this task.
        _logger?.error(
          'sync',
          'Failed to push task ${task.id} to remote',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  Future<void> handleRemoteInstancesSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    required bool isFamily,
  }) async {
    final isCache = snapshot.metadata.isFromCache;
    final localInsts = _localDataSource.getInstances();
    final localMap = {for (final inst in localInsts) inst.id: inst};
    final localSlotMap = {
      for (final inst in localInsts)
        '${inst.scheduleId}_${inst.ruleId}_${inst.scheduledDate}_${inst.workflowPayload?.stage.name ?? ""}':
            inst,
    };

    final toSave = <TaskInstance>[];
    final toDelete = <String>[];
    final toPush = <TaskInstance>[];
    final remoteIdsToDelete = <String>[];
    final remoteIdsInSnapshot = {for (final doc in snapshot.docs) doc.id};

    final familyId = await _getFamilyId();

    for (final change in snapshot.docChanges) {
      final docId = change.doc.id;
      if (change.type == DocumentChangeType.removed) {
        final localInst = localMap[docId];
        if (localInst == null ||
            (isFamily ? localInst.isFamily : !localInst.isFamily)) {
          toDelete.add(docId);
          localMap.remove(docId);
          toSave.removeWhere((i) => i.id == docId);
          toPush.removeWhere((i) => i.id == docId);
          if (localInst != null) {
            final slotKey =
                '${localInst.scheduleId}_${localInst.ruleId}_${localInst.scheduledDate}_${localInst.workflowPayload?.stage.name ?? ""}';
            if (localSlotMap[slotKey]?.id == docId) {
              localSlotMap.remove(slotKey);
            }
          } else {
            localSlotMap.removeWhere((_, v) => v.id == docId);
          }
          _logger?.info(
            'sync',
            'Remote instance removed: $docId',
            data: {'instanceId': docId, 'isFamily': isFamily},
          );
        }
      } else if (change.type == DocumentChangeType.added ||
          change.type == DocumentChangeType.modified) {
        if (change.doc.data() != null) {
          final remoteInst = TaskInstance.fromFirestore(change.doc);
          final localInst = localMap[remoteInst.id];

          final oldStatus = localInst?.status.name;
          final newStatus = remoteInst.status.name;
          final statusChanged = localInst != null && oldStatus != newStatus;

          _logger?.info(
            'sync',
            'Remote instance ${change.type == DocumentChangeType.added ? "added" : "modified"}: "${remoteInst.title}" (${remoteInst.scheduledDate})',
            data: {
              'instanceId': remoteInst.id,
              'scheduleId': remoteInst.scheduleId,
              'date': remoteInst.scheduledDate.toString(),
              if (statusChanged) 'statusChange': '$oldStatus -> $newStatus',
              'status': newStatus,
              if (remoteInst.statusReason != null)
                'statusReason': remoteInst.statusReason,
              if (remoteInst.lastModifiedByUserId != null)
                'modifiedByUserId': remoteInst.lastModifiedByUserId,
              if (remoteInst.lastModifiedByAppVersion != null)
                'modifiedByAppVersion': remoteInst.lastModifiedByAppVersion,
              if (remoteInst.lastModifiedByPlatform != null)
                'modifiedByPlatform': remoteInst.lastModifiedByPlatform,
              'isFamily': isFamily,
            },
          );

          if (localInst != null) {
            if (TaskSyncConflictResolver.doesLocalWin(localInst, remoteInst)) {
              toPush.add(localInst);
            } else {
              toSave.add(remoteInst);
              localMap[remoteInst.id] = remoteInst;
              localSlotMap['${remoteInst.scheduleId}_${remoteInst.ruleId}_${remoteInst.scheduledDate}_${remoteInst.workflowPayload?.stage.name ?? ""}'] =
                  remoteInst;
            }
          } else {
            final slotKey =
                '${remoteInst.scheduleId}_${remoteInst.ruleId}_${remoteInst.scheduledDate}_${remoteInst.workflowPayload?.stage.name ?? ""}';
            final localSlotInst = localSlotMap[slotKey];
            if (localSlotInst != null) {
              if (TaskSyncConflictResolver.doesSlotCandidateWin(
                localSlotInst,
                remoteInst,
              )) {
                toPush.add(localSlotInst);
                remoteIdsToDelete.add(remoteInst.id);
              } else {
                toDelete.add(localSlotInst.id);
                if (remoteIdsInSnapshot.contains(localSlotInst.id)) {
                  remoteIdsToDelete.add(localSlotInst.id);
                }
                localMap.remove(localSlotInst.id);
                toSave.removeWhere((i) => i.id == localSlotInst.id);
                toPush.removeWhere((i) => i.id == localSlotInst.id);
                toSave.add(remoteInst);
                localMap[remoteInst.id] = remoteInst;
                localSlotMap[slotKey] = remoteInst;
              }
            } else {
              toSave.add(remoteInst);
              localMap[remoteInst.id] = remoteInst;
              localSlotMap[slotKey] = remoteInst;
            }
          }
        }
      }
    }

    if (!isCache) {
      for (final localInst in localMap.values) {
        if ((isFamily ? localInst.isFamily : !localInst.isFamily) &&
            localInst.isFromCache) {
          final updated = localInst.copyWith(isFromCache: false);
          toSave.add(updated);
          localMap[localInst.id] = updated;
        }
      }
    }

    if (toDelete.isNotEmpty) {
      await _localDataSource.deleteInstances(toDelete);
      await _localDataSource.clearDirtyBatch(toDelete);
    }
    if (toSave.isNotEmpty) {
      await _localDataSource.saveInstances(toSave);
      await _localDataSource.clearDirtyBatch(toSave.map((i) => i.id).toList());
    }

    final pushedInstIds = <String>{};
    for (final inst in toPush) {
      if (!pushedInstIds.add(inst.id)) continue;
      await _localDataSource.markDirty(inst.id);
      try {
        final canClearDirty = await _pushInstanceToRemote(inst);
        if (canClearDirty) {
          await _localDataSource.clearDirty(inst.id);
        }
      } catch (e, st) {
        // Keep dirty flag so the next sync retries pushing this instance.
        _logger?.error(
          'sync',
          'Failed to push instance ${inst.id} to remote',
          error: e,
          stackTrace: st,
        );
      }
    }
    for (final remId in remoteIdsToDelete) {
      if (isFamily) {
        if (familyId != null && familyId.isNotEmpty) {
          final isParent = await _isFamilyParent();
          if (isParent) {
            try {
              await _firestore
                  .collection(FirestorePaths.families)
                  .doc(familyId)
                  .collection(FirestorePaths.instances)
                  .doc(remId)
                  .delete();
            } catch (e) {
              _logger?.warning(
                'sync',
                'Failed to delete remote family duplicate $remId: $e',
              );
            }
          }
        }
      } else {
        await _firestore
            .collection(FirestorePaths.users)
            .doc(_userId)
            .collection(FirestorePaths.instances)
            .doc(remId)
            .delete();
      }
    }
  }

  Future<void> handleRemoteRecipesSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    required bool isFamily,
  }) async {
    final isCache = snapshot.metadata.isFromCache;
    final localRecipes = _localDataSource.getRecipes();
    final localMap = {for (final r in localRecipes) r.id: r};

    final toSave = <Recipe>[];
    final toDelete = <String>[];

    for (final change in snapshot.docChanges) {
      final docId = change.doc.id;
      if (change.type == DocumentChangeType.removed) {
        final localRecipe = localMap[docId];
        if (localRecipe == null ||
            (isFamily ? localRecipe.isFamily : !localRecipe.isFamily)) {
          toDelete.add(docId);
          localMap.remove(docId);
        }
      } else if (change.type == DocumentChangeType.added ||
          change.type == DocumentChangeType.modified) {
        if (change.doc.data() != null) {
          final remoteRecipe = Recipe.fromFirestore(change.doc);
          final localRecipe = localMap[remoteRecipe.id];
          if (localRecipe == null ||
              remoteRecipe.updatedAt.isAfter(localRecipe.updatedAt)) {
            final cleanRecipe = remoteRecipe.copyWith(
              hasPendingWrites: false,
              isFromCache: isCache,
            );
            toSave.add(cleanRecipe);
            localMap[cleanRecipe.id] = cleanRecipe;
          }
        }
      }
    }

    if (!isCache) {
      for (final localRecipe in localMap.values) {
        if ((isFamily ? localRecipe.isFamily : !localRecipe.isFamily) &&
            localRecipe.isFromCache) {
          final updated = localRecipe.copyWith(isFromCache: false);
          toSave.add(updated);
          localMap[localRecipe.id] = updated;
        }
      }
    }

    if (toDelete.isNotEmpty) {
      await _localDataSource.deleteRecipes(toDelete);
    }
    if (toSave.isNotEmpty) {
      await _localDataSource.saveRecipes(toSave);
    }
  }
}
