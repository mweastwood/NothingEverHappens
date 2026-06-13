import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/widgets/daily_scheduling_widget.dart';
import 'package:nothing_ever_happens/widgets/daily_time_list_widget.dart';
import '../test_helper.dart';
import 'daily_scheduling_widget_robot.dart';

void main() {
  group('DailySchedulingWidget', () {
    testWidgets('renders all fields', (tester) async {
      final startDate = DateTime(2026, 10, 26);
      final dailyTimesController = ValueNotifier<List<DailyOccurrenceTime>>([
        const DailyOccurrenceTime(
          startTime: TimeOfDay(hour: 9, minute: 0),
          dueTime: TimeOfDay(hour: 17, minute: 0),
        ),
      ]);
      final intervalController = TextEditingController(text: '1');

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: DailySchedulingWidget(
                startDate: startDate,
                onStartDateChanged: (_) {},
                dailyTimesController: dailyTimesController,
                intervalController: intervalController,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Daily Occurrences'), findsOneWidget);
      expect(find.text('Start Time'), findsOneWidget);
      expect(find.text('Due Time'), findsOneWidget);
      expect(find.byType(DailyTimeListWidget), findsOneWidget);
      expect(find.text('Start Date'), findsOneWidget);
      expect(find.text('2026-10-26'), findsOneWidget);
      expect(find.text('Days Interval'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('calls onStartDateChanged when date is picked', (tester) async {
      DateTime startDate = DateTime(2026, 10, 26);
      DateTime? newDate;

      final dailyTimesController = ValueNotifier<List<DailyOccurrenceTime>>([
        const DailyOccurrenceTime(
          startTime: TimeOfDay(hour: 9, minute: 0),
          dueTime: TimeOfDay(hour: 17, minute: 0),
        ),
      ]);
      final intervalController = TextEditingController(text: '1');
      final robot = DailySchedulingWidgetRobot(tester);

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: DailySchedulingWidget(
                startDate: startDate,
                onStartDateChanged: (date) {
                  newDate = date;
                },
                dailyTimesController: dailyTimesController,
                intervalController: intervalController,
              ),
            ),
          ),
        ),
      );

      await robot.pickStartDate('27');

      expect(newDate, DateTime(2026, 10, 27));
    });

    testGoldens('DailySchedulingWidget renders correctly', (tester) async {
      final startDate = DateTime(2026, 10, 26);
      final dailyTimesController = ValueNotifier<List<DailyOccurrenceTime>>([
        const DailyOccurrenceTime(
          startTime: TimeOfDay(hour: 9, minute: 0),
          dueTime: TimeOfDay(hour: 17, minute: 0),
        ),
      ]);
      final intervalController = TextEditingController(text: '1');

      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 1.1)
        ..addScenario(
          'Default',
          DailySchedulingWidget(
            startDate: startDate,
            onStartDateChanged: (_) {},
            dailyTimesController: dailyTimesController,
            intervalController: intervalController,
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(800, 1000),
      );
      await screenMatchesGolden(tester, 'daily_scheduling_widget');
    });
  });
}
