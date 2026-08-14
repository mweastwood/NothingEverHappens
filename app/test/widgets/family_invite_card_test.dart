import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/family.dart';
import 'package:nothing_ever_happens/widgets/family_invite_card.dart';
import '../test_helper.dart';

void main() {
  group('FamilyInviteCard', () {
    final inviteParent = FamilyInvite(
      id: 'invite-1',
      familyId: 'family-1',
      familyName: 'The Simpsons',
      fromEmail: 'homer@simpsons.com',
      fromName: 'Homer',
      toEmail: 'lisa@simpsons.com',
      role: FamilyRole.parent,
      status: FamilyInviteStatus.pending,
      createdAt: DateTime(2026, 6, 11),
    );

    final inviteNonParent = FamilyInvite(
      id: 'invite-2',
      familyId: 'family-1',
      familyName: 'The Simpsons',
      fromEmail: 'homer@simpsons.com',
      fromName: 'Homer',
      toEmail: 'lisa@simpsons.com',
      role: FamilyRole.nonParent,
      status: FamilyInviteStatus.pending,
      createdAt: DateTime(2026, 6, 11),
    );

    testWidgets('renders all fields and triggers actions', (tester) async {
      bool accepted = false;
      bool declined = false;

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: FamilyInviteCard(
              invite: inviteParent,
              onAccept: () => accepted = true,
              onDecline: () => declined = true,
            ),
          ),
        ),
      );

      // Verify text details
      expect(find.text('The Simpsons'), findsOneWidget);
      expect(find.text('Parent'), findsOneWidget); // role
      expect(
        find.textContaining('Invited by Homer (homer@simpsons.com)'),
        findsOneWidget,
      );

      // Tap Accept
      await tester.tap(find.byKey(const Key('accept_invite_invite-1')));
      expect(accepted, isTrue);

      // Tap Decline
      await tester.tap(find.byKey(const Key('decline_invite_invite-1')));
      expect(declined, isTrue);
    });

    testGoldens('FamilyInviteCard renders correctly in different roles', (
      tester,
    ) async {
      final builder = GoldenBuilder.column()
        ..addScenario(
          'Parent role invite',
          FamilyInviteCard(
            invite: inviteParent,
            onAccept: () {},
            onDecline: () {},
          ),
        )
        ..addScenario(
          'Non-parent role invite',
          FamilyInviteCard(
            invite: inviteNonParent,
            onAccept: () {},
            onDecline: () {},
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
      );

      await screenMatchesGolden(tester, 'family_invite_card_golden');
    });
  });
}
