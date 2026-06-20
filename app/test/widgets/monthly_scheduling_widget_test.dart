import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/scheduling_policy.dart';
import 'package:nothing_ever_happens/logic/missed_occurrence_policy.dart';
import 'package:nothing_ever_happens/widgets/monthly_scheduling_widget.dart';
import 'package:nothing_ever_happens/widgets/relative_timing_widget.dart';
import 'package:nothing_ever_happens/widgets/missed_occurrence_policy_selector.dart';
import '../test_helper.dart';
import 'monthly_scheduling_widget_robot.dart';

void main() {
  group('MonthlySchedulingWidget', () {
    testWidgets('renders all fields when fully configured', (tester) async {
      final startDate = CivilDay(year: 2026, month: 10, day: 26);
      const startRelative = RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 9, minute: 0),
      );
      const dueRelative = RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 17, minute: 0),
      );
      const missed = MissedOccurrencePolicy.keepAround();

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: MonthlySchedulingWidget(
                startDate: startDate,
                onStartDateChanged: (_) {},
                interval: 1,
                onIntervalChanged: (_) {},
                schedulingPolicy: const FixedCalendarPolicy(),
                onSchedulingPolicyChanged: (_) {},
                ruleType: 'dayOfMonth',
                onRuleTypeChanged: (_) {},
                dayOfMonth: 15,
                onDayOfMonthChanged: (_) {},
                occurrence: 1,
                onOccurrenceChanged: (_) {},
                dayOfWeek: 1,
                onDayOfWeekChanged: (_) {},
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

      expect(find.text('Start Recurrence Date'), findsOneWidget);
      expect(find.text('2026-10-26'), findsOneWidget);
      expect(find.text('Interval'), findsOneWidget);
      expect(
        find.text('Every 1 month(s) (since last scheduled)'),
        findsOneWidget,
      );
      expect(find.text('Recurrence Rule'), findsOneWidget);
      expect(find.text('Day of Month (1-28, or -1 to -28)'), findsOneWidget);
      expect(find.byType(RelativeTimingWidget), findsOneWidget);
      expect(find.byType(MissedOccurrencePolicySelector), findsOneWidget);
    });

    testWidgets('calls callbacks when widgets are updated', (tester) async {
      CivilDay startDate = CivilDay(year: 2026, month: 10, day: 26);
      CivilDay? newDate;
      int interval = 1;
      int? newInterval;
      String ruleType = 'dayOfMonth';
      String? newRuleType;
      int? dayOfMonth = 15;
      int? newDayOfMonth;

      final robot = MonthlySchedulingWidgetRobot(tester);

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: MonthlySchedulingWidget(
                startDate: startDate,
                onStartDateChanged: (d) => newDate = d,
                interval: interval,
                onIntervalChanged: (i) => newInterval = i,
                schedulingPolicy: const FixedCalendarPolicy(),
                onSchedulingPolicyChanged: (_) {},
                ruleType: ruleType,
                onRuleTypeChanged: (t) => newRuleType = t,
                dayOfMonth: dayOfMonth,
                onDayOfMonthChanged: (dom) => newDayOfMonth = dom,
                occurrence: 1,
                onOccurrenceChanged: (_) {},
                dayOfWeek: 1,
                onDayOfWeekChanged: (_) {},
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

      // 2. Expand and type interval
      await robot.enterInterval('3');
      expect(newInterval, 3);

      // 3. Change Day of Month
      await robot.enterDayOfMonth('20');
      expect(newDayOfMonth, 20);

      // 4. Change rule type
      await robot.selectRuleType('Nth Day of Week');
      expect(newRuleType, 'nthDayOfWeek');
    });

    testGoldens('MonthlySchedulingWidget renders correctly', (tester) async {
      final startDate = CivilDay(year: 2026, month: 10, day: 26);
      const startRelative = RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 9, minute: 0),
      );
      const dueRelative = RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 17, minute: 0),
      );
      const missed = MissedOccurrencePolicy.keepAround();

      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 0.5)
        ..addScenario(
          'Day of Month (Collapsed)',
          Material(
            child: MonthlySchedulingWidget(
              startDate: startDate,
              onStartDateChanged: (_) {},
              interval: 2,
              onIntervalChanged: (_) {},
              schedulingPolicy: const FixedCalendarPolicy(),
              onSchedulingPolicyChanged: (_) {},
              ruleType: 'dayOfMonth',
              onRuleTypeChanged: (_) {},
              dayOfMonth: 15,
              onDayOfMonthChanged: (_) {},
              occurrence: 1,
              onOccurrenceChanged: (_) {},
              dayOfWeek: 1,
              onDayOfWeekChanged: (_) {},
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
        )
        ..addScenario(
          'Nth Day of Week (Expanded)',
          Material(
            child: MonthlySchedulingWidget(
              startDate: startDate,
              onStartDateChanged: (_) {},
              interval: 2,
              onIntervalChanged: (_) {},
              schedulingPolicy: const FixedCalendarPolicy(),
              onSchedulingPolicyChanged: (_) {},
              ruleType: 'nthDayOfWeek',
              onRuleTypeChanged: (_) {},
              dayOfMonth: null,
              onDayOfMonthChanged: (_) {},
              occurrence: 2, // Second
              onOccurrenceChanged: (_) {},
              dayOfWeek: 3, // Wednesday
              onDayOfWeekChanged: (_) {},
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
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(800, 3200),
      );

      // Expand the second scenario ('Nth Day of Week (Expanded)')
      final expansionTiles = find.byKey(
        const Key('monthly_interval_expansion_tile'),
      );
      expect(expansionTiles, findsNWidgets(2));
      await tester.tap(expansionTiles.last);
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, 'monthly_scheduling_widget');
    });
  });
}
