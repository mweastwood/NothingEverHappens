import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/widgets/notification_list_widget.dart';
import '../test_helper.dart';

void main() {
  group('NotificationListWidget Widget Tests', () {
    testWidgets('renders empty state message when notifications are empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: NotificationListWidget(
              notifications: const [],
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Notification Reminders'), findsOneWidget);
      expect(find.text('No notifications set'), findsOneWidget);
      expect(find.byKey(const Key('add_notification_button')), findsOneWidget);
    });

    testWidgets(
      'calls onChanged with default notification when add button tapped',
      (tester) async {
        List<RelativeTime>? changedList;

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: NotificationListWidget(
                notifications: const [],
                onChanged: (val) {
                  changedList = val;
                },
              ),
            ),
          ),
        );

        final addButton = find.byKey(const Key('add_notification_button'));
        expect(addButton, findsOneWidget);
        await tester.tap(addButton);
        await tester.pump();

        expect(changedList, isNotNull);
        expect(changedList!.length, 1);
        // Default notification is Day of (dayOffset: 0) at 9:00 AM
        expect(changedList!.first.dayOffset, 0);
        expect(changedList!.first.time.hour, 9);
        expect(changedList!.first.time.minute, 0);
      },
    );

    testWidgets('renders lists of notifications in relative mode', (
      tester,
    ) async {
      final notifs = [
        const RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 8, minute: 0)),
        const RelativeTime(dayOffset: -1, time: TimeOfDay(hour: 18, minute: 0)),
      ];

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: NotificationListWidget(
              notifications: notifs,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      // Verify notification counts and list content
      expect(find.text('Notification Reminders'), findsOneWidget);
      expect(find.text('2 / 5'), findsOneWidget);
      expect(find.text('No notifications set'), findsNothing);

      // Verify that delete buttons are shown
      expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
    });

    testWidgets('calls onChanged with item removed when delete is tapped', (
      tester,
    ) async {
      final notifs = [
        const RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 8, minute: 0)),
        const RelativeTime(dayOffset: -1, time: TimeOfDay(hour: 18, minute: 0)),
      ];
      List<RelativeTime>? changedList;

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: NotificationListWidget(
              notifications: notifs,
              onChanged: (val) {
                changedList = val;
              },
            ),
          ),
        ),
      );

      // Tap the delete button of the first item
      final deleteButtons = find.byIcon(Icons.delete_outline);
      await tester.tap(deleteButtons.first);
      await tester.pump();

      expect(changedList, isNotNull);
      expect(changedList!.length, 1);
      // The remaining item should be the second one (dayOffset: -1)
      expect(changedList!.first.dayOffset, -1);
    });

    testWidgets('hides add button and limit counters in read-only mode', (
      tester,
    ) async {
      final notifs = [
        const RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 8, minute: 0)),
      ];

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: NotificationListWidget(
              notifications: notifs,
              onChanged: (_) {},
              readOnly: true,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('add_notification_button')), findsNothing);
      expect(find.text('1 / 5'), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('hides add button when limit of 5 is reached', (tester) async {
      final notifs = List.generate(
        5,
        (index) => RelativeTime(
          dayOffset: index,
          time: const TimeOfDay(hour: 9, minute: 0),
        ),
      );

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: NotificationListWidget(
              notifications: notifs,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('5 / 5'), findsOneWidget);
      expect(find.byKey(const Key('add_notification_button')), findsNothing);
    });

    testGoldens('NotificationListWidget renders correctly', (tester) async {
      const refDate = CivilDay(year: 2026, month: 6, day: 15);
      final notifs = [
        const RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 9, minute: 0)),
        const RelativeTime(
          dayOffset: -1,
          time: TimeOfDay(hour: 18, minute: 30),
        ),
      ];

      final builder = GoldenBuilder.column()
        ..addScenario(
          'Empty State',
          NotificationListWidget(notifications: const [], onChanged: (_) {}),
        )
        ..addScenario(
          'Relative Mode (2 items)',
          NotificationListWidget(notifications: notifs, onChanged: (_) {}),
        )
        ..addScenario(
          'Absolute Mode (2 items)',
          NotificationListWidget(
            notifications: notifs,
            referenceDate: refDate,
            onChanged: (_) {},
          ),
        )
        ..addScenario(
          'Max Limit Reached (5 items)',
          NotificationListWidget(
            notifications: List.generate(
              5,
              (index) => RelativeTime(
                dayOffset: index - 2,
                time: TimeOfDay(hour: 8 + index, minute: 0),
              ),
            ),
            onChanged: (_) {},
          ),
        )
        ..addScenario(
          'Read-Only Mode',
          NotificationListWidget(
            notifications: notifs,
            onChanged: (_) {},
            readOnly: true,
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(800, 1600),
      );

      await screenMatchesGolden(tester, 'notification_list_widget_golden');
    });
  });
}
