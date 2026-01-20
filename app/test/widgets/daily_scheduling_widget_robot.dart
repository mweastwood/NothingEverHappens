import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'relative_time_widget_robot.dart';

class DailySchedulingWidgetRobot {
  final WidgetTester tester;

  DailySchedulingWidgetRobot(this.tester);

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
      find.widgetWithText(TextFormField, 'Days Interval'),
      interval,
    );
    await tester.pump();
  }
}
