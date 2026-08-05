import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nothing_ever_happens/logic/hive_local_data_source.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nothing_ever_happens/logic/subscription_service.dart';
import 'package:nothing_ever_happens/logic/auth_repository.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';

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

  StreamSubscription? _tasksSub;
  StreamSubscription? _instancesSub;

  bool _isSyncing = false;

  TaskSyncService({
    required FirebaseFirestore firestore,
    required HiveLocalDataSource localDataSource,
    required String userId,
    required bool isActivePremium,
  }) : _firestore = firestore,
       _localDataSource = localDataSource,
       _userId = userId,
       _isActivePremium = isActivePremium {
    if (_isActivePremium && _userId.isNotEmpty) {
      _startListeningToRemote();
    }
  }

  void dispose() {
    _tasksSub?.cancel();
    _instancesSub?.cancel();
  }

  void _startListeningToRemote() {
    _tasksSub = _firestore
        .collection('users')
        .doc(_userId)
        .collection('tasks')
        .snapshots()
        .listen((snapshot) {
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added ||
                change.type == DocumentChangeType.modified) {
              if (change.doc.data() != null) {
                _handleRemoteTaskUpdate(TaskSchedule.fromFirestore(change.doc));
              }
            } else if (change.type == DocumentChangeType.removed) {
              _localDataSource.deleteTask(change.doc.id);
            }
          }
        });

    _instancesSub = _firestore
        .collection('users')
        .doc(_userId)
        .collection('instances')
        .snapshots()
        .listen((snapshot) {
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added ||
                change.type == DocumentChangeType.modified) {
              if (change.doc.data() != null) {
                _handleRemoteInstanceUpdate(
                  TaskInstance.fromFirestore(change.doc),
                );
              }
            } else if (change.type == DocumentChangeType.removed) {
              _localDataSource.deleteInstance(change.doc.id);
            }
          }
        });
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

    if (localInstIndex == -1) {
      await _localDataSource.saveInstance(remoteInst);
      return;
    }

    final localInst = localInsts[localInstIndex];
    if (localInst.updatedAt.isAfter(remoteInst.updatedAt)) {
      await _pushInstanceToRemote(localInst);
    } else {
      await _localDataSource.saveInstance(remoteInst);
    }
  }

  Future<void> sync() async {
    if (!_isActivePremium || _userId.isEmpty || _isSyncing) return;
    _isSyncing = true;

    try {
      final dirtyTaskIds = _localDataSource.getDirtyTaskIds();
      final localTasks = _localDataSource.getTasks();
      final localInstances = _localDataSource.getInstances();

      final tasksMap = {for (final t in localTasks) t.id: t};
      final instancesMap = {for (final i in localInstances) i.id: i};

      for (final taskId in dirtyTaskIds) {
        if (taskId.startsWith('S-')) {
          final task = tasksMap[taskId];
          if (task != null) {
            await _pushTaskToRemote(task);
          } else {
            // Deleted locally, remove from remote
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
    } catch (e) {
      // ignore: avoid_print
      print('Sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _pushTaskToRemote(TaskSchedule task) async {
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('tasks')
        .doc(task.id)
        .set(task.toFirestore());
  }

  Future<void> _pushInstanceToRemote(TaskInstance inst) async {
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('instances')
        .doc(inst.id)
        .set(inst.toFirestore());
  }
}
