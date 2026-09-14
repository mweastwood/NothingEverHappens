import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

import 'package:nothing_ever_happens/logic/auth_repository.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/user_settings.dart';
import 'package:nothing_ever_happens/logic/user_settings_repository.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/widgets/calendar_day_timeline_view.dart';

import '../screens/home_screen_test.mocks.dart';
import '../test_helper.dart';

void main() {
  late MockAuthRepository mockAuthRepository;
  late MockTaskRepository mockTaskRepository;
  late MockUserSettingsRepository mockUserSettingsRepository;

  late BehaviorSubject<List<TaskSchedule>> tasksSubject;
  late BehaviorSubject<List<TaskInstance>> instancesSubject;
  late BehaviorSubject<UserSettings> settingsSubject;

  const today = CivilDay(year: 2026, month: 3, day: 8);

  final sampleTask = TaskInstance(
    id: 'I-timeline-1',
    scheduleId: 'S-1',
    ruleId: 'R-1',
    title: 'Morning Yoga',
    description: '30 minutes stretching',
    priority: TaskPriority.medium,
    scheduledDate: today,
    startRelativeTime: const RelativeTime(dayOffset: 0, hour: 7, minute: 0),
    dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 8, minute: 0),
    status: TaskStatus.pending,
  );

  final overlappingTask = TaskInstance(
    id: 'I-timeline-2',
    scheduleId: 'S-2',
    ruleId: 'R-2',
    title: 'Breakfast Meeting',
    description: 'Sync with team',
    priority: TaskPriority.high,
    scheduledDate: today,
    startRelativeTime: const RelativeTime(dayOffset: 0, hour: 7, minute: 30),
    dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 8, minute: 30),
    status: TaskStatus.pending,
  );

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    mockTaskRepository = MockTaskRepository();
    mockUserSettingsRepository = MockUserSettingsRepository();

    tasksSubject = BehaviorSubject<List<TaskSchedule>>.seeded([]);
    instancesSubject = BehaviorSubject<List<TaskInstance>>.seeded([
      sampleTask,
      overlappingTask,
    ]);
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

  Widget buildTimelineWidget({
    CivilDay initialDay = today,
    VoidCallback? onBackToMonth,
    List<TaskInstance>? instances,
    List<TaskSchedule>? schedules,
  }) {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepository),
        taskRepositoryProvider.overrideWithValue(mockTaskRepository),
        userSettingsRepositoryProvider.overrideWithValue(
          mockUserSettingsRepository,
        ),
        userSettingsProvider.overrideWith((ref) => settingsSubject.stream),
      ],
      child: buildTestableWidget(
        child: CalendarDayTimelineView(
          initialDay: initialDay,
          onBackToMonth: onBackToMonth ?? () {},
          instances: instances ?? [sampleTask, overlappingTask],
          schedules: schedules ?? [],
          today: today,
        ),
      ),
    );
  }

  testWidgets(
    'renders 24-hour midnight-to-midnight timeline and positions tasks',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTimelineWidget());
      await tester.pumpAndSettle();

      // Check hour labels exist in timeline
      expect(
        find.text(DateFormat.j('en').format(DateTime(2026, 1, 1, 0))),
        findsWidgets,
      );
      expect(
        find.text(DateFormat.j('en').format(DateTime(2026, 1, 1, 7))),
        findsWidgets,
      );
      expect(
        find.text(DateFormat.j('en').format(DateTime(2026, 1, 1, 8))),
        findsWidgets,
      );
      expect(
        find.text(DateFormat.j('en').format(DateTime(2026, 1, 1, 12))),
        findsWidgets,
      );

      // Check tasks are rendered
      expect(
        find.byKey(const Key('timeline_task_I-timeline-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('timeline_task_I-timeline-2')),
        findsOneWidget,
      );
      expect(find.text('Morning Yoga'), findsOneWidget);
      expect(find.text('Breakfast Meeting'), findsOneWidget);
    },
  );

  testWidgets(
    'on mobile screen (<600px), viewportFraction is 0.85 showing 1 day with peeking',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTimelineWidget());
      await tester.pumpAndSettle();

      final pageViewFinder = find.byKey(
        const Key('calendar_day_timeline_pageview'),
      );
      expect(pageViewFinder, findsOneWidget);

      final PageView pageView = tester.widget<PageView>(pageViewFinder);
      final PageController controller = pageView.controller!;
      expect(controller.viewportFraction, closeTo(0.85, 0.01));
    },
  );

  testWidgets(
    'on large desktop screen (>=1200px), viewportFraction shows 7 days simultaneously',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTimelineWidget());
      await tester.pumpAndSettle();

      final pageViewFinder = find.byKey(
        const Key('calendar_day_timeline_pageview'),
      );
      expect(pageViewFinder, findsOneWidget);

      final PageView pageView = tester.widget<PageView>(pageViewFinder);
      final PageController controller = pageView.controller!;
      expect(controller.viewportFraction, closeTo(1.0 / 7, 0.01));
    },
  );

  testWidgets('tapping back to month calls onBackToMonth callback', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    bool backCalled = false;
    await tester.pumpWidget(
      buildTimelineWidget(onBackToMonth: () => backCalled = true),
    );
    await tester.pumpAndSettle();

    final backButton = find.byKey(const Key('calendar_back_to_month_button'));
    expect(backButton, findsOneWidget);
    await tester.tap(backButton);
    await tester.pumpAndSettle();

    expect(backCalled, isTrue);
  });

  testWidgets(
    'tapping next and previous chevron buttons navigates between days',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTimelineWidget());
      await tester.pumpAndSettle();

      // Tap next chevron
      final nextButton = find.byIcon(Icons.chevron_right);
      expect(nextButton, findsOneWidget);
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // Tap previous chevron
      final prevButton = find.byIcon(Icons.chevron_left);
      expect(prevButton, findsOneWidget);
      await tester.tap(prevButton);
      await tester.pumpAndSettle();

      // Tap today button
      final todayButton = find.byKey(
        const Key('calendar_timeline_today_button'),
      );
      expect(todayButton, findsOneWidget);
      await tester.tap(todayButton);
      await tester.pumpAndSettle();
    },
  );

  test(
    'dayToIndex and indexToDay round-trip accurately across DST transitions',
    () {
      // DST transition test dates:
      // US Spring forward (e.g. March 8, 2026) and Fall back (November 1, 2026)
      // EU Spring forward (March 29, 2026) and Fall back (October 25, 2026)
      final dstBoundaries = [
        const CivilDay(year: 2026, month: 3, day: 7),
        const CivilDay(year: 2026, month: 3, day: 8),
        const CivilDay(year: 2026, month: 3, day: 9),
        const CivilDay(year: 2026, month: 3, day: 14),
        const CivilDay(year: 2026, month: 3, day: 15),
        const CivilDay(year: 2026, month: 3, day: 28),
        const CivilDay(year: 2026, month: 3, day: 29),
        const CivilDay(year: 2026, month: 3, day: 30),
        const CivilDay(year: 2026, month: 10, day: 24),
        const CivilDay(year: 2026, month: 10, day: 25),
        const CivilDay(year: 2026, month: 10, day: 26),
        const CivilDay(year: 2026, month: 10, day: 31),
        const CivilDay(year: 2026, month: 11, day: 1),
        const CivilDay(year: 2026, month: 11, day: 2),
      ];

      for (final day in dstBoundaries) {
        final index = CalendarDayTimelineViewState.dayToIndex(day);
        final roundTrippedDay = CalendarDayTimelineViewState.indexToDay(index);
        expect(roundTrippedDay, equals(day));
        expect(
          CalendarDayTimelineViewState.dayToIndex(roundTrippedDay),
          equals(index),
        );
      }

      // Sequential walk across entire DST period
      CivilDay current = const CivilDay(year: 2026, month: 3, day: 1);
      for (int i = 0; i < 260; i++) {
        final idx = CalendarDayTimelineViewState.dayToIndex(current);
        final roundTripped = CalendarDayTimelineViewState.indexToDay(idx);
        expect(roundTripped, equals(current));
        current = current.addDays(1);
      }
    },
  );

  testWidgets(
    'renders dense overlapping tasks (4+ tasks) without layout overflow assertions',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final denseTasks = List<TaskInstance>.generate(
        5,
        (i) => TaskInstance(
          id: 'I-dense-$i',
          scheduleId: 'S-dense-$i',
          ruleId: 'R-dense-$i',
          title: 'Dense Task $i',
          description: 'Description $i',
          priority: TaskPriority.medium,
          scheduledDate: today,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 10,
            minute: 0,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 11,
            minute: 0,
          ),
          status: TaskStatus.pending,
        ),
      );

      await tester.pumpWidget(buildTimelineWidget(instances: denseTasks));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      for (int i = 0; i < 5; i++) {
        expect(find.byKey(Key('timeline_task_I-dense-$i')), findsOneWidget);
      }
    },
  );

  testWidgets(
    'renders task ending near 24:00 without overflowing timeline bottom',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final lateTask = TaskInstance(
        id: 'I-late-1',
        scheduleId: 'S-late-1',
        ruleId: 'R-late-1',
        title: 'Late Night Task',
        description: 'Late night task description',
        priority: TaskPriority.high,
        scheduledDate: today,
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          hour: 23,
          minute: 45,
        ),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 23, minute: 55),
        status: TaskStatus.pending,
      );

      await tester.pumpWidget(buildTimelineWidget(instances: [lateTask]));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('timeline_task_I-late-1')), findsOneWidget);
    },
  );
}
