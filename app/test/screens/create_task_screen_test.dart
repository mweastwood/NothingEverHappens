import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:nothing_ever_happens/screens/create_task_screen.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'create_task_screen_test.mocks.dart';

@GenerateMocks([TaskRepository])
void main() {
  testWidgets('CreateTaskScreen renders form and saves task', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: CreateTaskScreen()));

    // Verify initial state
    expect(find.text('New Task'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Title'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Description'), findsOneWidget);

    // Verify new buttons
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);

    // Enter text
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Buy Milk',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Description'),
      'Or else',
    );

    // Tap save (ensure visible first)
    final saveButton = find.text('Save');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
  });

  testWidgets('CreateTaskScreen validates title', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(
      1000,
      2000,
    ); // Tall enough to see button
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: CreateTaskScreen()));

    // Tap save without entering title
    final saveButton = find.text('Save');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pump(); // Pump frame for validation error to appear

    // Verify error message
    // It should appear below the title field, which is at the top, so it should be visible.
    expect(find.text('Please enter a title'), findsOneWidget);
  });

  testWidgets('CreateTaskScreen shows interval input for Daily schedule', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: CreateTaskScreen()));

    // Change to Daily
    final dailySegment = find.text('Daily');
    await tester.ensureVisible(dailySegment);
    await tester.tap(dailySegment);
    await tester.pumpAndSettle();

    // Check for interval field
    expect(find.widgetWithText(TextFormField, 'Days Interval'), findsOneWidget);
  });

  testGoldens('CreateTaskScreen renders correctly', (tester) async {
    await tester.pumpWidgetBuilder(
      const CreateTaskScreen(),
      wrapper: materialAppWrapper(
        theme: ThemeData.light(useMaterial3: true).copyWith(
          shadowColor: Colors.transparent,
          textTheme: ThemeData.light(
            useMaterial3: true,
          ).textTheme.apply(fontFamily: 'Ahem'),
        ),
        platform: TargetPlatform.android,
      ),
      surfaceSize: const Size(800, 800),
    );
    await screenMatchesGolden(tester, 'create_task_screen');
  });

  group('Shortcuts', () {
    late MockTaskRepository mockRepository;

    setUp(() {
      mockRepository = MockTaskRepository();
    });

    Widget createWidgetUnderTest() {
      return MaterialApp(
        home: Provider<TaskRepository?>.value(
          value: mockRepository,
          child: const CreateTaskScreen(),
        ),
      );
    }

    testWidgets('Title field is focused by default', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Find the first EditableText which should be the title field due to autofocus
      final EditableText titleEditableText = tester.widget(
        find.byType(EditableText).first,
      );
      expect(titleEditableText.autofocus, isTrue);

      final FocusNode focusNode = Focus.of(
        tester.element(find.byType(EditableText).first),
      );
      expect(focusNode.hasFocus, isTrue);
    });

    testWidgets('Pressing Enter saves the task when title is focused', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Test Task',
      );
      await tester.pump();

      // Simulate Enter key
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      verify(mockRepository.addTask(any)).called(1);
      expect(
        find.byType(CreateTaskScreen),
        findsNothing,
      ); // Screen should be popped
    });

    testWidgets(
      'Pressing Enter does NOT save the task when description is focused',
      (WidgetTester tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Title'),
          'Test Task',
        );
        // Focus description
        await tester.tap(find.widgetWithText(TextFormField, 'Description'));
        await tester.pump();

        // Simulate Enter key - this should be consumed by the multiline text field or ignored by our action
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();

        verifyNever(mockRepository.addTask(any));
        expect(
          find.byType(CreateTaskScreen),
          findsOneWidget,
        ); // Screen should still be there
      },
    );

    testWidgets('Pressing Escape discards the task', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Simulate Escape key
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      verifyNever(mockRepository.addTask(any));
      expect(
        find.byType(CreateTaskScreen),
        findsNothing,
      ); // Screen should be popped
    });
  });
}
