import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/widgets/hierarchical_recurrence_selector.dart';
import '../test_helper.dart';

void main() {
  group('HierarchicalRecurrenceSelector', () {
    testWidgets(
      'renders segmented button and hides repeating cadences when one-off',
      (tester) async {
        HierarchicalRecurrenceKind? selected;

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: HierarchicalRecurrenceSelector(
                selectedValue: HierarchicalRecurrenceKind.oneOff,
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

        // Verify repeating chips and specialization options are NOT rendered
        expect(find.byKey(const Key('recurrence_chip_daily')), findsNothing);
        expect(find.text('RECURRENCE TYPE'), findsNothing);

        // Tap Repeating segment
        await tester.tap(find.text('Repeating'));
        await tester.pump();
        expect(selected, HierarchicalRecurrenceKind.dailyFixed);
      },
    );

    testWidgets(
      'shows cadence chips and specialization well when repeating is selected',
      (tester) async {
        HierarchicalRecurrenceKind? selected;

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: HierarchicalRecurrenceSelector(
                selectedValue: HierarchicalRecurrenceKind.dailyFixed,
                onSelected: (val) {
                  selected = val;
                },
              ),
            ),
          ),
        );

        // Verify cadence chips are rendered
        expect(find.byKey(const Key('recurrence_chip_daily')), findsOneWidget);
        expect(find.byKey(const Key('recurrence_chip_weekly')), findsOneWidget);
        expect(
          find.byKey(const Key('recurrence_chip_monthly')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('recurrence_chip_yearly')), findsOneWidget);

        // Verify the specialization options are rendered
        expect(find.text('RECURRENCE TYPE'), findsOneWidget);
        expect(find.text('On a fixed schedule'), findsOneWidget);
        expect(find.text('Based on when last completed'), findsOneWidget);

        // Tap Weekly chip
        await tester.tap(find.byKey(const Key('recurrence_chip_weekly')));
        await tester.pump();
        expect(selected, HierarchicalRecurrenceKind.weeklyFixed);
      },
    );

    testWidgets('triggers callback when a specialization is tapped', (
      tester,
    ) async {
      HierarchicalRecurrenceKind? selected;

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: HierarchicalRecurrenceSelector(
              selectedValue: HierarchicalRecurrenceKind.weeklyFixed,
              onSelected: (val) {
                selected = val;
              },
            ),
          ),
        ),
      );

      // Tapping the completion relative option
      await tester.tap(find.text('Based on when last completed'));
      await tester.pump();
      expect(selected, HierarchicalRecurrenceKind.weeklyCompletionRelative);
    });

    for (final kind in HierarchicalRecurrenceKind.values) {
      final snakeName = kind.name.replaceAllMapped(
        RegExp(r'([A-Z])'),
        (match) => '_${match.group(1)!.toLowerCase()}',
      );

      testGoldens('HierarchicalRecurrenceSelector renders $kind correctly', (
        tester,
      ) async {
        final builder = GoldenBuilder.column()
          ..addScenario(
            kind.toString(),
            HierarchicalRecurrenceSelector(
              selectedValue: kind,
              onSelected: (_) {},
            ),
          );

        await tester.pumpWidgetBuilder(
          builder.build(),
          wrapper: l10nMaterialAppWrapper(),
        );

        await screenMatchesGolden(
          tester,
          'hierarchical_recurrence_selector_$snakeName',
        );
      });
    }
  });
}
