import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:nothing_ever_happens/logic/task.dart';
import 'package:nothing_ever_happens/widgets/daily_time_list_widget.dart';

void main() {
  group('DailyTimeListWidget Goldens', () {
    testGoldens('renders single slot vs multiple slots correctly', (
      tester,
    ) async {
      final singleSlotController = ValueNotifier<List<DailyOccurrenceTime>>([
        const DailyOccurrenceTime(
          startTime: TimeOfDay(hour: 9, minute: 0),
          dueTime: TimeOfDay(hour: 17, minute: 0),
        ),
      ]);

      final multipleSlotsController = ValueNotifier<List<DailyOccurrenceTime>>([
        const DailyOccurrenceTime(
          startTime: TimeOfDay(hour: 8, minute: 0),
          dueTime: TimeOfDay(hour: 9, minute: 0),
        ),
        const DailyOccurrenceTime(
          startTime: TimeOfDay(hour: 14, minute: 0),
          dueTime: TimeOfDay(hour: 15, minute: 0),
        ),
        const DailyOccurrenceTime(
          startTime: TimeOfDay(hour: 20, minute: 0),
          dueTime: TimeOfDay(hour: 21, minute: 0),
        ),
      ]);

      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 0.5)
        ..addScenario(
          'Single Slot (No Delete Button)',
          DailyTimeListWidget(controller: singleSlotController),
        )
        ..addScenario(
          'Multiple Slots (With Delete Buttons)',
          DailyTimeListWidget(controller: multipleSlotsController),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: materialAppWrapper(),
        surfaceSize: const Size(800, 1000),
      );
      await screenMatchesGolden(tester, 'daily_time_list_widget_scenarios');
    });
  });
}
