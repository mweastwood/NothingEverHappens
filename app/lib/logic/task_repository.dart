import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'app_clock.dart';
import 'relative_time.dart';
import 'task.dart';
import 'task_delta.dart';
import 'task_list.dart';
import 'notification_service.dart';

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

  CollectionReference<Task> get _tasksRef {
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('tasks')
        .withConverter<Task>(
          fromFirestore: (snapshot, _) => Task.fromFirestore(snapshot),
          toFirestore: (task, _) => task.toFirestore(),
        );
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

  Stream<List<Task>> getTasks() {
    return _tasksRef.snapshots().map((snapshot) {
      final tasks = snapshot.docs.map((doc) => doc.data()).toList();
      _checkAndProcessMissedPolicies(tasks);
      return tasks;
    });
  }

  void _checkAndProcessMissedPolicies(List<Task> tasks) async {
    if (_isProcessingMissedPolicies) return;
    _isProcessingMissedPolicies = true;

    try {
      final now = AppClock.now;

      final batch = _firestore.batch();
      bool hasChanges = false;

      for (final task in tasks) {
        // 1. Skip policy
        if (task.schedule is! OneOffSchedule &&
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
          batch.set(_historyRef.doc(deltaId), delta);

          final nextOccur = task.schedule.nextOccurrenceAfter(
            task.schedule.scheduledDate,
          );
          final newSchedule = task.schedule.copyWithStartDate(nextOccur);

          final firstOccurStart = task.dailyTimes.isNotEmpty
              ? RelativeTime(dayOffset: 0, time: task.dailyTimes[0].startTime)
              : task.startRelativeTime;
          final firstOccurDue = task.dailyTimes.isNotEmpty
              ? RelativeTime(dayOffset: 0, time: task.dailyTimes[0].dueTime)
              : task.dueRelativeTime;

          final updatedTask = Task(
            id: task.id,
            title: task.title,
            description: task.description,
            startRelativeTime: firstOccurStart,
            dueRelativeTime: firstOccurDue,
            schedule: newSchedule,
            dailyTimes: task.dailyTimes,
            activeOccurrenceIndex: 0,
            missedPolicy: task.missedPolicy,
            isMaster: task.isMaster,
            lastSpawnedDate: task.lastSpawnedDate,
            parentTaskId: task.parentTaskId,
            estimatedDuration: task.estimatedDuration,
          );

          batch.set(_tasksRef.doc(task.id), updatedTask);
          hasChanges = true;
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
    return _historyRef.orderBy('timestamp', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  Future<void> addTask(Task task) async {
    final newState = const TaskList([]).add(task, _userId);
    final delta = newState.history.last;

    final batch = _firestore.batch();

    batch.set(_tasksRef.doc(task.id), task);
    batch.set(_historyRef.doc(delta.id), delta);

    await batch.commit();
    await _notificationService?.scheduleNotifications(task);
  }

  Future<void> updateTask(TaskModification modification) async {
    final batch = _firestore.batch();

    batch.set(_tasksRef.doc(modification.newTask.id), modification.newTask);
    batch.set(_historyRef.doc(modification.delta.id), modification.delta);

    await batch.commit();
    await _notificationService?.scheduleNotifications(modification.newTask);
  }

  Future<void> deleteTask(String id) async {
    final newState = const TaskList([]).delete(id, _userId);
    final delta = newState.history.last;

    final batch = _firestore.batch();

    batch.delete(_tasksRef.doc(id));
    batch.set(_historyRef.doc(delta.id), delta);

    final spawnedDocs = await _tasksRef
        .where('parentTaskId', isEqualTo: id)
        .get();
    for (final doc in spawnedDocs.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
    await _notificationService?.cancelNotifications(id);
  }

  Future<void> completeTask(String id) async {
    final doc = await _tasksRef.doc(id).get();
    if (!doc.exists) return;
    final task = doc.data()!;

    final isRecurring = task.schedule is! OneOffSchedule;
    final newState = TaskList([task]).complete(id, _userId);
    final delta = newState.history.last;

    final batch = _firestore.batch();

    Task? updatedTask;
    if (isRecurring) {
      updatedTask = newState.activeTasks.firstWhere((t) => t.id == id);
      batch.set(_tasksRef.doc(id), updatedTask);
    } else {
      batch.delete(_tasksRef.doc(id));
    }

    batch.set(_historyRef.doc(delta.id), delta);

    await batch.commit();

    if (isRecurring && updatedTask != null) {
      await _notificationService?.scheduleNotifications(updatedTask);
    } else {
      await _notificationService?.cancelNotifications(id);
    }
  }
}
