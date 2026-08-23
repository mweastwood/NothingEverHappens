import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/widgets/notification_config_section.dart';
import 'package:nothing_ever_happens/widgets/relative_time_widget.dart';
import '../test_helper.dart';

void main() {
  group('NotificationConfigSection Widget Tests', () {
    const fixtureRelativeTime = RelativeTime(
      dayOffset: 0,
      time: TimeOfDay(hour: 9, minute: 0),
    );

    group('Visibility & Conditional Rendering', () {
      testWidgets('renders SizedBox.shrink when showNotification is false', (
        tester,
      ) async {
        final controller = ValueNotifier<RelativeTime>(fixtureRelativeTime);

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: NotificationConfigSection(
                showNotification: false,
                notificationEnabled: false,
                readOnly: false,
                notificationController: controller,
                onNotificationRelativeTimeChanged: (_) {},
                keyPrefix: 'test_prefix',
              ),
            ),
          ),
        );

        expect(find.byType(CheckboxListTile), findsNothing);
        expect(find.byType(RelativeTimeWidget), findsNothing);
        expect(find.byType(Divider), findsNothing);
        expect(find.text('Enable notification reminder'), findsNothing);
        expect(find.text('Notification window'), findsNothing);
      });

      testWidgets(
        'renders checkbox but hides relative time picker when notificationEnabled is false',
        (tester) async {
          final controller = ValueNotifier<RelativeTime>(fixtureRelativeTime);

          await tester.pumpWidget(
            buildTestableWidget(
              child: Scaffold(
                body: NotificationConfigSection(
                  showNotification: true,
                  notificationEnabled: false,
                  readOnly: false,
                  notificationController: controller,
                  onNotificationRelativeTimeChanged: (_) {},
                  keyPrefix: 'test_prefix',
                ),
              ),
            ),
          );

          expect(find.byType(CheckboxListTile), findsOneWidget);
          expect(find.text('Enable notification reminder'), findsOneWidget);
          expect(find.text('Notification window'), findsNothing);
          expect(find.byType(RelativeTimeWidget), findsNothing);

          final checkboxTile = tester.widget<CheckboxListTile>(
            find.byType(CheckboxListTile),
          );
          expect(checkboxTile.value, isFalse);
        },
      );

      testWidgets(
        'renders checkbox and relative time picker when notificationEnabled is true',
        (tester) async {
          final controller = ValueNotifier<RelativeTime>(fixtureRelativeTime);

          await tester.pumpWidget(
            buildTestableWidget(
              child: Scaffold(
                body: NotificationConfigSection(
                  showNotification: true,
                  notificationEnabled: true,
                  readOnly: false,
                  notificationController: controller,
                  onNotificationRelativeTimeChanged: (_) {},
                  keyPrefix: 'test_prefix',
                ),
              ),
            ),
          );

          expect(find.byType(CheckboxListTile), findsOneWidget);
          expect(find.text('Enable notification reminder'), findsOneWidget);
          expect(find.text('Notification window'), findsOneWidget);
          expect(find.byType(RelativeTimeWidget), findsOneWidget);

          final checkboxTile = tester.widget<CheckboxListTile>(
            find.byType(CheckboxListTile),
          );
          expect(checkboxTile.value, isTrue);

          final relativeTimeWidget = tester.widget<RelativeTimeWidget>(
            find.byType(RelativeTimeWidget),
          );
          expect(
            relativeTimeWidget.constraint,
            RelativeTimeConstraint.unconstrained,
          );
          expect(relativeTimeWidget.controller, equals(controller));
        },
      );
    });

    group('Interactions & Callbacks', () {
      testWidgets(
        'invokes onNotificationRelativeTimeChanged with controller value when toggled to true',
        (tester) async {
          final controller = ValueNotifier<RelativeTime>(fixtureRelativeTime);
          RelativeTime? capturedTime;
          int callCount = 0;

          await tester.pumpWidget(
            buildTestableWidget(
              child: Scaffold(
                body: NotificationConfigSection(
                  showNotification: true,
                  notificationEnabled: false,
                  readOnly: false,
                  notificationController: controller,
                  onNotificationRelativeTimeChanged: (value) {
                    capturedTime = value;
                    callCount++;
                  },
                  keyPrefix: 'task_form',
                ),
              ),
            ),
          );

          await tester.tap(find.byType(CheckboxListTile));
          await tester.pumpAndSettle();

          expect(callCount, 1);
          expect(capturedTime, equals(fixtureRelativeTime));
        },
      );

      testWidgets(
        'invokes onNotificationRelativeTimeChanged with null when toggled to false',
        (tester) async {
          final controller = ValueNotifier<RelativeTime>(fixtureRelativeTime);
          RelativeTime? capturedTime = fixtureRelativeTime;
          int callCount = 0;

          await tester.pumpWidget(
            buildTestableWidget(
              child: Scaffold(
                body: NotificationConfigSection(
                  showNotification: true,
                  notificationEnabled: true,
                  readOnly: false,
                  notificationController: controller,
                  onNotificationRelativeTimeChanged: (value) {
                    capturedTime = value;
                    callCount++;
                  },
                  keyPrefix: 'task_form',
                ),
              ),
            ),
          );

          await tester.tap(find.byType(CheckboxListTile));
          await tester.pumpAndSettle();

          expect(callCount, 1);
          expect(capturedTime, isNull);
        },
      );

      testWidgets('disables interaction when readOnly is true', (tester) async {
        final controller = ValueNotifier<RelativeTime>(fixtureRelativeTime);
        int callCount = 0;

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: NotificationConfigSection(
                showNotification: true,
                notificationEnabled: false,
                readOnly: true,
                notificationController: controller,
                onNotificationRelativeTimeChanged: (_) {
                  callCount++;
                },
                keyPrefix: 'readonly_test',
              ),
            ),
          ),
        );

        final checkboxTile = tester.widget<CheckboxListTile>(
          find.byType(CheckboxListTile),
        );
        expect(checkboxTile.onChanged, isNull);

        await tester.tap(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();

        expect(callCount, 0);
      });
    });

    group('Key Prefix Support', () {
      testWidgets('assigns correct keys to components based on keyPrefix', (
        tester,
      ) async {
        final controller = ValueNotifier<RelativeTime>(fixtureRelativeTime);
        const prefix = 'schedule_modal';

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: NotificationConfigSection(
                showNotification: true,
                notificationEnabled: true,
                readOnly: false,
                notificationController: controller,
                onNotificationRelativeTimeChanged: (_) {},
                keyPrefix: prefix,
              ),
            ),
          ),
        );

        expect(
          find.byKey(const Key('${prefix}_notification_checkbox')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('${prefix}_notification_relative_time_picker')),
          findsOneWidget,
        );
      });

      testWidgets('ensures key isolation across different key prefixes', (
        tester,
      ) async {
        final controller1 = ValueNotifier<RelativeTime>(fixtureRelativeTime);
        final controller2 = ValueNotifier<RelativeTime>(fixtureRelativeTime);

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: Column(
                children: [
                  NotificationConfigSection(
                    showNotification: true,
                    notificationEnabled: true,
                    readOnly: false,
                    notificationController: controller1,
                    onNotificationRelativeTimeChanged: (_) {},
                    keyPrefix: 'prefix_one',
                  ),
                  NotificationConfigSection(
                    showNotification: true,
                    notificationEnabled: true,
                    readOnly: false,
                    notificationController: controller2,
                    onNotificationRelativeTimeChanged: (_) {},
                    keyPrefix: 'prefix_two',
                  ),
                ],
              ),
            ),
          ),
        );

        expect(
          find.byKey(const Key('prefix_one_notification_checkbox')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('prefix_one_notification_relative_time_picker')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('prefix_two_notification_checkbox')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('prefix_two_notification_relative_time_picker')),
          findsOneWidget,
        );
      });
    });
  });
}
