import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:rxdart/rxdart.dart';

import 'app_clock.dart';
import 'civil_day.dart';
import 'task_schedule.dart';
import 'task_instance.dart';
import 'notification_service.dart';
import 'auth_repository.dart';
import 'unified_task_repository.dart';
import 'hive_local_data_source.dart';
import 'task_sync_service.dart';
import 'error_handler.dart';
import 'app_logger.dart';
import 'telemetry_service.dart';
import 'subscription_service.dart';

export 'firestore_task_repository.dart';

class _AppLifecycleObserver extends WidgetsBindingObserver {
  final VoidCallback onResume;

  _AppLifecycleObserver({required this.onResume});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResume();
    }
  }
}

final firestoreProvider = Provider<FirebaseFirestore?>((ref) {
  try {
    if (Firebase.apps.isEmpty) return null;
    final firestore = FirebaseFirestore.instance;
    if (kIsWeb) {
      firestore.settings = const Settings(
        persistenceEnabled: false,
        webExperimentalAutoDetectLongPolling: true,
      );
    }
    return firestore;
  } catch (e, st) {
    // Expected during tests or initialization if Firebase is not initialized
    ref.read(errorHandlerProvider).report(e, stackTrace: st);
    return null;
  }
});

final taskRepositoryProvider = Provider<TaskRepository?>((ref) {
  final firestore = ref.watch(firestoreProvider);
  if (firestore == null) return null;
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;

  final localDataSource = ref.watch(hiveLocalDataSourceProvider);
  final syncService = ref.watch(taskSyncServiceProvider);

  final repo = UnifiedTaskRepository(
    localDataSource: localDataSource,
    syncService: syncService,
    firestore: firestore,
    userId: user.uid,
    notificationService: ref.watch(notificationServiceProvider),
    errorHandler: ref.read(errorHandlerProvider),
    logger: ref.watch(appLoggerProvider),
    telemetryService: ref.watch(telemetryServiceProvider),
  );

  // Re-evaluate schedules when the mock clock advances in dev/test
  void clockListener() {
    repo.triggerMissedPolicyProcessing();
  }

  AppClock.timeNotifier.addListener(clockListener);

  // Monitor app lifecycle changes to trigger sync on resume
  _AppLifecycleObserver? lifecycleObserver;
  try {
    lifecycleObserver = _AppLifecycleObserver(
      onResume: () {
        repo.triggerMissedPolicyProcessing();
      },
    );
    WidgetsBinding.instance.addObserver(lifecycleObserver);
  } catch (e, st) {
    // Expected in test environments without WidgetsBinding
    ref.read(errorHandlerProvider).report(e, stackTrace: st);
    lifecycleObserver = null;
  }

  // Monitor calendar day transitions to trigger missed policy processing at midnight
  var lastCheckedDay = CivilDay.fromDateTime(AppClock.now);
  final dayChangeTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
    final currentDay = CivilDay.fromDateTime(AppClock.now);
    if (currentDay != lastCheckedDay) {
      lastCheckedDay = currentDay;
      repo.triggerMissedPolicyProcessing();
    }
  });

  ref.onDispose(() {
    repo.dispose();
    AppClock.timeNotifier.removeListener(clockListener);
    if (lifecycleObserver != null) {
      try {
        WidgetsBinding.instance.removeObserver(lifecycleObserver);
      } catch (e, st) {
        // Ignore unregister errors on dispose, but log them
        ref.read(errorHandlerProvider).report(e, stackTrace: st);
      }
    }
    dayChangeTimer.cancel();
  });

  return repo;
});

final taskSchedulesProvider = StreamProvider<List<TaskSchedule>>((ref) {
  final repo = ref.watch(taskRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.getTasks();
});

final taskInstancesProvider = StreamProvider<List<TaskInstance>>((ref) {
  final repo = ref.watch(taskRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.getInstances();
});

final dirtyTaskIdsProvider = StreamProvider<List<String>>((ref) {
  final localDataSource = ref.watch(hiveLocalDataSourceProvider);
  return localDataSource.watchDirtyTaskIds();
});

final unsyncedTasksProvider = Provider<List<TaskSchedule>>((ref) {
  final tasks = ref.watch(taskSchedulesProvider).valueOrNull ?? [];
  final dirtyIds = ref.watch(dirtyTaskIdsProvider).valueOrNull ?? [];
  return tasks
      .where((t) => t.hasPendingWrites || dirtyIds.contains(t.id))
      .toList();
});

final unsyncedInstancesProvider = Provider<List<TaskInstance>>((ref) {
  final instances = ref.watch(taskInstancesProvider).valueOrNull ?? [];
  final dirtyIds = ref.watch(dirtyTaskIdsProvider).valueOrNull ?? [];
  return instances
      .where((i) => i.hasPendingWrites || dirtyIds.contains(i.id))
      .toList();
});

final unsyncedCountProvider = Provider<int>((ref) {
  final unsyncedTasks = ref.watch(unsyncedTasksProvider);
  final unsyncedInstances = ref.watch(unsyncedInstancesProvider);
  return unsyncedTasks.length + unsyncedInstances.length;
});

final isFromCacheProvider = Provider<bool>((ref) {
  final tasks = ref.watch(taskSchedulesProvider).valueOrNull ?? [];
  final instances = ref.watch(taskInstancesProvider).valueOrNull ?? [];
  if (tasks.isEmpty && instances.isEmpty) return false;
  return tasks.every((t) => t.isFromCache) &&
      instances.every((i) => i.isFromCache);
});

final showUnsyncedBannerProvider = Provider<bool>((ref) {
  final hasSubscription = ref
      .watch(subscriptionServiceProvider)
      .isActivePremium;
  final isCache = ref.watch(isFromCacheProvider);
  final count = ref.watch(unsyncedCountProvider);
  return hasSubscription && (count > 0 || isCache);
});

final plannedMinutesPerDayProvider = Provider<Map<CivilDay, double>>((ref) {
  final instances = ref.watch(taskInstancesProvider).valueOrNull ?? [];
  final schedules = ref.watch(taskSchedulesProvider).valueOrNull ?? [];
  final currentUserId = ref.watch(authStateProvider).valueOrNull?.uid;

  final today = CivilDay.fromDateTime(AppClock.now);
  final startHorizon = today.addDays(-14);
  final endHorizon = today.addDays(60);

  final durationMap = <String, double>{};
  for (final s in schedules) {
    if (s.estimatedDuration != null) {
      durationMap[s.id] = s.estimatedDuration!.inMinutes.toDouble();
    }
  }

  final plannedMinutesPerDay = <CivilDay, double>{};

  for (final inst in instances) {
    if (inst.status == TaskStatus.skipped) continue;
    if (inst.assignedUserId != null && inst.assignedUserId != currentUserId) {
      continue;
    }

    final scheduledDate = inst.scheduledDate;
    if (scheduledDate.isBefore(startHorizon) ||
        scheduledDate.isAfter(endHorizon)) {
      continue;
    }

    final durationMins = durationMap[inst.scheduleId];
    if (durationMins != null) {
      plannedMinutesPerDay[scheduledDate] =
          (plannedMinutesPerDay[scheduledDate] ?? 0.0) + durationMins;
    }
  }

  return plannedMinutesPerDay;
});

final hasSuspectedStaleDataProvider = StreamProvider<bool>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null || user.uid.isEmpty) return Stream.value(false);

  final localDataSource = ref.watch(hiveLocalDataSourceProvider);
  return Rx.combineLatest3<bool, List<TaskSchedule>, List<TaskInstance>, bool>(
    localDataSource.watchMigrationCompleted(),
    localDataSource.watchTasks(),
    localDataSource.watchInstances(),
    (isMigrated, tasks, instances) {
      if (!isMigrated) return true;
      if (tasks.isNotEmpty && instances.isEmpty) return true;
      return false;
    },
  );
});

abstract class TaskRepository {
  String get userId;
  Stream<List<TaskSchedule>> getTasks();
  Stream<List<TaskInstance>> getInstances();
  Future<void> addTaskSchedule(TaskSchedule task);
  Future<void> updateTaskSchedule(TaskModification modification);
  Future<({TaskSchedule task, List<TaskInstance> pendingInstances})?>
  deleteTaskSchedule(String id);
  Future<void> restoreTaskSchedule(
    TaskSchedule task,
    List<TaskInstance> pendingInstances,
  );
  Future<TaskInstance?> completeTaskInstance(String id);
  Future<TaskInstance?> uncompleteTaskInstance(String id);
  Future<TaskInstance?> dismissTaskInstance(String id);
  Future<void> saveTaskInstance(TaskInstance instance);
  Future<void> undoResolveTaskInstance(TaskInstance resolvedInstance);
  Future<void> triggerMissedPolicyProcessing({
    Future<void> Function()? postProcess,
  });
  Future<void> resetLocalDataAndResync();
  Future<String?> getFamilyId();
  void dispose();
}
