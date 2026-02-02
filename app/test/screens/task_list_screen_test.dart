import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

import 'package:mockito/annotations.dart';
import 'package:nothing_ever_happens/logic/auth_repository.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/screens/task_list_screen.dart';
import 'package:nothing_ever_happens/logic/task.dart';
import 'package:nothing_ever_happens/logic/task_delta.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';

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
      child: const MaterialApp(home: TaskListScreen()),
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

    expect(find.text('New Task Title'), findsOneWidget);
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
        child: const TaskListScreen(),
      ),
      wrapper: materialAppWrapper(),
      surfaceSize: const Size(400, 800),
    );

    // Initial state: we see the current task
    await screenMatchesGolden(tester, 'task_list_screen_initial');

    // Scroll up to reveal history
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
    await tester.pump();

    await screenMatchesGolden(tester, 'task_list_screen_history');
  });
}
