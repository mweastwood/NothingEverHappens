import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/widgets/daily_completion_relative_scheduling_widget.dart';
import 'package:nothing_ever_happens/widgets/interval_stepper.dart';
import 'package:nothing_ever_happens/widgets/relative_time_widget.dart';
import '../test_helper.dart';

void main() {
  group('DailyCompletionRelativeSchedulingWidget', () {
    const startRelative = RelativeTime(
      dayOffset: 0,
      time: TimeOfDay(hour: 9, minute: 0),
    );
    const dueRelative = RelativeTime(
      dayOffset: 0,
      time: TimeOfDay(hour: 17, minute: 0),
    );

    testWidgets('renders all fields when fully configured', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: DailyCompletionRelativeSchedulingWidget(
                interval: 2,
                onIntervalChanged: (_) {},
                startRelativeTime: startRelative,
                onStartRelativeTimeChanged: (_) {},
                dueRelativeTime: dueRelative,
                onDueRelativeTimeChanged: (_) {},
                notificationRelativeTime: null,
                onNotificationRelativeTimeChanged: (_) {},
                showNotification: true,
              ),
            ),
          ),
        ),
      );

      // Check IntervalStepper
      expect(find.byType(IntervalStepper), findsOneWidget);
      expect(find.text('Interval'), findsOneWidget);
      expect(find.text('2 days'), findsOneWidget);
      // Check helper text
      expect(find.textContaining('Every 2 day(s)'), findsOneWidget);

      // Check relative times
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Due'), findsOneWidget);
      expect(find.byType(RelativeTimeWidget), findsNWidgets(2));

      // Check notification checkbox
      expect(find.text('Enable notification reminder'), findsOneWidget);
    });

    testWidgets('calls callbacks on edits', (tester) async {
      int? newInterval;
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: DailyCompletionRelativeSchedulingWidget(
                interval: 2,
                onIntervalChanged: (i) => newInterval = i,
                startRelativeTime: startRelative,
                onStartRelativeTimeChanged: (_) {},
                dueRelativeTime: dueRelative,
                onDueRelativeTimeChanged: (_) {},
                notificationRelativeTime: null,
                onNotificationRelativeTimeChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      // Change Interval via Increment button
      await tester.tap(find.byKey(const Key('interval_increment_button')));
      await tester.pumpAndSettle();
      expect(newInterval, 3);
    });

    testGoldens('DailyCompletionRelativeSchedulingWidget renders correctly', (
      tester,
    ) async {
      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 1.1)
        ..addScenario(
          'DailyCompletion Default',
          Material(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: DailyCompletionRelativeSchedulingWidget(
                interval: 2,
                onIntervalChanged: (_) {},
                startRelativeTime: startRelative,
                onStartRelativeTimeChanged: (_) {},
                dueRelativeTime: dueRelative,
                onDueRelativeTimeChanged: (_) {},
                notificationRelativeTime: null,
                onNotificationRelativeTimeChanged: (_) {},
              ),
            ),
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(500, 600),
      );
      await screenMatchesGolden(
        tester,
        'daily_completion_relative_scheduling_widget_golden',
      );
    });
  });
}
