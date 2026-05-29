import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import '../test_helper.dart';

import 'package:nothing_ever_happens/logic/auth_repository.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/screens/task_schedule_screen.dart';
import 'package:nothing_ever_happens/logic/task.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';

import 'task_list_screen_test.mocks.dart';

void main() {
  late MockAuthRepository mockAuthRepository;
  late MockTaskRepository mockTaskRepository;
  late BehaviorSubject<List<Task>> tasksSubject;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    mockTaskRepository = MockTaskRepository();

    tasksSubject = BehaviorSubject<List<Task>>.seeded([]);

    when(mockTaskRepository.getTasks()).thenAnswer((_) => tasksSubject.stream);
  });

  tearDown(() {
    tasksSubject.close();
  });

  Widget createScreen() {
    return MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: mockAuthRepository),
        Provider<TaskRepository>.value(value: mockTaskRepository),
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

    final oneOffTask = Task(
      id: '3',
      title: 'One-off Task',
      description: 'Should not appear',
      startRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 9, minute: 0),
      ),
      dueRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 17, minute: 0),
      ),
      schedule: OneOffSchedule(
        date: const CivilDay(year: 2024, month: 1, day: 1),
      ),
    );

    tasksSubject.add([dailyTask, weeklyTask, oneOffTask]);

    await tester.pumpWidget(createScreen());
    await tester.pumpAndSettle();

    // Verify recurring tasks are rendered
    expect(find.text('Daily Task Title'), findsOneWidget);
    expect(find.text('Weekly Task Title'), findsOneWidget);

    // Verify one-off task is NOT rendered
    expect(find.text('One-off Task'), findsNothing);

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
      MultiProvider(
        providers: [
          Provider<AuthRepository>.value(value: mockAuthRepository),
          Provider<TaskRepository>.value(value: mockTaskRepository),
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

    final dailyTask = Task(
      id: '1',
      title: 'Daily Exercises',
      description: 'Run 5km and do pushups',
      startRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 7, minute: 0),
      ),
      dueRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 8, minute: 30),
      ),
      schedule: DailySchedule(
        startDate: const CivilDay(year: 2024, month: 1, day: 1),
        interval: 1,
      ),
    );

    final weeklyTask = Task(
      id: '2',
      title: 'Weekly Cleaning',
      description: 'Vacuum the house and dust the shelves',
      startRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 10, minute: 0),
      ),
      dueRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 12, minute: 0),
      ),
      schedule: WeeklySchedule(
        startDate: const CivilDay(year: 2024, month: 1, day: 1),
        interval: 1,
        daysOfWeek: {6, 7}, // Sat, Sun
      ),
    );

    when(
      mockTaskRepository.getTasks(),
    ).thenAnswer((_) => Stream.value([dailyTask, weeklyTask]));

    await tester.pumpWidgetBuilder(
      MultiProvider(
        providers: [
          Provider<AuthRepository>.value(value: mockAuthRepository),
          Provider<TaskRepository>.value(value: mockTaskRepository),
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
      final dailyTask = Task(
        id: 'delete-recurring-task-1',
        title: 'Daily Exercises',
        description: 'Run 5km and do pushups',
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 7, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 8, minute: 30),
        ),
        schedule: DailySchedule(
          startDate: const CivilDay(year: 2024, month: 1, day: 1),
          interval: 1,
        ),
      );

      tasksSubject.add([dailyTask]);

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
        mockTaskRepository.deleteTask('delete-recurring-task-1'),
      ).called(1);
    },
  );
}
