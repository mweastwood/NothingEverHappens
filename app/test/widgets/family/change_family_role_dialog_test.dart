import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/family.dart';
import 'package:nothing_ever_happens/widgets/family/change_family_role_dialog.dart';
import '../../test_helper.dart';

void main() {
  group('ChangeRoleDialog', () {
    final parentMember = FamilyMember(
      userId: 'user-1',
      displayName: 'Bob',
      email: 'bob@example.com',
      role: FamilyRole.parent,
    );

    final nonParentMember = FamilyMember(
      userId: 'user-2',
      displayName: 'Charlie',
      email: 'charlie@example.com',
      role: FamilyRole.nonParent,
    );

    testWidgets('allows role dropdown item selection and confirms change', (
      tester,
    ) async {
      FamilyRole? result;
      await tester.pumpWidget(
        buildTestableWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await ChangeRoleDialog.show(
                  context,
                  member: nonParentMember,
                  isOnlyParent: false,
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Charlie'), findsOneWidget);
      expect(find.byKey(const Key('change_role_dropdown')), findsOneWidget);

      // Open dropdown and select Parent
      await tester.tap(find.byKey(const Key('change_role_dropdown')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Parent').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm_change_role_button')));
      await tester.pumpAndSettle();

      expect(find.byType(ChangeRoleDialog), findsNothing);
      expect(result, FamilyRole.parent);
    });

    testWidgets('prevents demotion when isOnlyParent is true', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await ChangeRoleDialog.show(
                  context,
                  member: parentMember,
                  isOnlyParent: true,
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Warning message should be visible
      expect(
        find.text('A family must have at least one parent.'),
        findsOneWidget,
      );

      // Open dropdown
      await tester.tap(find.byKey(const Key('change_role_dropdown')));
      await tester.pumpAndSettle();

      // Non-parent option should be disabled (cannot be selected)
      final nonParentItem = tester.widget<DropdownMenuItem<FamilyRole>>(
        find.widgetWithText(DropdownMenuItem<FamilyRole>, 'Non-Parent').last,
      );
      expect(nonParentItem.enabled, isFalse);
    });

    testWidgets('returns null on cancel', (tester) async {
      FamilyRole? result = FamilyRole.parent;
      await tester.pumpWidget(
        buildTestableWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await ChangeRoleDialog.show(
                  context,
                  member: nonParentMember,
                  isOnlyParent: false,
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(ChangeRoleDialog), findsNothing);
      expect(result, isNull);
    });
  });
}
