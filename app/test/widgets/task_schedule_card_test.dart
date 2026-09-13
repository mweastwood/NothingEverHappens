import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';

import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/family.dart';
import 'package:nothing_ever_happens/logic/family_repository.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/user_profile_provider.dart';
import 'package:nothing_ever_happens/logic/user_settings.dart';
import 'package:nothing_ever_happens/logic/user_settings_repository.dart';
import 'package:nothing_ever_happens/widgets/task_schedule_card.dart';

import '../screens/task_list_screen_test.mocks.dart';
import '../test_helper.dart';

void main() {
  late MockTaskRepository mockTaskRepository;

  setUp(() {
    mockTaskRepository = MockTaskRepository();
  });

  final dailyTask = TaskSchedule(
    id: 'S-daily',
    title: 'Daily Task Title',
    description: '**Bold description**',
    estimatedDuration: const Duration(hours: 1, minutes: 30),
    lastSpawnedDate: const CivilDay(year: 2024, month: 6, day: 15),
    schedules: [
      DailySchedule(
        id: 'rule-daily',
        scheduleId: 'S-daily',
        startDate: const CivilDay(year: 2024, month: 1, day: 1),
        interval: 2,
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
      ),
    ],
  );

  final weeklyTask = TaskSchedule(
    id: 'S-weekly',
    title: 'Weekly Task Title',
    description: 'Weekly chore',
    estimatedDuration: const Duration(minutes: 45),
    schedules: [
      WeeklySchedule(
        id: 'rule-weekly',
        scheduleId: 'S-weekly',
        startDate: const CivilDay(year: 2024, month: 1, day: 1),
        interval: 1,
        daysOfWeek: {1, 3},
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          hour: 10,
          minute: 0,
        ),
        dueRelativeTime: const RelativeTime(dayOffset: 1, hour: 12, minute: 0),
      ),
    ],
  );

  final monthlyDayTask = TaskSchedule(
    id: 'S-monthly-day',
    title: 'Monthly Day Task',
    description: '',
    schedules: [
      MonthlySchedule(
        id: 'rule-mday',
        scheduleId: 'S-monthly-day',
        startDate: const CivilDay(year: 2024, month: 1, day: 1),
        interval: 1,
        dayOfMonth: 15,
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 8, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
      ),
    ],
  );

  final monthlyOccTask = TaskSchedule(
    id: 'S-monthly-occ',
    title: 'Monthly Occurrence Task',
    description: '',
    schedules: [
      MonthlySchedule(
        id: 'rule-mocc',
        scheduleId: 'S-monthly-occ',
        startDate: const CivilDay(year: 2024, month: 1, day: 1),
        interval: 2,
        occurrence: 1,
        dayOfWeek: 1,
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 8, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
      ),
    ],
  );

  final yearlyTask = TaskSchedule(
    id: 'S-yearly',
    title: 'Yearly Task Title',
    description: '',
    schedules: [
      YearlySchedule(
        id: 'rule-yearly',
        scheduleId: 'S-yearly',
        startDate: const CivilDay(year: 2024, month: 1, day: 1),
        interval: 1,
        month: 12,
        day: 25,
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 8, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
      ),
    ],
  );

  final oneOffTask = TaskSchedule(
    id: 'S-oneoff',
    title: 'One-Off Task Title',
    description: '',
    schedules: [
      OneOffSchedule(
        id: 'rule-oneoff',
        scheduleId: 'S-oneoff',
        date: const CivilDay(year: 2024, month: 5, day: 10),
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 8, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
      ),
    ],
  );

  final familyTask = TaskSchedule(
    id: 'S-family',
    title: 'Family Chore',
    description: 'Family chore description',
    isFamily: true,
    familyCompletionMode: FamilyCompletionMode.individual,
    assignedUserId: 'user-alice',
    schedules: [
      DailySchedule(
        id: 'rule-family',
        scheduleId: 'S-family',
        startDate: const CivilDay(year: 2024, month: 1, day: 1),
        interval: 1,
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 8, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
      ),
    ],
  );

  group('TaskScheduleCard Layout and Recurrence Rendering', () {
    testWidgets(
      'renders daily schedule, markdown, duration, and last spawned date',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              taskRepositoryProvider.overrideWithValue(mockTaskRepository),
            ],
            child: buildTestableWidget(
              child: Scaffold(
                body: SingleChildScrollView(
                  child: TaskScheduleCard(
                    task: dailyTask,
                    showLastSpawnedDate: true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Daily Task Title'), findsOneWidget);
        expect(find.byType(MarkdownBody), findsOneWidget);
        expect(find.textContaining('1 hr 30 min'), findsOneWidget);
        expect(find.textContaining('Every 2 days'), findsOneWidget);
        expect(
          find.textContaining('lastSpawnedDate: 2024-06-15'),
          findsOneWidget,
        );
      },
    );

    testWidgets('hides lastSpawnedDate when showLastSpawnedDate is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskRepositoryProvider.overrideWithValue(mockTaskRepository),
          ],
          child: buildTestableWidget(
            child: Scaffold(
              body: SingleChildScrollView(
                child: TaskScheduleCard(
                  task: dailyTask,
                  showLastSpawnedDate: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('lastSpawnedDate'), findsNothing);
    });

    testWidgets(
      'resolves showLastSpawnedDate from userSettingsProvider when omitted',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              taskRepositoryProvider.overrideWithValue(mockTaskRepository),
              userSettingsProvider.overrideWith(
                (ref) => Stream.value(
                  UserSettings(hoursAvailable: 8.0, showLastSpawnedDate: true),
                ),
              ),
            ],
            child: buildTestableWidget(
              child: Scaffold(
                body: SingleChildScrollView(
                  child: TaskScheduleCard(task: dailyTask),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('lastSpawnedDate: 2024-06-15'),
          findsOneWidget,
        );
      },
    );

    testWidgets('renders weekly schedule and relative time day offsets', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskRepositoryProvider.overrideWithValue(mockTaskRepository),
          ],
          child: buildTestableWidget(
            child: Scaffold(
              body: SingleChildScrollView(
                child: TaskScheduleCard(task: weeklyTask),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Weekly Task Title'), findsOneWidget);
      expect(find.text('Weekly'), findsOneWidget);
      expect(find.textContaining('Mon, Wed'), findsOneWidget);
      expect(find.textContaining('(+1)'), findsOneWidget);
      expect(find.textContaining('45 min'), findsOneWidget);
    });

    testWidgets('renders monthly schedule by day of month', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskRepositoryProvider.overrideWithValue(mockTaskRepository),
          ],
          child: buildTestableWidget(
            child: Scaffold(
              body: SingleChildScrollView(
                child: TaskScheduleCard(task: monthlyDayTask),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Monthly Day Task'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.textContaining('On day 15'), findsOneWidget);
    });

    testWidgets('renders monthly schedule by nth occurrence', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskRepositoryProvider.overrideWithValue(mockTaskRepository),
          ],
          child: buildTestableWidget(
            child: Scaffold(
              body: SingleChildScrollView(
                child: TaskScheduleCard(task: monthlyOccTask),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Monthly Occurrence Task'), findsOneWidget);
      expect(find.textContaining('Every 2 months'), findsOneWidget);
      expect(find.textContaining('Monday'), findsOneWidget);
    });

    testWidgets('renders yearly and one-off schedules correctly', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskRepositoryProvider.overrideWithValue(mockTaskRepository),
          ],
          child: buildTestableWidget(
            child: Scaffold(
              body: Column(
                children: [
                  TaskScheduleCard(task: yearlyTask),
                  TaskScheduleCard(task: oneOffTask),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Yearly Task Title'), findsOneWidget);
      expect(find.text('Yearly'), findsOneWidget);
      expect(find.textContaining('December'), findsOneWidget);
      expect(find.textContaining('25'), findsOneWidget);

      expect(find.text('One-Off Task Title'), findsOneWidget);
      expect(find.text('One-off'), findsOneWidget);
    });
  });

  group('TaskScheduleCard Badging', () {
    testWidgets('renders family, individual mode, and assigned user badges', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskRepositoryProvider.overrideWithValue(mockTaskRepository),
            userNameProvider(
              'user-alice',
            ).overrideWith((ref) => Future.value('Alice')),
          ],
          child: buildTestableWidget(
            child: Scaffold(
              body: SingleChildScrollView(
                child: TaskScheduleCard(task: familyTask, isParent: true),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Family'), findsOneWidget);
      expect(find.text('Everyone individually'), findsOneWidget);
      expect(find.text('Assigned to Alice'), findsOneWidget);
    });
  });

  group('TaskScheduleCard Actions & Permissions', () {
    testWidgets(
      'triggers onCopy, onEdit, and onDelete custom callbacks when provided',
      (tester) async {
        bool copyCalled = false;
        bool editCalled = false;
        bool deleteCalled = false;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              taskRepositoryProvider.overrideWithValue(mockTaskRepository),
            ],
            child: buildTestableWidget(
              child: Scaffold(
                body: SingleChildScrollView(
                  child: TaskScheduleCard(
                    task: dailyTask,
                    onCopy: () => copyCalled = true,
                    onEdit: () => editCalled = true,
                    onDelete: () => deleteCalled = true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('copy_schedule_button_S-daily')));
        expect(copyCalled, isTrue);

        await tester.tap(find.byKey(const Key('edit_schedule_button_S-daily')));
        expect(editCalled, isTrue);

        await tester.tap(
          find.byKey(const Key('delete_schedule_button_S-daily')),
        );
        expect(deleteCalled, isTrue);
      },
    );

    testWidgets('hides delete button for family task when user is non-parent', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskRepositoryProvider.overrideWithValue(mockTaskRepository),
            familyProfileStreamProvider.overrideWith(
              (ref) => Stream.value(
                const FamilyProfile(familyId: 'fam1', familyRole: 'member'),
              ),
            ),
          ],
          child: buildTestableWidget(
            child: Scaffold(
              body: SingleChildScrollView(
                child: TaskScheduleCard(task: familyTask),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('delete_schedule_button_S-family')),
        findsNothing,
      );
    });

    testWidgets(
      'shows delete button for family task when isParent is overridden to true',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              taskRepositoryProvider.overrideWithValue(mockTaskRepository),
            ],
            child: buildTestableWidget(
              child: Scaffold(
                body: SingleChildScrollView(
                  child: TaskScheduleCard(task: familyTask, isParent: true),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('delete_schedule_button_S-family')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'shows delete confirmation dialog and executes delete with UndoSnackBar',
      (tester) async {
        when(mockTaskRepository.deleteTaskSchedule('S-daily')).thenAnswer(
          (_) async => (task: dailyTask, pendingInstances: <TaskInstance>[]),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              taskRepositoryProvider.overrideWithValue(mockTaskRepository),
            ],
            child: buildTestableWidget(
              child: Scaffold(
                body: SingleChildScrollView(
                  child: TaskScheduleCard(
                    task: dailyTask,
                    repository: mockTaskRepository,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap delete button to open confirmation dialog
        await tester.tap(
          find.byKey(const Key('delete_schedule_button_S-daily')),
        );
        await tester.pumpAndSettle();

        // Dialog is displayed
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.byKey(const Key('confirm_delete_schedule_button_S-daily')),
          findsOneWidget,
        );

        // Confirm delete
        await tester.tap(
          find.byKey(const Key('confirm_delete_schedule_button_S-daily')),
        );
        await tester.pumpAndSettle();

        verify(mockTaskRepository.deleteTaskSchedule('S-daily')).called(1);
        // UndoSnackBar is displayed
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('Undo'), findsOneWidget);
      },
    );

    testWidgets('canceling delete dialog does not execute deleteTaskSchedule', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskRepositoryProvider.overrideWithValue(mockTaskRepository),
          ],
          child: buildTestableWidget(
            child: Scaffold(
              body: SingleChildScrollView(
                child: TaskScheduleCard(
                  task: dailyTask,
                  repository: mockTaskRepository,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('delete_schedule_button_S-daily')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      verifyNever(mockTaskRepository.deleteTaskSchedule(any));
    });
  });
}
