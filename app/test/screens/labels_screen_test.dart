import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
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
    String? userId = currentUserId,
  }) {
    return ProviderScope(
      overrides: [
        labelRepositoryProvider.overrideWithValue(labelRepo),
        familyRepositoryProvider.overrideWithValue(familyRepo),
        authStateProvider.overrideWith(
          (ref) => Stream.value(
            userId != null
                ? _FakeUser(
                    uid: userId,
                    email: 'test@example.com',
                    displayName: 'Tester',
                  )
                : null,
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

  Widget buildTestWidget({
    String familyRole = 'parent',
    bool hasFamily = true,
    String? userId = currentUserId,
  }) {
    return ProviderScope(
      overrides: [
        labelRepositoryProvider.overrideWithValue(labelRepo),
        familyRepositoryProvider.overrideWithValue(familyRepo),
        authStateProvider.overrideWith(
          (ref) => Stream.value(
            userId != null
                ? _FakeUser(
                    uid: userId,
                    email: 'test@example.com',
                    displayName: 'Tester',
                  )
                : null,
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
      child: const LabelsScreen(),
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
    testWidgets(
      'renders wide screen two-column layout with populated family labels without unbounded viewport error',
      (tester) async {
        // Pre-seed both personal and family labels
        final personalLabel = TaskLabel.create(
          id: 'L-pers-1',
          name: 'Personal Errands',
          colorKey: 'coral',
          iconKey: 'tag',
        );
        await labelRepo.savePersonalLabel(currentUserId, personalLabel);

        final familyLabel = TaskLabel.create(
          id: 'L-fam-1',
          name: 'Family Groceries',
          colorKey: 'teal',
          iconKey: 'shopping',
          scope: TaskLabelScope.family,
        );
        await labelRepo.saveFamilyLabel(familyId, familyLabel);

        await tester.pumpWidget(
          buildScreen(screenSize: const Size(900, 800), familyRole: 'parent'),
        );
        await tester.pumpAndSettle();

        expect(find.byType(VerticalDivider), findsOneWidget);
        expect(find.text('Personal Labels'), findsOneWidget);
        expect(find.text('Family Labels'), findsOneWidget);
        expect(find.text('Personal Errands'), findsOneWidget);
        expect(find.text('Family Groceries'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('parent can create, edit, and delete a family label', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen(familyRole: 'parent'));
      await tester.pumpAndSettle();

      // 1. Create a family label
      await tester.tap(find.byKey(const Key('add_family_label_button')));
      await tester.pumpAndSettle();

      expect(find.text('New Family Label'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('label_name_field')),
        'Family Chores',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('color_picker_emerald')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('icon_picker_cleaning')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('save_label_button')));
      await tester.pumpAndSettle();

      expect(find.text('New Family Label'), findsNothing);
      expect(find.text('Family Chores'), findsOneWidget);

      // Verify repository updated
      final labelsAfterCreate = await labelRepo
          .watchFamilyLabels(familyId)
          .first;
      expect(labelsAfterCreate.length, 1);
      final createdLabelId = labelsAfterCreate.first.id;
      expect(labelsAfterCreate.first.name, 'Family Chores');
      expect(labelsAfterCreate.first.scope, TaskLabelScope.family);

      // 2. Edit the family label
      await tester.tap(find.byKey(Key('edit_label_$createdLabelId')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Family Label'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('label_name_field')),
        'Updated Chores',
      );
      await tester.tap(find.byKey(const Key('color_picker_sunflower')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('save_label_button')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Family Label'), findsNothing);
      expect(find.text('Updated Chores'), findsOneWidget);
      expect(find.text('Family Chores'), findsNothing);

      final labelsAfterEdit = await labelRepo.watchFamilyLabels(familyId).first;
      expect(labelsAfterEdit.first.name, 'Updated Chores');

      // 3. Delete the family label
      await tester.tap(find.byKey(Key('delete_label_$createdLabelId')));
      await tester.pumpAndSettle();

      expect(find.text('Delete Label?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm_delete_label_button')));
      await tester.pumpAndSettle();

      expect(find.text('Updated Chores'), findsNothing);
      final labelsAfterDelete = await labelRepo
          .watchFamilyLabels(familyId)
          .first;
      expect(labelsAfterDelete, isEmpty);
    });

    testWidgets(
      'displays error dialog when saving personal label without authenticated user',
      (tester) async {
        await tester.pumpWidget(buildScreen(userId: null));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('add_personal_label_button')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('label_name_field')),
          'Unauthenticated Label',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('save_label_button')));
        await tester.pumpAndSettle();

        expect(find.text('Error Occurred'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
      },
    );

    testWidgets(
      'displays error dialog when deleting personal label without authenticated user',
      (tester) async {
        final authController = StreamController<User?>.broadcast();
        final user = _FakeUser(
          uid: currentUserId,
          email: 'test@example.com',
          displayName: 'Tester',
        );
        final label = TaskLabel.create(
          id: 'L-pers-test',
          name: 'Personal Label',
          colorKey: 'coral',
          iconKey: 'tag',
        );
        await labelRepo.savePersonalLabel(currentUserId, label);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              labelRepositoryProvider.overrideWithValue(labelRepo),
              familyRepositoryProvider.overrideWithValue(familyRepo),
              authStateProvider.overrideWith((ref) => authController.stream),
              familyProfileStreamProvider.overrideWith(
                (ref) => Stream.value(
                  FamilyProfile(familyId: familyId, familyRole: 'parent'),
                ),
              ),
            ],
            child: MediaQuery(
              data: const MediaQueryData(size: Size(400, 800)),
              child: buildTestableWidget(child: const LabelsScreen()),
            ),
          ),
        );
        authController.add(user);
        await tester.pumpAndSettle();

        expect(find.text('Personal Label'), findsOneWidget);
        await tester.tap(find.byKey(const Key('delete_label_L-pers-test')));
        await tester.pumpAndSettle();

        expect(find.text('Delete Label?'), findsOneWidget);

        // Auth state lost before confirming delete
        authController.add(null);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('confirm_delete_label_button')));
        await tester.pumpAndSettle();

        expect(find.text('Error Occurred'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);

        await authController.close();
      },
    );

    testWidgets(
      'renders all 16 color options in dialog with tooltips and correct checkmark contrast',
      (tester) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('add_personal_label_button')));
        await tester.pumpAndSettle();

        // Verify all 16 colors are present
        for (final item in LabelPalette.all) {
          final colorPickerFinder = find.byKey(Key('color_picker_${item.key}'));
          expect(colorPickerFinder, findsOneWidget);

          // Verify Tooltip message
          final tooltipFinder = find.ancestor(
            of: colorPickerFinder,
            matching: find.byType(Tooltip),
          );
          expect(tooltipFinder, findsOneWidget);
          final tooltip = tester.widget<Tooltip>(tooltipFinder);
          expect(tooltip.message, equals(item.name));
        }

        // Test checkmark contrast when selecting cream (light luminance) vs cobalt (darker luminance)
        // Select cream
        await tester.tap(find.byKey(const Key('color_picker_cream')));
        await tester.pumpAndSettle();

        final creamCheckIcon = tester.widget<Icon>(
          find.descendant(
            of: find.byKey(const Key('color_picker_cream')),
            matching: find.byIcon(Icons.check),
          ),
        );
        expect(creamCheckIcon.color, equals(Colors.black87));

        // Select cobalt
        await tester.tap(find.byKey(const Key('color_picker_cobalt')));
        await tester.pumpAndSettle();

        final cobaltCheckIcon = tester.widget<Icon>(
          find.descendant(
            of: find.byKey(const Key('color_picker_cobalt')),
            matching: find.byIcon(Icons.check),
          ),
        );
        expect(cobaltCheckIcon.color, equals(Colors.white));
      },
    );

    testWidgets(
      'creates label with pastel color (mint) and persists colorKey',
      (tester) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('add_personal_label_button')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('label_name_field')),
          'Garden Routine',
        );
        await tester.tap(find.byKey(const Key('color_picker_mint')));
        await tester.tap(find.byKey(const Key('icon_picker_yard')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('save_label_button')));
        await tester.pumpAndSettle();

        expect(find.text('Garden Routine'), findsOneWidget);

        final labels = await labelRepo.watchPersonalLabels(currentUserId).first;
        expect(labels.length, 1);
        expect(labels.first.name, 'Garden Routine');
        expect(labels.first.colorKey, 'mint');
        expect(labels.first.iconKey, 'yard');
      },
    );

    testWidgets(
      'edits existing label to pastel color (lavender) and updates repository',
      (tester) async {
        final label = TaskLabel.create(
          id: 'L-seed-pastel',
          name: 'Reading List',
          colorKey: 'coral',
          iconKey: 'star',
        );
        await labelRepo.savePersonalLabel(currentUserId, label);

        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        expect(find.text('Reading List'), findsOneWidget);

        await tester.tap(find.byKey(const Key('edit_label_L-seed-pastel')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('color_picker_lavender')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('save_label_button')));
        await tester.pumpAndSettle();

        final labels = await labelRepo.watchPersonalLabels(currentUserId).first;
        expect(labels.first.colorKey, 'lavender');
      },
    );

    testWidgets(
      'personal labels can be reordered via drag handle and persisted',
      (tester) async {
        final label1 = TaskLabel.create(
          id: 'L-drag-1',
          name: 'First Label',
          colorKey: 'coral',
          iconKey: 'tag',
          order: 0,
        );
        final label2 = TaskLabel.create(
          id: 'L-drag-2',
          name: 'Second Label',
          colorKey: 'teal',
          iconKey: 'star',
          order: 1,
        );
        await labelRepo.savePersonalLabel(currentUserId, label1);
        await labelRepo.savePersonalLabel(currentUserId, label2);

        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('drag_handle_L-drag-1')), findsOneWidget);
        expect(find.byKey(const Key('drag_handle_L-drag-2')), findsOneWidget);

        // Drag first label downwards past second label
        final handleCenter = tester.getCenter(
          find.byKey(const Key('drag_handle_L-drag-1')),
        );
        final gesture = await tester.startGesture(handleCenter);
        await tester.pump();
        await gesture.moveBy(const Offset(0, 150));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();

        final labels = await labelRepo.watchPersonalLabels(currentUserId).first;
        expect(labels.map((l) => l.name).toList(), [
          'Second Label',
          'First Label',
        ]);
      },
    );

    testWidgets('family labels can be reordered by parent via drag handle', (
      tester,
    ) async {
      final fam1 = TaskLabel.create(
        id: 'L-fam-drag-1',
        name: 'First Family',
        colorKey: 'emerald',
        iconKey: 'yard',
        scope: TaskLabelScope.family,
        order: 0,
      );
      final fam2 = TaskLabel.create(
        id: 'L-fam-drag-2',
        name: 'Second Family',
        colorKey: 'cobalt',
        iconKey: 'cleaning',
        scope: TaskLabelScope.family,
        order: 1,
      );
      await labelRepo.saveFamilyLabel(familyId, fam1);
      await labelRepo.saveFamilyLabel(familyId, fam2);

      await tester.pumpWidget(buildScreen(familyRole: 'parent'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('drag_handle_L-fam-drag-1')), findsOneWidget);
      expect(find.byKey(const Key('drag_handle_L-fam-drag-2')), findsOneWidget);

      final handleCenter = tester.getCenter(
        find.byKey(const Key('drag_handle_L-fam-drag-1')),
      );
      final gesture = await tester.startGesture(handleCenter);
      await tester.pump();
      await gesture.moveBy(const Offset(0, 150));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      final labels = await labelRepo.watchFamilyLabels(familyId).first;
      expect(labels.map((l) => l.name).toList(), [
        'Second Family',
        'First Family',
      ]);
    });

    testWidgets(
      'non-parent family member does not see drag handles on family labels',
      (tester) async {
        final famLabel = TaskLabel.create(
          id: 'L-fam-nonparent',
          name: 'Family Tasks',
          colorKey: 'teal',
          iconKey: 'cleaning',
          scope: TaskLabelScope.family,
        );
        await labelRepo.saveFamilyLabel(familyId, famLabel);

        await tester.pumpWidget(buildScreen(familyRole: 'non-parent'));
        await tester.pumpAndSettle();

        expect(find.text('Family Tasks'), findsOneWidget);
        expect(
          find.byKey(const Key('drag_handle_L-fam-nonparent')),
          findsNothing,
        );
      },
    );
  });

  group('LabelsScreen Golden tests', () {
    testGoldens(
      'LabelsScreen renders populated personal and family labels with pastel colors (Light Theme)',
      (tester) async {
        await labelRepo.savePersonalLabel(
          currentUserId,
          TaskLabel.create(
            id: 'L-pers-1',
            name: 'Errands',
            colorKey: 'coral',
            iconKey: 'tag',
          ),
        );
        await labelRepo.savePersonalLabel(
          currentUserId,
          TaskLabel.create(
            id: 'L-pers-2',
            name: 'Garden Routine',
            colorKey: 'mint',
            iconKey: 'yard',
          ),
        );
        await labelRepo.savePersonalLabel(
          currentUserId,
          TaskLabel.create(
            id: 'L-pers-3',
            name: 'Reading List',
            colorKey: 'lavender',
            iconKey: 'star',
          ),
        );

        await labelRepo.saveFamilyLabel(
          familyId,
          TaskLabel.create(
            id: 'L-fam-1',
            name: 'Family Chores',
            colorKey: 'peach',
            iconKey: 'cleaning',
            scope: TaskLabelScope.family,
          ),
        );
        await labelRepo.saveFamilyLabel(
          familyId,
          TaskLabel.create(
            id: 'L-fam-2',
            name: 'Health & Meds',
            colorKey: 'periwinkle',
            iconKey: 'medication',
            scope: TaskLabelScope.family,
          ),
        );
        await labelRepo.saveFamilyLabel(
          familyId,
          TaskLabel.create(
            id: 'L-fam-3',
            name: 'Vacation Planning',
            colorKey: 'sky',
            iconKey: 'beach_access',
            scope: TaskLabelScope.family,
          ),
        );

        await tester.pumpWidgetBuilder(
          buildTestWidget(),
          wrapper: l10nMaterialAppWrapper(),
          surfaceSize: const Size(400, 800),
        );
        await tester.pumpAndSettle();

        await screenMatchesGolden(tester, 'labels_screen_populated');
      },
    );

    testGoldens(
      'LabelsScreen renders populated personal and family labels with pastel colors (Dark Theme)',
      (tester) async {
        await labelRepo.savePersonalLabel(
          currentUserId,
          TaskLabel.create(
            id: 'L-pers-1',
            name: 'Errands',
            colorKey: 'coral',
            iconKey: 'tag',
          ),
        );
        await labelRepo.savePersonalLabel(
          currentUserId,
          TaskLabel.create(
            id: 'L-pers-2',
            name: 'Garden Routine',
            colorKey: 'mint',
            iconKey: 'yard',
          ),
        );
        await labelRepo.savePersonalLabel(
          currentUserId,
          TaskLabel.create(
            id: 'L-pers-3',
            name: 'Reading List',
            colorKey: 'lavender',
            iconKey: 'star',
          ),
        );

        await labelRepo.saveFamilyLabel(
          familyId,
          TaskLabel.create(
            id: 'L-fam-1',
            name: 'Family Chores',
            colorKey: 'peach',
            iconKey: 'cleaning',
            scope: TaskLabelScope.family,
          ),
        );
        await labelRepo.saveFamilyLabel(
          familyId,
          TaskLabel.create(
            id: 'L-fam-2',
            name: 'Health & Meds',
            colorKey: 'periwinkle',
            iconKey: 'medication',
            scope: TaskLabelScope.family,
          ),
        );
        await labelRepo.saveFamilyLabel(
          familyId,
          TaskLabel.create(
            id: 'L-fam-3',
            name: 'Vacation Planning',
            colorKey: 'sky',
            iconKey: 'beach_access',
            scope: TaskLabelScope.family,
          ),
        );

        await tester.pumpWidgetBuilder(
          buildTestWidget(),
          wrapper: l10nMaterialAppWrapper(
            theme: ThemeData.dark(
              useMaterial3: true,
            ).copyWith(shadowColor: Colors.transparent),
          ),
          surfaceSize: const Size(400, 800),
        );
        await tester.pumpAndSettle();

        await screenMatchesGolden(tester, 'labels_screen_populated_dark');
      },
    );

    testGoldens(
      'LabelsScreen dialog renders 16-color palette with high contrast checkmark',
      (tester) async {
        await tester.pumpWidgetBuilder(
          buildTestWidget(),
          wrapper: l10nMaterialAppWrapper(),
          surfaceSize: const Size(400, 800),
        );
        await tester.pumpAndSettle();

        // Open Add Label dialog
        await tester.tap(find.byKey(const Key('add_personal_label_button')));
        await tester.pumpAndSettle();

        // Select 'cream' pastel swatch (light luminance with dark checkmark)
        await tester.tap(find.byKey(const Key('color_picker_cream')));
        await tester.pumpAndSettle();

        // Select 'yard' icon
        await tester.tap(find.byKey(const Key('icon_picker_yard')));
        await tester.pumpAndSettle();

        // Enter label title
        await tester.enterText(
          find.byKey(const Key('label_name_field')),
          'Morning Routine',
        );
        await tester.pumpAndSettle();

        await screenMatchesGolden(tester, 'labels_screen_color_picker_dialog');
      },
    );

    testGoldens('LabelsScreen renders not in family state (Narrow Screen)', (
      tester,
    ) async {
      await labelRepo.savePersonalLabel(
        currentUserId,
        TaskLabel.create(
          id: 'L-pers-1',
          name: 'Errands',
          colorKey: 'coral',
          iconKey: 'tag',
        ),
      );
      await labelRepo.savePersonalLabel(
        currentUserId,
        TaskLabel.create(
          id: 'L-pers-2',
          name: 'Garden Routine',
          colorKey: 'mint',
          iconKey: 'yard',
        ),
      );

      await tester.pumpWidgetBuilder(
        buildTestWidget(hasFamily: false),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(400, 800),
      );
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, 'labels_screen_not_in_family');
    });

    testGoldens('LabelsScreen renders not in family state (Wide Screen)', (
      tester,
    ) async {
      await labelRepo.savePersonalLabel(
        currentUserId,
        TaskLabel.create(
          id: 'L-pers-1',
          name: 'Errands',
          colorKey: 'coral',
          iconKey: 'tag',
        ),
      );
      await labelRepo.savePersonalLabel(
        currentUserId,
        TaskLabel.create(
          id: 'L-pers-2',
          name: 'Garden Routine',
          colorKey: 'mint',
          iconKey: 'yard',
        ),
      );

      await tester.pumpWidgetBuilder(
        buildTestWidget(hasFamily: false),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(1200, 800),
      );
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, 'labels_screen_not_in_family_wide');
    });
  });
}
