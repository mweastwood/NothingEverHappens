import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/dashboard_stats.dart';
import 'package:nothing_ever_happens/logic/family.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/widgets/family_contributions_card.dart';
import '../test_helper.dart';

void main() {
  group('FamilyContributionsCard', () {
    final startDay = CivilDay(year: 2026, month: 7, day: 1);
    final endDay = CivilDay(year: 2026, month: 7, day: 7);

    final schedule1 = TaskSchedule(
      id: 's-1',
      title: 'Cook Dinner',
      description: 'Dinner',
      estimatedDuration: const Duration(minutes: 60),
      isFamily: true,
      schedules: [],
    );

    final schedule2 = TaskSchedule(
      id: 's-2',
      title: 'Wash Dishes',
      description: 'Dishes',
      estimatedDuration: const Duration(minutes: 30),
      isFamily: true,
      schedules: [],
    );

    final scheduleMap = <String, TaskSchedule>{
      schedule1.id: schedule1,
      schedule2.id: schedule2,
    };

    final taskHelen1 = TaskInstance(
      id: 't-h1',
      scheduleId: schedule1.id,
      ruleId: 'r-1',
      title: 'Cook Dinner',
      description: '',
      scheduledDate: CivilDay(year: 2026, month: 7, day: 5),
      startRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 17, minute: 0),
      ),
      dueRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 18, minute: 0),
      ),
      status: TaskStatus.completed,
      completedAt: DateTime(2026, 7, 5, 18, 0),
      completedByUserId: 'u-1',
      isFamily: true,
    );

    final taskHelen2 = TaskInstance(
      id: 't-h2',
      scheduleId: schedule1.id,
      ruleId: 'r-1',
      title: 'Cook Dinner',
      description: '',
      scheduledDate: CivilDay(year: 2026, month: 7, day: 6),
      startRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 17, minute: 0),
      ),
      dueRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 18, minute: 0),
      ),
      status: TaskStatus.completed,
      completedAt: DateTime(2026, 7, 6, 18, 0),
      completedByUserId: 'u-1',
      isFamily: true,
    );

    final taskBob = TaskInstance(
      id: 't-b1',
      scheduleId: schedule2.id,
      ruleId: 'r-2',
      title: 'Wash Dishes',
      description: '',
      scheduledDate: CivilDay(year: 2026, month: 7, day: 7),
      startRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 19, minute: 0),
      ),
      dueRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 20, minute: 0),
      ),
      status: TaskStatus.completed,
      completedAt: DateTime(2026, 7, 7, 19, 30),
      completedByUserId: 'u-2',
      isFamily: true,
    );

    final stats = FamilyLastWeekStats(
      familyId: 'fam-1',
      familyName: 'The Parrs',
      totalCompletedCount: 3,
      totalCompletedHours: 2.5, // Helen: 2.0h (80%), Bob: 0.5h (20%)
      totalSkippedCount: 0,
      totalMissedCount: 0,
      totalPlannedCount: 0,
      totalPlannedHours: 0.0,
      completionRate: 1.0,
      startDay: startDay,
      endDay: endDay,
      dailyStats: [],
      memberStats: [
        FamilyMemberStats(
          userId: 'u-1',
          displayName: 'Helen',
          email: 'helen@example.com',
          role: FamilyRole.parent,
          completedCount: 2,
          completedHours: 2.0,
          skippedCount: 0,
          missedCount: 0,
          contributionPercentage: 2.0 / 2.5, // 80%
          completedTasks: [taskHelen1, taskHelen2],
        ),
        FamilyMemberStats(
          userId: 'u-2',
          displayName: 'Bob',
          email: 'bob@example.com',
          role: FamilyRole.parent,
          completedCount: 1,
          completedHours: 0.5,
          skippedCount: 0,
          missedCount: 0,
          contributionPercentage: 0.5 / 2.5, // 20%
          completedTasks: [taskBob],
        ),
      ],
    );

    testWidgets('renders title, pie chart, member tiles with percentages', (
      tester,
    ) async {
      AppClock.setMockTime(DateTime(2026, 7, 7, 12, 0));
      addTearDown(AppClock.reset);

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: FamilyContributionsCard(
                stats: stats,
                scheduleMap: scheduleMap,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Family Contributions'), findsOneWidget);
      expect(
        find.byKey(const Key('family_contributions_pie_chart')),
        findsOneWidget,
      );

      // Members list
      expect(find.text('Helen'), findsOneWidget);
      expect(find.text('2 done (2h)'), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);

      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('1 done (30m)'), findsOneWidget);
      expect(find.text('20%'), findsOneWidget);
    });

    testWidgets('tapping member tile opens bottom sheet with task list', (
      tester,
    ) async {
      AppClock.setMockTime(DateTime(2026, 7, 7, 12, 0));
      addTearDown(AppClock.reset);

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: FamilyContributionsCard(
                stats: stats,
                scheduleMap: scheduleMap,
              ),
            ),
          ),
        ),
      );

      final helenTile = find.byKey(const Key('family_contribution_tile_u-1'));
      expect(helenTile, findsOneWidget);
      await tester.tap(helenTile);
      await tester.pumpAndSettle();

      // Bottom sheet open
      expect(
        find.byKey(const Key('family_member_contributions_sheet')),
        findsOneWidget,
      );
      expect(find.text('2 completed'), findsOneWidget);
      expect(find.text('2h'), findsOneWidget);
      expect(find.text('80% of total'), findsOneWidget);
      expect(find.text('Cook Dinner'), findsNWidgets(2));
    });

    testWidgets('tapping pie slice opens bottom sheet for member', (
      tester,
    ) async {
      AppClock.setMockTime(DateTime(2026, 7, 7, 12, 0));
      addTearDown(AppClock.reset);

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: FamilyContributionsCard(
                stats: stats,
                scheduleMap: scheduleMap,
              ),
            ),
          ),
        ),
      );

      final pieFinder = find.byKey(const Key('family_contributions_pie_chart'));
      expect(pieFinder, findsOneWidget);

      // Tap on top-right of pie chart (Helen's 80% slice covers from top clockwise)
      final center = tester.getCenter(pieFinder);
      await tester.tapAt(center + const Offset(40, -20));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('family_member_contributions_sheet')),
        findsOneWidget,
      );
      expect(find.text('Cook Dinner'), findsNWidgets(2));
    });

    testWidgets('renders empty state when no contributions', (tester) async {
      AppClock.setMockTime(DateTime(2026, 7, 7, 12, 0));
      addTearDown(AppClock.reset);

      final zeroStats = FamilyLastWeekStats(
        familyId: 'fam-1',
        familyName: 'The Parrs',
        totalCompletedCount: 0,
        totalCompletedHours: 0.0,
        totalSkippedCount: 0,
        totalMissedCount: 0,
        totalPlannedCount: 0,
        totalPlannedHours: 0.0,
        completionRate: 0.0,
        startDay: startDay,
        endDay: endDay,
        dailyStats: [],
        memberStats: [
          const FamilyMemberStats(
            userId: 'u-1',
            displayName: 'Helen',
            email: 'helen@example.com',
            role: FamilyRole.parent,
            completedCount: 0,
            completedHours: 0.0,
            skippedCount: 0,
            missedCount: 0,
            contributionPercentage: 0.0,
            completedTasks: [],
          ),
        ],
      );

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: FamilyContributionsCard(
                stats: zeroStats,
                scheduleMap: scheduleMap,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Family Contributions'), findsOneWidget);
      expect(find.text('0 done (0m)'), findsOneWidget);

      // Tap Helen tile
      final helenTile = find.byKey(const Key('family_contribution_tile_u-1'));
      await tester.tap(helenTile);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('family_member_contributions_sheet')),
        findsOneWidget,
      );
      expect(
        find.text('No contributions recorded in this period'),
        findsOneWidget,
      );
    });

    testGoldens('FamilyContributionsCard renders correctly', (tester) async {
      AppClock.setMockTime(DateTime(2026, 7, 7, 12, 0));
      addTearDown(AppClock.reset);

      final threeMemberStats = FamilyLastWeekStats(
        familyId: 'fam-1',
        familyName: 'The Incredibles',
        totalCompletedCount: 10,
        totalCompletedHours: 8.0,
        totalSkippedCount: 0,
        totalMissedCount: 0,
        totalPlannedCount: 0,
        totalPlannedHours: 0.0,
        completionRate: 1.0,
        startDay: startDay,
        endDay: endDay,
        dailyStats: [],
        memberStats: [
          FamilyMemberStats(
            userId: 'u-1',
            displayName: 'Helen',
            email: 'helen@example.com',
            role: FamilyRole.parent,
            completedCount: 5,
            completedHours: 4.0,
            skippedCount: 0,
            missedCount: 0,
            contributionPercentage: 0.5,
            completedTasks: [taskHelen1],
          ),
          FamilyMemberStats(
            userId: 'u-2',
            displayName: 'Bob',
            email: 'bob@example.com',
            role: FamilyRole.parent,
            completedCount: 3,
            completedHours: 2.4,
            skippedCount: 0,
            missedCount: 0,
            contributionPercentage: 0.3,
            completedTasks: [taskBob],
          ),
          const FamilyMemberStats(
            userId: 'u-3',
            displayName: 'Dash',
            email: 'dash@example.com',
            role: FamilyRole.nonParent,
            completedCount: 2,
            completedHours: 1.6,
            skippedCount: 0,
            missedCount: 0,
            contributionPercentage: 0.2,
            completedTasks: [],
          ),
        ],
      );

      final zeroStats = FamilyLastWeekStats(
        familyId: 'fam-1',
        familyName: 'The Parrs',
        totalCompletedCount: 0,
        totalCompletedHours: 0.0,
        totalSkippedCount: 0,
        totalMissedCount: 0,
        totalPlannedCount: 0,
        totalPlannedHours: 0.0,
        completionRate: 0.0,
        startDay: startDay,
        endDay: endDay,
        dailyStats: [],
        memberStats: [
          const FamilyMemberStats(
            userId: 'u-1',
            displayName: 'Helen',
            email: 'helen@example.com',
            role: FamilyRole.parent,
            completedCount: 0,
            completedHours: 0.0,
            skippedCount: 0,
            missedCount: 0,
            contributionPercentage: 0.0,
            completedTasks: [],
          ),
          const FamilyMemberStats(
            userId: 'u-2',
            displayName: 'Bob',
            email: 'bob@example.com',
            role: FamilyRole.parent,
            completedCount: 0,
            completedHours: 0.0,
            skippedCount: 0,
            missedCount: 0,
            contributionPercentage: 0.0,
            completedTasks: [],
          ),
        ],
      );

      final builder = GoldenBuilder.column()
        ..addScenario(
          'Family Contributions - Multi Member',
          FamilyContributionsCard(stats: stats, scheduleMap: scheduleMap),
        )
        ..addScenario(
          'Family Contributions - Three Members',
          FamilyContributionsCard(
            stats: threeMemberStats,
            scheduleMap: scheduleMap,
          ),
        )
        ..addScenario(
          'Family Contributions - Zero Completed',
          FamilyContributionsCard(stats: zeroStats, scheduleMap: scheduleMap),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(500, 1600),
      );

      await screenMatchesGolden(tester, 'family_contributions_card_golden');
    });
  });
}
