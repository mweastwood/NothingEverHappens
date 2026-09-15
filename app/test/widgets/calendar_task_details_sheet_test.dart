import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import '../test_helper.dart';
import 'package:nothing_ever_happens/logic/auth_repository.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/calendar_day_task.dart';
import 'package:nothing_ever_happens/logic/user_settings.dart';
import 'package:nothing_ever_happens/logic/user_settings_repository.dart';
import 'package:nothing_ever_happens/logic/family_repository.dart';
import 'package:nothing_ever_happens/logic/subscription_service.dart';
import 'package:nothing_ever_happens/widgets/calendar_task_details_sheet.dart';
import 'package:nothing_ever_happens/screens/create_task_screen.dart';

import '../screens/home_screen_test.mocks.dart';

void main() {
  late MockTaskRepository mockTaskRepository;
  late MockAuthRepository mockAuthRepository;
  late MockUserSettingsRepository mockUserSettingsRepository;

  late BehaviorSubject<List<TaskInstance>> instancesSubject;
  late BehaviorSubject<List<TaskSchedule>> tasksSubject;
  late BehaviorSubject<UserSettings> settingsSubject;

  const testDay = CivilDay(year: 2026, month: 3, day: 8);

  final sampleSchedule = TaskSchedule(
    id: 'S-detail-1',
    title: 'Water Houseplants',
    description: 'Living room and balcony plants need watering.',
    priority: TaskPriority.high,
    estimatedDuration: const Duration(minutes: 45),
    schedules: [
      DailySchedule(
        id: 'R-detail-1',
        scheduleId: 'S-detail-1',
        startDate: const CivilDay(year: 2026, month: 3, day: 1),
        interval: 1,
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 12, minute: 0),
      ),
    ],
  );

  final sampleInstance = TaskInstance(
    id: 'I-detail-1',
    scheduleId: 'S-detail-1',
    ruleId: 'R-detail-1',
    title: 'Water Houseplants',
    description: 'Living room and balcony plants need watering.',
    priority: TaskPriority.high,
    scheduledDate: testDay,
    startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
    dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 12, minute: 0),
    status: TaskStatus.pending,
  );

  setUp(() {
    mockTaskRepository = MockTaskRepository();
    mockAuthRepository = MockAuthRepository();
    mockUserSettingsRepository = MockUserSettingsRepository();

    instancesSubject = BehaviorSubject<List<TaskInstance>>.seeded([
      sampleInstance,
    ]);
    tasksSubject = BehaviorSubject<List<TaskSchedule>>.seeded([sampleSchedule]);
    settingsSubject = BehaviorSubject<UserSettings>.seeded(
      const UserSettings(hoursAvailable: 8.0),
    );

    when(
      mockAuthRepository.authStateChanges,
    ).thenAnswer((_) => Stream.value(null));
    when(
      mockTaskRepository.getInstances(),
    ).thenAnswer((_) => instancesSubject.stream);
    when(mockTaskRepository.getTasks()).thenAnswer((_) => tasksSubject.stream);
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
    instancesSubject.close();
    tasksSubject.close();
    settingsSubject.close();
  });

  Widget buildDetailsSheetWidget({required CalendarDayTask task}) {
    final firestore = FakeFirebaseFirestore();
    final familyRepo = FamilyRepository(
      firestore: firestore,
      userId: 'user-1',
      userEmail: 'user1@example.com',
      userDisplayName: 'Alice',
    );

    return ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(mockTaskRepository),
        authRepositoryProvider.overrideWithValue(mockAuthRepository),
        userSettingsRepositoryProvider.overrideWithValue(
          mockUserSettingsRepository,
        ),
        userSettingsProvider.overrideWith((ref) => settingsSubject.stream),
        familyRepositoryProvider.overrideWithValue(familyRepo),
        subscriptionServiceProvider.overrideWith(
          (ref) => FakeSubscriptionService(ref, SubscriptionTier.family),
        ),
      ],
      child: buildTestableWidget(
        child: Scaffold(
          body: CalendarTaskDetailsSheet(task: task, day: testDay),
        ),
      ),
    );
  }

  testWidgets('shows details of only the specified task', (tester) async {
    final dayTask = CalendarDayTask(
      id: sampleInstance.id,
      title: sampleInstance.title,
      description: sampleInstance.description,
      priority: sampleInstance.priority,
      status: sampleInstance.status,
      isInstance: true,
      instance: sampleInstance,
      schedule: sampleSchedule,
    );

    await tester.pumpWidget(buildDetailsSheetWidget(task: dayTask));
    await tester.pumpAndSettle();

    // Verify task title, priority, duration, time window, and description
    expect(
      find.byKey(const Key('calendar_task_details_title')),
      findsOneWidget,
    );
    expect(find.text('Water Houseplants'), findsOneWidget);
    expect(find.text('HIGH'), findsOneWidget);
    expect(find.text('Estimated duration: 45 min'), findsOneWidget);
    expect(
      find.text('Living room and balcony plants need watering.'),
      findsOneWidget,
    );
    expect(find.text('9:00 AM – 12:00 PM'), findsOneWidget);

    // Verify completion toggle button
    final toggleBtn = find.byKey(
      const Key('calendar_task_details_toggle_complete_button'),
    );
    expect(toggleBtn, findsOneWidget);
    expect(find.text('Mark as Completed'), findsOneWidget);

    // Tap complete button
    await tester.tap(toggleBtn);
    await tester.pumpAndSettle();
    verify(mockTaskRepository.completeTaskInstance('I-detail-1')).called(1);

    // Verify Edit Task button opens CreateTaskScreen
    final editBtn = find.byKey(const Key('calendar_task_details_edit_button'));
    expect(editBtn, findsOneWidget);
    await tester.tap(editBtn);
    await tester.pumpAndSettle();
    expect(find.byType(CreateTaskScreen), findsOneWidget);
  });

  testWidgets(
    'shows projected recurrence details for projected recurring task',
    (tester) async {
      final projectedTask = CalendarDayTask(
        id: 'projected_S-detail-1_2026-03-08',
        title: 'Projected Houseplants',
        description: 'Recurring chore',
        priority: TaskPriority.medium,
        status: TaskStatus.pending,
        isInstance: false,
        schedule: sampleSchedule,
        matchingRule: sampleSchedule.schedules.first,
      );

      await tester.pumpWidget(buildDetailsSheetWidget(task: projectedTask));
      await tester.pumpAndSettle();

      expect(find.text('Projected Houseplants'), findsOneWidget);
      expect(find.text('Projected occurrence'), findsOneWidget);
      // Concrete toggle button should not be present for projected tasks
      expect(
        find.byKey(const Key('calendar_task_details_toggle_complete_button')),
        findsNothing,
      );
    },
  );
}
