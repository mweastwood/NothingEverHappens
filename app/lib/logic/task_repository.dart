import 'package:cloud_firestore/cloud_firestore.dart';
import 'task.dart';

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

  Stream<List<Task>> getTasks() {
    return _tasksRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  Future<void> addTask(Task task) async {
    await _tasksRef.doc(task.id).set(task);
  }

  Future<void> updateTask(Task task) async {
    await _tasksRef.doc(task.id).set(task);
  }

  Future<void> deleteTask(String id) async {
    await _tasksRef.doc(id).delete();
  }
}
