import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/widgets/interval_stepper.dart';
import '../test_helper.dart';

void main() {
  group('IntervalStepper', () {
    testWidgets('renders initial values correctly', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: IntervalStepper(
              interval: 1,
              onIntervalChanged: (_) {},
              label: 'Interval',
            ),
          ),
        ),
      );

      expect(find.text('Interval'), findsOneWidget);
      expect(find.text('1 day'), findsOneWidget);
    });

    testWidgets('renders days plural correctly', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: IntervalStepper(
              interval: 5,
              onIntervalChanged: (_) {},
              label: 'Interval',
            ),
          ),
        ),
      );

      expect(find.text('5 days'), findsOneWidget);
    });

    testWidgets('triggers callback on increment', (tester) async {
      int? changedValue;
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: IntervalStepper(
              interval: 2,
              onIntervalChanged: (val) => changedValue = val,
              label: 'Interval',
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('interval_increment_button')));
      await tester.pumpAndSettle();

      expect(changedValue, 3);
    });

    testWidgets('triggers callback on decrement', (tester) async {
      int? changedValue;
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: IntervalStepper(
              interval: 2,
              onIntervalChanged: (val) => changedValue = val,
              label: 'Interval',
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('interval_decrement_button')));
      await tester.pumpAndSettle();

      expect(changedValue, 1);
    });

    testWidgets('disables decrement button when interval is 1', (tester) async {
      int? changedValue;
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: IntervalStepper(
              interval: 1,
              onIntervalChanged: (val) => changedValue = val,
              label: 'Interval',
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('interval_decrement_button')));
      await tester.pumpAndSettle();

      expect(changedValue, isNull);
    });

    testWidgets('handles manual input focus and formatting', (tester) async {
      int? changedValue;
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: IntervalStepper(
              interval: 3,
              onIntervalChanged: (val) => changedValue = val,
              label: 'Interval',
            ),
          ),
        ),
      );

      final textFinder = find.byKey(const Key('interval_text_field'));
      expect(textFinder, findsOneWidget);

      // Focus the text field by tapping it
      await tester.tap(textFinder);
      await tester.pump();

      // Should show only digits when focused
      expect(find.text('3'), findsOneWidget);
      expect(find.text('3 days'), findsNothing);

      // Enter a new value
      await tester.enterText(textFinder, '12');
      await tester.pump();

      expect(changedValue, 12);

      // Unfocus
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      // Should format displaying "12 days"
      expect(find.text('12 days'), findsOneWidget);
    });

    testGoldens('IntervalStepper renders correctly', (tester) async {
      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 4)
        ..addScenario(
          'Interval 1 day',
          Material(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: IntervalStepper(
                interval: 1,
                onIntervalChanged: (_) {},
                label: 'Interval',
              ),
            ),
          ),
        )
        ..addScenario(
          'Interval 5 days',
          Material(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: IntervalStepper(
                interval: 5,
                onIntervalChanged: (_) {},
                label: 'Interval',
              ),
            ),
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(400, 300),
      );
      await screenMatchesGolden(tester, 'interval_stepper_golden');
    });
  });
}
