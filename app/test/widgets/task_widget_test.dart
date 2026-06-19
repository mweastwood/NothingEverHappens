import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/widgets/task_widget.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import '../test_helper.dart';

import 'package:nothing_ever_happens/widgets/fun_check_button.dart';

@GenerateNiceMocks([MockSpec<TaskRepository>()])
import 'task_widget_test.mocks.dart';

void main() {
  late MockTaskRepository mockTaskRepository;

  final testTask = TaskSchedule(
    id: '1',
    title: 'Test TaskSchedule',
    description: 'This is a test description',
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

  TaskInstance createInstanceFor(TaskSchedule task) {
    final s = task.schedules.first;
    final date = s.scheduledDate;
    return TaskInstance(
      id: task.schedules.length <= 1
          ? '${task.id}_$date'
          : '${task.id}_${date}_0',
      scheduleId: task.id,
      title: task.title,
      description: task.description,
      scheduledDate: date,
      startRelativeTime: s.startRelativeTime,
      dueRelativeTime: s.dueRelativeTime,
      isFamily: task.isFamily,
      priority: task.priority,
      cycleId: task.cycleId,
      assignedUserId: task.assignedUserId,
      status: 'pending',
    );
  }

  final List<Map<String, dynamic>> clipboardStore = [];

  setUp(() {
    mockTaskRepository = MockTaskRepository();
    // Default completeTask/dismissTask/undoResolve to do nothing
    when(
      mockTaskRepository.completeTaskInstance(any),
    ).thenAnswer((_) async => null);
    when(
      mockTaskRepository.dismissTaskInstance(any),
    ).thenAnswer((_) async => null);
    when(
      mockTaskRepository.undoResolveTaskInstance(any),
    ).thenAnswer((_) async {});

    clipboardStore.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall methodCall,
        ) async {
          if (methodCall.method == 'Clipboard.setData') {
            clipboardStore.add(methodCall.arguments as Map<String, dynamic>);
            return null;
          } else if (methodCall.method == 'Clipboard.getData') {
            if (clipboardStore.isEmpty) return null;
            return <String, dynamic>{'text': clipboardStore.last['text']};
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Widget createWidget(TaskSchedule task) {
    final instance = createInstanceFor(task);
    return buildTestableWidget(
      child: Scaffold(
        body: ProviderScope(
          overrides: [
            taskRepositoryProvider.overrideWithValue(mockTaskRepository),
          ],
          child: TaskWidget(instance: instance, schedule: task),
        ),
      ),
    );
  }

  testWidgets('TaskWidget shows title and description', (tester) async {
    await tester.pumpWidget(createWidget(testTask));

    expect(find.text(testTask.title), findsOneWidget);
    expect(find.text(testTask.description), findsOneWidget);
  });

  testWidgets('TaskWidget renders markdown in description', (tester) async {
    final markdownTask = TaskSchedule(
      id: '2',
      title: 'Markdown TaskSchedule',
      description: 'This is **bold** text',
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

    await tester.pumpWidget(createWidget(markdownTask));

    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.text('**bold**'), findsNothing);
  });

  testWidgets('TaskWidget calls repository on completion', (tester) async {
    await tester.pumpWidget(createWidget(testTask));

    // Find checkbox (FunCheckButton).
    await tester.tap(find.byType(FunCheckButton));
    await tester.pump(); // Start confetti

    // Wait for confetti delay (500ms) plus buffer
    await tester.pump(const Duration(milliseconds: 510));
    await tester.pump(); // Start ticker

    // Wait for animation (200ms) plus buffer
    await tester.pump(const Duration(milliseconds: 210));
    await tester.pump(); // Ensure listener executes

    verify(
      mockTaskRepository.completeTaskInstance('${testTask.id}_2024-01-01'),
    ).called(1);
  });

  testGoldens('TaskWidget animation frames', (tester) async {
    final markdownTask = TaskSchedule(
      id: '2',
      title: 'Markdown TaskSchedule',
      description: 'Check me off!',
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

    await tester.pumpWidgetBuilder(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(mockTaskRepository),
        ],
        child: Container(
          color: Colors.white, // White background for clarity
          child: Column(
            children: [
              TaskWidget(
                instance: createInstanceFor(markdownTask),
                schedule: markdownTask,
              ),
              // Use a very high contrast container below
              Container(
                key: const Key('second_item'),
                height: 100,
                width: 400,
                color: Colors.amber, // High contrast
                child: const Center(
                  child: Text(
                    'SECOND TASK (SLIDING UP)',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      wrapper: l10nMaterialAppWrapper(),
      surfaceSize: const Size(400, 400),
    );

    // Frame 0: Start
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/task_widget_frame_0.png'),
    );

    // Trigger animation
    await tester.tap(find.byType(FunCheckButton));
    await tester.pump(); // Start confetti

    // Wait for delay (500ms)
    for (int i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    await tester.pump(); // Start ticker frame

    // Frame 1: 50ms into animation (25% progress)
    // Visual: 50% through vertical collapse. Layout: 75% height remains.
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/task_widget_frame_1.png'),
    );

    // Frame 2: 100ms into animation (50% progress)
    // Visual: Vertical collapse finished (thin line). Layout: 50% height remains.
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/task_widget_frame_2.png'),
    );

    // Frame 3: 150ms into animation (75% progress)
    // Visual: 50% through horizontal collapse. Layout: 25% height remains.
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/task_widget_frame_3.png'),
    );

    // Frame 4: 200ms into animation (100% progress)
    // Visual: Horizontal collapse finished (0 width). Layout: 0% height remains.
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/task_widget_frame_4.png'),
    );
  });

  testWidgets('TaskWidget exposes edit and delete buttons by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestableWidget(
        child: Scaffold(
          body: ProviderScope(
            overrides: [
              taskRepositoryProvider.overrideWithValue(mockTaskRepository),
            ],
            child: TaskWidget(
              instance: createInstanceFor(testTask),
              schedule: testTask,
            ),
          ),
        ),
      ),
    );

    // Exposes action buttons
    expect(find.byKey(const Key('edit_pencil_button')), findsOneWidget);
    expect(find.byKey(const Key('delete_task_button')), findsOneWidget);
  });

  testWidgets('TaskWidget does not expose edit button for recurring tasks', (
    tester,
  ) async {
    final recurringTask = TaskSchedule(
      id: '2',
      title: 'Recurring TaskSchedule',
      description: 'This is a recurring task description',
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

    await tester.pumpWidget(
      buildTestableWidget(
        child: Scaffold(
          body: ProviderScope(
            overrides: [
              taskRepositoryProvider.overrideWithValue(mockTaskRepository),
            ],
            child: TaskWidget(
              instance: createInstanceFor(recurringTask),
              schedule: recurringTask,
            ),
          ),
        ),
      ),
    );

    // Exposes delete button but NOT edit button
    expect(find.byKey(const Key('edit_pencil_button')), findsNothing);
    expect(find.byKey(const Key('delete_task_button')), findsOneWidget);
  });

  testWidgets('TaskWidget delete action plays poof animation and deletes', (
    tester,
  ) async {
    when(
      mockTaskRepository.deleteTaskSchedule(any),
    ).thenAnswer((_) async => null);

    await tester.pumpWidget(
      buildTestableWidget(
        child: Scaffold(
          body: ProviderScope(
            overrides: [
              taskRepositoryProvider.overrideWithValue(mockTaskRepository),
            ],
            child: TaskWidget(
              instance: createInstanceFor(testTask),
              schedule: testTask,
            ),
          ),
        ),
      ),
    );

    // Tap Delete button (our custom FunDeleteButton)
    await tester.tap(find.byKey(const Key('delete_task_button')));
    await tester.pump(); // Register tap

    // Wait for first Future.delayed (350ms) in FunDeleteButton
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(); // Trigger _handleDeletion()

    // Wait for second Future.delayed (400ms) in _handleDeletion()
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(); // Trigger _controller.forward()

    // Wait for collapse animation (200ms) to complete
    await tester.pump(const Duration(milliseconds: 210));
    await tester.pump(); // Allow completion listener to run

    // Verify repository dismissTaskInstance is called
    verify(mockTaskRepository.dismissTaskInstance('1_2024-01-01')).called(1);
  });

  testGoldens('TaskWidget focused state golden', (tester) async {
    await tester.pumpWidgetBuilder(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(mockTaskRepository),
        ],
        child: Container(
          color: Colors.white,
          child: TaskWidget(
            instance: createInstanceFor(testTask),
            schedule: testTask,
          ),
        ),
      ),
      wrapper: l10nMaterialAppWrapper(),
      surfaceSize: const Size(400, 200),
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/task_widget_focused.png'),
    );
  });

  testGoldens('TaskWidget recurring state golden (no pencil)', (tester) async {
    final recurringTask = TaskSchedule(
      id: '2',
      title: 'Recurring TaskSchedule',
      description: 'This is a recurring task description',
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

    await tester.pumpWidgetBuilder(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(mockTaskRepository),
        ],
        child: Container(
          color: Colors.white,
          child: TaskWidget(
            instance: createInstanceFor(recurringTask),
            schedule: recurringTask,
          ),
        ),
      ),
      wrapper: l10nMaterialAppWrapper(),
      surfaceSize: const Size(400, 200),
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/task_widget_recurring.png'),
    );
  });

  testGoldens('TaskWidget badges scenarios', (tester) async {
    const defaultStartTime = RelativeTime(
      dayOffset: 0,
      time: TimeOfDay(hour: 9, minute: 0),
    );
    const defaultEndTime = RelativeTime(
      dayOffset: 0,
      time: TimeOfDay(hour: 17, minute: 0),
    );

    final task1 = TaskSchedule(
      id: 'b1',
      title: 'High Priority TaskSchedule with Duration',
      description: 'Personal task with high priority and 1.5h duration.',
      priority: TaskPriority.high,
      estimatedDuration: const Duration(hours: 1, minutes: 30),
      schedules: [
        OneOffSchedule(
          date: const CivilDay(year: 2024, month: 1, day: 1),
          startRelativeTime: defaultStartTime,
          dueRelativeTime: defaultEndTime,
        ),
      ],
    );

    final task2 = TaskSchedule(
      id: 'b2',
      title: 'Family Daily TaskSchedule with Assignee',
      description:
          'Family task with daily schedule, medium priority, rollover policy, and assignee.',
      isFamily: true,
      priority: TaskPriority.medium,
      assignedUserId: 'user_1',
      schedules: [
        DailySchedule(
          startDate: const CivilDay(year: 2024, month: 1, day: 1),
          interval: 1,
          startRelativeTime: defaultStartTime,
          dueRelativeTime: defaultEndTime,
        ),
      ],
    );

    final task3 = TaskSchedule(
      id: 'b3',
      title: 'Low Priority Weekly TaskSchedule with Shift Policy',
      description:
          'Personal task with low priority, weekly schedule, and shift policy.',
      priority: TaskPriority.low,
      missedPolicy: MissedPolicy.shift,
      schedules: [
        WeeklySchedule(
          startDate: const CivilDay(year: 2024, month: 1, day: 1),
          interval: 1,
          daysOfWeek: {1},
          startRelativeTime: defaultStartTime,
          dueRelativeTime: defaultEndTime,
        ),
      ],
    );

    final task4 = TaskSchedule(
      id: 'b4',
      title: 'Monthly TaskSchedule with Stack Policy',
      description: 'Monthly schedule with stack policy.',
      priority: TaskPriority.medium,
      missedPolicy: MissedPolicy.stack,
      schedules: [
        MonthlySchedule(
          startDate: const CivilDay(year: 2024, month: 1, day: 1),
          interval: 1,
          dayOfMonth: 1,
          startRelativeTime: defaultStartTime,
          dueRelativeTime: defaultEndTime,
        ),
      ],
    );

    final task5 = TaskSchedule(
      id: 'b5',
      title: 'Yearly TaskSchedule with Skip Policy',
      description: 'Yearly schedule with skip policy.',
      priority: TaskPriority.medium,
      missedPolicy: MissedPolicy.skip,
      schedules: [
        YearlySchedule(
          startDate: const CivilDay(year: 2024, month: 1, day: 1),
          interval: 1,
          month: 1,
          day: 1,
          startRelativeTime: defaultStartTime,
          dueRelativeTime: defaultEndTime,
        ),
      ],
    );

    await tester.pumpWidgetBuilder(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(mockTaskRepository),
        ],
        child: Container(
          color: Colors.grey[100],
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TaskWidget(instance: createInstanceFor(task1), schedule: task1),
              const SizedBox(height: 8),
              TaskWidget(instance: createInstanceFor(task2), schedule: task2),
              const SizedBox(height: 8),
              TaskWidget(instance: createInstanceFor(task3), schedule: task3),
              const SizedBox(height: 8),
              TaskWidget(instance: createInstanceFor(task4), schedule: task4),
              const SizedBox(height: 8),
              TaskWidget(instance: createInstanceFor(task5), schedule: task5),
            ],
          ),
        ),
      ),
      wrapper: l10nMaterialAppWrapper(),
      surfaceSize: const Size(450, 850),
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/task_widget_badges_scenarios.png'),
    );
  });

  testWidgets('TaskWidget swipe LTR completes task immediately', (
    tester,
  ) async {
    await tester.pumpWidget(createWidget(testTask));

    // Fling from left to right (LTR) to complete
    await tester.fling(
      find.text(testTask.title),
      const Offset(500.0, 0.0),
      1000.0,
    );
    await tester.pumpAndSettle();

    verify(
      mockTaskRepository.completeTaskInstance('${testTask.id}_2024-01-01'),
    ).called(1);
  });

  testWidgets('TaskWidget swipe RTL dismisses task instance immediately', (
    tester,
  ) async {
    await tester.pumpWidget(createWidget(testTask));

    // Fling from right to left (RTL) to dismiss
    await tester.fling(
      find.text(testTask.title),
      const Offset(-500.0, 0.0),
      1000.0,
    );
    await tester.pumpAndSettle();

    // No confirmation dialog should exist
    expect(find.byType(AlertDialog), findsNothing);

    // Verify dismissTaskInstance is called immediately
    verify(mockTaskRepository.dismissTaskInstance('1_2024-01-01')).called(1);

    // Verify SnackBar with undo option is shown
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets(
    'TaskWidget swipe RTL dismisses task instance and undo resolves it',
    (tester) async {
      await tester.pumpWidget(createWidget(testTask));

      // Fling from right to left (RTL) to dismiss
      await tester.fling(
        find.text(testTask.title),
        const Offset(-500.0, 0.0),
        1000.0,
      );
      await tester.pumpAndSettle();

      // Verify dismissTaskInstance called
      verify(mockTaskRepository.dismissTaskInstance('1_2024-01-01')).called(1);

      // Tap Undo button on SnackBar
      await tester.tap(find.text('Undo'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify undoResolveTaskInstance called
      verify(mockTaskRepository.undoResolveTaskInstance(any)).called(1);

      // Verify action undone confirmation SnackBar is shown
      expect(find.text('"${testTask.title}" restored'), findsOneWidget);
    },
  );

  testGoldens('TaskWidget swipe LTR golden', (tester) async {
    await tester.pumpWidgetBuilder(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(mockTaskRepository),
        ],
        child: Container(
          color: Colors.white,
          child: TaskWidget(
            instance: createInstanceFor(testTask),
            schedule: testTask,
          ),
        ),
      ),
      wrapper: l10nMaterialAppWrapper(),
      surfaceSize: const Size(400, 200),
    );

    // Start drag LTR to reveal green background
    final gesture = await tester.startGesture(
      tester.getCenter(find.text(testTask.title)),
    );
    // Drag past the kTouchSlop threshold to resolve the gesture as a drag
    await gesture.moveBy(const Offset(30.0, 0.0));
    await tester.pump();
    // Move further to slide the card and reveal the background color
    await gesture.moveBy(const Offset(120.0, 0.0));
    await tester.pump();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/task_widget_swipe_ltr.png'),
    );

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testGoldens('TaskWidget swipe RTL golden', (tester) async {
    await tester.pumpWidgetBuilder(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(mockTaskRepository),
        ],
        child: Container(
          color: Colors.white,
          child: TaskWidget(
            instance: createInstanceFor(testTask),
            schedule: testTask,
          ),
        ),
      ),
      wrapper: l10nMaterialAppWrapper(),
      surfaceSize: const Size(400, 200),
    );

    // Start drag RTL to reveal red background
    final gesture = await tester.startGesture(
      tester.getCenter(find.text(testTask.title)),
    );
    // Drag past the kTouchSlop threshold to resolve the gesture as a drag
    await gesture.moveBy(const Offset(-30.0, 0.0));
    await tester.pump();
    // Move further to slide the card and reveal the background color
    await gesture.moveBy(const Offset(-120.0, 0.0));
    await tester.pump();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/task_widget_swipe_rtl.png'),
    );

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'TaskWidget mouse interaction enables text selection and disables swipe',
    (tester) async {
      await tester.pumpWidget(createWidget(testTask));

      // Initially, it should be in touch mode (_isMouse is false)
      final titleFinder = find.text(testTask.title);
      expect(
        find.byWidgetPredicate(
          (w) => w is SelectableText && w.data == testTask.title,
        ),
        findsNothing,
      );
      expect(
        find.byWidgetPredicate((w) => w is Text && w.data == testTask.title),
        findsOneWidget,
      );
      expect(
        tester.widget<MarkdownBody>(find.byType(MarkdownBody)).selectable,
        isFalse,
      );

      // Click mouse on the task widget to simulate mouse interaction
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: tester.getCenter(titleFinder));
      await gesture.down(tester.getCenter(titleFinder));
      await tester.pumpAndSettle();

      // Now, it should switch to mouse mode (_isMouse is true)
      expect(
        find.byWidgetPredicate(
          (w) => w is SelectableText && w.data == testTask.title,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is Text && w.data == testTask.title),
        findsNothing,
      );
      expect(
        tester.widget<MarkdownBody>(find.byType(MarkdownBody)).selectable,
        isTrue,
      );

      // Try to fling to complete (LTR) - should do nothing because direction is none
      await tester.fling(titleFinder, const Offset(500.0, 0.0), 1000.0);
      await tester.pumpAndSettle();

      verifyNever(mockTaskRepository.completeTaskInstance(any));

      // Clean up
      await gesture.up();
      await gesture.removePointer();
    },
  );

  testWidgets(
    'TaskWidget touch interaction enables swipe and long-press copy',
    (tester) async {
      await tester.pumpWidget(createWidget(testTask));

      // 1. Verify title is Text (not SelectableText)
      final titleFinder = find.text(testTask.title);
      expect(
        find.byWidgetPredicate(
          (w) => w is SelectableText && w.data == testTask.title,
        ),
        findsNothing,
      );
      expect(
        find.byWidgetPredicate((w) => w is Text && w.data == testTask.title),
        findsOneWidget,
      );
      expect(
        tester.widget<MarkdownBody>(find.byType(MarkdownBody)).selectable,
        isFalse,
      );

      // 2. Verify ListTile onLongPress is NOT null
      final listTileBefore = tester.widget<ListTile>(find.byType(ListTile));
      expect(listTileBefore.onLongPress, isNotNull);

      // 3. Trigger long press on the ListTile to copy to clipboard
      await tester.longPress(find.byType(ListTile));
      await tester.pumpAndSettle();

      // Verify SnackBar is shown
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Copied task to clipboard'), findsOneWidget);

      // Verify Clipboard has the copied text
      final ClipboardData? clipboardData = await Clipboard.getData(
        Clipboard.kTextPlain,
      );
      expect(clipboardData?.text, contains(testTask.title));

      // 4. Verify swipe completes task
      await tester.fling(titleFinder, const Offset(500.0, 0.0), 1000.0);
      await tester.pumpAndSettle();

      verify(
        mockTaskRepository.completeTaskInstance('${testTask.id}_2024-01-01'),
      ).called(1);
    },
  );

  testWidgets(
    'TaskWidget hybrid device transitions between mouse and touch dynamically',
    (tester) async {
      await tester.pumpWidget(createWidget(testTask));

      final titleFinder = find.text(testTask.title);

      // Starts in touch mode (Text)
      expect(
        find.byWidgetPredicate((w) => w is Text && w.data == testTask.title),
        findsOneWidget,
      );
      expect(
        tester.widget<ListTile>(find.byType(ListTile)).onLongPress,
        isNotNull,
      );
      expect(
        tester.widget<MarkdownBody>(find.byType(MarkdownBody)).selectable,
        isFalse,
      );

      // 1. Hover mouse -> Switches to mouse mode
      final mouseGesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouseGesture.addPointer(
        location: tester.getCenter(titleFinder) - const Offset(10, 10),
      );
      await mouseGesture.moveTo(tester.getCenter(titleFinder));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) => w is SelectableText && w.data == testTask.title,
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<ListTile>(find.byType(ListTile)).onLongPress,
        isNull,
      );
      expect(
        tester.widget<MarkdownBody>(find.byType(MarkdownBody)).selectable,
        isTrue,
      );

      // 2. Tap screen (touch down) -> Switches back to touch mode
      final touchGesture = await tester.createGesture(
        kind: PointerDeviceKind.touch,
      );
      await touchGesture.addPointer(location: tester.getCenter(titleFinder));
      await touchGesture.down(tester.getCenter(titleFinder));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate((w) => w is Text && w.data == testTask.title),
        findsOneWidget,
      );
      expect(
        tester.widget<ListTile>(find.byType(ListTile)).onLongPress,
        isNotNull,
      );
      expect(
        tester.widget<MarkdownBody>(find.byType(MarkdownBody)).selectable,
        isFalse,
      );

      // Clean up gestures
      await mouseGesture.removePointer();
      await touchGesture.up();
      await touchGesture.removePointer();
    },
  );

  testWidgets(
    'TaskWidget mouse swipe RTL does not trigger deletion or show confirmation dialog',
    (tester) async {
      when(
        mockTaskRepository.deleteTaskSchedule(any),
      ).thenAnswer((_) async => null);
      await tester.pumpWidget(createWidget(testTask));

      final titleFinder = find.text(testTask.title);

      // Hover mouse -> Switches to mouse mode
      final mouseGesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouseGesture.addPointer(
        location: tester.getCenter(titleFinder) - const Offset(10, 10),
      );
      await mouseGesture.moveTo(tester.getCenter(titleFinder));
      await tester.pumpAndSettle();

      // Try to swipe RTL using the mouse pointer
      await mouseGesture.down(tester.getCenter(titleFinder));
      await mouseGesture.moveBy(const Offset(-30.0, 0.0));
      await tester.pump();
      await mouseGesture.moveBy(const Offset(-120.0, 0.0));
      await tester.pump();
      await mouseGesture.up();
      await tester.pumpAndSettle();

      // Verify no dialog is shown and deleteTask was never called
      expect(find.byType(AlertDialog), findsNothing);
      verifyNever(mockTaskRepository.deleteTaskSchedule(any));

      await mouseGesture.removePointer();
    },
  );

  testWidgets(
    'TaskWidget swipe RTL undo passes resolved (completedAt set) instance to action',
    (tester) async {
      // Regression: previously the pending (pre-resolution) instance was
      // captured, causing undoResolveTaskInstance to compute the wrong
      // refDate and fail to delete the next spawned occurrence.
      final resolvedInstance = createInstanceFor(testTask).copyWith(
        status: 'dismissed',
        completedByUserId: 'user-1',
        completedAt: DateTime(2026, 6, 18, 9, 0),
      );
      when(
        mockTaskRepository.dismissTaskInstance(any),
      ).thenAnswer((_) async => resolvedInstance);

      TaskInstance? capturedInstance;
      when(mockTaskRepository.undoResolveTaskInstance(any)).thenAnswer((
        invocation,
      ) async {
        capturedInstance = invocation.positionalArguments[0] as TaskInstance;
      });

      await tester.pumpWidget(createWidget(testTask));

      // Fling RTL to dismiss
      await tester.fling(
        find.text(testTask.title),
        const Offset(-500.0, 0.0),
        1000.0,
      );
      await tester.pumpAndSettle();

      // Tap Undo
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      // The resolved instance (with completedAt set) should be passed to undo,
      // not the original pending instance.
      expect(capturedInstance, isNotNull);
      expect(
        capturedInstance!.completedAt,
        equals(resolvedInstance.completedAt),
      );
      expect(capturedInstance!.status, equals('dismissed'));
    },
  );

  testWidgets(
    'TaskWidget swipe LTR undo passes resolved (completedAt set) instance to action',
    (tester) async {
      // Same regression test for the complete (LTR) swipe direction.
      final resolvedInstance = createInstanceFor(testTask).copyWith(
        status: 'completed',
        completedByUserId: 'user-1',
        completedAt: DateTime(2026, 6, 18, 9, 0),
      );
      when(
        mockTaskRepository.completeTaskInstance(any),
      ).thenAnswer((_) async => resolvedInstance);

      TaskInstance? capturedInstance;
      when(mockTaskRepository.undoResolveTaskInstance(any)).thenAnswer((
        invocation,
      ) async {
        capturedInstance = invocation.positionalArguments[0] as TaskInstance;
      });

      await tester.pumpWidget(createWidget(testTask));

      // Fling LTR to complete
      await tester.fling(
        find.text(testTask.title),
        const Offset(500.0, 0.0),
        1000.0,
      );
      await tester.pumpAndSettle();

      // Tap Undo
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      // The resolved instance (with completedAt set) should be passed to undo.
      expect(capturedInstance, isNotNull);
      expect(
        capturedInstance!.completedAt,
        equals(resolvedInstance.completedAt),
      );
      expect(capturedInstance!.status, equals('completed'));
    },
  );

  testWidgets(
    'TaskWidget shows undo SnackBar even if unmounted during the repository async gap',
    (tester) async {
      final completeCompleter = Completer<TaskInstance?>();
      when(
        mockTaskRepository.completeTaskInstance(any),
      ).thenAnswer((_) => completeCompleter.future);

      bool showTask = true;
      late StateSetter setWrapperState;
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: ProviderScope(
              overrides: [
                taskRepositoryProvider.overrideWithValue(mockTaskRepository),
              ],
              child: StatefulBuilder(
                builder: (context, setState) {
                  setWrapperState = setState;
                  return showTask
                      ? TaskWidget(
                          instance: createInstanceFor(testTask),
                          schedule: testTask,
                        )
                      : const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      // Tap the checkbox to complete the task
      await tester.tap(find.byType(FunCheckButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500)); // wait for confetti
      await tester.pumpAndSettle(); // start and complete collapse animation

      // At this point, repo.completeTaskInstance has been called and is pending.
      // Manually unmount the TaskWidget before the repository completes
      setWrapperState(() {
        showTask = false;
      });
      await tester.pump(); // TaskWidget is now unmounted/disposed

      // Complete the repository future
      completeCompleter.complete(createInstanceFor(testTask));
      await tester.pump(); // let microtasks run to show SnackBar
      await tester.pumpAndSettle(); // wait for snackbar animation

      // Verify SnackBar with undo option is still shown
      expect(find.text('Undo'), findsOneWidget);
    },
  );

  testWidgets(
    'TaskWidget displays due date badge with correct formatting and colors based on urgency',
    (tester) async {
      // Set clock to 2026-06-19 09:00 AM
      final now = DateTime(2026, 6, 19, 9, 0);
      AppClock.setMockTime(now);

      final overdueTask = TaskSchedule(
        id: 'overdue_1',
        title: 'Overdue Task',
        description: 'Due yesterday',
        schedules: [
          OneOffSchedule(
            date: const CivilDay(year: 2026, month: 6, day: 18),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
          ),
        ],
      );

      final dueTodayTask = TaskSchedule(
        id: 'today_1',
        title: 'Due Today Task',
        description: 'Due today at 5:00 PM',
        schedules: [
          OneOffSchedule(
            date: const CivilDay(year: 2026, month: 6, day: 19),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
          ),
        ],
      );

      final dueTomorrowTask = TaskSchedule(
        id: 'tomorrow_1',
        title: 'Due Tomorrow Task',
        description: 'Due tomorrow at 5:00 PM',
        schedules: [
          OneOffSchedule(
            date: const CivilDay(year: 2026, month: 6, day: 20),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
          ),
        ],
      );

      // Test Overdue
      await tester.pumpWidget(createWidget(overdueTask));
      await tester.pumpAndSettle();
      expect(find.text('Overdue: Yesterday at 5:00 PM'), findsOneWidget);
      final Text overdueTextWidget = tester.widget(
        find.text('Overdue: Yesterday at 5:00 PM'),
      );
      expect(
        overdueTextWidget.style?.color,
        Theme.of(
          tester.element(find.text('Overdue: Yesterday at 5:00 PM')),
        ).colorScheme.error,
      );

      // Test Due Today
      await tester.pumpWidget(createWidget(dueTodayTask));
      await tester.pumpAndSettle();
      expect(find.text('Due Today at 5:00 PM'), findsOneWidget);
      final Text todayTextWidget = tester.widget(
        find.text('Due Today at 5:00 PM'),
      );
      expect(todayTextWidget.style?.color, Colors.orange.shade800);

      // Test Due Tomorrow
      await tester.pumpWidget(createWidget(dueTomorrowTask));
      await tester.pumpAndSettle();
      expect(find.text('Due Tomorrow at 5:00 PM'), findsOneWidget);
      final Text tomorrowTextWidget = tester.widget(
        find.text('Due Tomorrow at 5:00 PM'),
      );
      expect(
        tomorrowTextWidget.style?.color,
        Theme.of(
          tester.element(find.text('Due Tomorrow at 5:00 PM')),
        ).colorScheme.secondary,
      );

      AppClock.reset();
    },
  );
}
