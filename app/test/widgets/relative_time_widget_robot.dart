import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/widgets/relative_time_widget.dart';

/// A Robot for interacting with [RelativeTimeWidget] in tests.
///
/// Wraps [WidgetTester] to provide a semantic API for finding and interacting
/// with the widget's internal components, decoupling tests from implementation details.
///
/// Example:
/// ```dart
/// final robot = RelativeTimeWidgetRobot(tester);
///
/// // Interactions
/// await robot.selectDayAfter();
/// await robot.enterCustomDays('5');
///
/// // Assertions
/// expect(robot.timeTextFinder, findsOneWidget);
/// expect(find.text('5 days later'), findsOneWidget);
/// ```
class RelativeTimeWidgetRobot {
  final WidgetTester tester;

  RelativeTimeWidgetRobot(this.tester);

  Future<void> selectDayOf() async {
    await tester.tap(find.text('Day of'));
    await tester.pumpAndSettle();
  }

  Future<void> selectDayAfter() async {
    await tester.tap(find.text('1 day after'));
    await tester.pumpAndSettle();
  }

  Future<void> selectDayBefore() async {
    await tester.tap(find.text('1 day before'));
    await tester.pumpAndSettle();
  }

  Future<void> selectCustom() async {
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
  }

  Future<void> enterCustomDays(String days) async {
    await tester.enterText(customTextField, days);
    await tester.pump();
  }

  Future<void> pickTime(int hour, int minute) async {
    // Tap the time button
    await tester.tap(timeTextFinder);
    await tester.pumpAndSettle(); // Wait for dialog

    // Switch to input mode for easier testing
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();

    // Enter time
    await tester.enterText(find.byType(TextField).first, hour.toString());
    await tester.enterText(find.byType(TextField).last, minute.toString());
    await tester.pump();

    // Tap OK
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle(); // Wait for dialog to close
  }

  Future<void> closeCustomMode() async {
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
  }

  Finder get segmentedButton {
    return find.byWidgetPredicate((widget) => widget is SegmentedButton);
  }

  Finder get customTextField => find.byType(TextField);

  Finder get timeTextFinder => find.byWidgetPredicate((widget) {
    if (widget is FilledButton) {
      final child = widget.child;
      if (child is Row) {
        // Look for the text inside the button
        for (final childWidget in child.children) {
          if (childWidget is Text &&
              (childWidget.data?.contains(':') ?? false)) {
            return true;
          }
        }
      }
      return true;
    }
    return false;
  }).first;
}
