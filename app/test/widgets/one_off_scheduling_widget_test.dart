import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/widgets/one_off_scheduling_widget.dart';
import 'package:nothing_ever_happens/widgets/absolute_time_widget.dart';
import '../test_helper.dart';
import 'one_off_scheduling_widget_robot.dart';
import 'absolute_time_widget_robot.dart';

void main() {
  group('OneOffSchedulingWidget', () {
    testWidgets('renders basic fields', (tester) async {
      final due = ValueNotifier(DateTime(2026, 10, 26, 12, 0));
      final start = ValueNotifier(DateTime(2026, 10, 26, 9, 0));

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: OneOffSchedulingWidget(
              dueDateTime: due,
              startDateTime: start,
            ),
          ),
        ),
      );

      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Due'), findsOneWidget);
      expect(find.byType(AbsoluteTimeWidget), findsAtLeastNWidgets(2));
    });

    testWidgets('shows snooze option always (expanded by default/design)', (
      tester,
    ) async {
      final due = ValueNotifier(DateTime(2026, 10, 26, 12, 0));
      final start = ValueNotifier(DateTime(2026, 10, 26, 9, 0));

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: OneOffSchedulingWidget(
              dueDateTime: due,
              startDateTime: start,
            ),
          ),
        ),
      );

      // Start should be visible now
      expect(find.text('Start'), findsOneWidget);
      expect(find.byType(AbsoluteTimeWidget), findsNWidgets(2)); // Start + Due
    });

    testWidgets('updates controllers when time is changed', (tester) async {
      final due = ValueNotifier(DateTime(2026, 10, 26, 12, 0));
      final start = ValueNotifier(DateTime(2026, 10, 26, 9, 0));
      final oneOffRobot = OneOffSchedulingWidgetRobot(tester);
      final absoluteRobot = AbsoluteTimeWidgetRobot(tester);

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
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
        wrapper: l10nMaterialAppWrapper(),
      );
      await screenMatchesGolden(tester, 'one_off_scheduling_widget');
    });
  });
}
