import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class DailySchedulingWidgetRobot {
  final WidgetTester tester;

  DailySchedulingWidgetRobot(this.tester);

  Finder get startRecurrenceDateTile =>
      find.byKey(const Key('start_recurrence_date_tile'));
  Finder get intervalExpansionTile =>
      find.byKey(const Key('daily_interval_expansion_tile'));
  Finder get intervalField => find.byKey(const Key('daily_interval_field'));
  Finder get intervalTypeDropdown =>
      find.byKey(const Key('daily_interval_type_dropdown'));

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
    if (find.byKey(const Key('daily_interval_field')).evaluate().isEmpty) {
      await expandIntervalSection();
    }
    await tester.enterText(intervalField, val);
    await tester.pumpAndSettle();
  }

  Future<void> selectIntervalType(String typeText) async {
    if (find.byKey(const Key('daily_interval_field')).evaluate().isEmpty) {
      await expandIntervalSection();
    }
    await tester.tap(intervalTypeDropdown);
    await tester.pumpAndSettle();
    // Tap the dropdown option from the pop-up/overlay
    await tester.tap(find.text(typeText).last);
    await tester.pumpAndSettle();
  }
}
