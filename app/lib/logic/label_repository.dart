import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';
import 'family.dart';
import 'family_repository.dart';
import 'firestore_paths.dart';
import 'task_label.dart';

final labelRepositoryProvider = Provider<LabelRepository>((ref) {
  return LabelRepository();
});

final personalLabelsStreamProvider =
    StreamProvider.autoDispose<List<TaskLabel>>((ref) {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return Stream.value(const []);
      final repo = ref.watch(labelRepositoryProvider);
      return repo.watchPersonalLabels(user.uid);
    });

final familyLabelsStreamProvider = StreamProvider.autoDispose<List<TaskLabel>>((
  ref,
) {
  final profile = ref.watch(familyProfileStreamProvider).value;
  final familyId = profile?.familyId ?? '';
  if (familyId.isEmpty) return Stream.value(const []);
  final repo = ref.watch(labelRepositoryProvider);
  return repo.watchFamilyLabels(familyId);
});

final canEditFamilyLabelsProvider = Provider.autoDispose<bool>((ref) {
  final profile = ref.watch(familyProfileStreamProvider).value;
  if (profile == null || profile.familyId.isEmpty) return false;
  return profile.familyRole == FamilyRole.parent.value;
});

class LabelRepository {
  final FirebaseFirestore _firestore;

  LabelRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<TaskLabel>> watchPersonalLabels(String userId) {
    if (userId.isEmpty) return Stream.value(const []);
    return FirestoreCollections.userLabels(_firestore, userId).snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => doc.data()).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
    );
  }

  Stream<List<TaskLabel>> watchFamilyLabels(String familyId) {
    if (familyId.isEmpty) return Stream.value(const []);
    return FirestoreCollections.familyLabels(
      _firestore,
      familyId,
    ).snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => doc.data()).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
    );
  }

  Future<void> savePersonalLabel(String userId, TaskLabel label) async {
    final docRef = FirestoreCollections.userLabels(
      _firestore,
      userId,
    ).doc(label.id);
    await docRef.set(label, SetOptions(merge: true));
  }

  Future<void> deletePersonalLabel(String userId, String labelId) async {
    final docRef = FirestoreCollections.userLabels(
      _firestore,
      userId,
    ).doc(labelId);
    await docRef.delete();
  }

  Future<void> saveFamilyLabel(String familyId, TaskLabel label) async {
    final docRef = FirestoreCollections.familyLabels(
      _firestore,
      familyId,
    ).doc(label.id);
    await docRef.set(label, SetOptions(merge: true));
  }

  Future<void> deleteFamilyLabel(String familyId, String labelId) async {
    final docRef = FirestoreCollections.familyLabels(
      _firestore,
      familyId,
    ).doc(labelId);
    await docRef.delete();
  }
}
