import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nothing_ever_happens/screens/task_list_screen.dart';

void main() {
  // Helper to wrap the screen in a MaterialApp (needed for Scaffold, Theme, etc)
  Widget createScreen() {
    return MaterialApp(home: const TaskListScreen());
  }

  testWidgets('Task list mobile layout (ListView)', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createScreen());

    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('Buy groceries'), findsOneWidget);
  });

  testWidgets('Task list desktop layout (GridView)', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createScreen());

    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('Buy groceries'), findsOneWidget);
  });

  testWidgets('Task list shows FAB and navigates to CreateTaskScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createScreen());

    // Verify FAB exists
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);

    // Tap FAB
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Verify we are on the CreateTaskScreen
    expect(find.text('New Task'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));

    // Enter details for new task
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'New Task Title',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Description'),
      'New Task Description',
    );

    // Save
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Verify we are back on TaskListScreen and task is added
    expect(find.text('Nothing Ever Happens'), findsOneWidget);
    expect(find.text('New Task Title'), findsOneWidget);
    expect(find.text('New Task Description'), findsOneWidget);
  });
}
