import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/dashboard_stats.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/widgets/daily_activity_breakdown_sheet.dart';
import '../test_helper.dart';

void main() {
  group('DailyActivityBreakdownSheet', () {
    final day = CivilDay(year: 2026, month: 7, day: 1); // Wednesday

    const dummyStart = RelativeTime(
      dayOffset: 0,
      time: TimeOfDay(hour: 9, minute: 0),
    );
    const dummyDue = RelativeTime(
      dayOffset: 0,
      time: TimeOfDay(hour: 17, minute: 0),
    );

    final activeDayData = DailyStatsData(
      day: day,
      completedCount: 2,
      skippedCount: 1,
      missedCount: 1,
      completedHours: 2.5,
      completedTasks: [
        TaskInstance(
          id: 't-1',
          scheduleId: 's-1',
          ruleId: 'r-1',
          title: 'Clean the kitchen',
          description: 'Wash dishes and wipe counters',
          scheduledDate: day,
          startRelativeTime: dummyStart,
          dueRelativeTime: dummyDue,
          status: TaskStatus.completed,
          completedAt: DateTime(2026, 7, 1, 14, 30),
        ),
        TaskInstance(
          id: 't-2',
          scheduleId: 's-2',
          ruleId: 'r-2',
          title: 'Water plants',
          description: '',
          scheduledDate: day,
          startRelativeTime: dummyStart,
          dueRelativeTime: dummyDue,
          status: TaskStatus.completed,
        ),
      ],
      skippedTasks: [
        TaskInstance(
          id: 't-3',
          scheduleId: 's-3',
          ruleId: 'r-3',
          title: 'Vacuum living room',
          description: 'Carpet in hallway and living room',
          scheduledDate: day,
          startRelativeTime: dummyStart,
          dueRelativeTime: dummyDue,
          status: TaskStatus.skipped,
        ),
      ],
      missedTasks: [
        TaskInstance(
          id: 't-4',
          scheduleId: 's-4',
          ruleId: 'r-4',
          title: 'Take out recycling',
          description: '',
          scheduledDate: day,
          startRelativeTime: dummyStart,
          dueRelativeTime: dummyDue,
          status: TaskStatus.pending,
        ),
      ],
    );

    final emptyDayData = DailyStatsData(
      day: CivilDay(year: 2026, month: 7, day: 4),
      completedCount: 0,
      skippedCount: 0,
      missedCount: 0,
      completedHours: 0.0,
    );

    final completedOnlyDayData = DailyStatsData(
      day: CivilDay(year: 2026, month: 7, day: 5),
      completedCount: 2,
      skippedCount: 0,
      missedCount: 0,
      completedHours: 1.5,
      completedTasks: [
        TaskInstance(
          id: 't-5',
          scheduleId: 's-5',
          ruleId: 'r-5',
          title: 'Read chapter 4',
          description: 'Pages 50-80',
          scheduledDate: CivilDay(year: 2026, month: 7, day: 5),
          startRelativeTime: dummyStart,
          dueRelativeTime: dummyDue,
          status: TaskStatus.completed,
          completedAt: DateTime(2026, 7, 5, 10, 15),
        ),
        TaskInstance(
          id: 't-6',
          scheduleId: 's-6',
          ruleId: 'r-6',
          title: 'Morning stretch',
          description: '',
          scheduledDate: CivilDay(year: 2026, month: 7, day: 5),
          startRelativeTime: dummyStart,
          dueRelativeTime: dummyDue,
          status: TaskStatus.completed,
          completedAt: DateTime(2026, 7, 5, 8, 0),
        ),
      ],
    );

    testWidgets(
      'renders date header, metric chips, section headers, and task tiles',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: DailyActivityBreakdownSheet(dayData: activeDayData),
            ),
          ),
        );

        // Header date
        expect(find.text('Wednesday, Jul 1, 2026'), findsOneWidget);

        // Metric chips
        expect(find.text('2 completed'), findsOneWidget);
        expect(find.text('1 skipped'), findsOneWidget);
        expect(find.text('1 missed'), findsOneWidget);
        expect(find.text('2h 30m'), findsOneWidget);

        // Section headers
        expect(find.text('Completed (2)'), findsOneWidget);
        expect(find.text('Skipped (1)'), findsOneWidget);
        expect(find.text('Missed / Overdue (1)'), findsOneWidget);

        // Task tiles
        expect(find.text('Clean the kitchen'), findsOneWidget);
        expect(
          find.text('Wash dishes and wipe counters · Completed at 14:30'),
          findsOneWidget,
        );
        expect(find.text('Water plants'), findsOneWidget);
        expect(find.text('Vacuum living room'), findsOneWidget);
        expect(find.text('Carpet in hallway and living room'), findsOneWidget);
        expect(find.text('Take out recycling'), findsOneWidget);

        // Status tags
        expect(find.text('Completed'), findsNWidgets(2));
        expect(find.text('Skipped'), findsOneWidget);
        expect(find.text('Missed'), findsOneWidget);
      },
    );

    testWidgets('renders empty state when day has no tasks', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: DailyActivityBreakdownSheet(dayData: emptyDayData),
          ),
        ),
      );

      expect(find.text('Saturday, Jul 4, 2026'), findsOneWidget);
      expect(find.text('No tasks recorded'), findsOneWidget);
      expect(find.text('No activity recorded for this day'), findsOneWidget);
      expect(find.byIcon(Icons.event_busy_outlined), findsOneWidget);
    });

    testWidgets('close button dismisses sheet when opened via show', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    DailyActivityBreakdownSheet.show(context, activeDayData),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('daily_activity_breakdown_sheet')),
        findsOneWidget,
      );

      // Tap close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('daily_activity_breakdown_sheet')),
        findsNothing,
      );
    });

    testGoldens('DailyActivityBreakdownSheet renders correctly', (
      tester,
    ) async {
      final builder = GoldenBuilder.column()
        ..addScenario(
          'Active Day Breakdown',
          Material(child: DailyActivityBreakdownSheet(dayData: activeDayData)),
        )
        ..addScenario(
          'Completed Only Breakdown',
          Material(
            child: DailyActivityBreakdownSheet(dayData: completedOnlyDayData),
          ),
        )
        ..addScenario(
          'Empty Day Breakdown',
          Material(child: DailyActivityBreakdownSheet(dayData: emptyDayData)),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(500, 1600),
      );

      await screenMatchesGolden(
        tester,
        'daily_activity_breakdown_sheet_golden',
      );
    });
  });
}
