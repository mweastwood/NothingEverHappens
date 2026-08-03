import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import 'relative_time.dart';
import 'app_clock.dart';
import 'civil_day.dart';
import 'task_schedule.dart';
import 'task_instance.dart';
import 'notification_service.dart';
import 'auth_repository.dart';
import 'scheduler_engine.dart';
import 'task_spawner_engine.dart';
import 'user_settings.dart';

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
    return FirebaseFirestore.instance;
  } catch (_) {
    return null;
  }
});

final taskRepositoryProvider = Provider<TaskRepository?>((ref) {
  final firestore = ref.watch(firestoreProvider);
  if (firestore == null) return null;
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  final repo = TaskRepository(
    firestore: firestore,
    userId: user.uid,
    notificationService: ref.watch(notificationServiceProvider),
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
  } catch (_) {
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
      } catch (_) {}
    }
    dayChangeTimer.cancel();
  });

  return repo;
});

final taskSchedulesProvider = StreamProvider<List<TaskSchedule>>((ref) {
  final repo = ref.watch(taskRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.getTasks();
});

final taskInstancesProvider = StreamProvider<List<TaskInstance>>((ref) {
  final repo = ref.watch(taskRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.getInstances();
});

class TaskRepository {
  final FirebaseFirestore _firestore;
  final String _userId;
  final NotificationService? _notificationService;
  bool _isProcessingMissedPolicies = false;
  bool _needsProcessingAgain = false;
  List<TaskSchedule>? _nextTasksToProcess;
  Timer? _triggerTimer;
  DateTime? _scheduledTriggerTime;
  final Map<String, ({DateTime processedAt, String signature})>
  _lastProcessedTasks = {};
  final Map<String, DateTime> _spawnedInstancesCache = {};

  String get userId => _userId;

  TaskRepository({
    FirebaseFirestore? firestore,
    required String userId,
    NotificationService? notificationService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _userId = userId,
       _notificationService = notificationService;

  void dispose() {
    _triggerTimer?.cancel();
  }

  CollectionReference<TaskSchedule> _tasksRefForUser(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .withConverter<TaskSchedule>(
          fromFirestore: (snapshot, _) => TaskSchedule.fromFirestore(snapshot),
          toFirestore: (task, _) => task.toFirestore(),
        );
  }

  CollectionReference<TaskSchedule> get _tasksRef => _tasksRefForUser(_userId);

  Stream<List<TaskSchedule>> getPersonalTasksForUser(String userId) {
    return _tasksRefForUser(userId).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  CollectionReference<TaskInstance> _instancesRefForUser(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('instances')
        .withConverter<TaskInstance>(
          fromFirestore: (snapshot, _) => TaskInstance.fromFirestore(snapshot),
          toFirestore: (instance, _) => instance.toFirestore(),
        );
  }

  CollectionReference<TaskInstance> get _instancesRef =>
      _instancesRefForUser(_userId);

  Stream<List<TaskInstance>> getPersonalInstancesForUser(String userId) {
    return _instancesRefForUser(userId).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  Future<String?> _getFamilyId() async {
    final userDoc = await _firestore.collection('users').doc(_userId).get();
    return userDoc.data()?['familyId'] as String?;
  }

  DocumentReference<TaskSchedule> _taskRefFor(
    TaskSchedule task,
    String? familyId,
  ) {
    if (task.isFamily && familyId != null && familyId.isNotEmpty) {
      return _firestore
          .collection('families')
          .doc(familyId)
          .collection('tasks')
          .doc(task.id)
          .withConverter<TaskSchedule>(
            fromFirestore: (snapshot, _) =>
                TaskSchedule.fromFirestore(snapshot),
            toFirestore: (task, _) => task.toFirestore(),
          );
    }
    return _tasksRef.doc(task.id);
  }

  DocumentReference<TaskInstance> _instanceRefForId(
    String id,
    bool isFamily,
    String? familyId,
  ) {
    if (isFamily && familyId != null && familyId.isNotEmpty) {
      return _firestore
          .collection('families')
          .doc(familyId)
          .collection('instances')
          .doc(id)
          .withConverter<TaskInstance>(
            fromFirestore: (snapshot, _) =>
                TaskInstance.fromFirestore(snapshot),
            toFirestore: (instance, _) => instance.toFirestore(),
          );
    }
    return _instancesRef.doc(id);
  }

  DocumentReference<TaskInstance> _instanceRefFor(
    TaskInstance instance,
    String? familyId,
  ) {
    return _instanceRefForId(instance.id, instance.isFamily, familyId);
  }

  Future<TaskSchedule?> _fetchTask(String id) async {
    // Try personal first
    final personalDoc = await _tasksRef.doc(id).get();
    if (personalDoc.exists) return personalDoc.data();

    // If not found, check family collection
    final familyId = await _getFamilyId();
    if (familyId != null && familyId.isNotEmpty) {
      final familyDoc = await _firestore
          .collection('families')
          .doc(familyId)
          .collection('tasks')
          .doc(id)
          .withConverter<TaskSchedule>(
            fromFirestore: (snapshot, _) =>
                TaskSchedule.fromFirestore(snapshot),
            toFirestore: (task, _) => task.toFirestore(),
          )
          .get();
      if (familyDoc.exists) return familyDoc.data();
    }
    return null;
  }

  Future<TaskInstance?> _fetchInstance(String id) async {
    final personalDoc = await _instancesRef.doc(id).get();
    if (personalDoc.exists) return personalDoc.data();

    final familyId = await _getFamilyId();
    if (familyId != null && familyId.isNotEmpty) {
      final familyDoc = await _firestore
          .collection('families')
          .doc(familyId)
          .collection('instances')
          .doc(id)
          .withConverter<TaskInstance>(
            fromFirestore: (snapshot, _) =>
                TaskInstance.fromFirestore(snapshot),
            toFirestore: (instance, _) => instance.toFirestore(),
          )
          .get();
      if (familyDoc.exists) return familyDoc.data();
    }
    return null;
  }

  (CivilDay, TaskScheduleRule, int)? nextOccurrenceRuleOfScheduleOnOrAfter(
    TaskSchedule task,
    CivilDay ref,
  ) {
    CivilDay? earliestDate;
    TaskScheduleRule? earliestRule;
    int earliestIndex = -1;

    for (int i = 0; i < task.schedules.length; i++) {
      final s = task.schedules[i];
      CivilDay? next;
      if (s.occursOn(ref)) {
        next = ref;
      } else {
        final candidate = s.nextOccurrenceAfter(ref);
        if (candidate != null && !candidate.isBefore(ref)) {
          next = candidate;
        }
      }
      if (next != null) {
        if (earliestDate == null || next.isBefore(earliestDate)) {
          earliestDate = next;
          earliestRule = s;
          earliestIndex = i;
        }
      }
    }

    if (earliestDate != null && earliestRule != null) {
      return (earliestDate, earliestRule, earliestIndex);
    }
    return null;
  }

  Stream<List<TaskSchedule>> getTasks() {
    return _firestore.collection('users').doc(_userId).snapshots().switchMap((
      userDoc,
    ) {
      final familyId = userDoc.data()?['familyId'] as String? ?? '';

      final personalStream = _tasksRef.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) => doc.data()).toList();
      });

      if (familyId.isEmpty) {
        return personalStream.map((personalTasks) {
          _checkAndProcessMissedPolicies(personalTasks);
          return personalTasks;
        });
      } else {
        final familyTasksRef = _firestore
            .collection('families')
            .doc(familyId)
            .collection('tasks')
            .withConverter<TaskSchedule>(
              fromFirestore: (snapshot, _) =>
                  TaskSchedule.fromFirestore(snapshot),
              toFirestore: (task, _) => task.toFirestore(),
            );

        final familyStream = familyTasksRef.snapshots().map((snapshot) {
          return snapshot.docs.map((doc) => doc.data()).toList();
        });

        return Rx.combineLatest2<
          List<TaskSchedule>,
          List<TaskSchedule>,
          List<TaskSchedule>
        >(personalStream, familyStream, (personal, family) {
          final allTasks = [...personal, ...family];
          _checkAndProcessMissedPolicies(allTasks);
          return allTasks;
        });
      }
    });
  }

  Stream<List<TaskInstance>> getInstances() {
    return _firestore.collection('users').doc(_userId).snapshots().switchMap((
      userDoc,
    ) {
      final familyId = userDoc.data()?['familyId'] as String? ?? '';

      final personalStream = _instancesRef.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) => doc.data()).toList();
      });

      if (familyId.isEmpty) {
        return personalStream;
      } else {
        final familyInstancesRef = _firestore
            .collection('families')
            .doc(familyId)
            .collection('instances')
            .withConverter<TaskInstance>(
              fromFirestore: (snapshot, _) =>
                  TaskInstance.fromFirestore(snapshot),
              toFirestore: (instance, _) => instance.toFirestore(),
            );

        final familyStream = familyInstancesRef.snapshots().map((snapshot) {
          return snapshot.docs.map((doc) => doc.data()).toList();
        });

        return Rx.combineLatest2<
          List<TaskInstance>,
          List<TaskInstance>,
          List<TaskInstance>
        >(personalStream, familyStream, (personal, family) {
          return [...personal, ...family];
        });
      }
    });
  }

  void _checkAndProcessMissedPolicies(List<TaskSchedule> tasks) async {
    if (_isProcessingMissedPolicies) {
      _needsProcessingAgain = true;
      _nextTasksToProcess = tasks;
      return;
    }
    _isProcessingMissedPolicies = true;
    _needsProcessingAgain = false;

    try {
      final now = AppClock.now;

      final filteredTasks = tasks.where((task) {
        final lastProcessed = _lastProcessedTasks[task.id];
        if (lastProcessed != null) {
          final signature = _getScheduleSignature(task);
          if (lastProcessed.signature == signature &&
              now.difference(lastProcessed.processedAt).abs() <
                  const Duration(seconds: 2)) {
            return false;
          }
        }
        return true;
      }).toList();

      if (filteredTasks.isEmpty) {
        return;
      }

      final familyId = await _getFamilyId();

      // Fetch all instances
      final personalInstances = await _instancesRef.get();
      final List<TaskInstance> allInstances = personalInstances.docs
          .map((d) => d.data())
          .toList();
      if (familyId != null && familyId.isNotEmpty) {
        final familyInstancesRef = _firestore
            .collection('families')
            .doc(familyId)
            .collection('instances')
            .withConverter<TaskInstance>(
              fromFirestore: (snapshot, _) =>
                  TaskInstance.fromFirestore(snapshot),
              toFirestore: (instance, _) => instance.toFirestore(),
            );
        final familyInstances = await familyInstancesRef.get();
        allInstances.addAll(familyInstances.docs.map((d) => d.data()));
      }

      // Fetch user settings for capacity calculations
      final settingsSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('settings')
          .doc('agile')
          .get();
      final userSettings = UserSettings.fromJson(settingsSnapshot.data() ?? {});

      // Fetch all task schedules to build a lookup map for durations
      final personalTasksSnapshot = await _tasksRef.get();
      final List<TaskSchedule> allTasks = personalTasksSnapshot.docs
          .map((d) => d.data())
          .toList();
      if (familyId != null && familyId.isNotEmpty) {
        final familyTasksRef = _firestore
            .collection('families')
            .doc(familyId)
            .collection('tasks')
            .withConverter<TaskSchedule>(
              fromFirestore: (snapshot, _) =>
                  TaskSchedule.fromFirestore(snapshot),
              toFirestore: (task, _) => task.toFirestore(),
            );
        final familyTasks = await familyTasksRef.get();
        allTasks.addAll(familyTasks.docs.map((d) => d.data()));
      }
      final taskMap = {for (final t in allTasks) t.id: t};

      // Calculate planned hours per date
      final Map<CivilDay, double> dayPlannedHours = {};
      for (final inst in allInstances) {
        if (inst.status != 'skipped' && inst.status != 'failed') {
          final t = taskMap[inst.scheduleId];
          if (t != null && t.estimatedDuration != null) {
            final hours = t.estimatedDuration!.inMinutes / 60.0;
            dayPlannedHours[inst.scheduledDate] =
                (dayPlannedHours[inst.scheduledDate] ?? 0.0) + hours;
          }
        }
      }

      final Map<String, DateTime> lastCompletionCache = {};
      DateTime getLastCompletionTime(TaskSchedule task) {
        return lastCompletionCache.putIfAbsent(task.id, () {
          final completed = allInstances
              .where(
                (inst) =>
                    inst.scheduleId == task.id && inst.status == 'completed',
              )
              .toList();
          if (completed.isEmpty) {
            return DateTime.fromMillisecondsSinceEpoch(0);
          }
          return completed
              .map(
                (inst) =>
                    inst.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
              )
              .reduce((a, b) => a.isAfter(b) ? a : b);
        });
      }

      // Prioritize capacity-dependent tasks by Priority (High > Medium > Low)
      // If priority is equal, prioritize (evaluate first) the least recently completed task.
      filteredTasks.sort((a, b) {
        final pCompare = b.priority.index.compareTo(a.priority.index);
        if (pCompare != 0) return pCompare;

        if (a.skipIfNoCapacity && b.skipIfNoCapacity) {
          final aTime = getLastCompletionTime(a);
          final bTime = getLastCompletionTime(b);
          final timeCompare = aTime.compareTo(bTime);
          if (timeCompare != 0) return timeCompare;
        }

        return a.id.compareTo(b.id);
      });

      final batch = _firestore.batch();
      bool hasChanges = false;
      final List<DateTime> allTriggerTimes = [];

      for (final task in filteredTasks) {
        _lastProcessedTasks[task.id] = (
          processedAt: now,
          signature: _getScheduleSignature(task),
        );
        final taskInstances = allInstances
            .where((inst) => inst.scheduleId == task.id)
            .toList();

        final keysToRemove = <String>[];
        for (final entry in _spawnedInstancesCache.entries) {
          final key = entry.key;
          final spawnTime = entry.value;

          if (now.difference(spawnTime).abs() >= const Duration(seconds: 2)) {
            keysToRemove.add(key);
            continue;
          }

          final parts = key.split(':');
          if (parts.length == 3) {
            final sId = parts[0];
            final rId = parts[1];
            if (sId == task.id) {
              final dateParts = parts[2].split('-');
              if (dateParts.length == 3) {
                final date = CivilDay(
                  year: int.parse(dateParts[0]),
                  month: int.parse(dateParts[1]),
                  day: int.parse(dateParts[2]),
                );
                final exists = taskInstances.any(
                  (inst) => inst.ruleId == rId && inst.scheduledDate == date,
                );
                if (!exists) {
                  taskInstances.add(
                    TaskInstance(
                      id: 'VIRTUAL-${TaskInstance.generateId()}',
                      scheduleId: sId,
                      ruleId: rId,
                      title: task.title,
                      description: task.description,
                      scheduledDate: date,
                      startRelativeTime: RelativeTime(
                        dayOffset: 0,
                        time: const TimeOfDay(hour: 9, minute: 0),
                      ),
                      dueRelativeTime: RelativeTime(
                        dayOffset: 0,
                        time: const TimeOfDay(hour: 17, minute: 0),
                      ),
                      status: 'pending',
                    ),
                  );
                }
              }
            }
          }
        }
        for (final k in keysToRemove) {
          _spawnedInstancesCache.remove(k);
        }

        final action = SchedulerEngine.evaluate(
          task,
          taskInstances,
          now,
          userSettings: userSettings,
          dayPlannedHours: dayPlannedHours,
          applyCapacityLimits: task.assignedUserId == _userId,
        );

        for (final inst in action.instancesToUpdate) {
          batch.set(_instanceRefFor(inst, familyId), inst);
          hasChanges = true;
          // Update in-memory collections so subsequent evaluations see it
          final idx = allInstances.indexWhere((x) => x.id == inst.id);
          if (idx >= 0) {
            final oldInst = allInstances[idx];
            if (oldInst.status != 'skipped' && oldInst.status != 'failed') {
              final t = taskMap[oldInst.scheduleId];
              if (t != null && t.estimatedDuration != null) {
                final hours = t.estimatedDuration!.inMinutes / 60.0;
                dayPlannedHours[oldInst.scheduledDate] =
                    (dayPlannedHours[oldInst.scheduledDate] ?? 0.0) - hours;
              }
            }
            allInstances[idx] = inst;
            if (inst.status != 'skipped' && inst.status != 'failed') {
              final t = taskMap[inst.scheduleId];
              if (t != null && t.estimatedDuration != null) {
                final hours = t.estimatedDuration!.inMinutes / 60.0;
                dayPlannedHours[inst.scheduledDate] =
                    (dayPlannedHours[inst.scheduledDate] ?? 0.0) + hours;
              }
            }
          }
        }

        for (final inst in action.instancesToSpawn) {
          batch.set(_instanceRefFor(inst, familyId), inst);
          _spawnedInstancesCache['${inst.scheduleId}:${inst.ruleId}:${inst.scheduledDate}'] =
              now;
          hasChanges = true;
          // Add to in-memory collections so subsequent evaluations see it
          allInstances.add(inst);
          if (inst.status != 'skipped' && inst.status != 'failed') {
            final t = taskMap[inst.scheduleId];
            if (t != null && t.estimatedDuration != null) {
              final hours = t.estimatedDuration!.inMinutes / 60.0;
              dayPlannedHours[inst.scheduledDate] =
                  (dayPlannedHours[inst.scheduledDate] ?? 0.0) + hours;
            }
          }
        }

        for (final instId in action.instancesToDelete) {
          final inst = taskInstances.firstWhere((x) => x.id == instId);
          _spawnedInstancesCache.remove(
            '${inst.scheduleId}:${inst.ruleId}:${inst.scheduledDate}',
          );
          final isFamily = task.isFamily;
          batch.delete(_instanceRefForId(instId, isFamily, familyId));
          hasChanges = true;
          // Remove from in-memory collections so subsequent evaluations see it
          allInstances.removeWhere((x) => x.id == instId);
          if (inst.status != 'skipped' && inst.status != 'failed') {
            final t = taskMap[inst.scheduleId];
            if (t != null && t.estimatedDuration != null) {
              final hours = t.estimatedDuration!.inMinutes / 60.0;
              dayPlannedHours[inst.scheduledDate] =
                  (dayPlannedHours[inst.scheduledDate] ?? 0.0) - hours;
            }
          }
        }

        if (action.updatedSchedule != null) {
          batch.set(
            _taskRefFor(action.updatedSchedule!, familyId),
            action.updatedSchedule!,
          );
          hasChanges = true;
        }

        allTriggerTimes.addAll(action.triggerTimes);
      }

      if (hasChanges) {
        await batch.commit();
      }

      // Schedule dynamic timer for next critical time
      allTriggerTimes.sort();
      final nextTrigger = allTriggerTimes.firstWhere(
        (t) => t.isAfter(now),
        orElse: () => DateTime.fromMillisecondsSinceEpoch(0),
      );
      if (nextTrigger.millisecondsSinceEpoch > 0) {
        _scheduleTriggerTimer(nextTrigger);
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error in auto-processing missed policies: $e');
    } finally {
      _isProcessingMissedPolicies = false;
      if (_needsProcessingAgain && _nextTasksToProcess != null) {
        final next = _nextTasksToProcess!;
        _nextTasksToProcess = null;
        _checkAndProcessMissedPolicies(next);
      }
    }
  }

  void _scheduleTriggerTimer(DateTime triggerTime) {
    if (_scheduledTriggerTime != null &&
        !_scheduledTriggerTime!.isAfter(triggerTime)) {
      return;
    }
    _triggerTimer?.cancel();
    _scheduledTriggerTime = triggerTime;
    final delay = triggerTime.difference(AppClock.now);
    _triggerTimer = Timer(delay, () {
      _scheduledTriggerTime = null;
      triggerMissedPolicyProcessing();
    });
  }

  Future<void> triggerMissedPolicyProcessing() async {
    try {
      _lastProcessedTasks.clear();
      final familyId = await _getFamilyId();
      final personalTasksSnap = await _tasksRef.get();
      final List<TaskSchedule> allTasks = personalTasksSnap.docs
          .map((d) => d.data())
          .toList();

      if (familyId != null && familyId.isNotEmpty) {
        final familyTasksRef = _firestore
            .collection('families')
            .doc(familyId)
            .collection('tasks')
            .withConverter<TaskSchedule>(
              fromFirestore: (snapshot, _) =>
                  TaskSchedule.fromFirestore(snapshot),
              toFirestore: (task, _) => task.toFirestore(),
            );
        final familyTasksSnap = await familyTasksRef.get();
        allTasks.addAll(familyTasksSnap.docs.map((d) => d.data()));
      }

      _checkAndProcessMissedPolicies(allTasks);
    } catch (e) {
      // ignore: avoid_print
      print('Error in triggering missed policy processing: $e');
    }
  }

  Future<void> addTaskSchedule(TaskSchedule task) async {
    final familyId = await _getFamilyId();
    final batch = _firestore.batch();

    batch.set(_taskRefFor(task, familyId), task);

    await batch.commit();
    await _notificationService?.scheduleNotifications(task);

    _checkAndProcessMissedPolicies([task]);
  }

  Future<void> updateTaskSchedule(TaskModification modification) async {
    final familyId = await _getFamilyId();
    final batch = _firestore.batch();

    var newTask = modification.newTask;
    final changes = modification.changes;

    final isFamilyChanged = changes.containsKey('isFamily');
    final schedulesChanged = changes.containsKey('schedules');

    if (schedulesChanged) {
      final yesterday = CivilDay.fromDateTime(AppClock.now).addDays(-1);
      newTask = newTask.copyWith(lastSpawnedDate: yesterday);
    }

    if (isFamilyChanged) {
      if (newTask.isFamily) {
        // Personal -> Family
        batch.delete(_tasksRef.doc(newTask.id));
        batch.set(_taskRefFor(newTask, familyId), newTask);
      } else {
        // Family -> Personal
        final familyDocRef = (familyId != null && familyId.isNotEmpty)
            ? _firestore
                  .collection('families')
                  .doc(familyId)
                  .collection('tasks')
                  .doc(newTask.id)
            : null;
        if (familyDocRef != null) {
          batch.delete(familyDocRef);
        }
        batch.set(_tasksRef.doc(newTask.id), newTask);
      }
    } else {
      batch.set(_taskRefFor(newTask, familyId), newTask);
    }

    final List<DocumentSnapshot<TaskInstance>> personalPending = [];
    final List<DocumentSnapshot<TaskInstance>> familyPending = [];

    final personalSnapFuture = _instancesRef
        .where('scheduleId', isEqualTo: newTask.id)
        .get();

    final Future<QuerySnapshot<TaskInstance>>? familySnapFuture =
        (familyId != null && familyId.isNotEmpty)
        ? _firestore
              .collection('families')
              .doc(familyId)
              .collection('instances')
              .withConverter<TaskInstance>(
                fromFirestore: (snapshot, _) =>
                    TaskInstance.fromFirestore(snapshot),
                toFirestore: (instance, _) => instance.toFirestore(),
              )
              .where('scheduleId', isEqualTo: newTask.id)
              .get()
        : null;

    final results = await Future.wait([personalSnapFuture, ?familySnapFuture]);

    final personalSnap = results[0];
    for (final doc in personalSnap.docs) {
      if (doc.data().status == 'pending') {
        personalPending.add(doc);
      }
    }

    if (familySnapFuture != null) {
      final familySnap = results[1];
      for (final doc in familySnap.docs) {
        if (doc.data().status == 'pending') {
          familyPending.add(doc);
        }
      }
    }

    final allPending = [...personalPending, ...familyPending];

    if (schedulesChanged) {
      for (final doc in allPending) {
        batch.delete(doc.reference);
      }
    } else {
      for (final doc in allPending) {
        final updatedInst = doc.data()!.copyWith(
          title: newTask.title,
          description: newTask.description,
          priority: newTask.priority,
          isFamily: newTask.isFamily,
          cycleId: newTask.cycleId,
          clearCycleId: newTask.cycleId == null,
          assignedUserId: newTask.assignedUserId,
          clearAssignedUserId: newTask.assignedUserId == null,
        );

        if (isFamilyChanged) {
          batch.delete(doc.reference);
          if (newTask.isFamily) {
            batch.set(_instanceRefFor(updatedInst, familyId), updatedInst);
          } else {
            batch.set(_instancesRef.doc(updatedInst.id), updatedInst);
          }
        } else {
          batch.set(doc.reference, updatedInst);
        }
      }
    }

    await batch.commit();
    await _notificationService?.scheduleNotifications(newTask);

    if (schedulesChanged || changes.containsKey('futureInstancesCount')) {
      _checkAndProcessMissedPolicies([newTask]);
    }
  }

  Future<({TaskSchedule task, List<TaskInstance> pendingInstances})?>
  deleteTaskSchedule(String id) async {
    final task = await _fetchTask(id);
    if (task == null) return null;

    final familyId = await _getFamilyId();
    final batch = _firestore.batch();

    batch.delete(_taskRefFor(task, familyId));

    final List<TaskInstance> pendingInstances = [];

    final personalInstances = await _instancesRef
        .where('scheduleId', isEqualTo: id)
        .get();
    for (final doc in personalInstances.docs) {
      if (doc.data().status == 'pending') {
        pendingInstances.add(doc.data());
        batch.delete(doc.reference);
      }
    }

    if (familyId != null && familyId.isNotEmpty) {
      final familyInstances = await _firestore
          .collection('families')
          .doc(familyId)
          .collection('instances')
          .where('scheduleId', isEqualTo: id)
          .withConverter<TaskInstance>(
            fromFirestore: (snapshot, _) =>
                TaskInstance.fromFirestore(snapshot),
            toFirestore: (instance, _) => instance.toFirestore(),
          )
          .get();
      for (final doc in familyInstances.docs) {
        if (doc.data().status == 'pending') {
          pendingInstances.add(doc.data());
          batch.delete(doc.reference);
        }
      }
    }

    await batch.commit();
    await _notificationService?.cancelNotifications(id);
    _spawnedInstancesCache.removeWhere((key, value) => key.startsWith('$id:'));

    return (task: task, pendingInstances: pendingInstances);
  }

  Future<void> restoreTaskSchedule(
    TaskSchedule task,
    List<TaskInstance> pendingInstances,
  ) async {
    final familyId = await _getFamilyId();
    final batch = _firestore.batch();

    batch.set(_taskRefFor(task, familyId), task);

    for (final inst in pendingInstances) {
      batch.set(_instanceRefFor(inst, familyId), inst);
    }

    await batch.commit();
    await _notificationService?.scheduleNotifications(task);
  }

  Future<TaskInstance?> completeTaskInstance(String id) async {
    final instance = await _fetchInstance(id);
    if (instance == null) return null;

    final task = await _fetchTask(instance.scheduleId);

    final familyId = await _getFamilyId();
    final now = AppClock.now;

    final batch = _firestore.batch();

    final completedInstance = instance.copyWith(
      status: 'completed',
      completedByUserId: _userId,
      completedAt: now,
    );
    batch.set(_instanceRefFor(completedInstance, familyId), completedInstance);
    _spawnedInstancesCache.remove(
      '${instance.scheduleId}:${instance.ruleId}:${instance.scheduledDate}',
    );

    if (task != null) {
      final isRecurring = task.schedules.any((s) => s is! OneOffSchedule);
      if (isRecurring) {
        final allInstances = await _getInstancesForSchedule(
          task.id,
          task.isFamily,
          familyId,
        );
        _spawnNextOccurrence(
          task,
          instance,
          now,
          batch,
          familyId,
          allInstances,
        );
      }
    }

    await batch.commit();
    return completedInstance;
  }

  Future<TaskInstance?> dismissTaskInstance(String id) async {
    final instance = await _fetchInstance(id);
    if (instance == null) return null;

    final task = await _fetchTask(instance.scheduleId);

    final familyId = await _getFamilyId();
    final now = AppClock.now;

    final batch = _firestore.batch();

    final dismissedInstance = instance.copyWith(
      status: 'dismissed',
      completedByUserId: _userId,
      completedAt: now,
    );
    batch.set(_instanceRefFor(dismissedInstance, familyId), dismissedInstance);
    _spawnedInstancesCache.remove(
      '${instance.scheduleId}:${instance.ruleId}:${instance.scheduledDate}',
    );

    if (task != null) {
      final isRecurring = task.schedules.any((s) => s is! OneOffSchedule);
      if (isRecurring) {
        final allInstances = await _getInstancesForSchedule(
          task.id,
          task.isFamily,
          familyId,
        );
        _spawnNextOccurrence(
          task,
          instance,
          now,
          batch,
          familyId,
          allInstances,
        );
      }
    }

    await batch.commit();
    return dismissedInstance;
  }

  Future<void> undoResolveTaskInstance(TaskInstance resolvedInstance) async {
    final task = await _fetchTask(resolvedInstance.scheduleId);

    final familyId = await _getFamilyId();
    final batch = _firestore.batch();
    final now = resolvedInstance.completedAt ?? AppClock.now;

    final pendingInstance = resolvedInstance.copyWith(
      status: 'pending',
      clearCompletedByUserId: true,
      clearCompletedAt: true,
    );
    batch.set(_instanceRefFor(pendingInstance, familyId), pendingInstance);
    _spawnedInstancesCache['${resolvedInstance.scheduleId}:${resolvedInstance.ruleId}:${resolvedInstance.scheduledDate}'] =
        now;

    if (task != null) {
      final isRecurring = task.schedules.any((s) => s is! OneOffSchedule);
      if (isRecurring) {
        final allInstances = await _getInstancesForSchedule(
          task.id,
          task.isFamily,
          familyId,
        );
        final nextId = _nextOccurrenceId(
          task,
          resolvedInstance,
          now,
          allInstances,
        );
        if (nextId != null) {
          final nextInst = allInstances.firstWhere((x) => x.id == nextId);
          _spawnedInstancesCache.remove(
            '${nextInst.scheduleId}:${nextInst.ruleId}:${nextInst.scheduledDate}',
          );
          batch.delete(
            _instanceRefForId(nextId, resolvedInstance.isFamily, familyId),
          );
        }
      }
    }

    await batch.commit();
  }

  Future<List<TaskInstance>> _getInstancesForSchedule(
    String scheduleId,
    bool isFamily,
    String? familyId,
  ) async {
    if (isFamily && familyId != null && familyId.isNotEmpty) {
      final familySnap = await _firestore
          .collection('families')
          .doc(familyId)
          .collection('instances')
          .withConverter<TaskInstance>(
            fromFirestore: (snapshot, _) =>
                TaskInstance.fromFirestore(snapshot),
            toFirestore: (instance, _) => instance.toFirestore(),
          )
          .where('scheduleId', isEqualTo: scheduleId)
          .get();
      return familySnap.docs.map((d) => d.data()).toList();
    }
    final personalSnap = await _instancesRef
        .where('scheduleId', isEqualTo: scheduleId)
        .get();
    return personalSnap.docs.map((d) => d.data()).toList();
  }

  void _spawnNextOccurrence(
    TaskSchedule task,
    TaskInstance completedInstance,
    DateTime now,
    WriteBatch batch,
    String? familyId,
    List<TaskInstance> taskInstances,
  ) {
    final nextInst = TaskSpawnerEngine.calculateNextOccurrence(
      task: task,
      completedInstance: completedInstance,
      completionTime: now,
      existingInstances: taskInstances,
    );
    if (nextInst != null) {
      batch.set(_instanceRefFor(nextInst, familyId), nextInst);
      _spawnedInstancesCache['${nextInst.scheduleId}:${nextInst.ruleId}:${nextInst.scheduledDate}'] =
          now;
    }
  }

  String? _nextOccurrenceId(
    TaskSchedule task,
    TaskInstance completedInstance,
    DateTime now,
    List<TaskInstance> taskInstances,
  ) {
    return TaskSpawnerEngine.calculateOccurrenceIdToUndo(
      task: task,
      completedInstance: completedInstance,
      completionTime: now,
      existingInstances: taskInstances,
    );
  }

  String _getScheduleSignature(TaskSchedule task) {
    return TaskSpawnerEngine.computeScheduleSignature(task);
  }
}
