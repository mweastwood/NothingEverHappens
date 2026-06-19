import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import 'app_clock.dart';
import 'civil_day.dart';
import 'task_schedule.dart';
import 'task_instance.dart';
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
          for (int i = 0; i < task.schedules.length; i++) {
            final s = task.schedules[i];
            final schedInstances = taskInstances.where((inst) {
              if (task.schedules.length <= 1) return true;
              return inst.id.endsWith('_$i');
            }).toList();

            final pendingForSchedule = schedInstances
                .where((inst) => inst.status == 'pending')
                .toList();

            final ruleMissedPolicy = s.missedOccurrencePolicy.legacyPolicy;

            if (ruleMissedPolicy == MissedPolicy.stack) {
              final lastSpawned = task.lastSpawnedDate;
              final minStartDate = s.scheduledDate;

              CivilDay checkDate = lastSpawned != null
                  ? lastSpawned.addDays(1)
                  : minStartDate;

              List<CivilDay> datesToSpawn = [];
              int daysChecked = 0;
              while ((checkDate.isBefore(today) || checkDate == today) &&
                  daysChecked < 30) {
                if (s.occursOn(checkDate)) {
                  datesToSpawn.add(checkDate);
                }
                if (datesToSpawn.length >= 30) {
                  break;
                }
                checkDate = checkDate.addDays(1);
                daysChecked++;
              }

              if (datesToSpawn.isNotEmpty) {
                for (final date in datesToSpawn) {
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
                  }
                }

                final latestSpawned = datesToSpawn.last;
                if (task.lastSpawnedDate == null ||
                    task.lastSpawnedDate!.isBefore(latestSpawned)) {
                  final updatedMaster = task.copyWith(
                    lastSpawnedDate: latestSpawned,
                  );
                  batch.set(
                    _taskRefFor(updatedMaster, familyId),
                    updatedMaster,
                  );
                }
                hasChanges = true;
              }
            } else if (ruleMissedPolicy == MissedPolicy.rollover ||
                ruleMissedPolicy == MissedPolicy.shift) {
              final hasPendingForSchedule = pendingForSchedule.isNotEmpty;

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
            } else if (s.missedOccurrencePolicy.type ==
                    MissedOccurrenceType.autoDismiss ||
                ruleMissedPolicy == MissedPolicy.skip) {
              final gracePeriod =
                  s.missedOccurrencePolicy.gracePeriod ?? Duration.zero;
              bool spawnedNext = false;
              for (final pending in pendingForSchedule) {
                final dueDateTime = pending.dueRelativeTime.referenceTo(
                  pending.scheduledDate,
                );
                final expirationTime = dueDateTime.add(gracePeriod);
                if (now.isAfter(expirationTime)) {
                  final updatedInst = pending.copyWith(status: 'skipped');
                  batch.set(
                    _instanceRefFor(updatedInst, familyId),
                    updatedInst,
                  );
                  hasChanges = true;

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
                    final dueDateTime = s.dueRelativeTime.referenceTo(
                      checkDate,
                    );
                    final expirationTime = dueDateTime.add(gracePeriod);
                    final isMissed = now.isAfter(expirationTime);
                    final status = isMissed ? 'skipped' : 'pending';

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
                      status: status,
                    );
                    batch.set(
                      _instanceRefFor(skippedInst, familyId),
                      skippedInst,
                    );
                    taskInstances.add(skippedInst);
                    schedInstances.add(skippedInst);
                    hasChanges = true;

                    if (isMissed) {
                      spawnedNext = true;
                    }
                  }
                }
                checkDate = checkDate.addDays(1);
                daysChecked++;
              }

              final hasActivePending = schedInstances.any((inst) {
                if (inst.status != 'pending') return false;
                final dueDateTime = inst.dueRelativeTime.referenceTo(
                  inst.scheduledDate,
                );
                final expirationTime = dueDateTime.add(gracePeriod);
                return !now.isAfter(expirationTime);
              });

              if (spawnedNext || !hasActivePending) {
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
                    taskInstances.add(newInst);
                    schedInstances.add(newInst);
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

    final newTask = modification.newTask;
    final changes = modification.changes;

    final isFamilyChanged = changes.containsKey('isFamily');

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

    final schedulesChanged = changes.containsKey('schedules');

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
    if (task == null) return null;

    final familyId = await _getFamilyId();
    final now = AppClock.now;

    final batch = _firestore.batch();

    final completedInstance = instance.copyWith(
      status: 'completed',
      completedByUserId: _userId,
      completedAt: now,
    );
    batch.set(_instanceRefFor(completedInstance, familyId), completedInstance);

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
    return completedInstance;
  }

  Future<TaskInstance?> dismissTaskInstance(String id) async {
    final instance = await _fetchInstance(id);
    if (instance == null) return null;

    final task = await _fetchTask(instance.scheduleId);
    if (task == null) return null;

    final familyId = await _getFamilyId();
    final now = AppClock.now;

    final batch = _firestore.batch();

    final dismissedInstance = instance.copyWith(
      status: 'dismissed',
      completedByUserId: _userId,
      completedAt: now,
    );
    batch.set(_instanceRefFor(dismissedInstance, familyId), dismissedInstance);

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
    return dismissedInstance;
  }

  Future<void> undoResolveTaskInstance(TaskInstance resolvedInstance) async {
    final task = await _fetchTask(resolvedInstance.scheduleId);
    if (task == null) return;

    final familyId = await _getFamilyId();
    final batch = _firestore.batch();

    final pendingInstance = resolvedInstance.copyWith(
      status: 'pending',
      clearCompletedByUserId: true,
      clearCompletedAt: true,
    );
    batch.set(_instanceRefFor(pendingInstance, familyId), pendingInstance);

    final isRecurring = task.schedules.any((s) => s is! OneOffSchedule);
    if (isRecurring) {
      final now = resolvedInstance.completedAt ?? AppClock.now;
      final today = CivilDay.fromDateTime(now);
      final CivilDay refDate;
      if (task.missedPolicy == MissedPolicy.stack ||
          task.missedPolicy == MissedPolicy.rollover ||
          today.isBefore(resolvedInstance.scheduledDate)) {
        refDate = resolvedInstance.scheduledDate.addDays(1);
      } else {
        refDate = today.addDays(1);
      }

      final nextOcc = nextOccurrenceRuleOfScheduleOnOrAfter(task, refDate);
      if (nextOcc != null) {
        final date = nextOcc.$1;
        final idx = nextOcc.$3;
        final nextInstId = instanceIdFor(task, date, idx);

        batch.delete(
          _instanceRefForId(nextInstId, resolvedInstance.isFamily, familyId),
        );
      }
    }

    await batch.commit();
  }
}
