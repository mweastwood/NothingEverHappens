import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/missed_occurrence_policy.dart';
import 'package:nothing_ever_happens/widgets/weekly_scheduling_widget.dart';
import 'package:nothing_ever_happens/widgets/day_of_week_selector.dart';
import 'package:nothing_ever_happens/widgets/interval_stepper.dart';
import 'package:nothing_ever_happens/widgets/date_stepper.dart';
import 'package:nothing_ever_happens/widgets/relative_time_widget.dart';
import 'package:nothing_ever_happens/widgets/missed_occurrence_policy_selector.dart';
import '../test_helper.dart';

void main() {
  group('WeeklyFixedSchedulingWidget', () {
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
    final selectedWeekdays = {1, 3, 5}; // Mon, Wed, Fri

    testWidgets('renders all fields when fully configured', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: WeeklyFixedSchedulingWidget(
                startDate: startDate,
                onStartDateChanged: (_) {},
                interval: 1,
                onIntervalChanged: (_) {},
                selectedWeekdays: selectedWeekdays,
                onWeekdaysChanged: (_) {},
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

      // Check weekly interval 1 helper text
      expect(
        find.text('Repeats every week starting 2026-10-26.'),
        findsOneWidget,
      );

      // Check weekday selector
      expect(find.text('Repeats on'), findsOneWidget);
      expect(find.byType(DayOfWeekSelector), findsOneWidget);

      // Check relative times
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Due'), findsOneWidget);
      expect(find.byType(RelativeTimeWidget), findsNWidgets(2));
      expect(
        find.text('When does the task appear in your list of tasks?'),
        findsOneWidget,
      );

      // Check missed policy
      expect(find.byType(MissedOccurrencePolicySelector), findsOneWidget);
    });

    testWidgets('displays correct helper text for multi-week interval', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: WeeklyFixedSchedulingWidget(
                startDate: startDate,
                onStartDateChanged: (_) {},
                interval: 3,
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
        ),
      );

      expect(
        find.text('Repeats every 3 weeks starting 2026-10-26.'),
        findsOneWidget,
      );
    });

    testWidgets('calls callbacks on edits', (tester) async {
      CivilDay? newDate;
      int? newInterval;
      Set<int>? newWeekdays;

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: WeeklyFixedSchedulingWidget(
                startDate: startDate,
                onStartDateChanged: (d) => newDate = d,
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
                missedOccurrencePolicy: missed,
                onMissedOccurrencePolicyChanged: (_) {},
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

      // 3. Toggle weekday chip (index 1 = Tuesday)
      await tester.tap(find.byKey(const Key('weekly_weekday_chip_2')));
      await tester.pumpAndSettle();
      expect(newWeekdays, {1, 2, 3, 5});

      // 4. Preset Weekdays
      await tester.tap(find.byKey(const Key('preset_weekdays_button')));
      await tester.pumpAndSettle();
      expect(newWeekdays, {1, 2, 3, 4, 5});
    });

    testGoldens('WeeklyFixedSchedulingWidget renders correctly', (
      tester,
    ) async {
      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 0.8)
        ..addScenario(
          'WeeklyFixed Default',
          Material(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: WeeklyFixedSchedulingWidget(
                startDate: startDate,
                onStartDateChanged: (_) {},
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
        'weekly_fixed_scheduling_widget_golden',
      );
    });
  });
}
