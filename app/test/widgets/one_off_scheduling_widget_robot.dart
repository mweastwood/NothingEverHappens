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

  Future<void> openDueTimePicker() async {
    await tester.tap(dueTimeWidget);
    await tester.pumpAndSettle();
  }
}
