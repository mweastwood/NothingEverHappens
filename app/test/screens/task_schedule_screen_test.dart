import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:mockito/mockito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import '../test_helper.dart';

import 'package:nothing_ever_happens/logic/auth_repository.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/screens/task_schedule_screen.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';

import 'task_list_screen_test.mocks.dart';

void main() {
  late MockAuthRepository mockAuthRepository;
  late MockTaskRepository mockTaskRepository;
  late BehaviorSubject<List<TaskSchedule>> tasksSubject;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    mockTaskRepository = MockTaskRepository();

    tasksSubject = BehaviorSubject<List<TaskSchedule>>.seeded([]);

    when(mockTaskRepository.getTasks()).thenAnswer((_) => tasksSubject.stream);
  });

  tearDown(() {
    tasksSubject.close();
  });

  Widget createScreen() {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepository),
        taskRepositoryProvider.overrideWithValue(mockTaskRepository),
      ],
      child: buildTestableWidget(
        child: const Scaffold(body: TaskScheduleScreen()),
      ),
    );
  }

  testWidgets('TaskScheduleScreen renders empty state when no tasks', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createScreen());
    await tester.pumpAndSettle();

    expect(find.text('No recurring tasks scheduled'), findsOneWidget);
  });

  testWidgets('TaskScheduleScreen renders list of recurring tasks', (
    WidgetTester tester,
  ) async {
    final dailyTask = TaskSchedule(
      id: '1',
      title: 'Daily TaskSchedule Title',
      description: 'Daily TaskSchedule Desc',
      schedules: [
        DailySchedule(
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
      id: '2',
      title: 'Weekly TaskSchedule Title',
      description: 'Weekly TaskSchedule Desc',
      schedules: [
        WeeklySchedule(
          startDate: const CivilDay(year: 2024, month: 1, day: 1),
          interval: 1,
          daysOfWeek: const {1, 3},
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

    final oneOffTask = TaskSchedule(
      id: '3',
      title: 'One-off TaskSchedule',
      description: 'Should not appear',
      schedules: [
        OneOffSchedule(
          date: const CivilDay(year: 2024, month: 1, day: 1),
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

    tasksSubject.add([dailyTask, weeklyTask, oneOffTask]);

    await tester.pumpWidget(createScreen());
    await tester.pumpAndSettle();

    // Verify recurring tasks are rendered
    expect(find.text('Daily TaskSchedule Title'), findsOneWidget);
    expect(find.text('Weekly TaskSchedule Title'), findsOneWidget);

    // Verify one-off task is NOT rendered
    expect(find.text('One-off TaskSchedule'), findsNothing);

    // Verify schedule formatting details
    expect(find.text('Every 2 days'), findsOneWidget);
    expect(find.text('Every week'), findsOneWidget);
    expect(find.text('On: Mon, Wed'), findsOneWidget);
    expect(find.text('Starting: 2024-01-01'), findsNWidgets(2));

    // Verify times are formatted
    expect(find.text('9:00 AM - 5:00 PM'), findsOneWidget);
    expect(find.text('10:30 AM - 12:00 PM'), findsOneWidget);
  });

  testGoldens('TaskScheduleScreen empty state golden', (tester) async {
    final mockAuthRepository = MockAuthRepository();
    final mockTaskRepository = MockTaskRepository();

    when(mockTaskRepository.getTasks()).thenAnswer((_) => Stream.value([]));

    await tester.pumpWidgetBuilder(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          taskRepositoryProvider.overrideWithValue(mockTaskRepository),
        ],
        child: const Scaffold(body: TaskScheduleScreen()),
      ),
      wrapper: l10nMaterialAppWrapper(),
      surfaceSize: const Size(400, 800),
    );

    await screenMatchesGolden(tester, 'task_schedule_screen_empty');
  });

  testGoldens('TaskScheduleScreen populated state golden', (tester) async {
    final mockAuthRepository = MockAuthRepository();
    final mockTaskRepository = MockTaskRepository();

    final dailyTask = TaskSchedule(
      id: '1',
      title: 'Daily Exercises',
      description: 'Run 5km and do pushups',
      schedules: [
        DailySchedule(
          startDate: const CivilDay(year: 2024, month: 1, day: 1),
          interval: 1,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 7, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 8, minute: 30),
          ),
        ),
      ],
    );

    final weeklyTask = TaskSchedule(
      id: '2',
      title: 'Weekly Cleaning',
      description: 'Vacuum the house and dust the shelves',
      schedules: [
        WeeklySchedule(
          startDate: const CivilDay(year: 2024, month: 1, day: 1),
          interval: 1,
          daysOfWeek: const {6, 7},
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 10, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 12, minute: 0),
          ),
        ),
      ],
    );

    when(
      mockTaskRepository.getTasks(),
    ).thenAnswer((_) => Stream.value([dailyTask, weeklyTask]));

    await tester.pumpWidgetBuilder(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          taskRepositoryProvider.overrideWithValue(mockTaskRepository),
        ],
        child: const Scaffold(body: TaskScheduleScreen()),
      ),
      wrapper: l10nMaterialAppWrapper(),
      surfaceSize: const Size(400, 800),
    );

    await screenMatchesGolden(tester, 'task_schedule_screen_populated');
  });

  testWidgets(
    'TaskScheduleScreen delete button opens confirmation dialog and deletes task',
    (WidgetTester tester) async {
      final dailyTask = TaskSchedule(
        id: 'delete-recurring-task-1',
        title: 'Daily Exercises',
        description: 'Run 5km and do pushups',
        schedules: [
          DailySchedule(
            startDate: const CivilDay(year: 2024, month: 1, day: 1),
            interval: 1,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 7, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 8, minute: 30),
            ),
          ),
        ],
      );

      tasksSubject.add([dailyTask]);

      when(
        mockTaskRepository.deleteTaskSchedule('delete-recurring-task-1'),
      ).thenAnswer(
        (_) async => (task: dailyTask, pendingInstances: <TaskInstance>[]),
      );

      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      // Verify Delete Schedule Button is rendered
      final deleteButtonKey = const Key(
        'delete_schedule_button_delete-recurring-task-1',
      );
      expect(find.byKey(deleteButtonKey), findsOneWidget);

      // Tap Delete button
      await tester.tap(find.byKey(deleteButtonKey));
      await tester.pumpAndSettle();

      // Verify confirmation dialog is displayed
      expect(find.text('Delete Task?'), findsOneWidget);
      expect(
        find.text(
          'Are you sure you want to delete "Daily Exercises"? This action will permanently remove the task.',
        ),
        findsOneWidget,
      );

      // Tap confirm delete button in dialog
      final confirmDeleteKey = const Key(
        'confirm_delete_schedule_button_delete-recurring-task-1',
      );
      await tester.tap(find.byKey(confirmDeleteKey));
      await tester.pumpAndSettle();

      // Verify repository delete method was called with correct ID
      verify(
        mockTaskRepository.deleteTaskSchedule('delete-recurring-task-1'),
      ).called(1);
    },
  );

  testWidgets(
    'TaskScheduleScreen delete button opens confirmation dialog, deletes task, and undo restores it',
    (WidgetTester tester) async {
      final dailyTask = TaskSchedule(
        id: 'delete-recurring-task-1',
        title: 'Daily Exercises',
        description: 'Run 5km and do pushups',
        schedules: [
          DailySchedule(
            startDate: const CivilDay(year: 2024, month: 1, day: 1),
            interval: 1,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 7, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 8, minute: 30),
            ),
          ),
        ],
      );

      tasksSubject.add([dailyTask]);

      when(
        mockTaskRepository.deleteTaskSchedule('delete-recurring-task-1'),
      ).thenAnswer(
        (_) async => (task: dailyTask, pendingInstances: <TaskInstance>[]),
      );
      when(
        mockTaskRepository.restoreTaskSchedule(any, any),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      final deleteButtonKey = const Key(
        'delete_schedule_button_delete-recurring-task-1',
      );
      await tester.tap(find.byKey(deleteButtonKey));
      await tester.pumpAndSettle();

      final confirmDeleteKey = const Key(
        'confirm_delete_schedule_button_delete-recurring-task-1',
      );
      await tester.tap(find.byKey(confirmDeleteKey));
      await tester.pumpAndSettle();

      verify(
        mockTaskRepository.deleteTaskSchedule('delete-recurring-task-1'),
      ).called(1);

      // Verify SnackBar is shown
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      // Tap Undo
      await tester.tap(find.text('Undo'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify restoreTaskSchedule is called
      verify(mockTaskRepository.restoreTaskSchedule(dailyTask, any)).called(1);
    },
  );
}
