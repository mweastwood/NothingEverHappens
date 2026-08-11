import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:mockito/mockito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import '../test_helper.dart';

import 'package:mockito/annotations.dart';
import 'package:nothing_ever_happens/logic/auth_repository.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/screens/home_screen.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/main.dart';
import 'package:nothing_ever_happens/logic/user_settings.dart';
import 'package:nothing_ever_happens/logic/user_settings_repository.dart';
import 'package:nothing_ever_happens/widgets/task_widget.dart';
import '../widgets/task_widget_robot.dart';

@GenerateNiceMocks([MockSpec<AuthRepository>(), MockSpec<TaskRepository>()])
import 'task_list_screen_test.mocks.dart';
import 'home_screen_test.mocks.dart' as home_mocks;

void main() {
  late MockAuthRepository mockAuthRepository;
  late MockTaskRepository mockTaskRepository;
  late BehaviorSubject<List<TaskSchedule>> tasksSubject;
  late BehaviorSubject<List<TaskInstance>> instancesSubject;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    mockTaskRepository = MockTaskRepository();

    // Initial task list
    final initialTasks = [
      TaskSchedule(
        id: '1',
        title: 'Mock TaskSchedule',
        description: 'Mock Description',
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
      ),
    ];
    final initialInstances = [
      TaskInstance(
        id: 'I-1_2024-01-01',
        scheduleId: '1',
        ruleId: initialTasks[0].schedules[0].id,
        title: 'Mock TaskSchedule',
        description: 'Mock Description',
        scheduledDate: const CivilDay(year: 2024, month: 1, day: 1),
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        status: 'pending',
      ),
    ];
    tasksSubject = BehaviorSubject<List<TaskSchedule>>(sync: true)
      ..add(initialTasks);
    instancesSubject = BehaviorSubject<List<TaskInstance>>(sync: true)
      ..add(initialInstances);

    // Default stubbing
    when(mockAuthRepository.signOut()).thenAnswer((_) async {});
    when(mockTaskRepository.getTasks()).thenAnswer((_) => tasksSubject.stream);
    when(
      mockTaskRepository.getInstances(),
    ).thenAnswer((_) => instancesSubject.stream);

    when(mockTaskRepository.addTaskSchedule(any)).thenAnswer((
      invocation,
    ) async {
      final task = invocation.positionalArguments.first as TaskSchedule;
      final currentTasks = tasksSubject.value;
      tasksSubject.add([...currentTasks, task]);

      final currentInstances = instancesSubject.value;
      instancesSubject.add([
        ...currentInstances,
        TaskInstance(
          id: 'I-${task.id}_2026-03-08',
          scheduleId: task.id,
          ruleId: task.schedules.first.id,
          title: task.title,
          description: task.description,
          scheduledDate: const CivilDay(year: 2026, month: 3, day: 8),
          startRelativeTime: task.schedules.first.startRelativeTime,
          dueRelativeTime: task.schedules.first.dueRelativeTime,
          status: 'pending',
        ),
      ]);
    });
  });

  tearDown(() {
    tasksSubject.close();
    instancesSubject.close();
  });

  Widget createScreen() {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepository),
        taskRepositoryProvider.overrideWithValue(mockTaskRepository),
      ],
      child: buildTestableWidget(child: const HomeScreen()),
    );
  }

  testWidgets('TaskSchedule list renders with CustomScrollView', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createScreen());
    await tester.pumpAndSettle();

    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.text('Mock TaskSchedule'), findsOneWidget);
  });

  testWidgets('TaskSchedule list shows FAB and navigates to CreateTaskScreen', (
    WidgetTester tester,
  ) async {
    AppConfig.environment = AppEnvironment
        .prod; // Hide dev clock banner/bottom sheet from blocking hits
    AppClock.setMockTime(DateTime(2026, 3, 8, 9, 0));
    addTearDown(AppClock.reset);

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
      'New TaskSchedule Title',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Description'),
      'New TaskSchedule Description',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // The newly created task defaults to starting today (no snooze).
    // Verify it appears immediately in the task list on March 8!
    expect(find.text('New TaskSchedule Title'), findsOneWidget);

    AppClock.reset();
    AppConfig.environment = AppEnvironment.dev; // Restore dev env
  });

  testWidgets('TaskSchedule list mobile layout (ListView)', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createScreen());
    await tester.pumpAndSettle(); // Wait for stream

    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.text('Mock TaskSchedule'), findsOneWidget);
  });

  testWidgets('TaskSchedule list desktop layout', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createScreen());
    await tester.pumpAndSettle(); // Wait for stream

    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.text('Mock TaskSchedule'), findsOneWidget);
  });

  testWidgets('TaskSchedule list has drawer with logout button', (
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
    await robot.expectTitle('Mock TaskSchedule');

    // Tap the checkbox
    await robot.tapCheckbox();

    // Verify completeTask was NOT called immediately
    verifyNever(mockTaskRepository.completeTaskInstance('I-1_2024-01-01'));

    await robot.waitForCompletion();

    // Verify completeTask was called
    verify(mockTaskRepository.completeTaskInstance('I-1_2024-01-01')).called(1);
  });

  testWidgets(
    'Completing a recurring task advances its schedule and does not reappear on screen',
    (WidgetTester tester) async {
      AppClock.setMockTime(DateTime(2026, 3, 8, 9, 0));
      addTearDown(AppClock.reset);

      final recurringTask = TaskSchedule(
        id: 'recur-1',
        title: 'Daily Repeating TaskSchedule',
        description: 'Do daily',
        schedules: [
          DailySchedule(
            startDate: const CivilDay(year: 2026, month: 3, day: 8),
            interval: 1,
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

      tasksSubject.add([recurringTask]);
      instancesSubject.add([
        TaskInstance(
          id: 'I-recur-1_2026-03-08',
          scheduleId: 'recur-1',
          ruleId: recurringTask.schedules.first.id,
          title: 'Daily Repeating TaskSchedule',
          description: 'Do daily',
          scheduledDate: const CivilDay(year: 2026, month: 3, day: 8),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          status: 'pending',
        ),
      ]);

      when(
        mockTaskRepository.completeTaskInstance('I-recur-1_2026-03-08'),
      ).thenAnswer((_) async {
        final advancedTask = TaskSchedule(
          id: 'recur-1',
          title: 'Daily Repeating TaskSchedule',
          description: 'Do daily',
          schedules: [
            DailySchedule(
              startDate: const CivilDay(year: 2026, month: 3, day: 9),
              interval: 1,
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
        tasksSubject.add([advancedTask]);
        instancesSubject.add([]);
        return null;
      });

      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      final robot = TaskWidgetRobot.fromTitle(
        tester,
        'Daily Repeating TaskSchedule',
      );
      robot.expectVisible();

      await robot.tapCheckbox();
      await robot.waitForCompletion();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      robot.expectGone();

      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();
      robot.expectGone();
    },
  );

  testWidgets(
    'TaskSchedule list screen filters out tasks scheduled in the future',
    (WidgetTester tester) async {
      AppClock.setMockTime(DateTime(2026, 3, 8, 9, 0));
      addTearDown(AppClock.reset);

      final todayTask = TaskSchedule(
        id: 'today-task',
        title: 'Today TaskSchedule',
        description: 'Due today',
        schedules: [
          OneOffSchedule(
            date: const CivilDay(year: 2026, month: 3, day: 8),
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

      final tomorrowTask = TaskSchedule(
        id: 'tomorrow-task',
        title: 'Tomorrow TaskSchedule',
        description: 'Due tomorrow',
        schedules: [
          OneOffSchedule(
            date: const CivilDay(year: 2026, month: 3, day: 9),
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

      tasksSubject.add([todayTask, tomorrowTask]);
      instancesSubject.add([
        TaskInstance(
          id: 'I-today-task_2026-03-08',
          scheduleId: 'today-task',
          ruleId: todayTask.schedules.first.id,
          title: 'Today TaskSchedule',
          description: 'Due today',
          scheduledDate: const CivilDay(year: 2026, month: 3, day: 8),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          status: 'pending',
        ),
        TaskInstance(
          id: 'I-tomorrow-task_2026-03-09',
          scheduleId: 'tomorrow-task',
          ruleId: tomorrowTask.schedules.first.id,
          title: 'Tomorrow TaskSchedule',
          description: 'Due tomorrow',
          scheduledDate: const CivilDay(year: 2026, month: 3, day: 9),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          status: 'pending',
        ),
      ]);

      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      // Today's task should be shown
      expect(find.text('Today TaskSchedule'), findsOneWidget);

      // Tomorrow's task should be filtered out
      expect(find.text('Tomorrow TaskSchedule'), findsNothing);
    },
  );

  testWidgets(
    'TaskSchedule list screen shows one-off tasks starting today but due in the future',
    (WidgetTester tester) async {
      AppClock.setMockTime(DateTime(2026, 3, 8, 9, 0));
      addTearDown(AppClock.reset);

      final activeOneOffTask = TaskSchedule(
        id: 'active-one-off',
        title: 'Active One-Off',
        description: 'Starts today, due tomorrow',
        schedules: [
          OneOffSchedule(
            date: const CivilDay(year: 2026, month: 3, day: 9),
            startRelativeTime: const RelativeTime(
              dayOffset: -1,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
          ),
        ],
      );

      tasksSubject.add([activeOneOffTask]);
      instancesSubject.add([
        TaskInstance(
          id: 'I-active-one-off_2026-03-09',
          scheduleId: 'active-one-off',
          ruleId: activeOneOffTask.schedules.first.id,
          title: 'Active One-Off',
          description: 'Starts today, due tomorrow',
          scheduledDate: const CivilDay(year: 2026, month: 3, day: 9),
          startRelativeTime: const RelativeTime(
            dayOffset: -1,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          status: 'pending',
        ),
      ]);

      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      // Since it starts today (March 8), it should be shown
      expect(find.text('Active One-Off'), findsOneWidget);
    },
  );

  testWidgets(
    'TaskSchedule list screen hides one-off tasks due today but snoozed/starting in the future',
    (WidgetTester tester) async {
      AppClock.setMockTime(DateTime(2026, 3, 8, 9, 0));
      addTearDown(AppClock.reset);

      final snoozedOneOffTask = TaskSchedule(
        id: 'snoozed-one-off',
        title: 'Snoozed One-Off',
        description: 'Due today, starts tomorrow (snoozed)',
        schedules: [
          OneOffSchedule(
            date: const CivilDay(year: 2026, month: 3, day: 8),
            startRelativeTime: const RelativeTime(
              dayOffset: 1,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
          ),
        ],
      );

      tasksSubject.add([snoozedOneOffTask]);
      instancesSubject.add([
        TaskInstance(
          id: 'I-snoozed-one-off_2026-03-08',
          scheduleId: 'snoozed-one-off',
          ruleId: snoozedOneOffTask.schedules.first.id,
          title: 'Snoozed One-Off',
          description: 'Due today, starts tomorrow (snoozed)',
          scheduledDate: const CivilDay(year: 2026, month: 3, day: 8),
          startRelativeTime: const RelativeTime(
            dayOffset: 1,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          status: 'pending',
        ),
      ]);

      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      // Since it is snoozed until tomorrow (March 9), it should NOT be shown today
      expect(find.text('Snoozed One-Off'), findsNothing);
    },
  );

  testWidgets('TaskSchedule list screen hides tasks starting later today', (
    WidgetTester tester,
  ) async {
    AppClock.setMockTime(DateTime(2026, 3, 8, 9, 0));
    addTearDown(AppClock.reset);

    final futureTodayTask = TaskSchedule(
      id: 'future-today-task',
      title: 'Future Today Task',
      description: 'Starts at 10 AM',
      schedules: [
        OneOffSchedule(
          date: const CivilDay(year: 2026, month: 3, day: 8),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 10, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
        ),
      ],
    );

    tasksSubject.add([futureTodayTask]);
    instancesSubject.add([
      TaskInstance(
        id: 'I-future-today-task_2026-03-08',
        scheduleId: 'future-today-task',
        ruleId: futureTodayTask.schedules.first.id,
        title: 'Future Today Task',
        description: 'Starts at 10 AM',
        scheduledDate: const CivilDay(year: 2026, month: 3, day: 8),
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 10, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        status: 'pending',
      ),
    ]);

    await tester.pumpWidget(createScreen());
    await tester.pumpAndSettle();

    // Since it starts at 10:00 AM and mock time is 9:00 AM, it should NOT be shown
    expect(find.text('Future Today Task'), findsNothing);
  });

  testWidgets(
    'Completing a task does not affect the next task state (bug repro)',
    (WidgetTester tester) async {
      // Setup 2 tasks
      final task1 = TaskSchedule(
        id: '1',
        title: 'TaskSchedule 1',
        description: 'Desc 1',
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
      final task2 = TaskSchedule(
        id: '2',
        title: 'TaskSchedule 2',
        description: 'Desc 2',
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

      tasksSubject.add([task1, task2]);
      instancesSubject.add([
        TaskInstance(
          id: 'I-1_2024-01-01',
          scheduleId: '1',
          ruleId: task1.schedules.first.id,
          title: 'TaskSchedule 1',
          description: 'Desc 1',
          scheduledDate: const CivilDay(year: 2024, month: 1, day: 1),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          status: 'pending',
        ),
        TaskInstance(
          id: 'I-2_2024-01-01',
          scheduleId: '2',
          ruleId: task2.schedules.first.id,
          title: 'TaskSchedule 2',
          description: 'Desc 2',
          scheduledDate: const CivilDay(year: 2024, month: 1, day: 1),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          status: 'pending',
        ),
      ]);

      // Simulate deletion when completeTask is called
      when(
        mockTaskRepository.completeTaskInstance('I-1_2024-01-01'),
      ).thenAnswer((_) async {
        tasksSubject.add([task2]); // Remove task 1
        instancesSubject.add([
          TaskInstance(
            id: 'I-2_2024-01-01',
            scheduleId: '2',
            ruleId: task2.schedules.first.id,
            title: 'TaskSchedule 2',
            description: 'Desc 2',
            scheduledDate: const CivilDay(year: 2024, month: 1, day: 1),
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: 'pending',
          ),
        ]);
        return null;
      });

      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      final robot1 = TaskWidgetRobot.fromTitle(tester, 'TaskSchedule 1');
      final robot2 = TaskWidgetRobot.fromTitle(tester, 'TaskSchedule 2');

      robot1.expectVisible();
      robot2.expectVisible();

      // Tap TaskSchedule 1
      await robot1.tapCheckbox();

      await robot1.waitForCompletion();
      // Pump again to process the stream update and rebuild UI
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Verify completeTask was called
      verify(
        mockTaskRepository.completeTaskInstance('I-1_2024-01-01'),
      ).called(1);

      // Verify TaskSchedule 1 is gone (due to stream update)
      robot1.expectGone();

      // Verify TaskSchedule 2 is visible
      robot2.expectVisible();

      // Check if TaskSchedule 2 is inadvertently checked (state reuse bug)
      await robot2.expectChecked(false);
    },
  );

  testGoldens('TaskListScreen - Prod Mode (No Dev Clock Button)', (
    tester,
  ) async {
    // 1. Set environment to prod
    AppConfig.environment = AppEnvironment.prod;

    final mockAuthRepository = MockAuthRepository();
    final mockTaskRepository = MockTaskRepository();

    when(mockAuthRepository.signOut()).thenAnswer((_) async {});
    when(mockTaskRepository.getTasks()).thenAnswer((_) => Stream.value([]));
    when(mockTaskRepository.getInstances()).thenAnswer((_) => Stream.value([]));

    await tester.pumpWidgetBuilder(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          taskRepositoryProvider.overrideWithValue(mockTaskRepository),
        ],
        child: const HomeScreen(),
      ),
      wrapper: l10nMaterialAppWrapper(),
      surfaceSize: const Size(400, 800),
    );

    // Verify that the screen matches golden in prod environment without DevClockWidget

    await screenMatchesGolden(tester, 'task_list_screen_prod');

    // Reset back to dev environment for other tests
    AppConfig.environment = AppEnvironment.dev;
  });

  testGoldens('TaskListScreen - Shows Undo SnackBar', (tester) async {
    AppClock.setMockTime(DateTime(2026, 6, 19, 9, 0));
    addTearDown(AppClock.reset);

    final mockAuthRepository = MockAuthRepository();
    final mockTaskRepository = MockTaskRepository();

    final task = TaskSchedule(
      id: '1',
      title: 'Water the Houseplants',
      description: 'Give them water',
      schedules: [
        OneOffSchedule(
          date: const CivilDay(year: 2026, month: 6, day: 19),
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

    final instance = TaskInstance(
      id: 'I-1_2026-06-19',
      scheduleId: '1',
      ruleId: task.schedules.first.id,
      title: 'Water the Houseplants',
      description: 'Give them water',
      scheduledDate: const CivilDay(year: 2026, month: 6, day: 19),
      startRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 9, minute: 0),
      ),
      dueRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 17, minute: 0),
      ),
      status: 'pending',
    );

    final tasksSubject = BehaviorSubject<List<TaskSchedule>>.seeded([task]);
    final instancesSubject = BehaviorSubject<List<TaskInstance>>.seeded([
      instance,
    ]);

    when(mockAuthRepository.signOut()).thenAnswer((_) async {});
    when(mockTaskRepository.getTasks()).thenAnswer((_) => tasksSubject.stream);
    when(
      mockTaskRepository.getInstances(),
    ).thenAnswer((_) => instancesSubject.stream);
    when(mockTaskRepository.completeTaskInstance(any)).thenAnswer((_) async {
      // Optimistically remove the instance to mimic Firestore latency compensation
      instancesSubject.add([]);
      return instance.copyWith(status: 'completed');
    });

    await tester.pumpWidgetBuilder(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          taskRepositoryProvider.overrideWithValue(mockTaskRepository),
        ],
        child: const HomeScreen(),
      ),
      wrapper: l10nMaterialAppWrapper(),
      surfaceSize: const Size(400, 800),
    );

    await tester.pumpAndSettle();

    // Complete the task using the robot helper
    final robot = TaskWidgetRobot(tester);
    await robot.tapCheckbox();
    await robot.waitForCompletion();
    await tester.pumpAndSettle();

    // Verify the SnackBar is visible
    expect(find.text('Undo'), findsOneWidget);

    await screenMatchesGolden(tester, 'task_list_screen_with_snackbar');
  });

  testGoldens('TaskListScreen - Search Active with Results', (tester) async {
    AppClock.setMockTime(DateTime(2026, 6, 19, 9, 0));
    addTearDown(AppClock.reset);

    final mockAuthRepository = MockAuthRepository();
    final mockTaskRepository = MockTaskRepository();

    final task = TaskSchedule(
      id: '1',
      title: 'Water the Houseplants',
      description: 'Give them water',
      schedules: [
        OneOffSchedule(
          date: const CivilDay(year: 2026, month: 6, day: 19),
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

    final instance = TaskInstance(
      id: 'I-1_2026-06-19',
      scheduleId: '1',
      ruleId: task.schedules.first.id,
      title: 'Water the Houseplants',
      description: 'Give them water',
      scheduledDate: const CivilDay(year: 2026, month: 6, day: 19),
      startRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 9, minute: 0),
      ),
      dueRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 17, minute: 0),
      ),
      status: 'pending',
    );

    when(mockAuthRepository.signOut()).thenAnswer((_) async {});
    when(mockTaskRepository.getTasks()).thenAnswer((_) => Stream.value([task]));
    when(
      mockTaskRepository.getInstances(),
    ).thenAnswer((_) => Stream.value([instance]));

    await tester.pumpWidgetBuilder(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          taskRepositoryProvider.overrideWithValue(mockTaskRepository),
        ],
        child: const HomeScreen(),
      ),
      wrapper: l10nMaterialAppWrapper(),
      surfaceSize: const Size(400, 800),
    );

    await tester.pumpAndSettle();

    // Tap search icon to open search
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    // Enter query
    await tester.enterText(find.byType(TextField), 'water');
    await tester.pumpAndSettle();

    await screenMatchesGolden(tester, 'task_list_screen_search_results');
  });

  testGoldens('TaskListScreen - Search Active No Results Fallback', (
    tester,
  ) async {
    AppClock.setMockTime(DateTime(2026, 6, 19, 9, 0));
    addTearDown(AppClock.reset);

    final mockAuthRepository = MockAuthRepository();
    final mockTaskRepository = MockTaskRepository();

    when(mockAuthRepository.signOut()).thenAnswer((_) async {});
    when(mockTaskRepository.getTasks()).thenAnswer((_) => Stream.value([]));
    when(mockTaskRepository.getInstances()).thenAnswer((_) => Stream.value([]));

    await tester.pumpWidgetBuilder(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          taskRepositoryProvider.overrideWithValue(mockTaskRepository),
        ],
        child: const HomeScreen(),
      ),
      wrapper: l10nMaterialAppWrapper(),
      surfaceSize: const Size(400, 800),
    );

    await tester.pumpAndSettle();

    // Tap search icon to open search
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    // Enter query that has no match
    await tester.enterText(find.byType(TextField), 'nonexistent');
    await tester.pumpAndSettle();

    await screenMatchesGolden(tester, 'task_list_screen_search_no_results');
  });

  testWidgets('TaskListScreen search filters by title and description', (
    WidgetTester tester,
  ) async {
    // Set mock time
    AppClock.setMockTime(DateTime(2026, 6, 19, 9, 0));
    addTearDown(AppClock.reset);

    final mockAuthRepository = MockAuthRepository();
    final mockTaskRepository = MockTaskRepository();

    final task1 = TaskSchedule(
      id: '1',
      title: 'Water the Houseplants',
      description: 'Use warm water',
      schedules: [
        OneOffSchedule(
          date: const CivilDay(year: 2026, month: 6, day: 19),
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

    final task2 = TaskSchedule(
      id: '2',
      title: 'Buy Groceries',
      description: 'Get some fresh bread',
      schedules: [
        OneOffSchedule(
          date: const CivilDay(year: 2026, month: 6, day: 19),
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

    final inst1 = TaskInstance(
      id: 'I-1_2026-06-19',
      scheduleId: '1',
      ruleId: task1.schedules.first.id,
      title: 'Water the Houseplants',
      description: 'Use warm water',
      scheduledDate: const CivilDay(year: 2026, month: 6, day: 19),
      startRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 9, minute: 0),
      ),
      dueRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 17, minute: 0),
      ),
      status: 'pending',
    );

    final inst2 = TaskInstance(
      id: 'I-2_2026-06-19',
      scheduleId: '2',
      ruleId: task2.schedules.first.id,
      title: 'Buy Groceries',
      description: 'Get some fresh bread',
      scheduledDate: const CivilDay(year: 2026, month: 6, day: 19),
      startRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 9, minute: 0),
      ),
      dueRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 17, minute: 0),
      ),
      status: 'pending',
    );

    when(mockAuthRepository.signOut()).thenAnswer((_) async {});
    when(
      mockTaskRepository.getTasks(),
    ).thenAnswer((_) => Stream.value([task1, task2]));
    when(
      mockTaskRepository.getInstances(),
    ).thenAnswer((_) => Stream.value([inst1, inst2]));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          taskRepositoryProvider.overrideWithValue(mockTaskRepository),
        ],
        child: buildTestableWidget(child: const HomeScreen()),
      ),
    );

    await tester.pumpAndSettle();

    // Verify both tasks are visible initially
    expect(find.text('Water the Houseplants'), findsOneWidget);
    expect(find.text('Buy Groceries'), findsOneWidget);

    // Tap search button to expand search bar
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    // Type query to filter (by title)
    await tester.enterText(find.byType(TextField), 'houseplants');
    await tester.pumpAndSettle();

    // Verify task1 matches and is visible, task2 is filtered out
    expect(find.text('Water the Houseplants'), findsOneWidget);
    expect(find.text('Buy Groceries'), findsNothing);

    // Type query to filter (by description)
    await tester.enterText(find.byType(TextField), 'bread');
    await tester.pumpAndSettle();

    // Verify task2 matches and is visible, task1 is filtered out
    expect(find.text('Buy Groceries'), findsOneWidget);
    expect(find.text('Water the Houseplants'), findsNothing);

    // Type query with multiple words that should match (non-adjacent/individual words)
    await tester.enterText(find.byType(TextField), 'water houseplant');
    await tester.pumpAndSettle();

    // Verify task1 matches (contains both 'water' and 'houseplant')
    expect(find.text('Water the Houseplants'), findsOneWidget);
    expect(find.text('Buy Groceries'), findsNothing);

    // Type query with multiple words that do not exist together in one task
    await tester.enterText(find.byType(TextField), 'water bread');
    await tester.pumpAndSettle();

    expect(find.text('Water the Houseplants'), findsNothing);
    expect(find.text('Buy Groceries'), findsNothing);

    // Type query that matches nothing
    await tester.enterText(find.byType(TextField), 'xyz123');
    await tester.pumpAndSettle();

    // Verify both are gone, and fallback/empty state is shown
    expect(find.text('Water the Houseplants'), findsNothing);
    expect(find.text('Buy Groceries'), findsNothing);
    expect(
      find.textContaining('No matching tasks found for "xyz123"'),
      findsOneWidget,
    );

    // Tap Clear Search button
    await tester.tap(find.text('Clear Search'));
    await tester.pumpAndSettle();

    // Verify search field is cleared and both tasks are back
    expect(find.text('Water the Houseplants'), findsOneWidget);
    expect(find.text('Buy Groceries'), findsOneWidget);
  });

  testWidgets('pressing slash key focuses the search input', (
    WidgetTester tester,
  ) async {
    final mockAuthRepository = MockAuthRepository();
    final mockTaskRepository = MockTaskRepository();

    when(mockAuthRepository.signOut()).thenAnswer((_) async {});
    when(mockTaskRepository.getTasks()).thenAnswer((_) => Stream.value([]));
    when(mockTaskRepository.getInstances()).thenAnswer((_) => Stream.value([]));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          taskRepositoryProvider.overrideWithValue(mockTaskRepository),
        ],
        child: buildTestableWidget(child: const HomeScreen()),
      ),
    );

    await tester.pumpAndSettle();

    // Search bar should not be visible initially
    expect(find.byType(TextField), findsNothing);

    // Focus the main Focus widget to enable shortcut listening
    final node = Focus.of(tester.element(find.byType(Scaffold).first));
    node.requestFocus();
    await tester.pump();

    // Press slash key with character '/'
    await tester.sendKeyDownEvent(LogicalKeyboardKey.slash, character: '/');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.slash);
    await tester.pumpAndSettle();

    // Search bar should expand and focus
    expect(find.byType(TextField), findsOneWidget);
    final textFieldFocus = tester
        .widget<TextField>(find.byType(TextField))
        .focusNode;
    expect(textFieldFocus?.hasFocus, isTrue);
  });

  testWidgets('pressing Escape key collapses the search input', (
    WidgetTester tester,
  ) async {
    final mockAuthRepository = MockAuthRepository();
    final mockTaskRepository = MockTaskRepository();

    when(mockAuthRepository.signOut()).thenAnswer((_) async {});
    when(mockTaskRepository.getTasks()).thenAnswer((_) => Stream.value([]));
    when(mockTaskRepository.getInstances()).thenAnswer((_) => Stream.value([]));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          taskRepositoryProvider.overrideWithValue(mockTaskRepository),
        ],
        child: buildTestableWidget(child: const HomeScreen()),
      ),
    );

    await tester.pumpAndSettle();

    // Tap search button to expand search bar
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);

    // Press Escape key
    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    // Search bar should be collapsed
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('system back button collapses the search input', (
    WidgetTester tester,
  ) async {
    final mockAuthRepository = MockAuthRepository();
    final mockTaskRepository = MockTaskRepository();

    when(mockAuthRepository.signOut()).thenAnswer((_) async {});
    when(mockTaskRepository.getTasks()).thenAnswer((_) => Stream.value([]));
    when(mockTaskRepository.getInstances()).thenAnswer((_) => Stream.value([]));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          taskRepositoryProvider.overrideWithValue(mockTaskRepository),
        ],
        child: buildTestableWidget(child: const HomeScreen()),
      ),
    );

    await tester.pumpAndSettle();

    // Tap search button to expand search bar
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);

    // Simulate system back button press using handlePopRoute
    final bool handled = await tester.binding.handlePopRoute();
    expect(handled, isTrue);
    await tester.pumpAndSettle();

    // Search bar should be collapsed
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets(
    'does not show task when system clock crosses start time in real-time mode',
    (WidgetTester tester) async {
      final mockAuthRepository = MockAuthRepository();
      final mockTaskRepository = MockTaskRepository();

      // Revert to system clock (make sure no mock is active)
      AppClock.reset();

      // Get the initial test clock time (which is the fake DateTime.now() managed by tester)
      final startTime = DateTime.now(); // e.g. 2015-01-01 00:00:00
      final taskDate = CivilDay.fromDateTime(startTime);

      // Schedule the task to start 5 minutes in the future
      final taskStartLocalTime = startTime.add(const Duration(minutes: 5));
      final relativeStart = RelativeTime(
        dayOffset: 0,
        time: TimeOfDay.fromDateTime(taskStartLocalTime),
      );
      final relativeDue = RelativeTime(
        dayOffset: 0,
        time: TimeOfDay.fromDateTime(startTime.add(const Duration(hours: 1))),
      );

      final futureTask = TaskSchedule(
        id: 'future-task-1',
        title: 'Future Task',
        description: 'Starts in 5 minutes',
        schedules: [
          OneOffSchedule(
            date: taskDate,
            startRelativeTime: relativeStart,
            dueRelativeTime: relativeDue,
          ),
        ],
      );

      // Prepare behavior subjects
      final tasksSubj = BehaviorSubject<List<TaskSchedule>>.seeded([
        futureTask,
      ]);
      // Create the instance representing the task.
      final futureInstance = TaskInstance(
        id: 'I-future-task-1_inst',
        scheduleId: futureTask.id,
        ruleId: futureTask.schedules.first.id,
        title: futureTask.title,
        description: futureTask.description,
        scheduledDate: taskDate,
        startRelativeTime: relativeStart,
        dueRelativeTime: relativeDue,
        status: 'pending',
      );
      final instancesSubj = BehaviorSubject<List<TaskInstance>>.seeded([
        futureInstance,
      ]);

      when(mockAuthRepository.signOut()).thenAnswer((_) async {});
      when(mockTaskRepository.getTasks()).thenAnswer((_) => tasksSubj.stream);
      when(
        mockTaskRepository.getInstances(),
      ).thenAnswer((_) => instancesSubj.stream);

      // Pump the screen
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepository),
            taskRepositoryProvider.overrideWithValue(mockTaskRepository),
          ],
          child: buildTestableWidget(child: const HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // At startTime, the task should NOT be visible because startRelativeTime is 5 minutes in the future.
      expect(find.text('Future Task'), findsNothing);

      // Elapse 10 minutes. This advances the fake system clock past the task's start time.
      await tester.pump(const Duration(minutes: 10));

      // Under the fixed implementation (where TaskListScreen has a periodic timer),
      // the screen should rebuild and show the task once the clock passes the start time.
      expect(find.text('Future Task'), findsOneWidget);

      await tasksSubj.close();
      await instancesSubj.close();
    },
  );

  testWidgets('TaskListScreen does not display future pending tasks', (
    WidgetTester tester,
  ) async {
    final mockAuthRepository = MockAuthRepository();
    final mockTaskRepository = MockTaskRepository();

    final startTime = DateTime.now();
    final taskDate = CivilDay.fromDateTime(startTime);

    final taskStartLocalTime = startTime.add(const Duration(minutes: 5));
    final relativeStart = RelativeTime(
      dayOffset: 0,
      time: TimeOfDay.fromDateTime(taskStartLocalTime),
    );
    final relativeDue = RelativeTime(
      dayOffset: 0,
      time: TimeOfDay.fromDateTime(startTime.add(const Duration(hours: 1))),
    );

    final futureTask = TaskSchedule(
      id: 'future-task-1',
      title: 'Future Task',
      description: 'Starts in 5 minutes',
      schedules: [
        OneOffSchedule(
          date: taskDate,
          startRelativeTime: relativeStart,
          dueRelativeTime: relativeDue,
        ),
      ],
    );

    final tasksSubj = BehaviorSubject<List<TaskSchedule>>.seeded([futureTask]);
    final futureInstance = TaskInstance(
      id: 'I-future-task-1_inst',
      scheduleId: futureTask.id,
      ruleId: futureTask.schedules.first.id,
      title: futureTask.title,
      description: futureTask.description,
      scheduledDate: taskDate,
      startRelativeTime: relativeStart,
      dueRelativeTime: relativeDue,
      status: 'pending',
    );
    final instancesSubj = BehaviorSubject<List<TaskInstance>>.seeded([
      futureInstance,
    ]);

    when(mockAuthRepository.signOut()).thenAnswer((_) async {});
    when(mockTaskRepository.getTasks()).thenAnswer((_) => tasksSubj.stream);
    when(
      mockTaskRepository.getInstances(),
    ).thenAnswer((_) => instancesSubj.stream);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          taskRepositoryProvider.overrideWithValue(mockTaskRepository),
          userSettingsProvider.overrideWith(
            (ref) => Stream.value(const UserSettings(hoursAvailable: 8.0)),
          ),
        ],
        child: buildTestableWidget(child: const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Future Task'), findsNothing);
    expect(find.text('Pending'), findsNothing);

    await tasksSubj.close();
    await instancesSubj.close();
  });

  testWidgets('TaskListScreen sorts tasks correctly by name, due time, priority', (
    WidgetTester tester,
  ) async {
    final mockAuthRepository = MockAuthRepository();
    final mockTaskRepository = MockTaskRepository();

    final now = DateTime(2026, 6, 22, 12, 0);
    AppClock.setMockTime(now);
    addTearDown(AppClock.reset);
    final taskDate = CivilDay.fromDateTime(now);

    // B: Title Apple, Priority low, Start offset 1 hour, Due offset 2 hours
    final taskB = TaskSchedule(
      id: 'task-b',
      title: 'Apple',
      description: 'Test B',
      schedules: [
        OneOffSchedule(
          date: taskDate,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 10, minute: 0),
          ),
        ),
      ],
      priority: TaskPriority.low,
    );

    // A: Title Banana, Priority high, Start offset 2 hours, Due offset 3 hours
    final taskA = TaskSchedule(
      id: 'task-a',
      title: 'Banana',
      description: 'Test A',
      schedules: [
        OneOffSchedule(
          date: taskDate,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 10, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 11, minute: 0),
          ),
        ),
      ],
      priority: TaskPriority.high,
    );

    // C: Title Cherry, Priority medium, Start offset 3 hours, Due offset 1 hour
    final taskC = TaskSchedule(
      id: 'task-c',
      title: 'Cherry',
      description: 'Test C',
      schedules: [
        OneOffSchedule(
          date: taskDate,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 11, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 8, minute: 30),
          ),
        ),
      ],
      priority: TaskPriority.medium,
    );

    final instB = TaskInstance(
      id: 'inst-b',
      scheduleId: taskB.id,
      ruleId: taskB.schedules.first.id,
      title: taskB.title,
      description: taskB.description,
      scheduledDate: taskDate,
      startRelativeTime: taskB.schedules.first.startRelativeTime,
      dueRelativeTime: taskB.schedules.first.dueRelativeTime,
      priority: taskB.priority,
    );

    final instA = TaskInstance(
      id: 'inst-a',
      scheduleId: taskA.id,
      ruleId: taskA.schedules.first.id,
      title: taskA.title,
      description: taskA.description,
      scheduledDate: taskDate,
      startRelativeTime: taskA.schedules.first.startRelativeTime,
      dueRelativeTime: taskA.schedules.first.dueRelativeTime,
      priority: taskA.priority,
    );

    final instC = TaskInstance(
      id: 'inst-c',
      scheduleId: taskC.id,
      ruleId: taskC.schedules.first.id,
      title: taskC.title,
      description: taskC.description,
      scheduledDate: taskDate,
      startRelativeTime: taskC.schedules.first.startRelativeTime,
      dueRelativeTime: taskC.schedules.first.dueRelativeTime,
      priority: taskC.priority,
    );

    when(mockAuthRepository.signOut()).thenAnswer((_) async {});
    when(
      mockTaskRepository.getTasks(),
    ).thenAnswer((_) => Stream.value([taskB, taskA, taskC]));
    when(
      mockTaskRepository.getInstances(),
    ).thenAnswer((_) => Stream.value([instB, instA, instC]));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          taskRepositoryProvider.overrideWithValue(mockTaskRepository),
          userSettingsProvider.overrideWith(
            (ref) => Stream.value(const UserSettings(hoursAvailable: 8.0)),
          ),
        ],
        child: buildTestableWidget(child: const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Verify default sort by Name/Title (Apple, Banana, Cherry)
    var textFinder = find.byType(TaskWidget);
    expect(textFinder, findsNWidgets(3));

    // Check titles of the rendered widgets in sequence
    expect(tester.widget<TaskWidget>(textFinder.at(0)).instance.title, 'Apple');
    expect(
      tester.widget<TaskWidget>(textFinder.at(1)).instance.title,
      'Banana',
    );
    expect(
      tester.widget<TaskWidget>(textFinder.at(2)).instance.title,
      'Cherry',
    );

    // Tap on Priority sorting chip (find ChoiceChip with label 'Priority')
    await tester.ensureVisible(find.text('Priority'));
    await tester.tap(find.text('Priority'));
    await tester.pumpAndSettle();

    // Verify sort by Priority ascending (low to high: low, medium, high) -> Apple, Cherry, Banana
    expect(tester.widget<TaskWidget>(textFinder.at(0)).instance.title, 'Apple');
    expect(
      tester.widget<TaskWidget>(textFinder.at(1)).instance.title,
      'Cherry',
    );
    expect(
      tester.widget<TaskWidget>(textFinder.at(2)).instance.title,
      'Banana',
    );

    // Tap Priority again to toggle descending -> Banana, Cherry, Apple
    await tester.ensureVisible(find.text('Priority'));
    await tester.tap(find.text('Priority'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TaskWidget>(textFinder.at(0)).instance.title,
      'Banana',
    );
    expect(
      tester.widget<TaskWidget>(textFinder.at(1)).instance.title,
      'Cherry',
    );
    expect(tester.widget<TaskWidget>(textFinder.at(2)).instance.title, 'Apple');

    // Tap on Next Due sorting chip -> Cherry (8:30), Apple (10:00), Banana (11:00)
    await tester.ensureVisible(find.text('Next Due'));
    await tester.tap(find.text('Next Due'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TaskWidget>(textFinder.at(0)).instance.title,
      'Cherry',
    );
    expect(tester.widget<TaskWidget>(textFinder.at(1)).instance.title, 'Apple');
    expect(
      tester.widget<TaskWidget>(textFinder.at(2)).instance.title,
      'Banana',
    );
  });

  testWidgets(
    'TaskListScreen shows capacity prompt task card when capacity is not confirmed, and hides it when confirmed',
    (WidgetTester tester) async {
      final mockAuthRepository = MockAuthRepository();
      final mockTaskRepository = MockTaskRepository();
      final mockUserSettingsRepository =
          home_mocks.MockUserSettingsRepository();

      AppClock.setMockTime(
        DateTime(2026, 7, 1, 9, 0),
      ); // Wednesday (2026-07-01)
      addTearDown(AppClock.reset);

      final settingsSubject = BehaviorSubject<UserSettings>.seeded(
        const UserSettings(
          hoursAvailable: 8.0,
          lastCapacityConfirmedWeek: '', // Empty: not confirmed
        ),
      );

      when(mockAuthRepository.signOut()).thenAnswer((_) async {});
      when(mockTaskRepository.getTasks()).thenAnswer((_) => Stream.value([]));
      when(
        mockTaskRepository.getInstances(),
      ).thenAnswer((_) => Stream.value([]));
      when(
        mockUserSettingsRepository.getSettings(),
      ).thenAnswer((_) => settingsSubject.stream);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepository),
            taskRepositoryProvider.overrideWithValue(mockTaskRepository),
            userSettingsRepositoryProvider.overrideWithValue(
              mockUserSettingsRepository,
            ),
            userSettingsProvider.overrideWith((ref) => settingsSubject.stream),
          ],
          child: buildTestableWidget(child: const HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify capacity prompt card is visible
      expect(find.byKey(const Key('capacity_prompt_card')), findsOneWidget);
      expect(find.text('Adjust your weekly capacity'), findsOneWidget);

      // 2. Mock capacity confirmation
      settingsSubject.add(
        const UserSettings(
          hoursAvailable: 8.0,
          lastCapacityConfirmedWeek: '2026-06-29', // Confirmed for this week!
        ),
      );
      await tester.pumpAndSettle();

      // 3. Verify capacity prompt card disappears
      expect(find.byKey(const Key('capacity_prompt_card')), findsNothing);

      AppClock.reset();
      settingsSubject.close();
    },
  );
}
