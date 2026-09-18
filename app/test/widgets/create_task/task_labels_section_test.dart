import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/label_repository.dart';
import 'package:nothing_ever_happens/logic/task_label.dart';
import 'package:nothing_ever_happens/widgets/create_task/task_labels_section.dart';

import '../../test_helper.dart';

void main() {
  final personalLabel1 = TaskLabel(
    id: 'p-1',
    name: 'Personal Chores',
    colorKey: 'emerald',
    iconKey: 'cleaning',
    scope: TaskLabelScope.personal,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final personalLabel2 = TaskLabel(
    id: 'p-2',
    name: 'Personal Fitness',
    colorKey: 'cobalt',
    iconKey: 'fitness',
    scope: TaskLabelScope.personal,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final familyLabel1 = TaskLabel(
    id: 'f-1',
    name: 'Family Groceries',
    colorKey: 'tangerine',
    iconKey: 'shopping',
    scope: TaskLabelScope.family,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  Widget buildSection({
    required bool isFamily,
    required List<String> selectedLabelIds,
    required ValueChanged<String> onToggleLabel,
    bool readOnly = false,
    bool canEditFamily = true,
    List<TaskLabel> personalLabels = const [],
    List<TaskLabel> familyLabels = const [],
  }) {
    return ProviderScope(
      overrides: [
        personalLabelsStreamProvider.overrideWith(
          (ref) => Stream.value(personalLabels),
        ),
        familyLabelsStreamProvider.overrideWith(
          (ref) => Stream.value(familyLabels),
        ),
        canEditFamilyLabelsProvider.overrideWithValue(canEditFamily),
      ],
      child: buildTestableWidget(
        child: Scaffold(
          body: TaskLabelsSection(
            isFamily: isFamily,
            selectedLabelIds: selectedLabelIds,
            onToggleLabel: onToggleLabel,
            readOnly: readOnly,
          ),
        ),
      ),
    );
  }

  testWidgets('renders personal labels when isFamily is false', (tester) async {
    await tester.pumpWidget(
      buildSection(
        isFamily: false,
        selectedLabelIds: const [],
        onToggleLabel: (_) {},
        personalLabels: [personalLabel1, personalLabel2],
        familyLabels: [familyLabel1],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Personal Chores'), findsOneWidget);
    expect(find.text('Personal Fitness'), findsOneWidget);
    expect(find.text('Family Groceries'), findsNothing);
  });

  testWidgets('renders family labels when isFamily is true', (tester) async {
    await tester.pumpWidget(
      buildSection(
        isFamily: true,
        selectedLabelIds: const [],
        onToggleLabel: (_) {},
        personalLabels: [personalLabel1, personalLabel2],
        familyLabels: [familyLabel1],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Family Groceries'), findsOneWidget);
    expect(find.text('Personal Chores'), findsNothing);
    expect(find.text('Personal Fitness'), findsNothing);
  });

  testWidgets('allows toggling labels when not read-only', (tester) async {
    String? toggledLabelId;

    await tester.pumpWidget(
      buildSection(
        isFamily: false,
        selectedLabelIds: const ['p-1'],
        onToggleLabel: (id) => toggledLabelId = id,
        personalLabels: [personalLabel1, personalLabel2],
      ),
    );
    await tester.pumpAndSettle();

    // p-1 should be selected
    final chip1 = tester.widget<FilterChip>(
      find.byKey(const Key('label_chip_p-1')),
    );
    expect(chip1.selected, isTrue);
    expect(chip1.showCheckmark, isFalse);

    // p-2 should not be selected
    final chip2 = tester.widget<FilterChip>(
      find.byKey(const Key('label_chip_p-2')),
    );
    expect(chip2.selected, isFalse);
    expect(chip2.showCheckmark, isFalse);

    // Selected chip maintains custom icon and omits checkmark
    expect(find.byIcon(Icons.cleaning_services_outlined), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);

    // Tap p-2
    await tester.tap(find.byKey(const Key('label_chip_p-2')));
    await tester.pumpAndSettle();

    expect(toggledLabelId, 'p-2');
  });

  testWidgets(
    'disables checkmark overlay and keeps label icon visible when selected',
    (tester) async {
      await tester.pumpWidget(
        buildSection(
          isFamily: false,
          selectedLabelIds: const ['p-1'],
          onToggleLabel: (_) {},
          personalLabels: [personalLabel1, personalLabel2],
        ),
      );
      await tester.pumpAndSettle();

      final chip1 = tester.widget<FilterChip>(
        find.byKey(const Key('label_chip_p-1')),
      );
      final chip2 = tester.widget<FilterChip>(
        find.byKey(const Key('label_chip_p-2')),
      );

      expect(chip1.showCheckmark, isFalse);
      expect(chip2.showCheckmark, isFalse);

      // Icon for p-1 and p-2 remain visible and no check icon is rendered
      expect(find.byIcon(Icons.cleaning_services_outlined), findsOneWidget);
      expect(find.byIcon(Icons.fitness_center_outlined), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);
    },
  );

  testWidgets('disables toggling when read-only', (tester) async {
    await tester.pumpWidget(
      buildSection(
        isFamily: false,
        selectedLabelIds: const [],
        onToggleLabel: (_) {},
        readOnly: true,
        personalLabels: [personalLabel1],
      ),
    );
    await tester.pumpAndSettle();

    final chip1 = tester.widget<FilterChip>(
      find.byKey(const Key('label_chip_p-1')),
    );
    expect(chip1.onSelected, isNull);
  });

  testWidgets('shows empty state message when no labels exist', (tester) async {
    await tester.pumpWidget(
      buildSection(
        isFamily: false,
        selectedLabelIds: const [],
        onToggleLabel: (_) {},
        personalLabels: const [],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text("No personal labels yet. Tap '+ Add Label' to create one."),
      findsOneWidget,
    );
    expect(find.byKey(const Key('empty_manage_labels_button')), findsOneWidget);
    expect(find.text('Add Label'), findsOneWidget);
  });

  testWidgets(
    'shows parent empty state and add label button for family labels when user is parent',
    (tester) async {
      await tester.pumpWidget(
        buildSection(
          isFamily: true,
          selectedLabelIds: const [],
          onToggleLabel: (_) {},
          canEditFamily: true,
          familyLabels: const [],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text("No family labels yet. Tap '+ Add Label' to create one."),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('empty_manage_labels_button')),
        findsOneWidget,
      );
      expect(find.text('Add Label'), findsOneWidget);
    },
  );

  testWidgets(
    'shows non-parent empty state and hides add label button for family labels when user is non-parent',
    (tester) async {
      await tester.pumpWidget(
        buildSection(
          isFamily: true,
          selectedLabelIds: const [],
          onToggleLabel: (_) {},
          canEditFamily: false,
          familyLabels: const [],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No family labels yet.'), findsOneWidget);
      expect(find.byKey(const Key('empty_manage_labels_button')), findsNothing);
    },
  );

  testWidgets('hides add label button when readOnly is true', (tester) async {
    await tester.pumpWidget(
      buildSection(
        isFamily: true,
        selectedLabelIds: const [],
        onToggleLabel: (_) {},
        readOnly: true,
        canEditFamily: true,
        familyLabels: const [],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No family labels yet.'), findsOneWidget);
    expect(find.byKey(const Key('empty_manage_labels_button')), findsNothing);
  });
}
