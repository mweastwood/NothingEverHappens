import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'family.dart';
import 'auth_repository.dart';

final familyRepositoryProvider = Provider<FamilyRepository?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  return FamilyRepository(
    userId: user.uid,
    userEmail: user.email,
    userDisplayName: user.displayName,
  );
});

class FamilyRepository {
  final FirebaseFirestore _firestore;
  final String _userId;
  final String? _userEmail;
  final String? _userDisplayName;

  FamilyRepository({
    FirebaseFirestore? firestore,
    required String userId,
    String? userEmail,
    String? userDisplayName,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _userId = userId,
       _userEmail = userEmail,
       _userDisplayName = userDisplayName;

  Stream<DocumentSnapshot<Map<String, dynamic>>> getProfile() {
    return _firestore.collection('users').doc(_userId).snapshots();
  }

  Stream<Family?> getFamily(String familyId) {
    if (familyId.isEmpty) return Stream.value(null);
    return _firestore.collection('families').doc(familyId).snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return Family.fromJson(snapshot.data()!, snapshot.id);
    });
  }

  Stream<List<FamilyInvite>> getPendingInvites() {
    if (_userEmail == null || _userEmail.isEmpty) return Stream.value([]);
    return _firestore
        .collection('invites')
        .where('toEmail', isEqualTo: _userEmail.trim().toLowerCase())
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => FamilyInvite.fromJson(doc.data(), doc.id))
              .toList();
        });
  }

  Future<void> createFamily(String name) async {
    final familyRef = _firestore.collection('families').doc();
    final familyId = familyRef.id;

    final creator = FamilyMember(
      userId: _userId,
      displayName: _userDisplayName ?? _userEmail ?? 'Parent',
      email: _userEmail?.trim().toLowerCase() ?? '',
      role: 'parent',
    );

    final family = Family(
      id: familyId,
      name: name,
      members: {_userId: creator},
    );

    final batch = _firestore.batch();
    batch.set(familyRef, family.toJson());
    batch.set(_firestore.collection('users').doc(_userId), {
      'familyId': familyId,
      'familyRole': 'parent',
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> inviteMember({
    required String familyId,
    required String familyName,
    required String toEmail,
    required String role,
  }) async {
    final inviteRef = _firestore.collection('invites').doc();
    final invite = FamilyInvite(
      id: inviteRef.id,
      familyId: familyId,
      familyName: familyName,
      fromEmail: _userEmail?.trim().toLowerCase() ?? '',
      fromName: _userDisplayName ?? _userEmail ?? 'Parent',
      toEmail: toEmail.trim().toLowerCase(),
      role: role,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    await inviteRef.set(invite.toJson());
  }

  Future<void> acceptInvite(FamilyInvite invite) async {
    final familyRef = _firestore.collection('families').doc(invite.familyId);

    final newMember = FamilyMember(
      userId: _userId,
      displayName: _userDisplayName ?? _userEmail ?? 'Member',
      email: _userEmail?.trim().toLowerCase() ?? '',
      role: invite.role,
    );

    final batch = _firestore.batch();

    batch.update(familyRef, {'members.$_userId': newMember.toJson()});

    batch.set(_firestore.collection('users').doc(_userId), {
      'familyId': invite.familyId,
      'familyRole': invite.role,
    }, SetOptions(merge: true));

    batch.update(_firestore.collection('invites').doc(invite.id), {
      'status': 'accepted',
    });

    await batch.commit();
  }

  Future<void> declineInvite(FamilyInvite invite) async {
    await _firestore.collection('invites').doc(invite.id).update({
      'status': 'declined',
    });
  }

  Stream<List<FamilyInvite>> getOutstandingFamilyInvites(String familyId) {
    if (familyId.isEmpty) return Stream.value([]);
    return _firestore
        .collection('invites')
        .where('familyId', isEqualTo: familyId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => FamilyInvite.fromJson(doc.data(), doc.id))
              .toList();
        });
  }

  Future<void> revokeInvite(String inviteId) async {
    await _firestore.collection('invites').doc(inviteId).delete();
  }

  Future<void> leaveFamily(String familyId) async {
    final batch = _firestore.batch();

    batch.update(_firestore.collection('families').doc(familyId), {
      'members.$_userId': FieldValue.delete(),
    });

    batch.set(_firestore.collection('users').doc(_userId), {
      'familyId': FieldValue.delete(),
      'familyRole': FieldValue.delete(),
    }, SetOptions(merge: true));

    await batch.commit();
  }
}
