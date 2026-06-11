import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/task.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/widgets/schedule_card.dart';
import '../test_helper.dart';

void main() {
  group('ScheduleCard', () {
    final dailyTask = Task(
      id: '1',
      title: 'Daily Task Title',
      description: 'Daily Task Desc',
      startRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 9, minute: 0),
      ),
      dueRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 17, minute: 0),
      ),
      schedule: DailySchedule(
        startDate: const CivilDay(year: 2024, month: 1, day: 1),
        interval: 2,
      ),
    );

    final weeklyTask = Task(
      id: '2',
      title: 'Weekly Task Title',
      description: 'Weekly Task Desc',
      startRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 10, minute: 30),
      ),
      dueRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 12, minute: 0),
      ),
      schedule: WeeklySchedule(
        startDate: const CivilDay(year: 2024, month: 1, day: 1),
        interval: 1,
        daysOfWeek: {1, 3},
      ),
    );

    testWidgets('renders daily task details and triggers actions', (
      tester,
    ) async {
      bool editTapped = false;
      bool deleteTapped = false;

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: ScheduleCard(
                task: dailyTask,
                onEdit: () => editTapped = true,
                onDelete: () => deleteTapped = true,
              ),
            ),
          ),
        ),
      );

      // Verify basic text details
      expect(find.text('Daily Task Title'), findsOneWidget);
      expect(find.text('Daily Task Desc'), findsOneWidget);
      expect(find.text('Every 2 days'), findsOneWidget);
      expect(find.text('Starting: 2024-01-01'), findsOneWidget);
      expect(find.text('9:00 AM - 5:00 PM'), findsOneWidget);

      // Tap edit
      await tester.tap(find.byKey(const Key('edit_schedule_button_1')));
      expect(editTapped, isTrue);

      // Tap delete
      await tester.tap(find.byKey(const Key('delete_schedule_button_1')));
      expect(deleteTapped, isTrue);
    });

    testWidgets('renders weekly task details correctly', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: ScheduleCard(
                task: weeklyTask,
                onEdit: () {},
                onDelete: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Weekly Task Title'), findsOneWidget);
      expect(find.text('Every week'), findsOneWidget);
      expect(find.text('On: Mon, Wed'), findsOneWidget);
      expect(find.text('10:30 AM - 12:00 PM'), findsOneWidget);
    });

    testGoldens(
      'ScheduleCard renders correctly across different schedule types',
      (tester) async {
        final builder = GoldenBuilder.column()
          ..addScenario(
            'Daily Schedule',
            ScheduleCard(task: dailyTask, onEdit: () {}, onDelete: () {}),
          )
          ..addScenario(
            'Weekly Schedule',
            ScheduleCard(task: weeklyTask, onEdit: () {}, onDelete: () {}),
          );

        await tester.pumpWidgetBuilder(
          builder.build(),
          wrapper: l10nMaterialAppWrapper(),
          surfaceSize: const Size(600, 1000),
        );

        await screenMatchesGolden(tester, 'schedule_card_golden');
      },
    );
  });
}
