import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  });
}
