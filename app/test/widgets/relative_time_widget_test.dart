import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/widgets/relative_time_widget.dart';

void main() {
  Widget buildTestApp(
    Duration initialValue,
    Function(Duration) onChanged, {
    RelativeTimeConstraint constraint = RelativeTimeConstraint.forward,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) {
            return RelativeTimeWidget(
              value: initialValue,
              onChanged: (newValue) {
                setState(() {
                  initialValue = newValue;
                });
                onChanged(newValue);
              },
              constraint: constraint,
            );
          },
        ),
      ),
    );
  }

  testWidgets('RelativeTimeWidget renders initial state correctly (Day of)', (
    WidgetTester tester,
  ) async {
    Duration value = const Duration(hours: 14, minutes: 30); // 14:30

    await tester.pumpWidget(buildTestApp(value, (v) {}));

    // Check for 14:30 or 2:30 PM.
    // Simplifying: just find a text widget containing "2:30" or "14:30".
    expect(
      find.byWidgetPredicate((widget) {
        if (widget is Text) {
          final data = widget.data ?? '';
          return data.contains('14:30') || data.contains('2:30');
        }
        return false;
      }),
      findsOneWidget,
    );

    expect(find.text('Day of'), findsOneWidget);
    final segments = tester.widget<SegmentedButton<int>>(
      find.byType(SegmentedButton<int>),
    );
    expect(segments.selected.first, 0);
  });

  testWidgets('RelativeTimeWidget renders 1 day after correctly', (
    WidgetTester tester,
  ) async {
    Duration value = const Duration(days: 1, hours: 9, minutes: 0);

    await tester.pumpWidget(
      buildTestApp(value, (v) {}, constraint: RelativeTimeConstraint.forward),
    );

    expect(
      find.byWidgetPredicate((widget) {
        if (widget is Text) {
          final data = widget.data ?? '';
          return data.contains('9:00') || data.contains('09:00');
        }
        return false;
      }),
      findsOneWidget,
    );

    final segments = tester.widget<SegmentedButton<int>>(
      find.byType(SegmentedButton<int>),
    );
    expect(segments.selected.first, 1);
    expect(find.text('1 day after'), findsOneWidget);
  });

  testWidgets('RelativeTimeWidget renders 1 day before correctly', (
    WidgetTester tester,
  ) async {
    Duration value = const Duration(days: -1, hours: 9, minutes: 0);

    await tester.pumpWidget(
      buildTestApp(value, (v) {}, constraint: RelativeTimeConstraint.backward),
    );

    final segments = tester.widget<SegmentedButton<int>>(
      find.byType(SegmentedButton<int>),
    );
    expect(
      segments.selected.first,
      1,
    ); // Logic maps -1 to the valid "1" segment for backward (value 1 in UI)
    // Wait, let's double check widget implementation for segments.
    // In widget: value: 1, label: oneDayLabel.
    // Logic: if (constraint == backward && _dayOffset == -1) return 1.
    // So selected value is indeed 1.

    expect(find.text('1 day before'), findsOneWidget);
  });

  testWidgets('RelativeTimeWidget updates value when segments change', (
    WidgetTester tester,
  ) async {
    Duration value = const Duration(hours: 10);
    Duration? capturedValue;

    await tester.pumpWidget(
      buildTestApp(value, (v) {
        capturedValue = v;
      }),
    );

    await tester.tap(find.text('1 day after'));
    await tester.pump();

    expect(capturedValue, isNotNull);
    expect(capturedValue!.inDays, 1);
    // 10:00 -> 10 hours
    expect(capturedValue!.inHours % 24, 10);
  });

  testWidgets('RelativeTimeWidget custom input updates value', (
    WidgetTester tester,
  ) async {
    Duration value = const Duration(hours: 10);
    Duration? capturedValue;

    await tester.pumpWidget(
      buildTestApp(value, (v) {
        capturedValue = v;
      }),
    );

    // Tap "Custom"
    await tester.tap(find.text('Custom'));
    await tester.pump();

    // Default custom transition is 2 days
    expect(capturedValue!.inDays, 2);

    // Now field should exist, but SegmentedButton should be gone
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(SegmentedButton<int>), findsNothing);

    await tester.enterText(find.byType(TextField), '5');
    // TextField onChanged usually doesn't require extra pump if flutter_test handles it?
    // Usually need to pump to trigger rebuilds if setState called.
    // The widget calls _updateValue which triggers parent setState.
    await tester.pump();

    expect(capturedValue!.inDays, 5);
    expect(capturedValue!.inHours % 24, 10);
  });

  testWidgets(
    'RelativeTimeWidget handles negative duration (backward logic) correctly',
    (WidgetTester tester) async {
      // -26 hours = -2 days + 22 hours (10 PM)
      Duration value = const Duration(hours: -26);

      await tester.pumpWidget(
        buildTestApp(
          value,
          (v) {},
          constraint: RelativeTimeConstraint.backward,
        ),
      );

      // Custom
      // Since we are in custom mode, SegmentedButton is gone.
      expect(find.byType(SegmentedButton<int>), findsNothing);
      expect(find.byType(TextField), findsOneWidget);

      // Time check: 22:00 or 10:00 PM
      expect(
        find.byWidgetPredicate((widget) {
          if (widget is Text) {
            final data = widget.data ?? '';
            return data.contains('22:00') ||
                (data.contains('10:00') && data.contains('PM'));
          }
          return false;
        }),
        findsOneWidget,
      );

      // Day offset check
      // The controller text is absolute days: 2
      expect(find.text('2'), findsOneWidget);
    },
  );
}
