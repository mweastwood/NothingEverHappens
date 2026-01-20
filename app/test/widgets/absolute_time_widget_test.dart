import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/widgets/absolute_time_widget.dart';
import 'absolute_time_widget_robot.dart';

void main() {
  group('AbsoluteTimeWidget', () {
    testWidgets('renders initial value', (tester) async {
      final initialDate = DateTime(2026, 10, 26, 14, 30);
      final controller = ValueNotifier(initialDate);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AbsoluteTimeWidget(controller: controller)),
        ),
      );

      expect(find.text('2:30 PM'), findsOneWidget);
      expect(find.text('2026-10-26'), findsOneWidget);
    });

    testWidgets('updates when controller changes', (tester) async {
      final initialDate = DateTime(2026, 10, 26, 14, 30);
      final controller = ValueNotifier(initialDate);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AbsoluteTimeWidget(controller: controller)),
        ),
      );

      final newDate = DateTime(2026, 12, 25, 9, 0);
      controller.value = newDate;
      await tester.pumpAndSettle();

      expect(find.text('9:00 AM'), findsOneWidget);
      expect(find.text('2026-12-25'), findsOneWidget);
    });

    testWidgets('updates controller when time is picked', (tester) async {
      final initialDate = DateTime(2026, 10, 26, 14, 30);
      final controller = ValueNotifier(initialDate);
      final robot = AbsoluteTimeWidgetRobot(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AbsoluteTimeWidget(controller: controller)),
        ),
      );

      await robot.openTimePicker();
      await robot.pickTime(10, 0);

      expect(controller.value.hour, 10);
      expect(controller.value.minute, 0);
      expect(controller.value.day, 26); // Date should remain same
    });

    testWidgets('updates controller when date is picked', (tester) async {
      final initialDate = DateTime(2026, 10, 26, 14, 30);
      final controller = ValueNotifier(initialDate);
      final robot = AbsoluteTimeWidgetRobot(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AbsoluteTimeWidget(controller: controller)),
        ),
      );

      await robot.openDatePicker();
      await robot.pickDate('15');

      expect(controller.value.day, 15);
      expect(
        controller.value.month,
        10,
      ); // Month should remain same if available
      expect(controller.value.hour, 14); // Time should remain same
    });
  });
}
