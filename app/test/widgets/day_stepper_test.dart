import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/widgets/day_stepper.dart';
import '../test_helper.dart';

void main() {
  group('DayStepper', () {
    test('getOrdinalDaySuffix returns expected English suffixes', () {
      expect(getOrdinalDaySuffix(1), 'st');
      expect(getOrdinalDaySuffix(2), 'nd');
      expect(getOrdinalDaySuffix(3), 'rd');
      expect(getOrdinalDaySuffix(4), 'th');
      expect(getOrdinalDaySuffix(11), 'th');
      expect(getOrdinalDaySuffix(12), 'th');
      expect(getOrdinalDaySuffix(13), 'th');
      expect(getOrdinalDaySuffix(21), 'st');
      expect(getOrdinalDaySuffix(22), 'nd');
      expect(getOrdinalDaySuffix(23), 'rd');
      expect(getOrdinalDaySuffix(28), 'th');
    });

    testWidgets('renders initial day, label, and optional suffix', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: DayStepper(
              day: 21,
              maxDays: 28,
              onDayChanged: (_) {},
              label: 'Day of Month',
              textFieldKey: const Key('day_input'),
              rangeErrorText: '1-28',
              suffixBuilder: getOrdinalDaySuffix,
            ),
          ),
        ),
      );

      expect(find.text('Day of Month'), findsOneWidget);
      expect(find.text('21'), findsOneWidget);
      expect(find.text('st'), findsOneWidget);
    });

    testWidgets(
      'increments and decrements within bounds and disables at limits',
      (tester) async {
        int? changedDay;
        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: DayStepper(
                day: 1,
                maxDays: 28,
                onDayChanged: (val) => changedDay = val,
                label: 'Day',
                textFieldKey: const Key('day_input'),
                rangeErrorText: '1-28',
              ),
            ),
          ),
        );

        // At day = 1, decrement is disabled
        final decBtn = tester.widget<IconButton>(
          find.byKey(const Key('day_decrement_button')),
        );
        expect(decBtn.onPressed, isNull);

        await tester.tap(find.byKey(const Key('day_increment_button')));
        await tester.pump();
        expect(changedDay, 2);

        // At day = maxDays, increment is disabled
        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: DayStepper(
                day: 28,
                maxDays: 28,
                onDayChanged: (val) => changedDay = val,
                label: 'Day',
                textFieldKey: const Key('day_input'),
                rangeErrorText: '1-28',
              ),
            ),
          ),
        );
        final incBtn = tester.widget<IconButton>(
          find.byKey(const Key('day_increment_button')),
        );
        expect(incBtn.onPressed, isNull);

        await tester.tap(find.byKey(const Key('day_decrement_button')));
        await tester.pump();
        expect(changedDay, 27);
      },
    );

    testWidgets('clamps out-of-range text input on unfocus', (tester) async {
      int? changedDay;
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: DayStepper(
              day: 10,
              maxDays: 28,
              onDayChanged: (val) => changedDay = val,
              label: 'Day',
              textFieldKey: const Key('day_input'),
              rangeErrorText: '1-28',
            ),
          ),
        ),
      );

      final field = find.byKey(const Key('day_input'));
      await tester.tap(field);
      await tester.pump();
      await tester.enterText(field, '99');
      await tester.pump();

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(changedDay, 28);
      expect(find.text('28'), findsOneWidget);
    });
  });
}
