import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/auth_repository.dart';
import 'package:nothing_ever_happens/logic/family.dart';
import 'package:nothing_ever_happens/logic/family_repository.dart';
import 'package:nothing_ever_happens/logic/label_repository.dart';
import 'package:nothing_ever_happens/logic/task_label.dart';
import 'package:nothing_ever_happens/screens/labels_screen.dart';

import '../test_helper.dart';

class _FakeUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;

  _FakeUser({required this.uid, this.email, this.displayName});
}

void main() {
  late FakeFirebaseFirestore firestore;
  late LabelRepository labelRepo;
  late FamilyRepository familyRepo;

  const currentUserId = 'test-user-123';
  const familyId = 'test-family-456';

  setUp(() {
    firestore = FakeFirebaseFirestore();
    labelRepo = LabelRepository(firestore: firestore);
    familyRepo = FamilyRepository(
      firestore: firestore,
      userId: currentUserId,
      userEmail: 'test@example.com',
      userDisplayName: 'Tester',
    );
  });

  Widget buildScreen({
    Size screenSize = const Size(400, 800),
    String familyRole = 'parent',
    bool hasFamily = true,
  }) {
    return ProviderScope(
      overrides: [
        labelRepositoryProvider.overrideWithValue(labelRepo),
        familyRepositoryProvider.overrideWithValue(familyRepo),
        authStateProvider.overrideWith(
          (ref) => Stream.value(
            _FakeUser(
              uid: currentUserId,
              email: 'test@example.com',
              displayName: 'Tester',
            ),
          ),
        ),
        familyProfileStreamProvider.overrideWith(
          (ref) => Stream.value(
            hasFamily
                ? FamilyProfile(familyId: familyId, familyRole: familyRole)
                : null,
          ),
        ),
      ],
      child: MediaQuery(
        data: MediaQueryData(size: screenSize),
        child: buildTestableWidget(child: const LabelsScreen()),
      ),
    );
  }

  group('LabelsScreen tests', () {
    testWidgets('renders narrow layout stacked with empty states', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen(screenSize: const Size(400, 800)));
      await tester.pumpAndSettle();

      expect(find.text('Labels'), findsOneWidget);
      expect(find.text('Personal Labels'), findsOneWidget);
      expect(find.text('Only visible to you'), findsOneWidget);
      expect(find.text('Family Labels'), findsOneWidget);
      expect(find.text('Shared across the family'), findsOneWidget);

      expect(
        find.text("No personal labels yet. Tap '+ Add Label' to create one."),
        findsOneWidget,
      );
      expect(
        find.text("No family labels yet. Tap '+ Add Label' to create one."),
        findsOneWidget,
      );
    });

    testWidgets('renders wide screen two-column layout with vertical divider', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen(screenSize: const Size(900, 800)));
      await tester.pumpAndSettle();

      expect(find.byType(VerticalDivider), findsOneWidget);
      expect(find.text('Personal Labels'), findsOneWidget);
      expect(find.text('Family Labels'), findsOneWidget);
    });

    testWidgets('creates a personal label through dialog', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Tap "+ Add Label" in Personal section
      await tester.tap(find.byKey(const Key('add_personal_label_button')));
      await tester.pumpAndSettle();

      expect(find.text('New Personal Label'), findsOneWidget);

      // Enter name
      await tester.enterText(
        find.byKey(const Key('label_name_field')),
        'Health & Meds',
      );
      await tester.pumpAndSettle();

      // Select color (emerald)
      await tester.tap(find.byKey(const Key('color_picker_emerald')));
      await tester.pumpAndSettle();

      // Select icon (medication)
      await tester.tap(find.byKey(const Key('icon_picker_medication')));
      await tester.pumpAndSettle();

      // Save
      await tester.tap(find.byKey(const Key('save_label_button')));
      await tester.pumpAndSettle();

      // Dialog closed and item visible
      expect(find.text('New Personal Label'), findsNothing);
      expect(find.text('Health & Meds'), findsOneWidget);
    });

    testWidgets('edits and deletes a personal label', (tester) async {
      // Pre-seed a personal label
      final label = TaskLabel.create(
        id: 'L-seed-1',
        name: 'Errands',
        colorKey: 'coral',
        iconKey: 'tag',
      );
      await labelRepo.savePersonalLabel(currentUserId, label);

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Errands'), findsOneWidget);

      // Tap edit button
      await tester.tap(find.byKey(const Key('edit_label_L-seed-1')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Personal Label'), findsOneWidget);

      // Update name
      await tester.enterText(
        find.byKey(const Key('label_name_field')),
        'Urgent Errands',
      );
      await tester.tap(find.byKey(const Key('color_picker_rose')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('save_label_button')));
      await tester.pumpAndSettle();

      expect(find.text('Urgent Errands'), findsOneWidget);
      expect(find.text('Errands'), findsNothing);

      // Delete the label
      await tester.tap(find.byKey(const Key('delete_label_L-seed-1')));
      await tester.pumpAndSettle();

      expect(find.text('Delete Label?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm_delete_label_button')));
      await tester.pumpAndSettle();

      expect(find.text('Urgent Errands'), findsNothing);
    });

    testWidgets(
      'non-parent family member sees notice and cannot add/edit family labels',
      (tester) async {
        // Pre-seed a family label
        final famLabel = TaskLabel.create(
          id: 'L-fam-1',
          name: 'House Chores',
          colorKey: 'teal',
          iconKey: 'cleaning',
          scope: TaskLabelScope.family,
        );
        await labelRepo.saveFamilyLabel(familyId, famLabel);

        await tester.pumpWidget(buildScreen(familyRole: 'non-parent'));
        await tester.pumpAndSettle();

        // Info banner visible
        expect(
          find.text('Only parents can add, edit, or delete family labels.'),
          findsOneWidget,
        );

        // Add family label button should not be present
        expect(find.byKey(const Key('add_family_label_button')), findsNothing);

        // Label is visible
        expect(find.text('House Chores'), findsOneWidget);

        // Edit and delete buttons for family label should not be present
        expect(find.byKey(const Key('edit_label_L-fam-1')), findsNothing);
        expect(find.byKey(const Key('delete_label_L-fam-1')), findsNothing);
      },
    );

    testWidgets(
      'user not in a family sees invite prompt with Go to Family button',
      (tester) async {
        await tester.pumpWidget(buildScreen(hasFamily: false));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('You are not currently part of a family'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('go_to_family_button')), findsOneWidget);
        expect(find.byKey(const Key('add_family_label_button')), findsNothing);
      },
    );
  });
}
