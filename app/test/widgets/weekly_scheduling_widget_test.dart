import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:nothing_ever_happens/logic/task.dart';
import 'package:nothing_ever_happens/widgets/weekly_scheduling_widget.dart';
import 'package:nothing_ever_happens/widgets/daily_time_list_widget.dart';
import 'weekly_scheduling_widget_robot.dart';

void main() {
  group('WeeklySchedulingWidget', () {
    testWidgets('renders all fields', (tester) async {
      final startDate = DateTime(2026, 10, 26);
      final dailyTimesController = ValueNotifier<List<DailyOccurrenceTime>>([
        const DailyOccurrenceTime(
          startTime: TimeOfDay(hour: 9, minute: 0),
          dueTime: TimeOfDay(hour: 17, minute: 0),
        ),
      ]);
      final intervalController = TextEditingController(text: '1');
      final selectedWeekdays = {1, 3, 5}; // Mon, Wed, Fri

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WeeklySchedulingWidget(
                startDate: startDate,
                onStartDateChanged: (_) {},
                dailyTimesController: dailyTimesController,
                intervalController: intervalController,
                selectedWeekdays: selectedWeekdays,
                onWeekdaysChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Daily Occurrences'), findsOneWidget);
      expect(find.byType(DailyTimeListWidget), findsOneWidget);
      expect(find.text('Start Date'), findsOneWidget);
      expect(find.text('Weeks Interval'), findsOneWidget);
      expect(find.text('Repeats on'), findsOneWidget);
      expect(find.byType(FilterChip), findsNWidgets(7));

      final mondayChip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'M').first,
      );
      expect(mondayChip.selected, isTrue);

      final tuesdayChip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'T').first,
      );
      expect(tuesdayChip.selected, isFalse);
    });

    testWidgets('updates weekdays when chip is tapped', (tester) async {
      final startDate = DateTime(2026, 10, 26);
      final dailyTimesController = ValueNotifier<List<DailyOccurrenceTime>>([
        const DailyOccurrenceTime(
          startTime: TimeOfDay(hour: 9, minute: 0),
          dueTime: TimeOfDay(hour: 17, minute: 0),
        ),
      ]);
      final intervalController = TextEditingController(text: '1');
      Set<int> selectedWeekdays = {1}; // Mon
      final robot = WeeklySchedulingWidgetRobot(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return WeeklySchedulingWidget(
                    startDate: startDate,
                    onStartDateChanged: (_) {},
                    dailyTimesController: dailyTimesController,
                    intervalController: intervalController,
                    selectedWeekdays: selectedWeekdays,
                    onWeekdaysChanged: (newSet) {
                      setState(() {
                        selectedWeekdays = newSet;
                      });
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Tap Tuesday (index 1)
      await robot.toggleDayByIndex(1);

      expect(selectedWeekdays, {1, 2});

      // Tap Monday (index 0) to deselect
      await robot.toggleDayByIndex(0);

      expect(selectedWeekdays, {2});
    });

    testGoldens('WeeklySchedulingWidget renders correctly', (tester) async {
      final startDate = DateTime(2026, 10, 26);
      final dailyTimesController = ValueNotifier<List<DailyOccurrenceTime>>([
        const DailyOccurrenceTime(
          startTime: TimeOfDay(hour: 9, minute: 0),
          dueTime: TimeOfDay(hour: 17, minute: 0),
        ),
      ]);
      final intervalController = TextEditingController(text: '1');
      final selectedWeekdays = {1, 3, 5};

      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 0.9)
        ..addScenario(
          'Default',
          WeeklySchedulingWidget(
            startDate: startDate,
            onStartDateChanged: (_) {},
            dailyTimesController: dailyTimesController,
            intervalController: intervalController,
            selectedWeekdays: selectedWeekdays,
            onWeekdaysChanged: (_) {},
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: materialAppWrapper(),
        surfaceSize: const Size(800, 1000),
      );
      await screenMatchesGolden(tester, 'weekly_scheduling_widget');
    });
  });
}
