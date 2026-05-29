import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/task.dart';
import 'package:nothing_ever_happens/widgets/daily_time_list_widget.dart';
import '../test_helper.dart';

void main() {
  group('DailyTimeListWidget Goldens', () {
    testGoldens('renders single slot vs multiple slots correctly', (
      tester,
    ) async {
      final singleSlotController = ValueNotifier<List<DailyOccurrenceTime>>([
        const DailyOccurrenceTime(
          startTime: TimeOfDay(hour: 9, minute: 0),
          dueTime: TimeOfDay(hour: 17, minute: 0),
          notificationTime: null,
        ),
      ]);

      final multipleSlotsController = ValueNotifier<List<DailyOccurrenceTime>>([
        const DailyOccurrenceTime(
          startTime: TimeOfDay(hour: 8, minute: 0),
          dueTime: TimeOfDay(hour: 9, minute: 0),
          notificationTime: null,
        ),
        const DailyOccurrenceTime(
          startTime: TimeOfDay(hour: 14, minute: 0),
          dueTime: TimeOfDay(hour: 15, minute: 0),
          notificationTime: TimeOfDay(hour: 13, minute: 45),
        ),
        const DailyOccurrenceTime(
          startTime: TimeOfDay(hour: 20, minute: 0),
          dueTime: TimeOfDay(hour: 21, minute: 0),
          notificationTime: null,
        ),
      ]);

      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 0.5)
        ..addScenario(
          'Single Slot (No Delete Button, No Custom Notif)',
          DailyTimeListWidget(controller: singleSlotController),
        )
        ..addScenario(
          'Multiple Slots (With Delete Buttons, Mix of Notif)',
          DailyTimeListWidget(controller: multipleSlotsController),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(800, 1600),
      );
      await screenMatchesGolden(tester, 'daily_time_list_widget_scenarios');
    });
  });

  group('DailyTimeListWidget Interactions', () {
    testWidgets('allows setting and clearing notification time', (
      WidgetTester tester,
    ) async {
      final controller = ValueNotifier<List<DailyOccurrenceTime>>([
        const DailyOccurrenceTime(
          startTime: TimeOfDay(hour: 9, minute: 0),
          dueTime: TimeOfDay(hour: 17, minute: 0),
          notificationTime: null,
        ),
      ]);

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(body: DailyTimeListWidget(controller: controller)),
        ),
      );

      // Find "None" button representing unset notification
      final noneFinder = find.widgetWithText(OutlinedButton, 'None');
      expect(noneFinder, findsOneWidget);

      // Tap "None" button to set notification
      await tester.tap(noneFinder);
      await tester.pumpAndSettle();

      // Tap OK on the open time picker (uses initial 9:00 AM)
      final okFinder = find.text('OK');
      if (okFinder.evaluate().isNotEmpty) {
        await tester.tap(okFinder);
        await tester.pumpAndSettle();
      }

      // Notification time should now be set to 9:00 AM
      expect(controller.value.first.notificationTime, isNotNull);

      // Verify clear button exists and tap it
      final clearFinder = find.byIcon(Icons.clear);
      expect(clearFinder, findsOneWidget);

      await tester.tap(clearFinder);
      await tester.pumpAndSettle();

      // Reverts back to null/None
      expect(controller.value.first.notificationTime, isNull);
    });
  });
}
