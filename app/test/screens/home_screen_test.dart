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
import 'package:nothing_ever_happens/logic/family_repository.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_delta.dart';

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
  late BehaviorSubject<List<TaskDelta>> historySubject;
  late BehaviorSubject<UserSettings> settingsSubject;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    mockTaskRepository = MockTaskRepository();
    mockUserSettingsRepository = MockUserSettingsRepository();

    tasksSubject = BehaviorSubject<List<TaskSchedule>>.seeded([]);
    instancesSubject = BehaviorSubject<List<TaskInstance>>.seeded([]);
    historySubject = BehaviorSubject<List<TaskDelta>>.seeded([]);
    settingsSubject = BehaviorSubject<UserSettings>.seeded(
      const UserSettings(hoursAvailable: 8.0),
    );

    when(mockAuthRepository.signOut()).thenAnswer((_) async {});
    when(mockTaskRepository.getTasks()).thenAnswer((_) => tasksSubject.stream);
    when(
      mockTaskRepository.getInstances(),
    ).thenAnswer((_) => instancesSubject.stream);
    when(
      mockTaskRepository.getHistory(),
    ).thenAnswer((_) => historySubject.stream);
    when(
      mockUserSettingsRepository.getSettings(),
    ).thenAnswer((_) => settingsSubject.stream);
  });

  tearDown(() {
    tasksSubject.close();
    instancesSubject.close();
    historySubject.close();
    settingsSubject.close();
  });

  Widget createScreen() {
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
}
