import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/missed_occurrence_policy.dart';
import 'package:nothing_ever_happens/widgets/daily_fixed_scheduling_widget.dart';
import 'package:nothing_ever_happens/widgets/interval_stepper.dart';
import 'package:nothing_ever_happens/widgets/date_stepper.dart';
import 'package:nothing_ever_happens/widgets/relative_time_widget.dart';
import 'package:nothing_ever_happens/widgets/missed_occurrence_policy_selector.dart';
import '../test_helper.dart';

void main() {
  group('DailyFixedSchedulingWidget', () {
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
              child: DailyFixedSchedulingWidget(
                startDate: startDate,
                onStartDateChanged: (_) {},
                interval: 1,
                onIntervalChanged: (_) {},
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

      // Check daily interval 1 helper text
      expect(
        find.text('Repeats every day starting 2026-10-26.'),
        findsOneWidget,
      );

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

    testWidgets('displays correct helper text for multi-day interval', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: DailyFixedSchedulingWidget(
                startDate: startDate,
                onStartDateChanged: (_) {},
                interval: 3,
                onIntervalChanged: (_) {},
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
        find.text('Repeats every 3 days starting 2026-10-26.'),
        findsOneWidget,
      );
    });

    testWidgets('calls callbacks on edits', (tester) async {
      CivilDay? newDate;
      int? newInterval;
      RelativeTime? newStart;
      RelativeTime? newDue;
      RelativeTime? newNotif;
      MissedOccurrencePolicy? newPolicy;

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: DailyFixedSchedulingWidget(
                startDate: startDate,
                onStartDateChanged: (d) => newDate = d,
                interval: 2,
                onIntervalChanged: (i) => newInterval = i,
                startRelativeTime: startRelative,
                onStartRelativeTimeChanged: (t) => newStart = t,
                dueRelativeTime: dueRelative,
                onDueRelativeTimeChanged: (t) => newDue = t,
                notificationRelativeTime: const RelativeTime(
                  dayOffset: 0,
                  time: TimeOfDay(hour: 8, minute: 0),
                ),
                onNotificationRelativeTimeChanged: (t) => newNotif = t,
                missedOccurrencePolicy: missed,
                onMissedOccurrencePolicyChanged: (p) => newPolicy = p,
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
    });

    testGoldens('DailyFixedSchedulingWidget renders correctly', (tester) async {
      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 1.1)
        ..addScenario(
          'DailyFixed Default',
          Material(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: DailyFixedSchedulingWidget(
                startDate: startDate,
                onStartDateChanged: (_) {},
                interval: 2,
                onIntervalChanged: (_) {},
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
        surfaceSize: const Size(500, 750),
      );
      await screenMatchesGolden(tester, 'daily_fixed_scheduling_widget_golden');
    });
  });
}
