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
    TaskSchedule(
      id: 'S-3',
      title: 'Dentist Appointment',
      description: 'Routine dental checkup.',
      priority: TaskPriority.high,
      schedules: [
        OneOffSchedule(
          id: 'R-3',
          scheduleId: 'S-3',
          date: const CivilDay(year: 2026, month: 3, day: 12),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 14,
            minute: 0,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 15,
            minute: 30,
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
      scheduleId: 'S-3',
      ruleId: 'R-3',
      title: 'Dentist Appointment',
      description: 'Routine dental checkup.',
      priority: TaskPriority.high,
      scheduledDate: const CivilDay(year: 2026, month: 3, day: 12),
      startRelativeTime: const RelativeTime(dayOffset: 0, hour: 14, minute: 0),
      dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 15, minute: 30),
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
    'renders split month grid alongside live agenda pane with folded routines and highlighted one-off tasks',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Current month grid & live day pane are both visible
      expect(find.byKey(const Key('month_card_2026_3')), findsOneWidget);
      expect(find.byType(CalendarDayPane), findsOneWidget);
      expect(find.text('March 2026'), findsOneWidget);

      // Day 8 only has daily/weekly routine tasks -> collapsed under Routine & weekly
      expect(find.byKey(const Key('calendar_routine_toggle')), findsOneWidget);
      expect(find.text('Routine & weekly (2)'), findsOneWidget);
      expect(find.byKey(const Key('agenda_task_I-1')), findsNothing);

      // Expanding the routine drawer reveals routine tasks
      await tester.tap(find.byKey(const Key('calendar_routine_toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('agenda_task_I-1')), findsOneWidget);
      expect(find.byKey(const Key('agenda_task_I-2')), findsOneWidget);

      // Tapping Day 12 updates the live agenda to highlight the one-off Dentist Appointment
      await tester.tap(find.byKey(const Key('calendar_day_2026_3_12')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('agenda_task_I-3')), findsOneWidget);
      expect(find.text('Dentist Appointment'), findsOneWidget);
      // Month grid stays visible
      expect(find.byKey(const Key('month_card_2026_3')), findsOneWidget);
    },
  );

  testWidgets(
    'inline Agenda/Timeline toggle embeds CalendarDayTimelineView and supports full-screen expand/collapse',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Starts in Agenda mode
      expect(find.byType(CalendarDayTimelineView), findsNothing);

      // Switch inline toggle to Timeline
      await tester.tap(find.byKey(const Key('calendar_mode_timeline_button')));
      await tester.pumpAndSettle();

      // Embedded timeline is shown alongside the month grid
      expect(find.byType(CalendarDayTimelineView), findsOneWidget);
      expect(find.byKey(const Key('month_card_2026_3')), findsOneWidget);
      expect(find.byKey(const Key('timeline_task_I-1')), findsOneWidget);
      expect(find.byKey(const Key('timeline_task_I-2')), findsOneWidget);

      // Expand to full-screen timeline
      await tester.tap(
        find.byKey(const Key('calendar_expand_timeline_button')),
      );
      await tester.pumpAndSettle();

      final backButton = find.byKey(const Key('calendar_back_to_month_button'));
      expect(backButton, findsOneWidget);

      // Collapse back to split view
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('month_card_2026_3')), findsOneWidget);
      expect(find.byType(CalendarDayTimelineView), findsOneWidget);

      // Switch back to Agenda
      await tester.tap(find.byKey(const Key('calendar_mode_agenda_button')));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarDayTimelineView), findsNothing);
    },
  );

  testWidgets(
    'toggling task completion checkbox in embedded timeline calls complete and uncomplete without leaving timeline',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('calendar_mode_timeline_button')));
      await tester.pumpAndSettle();

      final timelineScope = find.byType(CalendarDayTimelineView);

      final uncheckedFinder = find.descendant(
        of: timelineScope,
        matching: find.byIcon(Icons.radio_button_unchecked),
      );
      expect(uncheckedFinder, findsOneWidget);
      await tester.tap(uncheckedFinder);
      await tester.pumpAndSettle();

      verify(mockTaskRepository.completeTaskInstance('I-2')).called(1);
      expect(find.byType(CalendarDayTimelineView), findsOneWidget);

      final checkedFinder = find.descendant(
        of: timelineScope,
        matching: find.byIcon(Icons.check_circle),
      );
      expect(checkedFinder, findsOneWidget);
      await tester.tap(checkedFinder);
      await tester.pumpAndSettle();

      verify(mockTaskRepository.uncompleteTaskInstance('I-1')).called(1);
      expect(find.byType(CalendarDayTimelineView), findsOneWidget);
    },
  );

  testWidgets('navigating months and tapping Today returns to current month', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('March 2026'), findsOneWidget);

    // Navigate to April 2026
    await tester.tap(find.byKey(const Key('calendar_next_month_button')));
    await tester.pumpAndSettle();
    expect(find.text('April 2026'), findsOneWidget);
    expect(find.byKey(const Key('month_card_2026_4')), findsOneWidget);

    // Tap Today to jump back to March 2026
    await tester.tap(find.byKey(const Key('calendar_jump_to_today_button')));
    await tester.pumpAndSettle();

    expect(find.text('March 2026'), findsOneWidget);
    expect(find.byKey(const Key('month_card_2026_3')), findsOneWidget);
  });

  testWidgets(
    'calendar month pager has PageStorageKey and directly renders current month',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(
        find.byKey(const PageStorageKey<String>('calendar_month_pager')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('month_card_2026_3')), findsOneWidget);
    },
  );

  testWidgets(
    'tapping "+ Add Task" in day pane navigates to CreateTaskScreen',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('calendar_pane_add_task_button')));
      await tester.pumpAndSettle();

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

      // Switch to Timeline on day 8
      await tester.tap(find.byKey(const Key('calendar_mode_timeline_button')));
      await tester.pumpAndSettle();

      expect(find.text('Skipped Task'), findsNothing);
      expect(find.text('Failed Task'), findsNothing);

      // Tap Day 10 in the month grid (no concrete instance, projected daily task S-1)
      await tester.tap(find.byKey(const Key('calendar_day_2026_3_10')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('timeline_task_projected_S-1_2026-03-10')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.event_repeat), findsWidgets);
    },
  );

  testWidgets(
    'daily timeline reactively updates when instance stream changes without reading stale cache',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('calendar_mode_timeline_button')));
      await tester.pumpAndSettle();

      final timelineScope = find.byType(CalendarDayTimelineView);
      expect(
        find.descendant(
          of: timelineScope,
          matching: find.byIcon(Icons.radio_button_unchecked),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: timelineScope,
          matching: find.byIcon(Icons.check_circle),
        ),
        findsOneWidget,
      );

      final updatedInstances = [
        sampleInstances[0],
        sampleInstances[1].copyWith(
          status: TaskStatus.completed,
          completedAt: DateTime(2026, 3, 8, 12, 0),
        ),
      ];
      instancesSubject.add(updatedInstances);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: timelineScope,
          matching: find.byIcon(Icons.check_circle),
        ),
        findsNWidgets(2),
      );
      expect(
        find.descendant(
          of: timelineScope,
          matching: find.byIcon(Icons.radio_button_unchecked),
        ),
        findsNothing,
      );
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

      await tester.pumpWidget(
        createTestWidget(currentUser: MockFirebaseUser('user-1')),
      );
      await tester.pumpAndSettle();

      // Family task with no rule is highlighted directly in Agenda
      expect(
        find.descendant(
          of: find.byKey(const Key('agenda_task_I-family-1')),
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

      await tester.pumpWidget(
        createTestWidget(currentUser: MockFirebaseUser('user-2')),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('agenda_task_I-family-2')),
          matching: find.byIcon(Icons.radio_button_unchecked),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'changing firstDayOfWeek in settings reactively updates month cards layout',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      settingsSubject.add(
        const UserSettings(
          hoursAvailable: 8.0,
          firstDayOfWeek: FirstDayOfWeek.sunday,
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final marchCardFinder = find.byWidgetPredicate(
        (w) =>
            w is CalendarMonthCard &&
            w.monthDate.year == 2026 &&
            w.monthDate.month == 3,
      );
      expect(marchCardFinder, findsOneWidget);

      CalendarMonthCard monthCard = tester.widget<CalendarMonthCard>(
        marchCardFinder,
      );
      expect(monthCard.firstDayOfWeek, equals(FirstDayOfWeek.sunday));

      settingsSubject.add(
        const UserSettings(
          hoursAvailable: 8.0,
          firstDayOfWeek: FirstDayOfWeek.monday,
        ),
      );
      await tester.pumpAndSettle();

      monthCard = tester.widget<CalendarMonthCard>(marchCardFinder);
      expect(monthCard.firstDayOfWeek, equals(FirstDayOfWeek.monday));
    },
  );

  group('CalendarDayTask.getTimeWindow', () {
    testWidgets(
      'formats time window correctly for concrete task instance (instance != null)',
      (tester) async {
        late BuildContext capturedContext;
        await tester.pumpWidget(
          buildTestableWidget(
            child: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox();
              },
            ),
          ),
        );

        final instance = TaskInstance(
          id: 'I-window-test',
          scheduleId: 'S-window-test',
          ruleId: 'R-window-test',
          title: 'Instance with time window',
          description: 'Testing instance time window',
          priority: TaskPriority.high,
          scheduledDate: const CivilDay(year: 2026, month: 3, day: 8),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 9,
            minute: 30,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 11,
            minute: 45,
          ),
          status: TaskStatus.pending,
        );

        final task = CalendarDayTask(
          id: 'task-instance',
          title: 'Instance with time window',
          priority: TaskPriority.high,
          isInstance: true,
          instance: instance,
        );

        expect(task.getTimeWindow(capturedContext), '9:30 AM – 11:45 AM');
      },
    );

    testWidgets(
      'formats time window correctly for projected recurring rule (matchingRule != null)',
      (tester) async {
        late BuildContext capturedContext;
        await tester.pumpWidget(
          buildTestableWidget(
            child: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox();
              },
            ),
          ),
        );

        final rule = DailySchedule(
          id: 'R-rule-window',
          scheduleId: 'S-rule-window',
          startDate: const CivilDay(year: 2026, month: 3, day: 1),
          interval: 1,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 14,
            minute: 0,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 15,
            minute: 30,
          ),
        );

        final task = CalendarDayTask(
          id: 'task-rule',
          title: 'Projected rule task',
          priority: TaskPriority.medium,
          isInstance: false,
          matchingRule: rule,
        );

        expect(task.getTimeWindow(capturedContext), '2:00 PM – 3:30 PM');
      },
    );

    testWidgets(
      'returns null when neither instance nor matchingRule is present (null fallback)',
      (tester) async {
        late BuildContext capturedContext;
        await tester.pumpWidget(
          buildTestableWidget(
            child: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox();
              },
            ),
          ),
        );

        const task = CalendarDayTask(
          id: 'task-empty',
          title: 'Fallback task',
          priority: TaskPriority.low,
          isInstance: false,
        );

        expect(task.getTimeWindow(capturedContext), isNull);
      },
    );
  });

  testWidgets(
    'agenda on a day with a skipped task instance does not show phantom unclickable recurring chore',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final skippedInstance = TaskInstance(
        id: 'I-skipped-only',
        scheduleId: 'S-1',
        ruleId: 'R-1',
        title: 'Water the Houseplants',
        description: 'Living room, kitchen, and balcony plants.',
        priority: TaskPriority.high,
        scheduledDate: const CivilDay(year: 2026, month: 3, day: 8),
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 8, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 12, minute: 0),
        status: TaskStatus.skipped,
      );

      instancesSubject.add([skippedInstance]);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Water the Houseplants was skipped on day 8; it must NOT be resurrected
      expect(find.text('Water the Houseplants'), findsNothing);
      expect(find.byKey(const Key('calendar_routine_toggle')), findsNothing);
    },
  );
}
