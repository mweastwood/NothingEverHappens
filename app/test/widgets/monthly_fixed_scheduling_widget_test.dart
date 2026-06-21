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
        find.byKey(const Key('monthly_direction_selector')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('monthly_day_of_month_stepper')),
        findsOneWidget,
      );

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
              child: StatefulBuilder(
                builder: (context, setState) {
                  return MonthlyFixedSchedulingWidget(
                    startDate: startDate,
                    onStartDateChanged: (d) => newDate = d,
                    interval: newInterval ?? 2,
                    onIntervalChanged: (i) => setState(() => newInterval = i),
                    dayOfMonth: newDayOfMonth ?? 15,
                    onDayOfMonthChanged: (dom) =>
                        setState(() => newDayOfMonth = dom),
                    startRelativeTime: startRelative,
                    onStartRelativeTimeChanged: (_) {},
                    dueRelativeTime: dueRelative,
                    onDueRelativeTimeChanged: (_) {},
                    notificationRelativeTime: null,
                    onNotificationRelativeTimeChanged: (_) {},
                  );
                },
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

      // 3. Change Day of Month via Stepper increment button
      await tester.tap(find.byKey(const Key('day_increment_button')));
      await tester.pumpAndSettle();
      expect(newDayOfMonth, 16);

      // 4. Change direction to From end of month
      await tester.tap(find.text('From end of month'));
      await tester.pumpAndSettle();
      expect(newDayOfMonth, -16);
    });

    testGoldens('MonthlyFixedSchedulingWidget renders correctly', (
      tester,
    ) async {
      final builder = GoldenBuilder.grid(columns: 2, widthToHeightRatio: 0.5)
        ..addScenario(
          'MonthlyFixed From Start',
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
        )
        ..addScenario(
          'MonthlyFixed From End',
          Material(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: MonthlyFixedSchedulingWidget(
                startDate: startDate,
                onStartDateChanged: (_) {},
                interval: 2,
                onIntervalChanged: (_) {},
                dayOfMonth: -10,
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
        surfaceSize: const Size(1000, 950),
      );
      await screenMatchesGolden(
        tester,
        'monthly_fixed_scheduling_widget_golden',
      );
    });

    group('Day Suffix and Help Text Formatting', () {
      final suffixCases = {
        1: 'st',
        2: 'nd',
        3: 'rd',
        4: 'th',
        11: 'th',
        12: 'th',
        13: 'th',
        21: 'st',
        22: 'nd',
        23: 'rd',
        28: 'th',
        -1: 'st',
        -2: 'nd',
        -3: 'rd',
        -4: 'th',
        -11: 'th',
        -12: 'th',
        -13: 'th',
        -21: 'st',
        -22: 'nd',
        -23: 'rd',
        -28: 'th',
      };

      suffixCases.forEach((day, expectedSuffix) {
        testWidgets('displays correct suffix "$expectedSuffix" for day $day', (
          tester,
        ) async {
          final controller = TextEditingController(text: day.toString());
          await tester.pumpWidget(
            buildTestableWidget(
              child: Scaffold(
                body: MonthlyFixedSchedulingWidget(
                  startDate: startDate,
                  onStartDateChanged: (_) {},
                  interval: 1,
                  onIntervalChanged: (_) {},
                  dayOfMonth: day,
                  onDayOfMonthChanged: (_) {},
                  startRelativeTime: startRelative,
                  onStartRelativeTimeChanged: (_) {},
                  dueRelativeTime: dueRelative,
                  onDueRelativeTimeChanged: (_) {},
                  notificationRelativeTime: null,
                  onNotificationRelativeTimeChanged: (_) {},
                  missedOccurrencePolicy: missed,
                  onMissedOccurrencePolicyChanged: (_) {},
                  showNotification: false,
                  showMissedPolicy: false,
                  dayOfMonthController: controller,
                ),
              ),
            ),
          );

          // Find the suffix text widget
          expect(find.text(expectedSuffix), findsAtLeast(1));

          // Also check the help text format
          final absVal = day.abs();
          final expectedFormattedText = '$absVal$expectedSuffix';
          if (day > 0) {
            expect(
              find.textContaining(
                'Repeats on the $expectedFormattedText day of the month.',
              ),
              findsOneWidget,
            );
          } else {
            expect(
              find.textContaining(
                'Repeats on the $expectedFormattedText day from the end of the month.',
              ),
              findsOneWidget,
            );
          }
        });
      });
    });
  });
}
