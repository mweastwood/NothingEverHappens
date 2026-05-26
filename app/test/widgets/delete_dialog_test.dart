import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:nothing_ever_happens/widgets/task_widget.dart';
import 'package:nothing_ever_happens/logic/task.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:provider/provider.dart';

import 'task_widget_test.mocks.dart';

void main() {
  late MockTaskRepository mockTaskRepository;

  final testTask = Task(
    id: 'delete-test-task',
    title: 'Clean the kitchen',
    description: 'Sweep and wash dishes',
    startRelativeTime: const RelativeTime(
      dayOffset: 0,
      time: TimeOfDay(hour: 9, minute: 0),
    ),
    dueRelativeTime: const RelativeTime(
      dayOffset: 0,
      time: TimeOfDay(hour: 17, minute: 0),
    ),
    schedule: OneOffSchedule(
      date: const CivilDay(year: 2026, month: 5, day: 26),
    ),
  );

  setUp(() {
    mockTaskRepository = MockTaskRepository();
  });

  group('Delete Confirmation Dialog Golden Test', () {
    testGoldens('Delete dialog renders correctly', (WidgetTester tester) async {
      await tester.pumpWidgetBuilder(
        Provider<TaskRepository>.value(
          value: mockTaskRepository,
          child: Scaffold(
            body: Center(child: TaskWidget(task: testTask)),
          ),
        ),
        wrapper: materialAppWrapper(
          theme: ThemeData.light(useMaterial3: true).copyWith(
            shadowColor: Colors.transparent,
            textTheme: ThemeData.light(
              useMaterial3: true,
            ).textTheme.apply(fontFamily: 'Ahem'),
          ),
          platform: TargetPlatform.android,
        ),
        surfaceSize: const Size(800, 600),
      );

      // Tap the delete button on TaskWidget to open the dialog
      await tester.tap(find.byKey(const Key('delete_task_button')));
      await tester.pumpAndSettle();

      // Verify the dialog elements render
      expect(find.text('Delete Task?'), findsOneWidget);
      expect(
        find.text(
          'Are you sure you want to delete "Clean the kitchen"? This action will permanently remove the task.',
        ),
        findsOneWidget,
      );

      // Match the golden screen image
      await screenMatchesGolden(tester, 'delete_confirmation_dialog');
    });
  });
}
