import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:mockito/mockito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import '../test_helper.dart';

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
import 'package:nothing_ever_happens/widgets/sort_bar.dart';

import 'task_list_screen_test.mocks.dart';
import 'home_screen_test.mocks.dart' as home_mocks;

void main() {
  late MockAuthRepository mockAuthRepository;
  late MockTaskRepository mockTaskRepository;
  late home_mocks.MockUserSettingsRepository mockUserSettingsRepository;
  late BehaviorSubject<List<TaskSchedule>> tasksSubject;
  late BehaviorSubject<List<TaskInstance>> instancesSubject;
  late BehaviorSubject<UserSettings> settingsSubject;

  final fixedDate = DateTime(2026, 3, 8, 9, 0);

  final testTasks = [
    TaskSchedule(
      id: 'S-1',
      title: 'Water the Houseplants',
      description: 'Give them water',
      schedules: [
        DailySchedule(
          id: 'R-1',
          scheduleId: 'S-1',
          startDate: const CivilDay(year: 2026, month: 3, day: 1),
          interval: 1,
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
    ),
    TaskSchedule(
      id: 'S-2',
      title: 'Buy Groceries',
      description: 'Milk, Eggs, Bread',
      schedules: [
        DailySchedule(
          id: 'R-2',
          scheduleId: 'S-2',
          startDate: const CivilDay(year: 2026, month: 3, day: 1),
          interval: 1,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 8, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 12, minute: 0),
          ),
        ),
      ],
    ),
  ];

  final testInstances = [
    TaskInstance(
      id: 'S-1_R-1_2026-03-08',
      scheduleId: 'S-1',
      ruleId: 'R-1',
      title: 'Water the Houseplants',
      description: 'Give them water',
      scheduledDate: const CivilDay(year: 2026, month: 3, day: 8),
      startRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 10, minute: 0),
      ),
      dueRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 17, minute: 0),
      ),
      status: TaskStatus.pending,
    ),
    TaskInstance(
      id: 'S-2_R-2_2026-03-08',
      scheduleId: 'S-2',
      ruleId: 'R-2',
      title: 'Buy Groceries',
      description: 'Milk, Eggs, Bread',
      scheduledDate: const CivilDay(year: 2026, month: 3, day: 8),
      startRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 8, minute: 0),
      ),
      dueRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 12, minute: 0),
      ),
      status: TaskStatus.pending,
    ),
  ];

  const defaultSettings = UserSettings(hoursAvailable: 8.0);

  setUp(() async {
    await loadAppFonts();
    AppClock.setMockTime(fixedDate);
    addTearDown(AppClock.reset);
    AppConfig.environment = AppEnvironment.prod;

    mockAuthRepository = MockAuthRepository();
    mockTaskRepository = MockTaskRepository();
    mockUserSettingsRepository = home_mocks.MockUserSettingsRepository();

    tasksSubject = BehaviorSubject<List<TaskSchedule>>.seeded(testTasks);
    instancesSubject = BehaviorSubject<List<TaskInstance>>.seeded(
      testInstances,
    );
    settingsSubject = BehaviorSubject<UserSettings>.seeded(defaultSettings);

    when(
      mockAuthRepository.authStateChanges,
    ).thenAnswer((_) => Stream.value(null));
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
    AppConfig.environment = AppEnvironment.dev;
    tasksSubject.close();
    instancesSubject.close();
    settingsSubject.close();
  });

  Widget createTestApp({
    required int initialTab,
    required bool sortBarVisible,
    required bool capacityPromptVisible,
  }) {
    if (!capacityPromptVisible) {
      settingsSubject.add(
        UserSettings(
          hoursAvailable: 8.0,
          lastCapacityConfirmedWeek: '2026-03-02',
          showTaskListSortBar: sortBarVisible,
          showScheduleListSortBar: sortBarVisible,
        ),
      );
    } else {
      settingsSubject.add(
        UserSettings(
          hoursAvailable: 8.0,
          lastCapacityConfirmedWeek: '',
          showTaskListSortBar: sortBarVisible,
          showScheduleListSortBar: sortBarVisible,
        ),
      );
    }

    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepository),
        taskRepositoryProvider.overrideWithValue(mockTaskRepository),
        userSettingsRepositoryProvider.overrideWithValue(
          mockUserSettingsRepository,
        ),
        homeTabIndexProvider.overrideWith((ref) => initialTab),
        showTaskListSortBarProvider.overrideWith((ref) => sortBarVisible),
        showScheduleListSortBarProvider.overrideWith((ref) => sortBarVisible),
        showSortBarProvider.overrideWith((ref) => sortBarVisible),
      ],
      child: buildTestableWidget(child: const HomeScreen()),
    );
  }

  testGoldens(
    'Golden Card Spacing - Tasks Tab (Sort Bar Visible + Capacity Prompt Visible)',
    (tester) async {
      tester.view.physicalSize = const Size(400, 750);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestApp(
          initialTab: 0,
          sortBarVisible: true,
          capacityPromptVisible: true,
        ),
      );
      await tester.pumpAndSettle();

      await screenMatchesGolden(
        tester,
        'golden_card_spacing_tasks_sort_and_capacity',
      );
    },
  );

  testGoldens(
    'Golden Card Spacing - Tasks Tab (Sort Bar Visible + Capacity Prompt Hidden)',
    (tester) async {
      tester.view.physicalSize = const Size(400, 750);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestApp(
          initialTab: 0,
          sortBarVisible: true,
          capacityPromptVisible: false,
        ),
      );
      await tester.pumpAndSettle();

      await screenMatchesGolden(
        tester,
        'golden_card_spacing_tasks_sort_no_capacity',
      );
    },
  );

  testGoldens(
    'Golden Card Spacing - Tasks Tab (Sort Bar Hidden + Capacity Prompt Visible)',
    (tester) async {
      tester.view.physicalSize = const Size(400, 750);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestApp(
          initialTab: 0,
          sortBarVisible: false,
          capacityPromptVisible: true,
        ),
      );
      await tester.pumpAndSettle();

      await screenMatchesGolden(
        tester,
        'golden_card_spacing_tasks_no_sort_with_capacity',
      );
    },
  );

  testGoldens('Golden Card Spacing - Schedule Tab (Sort Bar Visible)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 750);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      createTestApp(
        initialTab: 1,
        sortBarVisible: true,
        capacityPromptVisible: false,
      ),
    );
    await tester.pumpAndSettle();

    await screenMatchesGolden(
      tester,
      'golden_card_spacing_schedule_sort_visible',
    );
  });

  testGoldens('Golden Card Spacing - Schedule Tab (Sort Bar Hidden)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 750);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      createTestApp(
        initialTab: 1,
        sortBarVisible: false,
        capacityPromptVisible: false,
      ),
    );
    await tester.pumpAndSettle();

    await screenMatchesGolden(
      tester,
      'golden_card_spacing_schedule_sort_hidden',
    );
  });
}
