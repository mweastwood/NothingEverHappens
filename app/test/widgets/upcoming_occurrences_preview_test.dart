import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/task.dart';
import 'package:nothing_ever_happens/widgets/upcoming_occurrences_preview.dart';
import '../test_helper.dart';

void main() {
  group('UpcomingOccurrencesPreview', () {
    testWidgets('renders placeholder when schedule is null', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: UpcomingOccurrencesPreview(
              schedule: null,
              dailyTimes: const [],
              startDateTime: DateTime(2026, 6, 8, 9, 0),
              dueDateTime: DateTime(2026, 6, 8, 17, 0),
              scheduleType: RecurrenceType.daily,
            ),
          ),
        ),
      );

      expect(
        find.text(
          'No future occurrences scheduled. Ensure all inputs are valid.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders occurrences for One-Off task', (tester) async {
      final schedule = OneOffSchedule(
        date: const CivilDay(year: 2026, month: 6, day: 8),
      );

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: UpcomingOccurrencesPreview(
              schedule: schedule,
              dailyTimes: const [
                DailyOccurrenceTime(
                  startTime: TimeOfDay(hour: 9, minute: 0),
                  dueTime: TimeOfDay(hour: 17, minute: 0),
                ),
              ],
              startDateTime: DateTime(2026, 6, 8, 9, 0),
              dueDateTime: DateTime(2026, 6, 8, 17, 0),
              scheduleType: RecurrenceType.oneOff,
            ),
          ),
        ),
      );

      // Should show the title and 1 occurrence card
      expect(find.text('Next 10 Occurrences'), findsOneWidget);
      expect(find.byKey(const Key('occurrence_card_0')), findsOneWidget);
      expect(find.byKey(const Key('occurrence_card_1')), findsNothing);
    });

    testWidgets('renders 10 occurrences for Daily task', (tester) async {
      final schedule = DailySchedule(
        startDate: const CivilDay(year: 2026, month: 6, day: 8),
        interval: 2,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: UpcomingOccurrencesPreview(
                schedule: schedule,
                dailyTimes: const [
                  DailyOccurrenceTime(
                    startTime: TimeOfDay(hour: 9, minute: 0),
                    dueTime: TimeOfDay(hour: 17, minute: 0),
                  ),
                ],
                startDateTime: DateTime(2026, 6, 8, 9, 0),
                dueDateTime: DateTime(2026, 6, 8, 17, 0),
                scheduleType: RecurrenceType.daily,
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('occurrence_card_0')), findsOneWidget);
      expect(find.byKey(const Key('occurrence_card_9')), findsOneWidget);
      expect(find.byKey(const Key('occurrence_card_10')), findsNothing);
    });

    testGoldens('UpcomingOccurrencesPreview renders correctly', (tester) async {
      final oneOffSchedule = OneOffSchedule(
        date: const CivilDay(year: 2026, month: 6, day: 8),
      );
      final dailySchedule = DailySchedule(
        startDate: const CivilDay(year: 2026, month: 6, day: 8),
        interval: 1,
      );

      final builder = GoldenBuilder.column()
        ..addScenario(
          'Null Schedule Placeholder',
          SizedBox(
            height: 60,
            child: UpcomingOccurrencesPreview(
              schedule: null,
              dailyTimes: const [],
              startDateTime: DateTime(2026, 6, 8, 9, 0),
              dueDateTime: DateTime(2026, 6, 8, 17, 0),
              scheduleType: RecurrenceType.daily,
            ),
          ),
        )
        ..addScenario(
          'One-Off Preview',
          SizedBox(
            height: 140,
            child: UpcomingOccurrencesPreview(
              schedule: oneOffSchedule,
              dailyTimes: const [
                DailyOccurrenceTime(
                  startTime: TimeOfDay(hour: 9, minute: 0),
                  dueTime: TimeOfDay(hour: 17, minute: 0),
                ),
              ],
              startDateTime: DateTime(2026, 6, 8, 9, 0),
              dueDateTime: DateTime(2026, 6, 8, 17, 0),
              scheduleType: RecurrenceType.oneOff,
            ),
          ),
        )
        ..addScenario(
          'Daily Preview',
          SizedBox(
            height: 140,
            child: UpcomingOccurrencesPreview(
              schedule: dailySchedule,
              dailyTimes: const [
                DailyOccurrenceTime(
                  startTime: TimeOfDay(hour: 9, minute: 0),
                  dueTime: TimeOfDay(hour: 17, minute: 0),
                ),
              ],
              startDateTime: DateTime(2026, 6, 8, 9, 0),
              dueDateTime: DateTime(2026, 6, 8, 17, 0),
              scheduleType: RecurrenceType.daily,
              maxOccurrences: 1, // limit to 1 to fit layout comfortably
            ),
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
      );

      await screenMatchesGolden(tester, 'upcoming_occurrences_preview_golden');
    });
  });
}
