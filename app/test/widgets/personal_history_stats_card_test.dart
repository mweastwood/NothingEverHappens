import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/dashboard_stats.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/widgets/personal_history_stats_card.dart';
import '../test_helper.dart';

void main() {
  group('PersonalHistoryStatsCard', () {
    final startDay = CivilDay(year: 2026, month: 7, day: 1); // Wednesday
    final endDay = CivilDay(year: 2026, month: 7, day: 7); // Tuesday

    const dummyStart = RelativeTime(
      dayOffset: 0,
      time: TimeOfDay(hour: 9, minute: 0),
    );
    const dummyDue = RelativeTime(
      dayOffset: 0,
      time: TimeOfDay(hour: 17, minute: 0),
    );

    final stats = PersonalLastWeekStats(
      completedCount: 5,
      completedHours: 3.5,
      skippedCount: 1,
      missedCount: 2,
      completionRate: 5 / 8,
      startDay: startDay,
      endDay: endDay,
      dailyStats: [
        DailyStatsData(
          day: CivilDay(year: 2026, month: 7, day: 1),
          completedCount: 2,
          skippedCount: 0,
          missedCount: 0,
          completedHours: 1.5,
          completedTasks: [
            TaskInstance(
              id: 't-1',
              scheduleId: 's-1',
              ruleId: 'r-1',
              title: 'Clean the kitchen',
              description: 'Wash dishes and wipe counters',
              scheduledDate: CivilDay(year: 2026, month: 7, day: 1),
              startRelativeTime: dummyStart,
              dueRelativeTime: dummyDue,
              status: TaskStatus.completed,
            ),
            TaskInstance(
              id: 't-2',
              scheduleId: 's-2',
              ruleId: 'r-2',
              title: 'Water plants',
              description: '',
              scheduledDate: CivilDay(year: 2026, month: 7, day: 1),
              startRelativeTime: dummyStart,
              dueRelativeTime: dummyDue,
              status: TaskStatus.completed,
            ),
          ],
        ),
        DailyStatsData(
          day: CivilDay(year: 2026, month: 7, day: 2),
          completedCount: 0,
          skippedCount: 1,
          missedCount: 0,
          completedHours: 0.0,
          skippedTasks: [
            TaskInstance(
              id: 't-3',
              scheduleId: 's-3',
              ruleId: 'r-3',
              title: 'Vacuum living room',
              description: '',
              scheduledDate: CivilDay(year: 2026, month: 7, day: 2),
              startRelativeTime: dummyStart,
              dueRelativeTime: dummyDue,
              status: TaskStatus.skipped,
            ),
          ],
        ),
        DailyStatsData(
          day: CivilDay(year: 2026, month: 7, day: 3),
          completedCount: 1,
          skippedCount: 0,
          missedCount: 1,
          completedHours: 1.0,
          completedTasks: [
            TaskInstance(
              id: 't-4',
              scheduleId: 's-4',
              ruleId: 'r-4',
              title: 'Take out trash',
              description: '',
              scheduledDate: CivilDay(year: 2026, month: 7, day: 3),
              startRelativeTime: dummyStart,
              dueRelativeTime: dummyDue,
              status: TaskStatus.completed,
            ),
          ],
          missedTasks: [
            TaskInstance(
              id: 't-5',
              scheduleId: 's-5',
              ruleId: 'r-5',
              title: 'Mow the lawn',
              description: '',
              scheduledDate: CivilDay(year: 2026, month: 7, day: 3),
              startRelativeTime: dummyStart,
              dueRelativeTime: dummyDue,
              status: TaskStatus.pending,
            ),
          ],
        ),
        DailyStatsData(
          day: CivilDay(year: 2026, month: 7, day: 4),
          completedCount: 0,
          skippedCount: 0,
          missedCount: 0,
          completedHours: 0.0,
        ),
        DailyStatsData(
          day: CivilDay(year: 2026, month: 7, day: 5),
          completedCount: 1,
          skippedCount: 0,
          missedCount: 1,
          completedHours: 0.5,
        ),
        DailyStatsData(
          day: CivilDay(year: 2026, month: 7, day: 6),
          completedCount: 0,
          skippedCount: 0,
          missedCount: 0,
          completedHours: 0.0,
        ),
        DailyStatsData(
          day: CivilDay(year: 2026, month: 7, day: 7),
          completedCount: 1,
          skippedCount: 0,
          missedCount: 0,
          completedHours: 0.5,
        ),
      ],
    );

    testWidgets('renders header, date range, and KPI metric tiles', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: PersonalHistoryStatsCard(stats: stats),
            ),
          ),
        ),
      );

      expect(find.text('Your Past Week'), findsOneWidget);
      expect(find.text('Jul 1 – 7'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('personal_stats_completed_tile')),
          matching: find.text('5'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('personal_stats_time_tile')),
          matching: find.text('3h 30m'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('personal_stats_rate_tile')),
          matching: find.text('63%'),
        ),
        findsOneWidget,
      );
      expect(find.text('1 skipped · 2 missed/overdue'), findsOneWidget);
    });

    testWidgets('renders 3-letter weekday labels and top count labels', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: PersonalHistoryStatsCard(stats: stats),
            ),
          ),
        ),
      );

      // Verify standardized 3-letter day labels
      expect(find.text('Wed'), findsOneWidget);
      expect(find.text('Thu'), findsOneWidget);
      expect(find.text('Fri'), findsOneWidget);
      expect(find.text('Sat'), findsOneWidget);
      expect(find.text('Sun'), findsOneWidget);
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Tue'), findsOneWidget);

      // Verify day numbers
      expect(find.text('1'), findsNWidgets(2)); // Day 1 & top count '1'
      expect(find.text('2'), findsNWidgets(2)); // Day 2 & top count '2'
      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('5'), findsNWidgets(2)); // Day 5 & KPI tile 5
      expect(find.text('6'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);

      // Verify top ratio labels
      expect(find.text('1/2'), findsNWidgets(2));
      expect(find.text('0/1'), findsOneWidget);
      expect(find.text('-'), findsNWidgets(2));

      // Verify legend
      expect(find.text('Completed'), findsNWidgets(2));
      expect(find.text('Skipped / Missed'), findsOneWidget);
    });

    testWidgets(
      'tapping a daily activity bar opens breakdown bottom sheet with tasks',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: SingleChildScrollView(
                child: PersonalHistoryStatsCard(stats: stats),
              ),
            ),
          ),
        );

        // Tap on Day 1 (Wed Jul 1, 2026)
        final day1Bar = find.byKey(const Key('daily_activity_bar_2026-07-01'));
        expect(day1Bar, findsOneWidget);
        await tester.tap(day1Bar);
        await tester.pumpAndSettle();

        // Bottom sheet appears
        expect(
          find.byKey(const Key('daily_activity_breakdown_sheet')),
          findsOneWidget,
        );
        expect(find.text('Wednesday, Jul 1, 2026'), findsOneWidget);
        expect(find.text('2 completed'), findsOneWidget);
        expect(find.text('1h 30m'), findsOneWidget);

        // Task items
        expect(find.text('Clean the kitchen'), findsOneWidget);
        expect(find.text('Wash dishes and wipe counters'), findsNothing);
        expect(find.text('Water plants'), findsOneWidget);

        // Close bottom sheet
        final closeButton = find.byIcon(Icons.close);
        expect(closeButton, findsOneWidget);
        await tester.tap(closeButton);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('daily_activity_breakdown_sheet')),
          findsNothing,
        );

        // Tap on Day 3 (Fri Jul 3, 2026) which has completed and missed
        final day3Bar = find.byKey(const Key('daily_activity_bar_2026-07-03'));
        expect(day3Bar, findsOneWidget);
        await tester.tap(day3Bar);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('daily_activity_breakdown_sheet')),
          findsOneWidget,
        );
        expect(find.text('Friday, Jul 3, 2026'), findsOneWidget);
        expect(find.text('1 completed'), findsOneWidget);
        expect(find.text('1 skipped'), findsOneWidget);
        expect(find.text('Take out trash'), findsOneWidget);
        expect(find.text('Mow the lawn'), findsOneWidget);

        // Close again
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'tapping a day with no activity displays empty state in breakdown sheet',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: SingleChildScrollView(
                child: PersonalHistoryStatsCard(stats: stats),
              ),
            ),
          ),
        );

        // Tap Day 4 (Sat Jul 4, 2026) with zero activity
        final day4Bar = find.byKey(const Key('daily_activity_bar_2026-07-04'));
        expect(day4Bar, findsOneWidget);
        await tester.tap(day4Bar);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('daily_activity_breakdown_sheet')),
          findsOneWidget,
        );
        expect(find.text('Saturday, Jul 4, 2026'), findsOneWidget);
        expect(find.text('No activity recorded for this day'), findsOneWidget);
      },
    );

    testGoldens('PersonalHistoryStatsCard renders correctly', (tester) async {
      final perfectStats = PersonalLastWeekStats(
        completedCount: 7,
        completedHours: 7.0,
        skippedCount: 0,
        missedCount: 0,
        completionRate: 1.0,
        startDay: startDay,
        endDay: endDay,
        dailyStats: [
          for (int i = 1; i <= 7; i++)
            DailyStatsData(
              day: CivilDay(year: 2026, month: 7, day: i),
              completedCount: 1,
              skippedCount: 0,
              missedCount: 0,
              completedHours: 1.0,
            ),
        ],
      );

      final emptyStats = PersonalLastWeekStats(
        completedCount: 0,
        completedHours: 0.0,
        skippedCount: 0,
        missedCount: 0,
        completionRate: 0.0,
        startDay: startDay,
        endDay: endDay,
        dailyStats: [
          for (int i = 1; i <= 7; i++)
            DailyStatsData(
              day: CivilDay(year: 2026, month: 7, day: i),
              completedCount: 0,
              skippedCount: 0,
              missedCount: 0,
              completedHours: 0.0,
            ),
        ],
      );

      final builder = GoldenBuilder.column()
        ..addScenario(
          'Personal Past Week - Active Week',
          PersonalHistoryStatsCard(stats: stats),
        )
        ..addScenario(
          'Personal Past Week - Perfect Week',
          PersonalHistoryStatsCard(stats: perfectStats),
        )
        ..addScenario(
          'Personal Past Week - Zero Activity',
          PersonalHistoryStatsCard(stats: emptyStats),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(500, 1600),
      );

      await screenMatchesGolden(tester, 'personal_history_stats_card_golden');
    });
  });
}
