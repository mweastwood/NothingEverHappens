import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/screens/create_task_screen.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/task.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nothing_ever_happens/logic/family_repository.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';

import 'create_task_screen_test.mocks.dart';
import 'package:nothing_ever_happens/logic/error_handler.dart';
import '../test_helper.dart';

@GenerateMocks([TaskRepository])
void main() {
  testWidgets('CreateTaskScreen renders form and saves task', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildTestableWidget(
        child: Provider<ErrorHandler>(
          create: (_) => ErrorHandler(),
          child: const CreateTaskScreen(),
        ),
      ),
    );

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

    await tester.pumpWidget(
      buildTestableWidget(
        child: Provider<ErrorHandler>(
          create: (_) => ErrorHandler(),
          child: const CreateTaskScreen(),
        ),
      ),
    );

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

    await tester.pumpWidget(
      buildTestableWidget(
        child: Provider<ErrorHandler>(
          create: (_) => ErrorHandler(),
          child: const CreateTaskScreen(),
        ),
      ),
    );

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
      wrapper: (child) => l10nMaterialAppWrapper(
        theme: ThemeData.light(useMaterial3: true).copyWith(
          shadowColor: Colors.transparent,
          textTheme: ThemeData.light(
            useMaterial3: true,
          ).textTheme.apply(fontFamily: 'Ahem'),
        ),
        platform: TargetPlatform.android,
      )(Provider<ErrorHandler>(create: (_) => ErrorHandler(), child: child)),
      surfaceSize: const Size(800, 800),
    );
    await screenMatchesGolden(tester, 'create_task_screen');
  });

  testGoldens('CreateTaskScreen renders saving state correctly', (
    tester,
  ) async {
    CreateTaskScreen.saveTimeout = const Duration(minutes: 30);
    CreateTaskScreen.debugDisableAnimations = true;
    try {
      final mockRepository = MockTaskRepository();
      final completer = Completer<void>();
      when(mockRepository.addTask(any)).thenAnswer((_) => completer.future);

      await tester.pumpWidgetBuilder(
        const CreateTaskScreen(),
        wrapper: (child) =>
            l10nMaterialAppWrapper(
              theme: ThemeData.light(useMaterial3: true).copyWith(
                shadowColor: Colors.transparent,
                textTheme: ThemeData.light(
                  useMaterial3: true,
                ).textTheme.apply(fontFamily: 'Ahem'),
              ),
              platform: TargetPlatform.android,
            )(
              MultiProvider(
                providers: [
                  Provider<ErrorHandler>(create: (_) => ErrorHandler()),
                  Provider<TaskRepository?>.value(value: mockRepository),
                ],
                child: child,
              ),
            ),
        surfaceSize: const Size(800, 800),
      );

      // Enter a valid title to pass form validation
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Test Saving State',
      );
      await tester.pump();

      // Tap Save to trigger the saving state
      await tester.tap(find.byKey(const Key('save_task_button')));
      await tester.pump(); // Start saving operation

      // Verify loading elements are visible
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await screenMatchesGolden(tester, 'create_task_screen_saving');

      // Clean up pending future to prevent background timeout leak
      completer.complete();
      await tester.pumpAndSettle();
    } finally {
      CreateTaskScreen.saveTimeout = const Duration(seconds: 10);
      CreateTaskScreen.debugDisableAnimations = false;
    }
  });

  testGoldens('CreateTaskScreen renders monthly configuration correctly', (
    tester,
  ) async {
    await tester.pumpWidgetBuilder(
      const CreateTaskScreen(),
      wrapper: (child) => l10nMaterialAppWrapper(
        theme: ThemeData.light(useMaterial3: true).copyWith(
          shadowColor: Colors.transparent,
          textTheme: ThemeData.light(
            useMaterial3: true,
          ).textTheme.apply(fontFamily: 'Ahem'),
        ),
        platform: TargetPlatform.android,
      )(Provider<ErrorHandler>(create: (_) => ErrorHandler(), child: child)),
      surfaceSize: const Size(800, 800),
    );

    // Switch to Monthly
    final monthlySegment = find.text('Monthly');
    await tester.ensureVisible(monthlySegment);
    await tester.tap(monthlySegment);
    await tester.pumpAndSettle();

    await screenMatchesGolden(tester, 'create_task_screen_monthly');
  });

  testGoldens('CreateTaskScreen renders yearly configuration correctly', (
    tester,
  ) async {
    await tester.pumpWidgetBuilder(
      const CreateTaskScreen(),
      wrapper: (child) => l10nMaterialAppWrapper(
        theme: ThemeData.light(useMaterial3: true).copyWith(
          shadowColor: Colors.transparent,
          textTheme: ThemeData.light(
            useMaterial3: true,
          ).textTheme.apply(fontFamily: 'Ahem'),
        ),
        platform: TargetPlatform.android,
      )(Provider<ErrorHandler>(create: (_) => ErrorHandler(), child: child)),
      surfaceSize: const Size(800, 800),
    );

    // Switch to Yearly
    final yearlySegment = find.text('Yearly');
    await tester.ensureVisible(yearlySegment);
    await tester.tap(yearlySegment);
    await tester.pumpAndSettle();

    await screenMatchesGolden(tester, 'create_task_screen_yearly');
  });

  group('Shortcuts', () {
    late MockTaskRepository mockRepository;

    setUp(() {
      mockRepository = MockTaskRepository();
    });

    Widget createWidgetUnderTest() {
      return buildTestableWidget(
        child: MultiProvider(
          providers: [
            Provider<ErrorHandler>(create: (_) => ErrorHandler()),
            Provider<TaskRepository?>.value(value: mockRepository),
          ],
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

    testWidgets('Shows loading indicator when saving', (
      WidgetTester tester,
    ) async {
      // Use a completer to control when addTask finishes
      final completer = Completer<void>();
      when(mockRepository.addTask(any)).thenAnswer((_) => completer.future);

      await tester.pumpWidget(createWidgetUnderTest());

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Test Task',
      );
      await tester.tap(find.text('Save'));
      await tester.pump(); // Start the save operation

      // Verify loading indicator is present
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Save'), findsNothing);

      // Verify buttons are disabled
      final discardButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Discard'),
      );
      expect(discardButton.onPressed, isNull);

      final saveButton = tester.widget<FilledButton>(
        find.byKey(const Key('save_task_button')),
      );
      expect(saveButton.onPressed, isNull);

      // Complete the operation
      completer.complete();
      await tester.pumpAndSettle();

      expect(find.byType(CreateTaskScreen), findsNothing);
    });

    testWidgets('Shows error dialog when saving fails', (
      WidgetTester tester,
    ) async {
      when(mockRepository.addTask(any)).thenThrow(Exception('Firestore Error'));

      await tester.pumpWidget(createWidgetUnderTest());

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Test Task',
      );
      await tester.tap(find.text('Save'));
      await tester.pump(); // Start the save operation
      await tester.pumpAndSettle(); // Wait for dialog to appear

      expect(find.text('Error Occurred'), findsOneWidget);
      expect(find.textContaining('Firestore Error'), findsOneWidget);
      expect(find.byType(CreateTaskScreen), findsOneWidget); // Still there
    });

    testWidgets('Saves task with estimated duration', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Test Task',
      );
      await tester.enterText(
        find.byKey(const Key('estimated_effort_field')),
        '45',
      );
      await tester.pump();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final captured =
          verify(mockRepository.addTask(captureAny)).captured.single as Task;
      expect(captured.title, 'Test Task');
      expect(captured.estimatedDuration, const Duration(minutes: 45));
    });

    testWidgets('Configures and saves Monthly day of month task successfully', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Monthly Task',
      );

      // Select Monthly recurrence
      final monthlySegment = find.text('Monthly');
      await tester.ensureVisible(monthlySegment);
      await tester.tap(monthlySegment);
      await tester.pumpAndSettle();

      // Enter Months Interval
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Months Interval'),
        '3',
      );

      // Enter Day of Month (e.g. 15)
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Day of Month (1-28, or -1 to -28)'),
        '15',
      );
      await tester.pump();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final captured =
          verify(mockRepository.addTask(captureAny)).captured.single as Task;
      expect(captured.title, 'Monthly Task');
      expect(captured.schedule, isA<MonthlySchedule>());
      final schedule = captured.schedule as MonthlySchedule;
      expect(schedule.interval, 3);
      expect(schedule.dayOfMonth, 15);
    });

    testWidgets(
      'Validates day of month cannot exceed 28 on Monthly configuration',
      (WidgetTester tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Title'),
          'Invalid Monthly Task',
        );

        // Select Monthly recurrence
        final monthlySegment = find.text('Monthly');
        await tester.ensureVisible(monthlySegment);
        await tester.tap(monthlySegment);
        await tester.pumpAndSettle();

        // Enter invalid day of month (e.g. 29)
        await tester.enterText(
          find.widgetWithText(
            TextFormField,
            'Day of Month (1-28, or -1 to -28)',
          ),
          '29',
        );
        await tester.pump();

        await tester.tap(find.text('Save'));
        await tester.pump(); // Run validator

        expect(
          find.text('Please enter a valid day number: 1 to 28, or -1 to -28'),
          findsOneWidget,
        );
        verifyNever(mockRepository.addTask(any));
      },
    );

    testWidgets('Configures and saves Yearly task successfully', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Yearly Task',
      );

      // Select Yearly recurrence
      final yearlySegment = find.text('Yearly');
      await tester.ensureVisible(yearlySegment);
      await tester.tap(yearlySegment);
      await tester.pumpAndSettle();

      // Enter Years Interval
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Years Interval'),
        '2',
      );

      // Day of month
      await tester.enterText(find.widgetWithText(TextFormField, 'Day'), '24');
      await tester.pump();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final captured =
          verify(mockRepository.addTask(captureAny)).captured.single as Task;
      expect(captured.title, 'Yearly Task');
      expect(captured.schedule, isA<YearlySchedule>());
      final schedule = captured.schedule as YearlySchedule;
      expect(schedule.interval, 2);
      expect(schedule.month, 1); // Default is January (1)
      expect(schedule.day, 24);
    });
  });

  group('Agile Scoping and Permissions', () {
    late FakeFirebaseFirestore firestore;
    late MockTaskRepository mockTaskRepository;
    late FamilyRepository familyRepository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      mockTaskRepository = MockTaskRepository();
      familyRepository = FamilyRepository(
        firestore: firestore,
        userId: 'test-user-id',
        userEmail: 'test@example.com',
        userDisplayName: 'Test User',
      );
    });

    Widget createWidget({Task? taskToEdit}) {
      return buildTestableWidget(
        child: MultiProvider(
          providers: [
            Provider<ErrorHandler>(create: (_) => ErrorHandler()),
            Provider<TaskRepository?>.value(value: mockTaskRepository),
            Provider<FamilyRepository?>.value(value: familyRepository),
          ],
          child: CreateTaskScreen(taskToEdit: taskToEdit),
        ),
      );
    }

    testWidgets(
      'shows family toggle and priority dropdown if user is in a family',
      (WidgetTester tester) async {
        await firestore.collection('users').doc('test-user-id').set({
          'familyId': 'fam-123',
          'familyRole': 'parent',
        });

        await tester.pumpWidget(createWidget());
        await tester.pump();

        expect(find.byKey(const Key('is_family_toggle')), findsOneWidget);
        expect(find.byKey(const Key('task_priority_dropdown')), findsOneWidget);
      },
    );

    testWidgets('hides family toggle if user is not in a family', (
      WidgetTester tester,
    ) async {
      await firestore.collection('users').doc('test-user-id').set({
        'familyId': '',
        'familyRole': '',
      });

      await tester.pumpWidget(createWidget());
      await tester.pump();

      expect(find.byKey(const Key('is_family_toggle')), findsNothing);
      expect(find.byKey(const Key('task_priority_dropdown')), findsOneWidget);
    });

    testWidgets(
      'disables editing and shows warning if editing family task as non-parent',
      (WidgetTester tester) async {
        await firestore.collection('users').doc('test-user-id').set({
          'familyId': 'fam-123',
          'familyRole': 'non-parent',
        });

        final familyTask = Task(
          id: 'family-task-1',
          title: 'Family Chore',
          description: 'Clean the kitchen',
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          schedule: OneOffSchedule(
            date: const CivilDay(year: 2026, month: 6, day: 2),
          ),
          isFamily: true,
        );

        await tester.pumpWidget(createWidget(taskToEdit: familyTask));
        await tester.pump();

        expect(find.text('View Task'), findsOneWidget);
        expect(find.text('Only parents can edit family tasks'), findsOneWidget);

        final titleField = tester.widget<TextFormField>(
          find.widgetWithText(TextFormField, 'Title'),
        );
        expect(titleField.enabled, isFalse);

        final saveButton = tester.widget<FilledButton>(
          find.byKey(const Key('save_task_button')),
        );
        expect(saveButton.onPressed, isNull);
      },
    );

    testWidgets('allows editing family task if user is a parent', (
      WidgetTester tester,
    ) async {
      await firestore.collection('users').doc('test-user-id').set({
        'familyId': 'fam-123',
        'familyRole': 'parent',
      });

      final familyTask = Task(
        id: 'family-task-1',
        title: 'Family Chore',
        description: 'Clean the kitchen',
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        schedule: OneOffSchedule(
          date: const CivilDay(year: 2026, month: 6, day: 2),
        ),
        isFamily: true,
      );

      await tester.pumpWidget(createWidget(taskToEdit: familyTask));
      await tester.pump();

      expect(find.text('Edit Task'), findsOneWidget);
      expect(find.text('Only parents can edit family tasks'), findsNothing);

      final titleField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Title'),
      );
      expect(titleField.enabled, isTrue);

      final saveButton = tester.widget<FilledButton>(
        find.byKey(const Key('save_task_button')),
      );
      expect(saveButton.onPressed, isNotNull);
    });

    testWidgets(
      'configures and saves One-off task with custom notification successfully',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1000, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await firestore.collection('users').doc('test-user-id').set({
          'familyId': '',
          'familyRole': '',
        });

        when(mockTaskRepository.addTask(any)).thenAnswer((_) => Future.value());

        await tester.pumpWidget(createWidget());
        await tester.pump();

        // Enter title
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Title'),
          'Oneoff task notification',
        );

        // Verify custom notification selector is visible and click it
        final reminderBtnFinder = find.byKey(
          const Key('one_off_notification_button'),
        );
        expect(reminderBtnFinder, findsOneWidget);
        expect(find.text('None'), findsOneWidget);

        await tester.ensureVisible(reminderBtnFinder);
        await tester.tap(reminderBtnFinder);
        await tester.pumpAndSettle();

        // Tap OK on the time picker dialog to select the default/initial time
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        // Check if button text updated to show the time
        expect(find.text('None'), findsNothing);

        // Save the task
        await tester.tap(find.byKey(const Key('save_task_button')));
        await tester.pumpAndSettle();

        // Verify the task added has a notification time scheduled in dailyTimes
        final captured =
            verify(mockTaskRepository.addTask(captureAny)).captured.single
                as Task;
        expect(captured.dailyTimes, isNotEmpty);
        expect(captured.dailyTimes.first.notificationTime, isNotNull);
      },
    );
  });
}
