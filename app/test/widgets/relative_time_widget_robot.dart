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

  Future<void> selectCustom() async {
    await _openOffsetDialog();
    await tester.tap(find.text('Custom').last);
    await tester.pumpAndSettle();
  }

  Future<void> enterCustomDays(String days) async {
    await tester.enterText(customTextField, days);
    await tester.pump();
    await tester.tap(find.text('OK'));
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

  Future<void> closeCustomMode() async {
    await selectDayOf();
  }

  Finder get segmentedButton {
    // No segmented button in new design, return an empty finder or one that finds nothing
    return find.byWidgetPredicate((widget) => false);
  }

  Finder get customTextField => _find(find.byType(TextField));

  Finder get timeTextFinder => find.byIcon(Icons.access_time);
}
