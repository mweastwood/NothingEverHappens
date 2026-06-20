import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/missed_occurrence_policy.dart';
import 'package:nothing_ever_happens/widgets/yearly_scheduling_widget.dart';
import 'package:nothing_ever_happens/widgets/relative_timing_widget.dart';
import 'package:nothing_ever_happens/widgets/missed_occurrence_policy_selector.dart';
import '../test_helper.dart';
import 'yearly_scheduling_widget_robot.dart';

void main() {
  group('YearlySchedulingWidget', () {
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
              child: YearlySchedulingWidget(
                startDate: startDate,
                onStartDateChanged: (_) {},
                interval: 1,
                onIntervalChanged: (_) {},
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

      expect(find.text('Start Recurrence Date'), findsOneWidget);
      expect(find.text('2026-10-26'), findsOneWidget);
      expect(find.text('Interval'), findsOneWidget);
      expect(find.text('Every year'), findsOneWidget);
      expect(find.text('Month'), findsOneWidget);
      expect(find.text('October'), findsOneWidget);
      expect(find.text('Day'), findsOneWidget);
      expect(find.byType(RelativeTimingWidget), findsOneWidget);
      expect(find.byType(MissedOccurrencePolicySelector), findsOneWidget);
    });

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

      // 2. Expand and type interval
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
      const missed = MissedOccurrencePolicy.keepAround();

      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 0.5)
        ..addScenario(
          'Yearly Collapsed',
          Material(
            child: YearlySchedulingWidget(
              startDate: startDate,
              onStartDateChanged: (_) {},
              interval: 2,
              onIntervalChanged: (_) {},
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
          'Yearly Expanded',
          Material(
            child: YearlySchedulingWidget(
              startDate: startDate,
              onStartDateChanged: (_) {},
              interval: 2,
              onIntervalChanged: (_) {},
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
        surfaceSize: const Size(800, 3200),
      );

      // Expand the second scenario ('Yearly Expanded')
      final expansionTiles = find.byKey(
        const Key('yearly_interval_expansion_tile'),
      );
      expect(expansionTiles, findsNWidgets(2));
      await tester.tap(expansionTiles.last);
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, 'yearly_scheduling_widget');
    });
  });
}
