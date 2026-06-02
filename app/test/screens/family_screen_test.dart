import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:provider/provider.dart';
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
    return MultiProvider(
      providers: [
        Provider<FamilyRepository>.value(value: repository),
        Provider<ErrorHandler>.value(value: errorHandler),
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
}
