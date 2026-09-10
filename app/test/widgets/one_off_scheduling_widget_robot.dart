import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/widgets/absolute_time_widget.dart';

class OneOffSchedulingWidgetRobot {
  final WidgetTester tester;

  OneOffSchedulingWidgetRobot(this.tester);

  Finder get dueTimeWidget => find.descendant(
    of: find.byType(AbsoluteTimeWidget),
    matching: find.byIcon(Icons.access_time),
  );

  Finder get notificationButton =>
      find.byKey(const Key('one_off_notification_button'));

  Finder get clearNotificationButton =>
      find.byKey(const Key('one_off_notification_clear'));

  Future<void> openDueTimePicker() async {
    await tester.tap(dueTimeWidget);
    await tester.pumpAndSettle();
  }

  Future<void> openNotificationTimePicker() async {
    await tester.tap(notificationButton);
    await tester.pumpAndSettle();
  }

  Future<void> tapClearNotification() async {
    await tester.tap(clearNotificationButton);
    await tester.pumpAndSettle();
  }
}
