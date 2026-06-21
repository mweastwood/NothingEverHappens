import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/widgets/weekly_scheduling_widget.dart';
import 'package:nothing_ever_happens/widgets/interval_stepper.dart';
import 'package:nothing_ever_happens/widgets/relative_time_widget.dart';
import '../test_helper.dart';

void main() {
  group('WeeklyCompletionRelativeSchedulingWidget', () {
    const startRelative = RelativeTime(
      dayOffset: 0,
      time: TimeOfDay(hour: 9, minute: 0),
    );
    const dueRelative = RelativeTime(
      dayOffset: 0,
      time: TimeOfDay(hour: 17, minute: 0),
    );
    final selectedWeekdays = {1, 3, 5}; // Mon, Wed, Fri

    testWidgets('renders all fields when fully configured', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: WeeklyCompletionRelativeSchedulingWidget(
                interval: 2,
                onIntervalChanged: (_) {},
                selectedWeekdays: selectedWeekdays,
                onWeekdaysChanged: (_) {},
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
      expect(find.text('2 weeks'), findsOneWidget);

      // Check helper text
      expect(
        find.text('2 weeks after the task was last completed.'),
        findsOneWidget,
      );

      // Check weekday selector
      expect(find.text('Repeats on'), findsOneWidget);
      expect(find.byType(FilterChip), findsNWidgets(7));

      // Check relative times
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Due'), findsOneWidget);
      expect(find.byType(RelativeTimeWidget), findsNWidgets(2));
      expect(
        find.text('When does the task appear in your list of tasks?'),
        findsOneWidget,
      );
      expect(
        find.text(
          'When does this task need to be completed before it should be considered overdue?',
        ),
        findsOneWidget,
      );

      // Check notification checkbox
      expect(find.text('Enable notification reminder'), findsOneWidget);
    });

    testWidgets('calls callbacks on edits', (tester) async {
      int? newInterval;
      Set<int>? newWeekdays;

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: WeeklyCompletionRelativeSchedulingWidget(
                interval: 2,
                onIntervalChanged: (i) => newInterval = i,
                selectedWeekdays: selectedWeekdays,
                onWeekdaysChanged: (days) => newWeekdays = days,
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

      // 1. Change Interval via Increment button
      await tester.tap(find.byKey(const Key('interval_increment_button')));
      await tester.pumpAndSettle();
      expect(newInterval, 3);

      // 2. Toggle weekday chip (index 1 = Tuesday)
      await tester.tap(find.byKey(const Key('weekly_weekday_chip_2')));
      await tester.pumpAndSettle();
      expect(newWeekdays, {1, 2, 3, 5});
    });

    testGoldens('WeeklyCompletionRelativeSchedulingWidget renders correctly', (
      tester,
    ) async {
      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 0.8)
        ..addScenario(
          'WeeklyCompletion Default',
          Material(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: WeeklyCompletionRelativeSchedulingWidget(
                interval: 2,
                onIntervalChanged: (_) {},
                selectedWeekdays: selectedWeekdays,
                onWeekdaysChanged: (_) {},
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
        surfaceSize: const Size(500, 750),
      );
      await screenMatchesGolden(
        tester,
        'weekly_completion_relative_scheduling_widget_golden',
      );
    });
  });
}
