import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/widgets/recurrence_type_selector.dart';
import '../test_helper.dart';

void main() {
  group('RecurrenceTypeSelector', () {
    testWidgets('renders segmented button and repeating chips based on value', (
      tester,
    ) async {
      RecurrenceType? selected;

      // 1. Render with oneOff
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

      // Verify One-off and Repeating segments are present
      expect(find.text('One-off'), findsOneWidget);
      expect(find.text('Repeating'), findsOneWidget);

      // Verify repeating chips are NOT rendered when one-off is selected
      expect(find.byKey(const Key('recurrence_chip_daily')), findsNothing);
      expect(find.byKey(const Key('recurrence_chip_weekly')), findsNothing);

      // Tap the Repeating segment and verify callback to daily
      await tester.tap(find.text('Repeating'));
      await tester.pump();
      expect(selected, RecurrenceType.daily);

      // 2. Render with repeating type (daily)
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: RecurrenceTypeSelector(
              selectedValue: RecurrenceType.daily,
              onSelected: (val) {
                selected = val;
              },
            ),
          ),
        ),
      );

      // Verify repeating chips are rendered now
      expect(find.byKey(const Key('recurrence_chip_daily')), findsOneWidget);
      expect(find.byKey(const Key('recurrence_chip_weekly')), findsOneWidget);
      expect(find.byKey(const Key('recurrence_chip_monthly')), findsOneWidget);
      expect(find.byKey(const Key('recurrence_chip_yearly')), findsOneWidget);

      // Verify Daily chip is selected
      final ChoiceChip dailyChip = tester.widget(
        find.byKey(const Key('recurrence_chip_daily')),
      );
      expect(dailyChip.selected, isTrue);

      // Tap the Weekly chip and verify callback
      await tester.tap(find.byKey(const Key('recurrence_chip_weekly')));
      await tester.pump();
      expect(selected, RecurrenceType.weekly);
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
