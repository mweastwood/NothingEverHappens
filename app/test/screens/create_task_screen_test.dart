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
import 'package:flutter_riverpod/misc.dart';
import 'package:nothing_ever_happens/l10n/app_localizations.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nothing_ever_happens/logic/family_repository.dart';
import 'package:nothing_ever_happens/logic/auth_repository.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';

import 'package:nothing_ever_happens/logic/app_clock.dart';

import 'package:nothing_ever_happens/widgets/missed_occurrence_policy_selector.dart';
import 'package:nothing_ever_happens/widgets/create_task/task_basic_info_section.dart';
import 'create_task_screen_test.mocks.dart';
import '../test_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nothing_ever_happens/widgets/standard_choice_chip.dart';
import 'package:nothing_ever_happens/screens/help_screen.dart';

class _FakeAuthUser extends Fake implements User {
  final String _uid;
  _FakeAuthUser(this._uid);

  @override
  String get uid => _uid;
}

Widget buildTestProviderScope({
  required Widget child,
  List<Override> overrides = const [],
}) {
  final allOverrides = [
    authStateProvider.overrideWithValue(const AsyncData(null)),
    ...defaultTestOverrides,
    ...overrides,
  ];
  final map = <Override, Override>{};
  for (final o in allOverrides) {
    map[o.origin] = o;
  }
  return ProviderScope(overrides: map.values.toList(), child: child);
}

@GenerateMocks([TaskRepository])
void main() {
  setUp(() {
    AppClock.setMockTime(DateTime(2026, 3, 8, 9, 0));
    addTearDown(AppClock.reset);
  });

  tearDown(() {});

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

  testWidgets(
    'CreateTaskScreen defaults to repeating Daily schedule when defaultToRepeating is true',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          child: buildTestProviderScope(
            child: const CreateTaskScreen(defaultToRepeating: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('New Task'), findsOneWidget);
      // Verify Daily schedule summary text is shown
      expect(find.text('Daily, every 1 day(s)'), findsOneWidget);
      expect(find.textContaining('One-off on'), findsNothing);
    },
  );

  testWidgets(
    'CreateTaskScreen defaults to one-off schedule when defaultToRepeating is false',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          child: buildTestProviderScope(
            child: const CreateTaskScreen(defaultToRepeating: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('New Task'), findsOneWidget);
      // Verify One-off schedule summary text is shown (since mock time is 2026-03-08, tomorrow is 2026-03-09)
      expect(find.text('One-off on 2026-03-09'), findsOneWidget);
      expect(find.text('Daily, every 1 day(s)'), findsNothing);
    },
  );

  testWidgets(
    'CreateTaskScreen shows help button and navigates to HelpScreen (Scheduling tab)',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          child: buildTestProviderScope(child: const CreateTaskScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Verify help button exists in AppBar
      final helpIconFinder = find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.help_outline),
      );
      expect(helpIconFinder, findsOneWidget);

      // Tap help button
      await tester.tap(helpIconFinder);
      await tester.pumpAndSettle();

      // Verify HelpScreen is pushed
      final helpScreenFinder = find.byType(HelpScreen);
      expect(helpScreenFinder, findsOneWidget);

      // Verify HelpScreen has initialIndex = 1 (Scheduling tab)
      final HelpScreen helpScreen = tester.widget(helpScreenFinder);
      expect(helpScreen.initialIndex, 1);
    },
  );

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
      when(
        mockRepository.getInstances(),
      ).thenAnswer((_) => const Stream.empty());
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
      when(
        mockRepository.getInstances(),
      ).thenAnswer((_) => const Stream.empty());
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
      await tester.enterText(find.byKey(const Key('yearly_day_field')), '24');
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

    testWidgets('Configures and saves skipIfNoCapacity task successfully', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidgetUnderTest());

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Skip Capacity Task',
      );

      // Enter estimated effort
      await tester.enterText(
        find.byKey(const Key('estimated_effort_field')),
        '45',
      );

      // Tap on Skip if capacity is exceeded checkbox
      final checkboxFinder = find.byKey(
        const Key('skip_if_no_capacity_checkbox'),
      );
      await tester.ensureVisible(checkboxFinder);
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      final saveButton = find.text('Save');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      final captured =
          verify(mockRepository.addTaskSchedule(captureAny)).captured.single
              as TaskSchedule;
      expect(captured.title, 'Skip Capacity Task');
      expect(captured.skipIfNoCapacity, isTrue);
    });
  });

  group('Agile Scoping and Permissions', () {
    late FakeFirebaseFirestore firestore;
    late MockTaskRepository mockTaskRepository;
    late FamilyRepository familyRepository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      mockTaskRepository = MockTaskRepository();
      when(
        mockTaskRepository.getInstances(),
      ).thenAnswer((_) => const Stream.empty());
      familyRepository = FamilyRepository(
        firestore: firestore,
        userId: 'test-user-id',
        userEmail: 'test@example.com',
        userDisplayName: 'Test User',
      );
    });

    Widget createWidget({
      TaskSchedule? taskToEdit,
      List<Override> extraOverrides = const [],
    }) {
      return buildTestableWidget(
        child: buildTestProviderScope(
          overrides: [
            taskRepositoryProvider.overrideWithValue(mockTaskRepository),
            familyRepositoryProvider.overrideWithValue(familyRepository),
            ...extraOverrides,
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

    testGoldens(
      'CreateTaskScreen renders family assignment card when user in family',
      (tester) async {
        await firestore.collection('users').doc('test-user-id').set({
          'familyId': 'fam-123',
          'familyRole': 'parent',
        });

        await tester.pumpWidgetBuilder(
          createWidget(),
          surfaceSize: const Size(800, 1000),
        );

        await screenMatchesGolden(tester, 'create_task_screen_in_family');
      },
    );

    testGoldens(
      'CreateTaskScreen renders family task with assignee selection when members present',
      (tester) async {
        await firestore.collection('users').doc('test-user-id').set({
          'familyId': 'fam-123',
          'familyRole': 'parent',
        });
        await firestore.collection('families').doc('fam-123').set({
          'name': 'Test Family',
          'members': {
            'test-user-id': {
              'userId': 'test-user-id',
              'displayName': 'Parent User',
              'email': 'parent@example.com',
              'role': 'parent',
            },
            'member-2': {
              'userId': 'member-2',
              'displayName': 'Child User',
              'email': 'child@example.com',
              'role': 'non-parent',
            },
          },
        });

        await tester.pumpWidgetBuilder(
          createWidget(
            taskToEdit: TaskSchedule(
              id: 'task-1',
              title: 'Clean Bedroom',
              description: 'Tidy up bedroom and fold laundry',
              isFamily: true,
              assignedUserId: 'member-2',
            ),
          ),
          surfaceSize: const Size(800, 1000),
        );

        await screenMatchesGolden(tester, 'create_task_screen_family_assigned');
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
      'converts family task to individual task and calls updateTaskSchedule with newIsFamily false',
      (WidgetTester tester) async {
        await firestore.collection('users').doc('test-user-id').set({
          'familyId': 'fam-123',
          'familyRole': 'parent',
        });

        when(
          mockTaskRepository.updateTaskSchedule(any),
        ).thenAnswer((_) async {});

        final familyTask = TaskSchedule(
          id: 'task-1',
          title: 'Family Chore',
          description: 'Desc',
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
        await tester.pumpAndSettle();

        final personalChip = find.byKey(const Key('personal_task_chip'));
        await tester.ensureVisible(personalChip);
        await tester.tap(personalChip);
        await tester.pumpAndSettle();

        final saveButton = find.byKey(const Key('save_task_button'));
        await tester.ensureVisible(saveButton);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        final verification = verify(
          mockTaskRepository.updateTaskSchedule(captureAny),
        );
        verification.called(1);
        final modification = verification.captured.single as TaskModification;
        expect(modification.newTask.isFamily, isFalse);
      },
    );

    testWidgets(
      'converts individual task to family task and calls updateTaskSchedule with newIsFamily true',
      (WidgetTester tester) async {
        await firestore.collection('users').doc('test-user-id').set({
          'familyId': 'fam-123',
          'familyRole': 'parent',
        });

        when(
          mockTaskRepository.updateTaskSchedule(any),
        ).thenAnswer((_) async {});

        final individualTask = TaskSchedule(
          id: 'task-2',
          title: 'Personal Chore',
          description: 'Desc',
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
          isFamily: false,
        );

        await tester.pumpWidget(createWidget(taskToEdit: individualTask));
        await tester.pumpAndSettle();

        final familyChip = find.byKey(const Key('is_family_toggle'));
        await tester.ensureVisible(familyChip);
        await tester.tap(familyChip);
        await tester.pumpAndSettle();

        final saveButton = find.byKey(const Key('save_task_button'));
        await tester.ensureVisible(saveButton);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        final verification = verify(
          mockTaskRepository.updateTaskSchedule(captureAny),
        );
        verification.called(1);
        final modification = verification.captured.single as TaskModification;
        expect(modification.newTask.isFamily, isTrue);
      },
    );

    testWidgets(
      'allows assigning family task to a specific member and saves assignedUserId',
      (WidgetTester tester) async {
        await firestore.collection('users').doc('test-user-id').set({
          'familyId': 'fam-123',
          'familyRole': 'parent',
        });
        await firestore.collection('families').doc('fam-123').set({
          'name': 'Test Family',
          'members': {
            'test-user-id': {
              'userId': 'test-user-id',
              'displayName': 'Parent User',
              'email': 'parent@example.com',
              'role': 'parent',
            },
            'member-2': {
              'userId': 'member-2',
              'displayName': 'Child User',
              'email': 'child@example.com',
              'role': 'non-parent',
            },
          },
        });

        when(mockTaskRepository.addTaskSchedule(any)).thenAnswer((_) async {});

        await tester.pumpWidget(createWidget());
        await tester.pumpAndSettle();

        // Switch to family task
        final familyChip = find.byKey(const Key('is_family_toggle'));
        await tester.ensureVisible(familyChip);
        await tester.tap(familyChip);
        await tester.pumpAndSettle();

        // Check member chips appear
        expect(find.text('Assign to'), findsOneWidget);
        expect(find.byKey(const Key('unassigned_member_chip')), findsOneWidget);
        expect(find.byKey(const Key('member_chip_member-2')), findsOneWidget);

        // Select member-2
        await tester.ensureVisible(
          find.byKey(const Key('member_chip_member-2')),
        );
        await tester.tap(find.byKey(const Key('member_chip_member-2')));
        await tester.pumpAndSettle();

        // Enter title and save
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Title'),
          'Clean Bedroom',
        );
        final saveButton = find.byKey(const Key('save_task_button'));
        await tester.ensureVisible(saveButton);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        final verification = verify(
          mockTaskRepository.addTaskSchedule(captureAny),
        );
        verification.called(1);
        final createdTask = verification.captured.single as TaskSchedule;
        expect(createdTask.isFamily, isTrue);
        expect(createdTask.assignedUserId, 'member-2');
      },
    );

    testWidgets(
      'displays "You" instead of name on assignment chip for current user',
      (WidgetTester tester) async {
        await firestore.collection('users').doc('test-user-id').set({
          'familyId': 'fam-123',
          'familyRole': 'parent',
        });
        await firestore.collection('families').doc('fam-123').set({
          'name': 'Test Family',
          'members': {
            'test-user-id': {
              'userId': 'test-user-id',
              'displayName': 'Parent User',
              'email': 'parent@example.com',
              'role': 'parent',
            },
            'member-2': {
              'userId': 'member-2',
              'displayName': 'Child User',
              'email': 'child@example.com',
              'role': 'non-parent',
            },
          },
        });

        final mockUser = _FakeAuthUser('test-user-id');

        await tester.pumpWidget(
          createWidget(
            extraOverrides: [
              authStateProvider.overrideWithValue(AsyncData(mockUser)),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Switch to family task
        final familyChip = find.byKey(const Key('is_family_toggle'));
        await tester.ensureVisible(familyChip);
        await tester.tap(familyChip);
        await tester.pumpAndSettle();

        final currentUserChip = tester.widget<StandardChoiceChip>(
          find.byKey(const Key('member_chip_test-user-id')),
        );
        final otherUserChip = tester.widget<StandardChoiceChip>(
          find.byKey(const Key('member_chip_member-2')),
        );

        expect(currentUserChip.label, 'You');
        expect(otherUserChip.label, 'Child User');
      },
    );

    testWidgets(
      'clears assignedUserId when switching from assigned family task to personal task',
      (WidgetTester tester) async {
        await firestore.collection('users').doc('test-user-id').set({
          'familyId': 'fam-123',
          'familyRole': 'parent',
        });
        await firestore.collection('families').doc('fam-123').set({
          'name': 'Test Family',
          'members': {
            'test-user-id': {
              'userId': 'test-user-id',
              'displayName': 'Parent User',
              'email': 'parent@example.com',
              'role': 'parent',
            },
            'member-2': {
              'userId': 'member-2',
              'displayName': 'Child User',
              'email': 'child@example.com',
              'role': 'non-parent',
            },
          },
        });

        when(
          mockTaskRepository.updateTaskSchedule(any),
        ).thenAnswer((_) async {});

        final assignedFamilyTask = TaskSchedule(
          id: 'task-assigned',
          title: 'Wash Dishes',
          description: 'Desc',
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
          assignedUserId: 'member-2',
        );

        await tester.pumpWidget(createWidget(taskToEdit: assignedFamilyTask));
        await tester.pumpAndSettle();

        // Switch to personal
        final personalChip = find.byKey(const Key('personal_task_chip'));
        await tester.ensureVisible(personalChip);
        await tester.tap(personalChip);
        await tester.pumpAndSettle();

        final saveButton = find.byKey(const Key('save_task_button'));
        await tester.ensureVisible(saveButton);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        final verification = verify(
          mockTaskRepository.updateTaskSchedule(captureAny),
        );
        verification.called(1);
        final modification = verification.captured.single as TaskModification;
        expect(modification.newTask.isFamily, isFalse);
        expect(modification.newTask.assignedUserId, isNull);
      },
    );

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
      'transitions app bar title earlier (as soon as top of title field goes under app bar)',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final existingTask = TaskSchedule(
          id: 'existing-id',
          title: 'Original Title',
          description: 'Original Desc',
          schedules: [
            OneOffSchedule(
              date: CivilDay(year: 2026, month: 3, day: 8),
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

        // 2. Scroll dynamically by exactly enough to push the top of the Title field under the App Bar
        // but keep the bottom of the Title field below the App Bar.
        final double appBarHeight = tester.getSize(find.byType(AppBar)).height;
        final titleFieldFinder = find.widgetWithText(TextFormField, 'Title');
        final double initialTop = tester.getTopLeft(titleFieldFinder).dy;

        // Calculate the drag amount to put the top of the text field exactly 1 pixel under the AppBar.
        final double dragAmount = initialTop - appBarHeight + 1.0;
        await tester.drag(
          find.byType(SingleChildScrollView),
          Offset(0, -dragAmount),
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
      },
    );

    testWidgets(
      'dismisses keyboard and unfocuses title field when scrolled/dragged',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createWidget());
        await tester.pumpAndSettle();

        final titleFinder = find.byType(EditableText).first;
        final titleElement = tester.element(titleFinder);

        // Verify focus node has focus (autofocus is true)
        expect(Focus.of(titleElement).hasFocus, isTrue);

        // Drag/scroll the list to dismiss keyboard (onDrag)
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -50),
        );
        await tester.pumpAndSettle();

        // Verify that focus is lost
        expect(Focus.of(titleElement).hasFocus, isFalse);
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

      // Initially one-off, starts now, so 0 future occurrences
      expect(find.byKey(const Key('spawned_occurrence_card_0')), findsNothing);

      // Switch to Daily schedule
      await tester.tap(find.text('Repeating'));
      await tester.pumpAndSettle();

      // Under the new rules, Daily schedule has next 10 instances pre-created
      for (int i = 0; i < 10; i++) {
        expect(find.byKey(Key('spawned_occurrence_card_$i')), findsOneWidget);
      }
      expect(find.byKey(const Key('spawned_occurrence_card_10')), findsNothing);

      // Change interval to 3
      final intervalField = find.byKey(const Key('interval_text_field'));
      await tester.ensureVisible(intervalField);
      await tester.enterText(intervalField, '3');
      await tester.pumpAndSettle();

      // Verify occurrences still has 10 cards (dynamic preview rebuild with new interval)
      for (int i = 0; i < 10; i++) {
        expect(find.byKey(Key('spawned_occurrence_card_$i')), findsOneWidget);
      }
      expect(find.byKey(const Key('spawned_occurrence_card_10')), findsNothing);
    });
  });

  group('Undo edit integration', () {
    late MockTaskRepository mockRepository;

    setUp(() {
      mockRepository = MockTaskRepository();
      when(
        mockRepository.getInstances(),
      ).thenAnswer((_) => const Stream.empty());
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

    testWidgets(
      'CreateTaskScreen hides MissedOccurrencePolicySelector for completion-relative tasks',
      (WidgetTester tester) async {
        final mockRepository = MockTaskRepository();
        when(
          mockRepository.getInstances(),
        ).thenAnswer((_) => const Stream.empty());
        when(mockRepository.addTaskSchedule(any)).thenAnswer((_) async {});

        final existingTask = TaskSchedule(
          id: 'existing-id',
          title: 'Completion Relative Task',
          description: 'Desc',
          schedules: [
            DailySchedule(
              id: 'daily-rule',
              scheduleId: 'existing-id',
              startDate: CivilDay(year: 2026, month: 7, day: 1),
              interval: 2,
              schedulingPolicy: const CompletionRelativePolicy(
                interval: Duration(days: 2),
                targetTime: TimeOfDay(hour: 9, minute: 0),
              ),
            ),
          ],
        );

        tester.view.physicalSize = const Size(1000, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          buildTestableWidget(
            child: buildTestProviderScope(
              overrides: [
                taskRepositoryProvider.overrideWithValue(mockRepository),
              ],
              child: CreateTaskScreen(taskToEdit: existingTask),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Expands the schedule card to see its contents
        final expandButton = find.byIcon(Icons.expand_more);
        if (expandButton.evaluate().isNotEmpty) {
          await tester.tap(expandButton);
          await tester.pumpAndSettle();
        }

        // Verify that MissedOccurrencePolicySelector is NOT visible
        expect(find.byType(MissedOccurrencePolicySelector), findsNothing);
      },
    );

    testWidgets(
      'CreateTaskScreen pre-populates all fields and clones schedules with new IDs when taskToDuplicate is provided',
      (WidgetTester tester) async {
        final mockRepository = MockTaskRepository();
        final existingTask = TaskSchedule(
          id: 'original-task-id',
          title: 'Existing Task Title',
          description: 'Existing Description',
          priority: TaskPriority.high,
          estimatedDuration: const Duration(minutes: 45),
          isFamily: false,
          skipIfNoCapacity: true,
          schedules: [
            DailySchedule(
              id: 'daily-rule-id',
              scheduleId: 'original-task-id',
              startDate: const CivilDay(year: 2026, month: 7, day: 1),
              interval: 2,
              startRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 8, minute: 0),
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 9, minute: 30),
              ),
            ),
          ],
        );

        tester.view.physicalSize = const Size(1000, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        TaskSchedule? createdTask;
        when(mockRepository.addTaskSchedule(any)).thenAnswer((
          invocation,
        ) async {
          createdTask = invocation.positionalArguments[0] as TaskSchedule;
        });

        await tester.pumpWidget(
          buildTestableWidget(
            child: buildTestProviderScope(
              overrides: [
                taskRepositoryProvider.overrideWithValue(mockRepository),
              ],
              child: CreateTaskScreen(taskToDuplicate: existingTask),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify title in app bar shows New Task rather than Edit Task
        expect(find.text('New Task'), findsOneWidget);

        // Verify pre-populated values
        expect(find.text('Existing Task Title'), findsOneWidget);
        expect(find.text('Existing Description'), findsOneWidget);
        expect(find.text('45'), findsOneWidget);

        // Tap Save
        final saveButton = find.text('Save');
        await tester.ensureVisible(saveButton);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        verify(mockRepository.addTaskSchedule(any)).called(1);
        verifyNever(mockRepository.updateTaskSchedule(any));

        expect(createdTask, isNotNull);
        expect(createdTask!.id, isNot(equals('original-task-id')));
        expect(createdTask!.title, 'Existing Task Title');
        expect(createdTask!.description, 'Existing Description');
        expect(createdTask!.priority, TaskPriority.high);
        expect(createdTask!.estimatedDuration, const Duration(minutes: 45));
        expect(createdTask!.skipIfNoCapacity, isTrue);
        expect(createdTask!.schedules.length, 1);
        expect(createdTask!.schedules.first.id, isNot(equals('daily-rule-id')));
        expect(createdTask!.schedules.first.scheduleId, createdTask!.id);
      },
    );

    testWidgets('submitting whitespace-only title triggers validation error', (
      WidgetTester tester,
    ) async {
      final mockRepository = MockTaskRepository();
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          child: buildTestProviderScope(
            overrides: [
              taskRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CreateTaskScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final titleField = find
          .descendant(
            of: find.byType(TaskBasicInfoSection),
            matching: find.byType(TextFormField),
          )
          .first;

      // Enter whitespace-only title
      await tester.enterText(titleField, '     ');
      await tester.pump();

      final saveButton = find.text('Save');
      await tester.tap(saveButton);
      await tester.pump();

      // Verify validation error
      expect(find.text('Please enter a title'), findsOneWidget);
      verifyNever(mockRepository.addTaskSchedule(any));
    });

    testWidgets(
      'creating task with leading and trailing spaces saves trimmed values',
      (WidgetTester tester) async {
        final mockRepository = MockTaskRepository();
        tester.view.physicalSize = const Size(1000, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        TaskSchedule? savedTask;
        when(mockRepository.addTaskSchedule(any)).thenAnswer((
          invocation,
        ) async {
          savedTask = invocation.positionalArguments[0] as TaskSchedule;
        });

        await tester.pumpWidget(
          buildTestableWidget(
            child: buildTestProviderScope(
              overrides: [
                taskRepositoryProvider.overrideWithValue(mockRepository),
              ],
              child: const CreateTaskScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final basicInfoFields = find.descendant(
          of: find.byType(TaskBasicInfoSection),
          matching: find.byType(TextFormField),
        );

        await tester.enterText(basicInfoFields.first, '   Clean Room   ');
        await tester.enterText(basicInfoFields.at(1), '   Pick up clothes   ');

        final saveButton = find.text('Save');
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        verify(mockRepository.addTaskSchedule(any)).called(1);
        expect(savedTask, isNotNull);
        expect(savedTask!.title, 'Clean Room');
        expect(savedTask!.description, 'Pick up clothes');
      },
    );

    testWidgets(
      'editing task with leading and trailing spaces saves trimmed values',
      (WidgetTester tester) async {
        final mockRepository = MockTaskRepository();
        tester.view.physicalSize = const Size(1000, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final initialTask = TaskSchedule(
          id: 'task-123',
          title: 'Initial Title',
          description: 'Initial Description',
          schedules: [
            DailySchedule(
              id: 'rule-1',
              scheduleId: 'task-123',
              startDate: const CivilDay(year: 2026, month: 3, day: 8),
              interval: 1,
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

        TaskModification? updatedMod;
        when(mockRepository.updateTaskSchedule(any)).thenAnswer((
          invocation,
        ) async {
          updatedMod = invocation.positionalArguments[0] as TaskModification;
        });

        await tester.pumpWidget(
          buildTestableWidget(
            child: buildTestProviderScope(
              overrides: [
                taskRepositoryProvider.overrideWithValue(mockRepository),
              ],
              child: CreateTaskScreen(taskToEdit: initialTask),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final basicInfoFields = find.descendant(
          of: find.byType(TaskBasicInfoSection),
          matching: find.byType(TextFormField),
        );

        await tester.enterText(basicInfoFields.first, '   Organize Closet   ');
        await tester.enterText(
          basicInfoFields.at(1),
          '   Fold shirts and pants   ',
        );

        final saveButton = find.text('Save');
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        verify(mockRepository.updateTaskSchedule(any)).called(1);
        expect(updatedMod, isNotNull);
        expect(updatedMod!.newTask.title, 'Organize Closet');
        expect(updatedMod!.newTask.description, 'Fold shirts and pants');
        expect(updatedMod!.changes['title'], 'Organize Closet');
        expect(updatedMod!.changes['description'], 'Fold shirts and pants');
      },
    );
  });

  group('Experimental Features Card', () {
    late MockTaskRepository mockRepository;

    setUp(() {
      mockRepository = MockTaskRepository();
      when(
        mockRepository.getInstances(),
      ).thenAnswer((_) => const Stream.empty());
    });

    testWidgets(
      'The "Experimental Features" card renders collapsed by default',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestableWidget(
            child: buildTestProviderScope(
              overrides: [
                taskRepositoryProvider.overrideWithValue(mockRepository),
              ],
              child: const CreateTaskScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Experimental Features'), findsOneWidget);
        expect(find.byKey(const Key('workflow_standard_chip')), findsNothing);
        expect(find.byKey(const Key('workflow_meal_chip')), findsNothing);
      },
    );

    testWidgets(
      'Tapping the card expands it to reveal the Task Workflow chips and stage time selectors',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1000, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          buildTestableWidget(
            child: buildTestProviderScope(
              overrides: [
                taskRepositoryProvider.overrideWithValue(mockRepository),
              ],
              child: const CreateTaskScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap to expand
        final experimentalHeader = find.text('Experimental Features');
        await tester.ensureVisible(experimentalHeader);
        await tester.tap(experimentalHeader);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('workflow_standard_chip')), findsOneWidget);
        expect(find.byKey(const Key('workflow_meal_chip')), findsOneWidget);
        expect(find.text('1. Select'), findsNothing);

        // Tap Meal Planning Workflow chip
        await tester.tap(find.byKey(const Key('workflow_meal_chip')));
        await tester.pumpAndSettle();

        expect(find.text('1. Select'), findsOneWidget);
        expect(find.text('2. Shop'), findsOneWidget);
        expect(find.text('3. Prep'), findsOneWidget);

        // Tap header again to collapse
        await tester.tap(experimentalHeader);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('workflow_standard_chip')), findsNothing);
        expect(find.byKey(const Key('workflow_meal_chip')), findsNothing);
      },
    );

    testWidgets(
      'Selecting "Meal Planning Workflow" updates state and persists when saving',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1000, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        TaskSchedule? savedSchedule;
        when(mockRepository.addTaskSchedule(any)).thenAnswer((
          invocation,
        ) async {
          savedSchedule = invocation.positionalArguments[0] as TaskSchedule;
        });

        await tester.pumpWidget(
          buildTestableWidget(
            child: buildTestProviderScope(
              overrides: [
                taskRepositoryProvider.overrideWithValue(mockRepository),
              ],
              child: const CreateTaskScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Expand Experimental Features
        final experimentalHeader = find.text('Experimental Features');
        await tester.ensureVisible(experimentalHeader);
        await tester.tap(experimentalHeader);
        await tester.pumpAndSettle();

        // Select Meal Planning Workflow
        await tester.tap(find.byKey(const Key('workflow_meal_chip')));
        await tester.pumpAndSettle();

        // Check default title set to Dinner if empty
        expect(find.widgetWithText(TextFormField, 'Dinner'), findsOneWidget);

        // Tap Save
        final saveButton = find.byKey(const Key('save_task_button'));
        await tester.ensureVisible(saveButton);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        verify(mockRepository.addTaskSchedule(any)).called(1);
        expect(savedSchedule, isNotNull);
        expect(savedSchedule!.workflowType, 'mealWorkflow');
        expect(savedSchedule!.mealWorkflowConfig, isNotNull);
      },
    );
  });
}
