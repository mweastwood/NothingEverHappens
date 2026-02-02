import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:nothing_ever_happens/widgets/task_widget.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:nothing_ever_happens/logic/task.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:nothing_ever_happens/widgets/fun_check_button.dart';

@GenerateNiceMocks([MockSpec<TaskRepository>()])
import 'task_widget_test.mocks.dart';

void main() {
  late MockTaskRepository mockTaskRepository;

  final testTask = Task(
    id: '1',
    title: 'Test Task',
    description: 'This is a test description',
    startRelativeTime: const RelativeTime(
      dayOffset: 0,
      time: TimeOfDay(hour: 9, minute: 0),
    ),
    dueRelativeTime: const RelativeTime(
      dayOffset: 0,
      time: TimeOfDay(hour: 17, minute: 0),
    ),
    schedule: OneOffSchedule(
      date: const CivilDay(year: 2024, month: 1, day: 1),
    ),
  );

  setUp(() {
    mockTaskRepository = MockTaskRepository();
    // Default completeTask to do nothing
    when(mockTaskRepository.completeTask(any)).thenAnswer((_) async {});
  });

  Widget createWidget(Task task) {
    return MaterialApp(
      home: Scaffold(
        body: Provider<TaskRepository>.value(
          value: mockTaskRepository,
          child: TaskWidget(task: task),
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
    final markdownTask = Task(
      id: '2',
      title: 'Markdown Task',
      description: 'This is **bold** text',
      startRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 9, minute: 0),
      ),
      dueRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 17, minute: 0),
      ),
      schedule: OneOffSchedule(
        date: const CivilDay(year: 2024, month: 1, day: 1),
      ),
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

    verify(mockTaskRepository.completeTask(testTask.id)).called(1);
  });

  testGoldens('TaskWidget animation frames', (tester) async {
    final markdownTask = Task(
      id: '2',
      title: 'Markdown Task',
      description: 'Check me off!',
      startRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 9, minute: 0),
      ),
      dueRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 17, minute: 0),
      ),
      schedule: OneOffSchedule(
        date: const CivilDay(year: 2024, month: 1, day: 1),
      ),
    );

    await tester.pumpWidgetBuilder(
      Provider<TaskRepository>.value(
        value: mockTaskRepository,
        child: Container(
          color: Colors.white, // White background for clarity
          child: Column(
            children: [
              TaskWidget(task: markdownTask),
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
      wrapper: materialAppWrapper(),
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
}
