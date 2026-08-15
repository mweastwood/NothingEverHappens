import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
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

      expect(find.text('Weekly Capacity Forecast'), findsOneWidget);
      expect(
        find.text(
          'Tap a bar to override capacity for that specific calendar day.',
        ),
        findsOneWidget,
      );

      final editBtn = find.byKey(const Key('edit_default_capacity_button'));
      expect(editBtn, findsOneWidget);
      await tester.tap(editBtn);
      expect(editTemplateTapped, isTrue);
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

      // Verify formatted forecast labels
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
  });
}
