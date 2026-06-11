import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/widgets/standard_choice_chip.dart';
import '../test_helper.dart';

void main() {
  group('StandardChoiceChip', () {
    testWidgets('renders label and handles selection state', (tester) async {
      bool? selectedState;

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: Center(
              child: StandardChoiceChip(
                key: const Key('test_chip'),
                label: 'Test Chip',
                selected: false,
                onSelected: (val) {
                  selectedState = val;
                },
              ),
            ),
          ),
        ),
      );

      // Verify label is rendered
      expect(find.text('Test Chip'), findsOneWidget);

      // Verify chip properties
      final chipFinder = find.byKey(const Key('test_chip'));
      expect(chipFinder, findsOneWidget);
      final StandardChoiceChip chipWidget = tester.widget(chipFinder);
      expect(chipWidget.selected, isFalse);

      // Tap the chip and verify the callback is triggered
      await tester.tap(chipFinder);
      await tester.pump();

      expect(selectedState, isTrue);
    });

    testWidgets('renders unselected state', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: Center(
              child: StandardChoiceChip(
                key: const Key('test_chip_unselected'),
                label: 'Unselected Chip',
                selected: false,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      final chipFinder = find.byKey(const Key('test_chip_unselected'));
      expect(chipFinder, findsOneWidget);
      final StandardChoiceChip chipWidget = tester.widget(chipFinder);
      expect(chipWidget.selected, isFalse);
    });

    testGoldens('StandardChoiceChip renders correctly in different states', (
      tester,
    ) async {
      final builder = GoldenBuilder.column()
        ..addScenario(
          'Selected',
          StandardChoiceChip(
            label: 'Selected Chip',
            selected: true,
            onSelected: (_) {},
          ),
        )
        ..addScenario(
          'Not Selected',
          StandardChoiceChip(
            label: 'Not Selected Chip',
            selected: false,
            onSelected: (_) {},
          ),
        )
        ..addScenario(
          'Disabled Selected',
          StandardChoiceChip(
            label: 'Disabled Selected',
            selected: true,
            onSelected: null,
          ),
        )
        ..addScenario(
          'Disabled Not Selected',
          StandardChoiceChip(
            label: 'Disabled Not Selected',
            selected: false,
            onSelected: null,
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
      );

      await screenMatchesGolden(tester, 'standard_choice_chip_golden');
    });
  });
}
