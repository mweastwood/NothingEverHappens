import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/widgets/date_stepper.dart';
import '../test_helper.dart';

void main() {
  group('DateStepper', () {
    final testDate = DateTime(2026, 10, 26);

    testWidgets('renders initial date correctly', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: DateStepper(
              date: testDate,
              onDateChanged: (_) {},
              label: 'Start Date',
            ),
          ),
        ),
      );

      expect(find.text('Start Date'), findsOneWidget);
      expect(find.text('2026-10-26'), findsOneWidget);
    });

    testWidgets('triggers callback on increment', (tester) async {
      DateTime? changedValue;
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: DateStepper(
              date: testDate,
              onDateChanged: (val) => changedValue = val,
              label: 'Start Date',
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('date_increment_button')));
      await tester.pumpAndSettle();

      expect(changedValue, DateTime(2026, 10, 27));
    });

    testWidgets('triggers callback on decrement', (tester) async {
      DateTime? changedValue;
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: DateStepper(
              date: testDate,
              onDateChanged: (val) => changedValue = val,
              label: 'Start Date',
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('date_decrement_button')));
      await tester.pumpAndSettle();

      expect(changedValue, DateTime(2026, 10, 25));
    });

    testWidgets('shows date picker on center tile tap', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: DateStepper(
              date: testDate,
              onDateChanged: (_) {},
              label: 'Start Date',
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('start_recurrence_date_tile')));
      await tester.pumpAndSettle();

      // Check if DatePicker dialog is displayed
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testGoldens('DateStepper renders correctly', (tester) async {
      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 4)
        ..addScenario(
          'DateStepper Default',
          Material(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: DateStepper(
                date: testDate,
                onDateChanged: (_) {},
                label: 'Start Date',
              ),
            ),
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(400, 200),
      );
      await screenMatchesGolden(tester, 'date_stepper_golden');
    });
  });
}
