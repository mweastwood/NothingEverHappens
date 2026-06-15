import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:rxdart/rxdart.dart';
import 'app_clock.dart';
import 'civil_day.dart';
import 'task_schedule.dart';
import 'task_instance.dart';
import 'task_delta.dart';
import 'task_list.dart';
import 'notification_service.dart';
import 'auth_repository.dart';

final taskRepositoryProvider = Provider<TaskRepository?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  return TaskRepository(
    userId: user.uid,
    notificationService: ref.watch(notificationServiceProvider),
  );
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

  String get userId => _userId;

  TaskRepository({
    FirebaseFirestore? firestore,
    required String userId,
    NotificationService? notificationService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _userId = userId,
       _notificationService = notificationService;

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

  CollectionReference<TaskDelta> get _historyRef {
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('history')
        .withConverter<TaskDelta>(
          fromFirestore: (snapshot, _) => TaskDelta.fromJson(snapshot.data()!),
          toFirestore: (delta, _) => delta.toJson(),
        );
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

  DocumentReference<TaskInstance> _instanceRefFor(
    TaskInstance instance,
    String? familyId,
  ) {
    if (instance.isFamily && familyId != null && familyId.isNotEmpty) {
      return _firestore
          .collection('families')
          .doc(familyId)
          .collection('instances')
          .doc(instance.id)
          .withConverter<TaskInstance>(
            fromFirestore: (snapshot, _) =>
                TaskInstance.fromFirestore(snapshot),
            toFirestore: (instance, _) => instance.toFirestore(),
          );
    }
    return _instancesRef.doc(instance.id);
  }

  DocumentReference<TaskDelta> _historyRefFor(
    TaskSchedule task,
    String? familyId,
    String deltaId,
  ) {
    if (task.isFamily && familyId != null && familyId.isNotEmpty) {
      return _firestore
          .collection('families')
          .doc(familyId)
          .collection('history')
          .doc(deltaId)
          .withConverter<TaskDelta>(
            fromFirestore: (snapshot, _) =>
                TaskDelta.fromJson(snapshot.data()!),
            toFirestore: (delta, _) => delta.toJson(),
          );
    }
    return _historyRef.doc(deltaId);
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

  String instanceIdFor(TaskSchedule task, CivilDay date, int ruleIndex) {
    final dateStr = date.toString();
    return task.schedules.length == 1
        ? '${task.id}_$dateStr'
        : '${task.id}_${dateStr}_$ruleIndex';
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
    if (_isProcessingMissedPolicies) return;
    _isProcessingMissedPolicies = true;

    try {
      final now = AppClock.now;
      final today = CivilDay.fromDateTime(now);
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

      final batch = _firestore.batch();
      bool hasChanges = false;

      for (final task in tasks) {
        final taskInstances = allInstances
            .where((inst) => inst.scheduleId == task.id)
            .toList();
        final pendingInstances = taskInstances
            .where((inst) => inst.status == 'pending')
            .toList();
        final isRecurring = task.schedules.any((s) => s is! OneOffSchedule);

        if (!isRecurring) {
          // One-Off Schedule: Ensure an instance exists for each OneOffSchedule in the task.
          for (int i = 0; i < task.schedules.length; i++) {
            final s = task.schedules[i];
            if (s is OneOffSchedule) {
              final instId = instanceIdFor(task, s.scheduledDate, i);
              final exists = taskInstances.any((inst) => inst.id == instId);
              if (!exists) {
                final newInst = TaskInstance(
                  id: instId,
                  scheduleId: task.id,
                  title: task.title,
                  description: task.description,
                  scheduledDate: s.scheduledDate,
                  startRelativeTime: s.startRelativeTime,
                  dueRelativeTime: s.dueRelativeTime,
                  notificationRelativeTime: s.notificationRelativeTime,
                  isFamily: task.isFamily,
                  priority: task.priority,
                  cycleId: task.cycleId,
                  assignedUserId: task.assignedUserId,
                  status: 'pending',
                );
                batch.set(_instanceRefFor(newInst, familyId), newInst);
                hasChanges = true;
              }
            }
          }
        } else {
          // Recurring Schedule
          if (task.missedPolicy == MissedPolicy.stack) {
            final lastSpawned = task.lastSpawnedDate;
            final minStartDate = task.schedules
                .map((s) => s.scheduledDate)
                .reduce((a, b) => a.isBefore(b) ? a : b);

            CivilDay checkDate = lastSpawned != null
                ? lastSpawned.addDays(1)
                : minStartDate;

            List<(CivilDay, TaskScheduleRule, int)> occurrencesToSpawn = [];
            int daysChecked = 0;
            while ((checkDate.isBefore(today) || checkDate == today) &&
                daysChecked < 30) {
              for (int i = 0; i < task.schedules.length; i++) {
                final s = task.schedules[i];
                if (s.occursOn(checkDate)) {
                  occurrencesToSpawn.add((checkDate, s, i));
                }
              }
              if (occurrencesToSpawn.length >= 30) {
                break;
              }
              checkDate = checkDate.addDays(1);
              daysChecked++;
            }

            if (occurrencesToSpawn.isNotEmpty) {
              for (final occ in occurrencesToSpawn) {
                final date = occ.$1;
                final s = occ.$2;
                final idx = occ.$3;

                final instId = instanceIdFor(task, date, idx);
                if (!taskInstances.any((inst) => inst.id == instId)) {
                  final newInst = TaskInstance(
                    id: instId,
                    scheduleId: task.id,
                    title: task.title,
                    description: task.description,
                    scheduledDate: date,
                    startRelativeTime: s.startRelativeTime,
                    dueRelativeTime: s.dueRelativeTime,
                    notificationRelativeTime: s.notificationRelativeTime,
                    isFamily: task.isFamily,
                    priority: task.priority,
                    cycleId: task.cycleId,
                    assignedUserId: task.assignedUserId,
                    status: 'pending',
                  );
                  batch.set(_instanceRefFor(newInst, familyId), newInst);
                }
              }

              final updatedMaster = task.copyWith(
                lastSpawnedDate: occurrencesToSpawn.last.$1,
              );
              batch.set(_taskRefFor(updatedMaster, familyId), updatedMaster);
              hasChanges = true;
            }
          } else if (task.missedPolicy == MissedPolicy.rollover ||
              task.missedPolicy == MissedPolicy.shift) {
            for (int i = 0; i < task.schedules.length; i++) {
              final s = task.schedules[i];
              final hasPendingForSchedule = pendingInstances.any((inst) {
                if (task.schedules.length <= 1) return true;
                return inst.id.endsWith('_$i');
              });

              if (!hasPendingForSchedule) {
                CivilDay? date;
                if (s.occursOn(today)) {
                  date = today;
                } else {
                  final candidate = s.nextOccurrenceAfter(today);
                  if (candidate != null && !candidate.isBefore(today)) {
                    date = candidate;
                  }
                }

                if (date != null) {
                  final instId = instanceIdFor(task, date, i);
                  if (!taskInstances.any((inst) => inst.id == instId)) {
                    final newInst = TaskInstance(
                      id: instId,
                      scheduleId: task.id,
                      title: task.title,
                      description: task.description,
                      scheduledDate: date,
                      startRelativeTime: s.startRelativeTime,
                      dueRelativeTime: s.dueRelativeTime,
                      notificationRelativeTime: s.notificationRelativeTime,
                      isFamily: task.isFamily,
                      priority: task.priority,
                      cycleId: task.cycleId,
                      assignedUserId: task.assignedUserId,
                      status: 'pending',
                    );
                    batch.set(_instanceRefFor(newInst, familyId), newInst);
                    hasChanges = true;
                  }
                }
              }
            }
          } else if (task.missedPolicy == MissedPolicy.skip) {
            for (int i = 0; i < task.schedules.length; i++) {
              final s = task.schedules[i];
              final schedInstances = taskInstances.where((inst) {
                if (task.schedules.length <= 1) return true;
                return inst.id.endsWith('_$i');
              }).toList();

              final pendingForSchedule = schedInstances
                  .where((inst) => inst.status == 'pending')
                  .toList();

              bool spawnedNext = false;
              for (final pending in pendingForSchedule) {
                if (pending.scheduledDate.isBefore(today)) {
                  final updatedInst = pending.copyWith(status: 'skipped');
                  batch.set(
                    _instanceRefFor(updatedInst, familyId),
                    updatedInst,
                  );
                  hasChanges = true;

                  final deltaId = const Uuid().v4();
                  final delta = TaskDelta(
                    id: deltaId,
                    taskId: task.id,
                    timestamp: now,
                    expiresAt: now.add(const Duration(days: 90)),
                    operation: 'skipped',
                    changedFields: {'instanceId': pending.id},
                    userId: _userId,
                  );
                  batch.set(_historyRefFor(task, familyId, deltaId), delta);
                  spawnedNext = true;
                }
              }

              // Backfill missed occurrences in the gap
              CivilDay? maxExistingDate;
              if (schedInstances.isNotEmpty) {
                maxExistingDate = schedInstances
                    .map((inst) => inst.scheduledDate)
                    .reduce((a, b) => a.isBefore(b) ? b : a);
              }

              CivilDay checkDate = maxExistingDate != null
                  ? maxExistingDate.addDays(1)
                  : s.scheduledDate;

              int daysChecked = 0;
              while (checkDate.isBefore(today) && daysChecked < 30) {
                if (s.occursOn(checkDate)) {
                  final instId = instanceIdFor(task, checkDate, i);
                  if (!taskInstances.any((inst) => inst.id == instId)) {
                    final skippedInst = TaskInstance(
                      id: instId,
                      scheduleId: task.id,
                      title: task.title,
                      description: task.description,
                      scheduledDate: checkDate,
                      startRelativeTime: s.startRelativeTime,
                      dueRelativeTime: s.dueRelativeTime,
                      notificationRelativeTime: s.notificationRelativeTime,
                      isFamily: task.isFamily,
                      priority: task.priority,
                      cycleId: task.cycleId,
                      assignedUserId: task.assignedUserId,
                      status: 'skipped',
                    );
                    batch.set(
                      _instanceRefFor(skippedInst, familyId),
                      skippedInst,
                    );
                    hasChanges = true;

                    final deltaId = const Uuid().v4();
                    final delta = TaskDelta(
                      id: deltaId,
                      taskId: task.id,
                      timestamp: now,
                      expiresAt: now.add(const Duration(days: 90)),
                      operation: 'skipped',
                      changedFields: {'instanceId': instId},
                      userId: _userId,
                    );
                    batch.set(_historyRefFor(task, familyId, deltaId), delta);
                    spawnedNext = true;
                  }
                }
                checkDate = checkDate.addDays(1);
                daysChecked++;
              }

              final hasFuturePending = schedInstances.any(
                (inst) =>
                    inst.status == 'pending' &&
                    (today.isBefore(inst.scheduledDate) ||
                        inst.scheduledDate == today),
              );

              if (spawnedNext || !hasFuturePending) {
                CivilDay? date;
                if (s.occursOn(today)) {
                  date = today;
                } else {
                  final candidate = s.nextOccurrenceAfter(today);
                  if (candidate != null && !candidate.isBefore(today)) {
                    date = candidate;
                  }
                }

                if (date != null) {
                  final instId = instanceIdFor(task, date, i);
                  final exists = taskInstances.any((inst) => inst.id == instId);
                  if (!exists) {
                    final newInst = TaskInstance(
                      id: instId,
                      scheduleId: task.id,
                      title: task.title,
                      description: task.description,
                      scheduledDate: date,
                      startRelativeTime: s.startRelativeTime,
                      dueRelativeTime: s.dueRelativeTime,
                      notificationRelativeTime: s.notificationRelativeTime,
                      isFamily: task.isFamily,
                      priority: task.priority,
                      cycleId: task.cycleId,
                      assignedUserId: task.assignedUserId,
                      status: 'pending',
                    );
                    batch.set(_instanceRefFor(newInst, familyId), newInst);
                    hasChanges = true;
                  }
                }
              }
            }
          }
        }
      }

      if (hasChanges) {
        await batch.commit();
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error in auto-processing missed policies: $e');
    } finally {
      _isProcessingMissedPolicies = false;
    }
  }

  Stream<List<TaskDelta>> getHistory() {
    return _firestore.collection('users').doc(_userId).snapshots().switchMap((
      userDoc,
    ) {
      final familyId = userDoc.data()?['familyId'] as String? ?? '';

      final personalStream = _historyRef
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) => doc.data()).toList();
          });

      if (familyId.isEmpty) {
        return personalStream;
      } else {
        final familyHistoryRef = _firestore
            .collection('families')
            .doc(familyId)
            .collection('history')
            .withConverter<TaskDelta>(
              fromFirestore: (snapshot, _) =>
                  TaskDelta.fromJson(snapshot.data()!),
              toFirestore: (delta, _) => delta.toJson(),
            );

        final familyStream = familyHistoryRef
            .orderBy('timestamp', descending: true)
            .snapshots()
            .map((snapshot) {
              return snapshot.docs.map((doc) => doc.data()).toList();
            });

        return Rx.combineLatest2<
          List<TaskDelta>,
          List<TaskDelta>,
          List<TaskDelta>
        >(personalStream, familyStream, (personal, family) {
          final all = [...personal, ...family]
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return all;
        });
      }
    });
  }

  Future<void> addTaskSchedule(TaskSchedule task) async {
    final familyId = await _getFamilyId();
    final newState = const TaskList([]).add(task, _userId);
    final delta = newState.history.last;

    final batch = _firestore.batch();

    batch.set(_taskRefFor(task, familyId), task);
    batch.set(_historyRefFor(task, familyId, delta.id), delta);

    await batch.commit();
    await _notificationService?.scheduleNotifications(task);

    _checkAndProcessMissedPolicies([task]);
  }

  Future<void> updateTaskSchedule(TaskModification modification) async {
    final familyId = await _getFamilyId();
    final batch = _firestore.batch();

    final newTask = modification.newTask;
    final delta = modification.delta;

    final isFamilyChanged = delta.changedFields.containsKey('isFamily');

    if (isFamilyChanged) {
      if (newTask.isFamily) {
        // Personal -> Family
        batch.delete(_tasksRef.doc(newTask.id));
        batch.set(_taskRefFor(newTask, familyId), newTask);
        batch.set(_historyRefFor(newTask, familyId, delta.id), delta);
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
        batch.set(_historyRef.doc(delta.id), delta);
      }
    } else {
      batch.set(_taskRefFor(newTask, familyId), newTask);
      batch.set(_historyRefFor(newTask, familyId, delta.id), delta);
    }

    final schedulesChanged = delta.changedFields.containsKey('schedules');

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

    final results = await Future.wait([
      personalSnapFuture,
      if (familySnapFuture != null) familySnapFuture,
    ]);

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

    if (schedulesChanged) {
      _checkAndProcessMissedPolicies([newTask]);
    }
  }

  Future<void> deleteTaskSchedule(String id) async {
    final task = await _fetchTask(id);
    if (task == null) return;

    final familyId = await _getFamilyId();
    final newState = const TaskList([]).delete(id, _userId);
    final delta = newState.history.last;

    final batch = _firestore.batch();

    batch.delete(_taskRefFor(task, familyId));
    batch.set(_historyRefFor(task, familyId, delta.id), delta);

    final personalInstances = await _instancesRef
        .where('scheduleId', isEqualTo: id)
        .get();
    for (final doc in personalInstances.docs) {
      if (doc.data().status == 'pending') {
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
          batch.delete(doc.reference);
        }
      }
    }

    await batch.commit();
    await _notificationService?.cancelNotifications(id);
  }

  Future<void> completeTaskInstance(String id) async {
    final instance = await _fetchInstance(id);
    if (instance == null) return;

    final task = await _fetchTask(instance.scheduleId);
    if (task == null) return;

    final familyId = await _getFamilyId();
    final now = AppClock.now;

    final batch = _firestore.batch();

    final completedInstance = instance.copyWith(
      status: 'completed',
      completedByUserId: _userId,
      completedAt: now,
    );
    batch.set(_instanceRefFor(completedInstance, familyId), completedInstance);

    final deltaId = const Uuid().v4();
    final delta = TaskDelta(
      id: deltaId,
      taskId: task.id,
      timestamp: now,
      expiresAt: now.add(const Duration(days: 90)),
      operation: 'completed',
      changedFields: {'instanceId': instance.id},
      userId: _userId,
    );
    batch.set(_historyRefFor(task, familyId, deltaId), delta);

    final isRecurring = task.schedules.any((s) => s is! OneOffSchedule);
    if (isRecurring) {
      final today = CivilDay.fromDateTime(now);
      final CivilDay refDate;
      if (task.missedPolicy == MissedPolicy.stack ||
          task.missedPolicy == MissedPolicy.rollover ||
          today.isBefore(instance.scheduledDate)) {
        refDate = instance.scheduledDate.addDays(1);
      } else {
        refDate = today.addDays(1);
      }

      final nextOcc = nextOccurrenceRuleOfScheduleOnOrAfter(task, refDate);
      if (nextOcc != null) {
        final date = nextOcc.$1;
        final s = nextOcc.$2;
        final idx = nextOcc.$3;
        final nextInstId = instanceIdFor(task, date, idx);

        final newInst = TaskInstance(
          id: nextInstId,
          scheduleId: task.id,
          title: task.title,
          description: task.description,
          scheduledDate: date,
          startRelativeTime: s.startRelativeTime,
          dueRelativeTime: s.dueRelativeTime,
          notificationRelativeTime: s.notificationRelativeTime,
          isFamily: task.isFamily,
          priority: task.priority,
          cycleId: task.cycleId,
          assignedUserId: task.assignedUserId,
          status: 'pending',
        );
        batch.set(_instanceRefFor(newInst, familyId), newInst);
      }
    }

    await batch.commit();
  }
}
