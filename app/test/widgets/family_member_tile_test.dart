import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/family.dart';
import 'package:nothing_ever_happens/widgets/family_member_tile.dart';
import '../test_helper.dart';

void main() {
  group('FamilyMemberTile', () {
    const parentMember = FamilyMember(
      userId: 'user-1',
      displayName: 'Alice',
      email: 'alice@example.com',
      role: FamilyRole.parent,
    );

    const nonParentMember = FamilyMember(
      userId: 'user-2',
      displayName: 'Bob',
      email: 'bob@example.com',
      role: FamilyRole.nonParent,
    );

    testWidgets('renders all fields correctly', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: const Scaffold(body: FamilyMemberTile(member: parentMember)),
        ),
      );

      // Verify text
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('alice@example.com'), findsOneWidget);
      expect(find.text('Parent'), findsOneWidget); // role
    });

    testGoldens('FamilyMemberTile renders correctly for different roles', (
      tester,
    ) async {
      final builder = GoldenBuilder.column()
        ..addScenario(
          'Parent member',
          const FamilyMemberTile(member: parentMember),
        )
        ..addScenario(
          'Non-parent member',
          const FamilyMemberTile(member: nonParentMember),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
      );

      await screenMatchesGolden(tester, 'family_member_tile_golden');
    });
  });
}
