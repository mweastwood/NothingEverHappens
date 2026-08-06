import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/family.dart';
import 'package:nothing_ever_happens/widgets/family_outstanding_invite_tile.dart';
import '../test_helper.dart';

void main() {
  group('FamilyOutstandingInviteTile', () {
    final inviteParent = FamilyInvite(
      id: 'invite-1',
      familyId: 'family-1',
      familyName: 'The Simpsons',
      fromEmail: 'homer@simpsons.com',
      fromName: 'Homer',
      toEmail: 'new_parent@example.com',
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
      toEmail: 'new_child@example.com',
      role: FamilyRole.nonParent,
      status: FamilyInviteStatus.pending,
      createdAt: DateTime(2026, 6, 11),
    );

    testWidgets('renders details and triggers revoke action', (tester) async {
      bool revoked = false;

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: FamilyOutstandingInviteTile(
              invite: inviteParent,
              onRevoke: () => revoked = true,
            ),
          ),
        ),
      );

      // Verify text
      expect(find.text('new_parent@example.com'), findsOneWidget);
      expect(find.text('Parent'), findsOneWidget); // role

      // Tap Revoke
      await tester.tap(find.byKey(const Key('revoke_invite_invite-1')));
      expect(revoked, isTrue);
    });

    testGoldens('FamilyOutstandingInviteTile renders correctly', (
      tester,
    ) async {
      final builder = GoldenBuilder.column()
        ..addScenario(
          'Parent role invite',
          FamilyOutstandingInviteTile(invite: inviteParent, onRevoke: () {}),
        )
        ..addScenario(
          'Non-parent role invite',
          FamilyOutstandingInviteTile(invite: inviteNonParent, onRevoke: () {}),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
      );

      await screenMatchesGolden(
        tester,
        'family_outstanding_invite_tile_golden',
      );
    });
  });
}
