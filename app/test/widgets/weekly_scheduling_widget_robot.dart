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
    // Weekdays are in a Wrap. Index 0 = Monday.
    final wrap = find.byType(Wrap);
    final chips = find.descendant(of: wrap, matching: find.byType(FilterChip));
    await tester.tap(chips.at(index));
    await tester.pumpAndSettle();
  }
}
