import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MonthlySchedulingWidgetRobot {
  final WidgetTester tester;

  MonthlySchedulingWidgetRobot(this.tester);

  Finder get startRecurrenceDateTile =>
      find.byKey(const Key('start_recurrence_date_tile'));
  Finder get intervalField => find.byKey(const Key('interval_text_field'));
  Finder get dayOfMonthField =>
      find.byKey(const Key('monthly_day_of_month_field'));
  Finder get occurrenceDropdown =>
      find.byKey(const Key('monthly_occurrence_dropdown'));
  Finder get dayOfWeekDropdown =>
      find.byKey(const Key('monthly_day_of_week_dropdown'));

  Future<void> pickStartDate(String day) async {
    await tester.tap(startRecurrenceDateTile);
    await tester.pumpAndSettle();
    await tester.tap(find.text(day));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  Future<void> expandIntervalSection() async {
    // No-op: Interval is always visible in the new design
  }

  Future<void> enterInterval(String val) async {
    await tester.enterText(intervalField, val);
    await tester.pumpAndSettle();
  }

  Future<void> selectRuleType(String typeText) async {
    // No-op: Rule type dropdown was removed as it is redundant with parent selector
  }

  Future<void> enterDayOfMonth(String val) async {
    await tester.enterText(dayOfMonthField, val);
    await tester.pumpAndSettle();
  }

  Future<void> selectOccurrence(String occText) async {
    await tester.tap(occurrenceDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(occText).last);
    await tester.pumpAndSettle();
  }

  Future<void> selectDayOfWeek(String dayText) async {
    await tester.tap(dayOfWeekDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(dayText).last);
    await tester.pumpAndSettle();
  }
}
