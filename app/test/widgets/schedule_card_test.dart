import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/widgets/schedule_card.dart';
import '../test_helper.dart';

void main() {
  group('ScheduleCard', () {
    final dailyTask = TaskSchedule(
      id: 'S-1',
      title: 'Daily TaskSchedule Title',
      description: 'Daily TaskSchedule Desc',
      schedules: [
        DailySchedule(
          id: 'R-1',
          scheduleId: 'S-1',
          startDate: const CivilDay(year: 2024, month: 1, day: 1),
          interval: 2,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
        ),
      ],
    );

    final weeklyTask = TaskSchedule(
      id: 'S-2',
      title: 'Weekly TaskSchedule Title',
      description: 'Weekly TaskSchedule Desc',
      schedules: [
        WeeklySchedule(
          id: 'R-2',
          scheduleId: 'S-2',
          startDate: const CivilDay(year: 2024, month: 1, day: 1),
          interval: 1,
          daysOfWeek: {1, 3},
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 10, minute: 30),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 12, minute: 0),
          ),
        ),
      ],
    );

    testWidgets('renders daily task details and triggers actions', (
      tester,
    ) async {
      bool editTapped = false;
      bool deleteTapped = false;

      await tester.pumpWidget(
        ProviderScope(
          child: buildTestableWidget(
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
        ),
      );

      // Verify basic text details
      expect(find.text('Daily TaskSchedule Title'), findsOneWidget);
      expect(find.text('Daily TaskSchedule Desc'), findsOneWidget);
      expect(find.text('Every 2 days'), findsOneWidget);
      expect(find.text('Starting: 2024-01-01'), findsOneWidget);
      expect(find.text('9:00 AM - 5:00 PM'), findsOneWidget);

      // Tap edit
      await tester.tap(find.byKey(const Key('edit_schedule_button_S-1')));
      expect(editTapped, isTrue);

      // Tap delete
      await tester.tap(find.byKey(const Key('delete_schedule_button_S-1')));
      expect(deleteTapped, isTrue);
    });

    testWidgets('renders weekly task details correctly', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: buildTestableWidget(
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
        ),
      );

      expect(find.text('Weekly TaskSchedule Title'), findsOneWidget);
      expect(find.text('Every week'), findsOneWidget);
      expect(find.text('On: Mon, Wed'), findsOneWidget);
      expect(find.text('10:30 AM - 12:00 PM'), findsOneWidget);
    });

    testWidgets(
      'renders copy button when onCopy is provided and triggers action',
      (tester) async {
        bool copyTapped = false;

        await tester.pumpWidget(
          ProviderScope(
            child: buildTestableWidget(
              child: Scaffold(
                body: SingleChildScrollView(
                  child: ScheduleCard(
                    task: dailyTask,
                    onEdit: () {},
                    onDelete: () {},
                    onCopy: () => copyTapped = true,
                  ),
                ),
              ),
            ),
          ),
        );

        final copyButton = find.byKey(const Key('copy_schedule_button_S-1'));
        expect(copyButton, findsOneWidget);

        final iconButton = tester.widget<IconButton>(copyButton);
        expect(iconButton.tooltip, 'Copy Schedule');

        await tester.tap(copyButton);
        expect(copyTapped, isTrue);
      },
    );

    testWidgets('does not render copy button when onCopy is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: buildTestableWidget(
            child: Scaffold(
              body: SingleChildScrollView(
                child: ScheduleCard(
                  task: dailyTask,
                  onEdit: () {},
                  onDelete: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('copy_schedule_button_S-1')), findsNothing);
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
          wrapper: (child) =>
              ProviderScope(child: l10nMaterialAppWrapper()(child)),
          surfaceSize: const Size(600, 1000),
        );

        await screenMatchesGolden(tester, 'schedule_card_golden');
      },
    );
  });
}
