import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:nothing_ever_happens/widgets/one_off_scheduling_widget.dart';

import 'package:nothing_ever_happens/widgets/absolute_time_widget.dart';
import 'one_off_scheduling_widget_robot.dart';
import 'absolute_time_widget_robot.dart';

void main() {
  group('OneOffSchedulingWidget', () {
    testWidgets('renders basic fields', (tester) async {
      final due = ValueNotifier(DateTime(2026, 10, 26, 12, 0));
      final start = ValueNotifier(DateTime(2026, 10, 26, 9, 0));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OneOffSchedulingWidget(
              dueDateTime: due,
              startDateTime: start,
            ),
          ),
        ),
      );

      expect(find.text('Due: '), findsOneWidget);
      expect(find.byType(AbsoluteTimeWidget), findsAtLeastNWidgets(1));
      expect(find.text('Advanced'), findsOneWidget);
    });

    testWidgets('shows snooze option always (expanded by default/design)', (
      tester,
    ) async {
      final due = ValueNotifier(DateTime(2026, 10, 26, 12, 0));
      final start = ValueNotifier(DateTime(2026, 10, 26, 9, 0));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OneOffSchedulingWidget(
              dueDateTime: due,
              startDateTime: start,
            ),
          ),
        ),
      );

      // Snooze should be visible now as we removed ExpansionTile
      expect(find.text('Snooze Until: '), findsOneWidget);
      expect(find.byType(AbsoluteTimeWidget), findsNWidgets(2)); // Due + Snooze
    });

    testWidgets('updates controllers when time is changed', (tester) async {
      final due = ValueNotifier(DateTime(2026, 10, 26, 12, 0));
      final start = ValueNotifier(DateTime(2026, 10, 26, 9, 0));
      final oneOffRobot = OneOffSchedulingWidgetRobot(tester);
      final absoluteRobot = AbsoluteTimeWidgetRobot(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OneOffSchedulingWidget(
              dueDateTime: due,
              startDateTime: start,
            ),
          ),
        ),
      );

      // Change Due time
      await oneOffRobot.openDueTimePicker();
      await absoluteRobot.pickTime(10, 0, isAM: false); // 10 PM = 22:00

      expect(due.value.hour, 22);

      // Change Snooze time
      await oneOffRobot.openSnoozeTimePicker();
      await absoluteRobot.pickTime(8, 30, isAM: true); // 8:30 AM

      expect(start.value.hour, 8);
      expect(start.value.minute, 30);
    });
    testGoldens('OneOffSchedulingWidget renders correctly', (tester) async {
      final due = ValueNotifier(DateTime(2026, 10, 26, 12, 0));
      final start = ValueNotifier(DateTime(2026, 10, 26, 9, 0));

      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 2)
        ..addScenario(
          'Default',
          OneOffSchedulingWidget(dueDateTime: due, startDateTime: start),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: materialAppWrapper(),
      );
      await screenMatchesGolden(tester, 'one_off_scheduling_widget');
    });
  });
}
