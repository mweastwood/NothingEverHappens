import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/dashboard_stats.dart';
import 'package:nothing_ever_happens/widgets/weekly_capacity_chart.dart';
import '../test_helper.dart';

void main() {
  group('WeeklyCapacityChart', () {
    final testDays = [
      DailyCapacityData(
        date: DateTime(2026, 7, 1), // Wednesday
        capacityHours: 4.0,
        plannedMinutes: 135.0, // 2h 15m
        isOverridden: false,
      ),
      DailyCapacityData(
        date: DateTime(2026, 7, 2), // Thursday
        capacityHours: 8.0,
        plannedMinutes: 0.0, // 8h
        isOverridden: true,
      ),
    ];

    tearDown(() {
      AppClock.reset();
    });

    testWidgets('renders title, subtitle, and action buttons', (tester) async {
      AppClock.setMockTime(DateTime(2026, 7, 1));
      bool editTemplateTapped = false;

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: WeeklyCapacityChart(
              daysData: testDays,
              onDayTap: (_) {},
              onEditDefaultCapacity: () => editTemplateTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Personal Timeline'), findsOneWidget);
      expect(find.text('Jul 1 – 2'), findsOneWidget);
      expect(find.text('Past'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Past 6 Days'), findsNothing);
      expect(find.text('Next 6 Days'), findsNothing);
      expect(
        find.textContaining('6 days history + Today + 6 days forecast'),
        findsNothing,
      );

      final editBtn = find.byKey(const Key('edit_default_capacity_button'));
      expect(editBtn, findsOneWidget);
      expect(find.text('Edit Capacity'), findsOneWidget);
      await tester.tap(editBtn);
      expect(editTemplateTapped, isTrue);
    });

    testWidgets('past days do not render dashed capacity box', (tester) async {
      // Mock clock to July 2, 2026 (Thursday), so July 1 (Wednesday) is history
      AppClock.setMockTime(DateTime(2026, 7, 2));

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: WeeklyCapacityChart(
              daysData: testDays,
              onDayTap: (_) {},
              onEditDefaultCapacity: () {},
            ),
          ),
        ),
      );

      // Wednesday (past) bar should NOT contain DashedRectPainter
      final wedBar = find.byKey(const Key('capacity_bar_2026-07-01'));
      final wedDashed = find.descendant(
        of: wedBar,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint && widget.painter is DashedRectPainter,
        ),
      );
      expect(wedDashed, findsNothing);

      // Thursday (today) bar SHOULD contain DashedRectPainter
      final thuBar = find.byKey(const Key('capacity_bar_2026-07-02'));
      final thuDashed = find.descendant(
        of: thuBar,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint && widget.painter is DashedRectPainter,
        ),
      );
      expect(thuDashed, findsOneWidget);
    });

    testWidgets('renders capacity data and handles day tap callbacks', (
      tester,
    ) async {
      AppClock.setMockTime(DateTime(2026, 7, 1));
      DateTime? tappedDate;

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: WeeklyCapacityChart(
              daysData: testDays,
              onDayTap: (date) => tappedDate = date,
              onEditDefaultCapacity: () {},
            ),
          ),
        ),
      );

      // Verify formatted forecast labels for today (Wed) and future (Thu)
      expect(find.text('2h 15m/4h'), findsOneWidget);
      expect(find.text('8h'), findsOneWidget);

      // Verify day labels (Wed, Thu)
      expect(find.text('Wed'), findsOneWidget);
      expect(find.text('Thu'), findsOneWidget);

      // Tap Wednesday bar
      final wedBarKey = const Key('capacity_bar_2026-07-01');
      expect(find.byKey(wedBarKey), findsOneWidget);
      await tester.tap(find.byKey(wedBarKey));

      expect(tappedDate, equals(DateTime(2026, 7, 1)));
    });

    testWidgets('history bars display time spent without capacity label', (
      tester,
    ) async {
      // Mock clock to July 2, 2026 (Thursday), so July 1 (Wednesday) is history
      AppClock.setMockTime(DateTime(2026, 7, 2));

      final historyDays = [
        DailyCapacityData(
          date: DateTime(2026, 7, 1), // Wednesday (past)
          capacityHours: 4.0,
          plannedMinutes: 0.0,
          completedMinutes: 90.0, // 1h 30m spent
          isOverridden: false,
        ),
        DailyCapacityData(
          date: DateTime(2026, 7, 2), // Thursday (today)
          capacityHours: 8.0,
          plannedMinutes: 60.0,
          completedMinutes: 0.0,
          isOverridden: false,
        ),
      ];

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: WeeklyCapacityChart(
              daysData: historyDays,
              onDayTap: (_) {},
              onEditDefaultCapacity: () {},
            ),
          ),
        ),
      );

      // For Wednesday (history), label is "1h 30m" without capacity (/4h)
      expect(find.text('1h 30m'), findsOneWidget);
      expect(find.text('1h 30m/4h'), findsNothing);

      // For Thursday (today), label is "1h/8h"
      expect(find.text('1h/8h'), findsOneWidget);
    });

    testWidgets(
      'history bars render overdue in warning color and skipped in hatched red',
      (tester) async {
        // Mock clock to July 2, 2026 (Thursday), so July 1 (Wednesday) is history
        AppClock.setMockTime(DateTime(2026, 7, 2));

        final statsData = DailyStatsData(
          day: CivilDay(year: 2026, month: 7, day: 1),
          completedCount: 2,
          skippedCount: 1,
          missedCount: 0,
          completedHours: 2.0,
          completedOnTimeHours: 1.0,
          completedOverdueHours: 1.0,
          skippedHours: 0.5,
        );

        final historyDays = [
          DailyCapacityData(
            date: DateTime(2026, 7, 1), // Wednesday (past)
            capacityHours: 4.0,
            plannedMinutes: 0.0,
            completedMinutes: 120.0,
            isOverridden: false,
            statsData: statsData,
          ),
        ];

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: WeeklyCapacityChart(
                daysData: historyDays,
                onDayTap: (_) {},
                onEditDefaultCapacity: () {},
              ),
            ),
          ),
        );

        // Verify HatchedPatternPainter is used for skipped items
        final hatchedPaints = find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint && widget.painter is HatchedPatternPainter,
        );
        expect(hatchedPaints, findsWidgets);
      },
    );

    testWidgets(
      'renders seriously overdue in legend and stacks red gradient segment for past days',
      (tester) async {
        AppClock.setMockTime(DateTime(2026, 7, 2));

        final statsData = DailyStatsData(
          day: CivilDay(year: 2026, month: 7, day: 1),
          completedCount: 3,
          skippedCount: 0,
          missedCount: 0,
          completedHours: 3.0,
          completedOnTimeHours: 1.0,
          completedOverdueHours: 2.0,
          completedSeriouslyOverdueHours: 1.0,
        );

        final historyDays = [
          DailyCapacityData(
            date: DateTime(2026, 7, 1),
            capacityHours: 4.0,
            plannedMinutes: 0.0,
            completedMinutes: 180.0,
            isOverridden: false,
            statsData: statsData,
          ),
        ];

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: WeeklyCapacityChart(
                daysData: historyDays,
                onDayTap: (_) {},
                onEditDefaultCapacity: () {},
              ),
            ),
          ),
        );

        // Legend should include 'Seriously Overdue'
        expect(find.text('Seriously Overdue'), findsOneWidget);
        expect(find.text('Completed Overdue'), findsOneWidget);
        expect(find.text('Completed'), findsOneWidget);
      },
    );

    testWidgets('respects AppClock.now for current day highlighting', (
      tester,
    ) async {
      // Mock clock to July 2, 2026 (Thursday)
      AppClock.setMockTime(DateTime(2026, 7, 2));

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: WeeklyCapacityChart(
              daysData: testDays,
              onDayTap: (_) {},
              onEditDefaultCapacity: () {},
            ),
          ),
        ),
      );

      // Thursday date is 2
      final thuTextWidget = tester.widget<Text>(find.text('Thu'));
      expect(thuTextWidget.style?.fontWeight, equals(FontWeight.bold));

      final wedTextWidget = tester.widget<Text>(find.text('Wed'));
      expect(wedTextWidget.style?.fontWeight, equals(FontWeight.normal));
    });

    testGoldens('WeeklyCapacityChart renders correctly', (tester) async {
      AppClock.setMockTime(DateTime(2026, 7, 1)); // Wednesday

      final activeWeekDays = [
        DailyCapacityData(
          date: DateTime(2026, 7, 1), // Wed (today)
          capacityHours: 4.0,
          plannedMinutes: 135.0, // 2h 15m
          isOverridden: false,
        ),
        DailyCapacityData(
          date: DateTime(2026, 7, 2), // Thu
          capacityHours: 8.0,
          plannedMinutes: 0.0,
          isOverridden: true,
        ),
        DailyCapacityData(
          date: DateTime(2026, 7, 3), // Fri
          capacityHours: 2.0,
          plannedMinutes: 180.0, // 3h (over capacity)
          isOverridden: false,
        ),
        DailyCapacityData(
          date: DateTime(2026, 7, 4), // Sat
          capacityHours: 0.0,
          plannedMinutes: 0.0,
          isOverridden: false,
        ),
        DailyCapacityData(
          date: DateTime(2026, 7, 5), // Sun
          capacityHours: 0.0,
          plannedMinutes: 60.0, // 1h (over capacity)
          isOverridden: false,
        ),
        DailyCapacityData(
          date: DateTime(2026, 7, 6), // Mon
          capacityHours: 6.0,
          plannedMinutes: 120.0, // 2h
          isOverridden: true,
        ),
        DailyCapacityData(
          date: DateTime(2026, 7, 7), // Tue
          capacityHours: 4.0,
          plannedMinutes: 240.0, // 4h
          isOverridden: false,
        ),
      ];

      final baselineWeekDays = [
        for (int i = 1; i <= 7; i++)
          DailyCapacityData(
            date: DateTime(2026, 7, i),
            capacityHours: 8.0,
            plannedMinutes: 0.0,
            isOverridden: false,
          ),
      ];

      final builder = GoldenBuilder.column()
        ..addScenario(
          'Weekly Capacity Forecast - Active Week',
          WeeklyCapacityChart(
            daysData: activeWeekDays,
            onDayTap: (_) {},
            onEditDefaultCapacity: () {},
          ),
        )
        ..addScenario(
          'Weekly Capacity Forecast - Baseline Week',
          WeeklyCapacityChart(
            daysData: baselineWeekDays,
            onDayTap: (_) {},
            onEditDefaultCapacity: () {},
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(500, 900),
      );

      await screenMatchesGolden(tester, 'weekly_capacity_chart_golden');
    });
  });
}
