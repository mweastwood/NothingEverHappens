import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'relative_time_widget_robot.dart';

class WeeklySchedulingWidgetRobot {
  final WidgetTester tester;

  WeeklySchedulingWidgetRobot(this.tester);

  RelativeTimeWidgetRobot get startTime {
    final row = find
        .ancestor(of: find.text('Start Time'), matching: find.byType(Row))
        .first;
    return RelativeTimeWidgetRobot(tester, parent: row);
  }

  RelativeTimeWidgetRobot get dueTime {
    final row = find
        .ancestor(of: find.text('Due Time'), matching: find.byType(Row))
        .first;
    return RelativeTimeWidgetRobot(tester, parent: row);
  }

  Future<void> pickStartDate(String day) async {
    await tester.tap(find.text('Start Date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(day));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  Future<void> enterInterval(String interval) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Weeks Interval'),
      interval,
    );
    await tester.pump();
  }

  Future<void> toggleDay(String label) async {
    // Labels: M, T, W, T, F, S, S
    // Finds FilterChip with text.
    // Since there are duplicate labels (T, S), we might need to be specific or assume order?
    // User interface puts them in a Wrap.
    // Robot user might want to tap the first 'T' (Tuesday) or second 'T' (Thursday).
    // Let's accept label, but if ambiguous, maybe index?
    // Or just find widget with text.
    // If ambiguous, find.widgetWithText might find multiple.

    // For simplicity, let's assume unique enough or tappable.
    // But 'T' is twice.

    // We can expose toggleMonday, toggleTuesday etc.
    // Or toggleDay(int index) (0-6).

    // Let's stick to toggleDay(String) but if it finds multiple, tap first/last?
    // Better: toggleDay(String label, {int? index})

    // Actually, in the test I wrote earlier:
    // await tester.tap(find.widgetWithText(FilterChip, 'T').first);

    // I'll implement toggleDay(String label, {bool first = true}).

    final finder = find.widgetWithText(FilterChip, label);
    if (finder.evaluate().length > 1) {
      // This logic is tricky inside robot without argument.
      // Let's expose specific methods or use index.
    }

    await tester.tap(
      finder.first,
    ); // Default to first matches existing test behavior for T
    await tester.pump();
  }

  Future<void> toggleDayByIndex(int index) async {
    // Weekdays are in a Wrap. Index 0 = Monday.
    final wrap = find.byType(Wrap);
    final chips = find.descendant(of: wrap, matching: find.byType(FilterChip));
    await tester.tap(chips.at(index));
    await tester.pump();
  }
}
