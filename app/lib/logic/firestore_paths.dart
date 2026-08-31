import 'package:cloud_firestore/cloud_firestore.dart';

import 'task_instance.dart';
import 'task_schedule.dart';

/// Centralized collection path constants for Firestore across the application.
abstract final class FirestorePaths {
  static const String users = 'users';
  static const String families = 'families';
  static const String tasks = 'tasks';
  static const String instances = 'instances';
  static const String settings = 'settings';
  static const String history = 'history';
  static const String invites = 'invites';
  static const String recipes = 'recipes';
}

/// Centralized typed collection reference helpers with converters.
abstract final class FirestoreCollections {
  /// Returns typed [CollectionReference] for a user's tasks.
  static CollectionReference<TaskSchedule> userTasks(
    FirebaseFirestore firestore,
    String userId,
  ) => firestore
      .collection(FirestorePaths.users)
      .doc(userId)
      .collection(FirestorePaths.tasks)
      .withConverter<TaskSchedule>(
        fromFirestore: (snapshot, _) => TaskSchedule.fromFirestore(snapshot),
        toFirestore: (task, _) => task.toFirestore(),
      );

  /// Returns typed [CollectionReference] for a family's tasks.
  static CollectionReference<TaskSchedule> familyTasks(
    FirebaseFirestore firestore,
    String familyId,
  ) => firestore
      .collection(FirestorePaths.families)
      .doc(familyId)
      .collection(FirestorePaths.tasks)
      .withConverter<TaskSchedule>(
        fromFirestore: (snapshot, _) => TaskSchedule.fromFirestore(snapshot),
        toFirestore: (task, _) => task.toFirestore(),
      );

  /// Returns typed [CollectionReference] for a user's task instances.
  static CollectionReference<TaskInstance> userInstances(
    FirebaseFirestore firestore,
    String userId,
  ) => firestore
      .collection(FirestorePaths.users)
      .doc(userId)
      .collection(FirestorePaths.instances)
      .withConverter<TaskInstance>(
        fromFirestore: (snapshot, _) => TaskInstance.fromFirestore(snapshot),
        toFirestore: (instance, _) => instance.toFirestore(),
      );

  /// Returns typed [CollectionReference] for a family's task instances.
  static CollectionReference<TaskInstance> familyInstances(
    FirebaseFirestore firestore,
    String familyId,
  ) => firestore
      .collection(FirestorePaths.families)
      .doc(familyId)
      .collection(FirestorePaths.instances)
      .withConverter<TaskInstance>(
        fromFirestore: (snapshot, _) => TaskInstance.fromFirestore(snapshot),
        toFirestore: (instance, _) => instance.toFirestore(),
      );
}
