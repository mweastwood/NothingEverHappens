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

  bool Function(String id) _createLazyDirtyChecker() {
    Set<String>? dirtyIds;
    return (String id) =>
        (dirtyIds ??= _localDataSource.getDirtyTaskIds().toSet()).contains(id);
  }

  static bool _matchesSnapshotScope(bool? itemIsFamily, bool snapshotIsFamily) {
    if (itemIsFamily == null) return true;
    return snapshotIsFamily ? itemIsFamily : !itemIsFamily;
  }

  static void _clearStaleCacheFlags<T>({
    required bool isCache,
    required bool isFamily,
    required Map<String, T> localMap,
    required List<T> toSave,
    required bool Function(String id) isDirty,
    required Set<String> excludedIds,
    required String Function(T item) getId,
    required bool Function(T item) getIsFamily,
    required bool Function(T item) getIsFromCache,
    required bool Function(T item) getHasPendingWrites,
    required T Function(T item) clearCacheFlag,
  }) {
    if (isCache || localMap.isEmpty) return;
    for (final localItem in localMap.values) {
      final id = getId(localItem);
      if (_matchesSnapshotScope(getIsFamily(localItem), isFamily) &&
          getIsFromCache(localItem) &&
          !getHasPendingWrites(localItem) &&
          !isDirty(id) &&
          !excludedIds.contains(id)) {
        final updated = clearCacheFlag(localItem);
        toSave.add(updated);
        localMap[id] = updated;
      }
    }
  }

  Future<void> _applyBatchLocalUpdates<T>({
    required List<String> toDelete,
    required List<T> toSave,
    required Iterable<String> dirtyIdsToClear,
    required Future<void> Function(List<String> ids) deleteBatch,
    required Future<void> Function(List<T> items) saveBatch,
    bool clearDeletedDirtyIds = true,
  }) async {
    if (toDelete.isNotEmpty) {
      await deleteBatch(toDelete);
      if (clearDeletedDirtyIds) {
        await _localDataSource.clearDirtyBatch(toDelete);
      }
    }
    if (toSave.isNotEmpty) {
      await saveBatch(toSave);
    }
    if (dirtyIdsToClear.isNotEmpty) {
      await _localDataSource.clearDirtyBatch(dirtyIdsToClear.toList());
    }
  }

  Future<void> _pushLocalWinners<T>({
    required List<T> toPush,
    required String Function(T item) getId,
    required Future<bool> Function(T item) pushToRemote,
    required String entityLabel,
  }) async {
    final pushedIds = <String>{};
    for (final item in toPush) {
      final id = getId(item);
      if (!pushedIds.add(id)) continue;
      await _localDataSource.markDirty(id);
      try {
        final canClearDirty = await pushToRemote(item);
        if (canClearDirty) {
          await _localDataSource.clearDirty(id);
        }
      } catch (e, st) {
        // Keep dirty flag so the next sync retries pushing this item.
        _logger?.error(
          'sync',
          'Failed to push $entityLabel $id to remote',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  Future<void> handleRemoteTasksSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    required bool isFamily,
  }) async {
    final isCache = snapshot.metadata.isFromCache;
    final localTasks = _localDataSource.getTasks();
    final localMap = {for (final t in localTasks) t.id: t};
    final isDirty = _createLazyDirtyChecker();

    final toSave = <TaskSchedule>[];
    final remoteSavedIds = <String>{};
    final toDelete = <String>[];
    final toPush = <TaskSchedule>[];

    for (final change in snapshot.docChanges) {
      final docId = change.doc.id;
      if (change.type == DocumentChangeType.removed) {
        final localTask = localMap[docId];
        if (_matchesSnapshotScope(localTask?.isFamily, isFamily)) {
          toDelete.add(docId);
          localMap.remove(docId);
          toSave.removeWhere((t) => t.id == docId);
          remoteSavedIds.remove(docId);
          toPush.removeWhere((t) => t.id == docId);
        }
      } else if (change.type == DocumentChangeType.added ||
          change.type == DocumentChangeType.modified) {
        if (change.doc.data() != null) {
          final remoteTask = TaskSchedule.fromFirestore(change.doc);
          final localTask = localMap[remoteTask.id];
          if (localTask == null && isDirty(remoteTask.id)) {
            continue;
          }

          if (localTask != null) {
            if (TaskSyncConflictResolver.isStrictlyNewer(
              localTask.updatedAt,
              remoteTask.updatedAt,
            )) {
              toPush.add(localTask);
            } else {
              toSave.add(remoteTask);
              remoteSavedIds.add(remoteTask.id);
              localMap[remoteTask.id] = remoteTask;
            }
          } else {
            toSave.add(remoteTask);
            remoteSavedIds.add(remoteTask.id);
            localMap[remoteTask.id] = remoteTask;
          }
        }
      }
    }

    _clearStaleCacheFlags<TaskSchedule>(
      isCache: isCache,
      isFamily: isFamily,
      localMap: localMap,
      toSave: toSave,
      isDirty: isDirty,
      excludedIds: {for (final t in toPush) t.id},
      getId: (t) => t.id,
      getIsFamily: (t) => t.isFamily,
      getIsFromCache: (t) => t.isFromCache,
      getHasPendingWrites: (t) => t.hasPendingWrites,
      clearCacheFlag: (t) => t.copyWith(isFromCache: false),
    );

    await _applyBatchLocalUpdates<TaskSchedule>(
      toDelete: toDelete,
      toSave: toSave,
      dirtyIdsToClear: remoteSavedIds,
      deleteBatch: _localDataSource.deleteTasks,
      saveBatch: _localDataSource.saveTasks,
    );

    await _pushLocalWinners<TaskSchedule>(
      toPush: toPush,
      getId: (t) => t.id,
      pushToRemote: _pushTaskToRemote,
      entityLabel: 'task',
    );
  }

  Future<void> handleRemoteInstancesSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    required bool isFamily,
  }) async {
    final isCache = snapshot.metadata.isFromCache;
    final localInsts = _localDataSource.getInstances();
    final localMap = {for (final inst in localInsts) inst.id: inst};
    final isDirty = _createLazyDirtyChecker();
    final localSlotMap = {
      for (final inst in localInsts)
        '${inst.scheduleId}_${inst.ruleId}_${inst.scheduledDate}_${inst.workflowPayload?.stage.name ?? ""}':
            inst,
    };

    final toSave = <TaskInstance>[];
    final remoteSavedIds = <String>{};
    final toDelete = <String>[];
    final toPush = <TaskInstance>[];
    final remoteIdsToDelete = <String>[];
    final remoteIdsInSnapshot = {for (final doc in snapshot.docs) doc.id};

    final familyId = await _getFamilyId();

    for (final change in snapshot.docChanges) {
      final docId = change.doc.id;
      if (change.type == DocumentChangeType.removed) {
        final localInst = localMap[docId];
        if (_matchesSnapshotScope(localInst?.isFamily, isFamily)) {
          toDelete.add(docId);
          localMap.remove(docId);
          toSave.removeWhere((i) => i.id == docId);
          remoteSavedIds.remove(docId);
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
          if (localInst == null && isDirty(remoteInst.id)) {
            continue;
          }

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
              remoteSavedIds.add(remoteInst.id);
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
                remoteSavedIds.remove(localSlotInst.id);
                toPush.removeWhere((i) => i.id == localSlotInst.id);
                toSave.add(remoteInst);
                remoteSavedIds.add(remoteInst.id);
                localMap[remoteInst.id] = remoteInst;
                localSlotMap[slotKey] = remoteInst;
              }
            } else {
              toSave.add(remoteInst);
              remoteSavedIds.add(remoteInst.id);
              localMap[remoteInst.id] = remoteInst;
              localSlotMap[slotKey] = remoteInst;
            }
          }
        }
      }
    }

    _clearStaleCacheFlags<TaskInstance>(
      isCache: isCache,
      isFamily: isFamily,
      localMap: localMap,
      toSave: toSave,
      isDirty: isDirty,
      excludedIds: {for (final i in toPush) i.id},
      getId: (i) => i.id,
      getIsFamily: (i) => i.isFamily,
      getIsFromCache: (i) => i.isFromCache,
      getHasPendingWrites: (i) => i.hasPendingWrites,
      clearCacheFlag: (i) => i.copyWith(isFromCache: false),
    );

    await _applyBatchLocalUpdates<TaskInstance>(
      toDelete: toDelete,
      toSave: toSave,
      dirtyIdsToClear: remoteSavedIds,
      deleteBatch: _localDataSource.deleteInstances,
      saveBatch: _localDataSource.saveInstances,
    );

    await _pushLocalWinners<TaskInstance>(
      toPush: toPush,
      getId: (i) => i.id,
      pushToRemote: _pushInstanceToRemote,
      entityLabel: 'instance',
    );
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
    final isDirty = _createLazyDirtyChecker();

    final toSave = <Recipe>[];
    final toDelete = <String>[];
    final toClearDirty = <String>[];
    final toMarkDirty = <String>{};

    for (final change in snapshot.docChanges) {
      final docId = change.doc.id;
      if (change.type == DocumentChangeType.removed) {
        final localRecipe = localMap[docId];
        if (localRecipe != null &&
            (localRecipe.hasPendingWrites || isDirty(localRecipe.id))) {
          continue;
        }
        if (_matchesSnapshotScope(localRecipe?.isFamily, isFamily)) {
          toDelete.add(docId);
          toClearDirty.add(docId);
          localMap.remove(docId);
        }
      } else if (change.type == DocumentChangeType.added ||
          change.type == DocumentChangeType.modified) {
        if (change.doc.data() != null) {
          final remoteRecipe = Recipe.fromFirestore(change.doc);
          final localRecipe = localMap[remoteRecipe.id];
          if (localRecipe == null && isDirty(remoteRecipe.id)) {
            continue;
          }
          if (localRecipe != null &&
              (localRecipe.hasPendingWrites || isDirty(localRecipe.id)) &&
              (isCache ||
                  !remoteRecipe.updatedAt.isAfter(localRecipe.updatedAt))) {
            if (!isCache && !isDirty(localRecipe.id)) {
              toMarkDirty.add(localRecipe.id);
            }
            continue;
          }
          if (localRecipe == null ||
              remoteRecipe.updatedAt.isAfter(localRecipe.updatedAt)) {
            final cleanRecipe = remoteRecipe.copyWith(
              hasPendingWrites: false,
              isFromCache: isCache,
            );
            toSave.add(cleanRecipe);
            if (!isCache) {
              toClearDirty.add(cleanRecipe.id);
            }
            localMap[cleanRecipe.id] = cleanRecipe;
          } else if (localRecipe.updatedAt.isAfter(remoteRecipe.updatedAt) &&
              !isCache &&
              !isDirty(localRecipe.id)) {
            toMarkDirty.add(localRecipe.id);
          }
        }
      }
    }

    _clearStaleCacheFlags<Recipe>(
      isCache: isCache,
      isFamily: isFamily,
      localMap: localMap,
      toSave: toSave,
      isDirty: isDirty,
      excludedIds: toMarkDirty,
      getId: (r) => r.id,
      getIsFamily: (r) => r.isFamily,
      getIsFromCache: (r) => r.isFromCache,
      getHasPendingWrites: (r) => r.hasPendingWrites,
      clearCacheFlag: (r) => r.copyWith(isFromCache: false),
    );

    await _applyBatchLocalUpdates<Recipe>(
      toDelete: toDelete,
      toSave: toSave,
      dirtyIdsToClear: toClearDirty,
      deleteBatch: _localDataSource.deleteRecipes,
      saveBatch: _localDataSource.saveRecipes,
      clearDeletedDirtyIds: false,
    );
    for (final id in toMarkDirty) {
      await _localDataSource.markDirty(id);
    }
  }
}
