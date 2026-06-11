import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/task.dart';
import 'package:nothing_ever_happens/widgets/standard_choice_chip.dart';
import 'package:nothing_ever_happens/widgets/recurrence_type_selector.dart';
import '../test_helper.dart';

void main() {
  group('RecurrenceTypeSelector', () {
    testWidgets('renders all chips and shows selected value', (tester) async {
      RecurrenceType? selected;

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: RecurrenceTypeSelector(
              selectedValue: RecurrenceType.oneOff,
              onSelected: (val) {
                selected = val;
              },
            ),
          ),
        ),
      );

      // Verify all options are rendered
      expect(find.text('One-off'), findsOneWidget);
      expect(find.text('Daily'), findsOneWidget);
      expect(find.text('Weekly'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('Yearly'), findsOneWidget);

      // Verify One-off chip is selected
      final oneOffChipFinder = find.byKey(const Key('recurrence_chip_oneOff'));
      expect(oneOffChipFinder, findsOneWidget);
      final StandardChoiceChip oneOffChip = tester.widget(oneOffChipFinder);
      expect(oneOffChip.selected, isTrue);

      // Tap the Daily chip and verify callback
      await tester.tap(find.byKey(const Key('recurrence_chip_daily')));
      await tester.pump();

      expect(selected, RecurrenceType.daily);
    });

    testGoldens('RecurrenceTypeSelector renders correctly', (tester) async {
      final builder = GoldenBuilder.column()
        ..addScenario(
          'One-Off Selected',
          RecurrenceTypeSelector(
            selectedValue: RecurrenceType.oneOff,
            onSelected: (_) {},
          ),
        )
        ..addScenario(
          'Weekly Selected',
          RecurrenceTypeSelector(
            selectedValue: RecurrenceType.weekly,
            onSelected: (_) {},
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
      );

      await screenMatchesGolden(tester, 'recurrence_type_selector_golden');
    });
  });
}
