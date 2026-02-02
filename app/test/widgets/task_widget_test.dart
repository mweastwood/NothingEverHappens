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
    // We expect it to be a GestureDetector inside.
    await tester.tap(find.byType(FunCheckButton));
    await tester.pump(); // Start confetti

    // Wait for confetti delay (600ms)
    await tester.pump(const Duration(milliseconds: 700));

    // Wait for animation (600ms)
    await tester.pump(const Duration(milliseconds: 700));

    verify(mockTaskRepository.completeTask(testTask.id)).called(1);
  });

  testGoldens('TaskWidget renders correctly', (tester) async {
    final markdownTask = Task(
      id: '2',
      title: 'Markdown Task',
      description:
          'This is a **bold** description with [link](http://example.com)',
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
        child: TaskWidget(task: markdownTask),
      ),
      wrapper: materialAppWrapper(),
    );
    await screenMatchesGolden(tester, 'task_widget');
  });
}
