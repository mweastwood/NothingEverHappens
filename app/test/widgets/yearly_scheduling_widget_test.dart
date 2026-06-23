import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/scheduling_policy.dart';
import 'package:nothing_ever_happens/logic/missed_occurrence_policy.dart';
import 'package:nothing_ever_happens/widgets/yearly_scheduling_widget.dart';
import 'package:nothing_ever_happens/widgets/relative_time_widget.dart';
import 'package:nothing_ever_happens/widgets/missed_occurrence_policy_selector.dart';
import '../test_helper.dart';
import 'yearly_scheduling_widget_robot.dart';

void main() {
  group('YearlySchedulingWidget', () {
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
              child: YearlySchedulingWidget(
                startDate: startDate,
                onStartDateChanged: (_) {},
                interval: 1,
                onIntervalChanged: (_) {},
                schedulingPolicy: const FixedCalendarPolicy(),
                onSchedulingPolicyChanged: (_) {},
                month: 10,
                onMonthChanged: (_) {},
                day: 26,
                onDayChanged: (_) {},
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
        find.text('Repeats every year starting 2026-10-26.'),
        findsOneWidget,
      );
      expect(find.text('Repeats on'), findsOneWidget);
      expect(find.text('Month'), findsOneWidget);
      expect(find.text('October'), findsOneWidget);
      expect(find.byKey(const Key('yearly_day_field')), findsOneWidget);
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
          interval: const Duration(days: 365),
          targetTime: const TimeOfDay(hour: 9, minute: 0),
        );

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: SingleChildScrollView(
                child: YearlySchedulingWidget(
                  startDate: startDate,
                  onStartDateChanged: (_) {},
                  interval: 1,
                  onIntervalChanged: (_) {},
                  schedulingPolicy: policy,
                  onSchedulingPolicyChanged: (_) {},
                  month: 10,
                  onMonthChanged: (_) {},
                  day: 26,
                  onDayChanged: (_) {},
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
          find.text('1 year after the task was last completed.'),
          findsOneWidget,
        );
        expect(find.text('Repeats on'), findsNothing);
        expect(find.text('Month'), findsNothing);
        expect(find.text('October'), findsNothing);
        expect(find.byKey(const Key('yearly_day_field')), findsNothing);
        expect(find.byType(RelativeTimeWidget), findsNWidgets(2));
        expect(find.byType(MissedOccurrencePolicySelector), findsNothing);
      },
    );

    testWidgets('calls callbacks when widgets are updated', (tester) async {
      CivilDay startDate = CivilDay(year: 2026, month: 10, day: 26);
      CivilDay? newDate;
      int interval = 1;
      int? newInterval;
      int month = 10;
      int? newMonth;
      int day = 26;
      int? newDay;

      final robot = YearlySchedulingWidgetRobot(tester);

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: YearlySchedulingWidget(
                startDate: startDate,
                onStartDateChanged: (d) => newDate = d,
                interval: interval,
                onIntervalChanged: (i) => newInterval = i,
                schedulingPolicy: const FixedCalendarPolicy(),
                onSchedulingPolicyChanged: (_) {},
                month: month,
                onMonthChanged: (m) => newMonth = m,
                day: day,
                onDayChanged: (d) => newDay = d,
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

      // 3. Select Month
      await robot.selectMonth('December');
      expect(newMonth, 12);

      // 4. Enter Day
      await robot.enterDay('15');
      expect(newDay, 15);
    });

    testGoldens('YearlySchedulingWidget renders correctly', (tester) async {
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
          'Yearly Fixed',
          Material(
            child: YearlySchedulingWidget(
              startDate: startDate,
              onStartDateChanged: (_) {},
              interval: 2,
              onIntervalChanged: (_) {},
              schedulingPolicy: const FixedCalendarPolicy(),
              onSchedulingPolicyChanged: (_) {},
              month: 10,
              onMonthChanged: (_) {},
              day: 26,
              onDayChanged: (_) {},
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
          'Yearly Completion Relative',
          Material(
            child: YearlySchedulingWidget(
              startDate: startDate,
              onStartDateChanged: (_) {},
              interval: 2,
              onIntervalChanged: (_) {},
              schedulingPolicy: CompletionRelativePolicy(
                interval: const Duration(days: 730),
                targetTime: const TimeOfDay(hour: 9, minute: 0),
              ),
              onSchedulingPolicyChanged: (_) {},
              month: 10,
              onMonthChanged: (_) {},
              day: 26,
              onDayChanged: (_) {},
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
        surfaceSize: const Size(800, 2000),
      );

      await screenMatchesGolden(tester, 'yearly_scheduling_widget');
    });
  });
}
