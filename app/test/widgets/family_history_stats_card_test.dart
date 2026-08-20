import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/dashboard_stats.dart';
import 'package:nothing_ever_happens/logic/family.dart';
import 'package:nothing_ever_happens/widgets/family_history_stats_card.dart';
import '../test_helper.dart';

void main() {
  group('FamilyHistoryStatsCard', () {
    final startDay = CivilDay(year: 2026, month: 7, day: 1);
    final endDay = CivilDay(year: 2026, month: 7, day: 7);

    final stats = FamilyLastWeekStats(
      familyId: 'fam-1',
      familyName: 'The Parrs',
      totalCompletedCount: 6,
      totalCompletedHours: 4.5,
      totalSkippedCount: 1,
      totalMissedCount: 1,
      completionRate: 6 / 8,
      startDay: startDay,
      endDay: endDay,
      memberStats: [
        const FamilyMemberStats(
          userId: 'u-1',
          displayName: 'Helen',
          email: 'helen@example.com',
          role: FamilyRole.parent,
          completedCount: 4,
          completedHours: 3.0,
          skippedCount: 0,
          missedCount: 0,
          contributionPercentage: 4 / 6,
        ),
        const FamilyMemberStats(
          userId: 'u-2',
          displayName: 'Bob',
          email: 'bob@example.com',
          role: FamilyRole.parent,
          completedCount: 2,
          completedHours: 1.5,
          skippedCount: 1,
          missedCount: 1,
          contributionPercentage: 2 / 6,
        ),
      ],
    );

    testWidgets(
      'renders family header badge, metrics, chore distribution, and member tiles',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: SingleChildScrollView(
                child: FamilyHistoryStatsCard(stats: stats),
              ),
            ),
          ),
        );

        expect(find.text('Family Team Activity'), findsOneWidget);
        expect(find.text('The Parrs'), findsOneWidget);
        expect(find.text('6'), findsOneWidget);
        expect(find.text('4h 30m'), findsOneWidget);
        expect(find.text('75%'), findsOneWidget);
        expect(find.text('1 family tasks skipped · 1 missed'), findsOneWidget);

        // Chore Distribution section
        expect(find.text('Chore Distribution'), findsOneWidget);

        // Member items
        expect(find.text('Helen'), findsOneWidget);
        expect(find.text('Bob'), findsOneWidget);
        expect(find.text('67%'), findsOneWidget);
        expect(find.text('33%'), findsOneWidget);
      },
    );

    testGoldens('FamilyHistoryStatsCard renders correctly', (tester) async {
      final threeMemberStats = FamilyLastWeekStats(
        familyId: 'fam-1',
        familyName: 'The Incredibles',
        totalCompletedCount: 10,
        totalCompletedHours: 8.0,
        totalSkippedCount: 0,
        totalMissedCount: 0,
        completionRate: 1.0,
        startDay: startDay,
        endDay: endDay,
        memberStats: [
          const FamilyMemberStats(
            userId: 'u-1',
            displayName: 'Helen',
            email: 'helen@example.com',
            role: FamilyRole.parent,
            completedCount: 5,
            completedHours: 4.0,
            skippedCount: 0,
            missedCount: 0,
            contributionPercentage: 0.5,
          ),
          const FamilyMemberStats(
            userId: 'u-2',
            displayName: 'Bob',
            email: 'bob@example.com',
            role: FamilyRole.parent,
            completedCount: 3,
            completedHours: 2.5,
            skippedCount: 0,
            missedCount: 0,
            contributionPercentage: 0.3,
          ),
          const FamilyMemberStats(
            userId: 'u-3',
            displayName: 'Dash',
            email: 'dash@example.com',
            role: FamilyRole.nonParent,
            completedCount: 2,
            completedHours: 1.5,
            skippedCount: 0,
            missedCount: 0,
            contributionPercentage: 0.2,
          ),
        ],
      );

      final zeroCompletedStats = FamilyLastWeekStats(
        familyId: 'fam-1',
        familyName: 'The Parrs',
        totalCompletedCount: 0,
        totalCompletedHours: 0.0,
        totalSkippedCount: 1,
        totalMissedCount: 1,
        completionRate: 0.0,
        startDay: startDay,
        endDay: endDay,
        memberStats: [
          const FamilyMemberStats(
            userId: 'u-1',
            displayName: 'Helen',
            email: 'helen@example.com',
            role: FamilyRole.parent,
            completedCount: 0,
            completedHours: 0.0,
            skippedCount: 1,
            missedCount: 0,
            contributionPercentage: 0.0,
          ),
          const FamilyMemberStats(
            userId: 'u-2',
            displayName: 'Bob',
            email: 'bob@example.com',
            role: FamilyRole.parent,
            completedCount: 0,
            completedHours: 0.0,
            skippedCount: 0,
            missedCount: 1,
            contributionPercentage: 0.0,
          ),
        ],
      );

      final builder = GoldenBuilder.column()
        ..addScenario(
          'Family Team Activity - Multi Member',
          FamilyHistoryStatsCard(stats: stats),
        )
        ..addScenario(
          'Family Team Activity - Three Members',
          FamilyHistoryStatsCard(stats: threeMemberStats),
        )
        ..addScenario(
          'Family Team Activity - Zero Completed',
          FamilyHistoryStatsCard(stats: zeroCompletedStats),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(500, 1600),
      );

      await screenMatchesGolden(tester, 'family_history_stats_card_golden');
    });
  });
}
