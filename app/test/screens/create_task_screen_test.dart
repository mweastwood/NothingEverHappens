import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/screens/create_task_screen.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nothing_ever_happens/l10n/app_localizations.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nothing_ever_happens/logic/family_repository.dart';
import 'package:nothing_ever_happens/logic/auth_repository.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';

import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'create_task_screen_test.mocks.dart';
import '../test_helper.dart';

Widget buildTestProviderScope({
  required Widget child,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith((ref) => Stream.value(null)),
      ...overrides,
    ],
    child: child,
  );
}

@GenerateMocks([TaskRepository])
void main() {
  setUp(() {
    AppClock.setMockTime(DateTime(2026, 3, 8, 9, 0));
  });

  tearDown(() {
    AppClock.reset();
  });

  testWidgets('CreateTaskScreen renders form and saves task', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildTestableWidget(
        child: buildTestProviderScope(child: const CreateTaskScreen()),
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
        child: buildTestProviderScope(child: const CreateTaskScreen()),
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
        child: buildTestProviderScope(child: const CreateTaskScreen()),
      ),
    );

    // Change to Daily
    await tester.tap(find.text('Repeating'));
    await tester.pumpAndSettle();

    // Check for interval field
    expect(find.byKey(const Key('interval_text_field')), findsOneWidget);
  });

  testGoldens('CreateTaskScreen renders correctly', (tester) async {
    await tester.pumpWidgetBuilder(
      const CreateTaskScreen(),
      wrapper: (child) => l10nMaterialAppWrapper(
        theme: ThemeData.light(
          useMaterial3: true,
        ).copyWith(shadowColor: Colors.transparent),
        platform: TargetPlatform.android,
      )(buildTestProviderScope(child: child)),
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
      when(
        mockRepository.addTaskSchedule(any),
      ).thenAnswer((_) => completer.future);

      await tester.pumpWidgetBuilder(
        const CreateTaskScreen(),
        wrapper: (child) =>
            l10nMaterialAppWrapper(
              theme: ThemeData.light(
                useMaterial3: true,
              ).copyWith(shadowColor: Colors.transparent),
              platform: TargetPlatform.android,
            )(
              buildTestProviderScope(
                overrides: [
                  taskRepositoryProvider.overrideWithValue(mockRepository),
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
        theme: ThemeData.light(
          useMaterial3: true,
        ).copyWith(shadowColor: Colors.transparent),
        platform: TargetPlatform.android,
      )(buildTestProviderScope(child: child)),
      surfaceSize: const Size(800, 800),
    );

    // Switch to Monthly
    await tester.tap(find.text('Repeating'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recurrence_chip_monthly')));
    await tester.pumpAndSettle();

    await screenMatchesGolden(tester, 'create_task_screen_monthly');
  });

  testGoldens('CreateTaskScreen renders yearly configuration correctly', (
    tester,
  ) async {
    await tester.pumpWidgetBuilder(
      const CreateTaskScreen(),
      wrapper: (child) => l10nMaterialAppWrapper(
        theme: ThemeData.light(
          useMaterial3: true,
        ).copyWith(shadowColor: Colors.transparent),
        platform: TargetPlatform.android,
      )(buildTestProviderScope(child: child)),
      surfaceSize: const Size(800, 800),
    );

    // Switch to Yearly
    await tester.tap(find.text('Repeating'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recurrence_chip_yearly')));
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
        child: buildTestProviderScope(
          overrides: [taskRepositoryProvider.overrideWithValue(mockRepository)],
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
        'Test TaskSchedule',
      );
      await tester.pump();

      // Simulate Enter key
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      verify(mockRepository.addTaskSchedule(any)).called(1);
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
          'Test TaskSchedule',
        );
        // Focus description
        await tester.tap(find.widgetWithText(TextFormField, 'Description'));
        await tester.pump();

        // Simulate Enter key - this should be consumed by the multiline text field or ignored by our action
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();

        verifyNever(mockRepository.addTaskSchedule(any));
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

      verifyNever(mockRepository.addTaskSchedule(any));
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
      when(
        mockRepository.addTaskSchedule(any),
      ).thenAnswer((_) => completer.future);

      await tester.pumpWidget(createWidgetUnderTest());

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Test TaskSchedule',
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
      when(
        mockRepository.addTaskSchedule(any),
      ).thenThrow(Exception('Firestore Error'));

      await tester.pumpWidget(createWidgetUnderTest());

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Test TaskSchedule',
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
        'Test TaskSchedule',
      );
      await tester.enterText(
        find.byKey(const Key('estimated_effort_field')),
        '45',
      );
      await tester.pump();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final captured =
          verify(mockRepository.addTaskSchedule(captureAny)).captured.single
              as TaskSchedule;
      expect(captured.title, 'Test TaskSchedule');
      expect(captured.estimatedDuration, const Duration(minutes: 45));
    });

    testWidgets('Configures and saves Monthly day of month task successfully', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Monthly TaskSchedule',
      );

      // Select Monthly recurrence
      await tester.tap(find.text('Repeating'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('recurrence_chip_monthly')));
      await tester.pumpAndSettle();

      // Enter Months Interval
      await tester.enterText(find.byKey(const Key('interval_text_field')), '3');

      // Enter Day of Month (e.g. 15)
      await tester.enterText(find.byKey(const Key('day_text_field')), '15');
      await tester.pump();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final captured =
          verify(mockRepository.addTaskSchedule(captureAny)).captured.single
              as TaskSchedule;
      expect(captured.title, 'Monthly TaskSchedule');
      expect(captured.schedules.first, isA<MonthlySchedule>());
      final schedule = captured.schedules.first as MonthlySchedule;
      expect(schedule.interval, 3);
      expect(schedule.dayOfMonth, 15);
    });

    testWidgets(
      'Validates day of month cannot exceed 28 on Monthly configuration',
      (WidgetTester tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Title'),
          'Invalid Monthly TaskSchedule',
        );

        // Select Monthly recurrence
        await tester.tap(find.text('Repeating'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('recurrence_chip_monthly')));
        await tester.pumpAndSettle();

        // Enter invalid day of month (e.g. 29)
        await tester.enterText(find.byKey(const Key('day_text_field')), '29');
        await tester.pump();

        await tester.tap(find.text('Save'));
        await tester.pump(); // Run validator

        expect(find.text('Enter 1-28'), findsOneWidget);
        verifyNever(mockRepository.addTaskSchedule(any));
      },
    );

    testWidgets('Configures and saves Yearly task successfully', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Yearly TaskSchedule',
      );

      // Select Yearly recurrence
      await tester.tap(find.text('Repeating'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('recurrence_chip_yearly')));
      await tester.pumpAndSettle();

      // Enter Years Interval
      await tester.enterText(find.byKey(const Key('interval_text_field')), '2');

      // Day
      await tester.enterText(find.widgetWithText(TextFormField, 'Day'), '24');
      await tester.pump();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final captured =
          verify(mockRepository.addTaskSchedule(captureAny)).captured.single
              as TaskSchedule;
      expect(captured.title, 'Yearly TaskSchedule');
      expect(captured.schedules.first, isA<YearlySchedule>());
      final schedule = captured.schedules.first as YearlySchedule;
      expect(schedule.interval, 2);
      expect(
        schedule.month,
        3,
      ); // Initialized from current schedule's month (March)
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

    Widget createWidget({TaskSchedule? taskToEdit}) {
      return buildTestableWidget(
        child: buildTestProviderScope(
          overrides: [
            taskRepositoryProvider.overrideWithValue(mockTaskRepository),
            familyRepositoryProvider.overrideWithValue(familyRepository),
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

        final familyTask = TaskSchedule(
          id: 'family-task-1',
          title: 'Family Chore',
          description: 'Clean the kitchen',
          schedules: [
            OneOffSchedule(
              date: const CivilDay(year: 2026, month: 6, day: 2),
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

      final familyTask = TaskSchedule(
        id: 'family-task-1',
        title: 'Family Chore',
        description: 'Clean the kitchen',
        schedules: [
          OneOffSchedule(
            date: const CivilDay(year: 2026, month: 6, day: 2),
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
      'shows task title in AppBar when editing and scrolled down, updating dynamically',
      (WidgetTester tester) async {
        // Set physical size and device pixel ratio to ensure layout is scrollable
        tester.view.physicalSize = const Size(800, 400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final existingTask = TaskSchedule(
          id: 'existing-id',
          title: 'Original Title',
          description: 'Original Desc',
          schedules: List.generate(
            10,
            (index) => OneOffSchedule(
              date: CivilDay(year: 2026, month: 3, day: 8 + index),
              startRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 9, minute: 0),
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 17, minute: 0),
              ),
            ),
          ),
        );

        await tester.pumpWidget(createWidget(taskToEdit: existingTask));
        await tester.pumpAndSettle();

        // 1. Initially, Title field is visible, so AppBar title should be "Edit Task"
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Edit Task'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Original Title'),
          ),
          findsNothing,
        );

        // 2. Scroll down to push the Title field out of view
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();

        // AppBar title should now show the task's title ("Original Title")
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Original Title'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Edit Task'),
          ),
          findsNothing,
        );

        // 3. Edit the title field (scrolling back up to make it editable or just enter text)
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, 300),
        );
        await tester.pumpAndSettle();

        final titleFieldFinder = find.widgetWithText(TextFormField, 'Title');
        await tester.enterText(titleFieldFinder, 'Updated Title');
        await tester.pumpAndSettle();

        // Scroll down again to see the updated title in the AppBar
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Updated Title'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Original Title'),
          ),
          findsNothing,
        );
      },
    );

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

        when(
          mockTaskRepository.addTaskSchedule(any),
        ).thenAnswer((_) => Future.value());

        await tester.pumpWidget(createWidget());
        await tester.pump();

        // Enter title
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Title'),
          'Oneoff task notification',
        );

        // Tap Add Notification button
        final addNotifFinder = find.byKey(const Key('add_notification_button'));
        expect(addNotifFinder, findsOneWidget);
        await tester.tap(addNotifFinder);
        await tester.pumpAndSettle();

        // Save the task
        await tester.tap(find.byKey(const Key('save_task_button')));
        await tester.pumpAndSettle();

        // Verify the task added has a notification time scheduled in dailyTimes
        final captured =
            verify(
                  mockTaskRepository.addTaskSchedule(captureAny),
                ).captured.single
                as TaskSchedule;
        expect(captured.schedules, isNotEmpty);
        expect(captured.schedules.first.notificationRelativeTimes, isNotEmpty);
      },
    );

    testWidgets('calculates and shows upcoming occurrences dynamically', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 2500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await firestore.collection('users').doc('test-user-id').set({
        'familyId': '',
        'familyRole': '',
      });

      await tester.pumpWidget(createWidget());
      await tester.pump();

      // Initially one-off, should NOT show occurrences preview
      expect(find.byKey(const Key('occurrence_card_0')), findsNothing);
      expect(find.byKey(const Key('occurrence_card_1')), findsNothing);

      // Switch to Daily schedule
      await tester.tap(find.text('Repeating'));
      await tester.pumpAndSettle();

      // Should show 10 occurrences by default (maxOccurrences = 10 in CreateTaskScreen)
      expect(find.byKey(const Key('occurrence_card_0')), findsOneWidget);
      expect(find.byKey(const Key('occurrence_card_9')), findsOneWidget);
      expect(find.byKey(const Key('occurrence_card_10')), findsNothing);

      // Change interval to 3
      final intervalField = find.byKey(const Key('interval_text_field'));
      expect(intervalField, findsOneWidget);
      await tester.enterText(intervalField, '3');
      await tester.pumpAndSettle();

      // Verify occurrences updated (dynamic preview rebuild)
      expect(find.byKey(const Key('occurrence_card_0')), findsOneWidget);
      expect(find.byKey(const Key('occurrence_card_9')), findsOneWidget);
      expect(find.byKey(const Key('occurrence_card_10')), findsNothing);
    });
  });

  group('Undo edit integration', () {
    late MockTaskRepository mockRepository;

    setUp(() {
      mockRepository = MockTaskRepository();
    });

    testWidgets(
      'editing a task shows undo snackbar and tapping undo reverts changes',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1000, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final existingTask = TaskSchedule(
          id: 'edit-task-1',
          title: 'Original Title',
          description: 'Original Description',
          schedules: [
            OneOffSchedule(
              date: const CivilDay(year: 2026, month: 3, day: 9),
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

        when(
          mockRepository.updateTaskSchedule(any),
        ).thenAnswer((_) => Future.value());

        // Use a MaterialApp with a home that navigates to CreateTaskScreen
        // so the SnackBar persists after the screen pops.
        await tester.pumpWidget(
          buildTestProviderScope(
            overrides: [
              taskRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CreateTaskScreen(taskToEdit: existingTask),
                          ),
                        );
                      },
                      child: const Text('Open Edit'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        // Navigate to the CreateTaskScreen
        await tester.tap(find.text('Open Edit'));
        await tester.pumpAndSettle();

        // Edit the title
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Title'),
          'Updated Title',
        );
        await tester.pump();

        // Tap Save
        final saveButton = find.byKey(const Key('save_task_button'));
        await tester.ensureVisible(saveButton);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        // Verify updateTaskSchedule was called (not addTaskSchedule)
        verify(mockRepository.updateTaskSchedule(any)).called(1);
        verifyNever(mockRepository.addTaskSchedule(any));

        // The screen should have popped back to the home screen
        expect(find.text('Open Edit'), findsOneWidget);

        // The SnackBar should still be visible on the parent scaffold
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('Undo'), findsOneWidget);

        // Tap Undo
        await tester.tap(find.text('Undo'));
        await tester.pump();
        await tester.pumpAndSettle();

        // Verify updateTaskSchedule was called again to revert
        verify(mockRepository.updateTaskSchedule(any)).called(1);
      },
    );
  });
}
