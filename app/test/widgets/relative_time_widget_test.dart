import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/widgets/relative_time_widget.dart';
import 'relative_time_widget_robot.dart';

void main() {
  group('RelativeTimeWidget (dayOfOrAfter)', () {
    testWidgets('renders correctly with initial "Day of" state', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = ValueNotifier(const Duration(hours: 14, minutes: 30));
      final robot = RelativeTimeWidgetRobot(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelativeTimeWidget(
              controller: controller,
              constraint: RelativeTimeConstraint.dayOfOrAfter,
            ),
          ),
        ),
      );

      expect(robot.timeTextFinder, findsOneWidget);
      // 14:30 is 2:30 PM
      expect(find.textContaining('2:30'), findsOneWidget);

      // We can't access private enum values, but we can verify the segments
      // labels However, checking the selected set is tricky without the enum.
      // Instead, we verify UI state by ensuring "Day of" is visually selected
      // if possible, or simply that the correct segments are present.
      expect(find.text('Day of'), findsOneWidget);
      expect(find.text('1 day after'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);

      // Verify text field is not visible
      expect(robot.customTextField, findsNothing);
    });

    testWidgets('renders correctly with "1 day after" state', (tester) async {
      final controller = ValueNotifier(const Duration(days: 1, hours: 9));
      final robot = RelativeTimeWidgetRobot(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelativeTimeWidget(
              controller: controller,
              constraint: RelativeTimeConstraint.dayOfOrAfter,
            ),
          ),
        ),
      );

      // Verify checking logic for segmented button selection involves internal
      // enum, but we can trust the controller update tests.  Here just verify
      // the text is present and it didn't default to something else.
      expect(find.text('1 day after'), findsOneWidget);
      expect(robot.customTextField, findsNothing);
    });

    testWidgets('updates controller when "1 day after" segment is selected', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = ValueNotifier(const Duration(hours: 10));
      final robot = RelativeTimeWidgetRobot(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelativeTimeWidget(
              controller: controller,
              constraint: RelativeTimeConstraint.dayOfOrAfter,
            ),
          ),
        ),
      );

      await robot.selectDayAfter();

      expect(controller.value.inDays, 1);
      expect(controller.value.inHours % 24, 10);
    });

    testWidgets(
      'updates controller when Custom mode is selected and days entered',
      (tester) async {
        final controller = ValueNotifier(const Duration(hours: 10));
        final robot = RelativeTimeWidgetRobot(tester);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RelativeTimeWidget(
                controller: controller,
                constraint: RelativeTimeConstraint.dayOfOrAfter,
              ),
            ),
          ),
        );

        await robot.selectCustom();

        // Default assertion for custom mode logic (starts at 2 days for forward)
        expect(controller.value.inDays, 2);
        expect(robot.customTextField, findsOneWidget);
        expect(find.text('days later'), findsOneWidget);

        await robot.enterCustomDays('5');

        expect(controller.value.inDays, 5);
        expect(controller.value.inHours % 24, 10);
      },
    );

    testWidgets(
      'resets to "Day of" when close button is tapped in custom mode',
      (tester) async {
        final controller = ValueNotifier(const Duration(days: 5, hours: 10));
        final robot = RelativeTimeWidgetRobot(tester);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RelativeTimeWidget(
                controller: controller,
                constraint: RelativeTimeConstraint.dayOfOrAfter,
              ),
            ),
          ),
        );

        // Initially in custom mode due to 5 days
        expect(robot.customTextField, findsOneWidget);

        await robot.closeCustomMode();

        expect(controller.value.inDays, 0);
        expect(robot.customTextField, findsNothing);
        expect(robot.segmentedButton, findsOneWidget);
      },
    );

    testWidgets('updates controller when time is picked', (tester) async {
      final controller = ValueNotifier(const Duration(hours: 10));
      final robot = RelativeTimeWidgetRobot(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelativeTimeWidget(
              controller: controller,
              constraint: RelativeTimeConstraint.dayOfOrAfter,
            ),
          ),
        ),
      );

      // Initial time 10:00
      expect(find.textContaining('10:00'), findsOneWidget);

      // Pick 08:30 (Safe for AM/PM tests as 8:30 or 08:30)
      await robot.pickTime(8, 30);

      expect(controller.value.inHours, 8);
      expect(controller.value.inMinutes % 60, 30);
      expect(find.textContaining('8:30'), findsOneWidget);
    });

    testWidgets('updates UI when controller changes externally', (
      tester,
    ) async {
      final controller = ValueNotifier(const Duration(hours: 10));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelativeTimeWidget(
              controller: controller,
              constraint: RelativeTimeConstraint.dayOfOrAfter,
            ),
          ),
        ),
      );

      expect(find.textContaining('10:00'), findsOneWidget);

      controller.value = const Duration(days: 1, hours: 12, minutes: 15);
      await tester.pump();

      expect(find.textContaining('12:15'), findsOneWidget);
    });
  });

  group('RelativeTimeWidget (dayOfOrBefore)', () {
    testWidgets('renders correctly with "1 day before" state', (tester) async {
      final controller = ValueNotifier(const Duration(days: -1, hours: 9));
      final robot = RelativeTimeWidgetRobot(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelativeTimeWidget(
              controller: controller,
              constraint: RelativeTimeConstraint.dayOfOrBefore,
            ),
          ),
        ),
      );

      expect(find.text('1 day before'), findsOneWidget);
      expect(robot.customTextField, findsNothing);
    });

    testWidgets('updates controller when "1 day before" segment is selected', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = ValueNotifier(const Duration(hours: 10));
      final robot = RelativeTimeWidgetRobot(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelativeTimeWidget(
              controller: controller,
              constraint: RelativeTimeConstraint.dayOfOrBefore,
            ),
          ),
        ),
      );

      await robot.selectDayBefore();

      expect(controller.value, const Duration(days: -1, hours: 10));
    });

    testWidgets('handles custom input for backward constraint correctly', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = ValueNotifier(const Duration(hours: 10));
      final robot = RelativeTimeWidgetRobot(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelativeTimeWidget(
              controller: controller,
              constraint: RelativeTimeConstraint.dayOfOrBefore,
            ),
          ),
        ),
      );

      await robot.selectCustom();

      // Default custom logic for backward is -2 days
      expect(controller.value, const Duration(days: -2, hours: 10));
      expect(find.text('days before'), findsOneWidget);
      // The text field displays absolute value
      expect(find.text('2'), findsOneWidget);

      await robot.enterCustomDays('5');

      // Should be -5 days
      expect(controller.value, const Duration(days: -5, hours: 10));
    });
  });
}
