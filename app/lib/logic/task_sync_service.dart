import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:nothing_ever_happens/logic/hive_local_data_source.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nothing_ever_happens/logic/subscription_service.dart';
import 'package:nothing_ever_happens/logic/auth_repository.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/error_handler.dart';
import 'package:nothing_ever_happens/logic/app_logger.dart';
import 'package:nothing_ever_happens/logic/utils/app_version.dart';
import 'package:rxdart/rxdart.dart';

import 'package:nothing_ever_happens/logic/recipes/recipe.dart';

final taskSyncServiceProvider = Provider<TaskSyncService>((ref) {
  final firestore = ref.watch(firestoreProvider) ?? FirebaseFirestore.instance;
  final localDataSource = ref.watch(hiveLocalDataSourceProvider);
  final user = ref.watch(authStateProvider).value;
  final subscriptionState = ref.watch(subscriptionServiceProvider);

  final service = TaskSyncService(
    firestore: firestore,
    localDataSource: localDataSource,
    userId: user?.uid ?? '',
    isActivePremium: subscriptionState.isActivePremium,
    errorHandler: ref.read(errorHandlerProvider),
    logger: ref.watch(appLoggerProvider),
  );

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

final isSyncingProvider = StreamProvider<bool>((ref) {
  final syncService = ref.watch(taskSyncServiceProvider);
  return syncService.isSyncingStream;
});

class TaskSyncService {
  final FirebaseFirestore _firestore;
  final HiveLocalDataSource _localDataSource;
  final String _userId;
  final bool _isActivePremium;
  final ErrorHandler? errorHandler;
  final AppLogger? logger;

  StreamSubscription? _tasksSub;
  StreamSubscription? _instancesSub;
  StreamSubscription? _recipesSub;
  StreamSubscription? _userDocSub;
  StreamSubscription? _familyTasksSub;
  StreamSubscription? _familyInstancesSub;
  StreamSubscription? _familyRecipesSub;
  String? _familyId;

  bool _isSyncing = false;
  final _isSyncingSubject = BehaviorSubject<bool>.seeded(false);
  Stream<bool> get isSyncingStream => _isSyncingSubject.stream;
  Timer? _periodicSyncTimer;

  TaskSyncService({
    required FirebaseFirestore firestore,
    required HiveLocalDataSource localDataSource,
    required String userId,
    required bool isActivePremium,
    this.errorHandler,
    this.logger,
  }) : _firestore = firestore,
       _localDataSource = localDataSource,
       _userId = userId,
       _isActivePremium = isActivePremium {
    if (_isActivePremium &&
        _userId.isNotEmpty &&
        _localDataSource.isMigrationCompleted()) {
      startListeningToRemote();
    }
  }

  void dispose() {
    _periodicSyncTimer?.cancel();
    _isSyncingSubject.close();
    _tasksSub?.cancel();
    _instancesSub?.cancel();
    _recipesSub?.cancel();
    _userDocSub?.cancel();
    _familyTasksSub?.cancel();
    _familyInstancesSub?.cancel();
    _familyRecipesSub?.cancel();
  }

  void startListeningToRemote() {
    if (!_isActivePremium ||
        _userId.isEmpty ||
        !_localDataSource.isMigrationCompleted()) {
      return;
    }
    if (_tasksSub != null && _instancesSub != null) return;
    _tasksSub?.cancel();
    _instancesSub?.cancel();
    _recipesSub?.cancel();
    _userDocSub?.cancel();
    _familyTasksSub?.cancel();
    _familyInstancesSub?.cancel();
    _familyRecipesSub?.cancel();

    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      try {
        if (_localDataSource.getDirtyTaskIds().isNotEmpty) {
          sync();
        }
      } catch (e, st) {
        logger?.error(
          'sync',
          'Periodic dirty tasks check failed',
          error: e,
          stackTrace: st,
        );
      }
    });

    try {
      if (_localDataSource.getDirtyTaskIds().isNotEmpty) {
        scheduleMicrotask(() => sync());
      }
    } catch (e, st) {
      logger?.error(
        'sync',
        'Initial dirty tasks check failed',
        error: e,
        stackTrace: st,
      );
    }

    logger?.info(
      'sync',
      'Starting remote listeners for tasks, instances and recipes',
      data: {'userId': _userId},
    );

    _updateClientMetadata();

    _userDocSub = _firestore
        .collection('users')
        .doc(_userId)
        .snapshots()
        .listen(
          (snapshot) {
            final newFamilyId = snapshot.data()?['familyId'] as String?;
            if (newFamilyId != _familyId) {
              _familyId = newFamilyId;
              _familyTasksSub?.cancel();
              _familyInstancesSub?.cancel();
              _familyRecipesSub?.cancel();
              if (_familyId != null && _familyId!.isNotEmpty) {
                _startListeningToFamilyRemote(_familyId!);
              }
            }
          },
          onError: (e, st) {
            logger?.error(
              'sync',
              'User doc stream error',
              error: e,
              stackTrace: st,
            );
            errorHandler?.report(e, stackTrace: st);
          },
        );

    _tasksSub = _firestore
        .collection('users')
        .doc(_userId)
        .collection('tasks')
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snapshot) async {
            logger?.debug(
              'sync',
              'Received remote tasks snapshot',
              data: {
                'docsCount': snapshot.docs.length,
                'changesCount': snapshot.docChanges.length,
              },
            );
            await _handleRemoteTasksSnapshot(snapshot, isFamily: false);
          },
          onError: (e, st) {
            logger?.error(
              'sync',
              'Remote tasks stream error',
              error: e,
              stackTrace: st,
            );
            errorHandler?.report(e, stackTrace: st);
          },
        );

    _instancesSub = _firestore
        .collection('users')
        .doc(_userId)
        .collection('instances')
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snapshot) async {
            logger?.debug(
              'sync',
              'Received remote instances snapshot',
              data: {
                'docsCount': snapshot.docs.length,
                'changesCount': snapshot.docChanges.length,
              },
            );
            await _handleRemoteInstancesSnapshot(snapshot, isFamily: false);
          },
          onError: (e, st) {
            logger?.error(
              'sync',
              'Remote instances stream error',
              error: e,
              stackTrace: st,
            );
            errorHandler?.report(e, stackTrace: st);
          },
        );

    _recipesSub = _firestore
        .collection('users')
        .doc(_userId)
        .collection('recipes')
        .snapshots()
        .listen(
          (snapshot) async {
            await _handleRemoteRecipesSnapshot(snapshot, isFamily: false);
          },
          onError: (e, st) {
            logger?.error(
              'sync',
              'Remote recipes stream error',
              error: e,
              stackTrace: st,
            );
            errorHandler?.report(e, stackTrace: st);
          },
        );
  }

  void _startListeningToFamilyRemote(String familyId) {
    _familyTasksSub = _firestore
        .collection('families')
        .doc(familyId)
        .collection('tasks')
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snapshot) async {
            logger?.debug(
              'sync',
              'Received remote family tasks snapshot',
              data: {
                'docsCount': snapshot.docs.length,
                'changesCount': snapshot.docChanges.length,
              },
            );
            await _handleRemoteTasksSnapshot(snapshot, isFamily: true);
          },
          onError: (e, st) {
            logger?.error(
              'sync',
              'Remote family tasks stream error',
              error: e,
              stackTrace: st,
            );
            errorHandler?.report(e, stackTrace: st);
          },
        );

    _familyInstancesSub = _firestore
        .collection('families')
        .doc(familyId)
        .collection('instances')
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snapshot) async {
            logger?.debug(
              'sync',
              'Received remote family instances snapshot',
              data: {
                'docsCount': snapshot.docs.length,
                'changesCount': snapshot.docChanges.length,
              },
            );
            await _handleRemoteInstancesSnapshot(snapshot, isFamily: true);
          },
          onError: (e, st) {
            logger?.error(
              'sync',
              'Remote family instances stream error',
              error: e,
              stackTrace: st,
            );
            errorHandler?.report(e, stackTrace: st);
          },
        );

    _familyRecipesSub = _firestore
        .collection('families')
        .doc(familyId)
        .collection('recipes')
        .snapshots()
        .listen(
          (snapshot) async {
            await _handleRemoteRecipesSnapshot(snapshot, isFamily: true);
          },
          onError: (e, st) {
            logger?.error(
              'sync',
              'Remote family recipes stream error',
              error: e,
              stackTrace: st,
            );
            errorHandler?.report(e, stackTrace: st);
          },
        );
  }

  Future<String?> _getFamilyId() async {
    if (_familyId != null) return _familyId;
    if (_userId.isEmpty) return null;
    try {
      final userDoc = await _firestore.collection('users').doc(_userId).get();
      _familyId = userDoc.data()?['familyId'] as String?;
      return _familyId;
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleRemoteTasksSnapshot(
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
            if (localTask.updatedAt.isAfter(remoteTask.updatedAt)) {
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
    }
    if (toSave.isNotEmpty) {
      await _localDataSource.saveTasks(toSave);
    }

    for (final task in toPush) {
      await _localDataSource.markDirty(task.id);
      await _pushTaskToRemote(task);
    }
  }

  Future<void> _handleRemoteInstancesSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    required bool isFamily,
  }) async {
    final isCache = snapshot.metadata.isFromCache;
    final localInsts = _localDataSource.getInstances();
    final localMap = {for (final inst in localInsts) inst.id: inst};
    final localSlotMap = {
      for (final inst in localInsts)
        '${inst.scheduleId}_${inst.ruleId}_${inst.scheduledDate}': inst,
    };

    final toSave = <TaskInstance>[];
    final toDelete = <String>[];
    final toPush = <TaskInstance>[];
    final remoteIdsToDelete = <String>[];

    final familyId = await _getFamilyId();

    for (final change in snapshot.docChanges) {
      final docId = change.doc.id;
      if (change.type == DocumentChangeType.removed) {
        final localInst = localMap[docId];
        if (localInst == null ||
            (isFamily ? localInst.isFamily : !localInst.isFamily)) {
          toDelete.add(docId);
          localMap.remove(docId);
          logger?.info(
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

          logger?.info(
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
              'isFamily': isFamily,
            },
          );

          if (localInst != null) {
            if (localInst.updatedAt.isAfter(remoteInst.updatedAt)) {
              toPush.add(localInst);
            } else {
              toSave.add(remoteInst);
              localMap[remoteInst.id] = remoteInst;
              localSlotMap['${remoteInst.scheduleId}_${remoteInst.ruleId}_${remoteInst.scheduledDate}'] =
                  remoteInst;
            }
          } else {
            final slotKey =
                '${remoteInst.scheduleId}_${remoteInst.ruleId}_${remoteInst.scheduledDate}';
            final localSlotInst = localSlotMap[slotKey];
            if (localSlotInst != null) {
              if (localSlotInst.updatedAt.isAfter(remoteInst.updatedAt)) {
                toPush.add(localSlotInst);
                remoteIdsToDelete.add(remoteInst.id);
              } else {
                toDelete.add(localSlotInst.id);
                localMap.remove(localSlotInst.id);
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
    }
    if (toSave.isNotEmpty) {
      await _localDataSource.saveInstances(toSave);
    }

    for (final inst in toPush) {
      await _localDataSource.markDirty(inst.id);
      await _pushInstanceToRemote(inst);
    }
    for (final remId in remoteIdsToDelete) {
      if (isFamily && familyId != null && familyId.isNotEmpty) {
        await _firestore
            .collection('families')
            .doc(familyId)
            .collection('instances')
            .doc(remId)
            .delete();
      } else {
        await _firestore
            .collection('users')
            .doc(_userId)
            .collection('instances')
            .doc(remId)
            .delete();
      }
    }
  }

  Future<void> _handleRemoteRecipesSnapshot(
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

  Future<void> sync() async {
    if (!_isActivePremium ||
        _userId.isEmpty ||
        _isSyncing ||
        !_localDataSource.isMigrationCompleted()) {
      return;
    }
    _isSyncing = true;
    if (!_isSyncingSubject.isClosed) {
      _isSyncingSubject.add(true);
    }

    try {
      final dirtyTaskIds = _localDataSource.getDirtyTaskIds();
      logger?.debug(
        'sync',
        'Firestore sync started',
        data: {'dirtyCount': dirtyTaskIds.length},
      );
      final localTasks = _localDataSource.getTasks();
      final localInstances = _localDataSource.getInstances();

      final tasksMap = {for (final t in localTasks) t.id: t};
      final instancesMap = {for (final i in localInstances) i.id: i};
      final familyId = await _getFamilyId();

      for (final taskId in dirtyTaskIds) {
        try {
          if (taskId.startsWith('S-')) {
            final task = tasksMap[taskId];
            if (task != null) {
              await _pushTaskToRemote(task);
            } else {
              // Deleted locally, remove from remote
              if (familyId != null && familyId.isNotEmpty) {
                await _firestore
                    .collection('families')
                    .doc(familyId)
                    .collection('tasks')
                    .doc(taskId)
                    .delete();
              }
              await _firestore
                  .collection('users')
                  .doc(_userId)
                  .collection('tasks')
                  .doc(taskId)
                  .delete();
            }
          } else if (taskId.startsWith('I-')) {
            final inst = instancesMap[taskId];
            if (inst != null) {
              await _pushInstanceToRemote(inst);
            } else {
              if (familyId != null && familyId.isNotEmpty) {
                await _firestore
                    .collection('families')
                    .doc(familyId)
                    .collection('instances')
                    .doc(taskId)
                    .delete();
              }
              await _firestore
                  .collection('users')
                  .doc(_userId)
                  .collection('instances')
                  .doc(taskId)
                  .delete();
            }
          }
          await _localDataSource.clearDirty(taskId);
        } catch (e, st) {
          logger?.error(
            'sync',
            'Failed to sync dirty item $taskId',
            error: e,
            stackTrace: st,
          );
          if (e is FirebaseException && e.code == 'permission-denied') {
            await _localDataSource.clearDirty(taskId);
          } else {
            rethrow;
          }
        }
      }
      logger?.info('sync', 'Firestore sync completed successfully');
    } catch (e, st) {
      logger?.error('sync', 'Firestore sync failed', error: e, stackTrace: st);
      errorHandler?.report(e, stackTrace: st);
      // ignore: avoid_print
      print('Sync failed: $e');
    } finally {
      _isSyncing = false;
      if (!_isSyncingSubject.isClosed) {
        _isSyncingSubject.add(false);
      }
    }
  }

  Future<void> _pushTaskToRemote(TaskSchedule task) async {
    final familyId = await _getFamilyId();
    if (task.isFamily && familyId != null && familyId.isNotEmpty) {
      await _firestore
          .collection('families')
          .doc(familyId)
          .collection('tasks')
          .doc(task.id)
          .set(task.toFirestore());
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('tasks')
          .doc(task.id)
          .delete();
    } else {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('tasks')
          .doc(task.id)
          .set(task.toFirestore());
      if (familyId != null && familyId.isNotEmpty) {
        await _firestore
            .collection('families')
            .doc(familyId)
            .collection('tasks')
            .doc(task.id)
            .delete();
      }
    }

    final localCurrent = _localDataSource
        .getTasks()
        .where((t) => t.id == task.id)
        .firstOrNull;
    if (localCurrent != null &&
        (localCurrent.hasPendingWrites || localCurrent.isFromCache)) {
      await _localDataSource.saveTask(
        localCurrent.copyWith(hasPendingWrites: false, isFromCache: false),
      );
    }
  }

  Future<void> _pushInstanceToRemote(TaskInstance inst) async {
    final familyId = await _getFamilyId();
    if (inst.isFamily && familyId != null && familyId.isNotEmpty) {
      await _firestore
          .collection('families')
          .doc(familyId)
          .collection('instances')
          .doc(inst.id)
          .set(inst.toFirestore());
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('instances')
          .doc(inst.id)
          .delete();
    } else {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('instances')
          .doc(inst.id)
          .set(inst.toFirestore());
      if (familyId != null && familyId.isNotEmpty) {
        await _firestore
            .collection('families')
            .doc(familyId)
            .collection('instances')
            .doc(inst.id)
            .delete();
      }
    }

    final localCurrent = _localDataSource
        .getInstances()
        .where((i) => i.id == inst.id)
        .firstOrNull;
    if (localCurrent != null &&
        (localCurrent.hasPendingWrites || localCurrent.isFromCache)) {
      await _localDataSource.saveInstance(
        localCurrent.copyWith(hasPendingWrites: false, isFromCache: false),
      );
    }
  }

  Future<void> _updateClientMetadata() async {
    try {
      final now = DateTime.now().toUtc();
      final batch = _firestore.batch();
      batch.set(_firestore.collection('users').doc(_userId), {
        'appVersion': AppVersion.display,
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'lastSeenAt': now.toIso8601String(),
      }, SetOptions(merge: true));

      if (_familyId != null && _familyId!.isNotEmpty) {
        batch.update(_firestore.collection('families').doc(_familyId), {
          'members.$_userId.appVersion': AppVersion.display,
          'members.$_userId.platform': kIsWeb
              ? 'web'
              : defaultTargetPlatform.name,
          'members.$_userId.lastSeenAt': now.toIso8601String(),
        });
      }
      await batch.commit();
    } catch (e) {
      logger?.debug(
        'sync',
        'Failed to update client metadata in Firestore',
        error: e,
      );
    }
  }
}
