import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/scheduling_policy.dart';
import 'package:nothing_ever_happens/logic/missed_occurrence_policy.dart';
import 'package:nothing_ever_happens/widgets/monthly_scheduling_widget.dart';
import 'package:nothing_ever_happens/widgets/relative_time_widget.dart';
import 'package:nothing_ever_happens/widgets/missed_occurrence_policy_selector.dart';
import '../test_helper.dart';
import 'monthly_scheduling_widget_robot.dart';

void main() {
  group('MonthlySchedulingWidget', () {
    testWidgets('renders all fields when fully configured (Fixed)', (
      tester,
    ) async {
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

      expect(find.text('Start Date'), findsOneWidget);
      expect(find.text('2026-10-26'), findsOneWidget);
      expect(find.text('Interval'), findsOneWidget);
      expect(
        find.text('Repeats every month starting 2026-10-26.'),
        findsOneWidget,
      );
      expect(find.text('Repeats on'), findsOneWidget);
      expect(
        find.byKey(const Key('monthly_day_of_month_stepper')),
        findsOneWidget,
      );
      expect(find.byType(RelativeTimeWidget), findsNWidgets(2));
      expect(find.byType(MissedOccurrencePolicySelector), findsOneWidget);
    });

    testWidgets(
      'renders all fields when fully configured (Completion Relative)',
      (tester) async {
        final startDate = CivilDay(year: 2026, month: 10, day: 26);
        const startRelative = RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        );
        const dueRelative = RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        );
        final policy = CompletionRelativePolicy(
          interval: const Duration(days: 60),
          targetTime: const TimeOfDay(hour: 9, minute: 0),
        );

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: SingleChildScrollView(
                child: MonthlySchedulingWidget(
                  startDate: startDate,
                  onStartDateChanged: (_) {},
                  interval: 2,
                  onIntervalChanged: (_) {},
                  schedulingPolicy: policy,
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
                  showNotification: true,
                  showMissedPolicy: true,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Start Date'), findsNothing);
        expect(find.text('Interval'), findsOneWidget);
        expect(
          find.text('2 months after the task was last completed.'),
          findsOneWidget,
        );
        expect(find.text('Repeats on'), findsNothing);
        expect(find.text('Day of Month (1-28, or -1 to -28)'), findsNothing);
        expect(find.byType(RelativeTimeWidget), findsNWidgets(2));
        expect(find.byType(MissedOccurrencePolicySelector), findsNothing);
      },
    );

    testWidgets('calls callbacks when widgets are updated', (tester) async {
      CivilDay startDate = CivilDay(year: 2026, month: 10, day: 26);
      CivilDay? newDate;
      int interval = 1;
      int? newInterval;
      String ruleType = 'dayOfMonth';
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
                onRuleTypeChanged: (_) {},
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

      // 2. Type interval
      await robot.enterInterval('3');
      expect(newInterval, 3);

      // 3. Change Day of Month
      await robot.enterDayOfMonth('20');
      expect(newDayOfMonth, 20);
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
      const missed = MissedOccurrencePolicy.stack();

      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 0.5)
        ..addScenario(
          'Fixed Calendar (Day of Month)',
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
          'Fixed Calendar (Nth Day of Week)',
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
        )
        ..addScenario(
          'Completion Relative',
          Material(
            child: MonthlySchedulingWidget(
              startDate: startDate,
              onStartDateChanged: (_) {},
              interval: 2,
              onIntervalChanged: (_) {},
              schedulingPolicy: CompletionRelativePolicy(
                interval: const Duration(days: 60),
                targetTime: const TimeOfDay(hour: 9, minute: 0),
              ),
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
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(800, 2400),
      );

      await screenMatchesGolden(tester, 'monthly_scheduling_widget');
    });
  });
}
