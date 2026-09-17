import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:mockito/mockito.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/logic/auth_repository.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/label_repository.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_filter.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_label.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/user_settings.dart';
import 'package:nothing_ever_happens/logic/user_settings_repository.dart';
import 'package:nothing_ever_happens/screens/task_list_screen.dart';
import 'package:nothing_ever_happens/widgets/sort_bar.dart';
import 'package:rxdart/rxdart.dart';

import 'task_list_screen_test.mocks.dart';
import 'home_screen_test.mocks.dart' as home_mocks;
import '../test_helper.dart';

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'user-1';
}

void main() {
  final testDate = DateTime(2026, 6, 15, 12, 0);

  final testLabels = [
    TaskLabel(
      id: 'L-work',
      name: 'Work',
      colorKey: 'coral',
      iconKey: 'work',
      scope: TaskLabelScope.personal,
      createdAt: DateTime(2026, 1, 1),
    ),
    TaskLabel(
      id: 'L-home',
      name: 'Home',
      colorKey: 'ocean',
      iconKey: 'home',
      scope: TaskLabelScope.personal,
      createdAt: DateTime(2026, 1, 1),
    ),
  ];

  final testInstances = [
    TaskInstance(
      id: 'I-1',
      scheduleId: 'S-1',
      ruleId: 'R-1',
      scheduledDate: CivilDay.fromDateTime(testDate),
      title: 'Quarterly Review',
      description: 'Prepare the financial slides',
      startRelativeTime: const RelativeTime(dayOffset: 0, hour: 8, minute: 0),
      dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 10, minute: 0),
      priority: TaskPriority.high,
      labelIds: const ['L-work'],
    ),
    TaskInstance(
      id: 'I-2',
      scheduleId: 'S-2',
      ruleId: 'R-2',
      scheduledDate: CivilDay.fromDateTime(testDate),
      title: 'Water the plants',
      description: 'Living room and balcony',
      startRelativeTime: const RelativeTime(dayOffset: 0, hour: 8, minute: 0),
      dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
      priority: TaskPriority.low,
      labelIds: const ['L-home'],
    ),
  ];

  final testSchedules = [
    TaskSchedule(
      id: 'S-1',
      title: 'Quarterly Review',
      description: 'Prepare the financial slides',
      priority: TaskPriority.high,
      labelIds: const ['L-work'],
    ),
    TaskSchedule(
      id: 'S-2',
      title: 'Water the plants',
      description: 'Living room and balcony',
      priority: TaskPriority.low,
      labelIds: const ['L-home'],
    ),
  ];

  late MockAuthRepository mockAuthRepository;
  late MockTaskRepository mockTaskRepository;
  late home_mocks.MockUserSettingsRepository mockUserSettingsRepository;
  late BehaviorSubject<List<TaskSchedule>> tasksSubject;
  late BehaviorSubject<List<TaskInstance>> instancesSubject;

  setUp(() {
    AppClock.setMockTime(testDate);
    mockAuthRepository = MockAuthRepository();
    mockTaskRepository = MockTaskRepository();
    mockUserSettingsRepository = home_mocks.MockUserSettingsRepository();

    tasksSubject = BehaviorSubject<List<TaskSchedule>>(sync: true)
      ..add(testSchedules);
    instancesSubject = BehaviorSubject<List<TaskInstance>>(sync: true)
      ..add(testInstances);

    when(mockAuthRepository.signOut()).thenAnswer((_) async {});
    when(mockTaskRepository.getTasks()).thenAnswer((_) => tasksSubject.stream);
    when(
      mockTaskRepository.getInstances(),
    ).thenAnswer((_) => instancesSubject.stream);
    when(
      mockUserSettingsRepository.getSettings(),
    ).thenAnswer((_) => Stream.value(const UserSettings(hoursAvailable: 8.0)));
  });

  tearDown(() {
    AppClock.reset();
    tasksSubject.close();
    instancesSubject.close();
  });

  List<Override> buildOverrides() => [
    taskRepositoryProvider.overrideWithValue(mockTaskRepository),
    userSettingsRepositoryProvider.overrideWithValue(
      mockUserSettingsRepository,
    ),
    userSettingsProvider.overrideWith(
      (ref) => Stream.value(
        const UserSettings(
          hoursAvailable: 8.0,
          showTaskListSortBar: true,
          lastCapacityConfirmedWeek: '2026-06-15',
        ),
      ),
    ),
    taskListSortBarOverrideProvider.overrideWith((ref) => true),
    taskSchedulesProvider.overrideWith((ref) => tasksSubject.stream),
    taskInstancesProvider.overrideWith((ref) => instancesSubject.stream),
    authStateProvider.overrideWith((ref) => Stream.value(_FakeUser())),
    personalLabelsStreamProvider.overrideWith(
      (ref) => Stream.value(
        testLabels.where((l) => l.scope == TaskLabelScope.personal).toList(),
      ),
    ),
    familyLabelsStreamProvider.overrideWith(
      (ref) => Stream.value(
        testLabels.where((l) => l.scope == TaskLabelScope.family).toList(),
      ),
    ),
  ];

  group('TaskListScreen Filtering Integration', () {
    testWidgets('Displays quick filter chips and filters by label', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: buildOverrides(),
          child: l10nMaterialAppWrapper()(const TaskListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Both tasks should be visible initially
      expect(find.text('Quarterly Review'), findsOneWidget);
      expect(find.text('Water the plants'), findsOneWidget);

      // Label chips should be in the sort/filter bar
      expect(find.text('Work'), findsWidgets);
      expect(find.text('Home'), findsWidgets);
      expect(find.text('Filter'), findsOneWidget);

      // Tap on the 'Work' filter chip in the bar
      final workChipFinder = find.widgetWithText(FilterChip, 'Work');
      await tester.tap(workChipFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Only 'Quarterly Review' should remain
      expect(find.text('Quarterly Review'), findsOneWidget);
      expect(find.text('Water the plants'), findsNothing);

      // Active filter count on the button should show 'Filter (1)'
      expect(find.text('Filter (1)'), findsOneWidget);
      expect(find.text('Clear filters'), findsNothing); // List not empty

      // Tap 'Clear' action chip in the bar
      expect(find.text('Clear'), findsOneWidget);
      await tester.tap(find.text('Clear'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Both tasks should be back
      expect(find.text('Quarterly Review'), findsOneWidget);
      expect(find.text('Water the plants'), findsOneWidget);
    });

    testWidgets(
      'Shows empty state when filters match nothing and allows clearing',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...buildOverrides(),
              // Start with an urgency that matches no tasks (e.g. upcoming tomorrow)
              taskFilterProvider.overrideWith(
                (ref) => const TaskFilterState(
                  selectedUrgencies: {TaskUrgencyFilter.upcoming},
                ),
              ),
            ],
            child: l10nMaterialAppWrapper()(const TaskListScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Should show empty state
        expect(find.text('No tasks match the active filters.'), findsOneWidget);
        expect(find.text('Clear filters'), findsOneWidget);

        // Tap Clear filters
        await tester.tap(find.text('Clear filters'));
        await tester.pumpAndSettle();

        // Both tasks restored
        expect(find.text('Quarterly Review'), findsOneWidget);
        expect(find.text('Water the plants'), findsOneWidget);
      },
    );

    testGoldens('TaskListScreen with Sort & Filter Bar Golden', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...buildOverrides(),
            taskFilterProvider.overrideWith(
              (ref) => const TaskFilterState(selectedLabelIds: {'L-work'}),
            ),
          ],
          child: l10nMaterialAppWrapper()(
            const Scaffold(body: TaskListScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, 'task_list_filtered_golden');
    });
  });
}
