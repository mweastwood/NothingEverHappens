import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
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
import 'package:nothing_ever_happens/screens/calendar_screen.dart';
import 'package:nothing_ever_happens/logic/subscription_service.dart';

import 'home_screen_test.mocks.dart';

void main() {
  late MockAuthRepository mockAuthRepository;
  late MockTaskRepository mockTaskRepository;
  late MockUserSettingsRepository mockUserSettingsRepository;

  late BehaviorSubject<List<TaskSchedule>> tasksSubject;
  late BehaviorSubject<List<TaskInstance>> instancesSubject;
  late BehaviorSubject<UserSettings> settingsSubject;

  final fixedDate = DateTime(2026, 3, 8, 9, 0);

  final sampleTasks = [
    TaskSchedule(
      id: 'S-1',
      title: 'Water the Houseplants',
      description: 'Living room, kitchen, and balcony plants.',
      priority: TaskPriority.high,
      schedules: [
        DailySchedule(
          id: 'R-1',
          scheduleId: 'S-1',
          startDate: const CivilDay(year: 2026, month: 3, day: 1),
          interval: 1,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 8,
            minute: 0,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 12,
            minute: 0,
          ),
        ),
      ],
    ),
    TaskSchedule(
      id: 'S-2',
      title: 'Review Weekly Plan',
      description: 'Check calendar and meal schedule for the week.',
      priority: TaskPriority.medium,
      schedules: [
        WeeklySchedule(
          id: 'R-2',
          scheduleId: 'S-2',
          startDate: const CivilDay(year: 2026, month: 3, day: 1),
          interval: 1,
          daysOfWeek: {1, 3, 5},
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 9,
            minute: 0,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 17,
            minute: 0,
          ),
        ),
      ],
    ),
    TaskSchedule(
      id: 'S-3',
      title: 'Pay Utilities Bill',
      description: 'Electric and water bills.',
      priority: TaskPriority.high,
      schedules: [
        MonthlySchedule(
          id: 'R-3',
          scheduleId: 'S-3',
          startDate: const CivilDay(year: 2026, month: 3, day: 1),
          interval: 1,
          dayOfMonth: 15,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 10,
            minute: 0,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 18,
            minute: 0,
          ),
        ),
      ],
    ),
  ];

  final sampleInstances = [
    TaskInstance(
      id: 'I-1',
      scheduleId: 'S-1',
      ruleId: 'R-1',
      title: 'Water the Houseplants',
      description: 'Living room, kitchen, and balcony plants.',
      priority: TaskPriority.high,
      scheduledDate: const CivilDay(year: 2026, month: 3, day: 8),
      startRelativeTime: const RelativeTime(dayOffset: 0, hour: 8, minute: 0),
      dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 12, minute: 0),
      status: TaskStatus.completed,
      completedAt: DateTime(2026, 3, 8, 10, 30),
    ),
    TaskInstance(
      id: 'I-2',
      scheduleId: 'S-2',
      ruleId: 'R-2',
      title: 'Review Weekly Plan',
      description: 'Check calendar and meal schedule for the week.',
      priority: TaskPriority.medium,
      scheduledDate: const CivilDay(year: 2026, month: 3, day: 8),
      startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
      dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
      status: TaskStatus.pending,
    ),
    TaskInstance(
      id: 'I-3',
      scheduleId: 'S-1',
      ruleId: 'R-1',
      title: 'Grocery Shopping',
      description: 'Buy vegetables, fruits, and milk.',
      priority: TaskPriority.low,
      scheduledDate: const CivilDay(year: 2026, month: 3, day: 8),
      startRelativeTime: const RelativeTime(dayOffset: 0, hour: 14, minute: 0),
      dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 16, minute: 0),
      status: TaskStatus.pending,
    ),
    TaskInstance(
      id: 'I-4',
      scheduleId: 'S-1',
      ruleId: 'R-1',
      title: 'Water the Houseplants',
      description: 'Living room, kitchen, and balcony plants.',
      priority: TaskPriority.high,
      scheduledDate: const CivilDay(year: 2026, month: 3, day: 9),
      startRelativeTime: const RelativeTime(dayOffset: 0, hour: 8, minute: 0),
      dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 12, minute: 0),
      status: TaskStatus.pending,
    ),
    TaskInstance(
      id: 'I-5',
      scheduleId: 'S-2',
      ruleId: 'R-2',
      title: 'Review Weekly Plan',
      description: 'Check calendar and meal schedule for the week.',
      priority: TaskPriority.medium,
      scheduledDate: const CivilDay(year: 2026, month: 3, day: 9),
      startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
      dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
      status: TaskStatus.pending,
    ),
    TaskInstance(
      id: 'I-6',
      scheduleId: 'S-3',
      ruleId: 'R-3',
      title: 'Pay Utilities Bill',
      description: 'Electric and water bills.',
      priority: TaskPriority.high,
      scheduledDate: const CivilDay(year: 2026, month: 3, day: 15),
      startRelativeTime: const RelativeTime(dayOffset: 0, hour: 10, minute: 0),
      dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 18, minute: 0),
      status: TaskStatus.pending,
    ),
  ];

  setUp(() {
    AppClock.setMockTime(fixedDate);
    addTearDown(AppClock.reset);

    mockAuthRepository = MockAuthRepository();
    mockTaskRepository = MockTaskRepository();
    mockUserSettingsRepository = MockUserSettingsRepository();

    tasksSubject = BehaviorSubject<List<TaskSchedule>>.seeded(sampleTasks);
    instancesSubject = BehaviorSubject<List<TaskInstance>>.seeded(
      sampleInstances,
    );
    settingsSubject = BehaviorSubject<UserSettings>.seeded(
      const UserSettings(
        hoursAvailable: 8.0,
        lastCapacityConfirmedWeek: '2026-03-02',
      ),
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

  Widget createTestWidget({Brightness brightness = Brightness.light}) {
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
        userSettingsProvider.overrideWith((ref) => settingsSubject.stream),
        familyRepositoryProvider.overrideWithValue(familyRepo),
        subscriptionServiceProvider.overrideWith(
          (ref) => FakeSubscriptionService(ref, SubscriptionTier.family),
        ),
      ],
      child: const Scaffold(body: CalendarScreen()),
    );
  }

  testGoldens('CalendarScreen - Mobile Portrait (400x800) - Light Theme', (
    tester,
  ) async {
    await tester.pumpWidgetBuilder(
      createTestWidget(brightness: Brightness.light),
      wrapper: l10nMaterialAppWrapper(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.light,
          ),
        ),
      ),
      surfaceSize: const Size(400, 800),
    );
    await tester.pumpAndSettle();

    await screenMatchesGolden(tester, 'calendar_screen_mobile_portrait_light');
  });

  testGoldens('CalendarScreen - Mobile Portrait (400x800) - Dark Theme', (
    tester,
  ) async {
    await tester.pumpWidgetBuilder(
      createTestWidget(brightness: Brightness.dark),
      wrapper: l10nMaterialAppWrapper(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
        ),
      ),
      surfaceSize: const Size(400, 800),
    );
    await tester.pumpAndSettle();

    await screenMatchesGolden(tester, 'calendar_screen_mobile_portrait_dark');
  });

  testGoldens('CalendarScreen - Tablet Landscape (650x420)', (tester) async {
    await tester.pumpWidgetBuilder(
      createTestWidget(brightness: Brightness.light),
      wrapper: l10nMaterialAppWrapper(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.light,
          ),
        ),
      ),
      surfaceSize: const Size(650, 420),
    );
    await tester.pumpAndSettle();

    await screenMatchesGolden(tester, 'calendar_screen_tablet_landscape');
  });

  testGoldens(
    'CalendarScreen - Wide Screen Two Columns (900x600) - Light Theme',
    (tester) async {
      await tester.pumpWidgetBuilder(
        createTestWidget(brightness: Brightness.light),
        wrapper: l10nMaterialAppWrapper(
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.light,
            ),
          ),
        ),
        surfaceSize: const Size(900, 600),
      );
      await tester.pumpAndSettle();

      await screenMatchesGolden(
        tester,
        'calendar_screen_wide_two_columns_light',
      );
    },
  );

  testGoldens(
    'CalendarScreen - Wide Screen Two Columns (900x600) - Dark Theme',
    (tester) async {
      await tester.pumpWidgetBuilder(
        createTestWidget(brightness: Brightness.dark),
        wrapper: l10nMaterialAppWrapper(
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
            ),
          ),
        ),
        surfaceSize: const Size(900, 600),
      );
      await tester.pumpAndSettle();

      await screenMatchesGolden(
        tester,
        'calendar_screen_wide_two_columns_dark',
      );
    },
  );

  testGoldens('CalendarScreen - Desktop Large Screen (1200x800)', (
    tester,
  ) async {
    await tester.pumpWidgetBuilder(
      createTestWidget(brightness: Brightness.light),
      wrapper: l10nMaterialAppWrapper(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.light,
          ),
        ),
      ),
      surfaceSize: const Size(1200, 800),
    );
    await tester.pumpAndSettle();

    await screenMatchesGolden(tester, 'calendar_screen_desktop_large');
  });

  testGoldens('CalendarScreen - Day Details Bottom Sheet (400x800)', (
    tester,
  ) async {
    await tester.pumpWidgetBuilder(
      createTestWidget(brightness: Brightness.light),
      wrapper: l10nMaterialAppWrapper(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.light,
          ),
        ),
      ),
      surfaceSize: const Size(400, 800),
    );
    await tester.pumpAndSettle();

    // Tap on Day 8 (March 8, 2026 - today)
    await tester.tap(find.text('8').first);
    await tester.pumpAndSettle();

    await screenMatchesGolden(tester, 'calendar_screen_day_details_sheet');
  });
}
