import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:nothing_ever_happens/logic/task_delta.dart';
import 'package:nothing_ever_happens/widgets/task_delta_widget.dart';
import '../test_helper.dart';

void main() {
  testWidgets('TaskDeltaWidget shows operation in title', (tester) async {
    final delta = TaskDelta(
      id: 'delta-1',
      taskId: 'task-1',
      timestamp: DateTime(2023, 10, 26, 12, 0, 0),
      expiresAt: DateTime(2023, 10, 27, 12, 0, 0),
      operation: 'update',
      changedFields: {'title': 'New Title'},
      userId: 'user-1',
    );

    await tester.pumpWidget(
      buildTestableWidget(
        child: Scaffold(body: TaskDeltaWidget(delta: delta)),
      ),
    );

    expect(find.text('Operation: update'), findsOneWidget);
  });

  testWidgets('TaskDeltaWidget renders details in markdown', (tester) async {
    final delta = TaskDelta(
      id: 'delta-1',
      taskId: 'task-123',
      timestamp: DateTime(2023, 10, 26, 12, 0, 0),
      expiresAt: DateTime(2023, 10, 27, 12, 0, 0),
      operation: 'create',
      changedFields: {'status': 'done'},
      userId: 'user-abc',
    );

    await tester.pumpWidget(
      buildTestableWidget(
        child: Scaffold(body: TaskDeltaWidget(delta: delta)),
      ),
    );

    expect(find.byType(MarkdownBody), findsOneWidget);
    // Determine if specific text is present in the markdown body.
    // Since MarkdownBody renders complex widgets, we can't easily find.text.
    // But we verified the widget is a MarkdownBody, and we trust the widget logic constructs the string correctly.
    // We can check if the widget was built with the expected data string roughly,
    // but accessing the widget property is better.

    final markdownWidget = tester.widget<MarkdownBody>(
      find.byType(MarkdownBody),
    );
    expect(markdownWidget.data, contains('**TaskSchedule ID:** task-123'));
    expect(markdownWidget.data, contains('**User ID:** user-abc'));
    expect(markdownWidget.data, contains('status: done'));
  });

  testWidgets('TaskDeltaWidget handles empty changes', (tester) async {
    final delta = TaskDelta(
      id: 'delta-1',
      taskId: 'task-1',
      timestamp: DateTime(2023, 10, 26, 12, 0, 0),
      expiresAt: DateTime(2023, 10, 27, 12, 0, 0),
      operation: 'read',
      changedFields: {},
      userId: 'user-1',
    );

    await tester.pumpWidget(
      buildTestableWidget(
        child: Scaffold(body: TaskDeltaWidget(delta: delta)),
      ),
    );

    final markdownWidget = tester.widget<MarkdownBody>(
      find.byType(MarkdownBody),
    );
    expect(markdownWidget.data, contains('No fields changed.'));
  });

  testGoldens('TaskDeltaWidget renders correctly', (tester) async {
    final deltaWithChanges = TaskDelta(
      id: 'delta-1',
      taskId: 'task-1',
      timestamp: DateTime(2023, 10, 26, 12, 0, 0),
      expiresAt: DateTime(2023, 10, 27, 12, 0, 0),
      operation: 'update',
      changedFields: {'title': 'New Title', 'priority': 1},
      userId: 'user-1',
    );

    final deltaNoChanges = TaskDelta(
      id: 'delta-2',
      taskId: 'task-2',
      timestamp: DateTime(2023, 10, 27, 14, 30, 0),
      expiresAt: DateTime(2023, 10, 28, 14, 30, 0),
      operation: 'read',
      changedFields: {},
      userId: 'user-2',
    );

    final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 2)
      ..addScenario('With Changes', TaskDeltaWidget(delta: deltaWithChanges))
      ..addScenario('No Changes', TaskDeltaWidget(delta: deltaNoChanges));

    await tester.pumpWidgetBuilder(
      builder.build(),
      wrapper: l10nMaterialAppWrapper(),
    );
    await screenMatchesGolden(tester, 'task_delta_widget');
  });
}
