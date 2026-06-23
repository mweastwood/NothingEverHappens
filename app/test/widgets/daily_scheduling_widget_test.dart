import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/scheduling_policy.dart';
import 'package:nothing_ever_happens/logic/missed_occurrence_policy.dart';
import 'package:nothing_ever_happens/widgets/daily_scheduling_widget.dart';
import 'package:nothing_ever_happens/widgets/relative_time_widget.dart';
import 'package:nothing_ever_happens/widgets/missed_occurrence_policy_selector.dart';
import '../test_helper.dart';
import 'daily_scheduling_widget_robot.dart';

void main() {
  group('DailySchedulingWidget', () {
    testWidgets('renders all fields when fully configured', (tester) async {
      final startDate = CivilDay(year: 2026, month: 10, day: 26);
      int interval = 1;
      SchedulingPolicy policy = const FixedCalendarPolicy();
      const startRelative = RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 9, minute: 0),
      );
      const dueRelative = RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 17, minute: 0),
      );
      const missed = MissedOccurrencePolicy.stack();

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: DailySchedulingWidget(
                startDate: startDate,
                onStartDateChanged: (_) {},
                interval: interval,
                onIntervalChanged: (_) {},
                schedulingPolicy: policy,
                onSchedulingPolicyChanged: (_) {},
                startRelativeTime: startRelative,
                onStartRelativeTimeChanged: (_) {},
                dueRelativeTime: dueRelative,
                onDueRelativeTimeChanged: (_) {},
                notificationRelativeTime: null,
                onNotificationRelativeTimeChanged: (_) {},
                missedOccurrencePolicy: missed,
                onMissedOccurrencePolicyChanged: (_) {},
                showNotification: true,
                showMissedPolicy: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Start Date'), findsOneWidget);
      expect(find.text('2026-10-26'), findsOneWidget);
      expect(find.text('Interval'), findsOneWidget);
      expect(
        find.text('Repeats every day starting 2026-10-26.'),
        findsOneWidget,
      );
      expect(find.byType(RelativeTimeWidget), findsAtLeast(2));
      expect(find.byType(MissedOccurrencePolicySelector), findsOneWidget);
    });

    testWidgets('calls callbacks when widgets are updated', (tester) async {
      CivilDay startDate = CivilDay(year: 2026, month: 10, day: 26);
      CivilDay? newDate;
      int interval = 1;
      int? newInterval;
      SchedulingPolicy policy = const FixedCalendarPolicy();

      final robot = DailySchedulingWidgetRobot(tester);

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: DailySchedulingWidget(
                startDate: startDate,
                onStartDateChanged: (d) => newDate = d,
                interval: interval,
                onIntervalChanged: (i) => newInterval = i,
                schedulingPolicy: policy,
                onSchedulingPolicyChanged: (_) {},
                startRelativeTime: const RelativeTime(
                  dayOffset: 0,
                  time: TimeOfDay(hour: 9, minute: 0),
                ),
                onStartRelativeTimeChanged: (_) {},
                dueRelativeTime: const RelativeTime(
                  dayOffset: 0,
                  time: TimeOfDay(hour: 17, minute: 0),
                ),
                onDueRelativeTimeChanged: (_) {},
                notificationRelativeTime: null,
                onNotificationRelativeTimeChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      // 1. Pick start date
      await robot.pickStartDate('27');
      expect(newDate, CivilDay(year: 2026, month: 10, day: 27));

      // 2. Type interval
      await robot.enterInterval('3');
      expect(newInterval, 3);
    });

    testGoldens('DailySchedulingWidget renders correctly', (tester) async {
      final startDate = CivilDay(year: 2026, month: 10, day: 26);
      const startRelative = RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 9, minute: 0),
      );
      const dueRelative = RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 17, minute: 0),
      );
      const missed = MissedOccurrencePolicy.stack();

      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 1.1)
        ..addScenario(
          'Default Collapsed',
          Material(
            child: DailySchedulingWidget(
              startDate: startDate,
              onStartDateChanged: (_) {},
              interval: 2,
              onIntervalChanged: (_) {},
              schedulingPolicy: const FixedCalendarPolicy(),
              onSchedulingPolicyChanged: (_) {},
              startRelativeTime: startRelative,
              onStartRelativeTimeChanged: (_) {},
              dueRelativeTime: dueRelative,
              onDueRelativeTimeChanged: (_) {},
              notificationRelativeTime: null,
              onNotificationRelativeTimeChanged: (_) {},
              missedOccurrencePolicy: missed,
              onMissedOccurrencePolicyChanged: (_) {},
            ),
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(800, 800),
      );
      await screenMatchesGolden(tester, 'daily_scheduling_widget');
    });
  });
}
