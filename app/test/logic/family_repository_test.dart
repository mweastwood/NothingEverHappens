import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nothing_ever_happens/logic/family.dart';
import 'package:nothing_ever_happens/logic/family_repository.dart';

void main() {
  group('Family Models Unit Tests', () {
    test('FamilyMember serialization and deserialization', () {
      final member = const FamilyMember(
        userId: 'u1',
        displayName: 'Alice',
        email: 'alice@example.com',
        role: 'parent',
      );
      final json = member.toJson();
      expect(json['userId'], 'u1');
      expect(json['role'], 'parent');

      final deserialized = FamilyMember.fromJson(json);
      expect(deserialized.userId, 'u1');
      expect(deserialized.displayName, 'Alice');
      expect(deserialized.email, 'alice@example.com');
      expect(deserialized.role, 'parent');
    });

    test('Family serialization and deserialization', () {
      final member = const FamilyMember(
        userId: 'u1',
        displayName: 'Alice',
        email: 'alice@example.com',
        role: 'parent',
      );
      final family = Family(
        id: 'f1',
        name: 'The Simpsons',
        members: {'u1': member},
      );
      final json = family.toJson();
      expect(json['name'], 'The Simpsons');
      expect(json['members']['u1']['displayName'], 'Alice');

      final deserialized = Family.fromJson(json, 'f1');
      expect(deserialized.id, 'f1');
      expect(deserialized.name, 'The Simpsons');
      expect(deserialized.members['u1']?.displayName, 'Alice');
    });
  });

  group('FamilyRepository Unit Tests', () {
    late FakeFirebaseFirestore firestore;
    late FamilyRepository repository;
    const userId = 'user-1';
    const userEmail = 'user1@example.com';
    const userName = 'Alice';

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = FamilyRepository(
        firestore: firestore,
        userId: userId,
        userEmail: userEmail,
        userDisplayName: userName,
      );
    });

    test(
      'createFamily creates a family document and updates user profile',
      () async {
        await repository.createFamily('The Simpsons');

        // Check user document
        final userDoc = await firestore.collection('users').doc(userId).get();
        expect(userDoc.exists, isTrue);
        final familyId = userDoc.data()?['familyId'] as String;
        expect(familyId, isNotEmpty);
        expect(userDoc.data()?['familyRole'], 'parent');

        // Check family document
        final familyDoc = await firestore
            .collection('families')
            .doc(familyId)
            .get();
        expect(familyDoc.exists, isTrue);
        final family = Family.fromJson(familyDoc.data()!, familyDoc.id);
        expect(family.name, 'The Simpsons');
        expect(family.members[userId]?.displayName, userName);
        expect(family.members[userId]?.role, 'parent');
      },
    );

    test('inviteMember creates an invite document in Firestore', () async {
      await repository.inviteMember(
        familyId: 'f1',
        familyName: 'The Simpsons',
        toEmail: 'bob@example.com',
        role: 'non-parent',
      );

      final invitesSnapshot = await firestore.collection('invites').get();
      expect(invitesSnapshot.docs.length, 1);
      final inviteData = invitesSnapshot.docs.first.data();
      expect(inviteData['familyId'], 'f1');
      expect(inviteData['familyName'], 'The Simpsons');
      expect(inviteData['toEmail'], 'bob@example.com');
      expect(inviteData['role'], 'non-parent');
      expect(inviteData['status'], 'pending');
    });

    test('acceptInvite updates family, user doc, and invite status', () async {
      // 1. Create a family
      await repository.createFamily('The Simpsons');
      final userDoc = await firestore.collection('users').doc(userId).get();
      final familyId = userDoc.data()?['familyId'] as String;

      // 2. Invite Bob
      final bobUserId = 'user-bob';
      final bobEmail = 'bob@example.com';
      await repository.inviteMember(
        familyId: familyId,
        familyName: 'The Simpsons',
        toEmail: bobEmail,
        role: 'non-parent',
      );

      final invitesSnapshot = await firestore
          .collection('invites')
          .where('toEmail', isEqualTo: bobEmail)
          .get();
      final invite = FamilyInvite.fromJson(
        invitesSnapshot.docs.first.data(),
        invitesSnapshot.docs.first.id,
      );

      // 3. Bob accepts the invite
      final bobRepository = FamilyRepository(
        firestore: firestore,
        userId: bobUserId,
        userEmail: bobEmail,
        userDisplayName: 'Bob',
      );
      await bobRepository.acceptInvite(invite);

      // Bob's profile should be updated
      final bobDoc = await firestore.collection('users').doc(bobUserId).get();
      expect(bobDoc.data()?['familyId'], familyId);
      expect(bobDoc.data()?['familyRole'], 'non-parent');

      // Family members should now include Bob
      final familyDoc = await firestore
          .collection('families')
          .doc(familyId)
          .get();
      final family = Family.fromJson(familyDoc.data()!, familyDoc.id);
      expect(family.members.length, 2);
      expect(family.members[bobUserId]?.displayName, 'Bob');
      expect(family.members[bobUserId]?.role, 'non-parent');

      // Invite should be accepted
      final updatedInviteDoc = await firestore
          .collection('invites')
          .doc(invite.id)
          .get();
      expect(updatedInviteDoc.data()?['status'], 'accepted');
    });

    test('declineInvite updates invite status', () async {
      await repository.inviteMember(
        familyId: 'f1',
        familyName: 'The Simpsons',
        toEmail: 'bob@example.com',
        role: 'non-parent',
      );

      final invitesSnapshot = await firestore.collection('invites').get();
      final invite = FamilyInvite.fromJson(
        invitesSnapshot.docs.first.data(),
        invitesSnapshot.docs.first.id,
      );

      await repository.declineInvite(invite);

      final updatedInviteDoc = await firestore
          .collection('invites')
          .doc(invite.id)
          .get();
      expect(updatedInviteDoc.data()?['status'], 'declined');
    });

    test(
      'leaveFamily removes user from family and clears user profile',
      () async {
        await repository.createFamily('The Simpsons');
        final userDoc = await firestore.collection('users').doc(userId).get();
        final familyId = userDoc.data()?['familyId'] as String;

        await repository.leaveFamily(familyId);

        // User profile cleared
        final updatedUserDoc = await firestore
            .collection('users')
            .doc(userId)
            .get();
        expect(updatedUserDoc.data()?['familyId'], isNull);
        expect(updatedUserDoc.data()?['familyRole'], isNull);

        // Family members should be empty
        final familyDoc = await firestore
            .collection('families')
            .doc(familyId)
            .get();
        final family = Family.fromJson(familyDoc.data()!, familyDoc.id);
        expect(family.members.containsKey(userId), isFalse);
      },
    );

    test('getOutstandingFamilyInvites returns pending invites for the family', () async {
      await repository.inviteMember(
        familyId: 'f1',
        familyName: 'The Simpsons',
        toEmail: 'bob@example.com',
        role: 'non-parent',
      );

      final invites = await repository.getOutstandingFamilyInvites('f1').first;
      expect(invites.length, 1);
      expect(invites.first.toEmail, 'bob@example.com');
      expect(invites.first.status, 'pending');
    });

    test('revokeInvite deletes the invite document in Firestore', () async {
      await repository.inviteMember(
        familyId: 'f1',
        familyName: 'The Simpsons',
        toEmail: 'bob@example.com',
        role: 'non-parent',
      );

      final invitesSnapshot = await firestore.collection('invites').get();
      expect(invitesSnapshot.docs.length, 1);
      final inviteId = invitesSnapshot.docs.first.id;

      await repository.revokeInvite(inviteId);

      final deletedInviteDoc = await firestore.collection('invites').doc(inviteId).get();
      expect(deletedInviteDoc.exists, isFalse);
    });
  });
}
