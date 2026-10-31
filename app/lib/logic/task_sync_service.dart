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
import 'package:nothing_ever_happens/logic/firestore_paths.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/logic/app_logger.dart';
import 'package:nothing_ever_happens/logic/remote_snapshot_reconciler.dart';
import 'package:nothing_ever_happens/logic/utils/app_version.dart';
import 'package:rxdart/rxdart.dart';

import 'package:nothing_ever_happens/logic/family.dart';

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
    isSubscriptionResolved: subscriptionState.isResolved,
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
  final bool _isSubscriptionResolved;
  final Duration _initialSyncTimeout;
  final ErrorHandler? errorHandler;
  final AppLogger? logger;
  final FamilyIdFetcher _familyIdFetcher;
  late final RemoteSnapshotReconciler _snapshotReconciler;

  StreamSubscription? _tasksSub;
  StreamSubscription? _instancesSub;
  StreamSubscription? _recipesSub;
  StreamSubscription? _userDocSub;
  StreamSubscription? _familyTasksSub;
  StreamSubscription? _familyInstancesSub;
  StreamSubscription? _familyRecipesSub;
  String? _familyId;
  String? _familyRole;
  bool _updatedInitialClientMetadata = false;

  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;
  bool _hasQueuedSync = false;
  final _isSyncingSubject = BehaviorSubject<bool>.seeded(false);
  Stream<bool> get isSyncingStream => _isSyncingSubject.stream;
  Timer? _periodicSyncTimer;

  final Completer<void> _initialSyncCompleter = Completer<void>();
  Future<void> get waitForInitialSync {
    if ((!_isActivePremium && _isSubscriptionResolved) ||
        _userId.isEmpty ||
        !_localDataSource.isMigrationCompleted()) {
      return Future.value();
    }
    if (_initialSyncCompleter.isCompleted) {
      return Future.value();
    }
    return _initialSyncCompleter.future.timeout(
      _initialSyncTimeout + const Duration(seconds: 1),
      onTimeout: () {
        _completeInitialSync();
      },
    );
  }

  bool _receivedPersonalTasks = false;
  bool _receivedPersonalInstances = false;
  bool _receivedUserDoc = false;
  bool _receivedFamilyTasks = false;
  bool _receivedFamilyInstances = false;
  Timer? _initialSyncTimeoutTimer;

  void _startInitialSyncTimeoutTimer() {
    if (_initialSyncCompleter.isCompleted) return;
    _initialSyncTimeoutTimer?.cancel();
    _initialSyncTimeoutTimer = Timer(_initialSyncTimeout, () {
      _completeInitialSync();
    });
  }

  void _completeInitialSync() {
    _initialSyncTimeoutTimer?.cancel();
    _initialSyncTimeoutTimer = null;
    if (!_initialSyncCompleter.isCompleted) {
      _initialSyncCompleter.complete();
    }
  }

  void _checkInitialSyncComplete() {
    if (_initialSyncCompleter.isCompleted) return;

    if (!_receivedPersonalTasks ||
        !_receivedPersonalInstances ||
        !_receivedUserDoc) {
      return;
    }

    if (_familyId != null && _familyId!.isNotEmpty) {
      if (!_receivedFamilyTasks || !_receivedFamilyInstances) {
        return;
      }
    }

    _completeInitialSync();
  }

  TaskSyncService({
    required FirebaseFirestore firestore,
    required HiveLocalDataSource localDataSource,
    required String userId,
    required bool isActivePremium,
    bool isSubscriptionResolved = true,
    Duration initialSyncTimeout = const Duration(seconds: 10),
    this.errorHandler,
    this.logger,
    FamilyIdFetcher? familyIdFetcher,
  }) : _firestore = firestore,
       _localDataSource = localDataSource,
       _userId = userId,
       _isActivePremium = isActivePremium,
       _isSubscriptionResolved = isSubscriptionResolved,
       _initialSyncTimeout = initialSyncTimeout,
       _familyIdFetcher =
           familyIdFetcher ??
           FamilyIdFetcher(
             firestore: firestore,
             userId: userId,
             errorHandler: errorHandler,
           ) {
    _snapshotReconciler = RemoteSnapshotReconciler(
      firestore: _firestore,
      localDataSource: _localDataSource,
      userId: _userId,
      getFamilyId: _getFamilyId,
      isFamilyParent: _isFamilyParent,
      pushTaskToRemote: _pushTaskToRemote,
      pushInstanceToRemote: _pushInstanceToRemote,
      logger: logger,
    );
    if (_isActivePremium &&
        _userId.isNotEmpty &&
        _localDataSource.isMigrationCompleted()) {
      startListeningToRemote();
    } else if (!_isSubscriptionResolved &&
        _userId.isNotEmpty &&
        _localDataSource.isMigrationCompleted()) {
      _startInitialSyncTimeoutTimer();
    } else {
      _completeInitialSync();
    }
  }

  void dispose() {
    _isDisposed = true;
    _hasQueuedSync = false;
    _initialSyncTimeoutTimer?.cancel();
    _completeInitialSync();
    _periodicSyncTimer?.cancel();
    if (!_isSyncingSubject.isClosed) {
      _isSyncingSubject.close();
    }
    _tasksSub?.cancel();
    _instancesSub?.cancel();
    _recipesSub?.cancel();
    _userDocSub?.cancel();
    _familyTasksSub?.cancel();
    _familyInstancesSub?.cancel();
    _familyRecipesSub?.cancel();
  }

  void startListeningToRemote() {
    if (_isDisposed ||
        _userId.isEmpty ||
        !_localDataSource.isMigrationCompleted()) {
      _completeInitialSync();
      return;
    }
    if (!_isActivePremium) {
      if (_isSubscriptionResolved) {
        _completeInitialSync();
      } else {
        _startInitialSyncTimeoutTimer();
      }
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
    _updatedInitialClientMetadata = false;

    _startInitialSyncTimeoutTimer();

    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isDisposed) return;
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

    _userDocSub = _firestore
        .collection(FirestorePaths.users)
        .doc(_userId)
        .snapshots()
        .listen(
          (snapshot) async {
            _receivedUserDoc = true;
            final newFamilyId = snapshot.data()?['familyId'] as String?;
            final newFamilyRole = snapshot.data()?['familyRole'] as String?;
            final roleChanged = newFamilyRole != _familyRole;
            _familyRole = newFamilyRole;
            if (newFamilyId != _familyId ||
                (newFamilyId != null &&
                    newFamilyId.isNotEmpty &&
                    _familyTasksSub == null)) {
              final previousFamilyId = _familyId;
              _familyId = newFamilyId;
              _familyIdFetcher.clearCache();
              _familyTasksSub?.cancel();
              _familyTasksSub = null;
              _familyInstancesSub?.cancel();
              _familyInstancesSub = null;
              _familyRecipesSub?.cancel();
              _familyRecipesSub = null;
              _receivedFamilyTasks = false;
              _receivedFamilyInstances = false;
              if (previousFamilyId != null &&
                  previousFamilyId.isNotEmpty &&
                  previousFamilyId != newFamilyId) {
                await _localDataSource.purgeFamilyData();
              }
              if (!_isDisposed &&
                  _familyId == newFamilyId &&
                  _familyId != null &&
                  _familyId!.isNotEmpty) {
                _startListeningToFamilyRemote(_familyId!);
              }
              _updatedInitialClientMetadata = true;
              updateClientMetadata();
            } else {
              if (roleChanged) {
                _familyIdFetcher.clearCache();
              }
              if (!_updatedInitialClientMetadata) {
                _updatedInitialClientMetadata = true;
                updateClientMetadata();
              }
            }
            _checkInitialSyncComplete();
          },
          onError: (e, st) {
            logger?.error(
              'sync',
              'User doc stream error',
              error: e,
              stackTrace: st,
            );
            errorHandler?.report(e, stackTrace: st);
            _receivedUserDoc = true;
            _checkInitialSyncComplete();
          },
        );

    _tasksSub = _firestore
        .collection(FirestorePaths.users)
        .doc(_userId)
        .collection(FirestorePaths.tasks)
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
            _receivedPersonalTasks = true;
            _checkInitialSyncComplete();
          },
          onError: (e, st) {
            logger?.error(
              'sync',
              'Remote tasks stream error',
              error: e,
              stackTrace: st,
            );
            errorHandler?.report(e, stackTrace: st);
            _receivedPersonalTasks = true;
            _checkInitialSyncComplete();
          },
        );

    _instancesSub = _firestore
        .collection(FirestorePaths.users)
        .doc(_userId)
        .collection(FirestorePaths.instances)
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
            _receivedPersonalInstances = true;
            _checkInitialSyncComplete();
          },
          onError: (e, st) {
            logger?.error(
              'sync',
              'Remote instances stream error',
              error: e,
              stackTrace: st,
            );
            errorHandler?.report(e, stackTrace: st);
            _receivedPersonalInstances = true;
            _checkInitialSyncComplete();
          },
        );

    _recipesSub = _firestore
        .collection(FirestorePaths.users)
        .doc(_userId)
        .collection(FirestorePaths.recipes)
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
        .collection(FirestorePaths.families)
        .doc(familyId)
        .collection(FirestorePaths.tasks)
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
            _receivedFamilyTasks = true;
            _checkInitialSyncComplete();
          },
          onError: (e, st) {
            logger?.error(
              'sync',
              'Remote family tasks stream error',
              error: e,
              stackTrace: st,
            );
            errorHandler?.report(e, stackTrace: st);
            _receivedFamilyTasks = true;
            _checkInitialSyncComplete();
          },
        );

    _familyInstancesSub = _firestore
        .collection(FirestorePaths.families)
        .doc(familyId)
        .collection(FirestorePaths.instances)
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
            _receivedFamilyInstances = true;
            _checkInitialSyncComplete();
          },
          onError: (e, st) {
            logger?.error(
              'sync',
              'Remote family instances stream error',
              error: e,
              stackTrace: st,
            );
            errorHandler?.report(e, stackTrace: st);
            _receivedFamilyInstances = true;
            _checkInitialSyncComplete();
          },
        );

    _familyRecipesSub = _firestore
        .collection(FirestorePaths.families)
        .doc(familyId)
        .collection(FirestorePaths.recipes)
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
    final fetched = await _familyIdFetcher.getFamilyId();
    if (!_receivedUserDoc && _familyId == null && fetched != null) {
      _familyId = fetched;
    }
    return _familyId ?? fetched;
  }

  Future<bool> _isFamilyParent() async {
    if (_familyRole != null) {
      return _familyRole == FamilyRole.parent.value;
    }
    return await _familyIdFetcher.isFamilyParent();
  }

  Future<void> _handleRemoteTasksSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    required bool isFamily,
  }) => _snapshotReconciler.handleRemoteTasksSnapshot(
    snapshot,
    isFamily: isFamily,
  );

  Future<void> _handleRemoteInstancesSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    required bool isFamily,
  }) => _snapshotReconciler.handleRemoteInstancesSnapshot(
    snapshot,
    isFamily: isFamily,
  );

  Future<void> _handleRemoteRecipesSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    required bool isFamily,
  }) => _snapshotReconciler.handleRemoteRecipesSnapshot(
    snapshot,
    isFamily: isFamily,
  );

  Future<void> sync() async {
    if (_isDisposed ||
        !_isActivePremium ||
        _userId.isEmpty ||
        !_localDataSource.isMigrationCompleted()) {
      return;
    }
    if (_isSyncing) {
      _hasQueuedSync = true;
      return;
    }
    _isSyncing = true;
    if (!_isSyncingSubject.isClosed && !_isDisposed) {
      _isSyncingSubject.add(true);
    }

    try {
      do {
        _hasQueuedSync = false;
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
          if (_isDisposed) break;
          try {
            bool canClearDirty = true;
            if (taskId.startsWith('S-')) {
              final task = tasksMap[taskId];
              if (task != null) {
                canClearDirty = await _pushTaskToRemote(task);
              } else {
                // Deleted locally, remove from remote:
                // 1. Delete from personal user collection first
                await _firestore
                    .collection(FirestorePaths.users)
                    .doc(_userId)
                    .collection(FirestorePaths.tasks)
                    .doc(taskId)
                    .delete();
                // 2. Attempt family collection delete if familyId exists, swallowing permission-denied
                if (familyId != null && familyId.isNotEmpty) {
                  try {
                    await _firestore
                        .collection(FirestorePaths.families)
                        .doc(familyId)
                        .collection(FirestorePaths.tasks)
                        .doc(taskId)
                        .delete();
                  } catch (e) {
                    if (e is! FirebaseException ||
                        e.code != 'permission-denied') {
                      rethrow;
                    }
                  }
                }
                if (_localDataSource.getTasks().any((t) => t.id == taskId)) {
                  canClearDirty = false;
                  _hasQueuedSync = true;
                }
              }
            } else if (taskId.startsWith('I-')) {
              final inst = instancesMap[taskId];
              if (inst != null) {
                canClearDirty = await _pushInstanceToRemote(inst);
              } else {
                // Deleted locally, remove from remote:
                // 1. Delete from personal user collection first
                await _firestore
                    .collection(FirestorePaths.users)
                    .doc(_userId)
                    .collection(FirestorePaths.instances)
                    .doc(taskId)
                    .delete();
                // 2. Only parents can delete from family instances
                if (familyId != null && familyId.isNotEmpty) {
                  final isParent = await _isFamilyParent();
                  if (isParent) {
                    try {
                      await _firestore
                          .collection(FirestorePaths.families)
                          .doc(familyId)
                          .collection(FirestorePaths.instances)
                          .doc(taskId)
                          .delete();
                    } catch (e) {
                      if (e is! FirebaseException ||
                          e.code != 'permission-denied') {
                        rethrow;
                      }
                    }
                  }
                }
                if (_localDataSource.getInstances().any(
                  (i) => i.id == taskId,
                )) {
                  canClearDirty = false;
                  _hasQueuedSync = true;
                }
              }
            }
            if (_isDisposed) break;
            if (canClearDirty) {
              await _localDataSource.clearDirty(taskId);
            }
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
        if (!_isDisposed) {
          logger?.info('sync', 'Firestore sync completed successfully');
        }
      } while (_hasQueuedSync && !_isDisposed && _isActivePremium);
    } catch (e, st) {
      logger?.error('sync', 'Firestore sync failed', error: e, stackTrace: st);
      errorHandler?.report(e, stackTrace: st);
    } finally {
      _isSyncing = false;
      if (!_isSyncingSubject.isClosed && !_isDisposed) {
        _isSyncingSubject.add(false);
      }
    }
  }

  Future<bool> _pushTaskToRemote(TaskSchedule task) async {
    final familyId = await _getFamilyId();
    final taskData = <String, dynamic>{
      ...task.toFirestore(),
      'lastSpawnedDate': task.lastSpawnedDate?.toJson(),
      'parentTaskId': task.parentTaskId,
      'cycleId': task.cycleId,
      'assignedUserId': task.assignedUserId,
      'appLaunchUrl': task.appLaunchUrl,
      'workflowType': task.workflowType,
      'mealWorkflowConfig': task.mealWorkflowConfig?.toJson(),
    };
    if (task.isFamily && familyId != null && familyId.isNotEmpty) {
      await _firestore
          .collection(FirestorePaths.families)
          .doc(familyId)
          .collection(FirestorePaths.tasks)
          .doc(task.id)
          .set(taskData, SetOptions(merge: true));
      await _firestore
          .collection(FirestorePaths.users)
          .doc(_userId)
          .collection(FirestorePaths.tasks)
          .doc(task.id)
          .delete();
    } else {
      await _firestore
          .collection(FirestorePaths.users)
          .doc(_userId)
          .collection(FirestorePaths.tasks)
          .doc(task.id)
          .set(taskData, SetOptions(merge: true));
      if (familyId != null && familyId.isNotEmpty) {
        final isParent = await _isFamilyParent();
        if (isParent) {
          try {
            await _firestore
                .collection(FirestorePaths.families)
                .doc(familyId)
                .collection(FirestorePaths.tasks)
                .doc(task.id)
                .delete();
          } catch (e) {
            logger?.debug('sync', 'Silent error deleting task from family: $e');
          }
        }
      }
    }

    final localCurrent = _localDataSource
        .getTasks()
        .where((t) => t.id == task.id)
        .firstOrNull;
    if (localCurrent == null || localCurrent.updatedAt != task.updatedAt) {
      _hasQueuedSync = true;
      return false;
    }
    if (localCurrent.hasPendingWrites || localCurrent.isFromCache) {
      await _localDataSource.saveTask(
        localCurrent.copyWith(hasPendingWrites: false, isFromCache: false),
      );
    }
    return true;
  }

  Future<bool> _pushInstanceToRemote(TaskInstance inst) async {
    final familyId = await _getFamilyId();
    final instData = <String, dynamic>{
      ...inst.toFirestore(),
      'notificationRelativeTimes': inst.notificationRelativeTimes
          .map((t) => t.toJson())
          .toList(),
      'completedByUserId': inst.completedByUserId,
      'completedByUserIds': inst.completedByUserIds,
      'completedAt': inst.completedAt,
      'statusReason': inst.statusReason,
      'cycleId': inst.cycleId,
      'assignedUserId': inst.assignedUserId,
      'workflowPayload': inst.workflowPayload?.toJson(),
      'lastModifiedByUserId': inst.lastModifiedByUserId,
      'lastModifiedByAppVersion': inst.lastModifiedByAppVersion,
      'lastModifiedByPlatform': inst.lastModifiedByPlatform,
    };
    if (inst.isFamily && familyId != null && familyId.isNotEmpty) {
      await _firestore
          .collection(FirestorePaths.families)
          .doc(familyId)
          .collection(FirestorePaths.instances)
          .doc(inst.id)
          .set(instData, SetOptions(merge: true));
      await _firestore
          .collection(FirestorePaths.users)
          .doc(_userId)
          .collection(FirestorePaths.instances)
          .doc(inst.id)
          .delete();
    } else {
      await _firestore
          .collection(FirestorePaths.users)
          .doc(_userId)
          .collection(FirestorePaths.instances)
          .doc(inst.id)
          .set(instData, SetOptions(merge: true));
      if (familyId != null && familyId.isNotEmpty) {
        final isParent = await _isFamilyParent();
        if (isParent) {
          try {
            await _firestore
                .collection(FirestorePaths.families)
                .doc(familyId)
                .collection(FirestorePaths.instances)
                .doc(inst.id)
                .delete();
          } catch (e) {
            logger?.debug(
              'sync',
              'Silent error deleting instance from family: $e',
            );
          }
        }
      }
    }

    final localCurrent = _localDataSource
        .getInstances()
        .where((i) => i.id == inst.id)
        .firstOrNull;
    if (localCurrent == null || localCurrent.updatedAt != inst.updatedAt) {
      _hasQueuedSync = true;
      return false;
    }
    if (localCurrent.hasPendingWrites || localCurrent.isFromCache) {
      await _localDataSource.saveInstance(
        localCurrent.copyWith(hasPendingWrites: false, isFromCache: false),
      );
    }
    return true;
  }

  Future<void> updateClientMetadata() async {
    if (_isDisposed || _userId.isEmpty) return;
    try {
      final localNow = AppClock.now;
      final now = localNow.toUtc();
      final offsetMinutes = localNow.timeZoneOffset.inMinutes;
      final timeZoneName = localNow.timeZoneName;
      await _firestore.collection(FirestorePaths.users).doc(_userId).set({
        'appVersion': AppVersion.display,
        'platform': AppVersion.platform,
        'lastSeenAt': now.toIso8601String(),
        'timeZone': timeZoneName,
        'timeZoneOffsetMinutes': offsetMinutes,
      }, SetOptions(merge: true));

      if (_familyId != null && _familyId!.isNotEmpty) {
        try {
          await _firestore
              .collection(FirestorePaths.families)
              .doc(_familyId)
              .update({
                'members.$_userId.appVersion': AppVersion.display,
                'members.$_userId.platform': AppVersion.platform,
                'members.$_userId.lastSeenAt': now.toIso8601String(),
                'members.$_userId.timeZone': timeZoneName,
                'members.$_userId.timeZoneOffsetMinutes': offsetMinutes,
              });
        } catch (e) {
          logger?.debug(
            'sync',
            'Failed to update family member client metadata in Firestore',
            error: e,
          );
        }
      }
    } catch (e) {
      logger?.debug(
        'sync',
        'Failed to update client metadata in Firestore',
        error: e,
      );
    }
  }
}
