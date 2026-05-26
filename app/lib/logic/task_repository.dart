import 'package:cloud_firestore/cloud_firestore.dart';
import 'task.dart';
import 'task_delta.dart';
import 'task_list.dart';
import 'notification_service.dart';

class TaskRepository {
  final FirebaseFirestore _firestore;
  final String _userId;
  final NotificationService? _notificationService;

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
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
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
