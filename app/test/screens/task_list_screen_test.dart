import 'dart:async';
import 'package:flutter/material.dart';
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
  late BehaviorSubject<List<TaskSchedule>> tasksSubject;
  late BehaviorSubject<List<TaskInstance>> instancesSubject;
  late BehaviorSubject<List<TaskDelta>> historySubject;
  StreamSubscription? tasksSub;
  VoidCallback? clockListener;

  List<TaskInstance> mockInstancesFromSchedules(
    List<TaskSchedule> schedules,
    DateTime todayDate,
  ) {
    final today = CivilDay.fromDateTime(todayDate);
    final List<TaskInstance> list = [];
    for (final task in schedules) {
      for (int i = 0; i < task.schedules.length; i++) {
        final s = task.schedules[i];
        if (s is OneOffSchedule) {
          final startsDate = s.date.addDays(s.startRelativeTime.dayOffset);
          if (!today.isBefore(startsDate)) {
            list.add(
              TaskInstance(
                id: task.schedules.length <= 1
                    ? '${task.id}_${s.date}'
                    : '${task.id}_${s.date}_$i',
                scheduleId: task.id,
                title: task.title,
                description: task.description,
                scheduledDate: s.date,
                startRelativeTime: s.startRelativeTime,
                dueRelativeTime: s.dueRelativeTime,
                isFamily: task.isFamily,
                priority: task.priority,
                cycleId: task.cycleId,
                assignedUserId: task.assignedUserId,
                status: 'pending',
              ),
            );
          }
        } else if (s is DailySchedule) {
          if (!today.isBefore(s.startDate)) {
            list.add(
              TaskInstance(
                id: task.schedules.length <= 1
                    ? '${task.id}_$today'
                    : '${task.id}_${today}_$i',
                scheduleId: task.id,
                title: task.title,
                description: task.description,
                scheduledDate: today,
                startRelativeTime: s.startRelativeTime,
                dueRelativeTime: s.dueRelativeTime,
                isFamily: task.isFamily,
                priority: task.priority,
                cycleId: task.cycleId,
                assignedUserId: task.assignedUserId,
                status: 'pending',
              ),
            );
          }
        }
      }
    }
    return list;
  }

  void updateInstances() {
    final list = mockInstancesFromSchedules(tasksSubject.value, AppClock.now);
    instancesSubject.add(list);
  }

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
    tasksSubject = BehaviorSubject<List<TaskSchedule>>(sync: true)
      ..add(initialTasks);
    instancesSubject = BehaviorSubject<List<TaskInstance>>(sync: true)
      ..add(mockInstancesFromSchedules(initialTasks, AppClock.now));
    historySubject = BehaviorSubject<List<TaskDelta>>(sync: true)..add([]);

    // Listen to changes to auto-update instances
    tasksSub = tasksSubject.listen((_) => updateInstances());
    clockListener = () => updateInstances();
    AppClock.timeNotifier.addListener(clockListener!);

    // Default stubbing
    when(mockAuthRepository.signOut()).thenAnswer((_) async {});
    when(mockTaskRepository.getTasks()).thenAnswer((_) => tasksSubject.stream);
    when(
      mockTaskRepository.getInstances(),
    ).thenAnswer((_) => instancesSubject.stream);
    when(
      mockTaskRepository.getHistory(),
    ).thenAnswer((_) => historySubject.stream);

    when(mockTaskRepository.addTask(any)).thenAnswer((invocation) async {
      final task = invocation.positionalArguments.first as TaskSchedule;
      final currentTasks = tasksSubject.value;
      tasksSubject.add([...currentTasks, task]);
    });
  });

  tearDown(() {
    tasksSub?.cancel();
    if (clockListener != null) {
      AppClock.timeNotifier.removeListener(clockListener!);
    }
    tasksSubject.close();
    instancesSubject.close();
    historySubject.close();
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
    verifyNever(mockTaskRepository.completeTask('1_2024-01-01'));

    await robot.waitForCompletion();

    // Verify completeTask was called
    verify(mockTaskRepository.completeTask('1_2024-01-01')).called(1);
  });

  testWidgets(
    'Completing a recurring task advances its schedule and does not reappear on screen',
    (WidgetTester tester) async {
      AppClock.setMockTime(DateTime(2026, 3, 8, 9, 0));

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

      when(mockTaskRepository.completeTask('recur-1_2026-03-08')).thenAnswer((
        _,
      ) async {
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

      AppClock.reset();
    },
  );

  testWidgets(
    'TaskSchedule list screen filters out tasks scheduled in the future',
    (WidgetTester tester) async {
      AppClock.setMockTime(DateTime(2026, 3, 8, 9, 0));

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

      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      // Today's task should be shown
      expect(find.text('Today TaskSchedule'), findsOneWidget);

      // Tomorrow's task should be filtered out
      expect(find.text('Tomorrow TaskSchedule'), findsNothing);

      AppClock.reset();
    },
  );

  testWidgets(
    'TaskSchedule list screen shows one-off tasks starting today but due in the future',
    (WidgetTester tester) async {
      AppClock.setMockTime(DateTime(2026, 3, 8, 9, 0));

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

      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      // Since it starts today (March 8), it should be shown
      expect(find.text('Active One-Off'), findsOneWidget);

      AppClock.reset();
    },
  );

  testWidgets(
    'TaskSchedule list screen hides one-off tasks due today but snoozed/starting in the future',
    (WidgetTester tester) async {
      AppClock.setMockTime(DateTime(2026, 3, 8, 9, 0));

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

      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      // Since it is snoozed until tomorrow (March 9), it should NOT be shown today
      expect(find.text('Snoozed One-Off'), findsNothing);

      AppClock.reset();
    },
  );

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

      // Simulate deletion when completeTask is called
      when(mockTaskRepository.completeTask('1_2024-01-01')).thenAnswer((
        _,
      ) async {
        tasksSubject.add([task2]); // Remove task 1
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
      verify(mockTaskRepository.completeTask('1_2024-01-01')).called(1);

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
    when(mockTaskRepository.getHistory()).thenAnswer((_) => Stream.value([]));

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

    // Verify that the dev clock button is NOT displayed (only one widget tree item but shrunk to SizedBox)
    expect(find.byType(DevClockWidget), findsOneWidget);
    expect(find.byIcon(Icons.av_timer), findsNothing);

    await screenMatchesGolden(tester, 'task_list_screen_prod');

    // Reset back to dev environment for other tests
    AppConfig.environment = AppEnvironment.dev;
  });
}
