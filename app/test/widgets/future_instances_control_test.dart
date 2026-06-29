import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/widgets/future_instances_control.dart';
import '../test_helper.dart';

void main() {
  group('FutureInstancesControl', () {
    testWidgets('renders count and helper text correctly', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: const Scaffold(
            body: FutureInstancesControl(futureInstancesCount: 5),
          ),
        ),
      );

      expect(find.text('5'), findsOneWidget);
      expect(find.text('Future Occurrences'), findsOneWidget);
      expect(find.text('Pre-created future tasks (1-10)'), findsOneWidget);
    });

    testWidgets('triggers callback on increment', (tester) async {
      int? updatedValue;
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: FutureInstancesControl(
              futureInstancesCount: 5,
              onChanged: (val) => updatedValue = val,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('add_future_instances_button')));
      await tester.pumpAndSettle();

      expect(updatedValue, 6);
    });

    testWidgets('triggers callback on decrement', (tester) async {
      int? updatedValue;
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: FutureInstancesControl(
              futureInstancesCount: 5,
              onChanged: (val) => updatedValue = val,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('remove_future_instances_button')));
      await tester.pumpAndSettle();

      expect(updatedValue, 4);
    });

    testWidgets('disables decrement at lower limit (1)', (tester) async {
      int? updatedValue;
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: FutureInstancesControl(
              futureInstancesCount: 1,
              onChanged: (val) => updatedValue = val,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('remove_future_instances_button')));
      await tester.pumpAndSettle();

      expect(updatedValue, isNull);
    });

    testWidgets('disables increment at upper limit (10)', (tester) async {
      int? updatedValue;
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: FutureInstancesControl(
              futureInstancesCount: 10,
              onChanged: (val) => updatedValue = val,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('add_future_instances_button')));
      await tester.pumpAndSettle();

      expect(updatedValue, isNull);
    });

    testGoldens('FutureInstancesControl renders correctly', (tester) async {
      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 4)
        ..addScenario(
          'FutureInstancesControl Default',
          const Material(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: FutureInstancesControl(futureInstancesCount: 3),
            ),
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(400, 200),
      );

      await screenMatchesGolden(tester, 'future_instances_control_golden');
    });
  });
}
