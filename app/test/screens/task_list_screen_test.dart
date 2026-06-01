import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import '../test_helper.dart';

import 'package:mockito/annotations.dart';
import 'package:nothing_ever_happens/logic/auth_repository.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/screens/home_screen.dart';
import 'package:nothing_ever_happens/logic/task.dart';
import 'package:nothing_ever_happens/logic/task_delta.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/main.dart';
import 'package:nothing_ever_happens/widgets/dev_clock_widget.dart';
import '../widgets/task_widget_robot.dart';

@GenerateNiceMocks([MockSpec<AuthRepository>(), MockSpec<TaskRepository>()])
import 'task_list_screen_test.mocks.dart';

void main() {
  late MockAuthRepository mockAuthRepository;
  late MockTaskRepository mockTaskRepository;
  late BehaviorSubject<List<Task>> tasksSubject;
  late BehaviorSubject<List<TaskDelta>> historySubject;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    mockTaskRepository = MockTaskRepository();

    // Initial task list
    final initialTasks = [
      Task(
        id: '1',
        title: 'Mock Task',
        description: 'Mock Description',
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
      ),
    ];
    tasksSubject = BehaviorSubject<List<Task>>.seeded(initialTasks);
    historySubject = BehaviorSubject<List<TaskDelta>>.seeded([]);

    // Default stubbing
    when(mockAuthRepository.signOut()).thenAnswer((_) async {});
    when(mockTaskRepository.getTasks()).thenAnswer((_) => tasksSubject.stream);
    when(
      mockTaskRepository.getHistory(),
    ).thenAnswer((_) => historySubject.stream);

    when(mockTaskRepository.addTask(any)).thenAnswer((invocation) async {
      final task = invocation.positionalArguments.first as Task;
      final currentTasks = tasksSubject.value;
      tasksSubject.add([...currentTasks, task]);
    });
  });

  tearDown(() {
    tasksSubject.close();
    historySubject.close();
  });

  Widget createScreen() {
    return MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: mockAuthRepository),
        Provider<TaskRepository>.value(value: mockTaskRepository),
      ],
      child: buildTestableWidget(child: const HomeScreen()),
    );
  }

  testWidgets('Task list renders with CustomScrollView', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createScreen());
    await tester.pumpAndSettle();

    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.text('Mock Task'), findsOneWidget);
  });

  testWidgets('Task list shows FAB and navigates to CreateTaskScreen', (
    WidgetTester tester,
  ) async {
    AppConfig.environment = AppEnvironment
        .prod; // Hide dev clock banner/bottom sheet from blocking hits
    AppClock.setMockTime(DateTime(2026, 3, 8, 9, 0));

    await tester.pumpWidget(createScreen());
    await tester.pumpAndSettle();

    // Verify FAB exists
    expect(find.byType(FloatingActionButton), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Verify we are on the CreateTaskScreen
    expect(find.text('New Task'), findsOneWidget);

    // Simulate creating a task
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'New Task Title',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Description'),
      'New Task Description',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // The newly created task defaults to tomorrow (March 9).
    // Advance the mock clock to March 9 so it passes the scheduledDate <= today filter on TaskListScreen!
    AppClock.setMockTime(DateTime(2026, 3, 9, 9, 0));
    await tester.pumpAndSettle();

    expect(find.text('New Task Title'), findsOneWidget);

    AppClock.reset();
    AppConfig.environment = AppEnvironment.dev; // Restore dev env
  });

  testWidgets('Task list mobile layout (ListView)', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createScreen());
    await tester.pumpAndSettle(); // Wait for stream

    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.text('Mock Task'), findsOneWidget);
  });

  testWidgets('Task list desktop layout', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createScreen());
    await tester.pumpAndSettle(); // Wait for stream

    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.text('Mock Task'), findsOneWidget);
  });

  testWidgets('Task list has drawer with logout button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createScreen());
    await tester.pumpAndSettle();

    // Find the hamburger menu (Scaffold drawer)
    // Initially the drawer is closed, so we don't see 'Logout' yet.
    expect(find.text('Logout'), findsNothing);

    // Open the drawer
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    // Verify drawer content
    expect(find.text('Menu'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);

    // Tap logout
    await tester.tap(find.text('Logout'));
    await tester.pump();

    // Verify signOut was called
    verify(mockAuthRepository.signOut()).called(1);
  });

  testWidgets('Tapping checkbox completes the task', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createScreen());
    await tester.pumpAndSettle();

    final robot = TaskWidgetRobot(tester);

    // Verify task is present
    await robot.expectTitle('Mock Task');

    // Tap the checkbox
    await robot.tapCheckbox();

    // Verify completeTask was NOT called immediately
    verifyNever(mockTaskRepository.completeTask('1'));

    await robot.waitForCompletion();

    // Verify completeTask was called
    verify(mockTaskRepository.completeTask('1')).called(1);
  });

  testWidgets(
    'Completing a recurring task advances its schedule and does not reappear on screen',
    (WidgetTester tester) async {
      AppClock.setMockTime(DateTime(2026, 3, 8, 9, 0));

      final recurringTask = Task(
        id: 'recur-1',
        title: 'Daily Repeating Task',
        description: 'Do daily',
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        schedule: DailySchedule(
          startDate: const CivilDay(year: 2026, month: 3, day: 8),
          interval: 1,
        ),
      );

      tasksSubject.add([recurringTask]);

      when(mockTaskRepository.completeTask('recur-1')).thenAnswer((_) async {
        final advancedTask = Task(
          id: 'recur-1',
          title: 'Daily Repeating Task',
          description: 'Do daily',
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          schedule: DailySchedule(
            startDate: const CivilDay(year: 2026, month: 3, day: 9),
            interval: 1,
          ),
        );
        tasksSubject.add([advancedTask]);
      });

      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      final robot = TaskWidgetRobot.fromTitle(tester, 'Daily Repeating Task');
      robot.expectVisible();

      await robot.tapCheckbox();
      await robot.waitForCompletion();

      await tester.pumpAndSettle();

      robot.expectGone();

      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();
      robot.expectGone();

      AppClock.reset();
    },
  );

  testWidgets('Task list screen filters out tasks scheduled in the future', (
    WidgetTester tester,
  ) async {
    AppClock.setMockTime(DateTime(2026, 3, 8, 9, 0));

    final todayTask = Task(
      id: 'today-task',
      title: 'Today Task',
      description: 'Due today',
      startRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 9, minute: 0),
      ),
      dueRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 17, minute: 0),
      ),
      schedule: OneOffSchedule(
        date: const CivilDay(year: 2026, month: 3, day: 8),
      ),
    );

    final tomorrowTask = Task(
      id: 'tomorrow-task',
      title: 'Tomorrow Task',
      description: 'Due tomorrow',
      startRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 9, minute: 0),
      ),
      dueRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 17, minute: 0),
      ),
      schedule: OneOffSchedule(
        date: const CivilDay(year: 2026, month: 3, day: 9),
      ),
    );

    tasksSubject.add([todayTask, tomorrowTask]);

    await tester.pumpWidget(createScreen());
    await tester.pumpAndSettle();

    // Today's task should be shown
    expect(find.text('Today Task'), findsOneWidget);

    // Tomorrow's task should be filtered out
    expect(find.text('Tomorrow Task'), findsNothing);

    AppClock.reset();
  });

  testWidgets(
    'Completing a task does not affect the next task state (bug repro)',
    (WidgetTester tester) async {
      // Setup 2 tasks
      final task1 = Task(
        id: '1',
        title: 'Task 1',
        description: 'Desc 1',
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
      final task2 = Task(
        id: '2',
        title: 'Task 2',
        description: 'Desc 2',
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

      tasksSubject.add([task1, task2]);

      // Simulate deletion when completeTask is called
      when(mockTaskRepository.completeTask('1')).thenAnswer((_) async {
        tasksSubject.add([task2]); // Remove task 1
      });

      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      final robot1 = TaskWidgetRobot.fromTitle(tester, 'Task 1');
      final robot2 = TaskWidgetRobot.fromTitle(tester, 'Task 2');

      robot1.expectVisible();
      robot2.expectVisible();

      // Tap Task 1
      await robot1.tapCheckbox();

      await robot1.waitForCompletion();
      // Pump again to process the stream update and rebuild UI
      await tester.pump();

      // Verify completeTask was called
      verify(mockTaskRepository.completeTask('1')).called(1);

      // Verify Task 1 is gone (due to stream update)
      robot1.expectGone();

      // Verify Task 2 is visible
      robot2.expectVisible();

      // Check if Task 2 is inadvertently checked (state reuse bug)
      await robot2.expectChecked(false);
    },
  );

  testGoldens('TaskListScreen history scrolling', (tester) async {
    final mockAuthRepository = MockAuthRepository();
    final mockTaskRepository = MockTaskRepository();

    when(mockAuthRepository.signOut()).thenAnswer((_) async {});
    when(mockTaskRepository.getTasks()).thenAnswer(
      (_) => Stream.value([
        Task(
          id: '1',
          title: 'Current Task',
          description: 'Do this now',
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
        ),
      ]),
    );

    // Create some history items
    final historyItems = List.generate(3, (index) {
      return TaskDelta(
        id: 'delta-$index',
        taskId: 'task-$index',
        timestamp: DateTime(2023, 10, 26, 12, index, 0),
        expiresAt: DateTime(2023, 10, 27, 12, index, 0),
        operation: 'update',
        changedFields: {'status': 'modified $index'},
        userId: 'user-1',
      );
    });

    when(
      mockTaskRepository.getHistory(),
    ).thenAnswer((_) => Stream.value(historyItems));

    await tester.pumpWidgetBuilder(
      MultiProvider(
        providers: [
          Provider<AuthRepository>.value(value: mockAuthRepository),
          Provider<TaskRepository>.value(value: mockTaskRepository),
        ],
        child: const HomeScreen(),
      ),
      wrapper: l10nMaterialAppWrapper(),
      surfaceSize: const Size(400, 800),
    );

    // Initial state: we see the current task
    await screenMatchesGolden(tester, 'task_list_screen_initial');

    // Tap history navigation tab to navigate to history
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    await screenMatchesGolden(tester, 'task_list_screen_history');
  });

  testGoldens('TaskListScreen - Prod Mode (No Dev Clock Button)', (
    tester,
  ) async {
    // 1. Set environment to prod
    AppConfig.environment = AppEnvironment.prod;

    final mockAuthRepository = MockAuthRepository();
    final mockTaskRepository = MockTaskRepository();

    when(mockAuthRepository.signOut()).thenAnswer((_) async {});
    when(mockTaskRepository.getTasks()).thenAnswer((_) => Stream.value([]));
    when(mockTaskRepository.getHistory()).thenAnswer((_) => Stream.value([]));

    await tester.pumpWidgetBuilder(
      MultiProvider(
        providers: [
          Provider<AuthRepository>.value(value: mockAuthRepository),
          Provider<TaskRepository>.value(value: mockTaskRepository),
        ],
        child: const HomeScreen(),
      ),
      wrapper: l10nMaterialAppWrapper(),
      surfaceSize: const Size(400, 800),
    );

    // Verify that the dev clock button is NOT displayed (only one widget tree item but shrunk to SizedBox)
    expect(find.byType(DevClockWidget), findsOneWidget);
    expect(find.byIcon(Icons.av_timer), findsNothing);

    await screenMatchesGolden(tester, 'task_list_screen_prod');

    // Reset back to dev environment for other tests
    AppConfig.environment = AppEnvironment.dev;
  });
}
