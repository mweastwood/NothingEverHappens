import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import '../test_helper.dart';

import 'package:nothing_ever_happens/logic/auth_repository.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/screens/home_screen.dart';
import 'package:nothing_ever_happens/screens/task_list_screen.dart';
import 'package:nothing_ever_happens/screens/task_schedule_screen.dart';
import 'package:nothing_ever_happens/screens/task_history_screen.dart';
import 'package:nothing_ever_happens/logic/task.dart';
import 'package:nothing_ever_happens/logic/task_delta.dart';

import 'task_list_screen_test.mocks.dart';

void main() {
  late MockAuthRepository mockAuthRepository;
  late MockTaskRepository mockTaskRepository;
  late BehaviorSubject<List<Task>> tasksSubject;
  late BehaviorSubject<List<TaskDelta>> historySubject;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    mockTaskRepository = MockTaskRepository();

    tasksSubject = BehaviorSubject<List<Task>>.seeded([]);
    historySubject = BehaviorSubject<List<TaskDelta>>.seeded([]);

    when(mockAuthRepository.signOut()).thenAnswer((_) async {});
    when(mockTaskRepository.getTasks()).thenAnswer((_) => tasksSubject.stream);
    when(
      mockTaskRepository.getHistory(),
    ).thenAnswer((_) => historySubject.stream);
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

  testWidgets('HomeScreen initial state (Tasks tab)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createScreen());
    await tester.pumpAndSettle();

    // Verify NavigationBar is present
    expect(find.byType(NavigationBar), findsOneWidget);

    // Verify default selected tab is Tasks (index 0)
    final NavigationBar navBar = tester.widget(find.byType(NavigationBar));
    expect(navBar.selectedIndex, 0);

    // Verify TaskListScreen is visible, others are not
    expect(find.byType(TaskListScreen), findsOneWidget);
    expect(find.byType(TaskScheduleScreen), findsNothing);
    expect(find.byType(TaskHistoryScreen), findsNothing);

    // Verify FloatingActionButton is shown on Tasks tab
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('HomeScreen switch tabs to Schedule, History, and back', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createScreen());
    await tester.pumpAndSettle();

    // 1. Switch to Schedule tab
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();

    // Verify selected tab is index 1
    final NavigationBar navBar1 = tester.widget(find.byType(NavigationBar));
    expect(navBar1.selectedIndex, 1);

    // Verify TaskScheduleScreen is visible, others are not
    expect(find.byType(TaskScheduleScreen), findsOneWidget);
    expect(find.byType(TaskListScreen), findsNothing);
    expect(find.byType(TaskHistoryScreen), findsNothing);

    // Verify FAB is still shown on Schedule tab
    expect(find.byType(FloatingActionButton), findsOneWidget);

    // 2. Switch to History tab
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    // Verify selected tab is index 2
    final NavigationBar navBar2 = tester.widget(find.byType(NavigationBar));
    expect(navBar2.selectedIndex, 2);

    // Verify TaskHistoryScreen is visible, others are not
    expect(find.byType(TaskHistoryScreen), findsOneWidget);
    expect(find.byType(TaskListScreen), findsNothing);
    expect(find.byType(TaskScheduleScreen), findsNothing);

    // Verify FAB is hidden on History tab
    expect(find.byType(FloatingActionButton), findsNothing);

    // 3. Switch back to Tasks tab
    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();

    // Verify selected tab is index 0
    final NavigationBar navBar3 = tester.widget(find.byType(NavigationBar));
    expect(navBar3.selectedIndex, 0);

    // Verify TaskListScreen is visible again and FAB is back
    expect(find.byType(TaskListScreen), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
