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
}
