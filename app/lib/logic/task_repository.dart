import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:rxdart/rxdart.dart';
import 'app_clock.dart';
import 'civil_day.dart';
import 'task.dart';
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

  CollectionReference<Task> _tasksRefForUser(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .withConverter<Task>(
          fromFirestore: (snapshot, _) => Task.fromFirestore(snapshot),
          toFirestore: (task, _) => task.toFirestore(),
        );
  }

  CollectionReference<Task> get _tasksRef => _tasksRefForUser(_userId);

  Stream<List<Task>> getPersonalTasksForUser(String userId) {
    return _tasksRefForUser(userId).snapshots().map((snapshot) {
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

  DocumentReference<Task> _taskRefFor(Task task, String? familyId) {
    if (task.isFamily && familyId != null && familyId.isNotEmpty) {
      return _firestore
          .collection('families')
          .doc(familyId)
          .collection('tasks')
          .doc(task.id)
          .withConverter<Task>(
            fromFirestore: (snapshot, _) => Task.fromFirestore(snapshot),
            toFirestore: (task, _) => task.toFirestore(),
          );
    }
    return _tasksRef.doc(task.id);
  }

  DocumentReference<TaskDelta> _historyRefFor(
    Task task,
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

  Future<Task?> _fetchTask(String id) async {
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
          .withConverter<Task>(
            fromFirestore: (snapshot, _) => Task.fromFirestore(snapshot),
            toFirestore: (task, _) => task.toFirestore(),
          )
          .get();
      if (familyDoc.exists) return familyDoc.data();
    }
    return null;
  }

  Stream<List<Task>> getTasks() {
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
            .withConverter<Task>(
              fromFirestore: (snapshot, _) => Task.fromFirestore(snapshot),
              toFirestore: (task, _) => task.toFirestore(),
            );

        final familyStream = familyTasksRef.snapshots().map((snapshot) {
          return snapshot.docs.map((doc) => doc.data()).toList();
        });

        return Rx.combineLatest2<List<Task>, List<Task>, List<Task>>(
          personalStream,
          familyStream,
          (personal, family) {
            final allTasks = [...personal, ...family];
            _checkAndProcessMissedPolicies(allTasks);
            return allTasks;
          },
        );
      }
    });
  }

  void _checkAndProcessMissedPolicies(List<Task> tasks) async {
    if (_isProcessingMissedPolicies) return;
    _isProcessingMissedPolicies = true;

    try {
      final now = AppClock.now;
      final today = CivilDay.fromDateTime(now);
      final familyId = await _getFamilyId();

      final batch = _firestore.batch();
      bool hasChanges = false;

      for (final task in tasks) {
        // 1. Skip policy
        final isRecurring = task.schedules.any((s) => s is! OneOffSchedule);
        if (isRecurring &&
            task.missedPolicy == MissedPolicy.skip &&
            task.isOverdue(now)) {
          final deltaId = const Uuid().v4();
          final delta = TaskDelta(
            id: deltaId,
            taskId: task.id,
            timestamp: now,
            expiresAt: now.add(const Duration(days: 90)),
            operation: 'skipped',
            changedFields: {},
            userId: _userId,
          );
          batch.set(_historyRefFor(task, familyId, deltaId), delta);

          final today = CivilDay.fromDateTime(now);
          final List<TaskSchedule> list = [];
          for (final s in task.schedules) {
            if (s is OneOffSchedule) {
              if (s.scheduledDate.isBefore(today) || s.scheduledDate == today) {
                continue;
              }
              list.add(s);
            } else {
              if (s.scheduledDate.isBefore(today) || s.scheduledDate == today) {
                final nextOccur = s.nextOccurrenceAfter(s.scheduledDate);
                list.add(s.copyWithStartDate(nextOccur));
              } else {
                list.add(s);
              }
            }
          }
          final newSchedules = list;

          final updatedTask = Task(
            id: task.id,
            title: task.title,
            description: task.description,
            schedules: newSchedules,
            activeOccurrenceIndex: 0,
            missedPolicy: task.missedPolicy,
            isMaster: task.isMaster,
            lastSpawnedDate: task.lastSpawnedDate,
            parentTaskId: task.parentTaskId,
            estimatedDuration: task.estimatedDuration,
            isFamily: task.isFamily,
            priority: task.priority,
            cycleId: task.cycleId,
            preferredBy: task.preferredBy,
            assignedUserId: task.assignedUserId,
          );

          batch.set(_taskRefFor(updatedTask, familyId), updatedTask);
          hasChanges = true;
        }

        // 2. Stack policy
        if (task.isMaster && task.missedPolicy == MissedPolicy.stack) {
          final lastSpawned = task.lastSpawnedDate;
          final minStartDate = task.schedules
              .map((s) => s.scheduledDate)
              .reduce((a, b) => a.isBefore(b) ? a : b);

          CivilDay checkDate = lastSpawned != null
              ? lastSpawned.addDays(1)
              : minStartDate;

          List<(CivilDay, TaskSchedule, int)> occurrencesToSpawn = [];
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
            for (final occurrence in occurrencesToSpawn) {
              final date = occurrence.$1;
              final s = occurrence.$2;
              final idx = occurrence.$3;

              final dateStr =
                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              final spawnedId = task.schedules.length == 1
                  ? '${task.id}_$dateStr'
                  : '${task.id}_${dateStr}_$idx';

              final spawnedTask = Task(
                id: spawnedId,
                title: task.title,
                description: task.description,
                schedules: [
                  OneOffSchedule(
                    date: date,
                    startRelativeTime: s.startRelativeTime,
                    dueRelativeTime: s.dueRelativeTime,
                    notificationRelativeTime: s.notificationRelativeTime,
                  ),
                ],
                parentTaskId: task.id,
                missedPolicy: task.missedPolicy,
                estimatedDuration: task.estimatedDuration,
                isFamily: task.isFamily,
                priority: task.priority,
                cycleId: task.cycleId,
                preferredBy: task.preferredBy,
                assignedUserId: task.assignedUserId,
              );
              batch.set(_taskRefFor(spawnedTask, familyId), spawnedTask);
            }

            final updatedMaster = Task(
              id: task.id,
              title: task.title,
              description: task.description,
              schedules: task.schedules,
              activeOccurrenceIndex: task.activeOccurrenceIndex,
              missedPolicy: task.missedPolicy,
              isMaster: true,
              lastSpawnedDate: occurrencesToSpawn.last.$1,
              estimatedDuration: task.estimatedDuration,
              isFamily: task.isFamily,
              priority: task.priority,
              cycleId: task.cycleId,
              preferredBy: task.preferredBy,
              assignedUserId: task.assignedUserId,
            );
            batch.set(_taskRefFor(updatedMaster, familyId), updatedMaster);
            hasChanges = true;
          }
        }
      }

      if (hasChanges) {
        try {
          await batch.commit();
        } catch (e) {
          // ignore: avoid_print
          print('Error in auto-processing missed policies: $e');
        }
      }
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

  Future<void> addTask(Task task) async {
    final familyId = await _getFamilyId();
    final newState = const TaskList([]).add(task, _userId);
    final delta = newState.history.last;

    final batch = _firestore.batch();

    batch.set(_taskRefFor(task, familyId), task);
    batch.set(_historyRefFor(task, familyId, delta.id), delta);

    await batch.commit();
    await _notificationService?.scheduleNotifications(task);
  }

  Future<void> updateTask(TaskModification modification) async {
    final familyId = await _getFamilyId();
    final batch = _firestore.batch();

    final newTask = modification.newTask;
    final delta = modification.delta;

    // Detect if task scope was migrated Personal <-> Family
    final personalDoc = await _tasksRef.doc(newTask.id).get();
    final currentlyPersonal = personalDoc.exists;

    final familyDocRef = (familyId != null && familyId.isNotEmpty)
        ? _firestore
              .collection('families')
              .doc(familyId)
              .collection('tasks')
              .doc(newTask.id)
        : null;

    bool currentlyFamily = false;
    if (familyDocRef != null) {
      final familyDoc = await familyDocRef.get();
      currentlyFamily = familyDoc.exists;
    }

    if (newTask.isFamily && currentlyPersonal) {
      // Migrate: Delete from personal, write to family
      batch.delete(_tasksRef.doc(newTask.id));
      batch.set(_taskRefFor(newTask, familyId), newTask);
      batch.set(_historyRefFor(newTask, familyId, delta.id), delta);
    } else if (!newTask.isFamily && currentlyFamily) {
      // Migrate: Delete from family, write to personal
      if (familyDocRef != null) {
        batch.delete(familyDocRef);
      }
      batch.set(_tasksRef.doc(newTask.id), newTask);
      batch.set(_historyRef.doc(delta.id), delta);
    } else {
      // Standard update: update in respective active collection
      batch.set(_taskRefFor(newTask, familyId), newTask);
      batch.set(_historyRefFor(newTask, familyId, delta.id), delta);
    }

    await batch.commit();
    await _notificationService?.scheduleNotifications(newTask);
  }

  Future<void> deleteTask(String id) async {
    final task = await _fetchTask(id);
    if (task == null) return;

    final familyId = await _getFamilyId();
    final newState = const TaskList([]).delete(id, _userId);
    final delta = newState.history.last;

    final batch = _firestore.batch();

    batch.delete(_taskRefFor(task, familyId));
    batch.set(_historyRefFor(task, familyId, delta.id), delta);

    if (task.isFamily && familyId != null && familyId.isNotEmpty) {
      final spawnedDocs = await _firestore
          .collection('families')
          .doc(familyId)
          .collection('tasks')
          .where('parentTaskId', isEqualTo: id)
          .get();
      for (final doc in spawnedDocs.docs) {
        batch.delete(doc.reference);
      }
    } else {
      final spawnedDocs = await _tasksRef
          .where('parentTaskId', isEqualTo: id)
          .get();
      for (final doc in spawnedDocs.docs) {
        batch.delete(doc.reference);
      }
    }

    await batch.commit();
    await _notificationService?.cancelNotifications(id);
  }

  Future<void> completeTask(String id) async {
    final task = await _fetchTask(id);
    if (task == null) return;

    final familyId = await _getFamilyId();
    final newState = TaskList([task]).complete(id, _userId);
    final delta = newState.history.last;
    final taskStillExists = newState.activeTasks.any((t) => t.id == id);

    final batch = _firestore.batch();

    Task? updatedTask;
    if (taskStillExists) {
      updatedTask = newState.activeTasks.firstWhere((t) => t.id == id);
      batch.set(_taskRefFor(task, familyId), updatedTask);
    } else {
      batch.delete(_taskRefFor(task, familyId));
    }

    batch.set(_historyRefFor(task, familyId, delta.id), delta);

    await batch.commit();

    if (taskStillExists && updatedTask != null) {
      await _notificationService?.scheduleNotifications(updatedTask);
    } else {
      await _notificationService?.cancelNotifications(id);
    }
  }
}
