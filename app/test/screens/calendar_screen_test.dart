import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'package:nothing_ever_happens/screens/create_task_screen.dart';
import 'package:nothing_ever_happens/logic/subscription_service.dart';

import 'home_screen_test.mocks.dart';

class MockFirebaseUser extends Fake implements User {
  final String _uid;
  MockFirebaseUser([this._uid = 'user-1']);

  @override
  String get uid => _uid;
}

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
      id: 'I-skipped',
      scheduleId: 'S-1',
      ruleId: 'R-1',
      title: 'Skipped Task',
      description: 'This task was skipped.',
      priority: TaskPriority.low,
      scheduledDate: const CivilDay(year: 2026, month: 3, day: 8),
      startRelativeTime: const RelativeTime(dayOffset: 0, hour: 13, minute: 0),
      dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 14, minute: 0),
      status: TaskStatus.skipped,
    ),
    TaskInstance(
      id: 'I-failed',
      scheduleId: 'S-1',
      ruleId: 'R-1',
      title: 'Failed Task',
      description: 'This task failed.',
      priority: TaskPriority.low,
      scheduledDate: const CivilDay(year: 2026, month: 3, day: 8),
      startRelativeTime: const RelativeTime(dayOffset: 0, hour: 15, minute: 0),
      dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 16, minute: 0),
      status: TaskStatus.failed,
    ),
  ];

  setUp(() {
    AppClock.setMockTime(fixedDate);
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
    when(
      mockTaskRepository.completeTaskInstance(any),
    ).thenAnswer((_) async => null);
    when(
      mockTaskRepository.uncompleteTaskInstance(any),
    ).thenAnswer((_) async => null);
  });

  tearDown(() {
    AppClock.reset();
    tasksSubject.close();
    instancesSubject.close();
    settingsSubject.close();
  });

  Widget createTestWidget({User? currentUser}) {
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
        authStateProvider.overrideWithValue(AsyncData<User?>(currentUser)),
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
      child: buildTestableWidget(child: const Scaffold(body: CalendarScreen())),
    );
  }

  testWidgets(
    'tapping a calendar day cell opens modal bottom sheet with expected tasks',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap on day 8 of current month
      final day8Finder = find.descendant(
        of: find.byKey(const Key('month_card_2026_3')),
        matching: find.text('8'),
      );
      expect(day8Finder, findsWidgets);
      await tester.tap(day8Finder.first);
      await tester.pumpAndSettle();

      // Verify bottom sheet title and tasks
      expect(find.textContaining('March 8, 2026'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Water the Houseplants'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Review Weekly Plan'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'toggling task completion checkbox calls complete and uncomplete without dismissing sheet',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Open day 8 bottom sheet of current month
      final day8Finder = find.descendant(
        of: find.byKey(const Key('month_card_2026_3')),
        matching: find.text('8'),
      );
      await tester.tap(day8Finder.first);
      await tester.pumpAndSettle();

      // I-2 is pending -> unchecked icon
      final uncheckedFinder = find.byIcon(Icons.radio_button_unchecked);
      expect(uncheckedFinder, findsOneWidget);
      await tester.tap(uncheckedFinder);
      await tester.pumpAndSettle();

      // Verify completeTaskInstance called with I-2
      verify(mockTaskRepository.completeTaskInstance('I-2')).called(1);

      // Verify sheet is STILL open (title still visible)
      expect(find.textContaining('March 8, 2026'), findsOneWidget);

      // I-1 is completed -> checked circle icon
      final checkedFinder = find.byIcon(Icons.check_circle);
      expect(checkedFinder, findsOneWidget);
      await tester.tap(checkedFinder);
      await tester.pumpAndSettle();

      // Verify uncompleteTaskInstance called with I-1
      verify(mockTaskRepository.uncompleteTaskInstance('I-1')).called(1);

      // Verify sheet is STILL open
      expect(find.textContaining('March 8, 2026'), findsOneWidget);
    },
  );

  testWidgets('tapping FAB jumps/scrolls towards current month', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    final fabFinder = find.byKey(const Key('calendar_jump_to_today_button'));
    expect(fabFinder, findsOneWidget);

    // Scroll away
    await tester.drag(find.byType(ListView), const Offset(0, 1000));
    await tester.pumpAndSettle();

    // Tap FAB
    await tester.tap(fabFinder);
    await tester.pumpAndSettle();

    // Verify current month (March 2026) is visible
    expect(find.byKey(const Key('month_card_2026_3')), findsOneWidget);
  });

  testWidgets(
    'tapping "+ Add Task" in bottom sheet navigates to CreateTaskScreen',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Open day 8 bottom sheet
      final day8Finder = find.descendant(
        of: find.byKey(const Key('month_card_2026_3')),
        matching: find.text('8'),
      );
      await tester.tap(day8Finder.first);
      await tester.pumpAndSettle();

      // Tap + button inside bottom sheet
      final addFinder = find.byIcon(Icons.add);
      expect(addFinder, findsOneWidget);
      await tester.tap(addFinder);
      await tester.pumpAndSettle();

      // Verify navigated to CreateTaskScreen
      expect(find.byType(CreateTaskScreen), findsOneWidget);
    },
  );

  testWidgets(
    'skipped and failed instances are filtered out while recurring schedules are projected',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Open day 8 bottom sheet (which has skipped and failed instances)
      final day8Finder = find.descendant(
        of: find.byKey(const Key('month_card_2026_3')),
        matching: find.text('8'),
      );
      await tester.tap(day8Finder.first);
      await tester.pumpAndSettle();

      // Verify Skipped Task and Failed Task are NOT displayed
      expect(find.text('Skipped Task'), findsNothing);
      expect(find.text('Failed Task'), findsNothing);

      // Close sheet
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      // March 10, 2026 is Tuesday. Daily task S-1 recurs every day.
      // Day 10 has NO concrete instance in sampleInstances, so it should be projected.
      final day10Finder = find.descendant(
        of: find.byKey(const Key('month_card_2026_3')),
        matching: find.text('10'),
      );
      await tester.tap(day10Finder.first);
      await tester.pumpAndSettle();

      // Verify projected Daily schedule appears
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Water the Houseplants'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byIcon(Icons.event_repeat),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'bottom sheet reactively updates when instance stream changes without reading stale cache',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Open day 8 bottom sheet
      final day8Finder = find.descendant(
        of: find.byKey(const Key('month_card_2026_3')),
        matching: find.text('8'),
      );
      await tester.tap(day8Finder.first);
      await tester.pumpAndSettle();

      // Initially, I-2 is pending (unchecked)
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      // Now stream an updated instances list where I-2 is completed
      final updatedInstances = [
        sampleInstances[0],
        sampleInstances[1].copyWith(
          status: TaskStatus.completed,
          completedAt: DateTime(2026, 3, 8, 12, 0),
        ),
      ];
      instancesSubject.add(updatedInstances);
      await tester.pumpAndSettle();

      // Because _getMonthTaskMap invalidates cache when instances change,
      // bottom sheet rebuild shows both tasks completed (2 check_circle icons).
      expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
      expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
    },
  );

  testWidgets(
    'family task completion status is completed for user who completed task',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final familyTask = TaskInstance(
        id: 'I-family-1',
        scheduleId: 'S-family',
        ruleId: 'R-family',
        title: 'Family Chore',
        description: 'Clean up the kitchen',
        priority: TaskPriority.high,
        scheduledDate: const CivilDay(year: 2026, month: 3, day: 8),
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 8, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 12, minute: 0),
        status: TaskStatus.pending,
        isFamily: true,
        familyCompletionMode: FamilyCompletionMode.individual,
        completedByUserIds: const ['user-1'],
      );

      instancesSubject.add([familyTask]);

      // Pump with user-1 (who completed the task)
      await tester.pumpWidget(
        createTestWidget(currentUser: MockFirebaseUser('user-1')),
      );
      await tester.pumpAndSettle();

      final day8Finder = find.descendant(
        of: find.byKey(const Key('month_card_2026_3')),
        matching: find.text('8'),
      );
      await tester.tap(day8Finder.first);
      await tester.pumpAndSettle();

      // For user-1, task should be completed (check_circle)
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byIcon(Icons.check_circle),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'family task completion status is incomplete for user who has not completed task',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final familyTask = TaskInstance(
        id: 'I-family-2',
        scheduleId: 'S-family',
        ruleId: 'R-family',
        title: 'Family Chore',
        description: 'Clean up the kitchen',
        priority: TaskPriority.high,
        scheduledDate: const CivilDay(year: 2026, month: 3, day: 8),
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 8, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 12, minute: 0),
        status: TaskStatus.pending,
        isFamily: true,
        familyCompletionMode: FamilyCompletionMode.individual,
        completedByUserIds: const ['user-1'],
      );

      instancesSubject.add([familyTask]);

      // Pump with user-2 (who has NOT completed the task)
      await tester.pumpWidget(
        createTestWidget(currentUser: MockFirebaseUser('user-2')),
      );
      await tester.pumpAndSettle();

      final day8Finder = find.descendant(
        of: find.byKey(const Key('month_card_2026_3')),
        matching: find.text('8'),
      );
      await tester.tap(day8Finder.first);
      await tester.pumpAndSettle();

      // For user-2, task should be incomplete (radio_button_unchecked)
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byIcon(Icons.radio_button_unchecked),
        ),
        findsOneWidget,
      );
    },
  );
}
