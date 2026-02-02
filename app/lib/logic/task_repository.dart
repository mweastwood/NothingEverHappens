import 'package:cloud_firestore/cloud_firestore.dart';
import 'task.dart';
import 'task_delta.dart';
import 'task_list.dart';

class TaskRepository {
  final FirebaseFirestore _firestore;
  final String _userId;

  TaskRepository({FirebaseFirestore? firestore, required String userId})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _userId = userId;

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
  }

  Future<void> updateTask(TaskModification modification) async {
    final batch = _firestore.batch();

    batch.set(_tasksRef.doc(modification.newTask.id), modification.newTask);
    batch.set(_historyRef.doc(modification.delta.id), modification.delta);

    await batch.commit();
  }

  Future<void> deleteTask(String id) async {
    final newState = const TaskList([]).delete(id, _userId);
    final delta = newState.history.last;

    final batch = _firestore.batch();

    batch.delete(_tasksRef.doc(id));
    batch.set(_historyRef.doc(delta.id), delta);

    await batch.commit();
  }
}
