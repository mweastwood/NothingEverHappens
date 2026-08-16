import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:mockito/mockito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import '../test_helper.dart';

import 'package:nothing_ever_happens/logic/auth_repository.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/screens/task_schedule_screen.dart';
import 'package:nothing_ever_happens/screens/create_task_screen.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/user_settings.dart';
import 'package:nothing_ever_happens/logic/user_settings_repository.dart';

import 'package:nothing_ever_happens/logic/app_clock.dart';

import 'task_list_screen_test.mocks.dart';

void main() {
  late MockAuthRepository mockAuthRepository;
  late MockTaskRepository mockTaskRepository;
  late BehaviorSubject<List<TaskSchedule>> tasksSubject;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    mockTaskRepository = MockTaskRepository();

    tasksSubject = BehaviorSubject<List<TaskSchedule>>.seeded([]);

    when(mockTaskRepository.getTasks()).thenAnswer((_) => tasksSubject.stream);
    AppClock.setMockTime(DateTime(2026, 6, 22, 12, 0));
    addTearDown(AppClock.reset);
  });

  tearDown(() {
    tasksSubject.close();
  });

  Widget createScreen() {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepository),
        taskRepositoryProvider.overrideWithValue(mockTaskRepository),
      ],
      child: buildTestableWidget(
        child: const Scaffold(body: TaskScheduleScreen()),
      ),
    );
  }

  testWidgets('TaskScheduleScreen renders empty state when no tasks', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createScreen());
    await tester.pumpAndSettle();

    expect(find.text('No recurring tasks scheduled'), findsOneWidget);
  });

  testWidgets('TaskScheduleScreen renders list of recurring tasks', (
    WidgetTester tester,
  ) async {
    final dailyTask = TaskSchedule(
      id: '1',
      title: 'Daily TaskSchedule Title',
      description: 'Daily TaskSchedule Desc',
      schedules: [
        DailySchedule(
          startDate: const CivilDay(year: 2024, month: 1, day: 1),
          interval: 2,
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
    );

    final weeklyTask = TaskSchedule(
      id: '2',
      title: 'Weekly TaskSchedule Title',
      description: 'Weekly TaskSchedule Desc',
      schedules: [
        WeeklySchedule(
          startDate: const CivilDay(year: 2024, month: 1, day: 1),
          interval: 1,
          daysOfWeek: const {1, 3},
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 10, minute: 30),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 12, minute: 0),
          ),
        ),
      ],
    );

    final oneOffTask = TaskSchedule(
      id: '3',
      title: 'One-off TaskSchedule',
      description: 'Should not appear',
      schedules: [
        OneOffSchedule(
          date: const CivilDay(year: 2024, month: 1, day: 1),
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
    );

    tasksSubject.add([dailyTask, weeklyTask, oneOffTask]);

    await tester.pumpWidget(createScreen());
    await tester.pumpAndSettle();

    // Verify recurring tasks are rendered
    expect(find.text('Daily TaskSchedule Title'), findsOneWidget);
    expect(find.text('Weekly TaskSchedule Title'), findsOneWidget);

    // Verify one-off task is NOT rendered
    expect(find.text('One-off TaskSchedule'), findsNothing);

    // Verify schedule formatting details
    expect(find.text('Daily (Every 2 days)'), findsOneWidget);
    expect(find.text('Weekly'), findsOneWidget);
    expect(find.text('On: Mon, Wed'), findsOneWidget);

    // Verify times are formatted
    expect(find.text('9:00 AM -- 5:00 PM'), findsOneWidget);
    expect(find.text('10:30 AM -- 12:00 PM'), findsOneWidget);
  });

  testGoldens('TaskScheduleScreen empty state golden', (tester) async {
    final mockAuthRepository = MockAuthRepository();
    final mockTaskRepository = MockTaskRepository();

    when(mockTaskRepository.getTasks()).thenAnswer((_) => Stream.value([]));

    await tester.pumpWidgetBuilder(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          taskRepositoryProvider.overrideWithValue(mockTaskRepository),
        ],
        child: MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.zero,
            viewPadding: EdgeInsets.zero,
            viewInsets: EdgeInsets.zero,
          ),
          child: const Scaffold(body: TaskScheduleScreen()),
        ),
      ),
      wrapper: l10nMaterialAppWrapper(),
      surfaceSize: const Size(400, 800),
    );

    await screenMatchesGolden(tester, 'task_schedule_screen_empty');
  });

  testGoldens('TaskScheduleScreen populated state golden', (tester) async {
    final mockAuthRepository = MockAuthRepository();
    final mockTaskRepository = MockTaskRepository();

    final dailyTask = TaskSchedule(
      id: '1',
      title: 'Daily Exercises',
      description: 'Run 5km and do pushups',
      schedules: [
        DailySchedule(
          startDate: const CivilDay(year: 2024, month: 1, day: 1),
          interval: 1,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 7, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 8, minute: 30),
          ),
        ),
      ],
    );

    final weeklyTask = TaskSchedule(
      id: '2',
      title: 'Weekly Cleaning',
      description: 'Vacuum the house and dust the shelves',
      schedules: [
        WeeklySchedule(
          startDate: const CivilDay(year: 2024, month: 1, day: 1),
          interval: 1,
          daysOfWeek: const {6, 7},
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 10, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 12, minute: 0),
          ),
        ),
      ],
    );

    when(
      mockTaskRepository.getTasks(),
    ).thenAnswer((_) => Stream.value([dailyTask, weeklyTask]));

    await tester.pumpWidgetBuilder(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          taskRepositoryProvider.overrideWithValue(mockTaskRepository),
        ],
        child: MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.zero,
            viewPadding: EdgeInsets.zero,
            viewInsets: EdgeInsets.zero,
          ),
          child: const Scaffold(body: TaskScheduleScreen()),
        ),
      ),
      wrapper: l10nMaterialAppWrapper(),
      surfaceSize: const Size(400, 800),
    );

    await screenMatchesGolden(tester, 'task_schedule_screen_populated');
  });

  testWidgets(
    'TaskScheduleScreen delete button opens confirmation dialog and deletes task',
    (WidgetTester tester) async {
      final dailyTask = TaskSchedule(
        id: 'delete-recurring-task-1',
        title: 'Daily Exercises',
        description: 'Run 5km and do pushups',
        schedules: [
          DailySchedule(
            startDate: const CivilDay(year: 2024, month: 1, day: 1),
            interval: 1,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 7, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 8, minute: 30),
            ),
          ),
        ],
      );

      tasksSubject.add([dailyTask]);

      when(
        mockTaskRepository.deleteTaskSchedule('S-delete-recurring-task-1'),
      ).thenAnswer(
        (_) async => (task: dailyTask, pendingInstances: <TaskInstance>[]),
      );

      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      // Verify Delete Schedule Button is rendered
      final deleteButtonKey = const Key(
        'delete_schedule_button_S-delete-recurring-task-1',
      );
      expect(find.byKey(deleteButtonKey), findsOneWidget);

      // Tap Delete button
      await tester.tap(find.byKey(deleteButtonKey));
      await tester.pumpAndSettle();

      // Verify confirmation dialog is displayed
      expect(find.text('Delete Task?'), findsOneWidget);
      expect(
        find.text(
          'Are you sure you want to delete "Daily Exercises"? This action will permanently remove the task.',
        ),
        findsOneWidget,
      );

      // Tap confirm delete button in dialog
      final confirmDeleteKey = const Key(
        'confirm_delete_schedule_button_S-delete-recurring-task-1',
      );
      await tester.tap(find.byKey(confirmDeleteKey));
      await tester.pumpAndSettle();

      // Verify repository delete method was called with correct ID
      verify(
        mockTaskRepository.deleteTaskSchedule('S-delete-recurring-task-1'),
      ).called(1);
    },
  );

  testWidgets(
    'TaskScheduleScreen delete button opens confirmation dialog, deletes task, and undo restores it',
    (WidgetTester tester) async {
      final dailyTask = TaskSchedule(
        id: 'delete-recurring-task-1',
        title: 'Daily Exercises',
        description: 'Run 5km and do pushups',
        schedules: [
          DailySchedule(
            startDate: const CivilDay(year: 2024, month: 1, day: 1),
            interval: 1,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 7, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 8, minute: 30),
            ),
          ),
        ],
      );

      tasksSubject.add([dailyTask]);

      when(
        mockTaskRepository.deleteTaskSchedule('S-delete-recurring-task-1'),
      ).thenAnswer(
        (_) async => (task: dailyTask, pendingInstances: <TaskInstance>[]),
      );
      when(
        mockTaskRepository.restoreTaskSchedule(any, any),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      final deleteButtonKey = const Key(
        'delete_schedule_button_S-delete-recurring-task-1',
      );
      await tester.tap(find.byKey(deleteButtonKey));
      await tester.pumpAndSettle();

      final confirmDeleteKey = const Key(
        'confirm_delete_schedule_button_S-delete-recurring-task-1',
      );
      await tester.tap(find.byKey(confirmDeleteKey));
      await tester.pumpAndSettle();

      verify(
        mockTaskRepository.deleteTaskSchedule('S-delete-recurring-task-1'),
      ).called(1);

      // Verify SnackBar is shown
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      // Tap Undo
      await tester.tap(find.text('Undo'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify restoreTaskSchedule is called
      verify(mockTaskRepository.restoreTaskSchedule(dailyTask, any)).called(1);
    },
  );

  testWidgets(
    'TaskScheduleScreen shows arrow indicator only on active sort column and toggles correctly',
    (WidgetTester tester) async {
      final taskA = TaskSchedule(
        id: 'A',
        title: 'A Task',
        description: 'Desc',
        schedules: [
          DailySchedule(
            startDate: const CivilDay(year: 2024, month: 1, day: 1),
            interval: 1,
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
      );
      tasksSubject.add([taskA]);

      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      // 1. Initial State: Title ascending
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsNothing);

      // Verify avatar of Title chip has arrow_upward
      final titleChipFinder = find.widgetWithText(ChoiceChip, 'Title');
      final ChoiceChip titleChip = tester.widget(titleChipFinder);
      expect(titleChip.selected, isTrue);
      expect(titleChip.avatar, isNotNull);

      // Verify Priority, Next Start and Next Due chips are not selected and have no avatar
      final nextStartChipFinder = find.widgetWithText(ChoiceChip, 'Next Start');
      final ChoiceChip nextStartChip = tester.widget(nextStartChipFinder);
      expect(nextStartChip.selected, isFalse);
      expect(nextStartChip.avatar, isNull);

      final nextDueChipFinder = find.widgetWithText(ChoiceChip, 'Next Due');
      final ChoiceChip nextDueChip = tester.widget(nextDueChipFinder);
      expect(nextDueChip.selected, isFalse);
      expect(nextDueChip.avatar, isNull);

      final priorityChipFinder = find.widgetWithText(ChoiceChip, 'Priority');
      final ChoiceChip priorityChip = tester.widget(priorityChipFinder);
      expect(priorityChip.selected, isFalse);
      expect(priorityChip.avatar, isNull);

      // 2. Tap Title Chip again -> should toggle to descending
      await tester.ensureVisible(titleChipFinder);
      await tester.tap(titleChipFinder);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_upward), findsNothing);
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);

      final ChoiceChip updatedTitleChip = tester.widget(titleChipFinder);
      expect(updatedTitleChip.selected, isTrue);

      // 3. Tap Priority Chip -> should set priority ascending
      await tester.ensureVisible(priorityChipFinder);
      await tester.tap(priorityChipFinder);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsNothing);

      final ChoiceChip selectedPriorityChip = tester.widget(priorityChipFinder);
      expect(selectedPriorityChip.selected, isTrue);
      expect(selectedPriorityChip.avatar, isNotNull);

      final ChoiceChip unselectedTitleChip = tester.widget(titleChipFinder);
      expect(unselectedTitleChip.selected, isFalse);
      expect(unselectedTitleChip.avatar, isNull);
    },
  );

  testWidgets(
    'TaskScheduleScreen sorts by Title, Next Start, Next Due, and Priority correctly',
    (WidgetTester tester) async {
      TaskSchedule makeTask({
        required String id,
        required String title,
        required int startHour,
        required int dueHour,
        TaskPriority priority = TaskPriority.medium,
      }) {
        final startDate = const CivilDay(year: 2024, month: 1, day: 1);
        return TaskSchedule(
          id: id,
          title: title,
          description: 'Desc',
          priority: priority,
          schedules: [
            DailySchedule(
              startDate: startDate,
              interval: 1,
              startRelativeTime: RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: startHour, minute: 0),
              ),
              dueRelativeTime: RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: dueHour, minute: 0),
              ),
            ),
          ],
        );
      }

      final taskA = makeTask(
        id: 'A',
        title: 'Apple Task',
        startHour: 10,
        dueHour: 18,
        priority: TaskPriority.medium,
      );
      final taskB = makeTask(
        id: 'B',
        title: 'Banana Task',
        startHour: 8,
        dueHour: 20,
        priority: TaskPriority.high,
      );
      final taskC = makeTask(
        id: 'C',
        title: 'Cherry Task',
        startHour: 12,
        dueHour: 15,
        priority: TaskPriority.low,
      );

      tasksSubject.add([taskB, taskC, taskA]);

      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      List<String> getTitlesInOrder() {
        final List<({String title, double y})> items = [];
        for (final title in ['Apple Task', 'Banana Task', 'Cherry Task']) {
          final finder = find.text(title);
          if (finder.evaluate().isNotEmpty) {
            items.add((title: title, y: tester.getTopLeft(finder).dy));
          }
        }
        items.sort((a, b) => a.y.compareTo(b.y));
        return items.map((e) => e.title).toList();
      }

      // 1. Default sorting: Title ascending
      expect(getTitlesInOrder(), ['Apple Task', 'Banana Task', 'Cherry Task']);

      // Tap Title to make it descending
      final titleChipFinder = find.widgetWithText(ChoiceChip, 'Title');
      await tester.ensureVisible(titleChipFinder);
      await tester.tap(titleChipFinder);
      await tester.pumpAndSettle();
      expect(getTitlesInOrder(), ['Cherry Task', 'Banana Task', 'Apple Task']);

      // 2. Next Start sorting (Banana=8:00, Apple=10:00, Cherry=12:00)
      // Tap Next Start chip (first time: Next Start ascending)
      final nextStartChipFinder = find.widgetWithText(ChoiceChip, 'Next Start');
      await tester.ensureVisible(nextStartChipFinder);
      await tester.tap(nextStartChipFinder);
      await tester.pumpAndSettle();
      expect(getTitlesInOrder(), ['Banana Task', 'Apple Task', 'Cherry Task']);

      // Tap Next Start chip again (Next Start descending)
      await tester.ensureVisible(nextStartChipFinder);
      await tester.tap(nextStartChipFinder);
      await tester.pumpAndSettle();
      expect(getTitlesInOrder(), ['Cherry Task', 'Apple Task', 'Banana Task']);

      // 3. Next Due sorting (Cherry=15:00, Apple=18:00, Banana=20:00)
      // Tap Next Due chip (first time: Next Due ascending)
      final nextDueChipFinder = find.widgetWithText(ChoiceChip, 'Next Due');
      await tester.ensureVisible(nextDueChipFinder);
      await tester.tap(nextDueChipFinder);
      await tester.pumpAndSettle();
      expect(getTitlesInOrder(), ['Cherry Task', 'Apple Task', 'Banana Task']);

      // Tap Next Due chip again (Next Due descending)
      await tester.ensureVisible(nextDueChipFinder);
      await tester.tap(nextDueChipFinder);
      await tester.pumpAndSettle();
      expect(getTitlesInOrder(), ['Banana Task', 'Apple Task', 'Cherry Task']);

      // 4. Priority sorting (Low=0, Medium=1, High=2)
      // Tap Priority chip (first time: Priority ascending)
      final priorityChipFinder = find.widgetWithText(ChoiceChip, 'Priority');
      await tester.ensureVisible(priorityChipFinder);
      await tester.tap(priorityChipFinder);
      await tester.pumpAndSettle();
      expect(getTitlesInOrder(), ['Cherry Task', 'Apple Task', 'Banana Task']);

      // Tap Priority chip again (Priority descending)
      await tester.ensureVisible(priorityChipFinder);
      await tester.tap(priorityChipFinder);
      await tester.pumpAndSettle();
      expect(getTitlesInOrder(), ['Banana Task', 'Apple Task', 'Cherry Task']);
    },
  );

  testWidgets('TaskScheduleScreen maintains stable multi-key sorting history', (
    WidgetTester tester,
  ) async {
    final startDate = const CivilDay(year: 2024, month: 1, day: 1);
    final relTime = const RelativeTime(
      dayOffset: 0,
      time: TimeOfDay(hour: 9, minute: 0),
    );
    final defaultSchedule = [
      DailySchedule(
        startDate: startDate,
        interval: 1,
        startRelativeTime: relTime,
        dueRelativeTime: relTime,
      ),
    ];

    final task1 = TaskSchedule(
      id: '1',
      title: 'Banana',
      description: '',
      priority: TaskPriority.medium,
      schedules: defaultSchedule,
    );
    final task2 = TaskSchedule(
      id: '2',
      title: 'Apple',
      description: '',
      priority: TaskPriority.high,
      schedules: defaultSchedule,
    );
    final task3 = TaskSchedule(
      id: '3',
      title: 'Cherry',
      description: '',
      priority: TaskPriority.medium,
      schedules: defaultSchedule,
    );
    final task4 = TaskSchedule(
      id: '4',
      title: 'Date',
      description: '',
      priority: TaskPriority.high,
      schedules: defaultSchedule,
    );

    // Add them in mixed order to verify the stable sorting functions correctly.
    tasksSubject.add([task3, task1, task4, task2]);

    await tester.pumpWidget(createScreen());
    await tester.pumpAndSettle();

    List<String> getTitlesInOrder() {
      final List<({String title, double y})> items = [];
      for (final title in ['Apple', 'Banana', 'Cherry', 'Date']) {
        final finder = find.text(title);
        if (finder.evaluate().isNotEmpty) {
          items.add((title: title, y: tester.getTopLeft(finder).dy));
        }
      }
      items.sort((a, b) => a.y.compareTo(b.y));
      return items.map((e) => e.title).toList();
    }

    // 1. Initially sorted by Title ascending (default configuration)
    expect(getTitlesInOrder(), ['Apple', 'Banana', 'Cherry', 'Date']);

    // 2. Toggle Title to descending -> Title descending
    final titleChipFinder = find.widgetWithText(ChoiceChip, 'Title');
    await tester.ensureVisible(titleChipFinder);
    await tester.tap(titleChipFinder);
    await tester.pumpAndSettle();
    expect(getTitlesInOrder(), ['Date', 'Cherry', 'Banana', 'Apple']);

    // 3. Tap Priority (first time: ascending).
    // History queue: Priority (ascending), Title (descending).
    // Priorities order: medium, then high.
    // Within medium (Banana, Cherry) sorted by Title descending -> Cherry, Banana.
    // Within high (Apple, Date) sorted by Title descending -> Date, Apple.
    // Final order: Cherry, Banana, Date, Apple.
    final priorityChipFinder = find.widgetWithText(ChoiceChip, 'Priority');
    await tester.ensureVisible(priorityChipFinder);
    await tester.tap(priorityChipFinder);
    await tester.pumpAndSettle();
    expect(getTitlesInOrder(), ['Cherry', 'Banana', 'Date', 'Apple']);

    // 4. Tap Priority again (descending).
    // History queue: Priority (descending), Title (descending).
    // Priorities: high, then medium.
    // Within high (Apple, Date) sorted by Title descending -> Date, Apple.
    // Within medium (Banana, Cherry) sorted by Title descending -> Cherry, Banana.
    // Final expected order: Date, Apple, Cherry, Banana.
    await tester.ensureVisible(priorityChipFinder);
    await tester.tap(priorityChipFinder);
    await tester.pumpAndSettle();
    expect(getTitlesInOrder(), ['Date', 'Apple', 'Cherry', 'Banana']);

    // 5. Tap Title (ascending).
    // Since Title is now requested as ascending, and was already in history,
    // it gets promoted to the front with ascending: true.
    // History queue: Title (ascending), Priority (descending).
    // Since all titles are unique, it resolves purely by Title ascending.
    // Final expected order: Apple, Banana, Cherry, Date.
    await tester.ensureVisible(titleChipFinder);
    await tester.tap(titleChipFinder);
    await tester.pumpAndSettle();
    expect(getTitlesInOrder(), ['Apple', 'Banana', 'Cherry', 'Date']);
  });

  testWidgets(
    'TaskScheduleScreen displays lastSpawnedDate when showLastSpawnedDate setting is enabled',
    (WidgetTester tester) async {
      final dailyTask = TaskSchedule(
        id: '1',
        title: 'Daily Exercises',
        description: 'Run 5km and do pushups',
        lastSpawnedDate: const CivilDay(year: 2026, month: 6, day: 22),
        schedules: [
          DailySchedule(
            startDate: const CivilDay(year: 2024, month: 1, day: 1),
            interval: 1,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 7, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 8, minute: 30),
            ),
          ),
        ],
      );

      tasksSubject.add([dailyTask]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepository),
            taskRepositoryProvider.overrideWithValue(mockTaskRepository),
            userSettingsProvider.overrideWith(
              (ref) => Stream.value(
                const UserSettings(
                  hoursAvailable: 8.0,
                  showLastSpawnedDate: true,
                ),
              ),
            ),
          ],
          child: buildTestableWidget(
            child: const Scaffold(body: TaskScheduleScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('lastSpawnedDate: 2026-06-22'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'TaskScheduleScreen does not display lastSpawnedDate when showLastSpawnedDate setting is disabled',
    (WidgetTester tester) async {
      final dailyTask = TaskSchedule(
        id: '1',
        title: 'Daily Exercises',
        description: 'Run 5km and do pushups',
        lastSpawnedDate: const CivilDay(year: 2026, month: 6, day: 22),
        schedules: [
          DailySchedule(
            startDate: const CivilDay(year: 2024, month: 1, day: 1),
            interval: 1,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 7, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 8, minute: 30),
            ),
          ),
        ],
      );

      tasksSubject.add([dailyTask]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepository),
            taskRepositoryProvider.overrideWithValue(mockTaskRepository),
            userSettingsProvider.overrideWith(
              (ref) => Stream.value(
                const UserSettings(
                  hoursAvailable: 8.0,
                  showLastSpawnedDate: false,
                ),
              ),
            ),
          ],
          child: buildTestableWidget(
            child: const Scaffold(body: TaskScheduleScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('lastSpawnedDate:'), findsNothing);
    },
  );

  testWidgets(
    'TaskScheduleScreen copy button renders with proper tooltip and key',
    (WidgetTester tester) async {
      final dailyTask = TaskSchedule(
        id: 'task-copy-1',
        title: 'Daily Workout',
        description: 'Workout every morning',
        schedules: [
          DailySchedule(
            startDate: const CivilDay(year: 2024, month: 1, day: 1),
            interval: 1,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 7, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 8, minute: 0),
            ),
          ),
        ],
      );

      tasksSubject.add([dailyTask]);

      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      final copyButtonKey = const Key('copy_schedule_button_S-task-copy-1');
      expect(find.byKey(copyButtonKey), findsOneWidget);

      final iconButton = tester.widget<IconButton>(find.byKey(copyButtonKey));
      expect(iconButton.tooltip, 'Copy Schedule');
    },
  );

  testWidgets(
    'TaskScheduleScreen tapping copy button opens CreateTaskScreen pre-populated under a new ID and saves new task',
    (WidgetTester tester) async {
      final dailyTask = TaskSchedule(
        id: 'task-copy-2',
        title: 'Water Plants',
        description: 'Water indoor and balcony plants',
        priority: TaskPriority.high,
        estimatedDuration: const Duration(minutes: 25),
        schedules: [
          DailySchedule(
            id: 'R-water-orig',
            scheduleId: 'S-task-copy-2',
            startDate: const CivilDay(year: 2024, month: 1, day: 1),
            interval: 3,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 8, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
          ),
        ],
      );

      tasksSubject.add([dailyTask]);

      TaskSchedule? savedTask;
      when(mockTaskRepository.addTaskSchedule(any)).thenAnswer((
        invocation,
      ) async {
        savedTask = invocation.positionalArguments[0] as TaskSchedule;
      });

      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      // Tap copy button
      final copyButtonKey = const Key('copy_schedule_button_S-task-copy-2');
      await tester.tap(find.byKey(copyButtonKey));
      await tester.pumpAndSettle();

      // Verify CreateTaskScreen is opened
      expect(find.byType(CreateTaskScreen), findsOneWidget);

      // Verify pre-populated fields
      expect(find.text('Water Plants'), findsOneWidget);
      expect(find.text('Water indoor and balcony plants'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);

      // Save task
      final saveButton = find.text('Save');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Verify addTaskSchedule called with new TaskSchedule without mutating original
      verify(mockTaskRepository.addTaskSchedule(any)).called(1);
      verifyNever(mockTaskRepository.updateTaskSchedule(any));

      expect(savedTask, isNotNull);
      expect(savedTask!.id, isNot(equals('S-task-copy-2')));
      expect(savedTask!.title, 'Water Plants');
      expect(savedTask!.description, 'Water indoor and balcony plants');
      expect(savedTask!.priority, TaskPriority.high);
      expect(savedTask!.estimatedDuration, const Duration(minutes: 25));
      expect(savedTask!.schedules.length, 1);
      expect(savedTask!.schedules.first.id, isNot(equals('R-water-orig')));
      expect(savedTask!.schedules.first.scheduleId, savedTask!.id);
      expect((savedTask!.schedules.first as DailySchedule).interval, 3);
    },
  );

  testGoldens('TaskScheduleScreen populated with lastSpawnedDate golden', (
    tester,
  ) async {
    final mockAuthRepository = MockAuthRepository();
    final mockTaskRepository = MockTaskRepository();

    final dailyTask = TaskSchedule(
      id: '1',
      title: 'Daily Exercises',
      description: 'Run 5km and do pushups',
      lastSpawnedDate: const CivilDay(year: 2026, month: 6, day: 22),
      schedules: [
        DailySchedule(
          startDate: const CivilDay(year: 2024, month: 1, day: 1),
          interval: 1,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 7, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 8, minute: 30),
          ),
        ),
      ],
    );

    final weeklyTask = TaskSchedule(
      id: '2',
      title: 'Weekly Cleaning',
      description: 'Vacuum the house and dust the shelves',
      lastSpawnedDate: null,
      schedules: [
        WeeklySchedule(
          startDate: const CivilDay(year: 2024, month: 1, day: 1),
          interval: 1,
          daysOfWeek: const {6, 7},
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 10, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 12, minute: 0),
          ),
        ),
      ],
    );

    final tasksSubject = BehaviorSubject<List<TaskSchedule>>.seeded([
      dailyTask,
      weeklyTask,
    ], sync: true);
    final settingsSubject = BehaviorSubject<UserSettings>.seeded(
      const UserSettings(hoursAvailable: 8.0, showLastSpawnedDate: true),
      sync: true,
    );

    when(mockTaskRepository.getTasks()).thenAnswer((_) => tasksSubject.stream);

    await tester.pumpWidgetBuilder(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          taskRepositoryProvider.overrideWithValue(mockTaskRepository),
          userSettingsProvider.overrideWith((ref) => settingsSubject.stream),
        ],
        child: MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.zero,
            viewPadding: EdgeInsets.zero,
            viewInsets: EdgeInsets.zero,
          ),
          child: const Scaffold(body: TaskScheduleScreen()),
        ),
      ),
      wrapper: l10nMaterialAppWrapper(),
      surfaceSize: const Size(400, 800),
    );

    await tester.pumpAndSettle();

    await screenMatchesGolden(tester, 'task_schedule_screen_last_spawned_date');

    await tasksSubject.close();
    await settingsSubject.close();
  });
}
