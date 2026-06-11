import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nothing_ever_happens/logic/family_repository.dart';
import 'package:nothing_ever_happens/logic/error_handler.dart';
import 'package:nothing_ever_happens/screens/family_screen.dart';
import '../test_helper.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FamilyRepository repository;
  late ErrorHandler errorHandler;
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
    errorHandler = ErrorHandler();
  });

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        familyRepositoryProvider.overrideWithValue(repository),
        errorHandlerProvider.overrideWithValue(errorHandler),
      ],
      child: buildTestableWidget(child: const Scaffold(body: FamilyScreen())),
    );
  }

  testWidgets('renders create family screen when not in a family', (
    WidgetTester tester,
  ) async {
    // Current user has no family profile
    await firestore.collection('users').doc(userId).set({});

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Family'), findsWidgets);
    expect(
      find.textContaining('You are not currently in a family unit'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('create_family_button')), findsOneWidget);
  });

  testWidgets('creating a family updates Firestore', (
    WidgetTester tester,
  ) async {
    await firestore.collection('users').doc(userId).set({});

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Tap create family button
    await tester.tap(find.byKey(const Key('create_family_button')));
    await tester.pumpAndSettle();

    // Verify dialog shows up
    expect(find.text('Create Family'), findsWidgets);
    await tester.enterText(
      find.byKey(const Key('family_name_field')),
      'The Simpsons',
    );
    await tester.tap(find.byKey(const Key('confirm_create_family_button')));
    await tester.pumpAndSettle();

    // Verify family document is created
    final userDoc = await firestore.collection('users').doc(userId).get();
    expect(userDoc.data()?['familyId'], isNotNull);
    expect(userDoc.data()?['familyRole'], 'parent');
  });

  testWidgets('renders family details and allows parent to invite and leave', (
    WidgetTester tester,
  ) async {
    // 1. Setup user in a family
    final familyId = 'fam-123';
    await firestore.collection('users').doc(userId).set({
      'familyId': familyId,
      'familyRole': 'parent',
    });

    // 2. Setup family doc with members
    await firestore.collection('families').doc(familyId).set({
      'name': 'The Simpsons',
      'members': {
        userId: {
          'userId': userId,
          'displayName': userName,
          'email': userEmail,
          'role': 'parent',
        },
        'user-2': {
          'userId': 'user-2',
          'displayName': 'Bob',
          'email': 'bob@example.com',
          'role': 'non-parent',
        },
      },
    });

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('The Simpsons'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.byKey(const Key('invite_member_button')), findsOneWidget);

    // Test invite dialog
    await tester.tap(find.byKey(const Key('invite_member_button')));
    await tester.pumpAndSettle();

    expect(find.text('Invite Family Member'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('invite_email_field')),
      'new@example.com',
    );
    await tester.tap(find.byKey(const Key('confirm_invite_button')));
    await tester.pumpAndSettle();

    // Verify invite created in Firestore
    final invites = await firestore.collection('invites').get();
    expect(invites.docs.length, 1);
    expect(invites.docs.first.data()['toEmail'], 'new@example.com');
  });

  testGoldens('FamilyScreen not in family golden', (tester) async {
    await firestore.collection('users').doc(userId).set({});

    await tester.pumpWidgetBuilder(
      buildTestWidget(),
      wrapper: l10nMaterialAppWrapper(),
      surfaceSize: const Size(400, 800),
    );
    await tester.pumpAndSettle();

    await screenMatchesGolden(tester, 'family_screen_not_in_family');
  });

  testGoldens('FamilyScreen pending invites golden', (tester) async {
    await firestore.collection('users').doc(userId).set({});
    await repository.inviteMember(
      familyId: 'fam-123',
      familyName: 'The Simpsons',
      toEmail: userEmail,
      role: 'non-parent',
    );

    await tester.pumpWidgetBuilder(
      buildTestWidget(),
      wrapper: l10nMaterialAppWrapper(),
      surfaceSize: const Size(400, 800),
    );
    await tester.pumpAndSettle();

    await screenMatchesGolden(tester, 'family_screen_pending_invites');
  });

  testGoldens('FamilyScreen family members golden', (tester) async {
    final familyId = 'fam-123';
    await firestore.collection('users').doc(userId).set({
      'familyId': familyId,
      'familyRole': 'parent',
    });
    await firestore.collection('families').doc(familyId).set({
      'name': 'The Simpsons',
      'members': {
        userId: {
          'userId': userId,
          'displayName': userName,
          'email': userEmail,
          'role': 'parent',
        },
        'user-2': {
          'userId': 'user-2',
          'displayName': 'Bob',
          'email': 'bob@example.com',
          'role': 'non-parent',
        },
      },
    });

    await tester.pumpWidgetBuilder(
      buildTestWidget(),
      wrapper: l10nMaterialAppWrapper(),
      surfaceSize: const Size(400, 800),
    );
    await tester.pumpAndSettle();

    await screenMatchesGolden(tester, 'family_screen_members_list');
  });

  testWidgets(
    'renders outstanding invites list for parent and handles revoke',
    (WidgetTester tester) async {
      final familyId = 'fam-123';
      await firestore.collection('users').doc(userId).set({
        'familyId': familyId,
        'familyRole': 'parent',
      });

      await firestore.collection('families').doc(familyId).set({
        'name': 'The Simpsons',
        'members': {
          userId: {
            'userId': userId,
            'displayName': userName,
            'email': userEmail,
            'role': 'parent',
          },
        },
      });

      await firestore.collection('invites').doc('invite-abc').set({
        'familyId': familyId,
        'familyName': 'The Simpsons',
        'fromEmail': userEmail,
        'fromName': userName,
        'toEmail': 'new@example.com',
        'role': 'non-parent',
        'status': 'pending',
        'createdAt': Timestamp.now(),
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Outstanding Invitations'), findsOneWidget);
      expect(find.text('new@example.com'), findsOneWidget);
      expect(find.byKey(const Key('revoke_invite_invite-abc')), findsOneWidget);

      // Tap revoke button
      await tester.tap(find.byKey(const Key('revoke_invite_invite-abc')));
      await tester.pumpAndSettle();

      // Verify confirmation dialog shows
      expect(find.text('Revoke Invitation?'), findsOneWidget);
      expect(
        find.text(
          'Are you sure you want to revoke the invitation for new@example.com?',
        ),
        findsOneWidget,
      );

      // Tap confirm revoke
      await tester.tap(find.byKey(const Key('confirm_revoke_invite_button')));
      await tester.pumpAndSettle();

      // Verify invite document is deleted from Firestore
      final invites = await firestore.collection('invites').get();
      expect(invites.docs.isEmpty, isTrue);

      // Dialog should be dismissed
      expect(find.text('Revoke Invitation?'), findsNothing);
    },
  );

  testWidgets(
    'renders family details and does NOT show outstanding invites to non-parent',
    (WidgetTester tester) async {
      final familyId = 'fam-123';
      await firestore.collection('users').doc(userId).set({
        'familyId': familyId,
        'familyRole': 'non-parent',
      });

      await firestore.collection('families').doc(familyId).set({
        'name': 'The Simpsons',
        'members': {
          userId: {
            'userId': userId,
            'displayName': userName,
            'email': userEmail,
            'role': 'non-parent',
          },
        },
      });

      await firestore.collection('invites').doc('invite-abc').set({
        'familyId': familyId,
        'familyName': 'The Simpsons',
        'fromEmail': 'parent@example.com',
        'fromName': 'Marge',
        'toEmail': 'new@example.com',
        'role': 'non-parent',
        'status': 'pending',
        'createdAt': Timestamp.now(),
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Outstanding Invitations'), findsNothing);
      expect(find.text('new@example.com'), findsNothing);
    },
  );

  testGoldens('FamilyScreen outstanding invites golden', (tester) async {
    final familyId = 'fam-123';
    await firestore.collection('users').doc(userId).set({
      'familyId': familyId,
      'familyRole': 'parent',
    });
    await firestore.collection('families').doc(familyId).set({
      'name': 'The Simpsons',
      'members': {
        userId: {
          'userId': userId,
          'displayName': userName,
          'email': userEmail,
          'role': 'parent',
        },
      },
    });

    await firestore.collection('invites').doc('invite-1').set({
      'familyId': familyId,
      'familyName': 'The Simpsons',
      'fromEmail': userEmail,
      'fromName': userName,
      'toEmail': 'invited1@example.com',
      'role': 'non-parent',
      'status': 'pending',
      'createdAt': Timestamp.now(),
    });
    await firestore.collection('invites').doc('invite-2').set({
      'familyId': familyId,
      'familyName': 'The Simpsons',
      'fromEmail': userEmail,
      'fromName': userName,
      'toEmail': 'invited2@example.com',
      'role': 'parent',
      'status': 'pending',
      'createdAt': Timestamp.now(),
    });

    await tester.pumpWidgetBuilder(
      buildTestWidget(),
      wrapper: l10nMaterialAppWrapper(),
      surfaceSize: const Size(400, 800),
    );
    await tester.pumpAndSettle();

    await screenMatchesGolden(tester, 'family_screen_outstanding_invites');
  });
}
