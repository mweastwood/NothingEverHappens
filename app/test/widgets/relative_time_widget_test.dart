import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/widgets/relative_time_widget.dart';
import '../test_helper.dart';
import 'relative_time_widget_robot.dart';

void main() {
  group('RelativeTimeWidget (dayOfOrAfter)', () {
    testWidgets('renders correctly with initial "Day of" state', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = ValueNotifier(
        const RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 14, minute: 30)),
      );
      final robot = RelativeTimeWidgetRobot(tester);

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
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

      expect(find.text('Day of'), findsOneWidget);
      // Open the dialog to verify options exist
      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();
      expect(find.text('1 day after'), findsOneWidget);
      expect(find.text('2 days later'), findsOneWidget);
      expect(find.text('7 days later'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('renders correctly with "1 day after" state', (tester) async {
      final controller = ValueNotifier(
        const RelativeTime(dayOffset: 1, time: TimeOfDay(hour: 9, minute: 0)),
      );

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: RelativeTimeWidget(
              controller: controller,
              constraint: RelativeTimeConstraint.dayOfOrAfter,
            ),
          ),
        ),
      );

      expect(find.text('1 day after'), findsOneWidget);
    });

    testWidgets('updates controller when "1 day after" chip is selected', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = ValueNotifier(
        const RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 10, minute: 0)),
      );
      final robot = RelativeTimeWidgetRobot(tester);

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: RelativeTimeWidget(
              controller: controller,
              constraint: RelativeTimeConstraint.dayOfOrAfter,
            ),
          ),
        ),
      );

      await robot.selectDayAfter();

      expect(controller.value.dayOffset, 1);
      expect(controller.value.time.hour, 10);
    });

    testWidgets('updates controller when stepper is used to change days', (
      tester,
    ) async {
      final controller = ValueNotifier(
        const RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 10, minute: 0)),
      );
      final robot = RelativeTimeWidgetRobot(tester);

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: RelativeTimeWidget(
              controller: controller,
              constraint: RelativeTimeConstraint.dayOfOrAfter,
            ),
          ),
        ),
      );

      await robot.openDialog();
      await robot.tapIncrement(3);
      await robot.commitDialog();

      expect(controller.value.dayOffset, 3);
      expect(controller.value.time.hour, 10);
    });

    testWidgets('does not update controller when dialog is cancelled', (
      tester,
    ) async {
      final controller = ValueNotifier(
        const RelativeTime(dayOffset: 1, time: TimeOfDay(hour: 10, minute: 0)),
      );
      final robot = RelativeTimeWidgetRobot(tester);

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: RelativeTimeWidget(
              controller: controller,
              constraint: RelativeTimeConstraint.dayOfOrAfter,
            ),
          ),
        ),
      );

      expect(find.text('1 day after'), findsOneWidget);

      await robot.openDialog();
      await robot.tapIncrement(2);
      await robot.cancelDialog();

      expect(controller.value.dayOffset, 1);
      expect(find.text('1 day after'), findsOneWidget);
    });

    testWidgets('updates controller when time is picked', (tester) async {
      final controller = ValueNotifier(
        const RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 10, minute: 0)),
      );
      final robot = RelativeTimeWidgetRobot(tester);

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: RelativeTimeWidget(
              controller: controller,
              constraint: RelativeTimeConstraint.dayOfOrAfter,
            ),
          ),
        ),
      );

      // Initial time 10:00
      expect(find.textContaining('10:00'), findsOneWidget);

      // Pick 08:30
      await robot.pickTime(8, 30);

      expect(controller.value.time.hour, 8);
      expect(controller.value.time.minute, 30);
      expect(find.textContaining('8:30'), findsOneWidget);
    });

    testWidgets('updates UI when controller changes externally', (
      tester,
    ) async {
      final controller = ValueNotifier(
        const RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 10, minute: 0)),
      );

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: RelativeTimeWidget(
              controller: controller,
              constraint: RelativeTimeConstraint.dayOfOrAfter,
            ),
          ),
        ),
      );

      expect(find.textContaining('10:00'), findsOneWidget);

      controller.value = const RelativeTime(
        dayOffset: 1,
        time: TimeOfDay(hour: 12, minute: 15),
      );
      await tester.pump();

      expect(find.textContaining('12:15'), findsOneWidget);
    });
  });

  group('RelativeTimeWidget (dayOfOrBefore)', () {
    testWidgets('renders correctly with "1 day before" state', (tester) async {
      final controller = ValueNotifier(
        const RelativeTime(dayOffset: -1, time: TimeOfDay(hour: 9, minute: 0)),
      );

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: RelativeTimeWidget(
              controller: controller,
              constraint: RelativeTimeConstraint.dayOfOrBefore,
            ),
          ),
        ),
      );

      expect(find.text('1 day before'), findsOneWidget);
    });

    testWidgets('updates controller when "1 day before" chip is selected', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = ValueNotifier(
        const RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 10, minute: 0)),
      );
      final robot = RelativeTimeWidgetRobot(tester);

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: RelativeTimeWidget(
              controller: controller,
              constraint: RelativeTimeConstraint.dayOfOrBefore,
            ),
          ),
        ),
      );

      await robot.selectDayBefore();

      expect(
        controller.value,
        const RelativeTime(dayOffset: -1, time: TimeOfDay(hour: 10, minute: 0)),
      );
    });

    testWidgets(
      'handles custom stepper input for backward constraint correctly',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final controller = ValueNotifier(
          const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 10, minute: 0),
          ),
        );
        final robot = RelativeTimeWidgetRobot(tester);

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: RelativeTimeWidget(
                controller: controller,
                constraint: RelativeTimeConstraint.dayOfOrBefore,
              ),
            ),
          ),
        );

        await robot.openDialog();
        await robot.tapDecrement(5);
        await robot.commitDialog();

        expect(
          controller.value,
          const RelativeTime(
            dayOffset: -5,
            time: TimeOfDay(hour: 10, minute: 0),
          ),
        );
      },
    );
  });
  testGoldens('RelativeTimeWidget renders correctly', (tester) async {
    final builder = GoldenBuilder.grid(columns: 2, widthToHeightRatio: 3)
      ..addScenario(
        'DayOfOrAfter - Day of',
        RelativeTimeWidget(
          controller: ValueNotifier(
            const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 10, minute: 0),
            ),
          ),
          constraint: RelativeTimeConstraint.dayOfOrAfter,
        ),
      )
      ..addScenario(
        'DayOfOrBefore - Day of',
        RelativeTimeWidget(
          controller: ValueNotifier(
            const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 10, minute: 0),
            ),
          ),
          constraint: RelativeTimeConstraint.dayOfOrBefore,
        ),
      )
      ..addScenario(
        'DayOfOrAfter - 1 day after',
        RelativeTimeWidget(
          controller: ValueNotifier(
            const RelativeTime(
              dayOffset: 1,
              time: TimeOfDay(hour: 10, minute: 0),
            ),
          ),
          constraint: RelativeTimeConstraint.dayOfOrAfter,
        ),
      )
      ..addScenario(
        'DayOfOrBefore - 1 day before',
        RelativeTimeWidget(
          controller: ValueNotifier(
            const RelativeTime(
              dayOffset: -1,
              time: TimeOfDay(hour: 10, minute: 0),
            ),
          ),
          constraint: RelativeTimeConstraint.dayOfOrBefore,
        ),
      )
      ..addScenario(
        'Unconstrained - 5 days later',
        RelativeTimeWidget(
          controller: ValueNotifier(
            const RelativeTime(
              dayOffset: 5,
              time: TimeOfDay(hour: 10, minute: 0),
            ),
          ),
          constraint: RelativeTimeConstraint.unconstrained,
        ),
      )
      ..addScenario(
        'Unconstrained - 5 days before',
        RelativeTimeWidget(
          controller: ValueNotifier(
            const RelativeTime(
              dayOffset: -5,
              time: TimeOfDay(hour: 10, minute: 0),
            ),
          ),
          constraint: RelativeTimeConstraint.unconstrained,
        ),
      );

    await tester.pumpWidgetBuilder(
      builder.build(),
      wrapper: l10nMaterialAppWrapper(),
      surfaceSize: const Size(800, 600),
    );
    await screenMatchesGolden(tester, 'relative_time_widget');
  });

  testGoldens('RelativeTimeWidget offset dialog renders correctly', (
    tester,
  ) async {
    final controller = ValueNotifier(
      const RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 10, minute: 0)),
    );

    await tester.pumpWidgetBuilder(
      Scaffold(
        body: Center(
          child: RelativeTimeWidget(
            controller: controller,
            constraint: RelativeTimeConstraint.unconstrained,
          ),
        ),
      ),
      wrapper: l10nMaterialAppWrapper(),
      surfaceSize: const Size(400, 600),
    );

    // Open the dialog
    await tester.tap(find.byIcon(Icons.calendar_today));
    await tester.pumpAndSettle();

    await screenMatchesGolden(tester, 'relative_time_widget_dialog_standard');
  });

  testGoldens('RelativeTimeWidget custom offset dialog renders correctly', (
    tester,
  ) async {
    final controller = ValueNotifier(
      const RelativeTime(dayOffset: 5, time: TimeOfDay(hour: 10, minute: 0)),
    );

    await tester.pumpWidgetBuilder(
      Scaffold(
        body: Center(
          child: RelativeTimeWidget(
            controller: controller,
            constraint: RelativeTimeConstraint.unconstrained,
          ),
        ),
      ),
      wrapper: l10nMaterialAppWrapper(),
      surfaceSize: const Size(400, 600),
    );

    // Open the dialog
    await tester.tap(find.byIcon(Icons.calendar_today));
    await tester.pumpAndSettle();

    await screenMatchesGolden(tester, 'relative_time_widget_dialog_custom');
  });
}
