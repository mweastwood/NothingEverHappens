import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/widgets/weekly_day_of_week_selector.dart';
import '../test_helper.dart';

void main() {
  group('WeeklyDayOfWeekSelector', () {
    testWidgets('renders days with correct selections', (tester) async {
      Set<int> selected = {1, 3, 5}; // Mon, Wed, Fri
      Set<int>? updated;

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: WeeklyDayOfWeekSelector(
              selectedWeekdays: selected,
              onChanged: (val) => updated = val,
            ),
          ),
        ),
      );

      // Verify that Mon, Wed, Fri look different (selected) from Tue, Thu, Sat, Sun
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

      // Selected vs Unselected colors
      final selectedColor = getMaterialForDay(1).color;
      final unselectedColor = getMaterialForDay(2).color;
      expect(selectedColor, isNot(unselectedColor));

      expect(getMaterialForDay(3).color, selectedColor);
      expect(getMaterialForDay(4).color, unselectedColor);

      // Verify short names (depending on localization wrapper, in English they should be Mon, Tue, etc.)
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

    testWidgets('triggers preset callbacks correctly', (tester) async {
      Set<int>? updated;

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: WeeklyDayOfWeekSelector(
              selectedWeekdays: const {},
              onChanged: (val) => updated = val,
            ),
          ),
        ),
      );

      // Weekdays preset
      await tester.tap(find.byKey(const Key('preset_weekdays_button')));
      await tester.pumpAndSettle();
      expect(updated, {1, 2, 3, 4, 5});

      // Weekends preset
      await tester.tap(find.byKey(const Key('preset_weekends_button')));
      await tester.pumpAndSettle();
      expect(updated, {6, 7});

      // All preset
      await tester.tap(find.byKey(const Key('preset_all_button')));
      await tester.pumpAndSettle();
      expect(updated, {1, 2, 3, 4, 5, 6, 7});

      // Clear preset
      await tester.tap(find.byKey(const Key('preset_clear_button')));
      await tester.pumpAndSettle();
      expect(updated, isEmpty);
    });

    testWidgets('shows validation warning when empty', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: WeeklyDayOfWeekSelector(
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

    testGoldens('WeeklyDayOfWeekSelector renders correctly', (tester) async {
      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 2.5)
        ..addScenario(
          'With Selection',
          Material(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: WeeklyDayOfWeekSelector(
                selectedWeekdays: const {1, 3, 5},
                onChanged: (_) {},
              ),
            ),
          ),
        )
        ..addScenario(
          'Empty (Warning)',
          Material(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: WeeklyDayOfWeekSelector(
                selectedWeekdays: const {},
                onChanged: (_) {},
              ),
            ),
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(600, 400),
      );
      await screenMatchesGolden(tester, 'weekly_day_of_week_selector_golden');
    });
  });
}
