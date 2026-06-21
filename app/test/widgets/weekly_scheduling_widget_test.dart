import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/scheduling_policy.dart';
import 'package:nothing_ever_happens/logic/missed_occurrence_policy.dart';
import 'package:nothing_ever_happens/widgets/weekly_scheduling_widget.dart';
import 'package:nothing_ever_happens/widgets/day_of_week_selector.dart';
import 'package:nothing_ever_happens/widgets/relative_time_widget.dart';
import 'package:nothing_ever_happens/widgets/missed_occurrence_policy_selector.dart';
import '../test_helper.dart';
import 'weekly_scheduling_widget_robot.dart';

void main() {
  group('WeeklySchedulingWidget', () {
    testWidgets('renders all fields when fully configured (Fixed)', (
      tester,
    ) async {
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
      const missed = MissedOccurrencePolicy.keepAround();
      final selectedWeekdays = {1, 3, 5}; // Mon, Wed, Fri

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: WeeklySchedulingWidget(
                startDate: startDate,
                onStartDateChanged: (_) {},
                interval: interval,
                onIntervalChanged: (_) {},
                schedulingPolicy: policy,
                onSchedulingPolicyChanged: (_) {},
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

      expect(find.text('Start Date'), findsOneWidget);
      expect(find.text('2026-10-26'), findsOneWidget);
      expect(find.text('Interval'), findsOneWidget);
      expect(
        find.text('Repeats every week starting 2026-10-26.'),
        findsOneWidget,
      );
      expect(find.text('Repeats on'), findsOneWidget);
      expect(find.byType(DayOfWeekSelector), findsOneWidget);
      expect(find.byType(RelativeTimeWidget), findsNWidgets(2));
      expect(find.byType(MissedOccurrencePolicySelector), findsOneWidget);

      Material getMaterialForDay(int dayIndex) {
        return tester.widget<Material>(
          find
              .ancestor(
                of: find.byKey(Key('weekly_weekday_chip_$dayIndex')),
                matching: find.byType(Material),
              )
              .first,
        );
      }

      expect(
        getMaterialForDay(1).color,
        isNot(getMaterialForDay(2).color),
      ); // Mon (selected) vs Tue (unselected)
    });

    testWidgets(
      'renders all fields when fully configured (Completion Relative)',
      (tester) async {
        final startDate = CivilDay(year: 2026, month: 10, day: 26);
        int interval = 2;
        SchedulingPolicy policy = CompletionRelativePolicy(
          interval: const Duration(days: 14),
          targetTime: const TimeOfDay(hour: 9, minute: 0),
        );
        const startRelative = RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        );
        const dueRelative = RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        );
        final selectedWeekdays = {1, 3, 5}; // Mon, Wed, Fri

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: SingleChildScrollView(
                child: WeeklySchedulingWidget(
                  startDate: startDate,
                  onStartDateChanged: (_) {},
                  interval: interval,
                  onIntervalChanged: (_) {},
                  schedulingPolicy: policy,
                  onSchedulingPolicyChanged: (_) {},
                  selectedWeekdays: selectedWeekdays,
                  onWeekdaysChanged: (_) {},
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
          find.text('2 weeks after the task was last completed.'),
          findsOneWidget,
        );
        expect(find.text('Repeats on'), findsNothing);
        expect(find.byType(DayOfWeekSelector), findsNothing);
        expect(find.byType(RelativeTimeWidget), findsNWidgets(2));
        expect(find.byType(MissedOccurrencePolicySelector), findsNothing);
      },
    );

    testWidgets('calls callbacks when widgets are updated', (tester) async {
      CivilDay startDate = CivilDay(year: 2026, month: 10, day: 26);
      CivilDay? newDate;
      int interval = 1;
      int? newInterval;
      SchedulingPolicy policy = const FixedCalendarPolicy();
      Set<int> selectedWeekdays = {1}; // Mon
      Set<int>? newWeekdays;

      final robot = WeeklySchedulingWidgetRobot(tester);

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: WeeklySchedulingWidget(
                startDate: startDate,
                onStartDateChanged: (d) => newDate = d,
                interval: interval,
                onIntervalChanged: (i) => newInterval = i,
                schedulingPolicy: policy,
                onSchedulingPolicyChanged: (_) {},
                selectedWeekdays: selectedWeekdays,
                onWeekdaysChanged: (days) => newWeekdays = days,
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

      // 3. Toggle weekday chip (index 1 = Tuesday)
      await robot.toggleDayByIndex(1);
      expect(newWeekdays, {1, 2});

      // 4. Test presets
      await robot.tapPresetWeekends();
      expect(newWeekdays, {6, 7});

      await robot.tapPresetWeekdays();
      expect(newWeekdays, {1, 2, 3, 4, 5});

      await robot.tapPresetAll();
      expect(newWeekdays, {1, 2, 3, 4, 5, 6, 7});

      await robot.tapPresetClear();
      expect(newWeekdays, isEmpty);
    });

    testGoldens('WeeklySchedulingWidget renders correctly', (tester) async {
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
      final selectedWeekdays = {1, 3, 5};

      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 0.6)
        ..addScenario(
          'Fixed Calendar',
          Material(
            child: WeeklySchedulingWidget(
              startDate: startDate,
              onStartDateChanged: (_) {},
              interval: 2,
              onIntervalChanged: (_) {},
              schedulingPolicy: const FixedCalendarPolicy(),
              onSchedulingPolicyChanged: (_) {},
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
        )
        ..addScenario(
          'Completion Relative',
          Material(
            child: WeeklySchedulingWidget(
              startDate: startDate,
              onStartDateChanged: (_) {},
              interval: 2,
              onIntervalChanged: (_) {},
              schedulingPolicy: CompletionRelativePolicy(
                interval: const Duration(days: 14),
                targetTime: const TimeOfDay(hour: 9, minute: 0),
              ),
              onSchedulingPolicyChanged: (_) {},
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
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(800, 1600),
      );

      await screenMatchesGolden(tester, 'weekly_scheduling_widget');
    });
  });
}
