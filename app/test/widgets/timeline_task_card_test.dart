import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:nothing_ever_happens/logic/auth_repository.dart';
import 'package:nothing_ever_happens/logic/calendar_day_task.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/family_repository.dart';
import 'package:nothing_ever_happens/logic/label_repository.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/user_settings.dart';
import 'package:nothing_ever_happens/logic/user_settings_repository.dart';
import 'package:nothing_ever_happens/widgets/calendar_month_card.dart';
import 'package:nothing_ever_happens/widgets/calendar_task_details_sheet.dart';
import 'package:nothing_ever_happens/widgets/timeline_task_card.dart';

import '../screens/home_screen_test.mocks.dart';
import '../test_helper.dart';

void main() {
  late MockTaskRepository mockTaskRepository;
  late MockAuthRepository mockAuthRepository;
  late MockUserSettingsRepository mockUserSettingsRepository;

  const testDay = CivilDay(year: 2026, month: 3, day: 8);

  final sampleInstance = TaskInstance(
    id: 'I-card-1',
    scheduleId: 'S-card-1',
    ruleId: 'R-card-1',
    title: 'Clean Kitchen',
    description: 'Wipe counters and wash dishes',
    priority: TaskPriority.high,
    scheduledDate: testDay,
    startRelativeTime: const RelativeTime(dayOffset: 0, hour: 10, minute: 0),
    dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 11, minute: 0),
    status: TaskStatus.pending,
  );

  final completedInstance = TaskInstance(
    id: 'I-card-2',
    scheduleId: 'S-card-2',
    ruleId: 'R-card-2',
    title: 'Read Book',
    description: 'Read chapter 4',
    priority: TaskPriority.low,
    scheduledDate: testDay,
    startRelativeTime: const RelativeTime(dayOffset: 0, hour: 14, minute: 0),
    dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 15, minute: 0),
    status: TaskStatus.completed,
  );

  setUp(() {
    mockTaskRepository = MockTaskRepository();
    mockAuthRepository = MockAuthRepository();
    mockUserSettingsRepository = MockUserSettingsRepository();

    when(
      mockAuthRepository.authStateChanges,
    ).thenAnswer((_) => Stream.value(null));
    when(
      mockTaskRepository.getInstances(),
    ).thenAnswer((_) => Stream.value([sampleInstance, completedInstance]));
    when(mockTaskRepository.getTasks()).thenAnswer((_) => Stream.value([]));
    when(
      mockUserSettingsRepository.getSettings(),
    ).thenAnswer((_) => Stream.value(const UserSettings(hoursAvailable: 8.0)));
    when(
      mockTaskRepository.completeTaskInstance(any),
    ).thenAnswer((_) async => null);
    when(
      mockTaskRepository.uncompleteTaskInstance(any),
    ).thenAnswer((_) async => null);
  });

  Widget buildCardWidget({
    required CalendarDayTask task,
    double cardHeight = 60.0,
    double cardWidth = 120.0,
  }) {
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
        familyRepositoryProvider.overrideWithValue(familyRepo),
        taskInstancesProvider.overrideWith(
          (ref) => Stream.value([sampleInstance, completedInstance]),
        ),
        taskSchedulesProvider.overrideWith((ref) => Stream.value([])),
        personalLabelsStreamProvider.overrideWith(
          (ref) => Stream.value(const []),
        ),
        familyLabelsStreamProvider.overrideWith(
          (ref) => Stream.value(const []),
        ),
        canEditFamilyLabelsProvider.overrideWithValue(false),
        userSettingsProvider.overrideWith(
          (ref) => Stream.value(const UserSettings(hoursAvailable: 8.0)),
        ),
      ],
      child: buildTestableWidget(
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: cardWidth,
              height: cardHeight,
              child: TimelineTaskCard(
                day: testDay,
                task: task,
                cardHeight: cardHeight,
                cardWidth: cardWidth,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('tapping card opens CalendarTaskDetailsSheet', (tester) async {
    final task = CalendarDayTask(
      id: sampleInstance.id,
      title: sampleInstance.title,
      description: sampleInstance.description,
      priority: sampleInstance.priority,
      isInstance: true,
      instance: sampleInstance,
    );

    await tester.pumpWidget(buildCardWidget(task: task));
    await tester.pumpAndSettle();

    final cardFinder = find.byKey(Key('timeline_task_${task.id}'));
    expect(cardFinder, findsOneWidget);

    await tester.tap(cardFinder);
    await tester.pumpAndSettle();

    expect(find.byType(CalendarTaskDetailsSheet), findsOneWidget);
    expect(find.text('Clean Kitchen'), findsWidgets);
  });

  testWidgets(
    'tapping checkbox on uncompleted instance task invokes completeTaskInstance',
    (tester) async {
      final task = CalendarDayTask(
        id: sampleInstance.id,
        title: sampleInstance.title,
        priority: sampleInstance.priority,
        isInstance: true,
        instance: sampleInstance,
        isCompleted: false,
      );

      await tester.pumpWidget(buildCardWidget(task: task));
      await tester.pumpAndSettle();

      final checkboxFinder = find.byIcon(Icons.radio_button_unchecked);
      expect(checkboxFinder, findsOneWidget);

      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      verify(
        mockTaskRepository.completeTaskInstance(sampleInstance.id),
      ).called(1);
    },
  );

  testWidgets(
    'tapping checkbox on completed instance task invokes uncompleteTaskInstance',
    (tester) async {
      final task = CalendarDayTask(
        id: completedInstance.id,
        title: completedInstance.title,
        priority: completedInstance.priority,
        isInstance: true,
        instance: completedInstance,
        isCompleted: true,
      );

      await tester.pumpWidget(buildCardWidget(task: task));
      await tester.pumpAndSettle();

      final checkboxFinder = find.byIcon(Icons.check_circle);
      expect(checkboxFinder, findsOneWidget);

      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      verify(
        mockTaskRepository.uncompleteTaskInstance(completedInstance.id),
      ).called(1);
    },
  );

  testWidgets('priority stripe matches task priority theme color', (
    tester,
  ) async {
    final task = CalendarDayTask(
      id: sampleInstance.id,
      title: sampleInstance.title,
      priority: TaskPriority.high,
      isInstance: true,
      instance: sampleInstance,
    );

    await tester.pumpWidget(buildCardWidget(task: task));
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.byType(TimelineTaskCard));
    final expectedColor = getPriorityColor(
      Theme.of(context).colorScheme,
      TaskPriority.high,
    );

    final stripeContainer = tester.widget<Container>(
      find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.constraints?.minWidth == 4 &&
            w.constraints?.maxWidth == 4 &&
            w.color == expectedColor,
      ),
    );
    expect(stripeContainer.color, equals(expectedColor));
  });

  testWidgets('non-instance tasks display recurring icon instead of checkbox', (
    tester,
  ) async {
    final nonInstanceTask = CalendarDayTask(
      id: 'S-recurring-1',
      title: 'Recurring Task',
      priority: TaskPriority.medium,
      isInstance: false,
    );

    await tester.pumpWidget(buildCardWidget(task: nonInstanceTask));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.event_repeat), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets(
    'completed tasks apply strike-through typography and muted surface colors',
    (tester) async {
      final completedTask = CalendarDayTask(
        id: completedInstance.id,
        title: completedInstance.title,
        priority: completedInstance.priority,
        isInstance: true,
        instance: completedInstance,
        isCompleted: true,
      );

      await tester.pumpWidget(buildCardWidget(task: completedTask));
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(
        find.byType(TimelineTaskCard),
      );
      final theme = Theme.of(context);
      final expectedCardColor = theme.colorScheme.surfaceContainerHighest
          .withValues(alpha: 0.4);

      final cardWidget = tester.widget<Card>(
        find.byKey(Key('timeline_task_${completedTask.id}')),
      );
      expect(cardWidget.color, equals(expectedCardColor));

      final titleText = tester.widget<Text>(find.text(completedTask.title));
      expect(titleText.style?.decoration, equals(TextDecoration.lineThrough));
    },
  );
}
