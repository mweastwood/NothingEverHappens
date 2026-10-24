import 'package:cloud_firestore/cloud_firestore.dart';

import 'task_label.dart';

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
  static const String labels = 'labels';
}

/// Centralized typed collection reference helpers with converters.
abstract final class FirestoreCollections {
  /// Returns typed [CollectionReference] for a user's labels.
  static CollectionReference<TaskLabel> userLabels(
    FirebaseFirestore firestore,
    String userId,
  ) => firestore
      .collection(FirestorePaths.users)
      .doc(userId)
      .collection(FirestorePaths.labels)
      .withConverter<TaskLabel>(
        fromFirestore: (snapshot, _) => TaskLabel.fromFirestore(snapshot),
        toFirestore: (label, _) => label.toFirestore(),
      );

  /// Returns typed [CollectionReference] for a family's labels.
  static CollectionReference<TaskLabel> familyLabels(
    FirebaseFirestore firestore,
    String familyId,
  ) => firestore
      .collection(FirestorePaths.families)
      .doc(familyId)
      .collection(FirestorePaths.labels)
      .withConverter<TaskLabel>(
        fromFirestore: (snapshot, _) => TaskLabel.fromFirestore(snapshot),
        toFirestore: (label, _) => label.toFirestore(),
      );
}
