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
  final Finder? parent;

  RelativeTimeWidgetRobot(this.tester, {this.parent});

  Finder _find(Finder finder) {
    if (parent != null) {
      return find.descendant(of: parent!, matching: finder);
    }
    return finder;
  }

  Future<void> _openOffsetDialog() async {
    await tester.tap(find.byIcon(Icons.calendar_today));
    await tester.pumpAndSettle();
  }

  Future<void> selectDayOf() async {
    await _openOffsetDialog();
    await tester.tap(find.text('Day of').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  Future<void> selectDayAfter() async {
    await _openOffsetDialog();
    await tester.tap(find.text('1 day after').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  Future<void> selectDayBefore() async {
    await _openOffsetDialog();
    await tester.tap(find.text('1 day before').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  Future<void> openDialog() async {
    await _openOffsetDialog();
  }

  Future<void> tapIncrement([int times = 1]) async {
    for (int i = 0; i < times; i++) {
      await tester.tap(find.byKey(const Key('stepper_increment_button')));
      await tester.pump();
    }
  }

  Future<void> tapDecrement([int times = 1]) async {
    for (int i = 0; i < times; i++) {
      await tester.tap(find.byKey(const Key('stepper_decrement_button')));
      await tester.pump();
    }
  }

  Future<void> commitDialog() async {
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  Future<void> cancelDialog() async {
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  }

  Future<void> pickTime(int hour, int minute) async {
    // Tap the time button/icon
    await tester.tap(_find(timeTextFinder));
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

  Finder get segmentedButton {
    return find.byWidgetPredicate((widget) => false);
  }

  Finder get timeTextFinder => find.byIcon(Icons.access_time);
}
