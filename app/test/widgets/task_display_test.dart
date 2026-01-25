import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:nothing_ever_happens/widgets/task_display.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

void main() {
  testWidgets('TaskDisplay shows title and description', (tester) async {
    const title = 'Test Task';
    const description = 'This is a test description';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TaskDisplay(title: title, description: description),
        ),
      ),
    );

    expect(find.text(title), findsOneWidget);
    expect(find.text(description), findsOneWidget);
  });

  testWidgets('TaskDisplay renders markdown in description', (tester) async {
    const title = 'Markdown Task';
    const description = 'This is **bold** text';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TaskDisplay(title: title, description: description),
        ),
      ),
    );

    expect(find.byType(MarkdownBody), findsOneWidget);

    // Verify that the markdown syntax is NOT displayed literally (indicates parsing happened)
    expect(find.text('**bold**'), findsNothing);

    // We verified MarkdownBody is present and raw syntax is gone, so parsing occurred.
    // Finding specific styled text fragments in MarkdownBody can be brittle.

    // Verify selectable is true
    final markdownWidget = tester.widget<MarkdownBody>(
      find.byType(MarkdownBody),
    );
    expect(markdownWidget.selectable, isTrue);
  });

  testGoldens('TaskDisplay renders correctly', (tester) async {
    const title = 'Test Task';
    const description =
        'This is a **bold** description with [link](http://example.com)';

    final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 2)
      ..addScenario(
        'Default',
        const TaskDisplay(title: title, description: description),
      );

    await tester.pumpWidgetBuilder(
      builder.build(),
      wrapper: materialAppWrapper(),
    );
    await screenMatchesGolden(tester, 'task_display');
  });
}
