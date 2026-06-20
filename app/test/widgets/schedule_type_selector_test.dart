import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/scheduling_policy.dart';
import 'package:nothing_ever_happens/widgets/schedule_type_selector.dart';
import '../test_helper.dart';

void main() {
  group('ScheduleTypeSelector', () {
    testWidgets('renders segments and highlights selected type', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: ScheduleTypeSelector(
              selectedType: SchedulingType.fixedCalendar,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Fixed Calendar'), findsOneWidget);
      expect(find.text('Completion-Relative'), findsOneWidget);
    });

    testWidgets('calls onChanged when segment is tapped', (tester) async {
      SchedulingType? changedType;
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: ScheduleTypeSelector(
              selectedType: SchedulingType.fixedCalendar,
              onChanged: (type) {
                changedType = type;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Completion-Relative'));
      await tester.pump();

      expect(changedType, SchedulingType.completionRelative);
    });

    testWidgets('does not call onChanged when readOnly is true', (
      tester,
    ) async {
      SchedulingType? changedType;
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: ScheduleTypeSelector(
              selectedType: SchedulingType.fixedCalendar,
              onChanged: (type) {
                changedType = type;
              },
              readOnly: true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Completion-Relative'));
      await tester.pump();

      expect(changedType, isNull);
    });
  });
}
