import 'dart:async';
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
import 'package:nothing_ever_happens/logic/family_repository.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/screens/login_screen.dart';
import 'package:nothing_ever_happens/screens/settings_screen.dart';
import 'package:nothing_ever_happens/screens/home_screen.dart';
import 'package:nothing_ever_happens/screens/create_task_screen.dart';
import 'package:nothing_ever_happens/logic/subscription_service.dart';
import 'package:nothing_ever_happens/screens/help_screen.dart';

@GenerateNiceMocks([
  MockSpec<AuthRepository>(),
  MockSpec<TaskRepository>(),
  MockSpec<UserSettingsRepository>(),
])
import 'localization_es_goldens_test.mocks.dart';

void main() {
  late MockAuthRepository mockAuthRepository;
  late MockTaskRepository mockTaskRepository;
  late MockUserSettingsRepository mockUserSettingsRepository;

  late BehaviorSubject<List<TaskSchedule>> tasksSubject;
  late BehaviorSubject<List<TaskInstance>> instancesSubject;
  late BehaviorSubject<UserSettings> settingsSubject;

  final now = DateTime(2026, 6, 26, 10, 0);
  final taskDate = CivilDay.fromDateTime(now);

  setUp(() {
    AppClock.setMockTime(now);
    addTearDown(AppClock.reset);

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
    AppClock.reset();
    tasksSubject.close();
    instancesSubject.close();
    settingsSubject.close();
  });

  Widget buildEsWrapper(Widget child) {
    return l10nMaterialAppWrapper(
      localeOverrides: [const Locale('es')],
      theme: ThemeData.light(
        useMaterial3: true,
      ).copyWith(shadowColor: Colors.transparent),
    )(child);
  }

  testGoldens('Spanish Golden - LoginScreen', (tester) async {
    await tester.pumpWidgetBuilder(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          authStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const LoginScreen(),
      ),
      wrapper: buildEsWrapper,
      surfaceSize: const Size(400, 800),
    );

    await screenMatchesGolden(tester, 'login_screen_es');
  });

  testGoldens('Spanish Golden - SettingsScreen', (tester) async {
    await tester.pumpWidgetBuilder(
      ProviderScope(
        overrides: [
          userSettingsRepositoryProvider.overrideWithValue(
            mockUserSettingsRepository,
          ),
          authStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const SettingsScreen(),
      ),
      wrapper: buildEsWrapper,
      surfaceSize: const Size(400, 800),
    );

    await screenMatchesGolden(tester, 'settings_screen_es');
  });

  testGoldens('Spanish Golden - TaskListScreen (HomeScreen Tab 0)', (
    tester,
  ) async {
    final task = TaskSchedule(
      id: 'task-1',
      title: 'Comprar leche',
      description: 'Ir al supermercado a comprar leche descremada.',
      schedules: [
        OneOffSchedule(
          date: taskDate,
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
      priority: TaskPriority.high,
    );

    final instance = TaskInstance(
      id: 'inst-1',
      scheduleId: task.id,
      ruleId: task.schedules.first.id,
      title: task.title,
      description: task.description,
      scheduledDate: taskDate,
      startRelativeTime: task.schedules.first.startRelativeTime,
      dueRelativeTime: task.schedules.first.dueRelativeTime,
      priority: task.priority,
    );

    tasksSubject.add([task]);
    instancesSubject.add([instance]);

    final firestore = FakeFirebaseFirestore();
    final familyRepo = FamilyRepository(
      firestore: firestore,
      userId: 'user-1',
      userEmail: 'user1@example.com',
      userDisplayName: 'Alice',
    );

    await tester.pumpWidgetBuilder(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          taskRepositoryProvider.overrideWithValue(mockTaskRepository),
          userSettingsRepositoryProvider.overrideWithValue(
            mockUserSettingsRepository,
          ),
          familyRepositoryProvider.overrideWithValue(familyRepo),
          userSettingsProvider.overrideWith(
            (ref) => Stream.value(const UserSettings(hoursAvailable: 8.0)),
          ),
        ],
        child: const HomeScreen(),
      ),
      wrapper: buildEsWrapper,
      surfaceSize: const Size(400, 800),
    );

    await screenMatchesGolden(tester, 'task_list_screen_es');
  });

  testGoldens('Spanish Golden - TaskScheduleScreen (HomeScreen Tab 1)', (
    tester,
  ) async {
    final task = TaskSchedule(
      id: 'task-1',
      title: 'Sacar la basura',
      description: 'Cada dos días por la noche.',
      schedules: [
        DailySchedule(
          startDate: taskDate,
          interval: 2,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 20, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 21, minute: 0),
          ),
        ),
      ],
      priority: TaskPriority.medium,
    );

    tasksSubject.add([task]);

    final firestore = FakeFirebaseFirestore();
    final familyRepo = FamilyRepository(
      firestore: firestore,
      userId: 'user-1',
      userEmail: 'user1@example.com',
      userDisplayName: 'Alice',
    );

    await tester.pumpWidgetBuilder(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          taskRepositoryProvider.overrideWithValue(mockTaskRepository),
          userSettingsRepositoryProvider.overrideWithValue(
            mockUserSettingsRepository,
          ),
          familyRepositoryProvider.overrideWithValue(familyRepo),
          userSettingsProvider.overrideWith(
            (ref) => Stream.value(const UserSettings(hoursAvailable: 8.0)),
          ),
        ],
        child: const HomeScreen(),
      ),
      wrapper: buildEsWrapper,
      surfaceSize: const Size(400, 800),
    );

    // Tap on Calendario / Schedules Tab
    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();

    await screenMatchesGolden(tester, 'task_schedule_screen_es');
  });

  testGoldens('Spanish Golden - CreateTaskScreen (Repeating)', (tester) async {
    await tester.pumpWidgetBuilder(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(mockTaskRepository),
          familyRepositoryProvider.overrideWithValue(null),
          authStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const CreateTaskScreen(defaultToRepeating: true),
      ),
      wrapper: buildEsWrapper,
      surfaceSize: const Size(800, 1000),
    );

    await screenMatchesGolden(tester, 'create_task_screen_es');
  });

  testGoldens('Spanish Golden - DashboardScreen (HomeScreen Tab 2)', (
    tester,
  ) async {
    await tester.pumpWidgetBuilder(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          taskRepositoryProvider.overrideWithValue(mockTaskRepository),
          userSettingsRepositoryProvider.overrideWithValue(
            mockUserSettingsRepository,
          ),
          familyRepositoryProvider.overrideWithValue(null),
          userSettingsProvider.overrideWith(
            (ref) => Stream.value(
              const UserSettings(
                hoursAvailable: 8.0,
                defaultDailyCapacity: {'1': 2.0, '2': 1.5, '5': 4.0},
                dailyCapacityOverrides: {'2026-07-06': 0.0},
                lastCapacityConfirmedWeek: '2026-07-06',
              ),
            ),
          ),
        ],
        child: const HomeScreen(),
      ),
      wrapper: buildEsWrapper,
      surfaceSize: const Size(400, 800),
    );

    await tester.tap(find.byIcon(Icons.dashboard_outlined));
    await tester.pumpAndSettle();

    await screenMatchesGolden(tester, 'dashboard_screen_es');
  });

  testGoldens('Spanish Golden - FamilyScreen (HomeScreen Tab 3)', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final familyId = 'fam-123';

    // User is parent in a family with another member
    await firestore.collection('users').doc('user-1').set({
      'familyId': familyId,
      'familyRole': 'parent',
    });

    await firestore.collection('families').doc(familyId).set({
      'name': 'Los Simpson',
      'members': {
        'user-1': {
          'userId': 'user-1',
          'displayName': 'Alice',
          'email': 'user1@example.com',
          'role': 'parent',
        },
        'user-2': {
          'userId': 'user-2',
          'displayName': 'Bob',
          'email': 'bob@example.com',
          'role': 'non-parent',
        },
      },
    });

    final familyRepo = FamilyRepository(
      firestore: firestore,
      userId: 'user-1',
      userEmail: 'user1@example.com',
      userDisplayName: 'Alice',
    );

    await tester.pumpWidgetBuilder(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          taskRepositoryProvider.overrideWithValue(mockTaskRepository),
          userSettingsRepositoryProvider.overrideWithValue(
            mockUserSettingsRepository,
          ),
          familyRepositoryProvider.overrideWithValue(familyRepo),
          userSettingsProvider.overrideWith(
            (ref) => Stream.value(const UserSettings(hoursAvailable: 8.0)),
          ),
          subscriptionServiceProvider.overrideWith(
            (ref) => FakeSubscriptionService(ref, SubscriptionTier.family),
          ),
        ],
        child: const HomeScreen(),
      ),
      wrapper: buildEsWrapper,
      surfaceSize: const Size(400, 800),
    );

    // Tap on Familia / Family Tab
    await tester.tap(find.byIcon(Icons.people_outline));
    await tester.pumpAndSettle();

    await screenMatchesGolden(tester, 'family_screen_es');
  });

  testGoldens('Spanish Golden - HelpScreen', (tester) async {
    await tester.pumpWidgetBuilder(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          familyRepositoryProvider.overrideWithValue(null),
        ],
        child: const HelpScreen(),
      ),
      wrapper: buildEsWrapper,
      surfaceSize: const Size(600, 1000),
    );

    await screenMatchesGolden(tester, 'help_screen_es');
  });
}
