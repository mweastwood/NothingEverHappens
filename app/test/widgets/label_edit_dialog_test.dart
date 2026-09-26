import 'dart:async';

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
import 'package:nothing_ever_happens/widgets/label_edit_dialog.dart';

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

  Widget buildDialogLauncher({
    TaskLabel? existingLabel,
    TaskLabelScope scope = TaskLabelScope.personal,
    int nextOrder = 0,
    String? userId = currentUserId,
    bool hasFamily = true,
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
                ? FamilyProfile(familyId: familyId, familyRole: 'parent')
                : null,
          ),
        ),
      ],
      child: buildTestableWidget(
        child: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              ref.watch(authStateProvider);
              ref.watch(familyProfileStreamProvider);
              return ElevatedButton(
                onPressed: () => LabelEditDialog.show(
                  context,
                  existingLabel: existingLabel,
                  scope: scope,
                  nextOrder: nextOrder,
                ),
                child: const Text('Open Dialog'),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> openDialog(
    WidgetTester tester, {
    TaskLabel? existingLabel,
    TaskLabelScope scope = TaskLabelScope.personal,
    int nextOrder = 0,
    String? userId = currentUserId,
    bool hasFamily = true,
  }) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      buildDialogLauncher(
        existingLabel: existingLabel,
        scope: scope,
        nextOrder: nextOrder,
        userId: userId,
        hasFamily: hasFamily,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();
  }

  group('LabelEditDialog UI and Creation Mode', () {
    testWidgets('renders creation dialog with defaults for personal scope', (
      tester,
    ) async {
      await openDialog(tester, scope: TaskLabelScope.personal);

      expect(find.byType(LabelEditDialog), findsOneWidget);
      expect(find.text('New Personal Label'), findsOneWidget);

      // Verify name text field is empty
      final nameFieldFinder = find.byKey(const Key('label_name_field'));
      expect(nameFieldFinder, findsOneWidget);
      final textFormField = tester.widget<TextFormField>(nameFieldFinder);
      expect(textFormField.controller?.text, isEmpty);

      // Default preview text
      expect(find.text('Preview'), findsOneWidget);

      // Default color selection is coral
      expect(find.byKey(const Key('color_picker_coral')), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      // Default icon selection is tag
      expect(find.byKey(const Key('icon_picker_tag')), findsOneWidget);

      // SaveDiscardBar buttons
      expect(find.byKey(const Key('save_label_button')), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);
    });

    testWidgets('renders creation dialog title for family scope', (
      tester,
    ) async {
      await openDialog(tester, scope: TaskLabelScope.family);

      expect(find.text('New Family Label'), findsOneWidget);
    });

    testWidgets(
      'live preview chip updates dynamically with name, color, and icon',
      (tester) async {
        await openDialog(tester);

        expect(find.text('Preview'), findsOneWidget);

        // Type label name
        await tester.enterText(
          find.byKey(const Key('label_name_field')),
          'Gym & Fitness',
        );
        await tester.pumpAndSettle();

        // Preview text updates
        expect(
          find.text('Gym & Fitness'),
          findsNWidgets(2),
        ); // field and preview chip

        // Select different color (emerald)
        await tester.tap(find.byKey(const Key('color_picker_emerald')));
        await tester.pumpAndSettle();

        // Emerald should now have the checkmark
        final checkIcon = tester.widget<Icon>(find.byIcon(Icons.check));
        expect(checkIcon, isNotNull);

        // Select different icon (fitness)
        await tester.ensureVisible(
          find.byKey(const Key('icon_picker_fitness')),
        );
        await tester.tap(find.byKey(const Key('icon_picker_fitness')));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.fitness_center_outlined), findsNWidgets(2));
      },
    );

    testWidgets('renders all palette colors and icon choices with tooltips', (
      tester,
    ) async {
      await openDialog(tester);

      for (final color in LabelPalette.all) {
        final colorFinder = find.byKey(Key('color_picker_${color.key}'));
        expect(colorFinder, findsOneWidget);
        final tooltip = tester.widget<Tooltip>(
          find.ancestor(of: colorFinder, matching: find.byType(Tooltip)),
        );
        expect(tooltip.message, color.name);
      }

      for (final icon in LabelIcons.all) {
        final iconFinder = find.byKey(Key('icon_picker_${icon.key}'));
        expect(iconFinder, findsOneWidget);
        final tooltip = tester.widget<Tooltip>(
          find.ancestor(of: iconFinder, matching: find.byType(Tooltip)),
        );
        expect(tooltip.message, icon.name);
      }
    });

    testWidgets(
      'respects barrierDismissible parameter when tapping modal barrier',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
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
                  FamilyProfile(familyId: familyId, familyRole: 'parent'),
                ),
              ),
            ],
            child: buildTestableWidget(
              child: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => LabelEditDialog.show(
                      context,
                      scope: TaskLabelScope.personal,
                      barrierDismissible: false,
                    ),
                    child: const Text('Open Non-Dismissible'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open Non-Dismissible'));
        await tester.pumpAndSettle();

        expect(find.byType(LabelEditDialog), findsOneWidget);

        // Tap outside dialog bounds
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        // Dialog remains open because barrierDismissible is false
        expect(find.byType(LabelEditDialog), findsOneWidget);
      },
    );
  });

  group('LabelEditDialog Edit Mode', () {
    testWidgets(
      'renders edit dialog populated with existing label attributes for personal scope',
      (tester) async {
        final existing = TaskLabel.create(
          id: 'L-existing-1',
          name: 'Work Tasks',
          colorKey: 'teal',
          iconKey: 'work',
          scope: TaskLabelScope.personal,
        );

        await openDialog(
          tester,
          existingLabel: existing,
          scope: TaskLabelScope.personal,
        );

        expect(find.text('Edit Personal Label'), findsOneWidget);
        expect(
          find.text('Work Tasks'),
          findsNWidgets(2),
        ); // Field and preview chip
        expect(
          find.byIcon(Icons.work_outline),
          findsNWidgets(2),
        ); // Preview chip and icon picker
      },
    );

    testWidgets('renders edit dialog title for family scope', (tester) async {
      final existing = TaskLabel.create(
        id: 'L-existing-family',
        name: 'Household',
        colorKey: 'sunflower',
        iconKey: 'home',
        scope: TaskLabelScope.family,
      );

      await openDialog(
        tester,
        existingLabel: existing,
        scope: TaskLabelScope.family,
      );

      expect(find.text('Edit Family Label'), findsOneWidget);
    });

    testWidgets('asserts when existingLabel scope mismatches widget scope', (
      tester,
    ) async {
      final mismatchedLabel = TaskLabel.create(
        name: 'Mismatch',
        colorKey: 'coral',
        iconKey: 'tag',
        scope: TaskLabelScope.personal,
      );

      await tester.pumpWidget(
        buildDialogLauncher(
          existingLabel: mismatchedLabel,
          scope: TaskLabelScope.family,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Dialog'));
      await tester.pump();

      final dynamic exception = tester.takeException();
      expect(exception, isA<AssertionError>());
      expect(
        (exception as AssertionError).message,
        'existingLabel.scope must match dialog scope',
      );
    });
  });

  group('LabelEditDialog Form Validation', () {
    testWidgets(
      'blocks save and displays error text when name is empty or whitespace',
      (tester) async {
        await openDialog(tester);

        // Tap save without entering anything
        await tester.tap(find.byKey(const Key('save_label_button')));
        await tester.pumpAndSettle();

        expect(find.text('Please enter a label name'), findsOneWidget);
        expect(find.byType(LabelEditDialog), findsOneWidget);

        // Enter whitespace only
        await tester.enterText(
          find.byKey(const Key('label_name_field')),
          '    ',
        );
        await tester.tap(find.byKey(const Key('save_label_button')));
        await tester.pumpAndSettle();

        expect(find.text('Please enter a label name'), findsOneWidget);
        expect(find.byType(LabelEditDialog), findsOneWidget);
      },
    );

    testWidgets(
      'blocks save and displays error text when existing name exceeds 24 characters',
      (tester) async {
        final longLabel = TaskLabel.create(
          name: 'This label name exceeds twenty four chars',
          colorKey: 'coral',
          iconKey: 'tag',
          scope: TaskLabelScope.personal,
        );
        await openDialog(tester, existingLabel: longLabel);

        await tester.tap(find.byKey(const Key('save_label_button')));
        await tester.pumpAndSettle();

        expect(
          find.text('Label name must be at most 24 characters'),
          findsOneWidget,
        );
        expect(find.byType(LabelEditDialog), findsOneWidget);
      },
    );

    testWidgets('discard button dismisses the dialog without saving', (
      tester,
    ) async {
      await openDialog(tester);

      await tester.enterText(
        find.byKey(const Key('label_name_field')),
        'Discarded Label',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(find.byType(LabelEditDialog), findsNothing);
      final labels = await labelRepo.watchPersonalLabels(currentUserId).first;
      expect(labels, isEmpty);
    });
  });

  group('LabelEditDialog Persistence & Scopes', () {
    testWidgets('creates and persists a new personal label', (tester) async {
      await openDialog(tester, scope: TaskLabelScope.personal, nextOrder: 3);

      await tester.enterText(
        find.byKey(const Key('label_name_field')),
        'Finance & Taxes',
      );
      await tester.tap(find.byKey(const Key('color_picker_cobalt')));
      await tester.ensureVisible(find.byKey(const Key('icon_picker_payments')));
      await tester.tap(find.byKey(const Key('icon_picker_payments')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('save_label_button')));
      await tester.pumpAndSettle();

      // Dialog is dismissed
      expect(find.byType(LabelEditDialog), findsNothing);

      final labels = await labelRepo.watchPersonalLabels(currentUserId).first;
      expect(labels.length, 1);
      expect(labels.first.name, 'Finance & Taxes');
      expect(labels.first.colorKey, 'cobalt');
      expect(labels.first.iconKey, 'payments');
      expect(labels.first.scope, TaskLabelScope.personal);
      expect(labels.first.order, 3);
    });

    testWidgets('updates an existing personal label', (tester) async {
      final existing = TaskLabel.create(
        id: 'L-edit-pers',
        name: 'Old Personal',
        colorKey: 'coral',
        iconKey: 'tag',
        scope: TaskLabelScope.personal,
        order: 1,
      );
      await labelRepo.savePersonalLabel(currentUserId, existing);

      await openDialog(
        tester,
        existingLabel: existing,
        scope: TaskLabelScope.personal,
      );

      await tester.enterText(
        find.byKey(const Key('label_name_field')),
        'Updated Personal',
      );
      await tester.tap(find.byKey(const Key('color_picker_grape')));
      await tester.ensureVisible(find.byKey(const Key('icon_picker_book')));
      await tester.tap(find.byKey(const Key('icon_picker_book')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('save_label_button')));
      await tester.pumpAndSettle();

      expect(find.byType(LabelEditDialog), findsNothing);

      final labels = await labelRepo.watchPersonalLabels(currentUserId).first;
      expect(labels.length, 1);
      expect(labels.first.id, 'L-edit-pers');
      expect(labels.first.name, 'Updated Personal');
      expect(labels.first.colorKey, 'grape');
      expect(labels.first.iconKey, 'book');
      expect(labels.first.order, 1);
    });

    testWidgets('creates and persists a new family label', (tester) async {
      await openDialog(tester, scope: TaskLabelScope.family, nextOrder: 2);

      await tester.enterText(
        find.byKey(const Key('label_name_field')),
        'Family Groceries',
      );
      await tester.tap(find.byKey(const Key('color_picker_peach')));
      await tester.ensureVisible(find.byKey(const Key('icon_picker_shopping')));
      await tester.tap(find.byKey(const Key('icon_picker_shopping')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('save_label_button')));
      await tester.pumpAndSettle();

      expect(find.byType(LabelEditDialog), findsNothing);

      final labels = await labelRepo.watchFamilyLabels(familyId).first;
      expect(labels.length, 1);
      expect(labels.first.name, 'Family Groceries');
      expect(labels.first.colorKey, 'peach');
      expect(labels.first.iconKey, 'shopping');
      expect(labels.first.scope, TaskLabelScope.family);
      expect(labels.first.order, 2);
    });

    testWidgets('updates an existing family label', (tester) async {
      final existing = TaskLabel.create(
        id: 'L-edit-fam',
        name: 'Family Event',
        colorKey: 'rose',
        iconKey: 'celebration',
        scope: TaskLabelScope.family,
        order: 5,
      );
      await labelRepo.saveFamilyLabel(familyId, existing);

      await openDialog(
        tester,
        existingLabel: existing,
        scope: TaskLabelScope.family,
      );

      await tester.enterText(
        find.byKey(const Key('label_name_field')),
        'Updated Celebration',
      );
      await tester.tap(find.byKey(const Key('color_picker_mint')));
      await tester.ensureVisible(find.byKey(const Key('icon_picker_event')));
      await tester.tap(find.byKey(const Key('icon_picker_event')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('save_label_button')));
      await tester.pumpAndSettle();

      expect(find.byType(LabelEditDialog), findsNothing);

      final labels = await labelRepo.watchFamilyLabels(familyId).first;
      expect(labels.length, 1);
      expect(labels.first.id, 'L-edit-fam');
      expect(labels.first.name, 'Updated Celebration');
      expect(labels.first.colorKey, 'mint');
      expect(labels.first.iconKey, 'event');
      expect(labels.first.order, 5);
    });
  });

  group('LabelEditDialog Error Handling', () {
    testWidgets(
      'shows error dialog when personal save has unauthenticated user',
      (tester) async {
        await openDialog(
          tester,
          scope: TaskLabelScope.personal,
          userId: null, // Unauthenticated
        );

        await tester.enterText(
          find.byKey(const Key('label_name_field')),
          'Offline Label',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('save_label_button')));
        await tester.pumpAndSettle();

        // ErrorDialog should be displayed via ErrorHandler
        expect(find.text('Error Occurred'), findsOneWidget);
      },
    );

    testWidgets('shows error dialog when family save has missing family ID', (
      tester,
    ) async {
      await openDialog(
        tester,
        scope: TaskLabelScope.family,
        hasFamily: false, // No family
      );

      await tester.enterText(
        find.byKey(const Key('label_name_field')),
        'Missing Family Label',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('save_label_button')));
      await tester.pumpAndSettle();

      // ErrorDialog should be displayed via ErrorHandler
      expect(find.text('Error Occurred'), findsOneWidget);
    });
  });
}
