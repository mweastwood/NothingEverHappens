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

    test('inviteMember and getPendingInvites normalize email casing', () async {
      await repository.inviteMember(
        familyId: 'f1',
        familyName: 'The Simpsons',
        toEmail: 'Bob@Example.Com ',
        role: 'non-parent',
      );

      final invitesSnapshot = await firestore.collection('invites').get();
      expect(invitesSnapshot.docs.length, 1);
      final inviteData = invitesSnapshot.docs.first.data();
      expect(inviteData['toEmail'], 'bob@example.com');

      final bobRepository = FamilyRepository(
        firestore: firestore,
        userId: 'user-bob',
        userEmail: ' BOB@example.com',
        userDisplayName: 'Bob',
      );

      final pending = await bobRepository.getPendingInvites().first;
      expect(pending.length, 1);
      expect(pending.first.toEmail, 'bob@example.com');
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
      'leaveFamily removes user from family and deletes family doc if empty',
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

        // Family document deleted since empty
        final familyDoc = await firestore
            .collection('families')
            .doc(familyId)
            .get();
        expect(familyDoc.exists, isFalse);
      },
    );

    test(
      'leaveFamily converts family tasks and instances to individual tasks when last member leaves',
      () async {
        await repository.createFamily('The Simpsons');
        final userDoc = await firestore.collection('users').doc(userId).get();
        final familyId = userDoc.data()?['familyId'] as String;

        // Seed family task schedule and instance
        await firestore
            .collection('families')
            .doc(familyId)
            .collection('tasks')
            .doc('task-100')
            .set({'id': 'task-100', 'title': 'Clean House', 'isFamily': true});

        await firestore
            .collection('families')
            .doc(familyId)
            .collection('instances')
            .doc('inst-100')
            .set({
              'id': 'inst-100',
              'scheduleId': 'task-100',
              'isFamily': true,
            });

        await repository.leaveFamily(familyId);

        // Verify family doc deleted
        final familyDoc = await firestore
            .collection('families')
            .doc(familyId)
            .get();
        expect(familyDoc.exists, isFalse);

        // Verify task schedule converted and moved to user's collection
        final userTaskDoc = await firestore
            .collection('users')
            .doc(userId)
            .collection('tasks')
            .doc('task-100')
            .get();
        expect(userTaskDoc.exists, isTrue);
        expect(userTaskDoc.data()?['isFamily'], isFalse);
        expect(userTaskDoc.data()?['title'], 'Clean House');

        // Verify task instance converted and moved to user's collection
        final userInstanceDoc = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc('inst-100')
            .get();
        expect(userInstanceDoc.exists, isTrue);
        expect(userInstanceDoc.data()?['isFamily'], isFalse);
      },
    );

    test(
      'leaveFamily preserves family tasks for remaining members when non-last member leaves',
      () async {
        await repository.createFamily('The Simpsons');
        final userDoc = await firestore.collection('users').doc(userId).get();
        final familyId = userDoc.data()?['familyId'] as String;

        // Add Bob to family
        await firestore.collection('families').doc(familyId).update({
          'members.user-bob': {
            'userId': 'user-bob',
            'displayName': 'Bob',
            'email': 'bob@example.com',
            'role': 'parent',
          },
        });

        // Seed family task
        await firestore
            .collection('families')
            .doc(familyId)
            .collection('tasks')
            .doc('task-shared')
            .set({
              'id': 'task-shared',
              'title': 'Shared Chores',
              'isFamily': true,
            });

        await repository.leaveFamily(familyId);

        // Family still exists for Bob
        final familyDoc = await firestore
            .collection('families')
            .doc(familyId)
            .get();
        expect(familyDoc.exists, isTrue);

        // Task stays in family collection as a family task
        final familyTaskDoc = await firestore
            .collection('families')
            .doc(familyId)
            .collection('tasks')
            .doc('task-shared')
            .get();
        expect(familyTaskDoc.exists, isTrue);
        expect(familyTaskDoc.data()?['isFamily'], isTrue);
      },
    );

    test(
      'acceptInvite removes member from previous family when switching families',
      () async {
        // Create Family 1 with Alice
        await repository.createFamily('Family 1');
        final userDoc1 = await firestore.collection('users').doc(userId).get();
        final familyId1 = userDoc1.data()?['familyId'] as String;

        // Bob creates Family 2
        final bobRepo = FamilyRepository(
          firestore: firestore,
          userId: 'user-bob',
          userEmail: 'bob@example.com',
          userDisplayName: 'Bob',
        );
        await bobRepo.createFamily('Family 2');
        final bobDoc = await firestore
            .collection('users')
            .doc('user-bob')
            .get();
        final familyId2 = bobDoc.data()?['familyId'] as String;

        // Bob invites Alice to Family 2
        await bobRepo.inviteMember(
          familyId: familyId2,
          familyName: 'Family 2',
          toEmail: userEmail,
          role: 'non-parent',
        );

        final inviteSnap = await firestore
            .collection('invites')
            .where('toEmail', isEqualTo: userEmail)
            .get();
        final invite = FamilyInvite.fromJson(
          inviteSnap.docs.first.data(),
          inviteSnap.docs.first.id,
        );

        // Alice accepts invite to Family 2
        await repository.acceptInvite(invite);

        // Alice should no longer be in Family 1 members map
        final f1Doc = await firestore
            .collection('families')
            .doc(familyId1)
            .get();
        expect(f1Doc.data()?['members']?[userId], isNull);

        // Alice should be in Family 2 members map
        final f2Doc = await firestore
            .collection('families')
            .doc(familyId2)
            .get();
        expect(f2Doc.data()?['members']?[userId], isNotNull);

        // Alice's user profile updated to Family 2
        final updatedAlice = await firestore
            .collection('users')
            .doc(userId)
            .get();
        expect(updatedAlice.data()?['familyId'], familyId2);
      },
    );

    test(
      'leaveFamily auto-promotes remaining member to parent when sole parent leaves',
      () async {
        await repository.createFamily('The Simpsons');
        final userDoc = await firestore.collection('users').doc(userId).get();
        final familyId = userDoc.data()?['familyId'] as String;

        // Invite Bob as non-parent
        await repository.inviteMember(
          familyId: familyId,
          familyName: 'The Simpsons',
          toEmail: 'bob@example.com',
          role: 'non-parent',
        );
        final inviteSnap = await firestore
            .collection('invites')
            .where('toEmail', isEqualTo: 'bob@example.com')
            .get();
        final invite = FamilyInvite.fromJson(
          inviteSnap.docs.first.data(),
          inviteSnap.docs.first.id,
        );

        final bobRepo = FamilyRepository(
          firestore: firestore,
          userId: 'user-bob',
          userEmail: 'bob@example.com',
          userDisplayName: 'Bob',
        );
        await bobRepo.acceptInvite(invite);

        // Parent (Alice) leaves
        await repository.leaveFamily(familyId);

        // Family doc should still exist
        final familyDoc = await firestore
            .collection('families')
            .doc(familyId)
            .get();
        expect(familyDoc.exists, isTrue);

        // Bob should now be promoted to parent
        final family = Family.fromJson(familyDoc.data()!, familyDoc.id);
        expect(family.members.length, 1);
        expect(family.members['user-bob']?.role, 'parent');

        // Bob's user doc should also be updated
        final bobUserDoc = await firestore
            .collection('users')
            .doc('user-bob')
            .get();
        expect(bobUserDoc.data()?['familyRole'], 'parent');
      },
    );

    test(
      'getOutstandingFamilyInvites returns pending invites for the family',
      () async {
        await repository.inviteMember(
          familyId: 'f1',
          familyName: 'The Simpsons',
          toEmail: 'bob@example.com',
          role: 'non-parent',
        );

        final invites = await repository
            .getOutstandingFamilyInvites('f1')
            .first;
        expect(invites.length, 1);
        expect(invites.first.toEmail, 'bob@example.com');
        expect(invites.first.status, 'pending');
      },
    );

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

      final deletedInviteDoc = await firestore
          .collection('invites')
          .doc(inviteId)
          .get();
      expect(deletedInviteDoc.exists, isFalse);
    });
  });
}
