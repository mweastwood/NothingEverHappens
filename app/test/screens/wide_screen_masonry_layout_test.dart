import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/auth_repository.dart';
import 'package:nothing_ever_happens/logic/user_settings_repository.dart';
import 'package:nothing_ever_happens/logic/user_settings.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/screens/task_list_screen.dart';
import 'package:nothing_ever_happens/screens/task_schedule_screen.dart';
import 'package:nothing_ever_happens/widgets/smooth_shuffle_item.dart';

import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import '../test_helper.dart';

import 'home_screen_test.mocks.dart' as home_mocks;

@GenerateMocks([TaskRepository, AuthRepository])
import 'wide_screen_masonry_layout_test.mocks.dart';

void main() {
  late MockTaskRepository mockTaskRepository;
  late MockAuthRepository mockAuthRepository;
  late home_mocks.MockUserSettingsRepository mockUserSettingsRepository;

  setUp(() {
    SmoothShuffleItem.clearPositions();
    mockTaskRepository = MockTaskRepository();
    mockAuthRepository = MockAuthRepository();
    mockUserSettingsRepository = home_mocks.MockUserSettingsRepository();

    when(
      mockAuthRepository.authStateChanges,
    ).thenAnswer((_) => Stream.value(null));
  });

  group('Wide Screen Independent 2-Column Layout Tests', () {
    testWidgets(
      'TaskListScreen wide screen allows independent vertical heights without grid gaps',
      (WidgetTester tester) async {
        // Task 1 (left) is long description -> tall card
        // Task 2 (right) is short description -> short card
        // Task 4 (right) should start right below Task 2, NOT forced down to Task 1 bottom
        final tasks = [
          TaskSchedule(
            id: '1',
            title: 'Task 1 Tall',
            description:
                'Paragraph 1\n\nParagraph 2\n\nParagraph 3\n\nParagraph 4\n\nParagraph 5',
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
          ),
          TaskSchedule(
            id: '2',
            title: 'Task 2 Short',
            description: 'Short',
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
          ),
          TaskSchedule(
            id: '3',
            title: 'Task 3 Below Tall',
            description: 'Left col item 2',
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
          ),
          TaskSchedule(
            id: '4',
            title: 'Task 4 Below Short',
            description: 'Right col item 2',
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
          ),
        ];

        final instances = [
          TaskInstance(
            id: 'I-1',
            scheduleId: '1',
            ruleId: 'R-1',
            title: 'Task 1 Tall',
            description:
                'Paragraph 1\n\nParagraph 2\n\nParagraph 3\n\nParagraph 4\n\nParagraph 5',
            scheduledDate: const CivilDay(year: 2024, month: 1, day: 1),
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.pending,
          ),
          TaskInstance(
            id: 'I-2',
            scheduleId: '2',
            ruleId: 'R-2',
            title: 'Task 2 Short',
            description: 'Short',
            scheduledDate: const CivilDay(year: 2024, month: 1, day: 1),
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.pending,
          ),
          TaskInstance(
            id: 'I-3',
            scheduleId: '3',
            ruleId: 'R-3',
            title: 'Task 3 Below Tall',
            description: 'Left col item 2',
            scheduledDate: const CivilDay(year: 2024, month: 1, day: 1),
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.pending,
          ),
          TaskInstance(
            id: 'I-4',
            scheduleId: '4',
            ruleId: 'R-4',
            title: 'Task 4 Below Short',
            description: 'Right col item 2',
            scheduledDate: const CivilDay(year: 2024, month: 1, day: 1),
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.pending,
          ),
        ];

        when(
          mockTaskRepository.getTasks(),
        ).thenAnswer((_) => Stream.value(tasks));
        when(
          mockTaskRepository.getInstances(),
        ).thenAnswer((_) => Stream.value(instances));
        when(mockUserSettingsRepository.getSettings()).thenAnswer(
          (_) => Stream.value(const UserSettings(hoursAvailable: 8.0)),
        );

        tester.view.physicalSize = const Size(1000, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(mockAuthRepository),
              taskRepositoryProvider.overrideWithValue(mockTaskRepository),
              userSettingsRepositoryProvider.overrideWithValue(
                mockUserSettingsRepository,
              ),
              userSettingsProvider.overrideWith(
                (ref) => Stream.value(const UserSettings(hoursAvailable: 8.0)),
              ),
            ],
            child: buildTestableWidget(child: const TaskListScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Get bounds of all 4 tasks
        final rect1 = tester.getRect(find.text('Task 1 Tall'));
        final rect2 = tester.getRect(find.text('Task 2 Short'));
        final rect3 = tester.getRect(find.text('Task 3 Below Tall'));
        final rect4 = tester.getRect(find.text('Task 4 Below Short'));

        // Height-balanced assignment:
        // Left column: Task 1 (Tall) and Task 4
        // Right column: Task 2 (Short) and Task 3 (placed on shorter right column)
        expect(rect1.left, rect4.left);
        expect(rect2.left, rect3.left);
        expect(rect2.left, greaterThan(rect1.left));

        // Task 3 under short Task 2 starts higher than Task 4 under tall Task 1
        expect(rect3.top, lessThan(rect4.top));
      },
    );

    testWidgets(
      'TaskScheduleScreen wide screen allows independent vertical heights without grid gaps',
      (WidgetTester tester) async {
        final tasks = [
          TaskSchedule(
            id: 'S-1',
            title: 'Schedule 1 Tall',
            description:
                'Paragraph 1\n\nParagraph 2\n\nParagraph 3\n\nParagraph 4\n\nParagraph 5',
            schedules: [
              DailySchedule(
                id: 'R-1',
                scheduleId: 'S-1',
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
          ),
          TaskSchedule(
            id: 'S-2',
            title: 'Schedule 2 Short',
            description: 'Short',
            schedules: [
              DailySchedule(
                id: 'R-2',
                scheduleId: 'S-2',
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
          ),
          TaskSchedule(
            id: 'S-3',
            title: 'Schedule 3 Below Tall',
            description: 'Left 2',
            schedules: [
              DailySchedule(
                id: 'R-3',
                scheduleId: 'S-3',
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
          ),
          TaskSchedule(
            id: 'S-4',
            title: 'Schedule 4 Below Short',
            description: 'Right 2',
            schedules: [
              DailySchedule(
                id: 'R-4',
                scheduleId: 'S-4',
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
          ),
        ];

        when(
          mockTaskRepository.getTasks(),
        ).thenAnswer((_) => Stream.value(tasks));
        when(mockUserSettingsRepository.getSettings()).thenAnswer(
          (_) => Stream.value(const UserSettings(hoursAvailable: 8.0)),
        );

        tester.view.physicalSize = const Size(1000, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(mockAuthRepository),
              taskRepositoryProvider.overrideWithValue(mockTaskRepository),
              userSettingsRepositoryProvider.overrideWithValue(
                mockUserSettingsRepository,
              ),
              userSettingsProvider.overrideWith(
                (ref) => Stream.value(const UserSettings(hoursAvailable: 8.0)),
              ),
            ],
            child: buildTestableWidget(child: const TaskScheduleScreen()),
          ),
        );
        await tester.pumpAndSettle();

        final rect1 = tester.getRect(find.text('Schedule 1 Tall'));
        final rect2 = tester.getRect(find.text('Schedule 2 Short'));
        final rect3 = tester.getRect(find.text('Schedule 3 Below Tall'));
        final rect4 = tester.getRect(find.text('Schedule 4 Below Short'));

        // Height-balanced assignment:
        // Left column: Schedule 1 (Tall) and Schedule 4
        // Right column: Schedule 2 (Short) and Schedule 3 (placed on shorter right column)
        expect(rect1.left, rect4.left);
        expect(rect2.left, rect3.left);
        expect(rect2.left, greaterThan(rect1.left));

        // Schedule 3 starts higher than Schedule 4 because Schedule 2 is shorter
        expect(rect3.top, lessThan(rect4.top));
      },
    );

    testWidgets(
      'TaskListScreen balances columns by height so last task fills shorter column',
      (WidgetTester tester) async {
        // T1 (Left): Tall description
        // T2 (Right): Very tall description (2 tall tasks worth)
        // T3 (Right): Short
        // T4 (Left): Short
        // T5 (Left): Should be placed in Left column because Right column is taller overall
        final tasks = [
          TaskSchedule(
            id: '1',
            title: 'Task 1 Medium',
            description: 'Paragraph 1\n\nParagraph 2',
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
          ),
          TaskSchedule(
            id: '2',
            title: 'Task 2 Extra Tall',
            description:
                'Paragraph 1\n\nParagraph 2\n\nParagraph 3\n\nParagraph 4\n\nParagraph 5\n\nParagraph 6\n\nParagraph 7\n\nParagraph 8',
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
          ),
          TaskSchedule(
            id: '3',
            title: 'Task 3 Short',
            description: 'Short',
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
          ),
        ];

        final instances = [
          TaskInstance(
            id: 'I-1',
            scheduleId: '1',
            ruleId: 'R-1',
            title: 'Task 1 Medium',
            description: 'Paragraph 1\n\nParagraph 2',
            scheduledDate: const CivilDay(year: 2024, month: 1, day: 1),
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.pending,
          ),
          TaskInstance(
            id: 'I-2',
            scheduleId: '2',
            ruleId: 'R-2',
            title: 'Task 2 Extra Tall',
            description:
                'Paragraph 1\n\nParagraph 2\n\nParagraph 3\n\nParagraph 4\n\nParagraph 5\n\nParagraph 6\n\nParagraph 7\n\nParagraph 8',
            scheduledDate: const CivilDay(year: 2024, month: 1, day: 1),
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.pending,
          ),
          TaskInstance(
            id: 'I-3',
            scheduleId: '3',
            ruleId: 'R-3',
            title: 'Task 3 Short',
            description: 'Short',
            scheduledDate: const CivilDay(year: 2024, month: 1, day: 1),
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.pending,
          ),
        ];

        when(
          mockTaskRepository.getTasks(),
        ).thenAnswer((_) => Stream.value(tasks));
        when(
          mockTaskRepository.getInstances(),
        ).thenAnswer((_) => Stream.value(instances));
        when(mockUserSettingsRepository.getSettings()).thenAnswer(
          (_) => Stream.value(const UserSettings(hoursAvailable: 8.0)),
        );

        tester.view.physicalSize = const Size(1000, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(mockAuthRepository),
              taskRepositoryProvider.overrideWithValue(mockTaskRepository),
              userSettingsRepositoryProvider.overrideWithValue(
                mockUserSettingsRepository,
              ),
              userSettingsProvider.overrideWith(
                (ref) => Stream.value(const UserSettings(hoursAvailable: 8.0)),
              ),
            ],
            child: buildTestableWidget(child: const TaskListScreen()),
          ),
        );
        await tester.pumpAndSettle();

        final rect1 = tester.getRect(find.text('Task 1 Medium'));
        final rect2 = tester.getRect(find.text('Task 2 Extra Tall'));
        final rect3 = tester.getRect(find.text('Task 3 Short'));

        // Task 1 on Left, Task 2 on Right (very tall).
        // Task 3 is placed in Left column because Left column is shorter than Right column!
        expect(rect1.left, rect3.left);
        expect(rect2.left, greaterThan(rect1.left));
      },
    );

    testGoldens(
      'TaskListScreen wide screen masonry layout with uneven heights golden',
      (WidgetTester tester) async {
        final tasks = [
          TaskSchedule(
            id: '1',
            title: 'Clean & Organize Garage Workshop',
            description:
                '1. Sort hand tools onto pegboard\n2. Sweep wood shavings and dust\n3. Organize storage bins on metal shelving\n4. Dispose of hazardous chemical waste safely',
            priority: TaskPriority.high,
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
          ),
          TaskSchedule(
            id: '2',
            title: 'Water Indoor Houseplants',
            description: 'Living room monstera and ferns.',
            priority: TaskPriority.low,
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
          ),
          TaskSchedule(
            id: '3',
            title: 'Take Out Recycling & Compost',
            description: 'Sort plastics and place curbside before 8 AM.',
            priority: TaskPriority.medium,
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
          ),
          TaskSchedule(
            id: '4',
            title: 'Weekly Meal Planning & Grocery List',
            description:
                'Check pantry inventory for staple items, fresh produce, and spices before heading to the market.',
            priority: TaskPriority.medium,
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
          ),
        ];

        final instances = [
          TaskInstance(
            id: 'I-1',
            scheduleId: '1',
            ruleId: 'R-1',
            title: 'Clean & Organize Garage Workshop',
            description:
                '1. Sort hand tools onto pegboard\n2. Sweep wood shavings and dust\n3. Organize storage bins on metal shelving\n4. Dispose of hazardous chemical waste safely',
            priority: TaskPriority.high,
            scheduledDate: const CivilDay(year: 2024, month: 1, day: 1),
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.pending,
          ),
          TaskInstance(
            id: 'I-2',
            scheduleId: '2',
            ruleId: 'R-2',
            title: 'Water Indoor Houseplants',
            description: 'Living room monstera and ferns.',
            priority: TaskPriority.low,
            scheduledDate: const CivilDay(year: 2024, month: 1, day: 1),
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.pending,
          ),
          TaskInstance(
            id: 'I-3',
            scheduleId: '3',
            ruleId: 'R-3',
            title: 'Take Out Recycling & Compost',
            description: 'Sort plastics and place curbside before 8 AM.',
            priority: TaskPriority.medium,
            scheduledDate: const CivilDay(year: 2024, month: 1, day: 1),
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.pending,
          ),
          TaskInstance(
            id: 'I-4',
            scheduleId: '4',
            ruleId: 'R-4',
            title: 'Weekly Meal Planning & Grocery List',
            description:
                'Check pantry inventory for staple items, fresh produce, and spices before heading to the market.',
            priority: TaskPriority.medium,
            scheduledDate: const CivilDay(year: 2024, month: 1, day: 1),
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: TaskStatus.pending,
          ),
        ];

        when(
          mockTaskRepository.getTasks(),
        ).thenAnswer((_) => Stream.value(tasks));
        when(
          mockTaskRepository.getInstances(),
        ).thenAnswer((_) => Stream.value(instances));
        when(mockUserSettingsRepository.getSettings()).thenAnswer(
          (_) => Stream.value(const UserSettings(hoursAvailable: 8.0)),
        );

        await tester.pumpWidgetBuilder(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(mockAuthRepository),
              taskRepositoryProvider.overrideWithValue(mockTaskRepository),
              userSettingsRepositoryProvider.overrideWithValue(
                mockUserSettingsRepository,
              ),
              userSettingsProvider.overrideWith(
                (ref) => Stream.value(const UserSettings(hoursAvailable: 8.0)),
              ),
            ],
            child: const TaskListScreen(),
          ),
          wrapper: l10nMaterialAppWrapper(),
          surfaceSize: const Size(900, 600),
        );
        await tester.pumpAndSettle();

        await screenMatchesGolden(
          tester,
          'task_list_screen_wide_masonry_uneven_heights',
        );
      },
    );

    testGoldens(
      'TaskScheduleScreen wide screen masonry layout with uneven heights golden',
      (WidgetTester tester) async {
        final tasks = [
          TaskSchedule(
            id: 'S-1',
            title: 'Vehicle Maintenance Inspection',
            description:
                '• Check tire pressure (35 psi)\n• Top up windshield washer fluid\n• Inspect engine oil level and filter\n• Test turn signals and brake lights',
            priority: TaskPriority.high,
            schedules: [
              DailySchedule(
                id: 'R-1',
                scheduleId: 'S-1',
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
          ),
          TaskSchedule(
            id: 'S-2',
            title: 'Evening Journal & Daily Reflection',
            description: 'Write 3 highlights and gratitude items.',
            priority: TaskPriority.low,
            schedules: [
              DailySchedule(
                id: 'R-2',
                scheduleId: 'S-2',
                startDate: const CivilDay(year: 2024, month: 1, day: 1),
                interval: 1,
                startRelativeTime: const RelativeTime(
                  dayOffset: 0,
                  time: TimeOfDay(hour: 20, minute: 0),
                ),
                dueRelativeTime: const RelativeTime(
                  dayOffset: 0,
                  time: TimeOfDay(hour: 20, minute: 30),
                ),
              ),
            ],
          ),
          TaskSchedule(
            id: 'S-3',
            title: 'Water Garden Vegetables',
            description: 'Deep soak tomato beds and herbs in raised planters.',
            priority: TaskPriority.medium,
            schedules: [
              DailySchedule(
                id: 'R-3',
                scheduleId: 'S-3',
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
          ),
          TaskSchedule(
            id: 'S-4',
            title: 'Monthly Budget & Expenses Audit',
            description:
                'Review bank transactions and reconcile spending categories against monthly allocation targets.',
            priority: TaskPriority.medium,
            schedules: [
              DailySchedule(
                id: 'R-4',
                scheduleId: 'S-4',
                startDate: const CivilDay(year: 2024, month: 1, day: 1),
                interval: 1,
                startRelativeTime: const RelativeTime(
                  dayOffset: 0,
                  time: TimeOfDay(hour: 9, minute: 0),
                ),
                dueRelativeTime: const RelativeTime(
                  dayOffset: 0,
                  time: TimeOfDay(hour: 10, minute: 0),
                ),
              ),
            ],
          ),
        ];

        when(
          mockTaskRepository.getTasks(),
        ).thenAnswer((_) => Stream.value(tasks));
        when(mockUserSettingsRepository.getSettings()).thenAnswer(
          (_) => Stream.value(const UserSettings(hoursAvailable: 8.0)),
        );

        await tester.pumpWidgetBuilder(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(mockAuthRepository),
              taskRepositoryProvider.overrideWithValue(mockTaskRepository),
              userSettingsRepositoryProvider.overrideWithValue(
                mockUserSettingsRepository,
              ),
              userSettingsProvider.overrideWith(
                (ref) => Stream.value(const UserSettings(hoursAvailable: 8.0)),
              ),
            ],
            child: const Scaffold(body: TaskScheduleScreen()),
          ),
          wrapper: l10nMaterialAppWrapper(),
          surfaceSize: const Size(900, 600),
        );
        await tester.pumpAndSettle();

        await screenMatchesGolden(
          tester,
          'task_schedule_screen_wide_masonry_uneven_heights',
        );
      },
    );
  });
}
