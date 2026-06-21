import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class WeeklySchedulingWidgetRobot {
  final WidgetTester tester;

  WeeklySchedulingWidgetRobot(this.tester);

  Finder get startRecurrenceDateTile =>
      find.byKey(const Key('start_recurrence_date_tile'));
  Finder get intervalField => find.byKey(const Key('interval_text_field'));

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

  Future<void> selectIntervalType(String typeText) async {
    // No-op: Done at a higher level via HierarchicalRecurrenceSelector now
  }

  Future<void> toggleDayByIndex(int index) async {
    // Index 0 = Monday (dayIndex = 1)
    final dayIndex = index + 1;
    await tester.tap(find.byKey(Key('weekly_weekday_chip_$dayIndex')));
    await tester.pumpAndSettle();
  }

  Future<void> tapPresetWeekdays() async {
    await tester.tap(find.byKey(const Key('preset_weekdays_button')));
    await tester.pumpAndSettle();
  }

  Future<void> tapPresetWeekends() async {
    await tester.tap(find.byKey(const Key('preset_weekends_button')));
    await tester.pumpAndSettle();
  }

  Future<void> tapPresetAll() async {
    await tester.tap(find.byKey(const Key('preset_all_button')));
    await tester.pumpAndSettle();
  }

  Future<void> tapPresetClear() async {
    await tester.tap(find.byKey(const Key('preset_clear_button')));
    await tester.pumpAndSettle();
  }
}
