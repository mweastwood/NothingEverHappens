import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/widgets/day_of_week_selector.dart';
import '../test_helper.dart';

void main() {
  group('DayOfWeekSelector', () {
    testWidgets('renders days with correct selections (multi-select)', (
      tester,
    ) async {
      Set<int> selected = {1, 3, 5}; // Mon, Wed, Fri
      Set<int>? updated;

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: DayOfWeekSelector(
              selectedWeekdays: selected,
              onChanged: (val) => updated = val,
              multiSelect: true,
            ),
          ),
        ),
      );

      Material getMaterialForDay(int dayIndex) {
        return tester.widget<Material>(
          find
              .ancestor(
                of: find.byKey(Key('weekly_weekday_chip_$dayIndex')),
                matching: find.byType(Material),
              )
              .first,
        );
      }

      final selectedColor = getMaterialForDay(1).color;
      final unselectedColor = getMaterialForDay(2).color;
      expect(selectedColor, isNot(unselectedColor));

      expect(getMaterialForDay(3).color, selectedColor);
      expect(getMaterialForDay(4).color, unselectedColor);

      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Tue'), findsOneWidget);
      expect(find.text('Wed'), findsOneWidget);

      // Toggle unselected day
      await tester.tap(find.byKey(const Key('weekly_weekday_chip_2')));
      await tester.pumpAndSettle();
      expect(updated, {1, 2, 3, 5});

      // Toggle selected day
      await tester.tap(find.byKey(const Key('weekly_weekday_chip_1')));
      await tester.pumpAndSettle();
      expect(updated, {3, 5});
    });

    testWidgets('renders single-select mode correctly', (tester) async {
      Set<int>? updated;

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: DayOfWeekSelector(
              selectedWeekdays: const {3}, // Wed
              onChanged: (val) => updated = val,
              multiSelect: false,
            ),
          ),
        ),
      );

      // No preset buttons should be found
      expect(find.byKey(const Key('preset_weekdays_button')), findsNothing);
      expect(find.byKey(const Key('preset_clear_button')), findsNothing);

      // Tap Wednesday (already selected) -> should not trigger change or no-op
      await tester.tap(find.byKey(const Key('weekly_weekday_chip_3')));
      await tester.pumpAndSettle();
      expect(updated, null);

      // Tap Friday (not selected) -> should trigger change to {5}
      await tester.tap(find.byKey(const Key('weekly_weekday_chip_5')));
      await tester.pumpAndSettle();
      expect(updated, {5});
    });

    testWidgets('triggers preset callbacks correctly', (tester) async {
      Set<int>? updated;

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: DayOfWeekSelector(
              selectedWeekdays: const {},
              onChanged: (val) => updated = val,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('preset_weekdays_button')));
      await tester.pumpAndSettle();
      expect(updated, {1, 2, 3, 4, 5});

      await tester.tap(find.byKey(const Key('preset_weekends_button')));
      await tester.pumpAndSettle();
      expect(updated, {6, 7});

      await tester.tap(find.byKey(const Key('preset_all_button')));
      await tester.pumpAndSettle();
      expect(updated, {1, 2, 3, 4, 5, 6, 7});

      await tester.tap(find.byKey(const Key('preset_clear_button')));
      await tester.pumpAndSettle();
      expect(updated, isEmpty);
    });

    testWidgets('shows validation warning when empty in multi-select', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: DayOfWeekSelector(
              selectedWeekdays: const {},
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(
        find.text('Please select at least one day of the week'),
        findsOneWidget,
      );
    });

    testGoldens('DayOfWeekSelector renders correctly', (tester) async {
      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 2.2)
        ..addScenario(
          'With Selection (Multi)',
          Material(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: DayOfWeekSelector(
                selectedWeekdays: const {1, 3, 5},
                onChanged: (_) {},
              ),
            ),
          ),
        )
        ..addScenario(
          'Empty (Warning) (Multi)',
          Material(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: DayOfWeekSelector(
                selectedWeekdays: const {},
                onChanged: (_) {},
              ),
            ),
          ),
        )
        ..addScenario(
          'Single Select',
          Material(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: DayOfWeekSelector(
                selectedWeekdays: const {4},
                onChanged: (_) {},
                multiSelect: false,
              ),
            ),
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(600, 500),
      );
      await screenMatchesGolden(tester, 'weekly_day_of_week_selector_golden');
    });
  });
}
