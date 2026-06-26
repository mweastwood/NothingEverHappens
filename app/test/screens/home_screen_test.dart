import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import '../test_helper.dart';

import 'package:nothing_ever_happens/logic/auth_repository.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/user_settings.dart';
import 'package:nothing_ever_happens/logic/user_settings_repository.dart';
import 'package:nothing_ever_happens/screens/home_screen.dart';
import 'package:nothing_ever_happens/screens/settings_screen.dart';
import 'package:nothing_ever_happens/screens/task_list_screen.dart';
import 'package:nothing_ever_happens/screens/task_schedule_screen.dart';
import 'package:nothing_ever_happens/screens/family_screen.dart';
import 'package:nothing_ever_happens/screens/help_screen.dart';
import 'package:nothing_ever_happens/logic/family_repository.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/main.dart';
import 'package:nothing_ever_happens/screens/create_task_screen.dart';

@GenerateNiceMocks([
  MockSpec<AuthRepository>(),
  MockSpec<TaskRepository>(),
  MockSpec<UserSettingsRepository>(),
])
import 'home_screen_test.mocks.dart';

void main() {
  late MockAuthRepository mockAuthRepository;
  late MockTaskRepository mockTaskRepository;
  late MockUserSettingsRepository mockUserSettingsRepository;
  late BehaviorSubject<List<TaskSchedule>> tasksSubject;
  late BehaviorSubject<List<TaskInstance>> instancesSubject;
  late BehaviorSubject<UserSettings> settingsSubject;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    mockTaskRepository = MockTaskRepository();
    mockUserSettingsRepository = MockUserSettingsRepository();

    tasksSubject = BehaviorSubject<List<TaskSchedule>>.seeded([]);
    instancesSubject = BehaviorSubject<List<TaskInstance>>.seeded([]);
    settingsSubject = BehaviorSubject<UserSettings>.seeded(
      const UserSettings(hoursAvailable: 8.0),
    );

    when(mockAuthRepository.signOut()).thenAnswer((_) async {});
    when(mockTaskRepository.getTasks()).thenAnswer((_) => tasksSubject.stream);
    when(
      mockTaskRepository.getInstances(),
    ).thenAnswer((_) => instancesSubject.stream);
    when(
      mockUserSettingsRepository.getSettings(),
    ).thenAnswer((_) => settingsSubject.stream);
  });

  tearDown(() {
    tasksSubject.close();
    instancesSubject.close();
    settingsSubject.close();
  });

  Widget createScreen({Uri? mockUri}) {
    final firestore = FakeFirebaseFirestore();
    final familyRepo = FamilyRepository(
      firestore: firestore,
      userId: 'user-1',
      userEmail: 'user1@example.com',
      userDisplayName: 'Alice',
    );

    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepository),
        taskRepositoryProvider.overrideWithValue(mockTaskRepository),
        userSettingsRepositoryProvider.overrideWithValue(
          mockUserSettingsRepository,
        ),
        familyRepositoryProvider.overrideWithValue(familyRepo),
      ],
      child: buildTestableWidget(child: HomeScreen(mockUri: mockUri)),
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
    expect(find.byType(FamilyScreen), findsNothing);

    // Verify FloatingActionButton is shown on Tasks tab
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('HomeScreen switch tabs to Schedule, Family, and back', (
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
    expect(find.byType(FamilyScreen), findsNothing);

    // Verify FAB is still shown on Schedule tab
    expect(find.byType(FloatingActionButton), findsOneWidget);

    // 2. Switch to Family tab
    await tester.tap(find.text('Family'));
    await tester.pumpAndSettle();

    // Verify selected tab is index 2
    final NavigationBar navBar2 = tester.widget(find.byType(NavigationBar));
    expect(navBar2.selectedIndex, 2);

    // Verify FamilyScreen is visible, others are not
    expect(find.byType(FamilyScreen), findsOneWidget);
    expect(find.byType(TaskListScreen), findsNothing);
    expect(find.byType(TaskScheduleScreen), findsNothing);

    // Verify FAB is hidden on Family tab
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

  testWidgets('HomeScreen drawer opens and navigates to settings', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createScreen());
    await tester.pumpAndSettle();

    // Verify drawer is closed initially
    expect(find.byType(Drawer), findsNothing);

    // Open drawer using the menu icon
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    // Verify drawer is now open
    expect(find.byType(Drawer), findsOneWidget);

    // Verify drawer header and list tiles
    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text('Menu')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('drawer_settings_tile')), findsOneWidget);
    expect(find.byKey(const Key('drawer_logout_tile')), findsOneWidget);

    // Tap on settings tile and verify navigation
    await tester.tap(find.byKey(const Key('drawer_settings_tile')));
    await tester.pumpAndSettle();

    // Verify SettingsScreen is visible
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testGoldens('HomeScreen drawer open state golden', (tester) async {
    await tester.pumpWidgetBuilder(
      createScreen(),
      wrapper: l10nMaterialAppWrapper(),
      surfaceSize: const Size(400, 800),
    );

    // Open drawer
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    // Match golden
    await screenMatchesGolden(tester, 'home_screen_drawer_open');
  });

  testWidgets(
    'HomeScreen tasks tab shows help button and navigates to HelpScreen',
    (WidgetTester tester) async {
      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      // Verify help icon button is present
      expect(find.byIcon(Icons.help_outline), findsOneWidget);

      // Tap help button
      await tester.tap(find.byIcon(Icons.help_outline));
      await tester.pumpAndSettle();

      // Verify HelpScreen is pushed
      expect(find.byType(HelpScreen), findsOneWidget);
    },
  );

  testGoldens('HomeScreen tasks tab with help button golden', (tester) async {
    await tester.pumpWidgetBuilder(
      createScreen(),
      wrapper: l10nMaterialAppWrapper(),
      surfaceSize: const Size(400, 800),
    );

    await tester.pumpAndSettle();

    // Verify help button is shown
    expect(find.byIcon(Icons.help_outline), findsOneWidget);

    await screenMatchesGolden(tester, 'home_screen_tasks_tab_with_help');
  });

  testWidgets(
    'HomeScreen FAB on Tasks tab navigates to CreateTaskScreen defaulting to one-off',
    (WidgetTester tester) async {
      AppConfig.environment = AppEnvironment.prod;
      AppClock.setMockTime(DateTime(2026, 3, 8, 9, 0));

      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      // Verify FAB exists and tap it
      expect(find.byType(FloatingActionButton), findsOneWidget);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Verify we navigated to CreateTaskScreen
      expect(find.byType(CreateTaskScreen), findsOneWidget);
      // Verify it defaulted to one-off schedule (tomorrow is 2026-03-09)
      expect(find.text('One-off on 2026-03-09'), findsOneWidget);
    },
  );

  testWidgets(
    'HomeScreen FAB on Schedule tab navigates to CreateTaskScreen defaulting to repeating',
    (WidgetTester tester) async {
      AppConfig.environment = AppEnvironment.prod;
      AppClock.setMockTime(DateTime(2026, 3, 8, 9, 0));

      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      // Switch to Schedule tab
      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();

      // Verify FAB exists and tap it
      expect(find.byType(FloatingActionButton), findsOneWidget);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Verify we navigated to CreateTaskScreen
      expect(find.byType(CreateTaskScreen), findsOneWidget);
      // Verify it defaulted to repeating daily schedule
      expect(find.text('Daily, every 1 day(s)'), findsOneWidget);
    },
  );

  group('URL path and params routing tests', () {
    testWidgets('routes to /tasks when path is /tasks', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createScreen(mockUri: Uri.parse('https://example.com/tasks')),
      );
      await tester.pumpAndSettle();

      final NavigationBar navBar = tester.widget(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 0);
      expect(find.byType(TaskListScreen), findsOneWidget);
    });

    testWidgets('routes to /schedules when path is /schedules', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createScreen(mockUri: Uri.parse('https://example.com/schedules')),
      );
      await tester.pumpAndSettle();

      final NavigationBar navBar = tester.widget(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 1);
      expect(find.byType(TaskScheduleScreen), findsOneWidget);
    });

    testWidgets('routes to /family when path is /family', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createScreen(mockUri: Uri.parse('https://example.com/family')),
      );
      await tester.pumpAndSettle();

      final NavigationBar navBar = tester.widget(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 2);
      expect(find.byType(FamilyScreen), findsOneWidget);
    });

    testWidgets('pushes SettingsScreen when path is /settings', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createScreen(mockUri: Uri.parse('https://example.com/settings')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets(
      'routes to /edit/<id> and pushes CreateTaskScreen with target task',
      (WidgetTester tester) async {
        final task = TaskSchedule(
          id: 'S-target-task-id',
          title: 'Target Task',
          description: 'Test target task',
        );
        tasksSubject.add([task]);

        await tester.pumpWidget(
          createScreen(
            mockUri: Uri.parse('https://example.com/edit/S-target-task-id'),
          ),
        );
        await tester.pump();
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();

        expect(find.byType(CreateTaskScreen), findsOneWidget);
        expect(find.text('Target Task'), findsOneWidget);
      },
    );

    testWidgets('routes to /new and pushes CreateTaskScreen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createScreen(mockUri: Uri.parse('https://example.com/new')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CreateTaskScreen), findsOneWidget);
    });

    testWidgets('routes to /tasks when path is empty /', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createScreen(mockUri: Uri.parse('https://example.com/')),
      );
      await tester.pumpAndSettle();

      final NavigationBar navBar = tester.widget(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 0);
    });
  });
}
