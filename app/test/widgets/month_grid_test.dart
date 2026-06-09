import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/widgets/month_grid.dart';
import '../test_helper.dart';

void main() {
  group('MonthGrid', () {
    testWidgets('renders month and year header and days grid', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: MonthGrid(
              year: 2026,
              month: 10,
              highlightedDays: {CivilDay(year: 2026, month: 10, day: 15)},
              startDays: {CivilDay(year: 2026, month: 10, day: 10)},
              dueDays: {CivilDay(year: 2026, month: 10, day: 20)},
              rangeDays: {
                CivilDay(year: 2026, month: 10, day: 10),
                CivilDay(year: 2026, month: 10, day: 11),
                CivilDay(year: 2026, month: 10, day: 12),
                CivilDay(year: 2026, month: 10, day: 13),
                CivilDay(year: 2026, month: 10, day: 14),
                CivilDay(year: 2026, month: 10, day: 15),
                CivilDay(year: 2026, month: 10, day: 16),
                CivilDay(year: 2026, month: 10, day: 17),
                CivilDay(year: 2026, month: 10, day: 18),
                CivilDay(year: 2026, month: 10, day: 19),
                CivilDay(year: 2026, month: 10, day: 20),
              },
              startDate: CivilDay(year: 2026, month: 10, day: 10),
            ),
          ),
        ),
      );

      // Verify the header is rendered
      expect(find.text('October 2026'), findsOneWidget);

      // Verify a day in the range is rendered
      expect(find.text('15'), findsOneWidget);
    });

    testGoldens('MonthGrid renders correctly', (tester) async {
      final builder = GoldenBuilder.column()
        ..addScenario(
          'October 2026 Grid with range',
          MonthGrid(
            year: 2026,
            month: 10,
            highlightedDays: {CivilDay(year: 2026, month: 10, day: 15)},
            startDays: {CivilDay(year: 2026, month: 10, day: 10)},
            dueDays: {CivilDay(year: 2026, month: 10, day: 20)},
            rangeDays: {
              CivilDay(year: 2026, month: 10, day: 10),
              CivilDay(year: 2026, month: 10, day: 11),
              CivilDay(year: 2026, month: 10, day: 12),
              CivilDay(year: 2026, month: 10, day: 13),
              CivilDay(year: 2026, month: 10, day: 14),
              CivilDay(year: 2026, month: 10, day: 15),
              CivilDay(year: 2026, month: 10, day: 16),
              CivilDay(year: 2026, month: 10, day: 17),
              CivilDay(year: 2026, month: 10, day: 18),
              CivilDay(year: 2026, month: 10, day: 19),
              CivilDay(year: 2026, month: 10, day: 20),
            },
            startDate: CivilDay(year: 2026, month: 10, day: 10),
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
      );

      await screenMatchesGolden(tester, 'month_grid_golden');
    });
  });
}
