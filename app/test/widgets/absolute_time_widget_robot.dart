import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class AbsoluteTimeWidgetRobot {
  final WidgetTester tester;

  AbsoluteTimeWidgetRobot(this.tester);

  Future<void> openDatePicker() async {
    await tester.tap(find.byIcon(Icons.calendar_today));
    await tester.pumpAndSettle();
  }

  Future<void> openTimePicker() async {
    await tester.tap(find.byIcon(Icons.access_time));
    await tester.pumpAndSettle();
  }

  Future<void> pickDate(String day) async {
    // Note: This assumes the day is visible in the current month view.
    // If testing cross-month, helper needs to be more sophisticated.
    // day should be a string like '27'
    await tester.tap(find.text(day));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  Future<void> pickTime(int hour, int minute, {bool isAM = true}) async {
    // Select period first (in Dial mode)
    if (isAM) {
      await tester.tap(find.text('AM'));
    } else {
      await tester.tap(find.text('PM'));
    }

    // Switch to keyboard input for reliability
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();

    final hourField = find.byType(TextField).first; // Usually Hour is first
    final minuteField = find.byType(TextField).last; // Minute is last

    await tester.enterText(hourField, hour.toString().padLeft(2, '0'));
    await tester.enterText(minuteField, minute.toString().padLeft(2, '0'));

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }
}
