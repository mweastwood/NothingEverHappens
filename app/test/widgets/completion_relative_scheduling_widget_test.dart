import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/widgets/completion_relative_scheduling_widget.dart';
import '../test_helper.dart';

void main() {
  group('CompletionRelativeSchedulingWidget', () {
    testWidgets(
      'renders interval stepper, help text, timing section, and notification section',
      (tester) async {
        int? updatedInterval;
        RelativeTime? updatedNotification;

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: SingleChildScrollView(
                child: CompletionRelativeSchedulingWidget(
                  interval: 2,
                  onIntervalChanged: (val) => updatedInterval = val,
                  unitSingular: 'week',
                  unitPlural: 'weeks',
                  helpText: 'Repeats 2 weeks after completion.',
                  keyPrefix: 'weekly_cr',
                  startRelativeTime: const RelativeTime(
                    dayOffset: 0,
                    hour: 9,
                    minute: 0,
                  ),
                  onStartRelativeTimeChanged: (_) {},
                  dueRelativeTime: const RelativeTime(
                    dayOffset: 0,
                    hour: 17,
                    minute: 0,
                  ),
                  onDueRelativeTimeChanged: (_) {},
                  notificationRelativeTime: null,
                  onNotificationRelativeTimeChanged: (val) =>
                      updatedNotification = val,
                ),
              ),
            ),
          ),
        );

        expect(find.text('2 weeks'), findsOneWidget);
        expect(find.text('Repeats 2 weeks after completion.'), findsOneWidget);
        expect(
          find.byKey(const Key('weekly_cr_interval_stepper')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('interval_increment_button')));
        await tester.pumpAndSettle();
        expect(updatedInterval, 3);

        final checkboxFinder = find.byKey(
          const Key('weekly_cr_notification_checkbox'),
        );
        expect(checkboxFinder, findsOneWidget);
        await tester.tap(checkboxFinder);
        await tester.pumpAndSettle();
        expect(updatedNotification, isNotNull);
      },
    );
  });
}
