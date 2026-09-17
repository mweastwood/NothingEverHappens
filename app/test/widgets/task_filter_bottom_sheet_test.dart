import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/l10n/app_localizations.dart';
import 'package:nothing_ever_happens/logic/label_repository.dart';
import 'package:nothing_ever_happens/logic/task_filter.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_label.dart';
import 'package:nothing_ever_happens/widgets/task_filter_bottom_sheet.dart';
import '../test_helper.dart';

void main() {
  group('TaskFilterBottomSheet Widget Tests', () {
    final testLabels = [
      TaskLabel(
        id: 'lbl-work',
        name: 'Work',
        colorKey: 'coral',
        iconKey: 'work',
        scope: TaskLabelScope.personal,
        createdAt: DateTime(2026, 1, 1),
      ),
      TaskLabel(
        id: 'lbl-chores',
        name: 'Chores',
        colorKey: 'ocean',
        iconKey: 'cleaning_services',
        scope: TaskLabelScope.personal,
        createdAt: DateTime(2026, 1, 1),
      ),
      TaskLabel(
        id: 'lbl-finance',
        name: 'Finance',
        colorKey: 'sunflower',
        iconKey: 'attach_money',
        scope: TaskLabelScope.personal,
        createdAt: DateTime(2026, 1, 1),
      ),
    ];

    testWidgets('Toggles urgency, priority, and label filters', (
      WidgetTester tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          allLabelsMapProvider.overrideWithValue({
            for (final l in testLabels) l.id: l,
          }),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: TaskFilterBottomSheet()),
          ),
        ),
      );

      expect(find.text('Filter Tasks'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);

      // Select Overdue
      await tester.tap(find.text('Overdue'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
        container.read(taskFilterProvider).selectedUrgencies,
        contains(TaskUrgencyFilter.overdue),
      );

      // Select High Priority
      await tester.tap(find.text('High'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
        container.read(taskFilterProvider).selectedPriorities,
        contains(TaskPriority.high),
      );

      // Select Work Label
      await tester.tap(find.text('Work'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
        container.read(taskFilterProvider).selectedLabelIds,
        contains('lbl-work'),
      );

      expect(container.read(taskFilterProvider).activeFilterCount, 3);

      // Reset button should now be visible
      expect(find.text('Reset'), findsOneWidget);

      // Tap Reset
      await tester.tap(find.text('Reset'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(container.read(taskFilterProvider).isEmpty, isTrue);
    });

    testGoldens('TaskFilterBottomSheet states golden test', (tester) async {
      final labelsMap = {for (final l in testLabels) l.id: l};

      final builder = GoldenBuilder.grid(columns: 2, widthToHeightRatio: 0.55)
        ..addScenario(
          'Empty / Initial State (Light)',
          ProviderScope(
            overrides: [
              allLabelsMapProvider.overrideWithValue(labelsMap),
              taskFilterProvider.overrideWith((ref) => const TaskFilterState()),
            ],
            child: const TaskFilterBottomSheet(),
          ),
        )
        ..addScenario(
          'Multi-selected Filters (Light)',
          ProviderScope(
            overrides: [
              allLabelsMapProvider.overrideWithValue(labelsMap),
              taskFilterProvider.overrideWith(
                (ref) => const TaskFilterState(
                  selectedUrgencies: {
                    TaskUrgencyFilter.overdue,
                    TaskUrgencyFilter.dueToday,
                  },
                  selectedPriorities: {TaskPriority.high},
                  selectedLabelIds: {'lbl-work', 'lbl-chores'},
                ),
              ),
            ],
            child: const TaskFilterBottomSheet(),
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(900, 750),
      );

      await screenMatchesGolden(tester, 'task_filter_bottom_sheet_states');
    });
  });
}
