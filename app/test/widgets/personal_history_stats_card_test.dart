import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/dashboard_stats.dart';
import 'package:nothing_ever_happens/widgets/personal_history_stats_card.dart';
import '../test_helper.dart';

void main() {
  group('PersonalHistoryStatsCard', () {
    final startDay = CivilDay(year: 2026, month: 7, day: 1); // Wednesday
    final endDay = CivilDay(year: 2026, month: 7, day: 7); // Tuesday

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
        ),
        DailyStatsData(
          day: CivilDay(year: 2026, month: 7, day: 2),
          completedCount: 0,
          skippedCount: 1,
          missedCount: 0,
          completedHours: 0.0,
        ),
        DailyStatsData(
          day: CivilDay(year: 2026, month: 7, day: 3),
          completedCount: 1,
          skippedCount: 0,
          missedCount: 1,
          completedHours: 1.0,
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
