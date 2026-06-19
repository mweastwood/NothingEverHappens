import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import 'app_clock.dart';
import 'civil_day.dart';
import 'relative_time.dart';
import 'task_schedule.dart';
import 'task_instance.dart';
import 'notification_service.dart';
import 'auth_repository.dart';
import 'scheduler_engine.dart';

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

        final action = SchedulerEngine.evaluate(task, taskInstances, now);

        for (final inst in action.instancesToUpdate) {
          batch.set(_instanceRefFor(inst, familyId), inst);
          hasChanges = true;
        }

        for (final inst in action.instancesToSpawn) {
          batch.set(_instanceRefFor(inst, familyId), inst);
          hasChanges = true;
        }

        if (action.updatedSchedule != null) {
          batch.set(
            _taskRefFor(action.updatedSchedule!, familyId),
            action.updatedSchedule!,
          );
          hasChanges = true;
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
      _spawnNextOccurrence(task, instance, now, batch, familyId);
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
      _spawnNextOccurrence(task, instance, now, batch, familyId);
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
      final nextId = _nextOccurrenceId(task, resolvedInstance, now);
      if (nextId != null) {
        batch.delete(
          _instanceRefForId(nextId, resolvedInstance.isFamily, familyId),
        );
      }
    }

    await batch.commit();
  }

  int _ruleIndexOfInstance(TaskSchedule task, TaskInstance instance) {
    if (task.schedules.length <= 1) return 0;
    final parts = instance.id.split('_');
    if (parts.isNotEmpty) {
      final idxStr = parts.last;
      final idx = int.tryParse(idxStr);
      if (idx != null && idx >= 0 && idx < task.schedules.length) {
        return idx;
      }
    }
    return 0;
  }

  RelativeTime _getCompletionRelativeDue(
    TaskScheduleRule rule,
    CompletionRelativePolicy policy,
    CivilDay newScheduledDate,
  ) {
    final originalStartRef = rule.startRelativeTime.referenceTo(
      rule.scheduledDate,
    );
    final originalDueRef = rule.dueRelativeTime.referenceTo(rule.scheduledDate);
    final duration = originalDueRef.difference(originalStartRef);

    final newStartRef = DateTime(
      newScheduledDate.year,
      newScheduledDate.month,
      newScheduledDate.day,
      policy.targetTime.hour,
      policy.targetTime.minute,
    );
    final newDueRef = newStartRef.add(duration);
    final dueDay = CivilDay.fromDateTime(newDueRef);
    return RelativeTime(
      dayOffset: dueDay
          .toDateTime()
          .difference(newScheduledDate.toDateTime())
          .inDays,
      time: TimeOfDay.fromDateTime(newDueRef),
    );
  }

  RelativeTime? _getCompletionRelativeNotification(
    TaskScheduleRule rule,
    CompletionRelativePolicy policy,
    CivilDay newScheduledDate,
  ) {
    if (rule.notificationRelativeTime == null) return null;
    final originalStartRef = rule.startRelativeTime.referenceTo(
      rule.scheduledDate,
    );
    final originalNotifRef = rule.notificationRelativeTime!.referenceTo(
      rule.scheduledDate,
    );
    final duration = originalNotifRef.difference(originalStartRef);

    final newStartRef = DateTime(
      newScheduledDate.year,
      newScheduledDate.month,
      newScheduledDate.day,
      policy.targetTime.hour,
      policy.targetTime.minute,
    );
    final newNotifRef = newStartRef.add(duration);
    final notifDay = CivilDay.fromDateTime(newNotifRef);
    return RelativeTime(
      dayOffset: notifDay
          .toDateTime()
          .difference(newScheduledDate.toDateTime())
          .inDays,
      time: TimeOfDay.fromDateTime(newNotifRef),
    );
  }

  void _spawnNextOccurrence(
    TaskSchedule task,
    TaskInstance completedInstance,
    DateTime now,
    WriteBatch batch,
    String? familyId,
  ) {
    final ruleIndex = _ruleIndexOfInstance(task, completedInstance);
    final rule = task.schedules[ruleIndex];
    if (rule.schedulingPolicy is CompletionRelativePolicy) {
      final policy = rule.schedulingPolicy as CompletionRelativePolicy;
      final nextDate = CivilDay.fromDateTime(now.add(policy.interval));
      final nextInstId = instanceIdFor(task, nextDate, ruleIndex);

      final startRelative = RelativeTime(dayOffset: 0, time: policy.targetTime);
      final dueRelative = _getCompletionRelativeDue(rule, policy, nextDate);
      final notifRelative = _getCompletionRelativeNotification(
        rule,
        policy,
        nextDate,
      );

      final newInst = TaskInstance(
        id: nextInstId,
        scheduleId: task.id,
        title: task.title,
        description: task.description,
        scheduledDate: nextDate,
        startRelativeTime: startRelative,
        dueRelativeTime: dueRelative,
        notificationRelativeTime: notifRelative,
        isFamily: task.isFamily,
        priority: task.priority,
        cycleId: task.cycleId,
        assignedUserId: task.assignedUserId,
        status: 'pending',
      );
      batch.set(_instanceRefFor(newInst, familyId), newInst);
    } else {
      final today = CivilDay.fromDateTime(now);
      final CivilDay refDate;
      final ruleMissedPolicy = rule.missedOccurrencePolicy.legacyPolicy;
      if (ruleMissedPolicy == MissedPolicy.stack ||
          ruleMissedPolicy == MissedPolicy.rollover ||
          today.isBefore(completedInstance.scheduledDate)) {
        refDate = completedInstance.scheduledDate.addDays(1);
      } else {
        refDate = today.addDays(1);
      }

      CivilDay? nextDate;
      if (rule.occursOn(refDate)) {
        nextDate = refDate;
      } else {
        final candidate = rule.nextOccurrenceAfter(refDate);
        if (candidate != null && !candidate.isBefore(refDate)) {
          nextDate = candidate;
        }
      }

      if (nextDate != null) {
        final nextInstId = instanceIdFor(task, nextDate, ruleIndex);
        final newInst = TaskInstance(
          id: nextInstId,
          scheduleId: task.id,
          title: task.title,
          description: task.description,
          scheduledDate: nextDate,
          startRelativeTime: rule.startRelativeTime,
          dueRelativeTime: rule.dueRelativeTime,
          notificationRelativeTime: rule.notificationRelativeTime,
          isFamily: task.isFamily,
          priority: task.priority,
          cycleId: task.cycleId,
          assignedUserId: task.assignedUserId,
          status: 'pending',
        );
        batch.set(_instanceRefFor(newInst, familyId), newInst);
      }
    }
  }

  String? _nextOccurrenceId(
    TaskSchedule task,
    TaskInstance completedInstance,
    DateTime now,
  ) {
    final ruleIndex = _ruleIndexOfInstance(task, completedInstance);
    final rule = task.schedules[ruleIndex];
    if (rule.schedulingPolicy is CompletionRelativePolicy) {
      final policy = rule.schedulingPolicy as CompletionRelativePolicy;
      final nextDate = CivilDay.fromDateTime(now.add(policy.interval));
      return instanceIdFor(task, nextDate, ruleIndex);
    } else {
      final today = CivilDay.fromDateTime(now);
      final CivilDay refDate;
      final ruleMissedPolicy = rule.missedOccurrencePolicy.legacyPolicy;
      if (ruleMissedPolicy == MissedPolicy.stack ||
          ruleMissedPolicy == MissedPolicy.rollover ||
          today.isBefore(completedInstance.scheduledDate)) {
        refDate = completedInstance.scheduledDate.addDays(1);
      } else {
        refDate = today.addDays(1);
      }

      CivilDay? nextDate;
      if (rule.occursOn(refDate)) {
        nextDate = refDate;
      } else {
        final candidate = rule.nextOccurrenceAfter(refDate);
        if (candidate != null && !candidate.isBefore(refDate)) {
          nextDate = candidate;
        }
      }

      if (nextDate != null) {
        return instanceIdFor(task, nextDate, ruleIndex);
      }
    }
    return null;
  }
}
