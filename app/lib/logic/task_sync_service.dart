import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nothing_ever_happens/logic/hive_local_data_source.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nothing_ever_happens/logic/subscription_service.dart';
import 'package:nothing_ever_happens/logic/auth_repository.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/error_handler.dart';
import 'package:nothing_ever_happens/logic/app_logger.dart';

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

    logger?.info(
      'sync',
      'Starting remote listeners for tasks, instances and recipes',
      data: {'userId': _userId},
    );

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
        .snapshots()
        .listen(
          (snapshot) {
            logger?.debug(
              'sync',
              'Received remote tasks snapshot',
              data: {
                'docsCount': snapshot.docs.length,
                'changesCount': snapshot.docChanges.length,
              },
            );
            for (final change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added ||
                  change.type == DocumentChangeType.modified) {
                if (change.doc.data() != null) {
                  _handleRemoteTaskUpdate(
                    TaskSchedule.fromFirestore(change.doc),
                  );
                }
              } else if (change.type == DocumentChangeType.removed) {
                final localTask = _localDataSource
                    .getTasks()
                    .where((t) => t.id == change.doc.id)
                    .firstOrNull;
                if (localTask == null || !localTask.isFamily) {
                  _localDataSource.deleteTask(change.doc.id);
                }
              }
            }
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
        .snapshots()
        .listen(
          (snapshot) {
            logger?.debug(
              'sync',
              'Received remote instances snapshot',
              data: {
                'docsCount': snapshot.docs.length,
                'changesCount': snapshot.docChanges.length,
              },
            );
            for (final change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added ||
                  change.type == DocumentChangeType.modified) {
                if (change.doc.data() != null) {
                  _handleRemoteInstanceUpdate(
                    TaskInstance.fromFirestore(change.doc),
                  );
                }
              } else if (change.type == DocumentChangeType.removed) {
                final localInst = _localDataSource
                    .getInstances()
                    .where((i) => i.id == change.doc.id)
                    .firstOrNull;
                if (localInst == null || !localInst.isFamily) {
                  _localDataSource.deleteInstance(change.doc.id);
                }
              }
            }
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
          (snapshot) {
            for (final change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added ||
                  change.type == DocumentChangeType.modified) {
                if (change.doc.data() != null) {
                  final remoteRecipe = Recipe.fromFirestore(change.doc);
                  final localRecipe = _localDataSource
                      .getRecipes()
                      .where((r) => r.id == remoteRecipe.id)
                      .firstOrNull;
                  if (localRecipe == null ||
                      remoteRecipe.updatedAt.isAfter(localRecipe.updatedAt)) {
                    _localDataSource.saveRecipe(
                      remoteRecipe.copyWith(
                        hasPendingWrites: false,
                        isFromCache: false,
                      ),
                    );
                  }
                }
              } else if (change.type == DocumentChangeType.removed) {
                final localRecipe = _localDataSource
                    .getRecipes()
                    .where((r) => r.id == change.doc.id)
                    .firstOrNull;
                if (localRecipe == null || !localRecipe.isFamily) {
                  _localDataSource.deleteRecipe(change.doc.id);
                }
              }
            }
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
        .snapshots()
        .listen(
          (snapshot) {
            logger?.debug(
              'sync',
              'Received remote family tasks snapshot',
              data: {
                'docsCount': snapshot.docs.length,
                'changesCount': snapshot.docChanges.length,
              },
            );
            for (final change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added ||
                  change.type == DocumentChangeType.modified) {
                if (change.doc.data() != null) {
                  _handleRemoteTaskUpdate(
                    TaskSchedule.fromFirestore(change.doc),
                  );
                }
              } else if (change.type == DocumentChangeType.removed) {
                final localTask = _localDataSource
                    .getTasks()
                    .where((t) => t.id == change.doc.id)
                    .firstOrNull;
                if (localTask == null || localTask.isFamily) {
                  _localDataSource.deleteTask(change.doc.id);
                }
              }
            }
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
        .snapshots()
        .listen(
          (snapshot) {
            logger?.debug(
              'sync',
              'Received remote family instances snapshot',
              data: {
                'docsCount': snapshot.docs.length,
                'changesCount': snapshot.docChanges.length,
              },
            );
            for (final change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added ||
                  change.type == DocumentChangeType.modified) {
                if (change.doc.data() != null) {
                  _handleRemoteInstanceUpdate(
                    TaskInstance.fromFirestore(change.doc),
                  );
                }
              } else if (change.type == DocumentChangeType.removed) {
                final localInst = _localDataSource
                    .getInstances()
                    .where((i) => i.id == change.doc.id)
                    .firstOrNull;
                if (localInst == null || localInst.isFamily) {
                  _localDataSource.deleteInstance(change.doc.id);
                }
              }
            }
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
          (snapshot) {
            for (final change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added ||
                  change.type == DocumentChangeType.modified) {
                if (change.doc.data() != null) {
                  final remoteRecipe = Recipe.fromFirestore(change.doc);
                  final localRecipe = _localDataSource
                      .getRecipes()
                      .where((r) => r.id == remoteRecipe.id)
                      .firstOrNull;
                  if (localRecipe == null ||
                      remoteRecipe.updatedAt.isAfter(localRecipe.updatedAt)) {
                    _localDataSource.saveRecipe(
                      remoteRecipe.copyWith(
                        hasPendingWrites: false,
                        isFromCache: false,
                      ),
                    );
                  }
                }
              } else if (change.type == DocumentChangeType.removed) {
                _localDataSource.deleteRecipe(change.doc.id);
              }
            }
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

  Future<void> _handleRemoteTaskUpdate(TaskSchedule remoteTask) async {
    final localTasks = _localDataSource.getTasks();
    final localTaskIndex = localTasks.indexWhere((t) => t.id == remoteTask.id);

    if (localTaskIndex == -1) {
      await _localDataSource.saveTask(remoteTask);
      return;
    }

    final localTask = localTasks[localTaskIndex];
    if (localTask.updatedAt.isAfter(remoteTask.updatedAt)) {
      // Local wins
      await _pushTaskToRemote(localTask);
    } else {
      // Remote wins (or equal)
      await _localDataSource.saveTask(remoteTask);
    }
  }

  Future<void> _handleRemoteInstanceUpdate(TaskInstance remoteInst) async {
    final localInsts = _localDataSource.getInstances();
    final localInstIndex = localInsts.indexWhere((i) => i.id == remoteInst.id);

    if (localInstIndex != -1) {
      final localInst = localInsts[localInstIndex];
      if (localInst.updatedAt.isAfter(remoteInst.updatedAt)) {
        await _pushInstanceToRemote(localInst);
      } else {
        await _localDataSource.saveInstance(remoteInst);
      }
      return;
    }

    final localSlotIndex = localInsts.indexWhere(
      (i) =>
          i.scheduleId == remoteInst.scheduleId &&
          i.ruleId == remoteInst.ruleId &&
          i.scheduledDate == remoteInst.scheduledDate,
    );

    if (localSlotIndex != -1) {
      final localInst = localInsts[localSlotIndex];
      if (localInst.updatedAt.isAfter(remoteInst.updatedAt)) {
        // Local wins
        await _localDataSource.markDirty(localInst.id);
        await _pushInstanceToRemote(localInst);
        final familyId = await _getFamilyId();
        if (remoteInst.isFamily && familyId != null && familyId.isNotEmpty) {
          await _firestore
              .collection('families')
              .doc(familyId)
              .collection('instances')
              .doc(remoteInst.id)
              .delete();
        } else {
          await _firestore
              .collection('users')
              .doc(_userId)
              .collection('instances')
              .doc(remoteInst.id)
              .delete();
        }
      } else {
        // Remote wins (or equal)
        await _localDataSource.deleteInstance(localInst.id);
        await _localDataSource.saveInstance(remoteInst);
      }
      return;
    }

    await _localDataSource.saveInstance(remoteInst);
  }

  Future<void> sync() async {
    if (!_isActivePremium ||
        _userId.isEmpty ||
        _isSyncing ||
        !_localDataSource.isMigrationCompleted()) {
      return;
    }
    _isSyncing = true;

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
      }
      logger?.info('sync', 'Firestore sync completed successfully');
    } catch (e, st) {
      logger?.error('sync', 'Firestore sync failed', error: e, stackTrace: st);
      errorHandler?.report(e, stackTrace: st);
      // ignore: avoid_print
      print('Sync failed: $e');
    } finally {
      _isSyncing = false;
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
  }
}
