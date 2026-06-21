import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/missed_occurrence_policy.dart';
import 'package:nothing_ever_happens/widgets/monthly_fixed_scheduling_widget.dart';
import 'package:nothing_ever_happens/widgets/interval_stepper.dart';
import 'package:nothing_ever_happens/widgets/date_stepper.dart';
import 'package:nothing_ever_happens/widgets/relative_time_widget.dart';
import 'package:nothing_ever_happens/widgets/missed_occurrence_policy_selector.dart';
import '../test_helper.dart';

void main() {
  group('MonthlyFixedSchedulingWidget', () {
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

    testWidgets('renders all fields when fully configured', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: MonthlyFixedSchedulingWidget(
                startDate: startDate,
                onStartDateChanged: (_) {},
                interval: 1,
                onIntervalChanged: (_) {},
                dayOfMonth: 15,
                onDayOfMonthChanged: (_) {},
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

      // Check Interval & Start Date steppers
      expect(find.byType(IntervalStepper), findsOneWidget);
      expect(find.byType(DateStepper), findsOneWidget);
      expect(find.text('Interval'), findsOneWidget);
      expect(find.text('Start Date'), findsOneWidget);

      // Check monthly interval 1 helper text
      expect(
        find.text('Repeats every month starting 2026-10-26.'),
        findsOneWidget,
      );

      // Check repeats on header
      expect(find.text('Repeats on'), findsOneWidget);
      expect(
        find.byKey(const Key('monthly_day_of_month_field')),
        findsOneWidget,
      ); // dayOfMonth input

      // Check relative times
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Due'), findsOneWidget);
      expect(find.byType(RelativeTimeWidget), findsNWidgets(2));

      // Check missed policy
      expect(find.byType(MissedOccurrencePolicySelector), findsOneWidget);
    });

    testWidgets('calls callbacks on edits', (tester) async {
      CivilDay? newDate;
      int? newInterval;
      int? newDayOfMonth;

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: MonthlyFixedSchedulingWidget(
                startDate: startDate,
                onStartDateChanged: (d) => newDate = d,
                interval: 2,
                onIntervalChanged: (i) => newInterval = i,
                dayOfMonth: 15,
                onDayOfMonthChanged: (dom) => newDayOfMonth = dom,
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

      // 1. Change Date via Increment button
      await tester.tap(find.byKey(const Key('date_increment_button')));
      await tester.pumpAndSettle();
      expect(newDate, CivilDay(year: 2026, month: 10, day: 27));

      // 2. Change Interval via Increment button
      await tester.tap(find.byKey(const Key('interval_increment_button')));
      await tester.pumpAndSettle();
      expect(newInterval, 3);

      // 3. Change Day of Month field
      await tester.enterText(
        find.byKey(const Key('monthly_day_of_month_field')),
        '20',
      );
      await tester.pumpAndSettle();
      expect(newDayOfMonth, 20);
    });

    testGoldens('MonthlyFixedSchedulingWidget renders correctly', (
      tester,
    ) async {
      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 0.8)
        ..addScenario(
          'MonthlyFixed Default',
          Material(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: MonthlyFixedSchedulingWidget(
                startDate: startDate,
                onStartDateChanged: (_) {},
                interval: 2,
                onIntervalChanged: (_) {},
                dayOfMonth: 15,
                onDayOfMonthChanged: (_) {},
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
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(500, 850),
      );
      await screenMatchesGolden(
        tester,
        'monthly_fixed_scheduling_widget_golden',
      );
    });
  });
}
