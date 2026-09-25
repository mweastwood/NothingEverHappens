import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/family.dart';
import 'package:nothing_ever_happens/widgets/family/invite_member_dialog.dart';
import '../../test_helper.dart';

void main() {
  group('InviteMemberDialog', () {
    testWidgets('shows validation error on empty email', (tester) async {
      InviteMemberResult? result;
      await tester.pumpWidget(
        buildTestableWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await InviteMemberDialog.show(context);
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm_invite_button')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter an email address'), findsOneWidget);
      expect(result, isNull);
    });

    testWidgets('shows validation error on malformed email', (tester) async {
      InviteMemberResult? result;
      await tester.pumpWidget(
        buildTestableWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await InviteMemberDialog.show(context);
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('invite_email_field')),
        'not-an-email',
      );
      await tester.tap(find.byKey(const Key('confirm_invite_button')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
      expect(result, isNull);
    });

    testWidgets('switches role selection and submits valid form', (
      tester,
    ) async {
      InviteMemberResult? result;
      await tester.pumpWidget(
        buildTestableWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await InviteMemberDialog.show(context);
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('invite_email_field')),
        ' alice@example.com ',
      );

      // Default role is nonParent (Non-Parent). Open dropdown and select Parent.
      await tester.tap(find.byKey(const Key('invite_role_dropdown')));
      await tester.pumpAndSettle();

      // Tap 'Parent' dropdown item (the one in the dropdown menu popup)
      await tester.tap(find.text('Parent').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm_invite_button')));
      await tester.pumpAndSettle();

      expect(find.byType(InviteMemberDialog), findsNothing);
      expect(result, isNotNull);
      expect(result!.email, 'alice@example.com');
      expect(result!.role, FamilyRole.parent);
      // Also verify Map accessor backwards compatibility
      expect(result!['email'], 'alice@example.com');
      expect(result!['role'], FamilyRole.parent);
      expect(result!.toMap(), {
        'email': 'alice@example.com',
        'role': FamilyRole.parent,
      });
    });

    testWidgets('returns null on cancel', (tester) async {
      InviteMemberResult? result = const InviteMemberResult(
        email: 'init@test.com',
        role: FamilyRole.parent,
      );
      await tester.pumpWidget(
        buildTestableWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await InviteMemberDialog.show(context);
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

      expect(find.byType(InviteMemberDialog), findsNothing);
      expect(result, isNull);
    });
  });
}
