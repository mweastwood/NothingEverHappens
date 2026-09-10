import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/widgets/one_off_scheduling_widget.dart';
import 'package:nothing_ever_happens/widgets/absolute_time_widget.dart';
import '../test_helper.dart';
import 'one_off_scheduling_widget_robot.dart';
import 'absolute_time_widget_robot.dart';

void main() {
  group('OneOffSchedulingWidget', () {
    testWidgets('renders basic fields', (tester) async {
      final due = ValueNotifier(DateTime(2026, 10, 26, 12, 0));

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(body: OneOffSchedulingWidget(dueDateTime: due)),
        ),
      );

      expect(find.text('Start'), findsNothing);
      expect(find.text('Due'), findsOneWidget);
      expect(find.byType(AbsoluteTimeWidget), findsOneWidget);
    });

    testWidgets('hides notification section when showNotification is false', (
      tester,
    ) async {
      final due = ValueNotifier(DateTime(2026, 10, 26, 12, 0));
      final notificationTime = ValueNotifier<TimeOfDay?>(
        const TimeOfDay(hour: 9, minute: 0),
      );

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: OneOffSchedulingWidget(
              dueDateTime: due,
              notificationTimeController: notificationTime,
              showNotification: false,
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('one_off_notification_button')),
        findsNothing,
      );
    });

    testWidgets('updates controllers when time is changed', (tester) async {
      final due = ValueNotifier(DateTime(2026, 10, 26, 12, 0));
      final oneOffRobot = OneOffSchedulingWidgetRobot(tester);
      final absoluteRobot = AbsoluteTimeWidgetRobot(tester);

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(body: OneOffSchedulingWidget(dueDateTime: due)),
        ),
      );

      // Change Due time
      await oneOffRobot.openDueTimePicker();
      await absoluteRobot.pickTime(10, 0, isAM: false); // 10 PM = 22:00

      expect(due.value.hour, 22);
    });

    testWidgets('renders notification section with initial time', (
      tester,
    ) async {
      final due = ValueNotifier(DateTime(2026, 10, 26, 12, 0));
      final notificationTime = ValueNotifier<TimeOfDay?>(
        const TimeOfDay(hour: 14, minute: 30),
      );

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: OneOffSchedulingWidget(
              dueDateTime: due,
              notificationTimeController: notificationTime,
              showNotification: true,
            ),
          ),
        ),
      );

      expect(find.text('2:30 PM'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_active), findsOneWidget);
      expect(
        find.byKey(const Key('one_off_notification_clear')),
        findsOneWidget,
      );
    });

    testWidgets('renders notification section with null initial time', (
      tester,
    ) async {
      final due = ValueNotifier(DateTime(2026, 10, 26, 12, 0));
      final notificationTime = ValueNotifier<TimeOfDay?>(null);

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: OneOffSchedulingWidget(
              dueDateTime: due,
              notificationTimeController: notificationTime,
              showNotification: true,
            ),
          ),
        ),
      );

      expect(find.text('None'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none), findsOneWidget);
      expect(find.byKey(const Key('one_off_notification_clear')), findsNothing);
    });

    testWidgets('picking notification time updates controller and UI', (
      tester,
    ) async {
      final due = ValueNotifier(DateTime(2026, 10, 26, 12, 0));
      final notificationTime = ValueNotifier<TimeOfDay?>(null);
      final oneOffRobot = OneOffSchedulingWidgetRobot(tester);
      final absoluteRobot = AbsoluteTimeWidgetRobot(tester);

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: OneOffSchedulingWidget(
              dueDateTime: due,
              notificationTimeController: notificationTime,
              showNotification: true,
            ),
          ),
        ),
      );

      expect(find.text('None'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none), findsOneWidget);
      expect(oneOffRobot.clearNotificationButton, findsNothing);

      await oneOffRobot.openNotificationTimePicker();
      await absoluteRobot.pickTime(9, 0, isAM: true);

      expect(notificationTime.value, const TimeOfDay(hour: 9, minute: 0));
      expect(find.text('9:00 AM'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_active), findsOneWidget);
      expect(oneOffRobot.clearNotificationButton, findsOneWidget);
    });

    testWidgets('clearing notification time resets controller and UI', (
      tester,
    ) async {
      final due = ValueNotifier(DateTime(2026, 10, 26, 12, 0));
      final notificationTime = ValueNotifier<TimeOfDay?>(
        const TimeOfDay(hour: 9, minute: 0),
      );
      final oneOffRobot = OneOffSchedulingWidgetRobot(tester);

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: OneOffSchedulingWidget(
              dueDateTime: due,
              notificationTimeController: notificationTime,
              showNotification: true,
            ),
          ),
        ),
      );

      expect(find.text('9:00 AM'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_active), findsOneWidget);
      expect(oneOffRobot.clearNotificationButton, findsOneWidget);

      await oneOffRobot.tapClearNotification();

      expect(notificationTime.value, isNull);
      expect(find.text('None'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none), findsOneWidget);
      expect(oneOffRobot.clearNotificationButton, findsNothing);
    });

    testWidgets(
      'canceling notification time picker leaves controller unchanged',
      (tester) async {
        final due = ValueNotifier(DateTime(2026, 10, 26, 12, 0));
        final notificationTime = ValueNotifier<TimeOfDay?>(
          const TimeOfDay(hour: 14, minute: 30),
        );
        final oneOffRobot = OneOffSchedulingWidgetRobot(tester);

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: OneOffSchedulingWidget(
                dueDateTime: due,
                notificationTimeController: notificationTime,
                showNotification: true,
              ),
            ),
          ),
        );

        await oneOffRobot.openNotificationTimePicker();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(notificationTime.value, const TimeOfDay(hour: 14, minute: 30));
        expect(find.text('2:30 PM'), findsOneWidget);
      },
    );

    testGoldens('OneOffSchedulingWidget renders correctly', (tester) async {
      final due = ValueNotifier(DateTime(2026, 10, 26, 12, 0));

      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 2)
        ..addScenario('Default', OneOffSchedulingWidget(dueDateTime: due));

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
      );
      await screenMatchesGolden(tester, 'one_off_scheduling_widget');
    });
  });
}
