import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/missed_occurrence_policy.dart';
import 'package:nothing_ever_happens/widgets/monthly_nth_weekday_scheduling_widget.dart';
import 'package:nothing_ever_happens/widgets/day_of_week_selector.dart';
import 'package:nothing_ever_happens/widgets/interval_stepper.dart';
import 'package:nothing_ever_happens/widgets/date_stepper.dart';
import 'package:nothing_ever_happens/widgets/relative_time_widget.dart';
import 'package:nothing_ever_happens/widgets/missed_occurrence_policy_selector.dart';
import '../test_helper.dart';

void main() {
  group('MonthlyNthWeekdaySchedulingWidget', () {
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
              child: MonthlyNthWeekdaySchedulingWidget(
                startDate: startDate,
                onStartDateChanged: (_) {},
                interval: 1,
                onIntervalChanged: (_) {},
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
        find.byKey(const Key('monthly_occurrence_selector')),
        findsOneWidget,
      );
      expect(find.byType(DayOfWeekSelector), findsOneWidget);

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
      int? newOccurrence;
      int? newDayOfWeek;

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: MonthlyNthWeekdaySchedulingWidget(
                startDate: startDate,
                onStartDateChanged: (d) => newDate = d,
                interval: 2,
                onIntervalChanged: (i) => newInterval = i,
                occurrence: 2,
                onOccurrenceChanged: (o) => newOccurrence = o,
                dayOfWeek: 3,
                onDayOfWeekChanged: (dow) => newDayOfWeek = dow,
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

      // 3. Change occurrence via SegmentedButton
      await tester.tap(find.text('3rd'));
      await tester.pumpAndSettle();
      expect(newOccurrence, 3);

      // 4. Change dayOfWeek via DayOfWeekSelector chip
      await tester.tap(
        find.byKey(const Key('weekly_weekday_chip_4')),
      ); // Thursday
      await tester.pumpAndSettle();
      expect(newDayOfWeek, 4);
    });

    testGoldens('MonthlyNthWeekdaySchedulingWidget renders correctly', (
      tester,
    ) async {
      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 0.4)
        ..addScenario(
          'MonthlyNthWeekday Default',
          Material(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: MonthlyNthWeekdaySchedulingWidget(
                startDate: startDate,
                onStartDateChanged: (_) {},
                interval: 2,
                onIntervalChanged: (_) {},
                occurrence: 2,
                onOccurrenceChanged: (_) {},
                dayOfWeek: 3,
                onDayOfWeekChanged: (_) {},
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
        surfaceSize: const Size(500, 1300),
      );
      await screenMatchesGolden(
        tester,
        'monthly_nth_weekday_scheduling_widget_golden',
      );
    });
  });
}
