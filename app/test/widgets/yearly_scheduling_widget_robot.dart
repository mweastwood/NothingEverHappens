import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class YearlySchedulingWidgetRobot {
  final WidgetTester tester;

  YearlySchedulingWidgetRobot(this.tester);

  Finder get startRecurrenceDateTile =>
      find.byKey(const Key('yearly_start_recurrence_date_tile'));
  Finder get intervalExpansionTile =>
      find.byKey(const Key('yearly_interval_expansion_tile'));
  Finder get intervalField => find.byKey(const Key('yearly_interval_field'));
  Finder get monthDropdown => find.byKey(const Key('yearly_month_dropdown'));
  Finder get dayField => find.byKey(const Key('yearly_day_field'));

  Future<void> pickStartDate(String day) async {
    await tester.tap(startRecurrenceDateTile);
    await tester.pumpAndSettle();
    await tester.tap(find.text(day));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  Future<void> expandIntervalSection() async {
    await tester.tap(intervalExpansionTile);
    await tester.pumpAndSettle();
  }

  Future<void> enterInterval(String val) async {
    if (find.byKey(const Key('yearly_interval_field')).evaluate().isEmpty) {
      await expandIntervalSection();
    }
    await tester.enterText(intervalField, val);
    await tester.pumpAndSettle();
  }

  Future<void> selectMonth(String monthText) async {
    await tester.tap(monthDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(monthText).last);
    await tester.pumpAndSettle();
  }

  Future<void> enterDay(String val) async {
    await tester.enterText(dayField, val);
    await tester.pumpAndSettle();
  }
}
