import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/logic/task.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/user_settings_repository.dart';
import 'package:nothing_ever_happens/logic/family_repository.dart';
import 'package:nothing_ever_happens/logic/error_handler.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/screens/sprint_dashboard_screen.dart';
import '../test_helper.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late TaskRepository taskRepo;
  late UserSettingsRepository settingsRepo;
  late FamilyRepository familyRepo;
  late ErrorHandler errorHandler;

  const userId = 'user-1';
  const userEmail = 'user1@example.com';
  const userName = 'Alice';
  const familyId = 'fam-123';

  setUp(() {
    AppClock.setMockTime(DateTime(2026, 6, 3, 12, 0)); // Wednesday of 2026-W23
    firestore = FakeFirebaseFirestore();
    taskRepo = TaskRepository(firestore: firestore, userId: userId);
    settingsRepo = UserSettingsRepository(firestore: firestore, userId: userId);
    familyRepo = FamilyRepository(
      firestore: firestore,
      userId: userId,
      userEmail: userEmail,
      userDisplayName: userName,
    );
    errorHandler = ErrorHandler();
  });

  tearDown(() {
    AppClock.reset();
  });

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(taskRepo),
        userSettingsRepositoryProvider.overrideWithValue(settingsRepo),
        familyRepositoryProvider.overrideWithValue(familyRepo),
        errorHandlerProvider.overrideWithValue(errorHandler),
      ],
      child: buildTestableWidget(child: const SprintDashboardScreen()),
    );
  }

  group('SprintDashboardScreen Unit and Widget Tests', () {
    testWidgets('renders empty active cycle and backlog', (
      WidgetTester tester,
    ) async {
      await firestore.collection('users').doc(userId).set({
        'familyId': familyId,
        'familyRole': 'parent',
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Check dates
      expect(find.text('Mon, Jun 1 – Sun, Jun 7'), findsOneWidget);
      expect(find.text('2026-W23'), findsOneWidget);

      // Check capacity card
      expect(find.text('Weekly Capacity'), findsOneWidget);
      expect(
        find.text('3360 min (8.0h/day)'),
        findsOneWidget,
      ); // Default 8 hours -> 56h -> 3360m

      // Check empty state
      expect(
        find.text('No active tasks in this cycle. Move some from the backlog!'),
        findsOneWidget,
      );

      // Switch to Backlog
      await tester.tap(find.text('Backlog'));
      await tester.pumpAndSettle();

      expect(find.text('No tasks in the backlog.'), findsOneWidget);
    });

    testWidgets('renders active and backlog tasks, updates capacity math', (
      WidgetTester tester,
    ) async {
      // Set settings to 2 hours per day
      await firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('agile')
          .set({'hoursAvailable': 2.0});

      await firestore.collection('users').doc(userId).set({
        'familyId': familyId,
        'familyRole': 'parent',
      });

      // Add 1 personal active task (30m)
      final personalTask = Task(
        id: 't-personal',
        title: 'Personal Chore',
        description: 'Clean room',
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        schedule: OneOffSchedule(
          date: const CivilDay(year: 2026, month: 6, day: 1),
        ),
        estimatedDuration: const Duration(minutes: 30),
        isFamily: false,
        cycleId: '2026-W23',
      );
      await taskRepo.addTask(personalTask);

      // Add 1 family active task (45m) assigned to user-1
      final familyTaskActive = Task(
        id: 't-family-active',
        title: 'Family Dishwashing',
        description: 'Wash plates',
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        schedule: OneOffSchedule(
          date: const CivilDay(year: 2026, month: 6, day: 1),
        ),
        estimatedDuration: const Duration(minutes: 45),
        isFamily: true,
        cycleId: '2026-W23',
        assignedUserId: userId,
      );
      await taskRepo.addTask(familyTaskActive);

      // Add 1 backlog task (60m)
      final backlogTask = Task(
        id: 't-backlog',
        title: 'Backlog Chore',
        description: 'Clean attic',
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        schedule: OneOffSchedule(
          date: const CivilDay(year: 2026, month: 6, day: 1),
        ),
        estimatedDuration: const Duration(minutes: 60),
        isFamily: true,
        cycleId: null,
      );
      await taskRepo.addTask(backlogTask);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Total capacity is 2.0 * 7 * 60 = 840 mins
      expect(find.text('840 min (2.0h/day)'), findsOneWidget);
      expect(find.text('Personal Tasks: 30 min'), findsOneWidget);
      expect(find.text('Family Chores: 45 min'), findsOneWidget);
      expect(find.text('Remaining Capacity: 765 min'), findsOneWidget);

      // Check tasks
      expect(find.text('Personal Chore'), findsOneWidget);
      expect(find.text('Family Dishwashing'), findsOneWidget);
    });

    testWidgets('toggles tasks in/out of cycle', (WidgetTester tester) async {
      await firestore.collection('users').doc(userId).set({
        'familyId': familyId,
        'familyRole': 'parent',
      });

      // Add 1 personal active task (30m)
      final personalTask = Task(
        id: 't-personal',
        title: 'Personal Chore',
        description: 'Clean room',
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        schedule: OneOffSchedule(
          date: const CivilDay(year: 2026, month: 6, day: 1),
        ),
        estimatedDuration: const Duration(minutes: 30),
        isFamily: false,
        cycleId: '2026-W23',
      );
      await taskRepo.addTask(personalTask);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Personal Chore'), findsOneWidget);

      // Tap remove from cycle button
      await tester.tap(find.byKey(const Key('remove_btn_t-personal')));
      await tester.pumpAndSettle();

      // Check active list is empty
      expect(
        find.text('No active tasks in this cycle. Move some from the backlog!'),
        findsOneWidget,
      );

      // Check backlog list has the task
      await tester.tap(find.text('Backlog'));
      await tester.pumpAndSettle();
      expect(find.text('Personal Chore'), findsOneWidget);

      // Tap add to cycle button
      await tester.tap(find.byKey(const Key('add_btn_t-personal')));
      await tester.pumpAndSettle();

      expect(find.text('No tasks in the backlog.'), findsOneWidget);
    });

    testWidgets('stars/unstars family backlog task', (
      WidgetTester tester,
    ) async {
      await firestore.collection('users').doc(userId).set({
        'familyId': familyId,
        'familyRole': 'parent',
      });

      final familyTask = Task(
        id: 't-family',
        title: 'Family Chore',
        description: 'Mow lawn',
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        schedule: OneOffSchedule(
          date: const CivilDay(year: 2026, month: 6, day: 1),
        ),
        isFamily: true,
        cycleId: null,
      );
      await taskRepo.addTask(familyTask);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Switch to Backlog
      await tester.tap(find.text('Backlog'));
      await tester.pumpAndSettle();

      // Star is unselected initially
      final starBtn = find.byKey(const Key('star_btn_t-family'));
      expect(starBtn, findsOneWidget);

      // Tap star
      await tester.tap(starBtn);
      await tester.pumpAndSettle();

      // Verify in database that it is starred
      final doc = await firestore
          .collection('families')
          .doc(familyId)
          .collection('tasks')
          .doc('t-family')
          .get();
      final updated = Task.fromFirestore(doc);
      expect(updated.preferredBy[userId], isTrue);
    });

    testWidgets('auto-allocate button runs allocator and assigns chores', (
      WidgetTester tester,
    ) async {
      // 1. Setup user in a family
      await firestore.collection('users').doc(userId).set({
        'familyId': familyId,
        'familyRole': 'parent',
      });

      // 2. Setup family with Alice and Bob
      await firestore.collection('families').doc(familyId).set({
        'name': 'The Simpsons',
        'members': {
          userId: {
            'userId': userId,
            'displayName': userName,
            'email': userEmail,
            'role': 'parent',
          },
          'user-2': {
            'userId': 'user-2',
            'displayName': 'Bob',
            'email': 'bob@example.com',
            'role': 'non-parent',
          },
        },
      });

      // 3. Add family tasks in active cycle
      final task1 = Task(
        id: 't1',
        title: 'Task 1',
        description: '',
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        schedule: OneOffSchedule(
          date: const CivilDay(year: 2026, month: 6, day: 1),
        ),
        estimatedDuration: const Duration(minutes: 60),
        isFamily: true,
        priority: TaskPriority.high,
        cycleId: '2026-W23',
      );
      await taskRepo.addTask(task1);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('auto_allocate_button')), findsOneWidget);

      // Tap auto allocate
      await tester.tap(find.byKey(const Key('auto_allocate_button')));
      await tester.pumpAndSettle();

      // Verify that task is allocated to either Alice or Bob in database
      final doc = await firestore
          .collection('families')
          .doc(familyId)
          .collection('tasks')
          .doc('t1')
          .get();
      final allocatedTask = Task.fromFirestore(doc);
      expect(allocatedTask.assignedUserId, isNotNull);
      expect(allocatedTask.assignedUserId!.isNotEmpty, isTrue);
    });

    testWidgets('renders pooled capacities for all family members', (
      WidgetTester tester,
    ) async {
      // 1. Setup user settings and user profile
      await firestore.collection('users').doc(userId).set({
        'familyId': familyId,
        'familyRole': 'parent',
      });
      await firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('agile')
          .set({'hoursAvailable': 4.0}); // 4 * 7 * 60 = 1680 mins

      // 2. Setup another user profile and settings
      await firestore.collection('users').doc('user-2').set({
        'familyId': familyId,
        'familyRole': 'non-parent',
      });
      await firestore
          .collection('users')
          .doc('user-2')
          .collection('settings')
          .doc('agile')
          .set({'hoursAvailable': 2.0}); // 2 * 7 * 60 = 840 mins

      // 3. Setup family document
      await firestore.collection('families').doc(familyId).set({
        'name': 'The Simpsons',
        'members': {
          userId: {
            'userId': userId,
            'displayName': 'Alice',
            'email': userEmail,
            'role': 'parent',
          },
          'user-2': {
            'userId': 'user-2',
            'displayName': 'Bob',
            'email': 'bob@example.com',
            'role': 'non-parent',
          },
        },
      });

      // 4. Setup some personal tasks for Bob
      final bobTask = Task(
        id: 't-bob-personal',
        title: 'Bob Personal Task',
        description: '',
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        schedule: OneOffSchedule(
          date: const CivilDay(year: 2026, month: 6, day: 1),
        ),
        estimatedDuration: const Duration(minutes: 120),
        isFamily: false,
        cycleId: '2026-W23',
      );
      await firestore
          .collection('users')
          .doc('user-2')
          .collection('tasks')
          .doc('t-bob-personal')
          .set(bobTask.toFirestore());

      // 5. Setup family task assigned to Bob
      final familyTask = Task(
        id: 't-fam-assigned',
        title: 'Shared Task',
        description: '',
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        schedule: OneOffSchedule(
          date: const CivilDay(year: 2026, month: 6, day: 1),
        ),
        estimatedDuration: const Duration(minutes: 180),
        isFamily: true,
        cycleId: '2026-W23',
        assignedUserId: 'user-2',
      );
      await taskRepo.addTask(familyTask);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Check header
      expect(find.text('Family Capacity Pool'), findsOneWidget);

      // Check Alice (You) row
      expect(find.text('Alice (You)'), findsOneWidget);
      // Alice has 4h/day = 1680 min total.
      expect(find.textContaining('1680 min total'), findsOneWidget);

      // Check Bob row
      expect(find.text('Bob'), findsOneWidget);
      // Bob has 2h/day = 840 min total. Remaining is 840 - 120 (personal) - 180 (family) = 540 min.
      expect(find.textContaining('540 min remaining'), findsOneWidget);
      expect(find.textContaining('840 min total'), findsOneWidget);
      expect(
        find.textContaining('Personal: 120 min | Family Chores: 180 min'),
        findsOneWidget,
      );
    });
  });

  group('SprintDashboardScreen Goldens', () {
    testGoldens('SprintDashboardScreen empty state golden', (tester) async {
      await firestore.collection('users').doc(userId).set({
        'familyId': familyId,
        'familyRole': 'parent',
      });

      await tester.pumpWidgetBuilder(
        buildTestWidget(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(400, 800),
      );
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, 'sprint_dashboard_screen_empty');
    });

    testGoldens('SprintDashboardScreen with active tasks golden', (
      tester,
    ) async {
      await firestore.collection('users').doc(userId).set({
        'familyId': familyId,
        'familyRole': 'parent',
      });

      final personalTask = Task(
        id: 't-personal',
        title: 'Personal Chore',
        description: 'Clean room',
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        schedule: OneOffSchedule(
          date: const CivilDay(year: 2026, month: 6, day: 1),
        ),
        estimatedDuration: const Duration(minutes: 30),
        isFamily: false,
        cycleId: '2026-W23',
      );
      await taskRepo.addTask(personalTask);

      final familyTask = Task(
        id: 't-family',
        title: 'Family Dishwashing',
        description: 'Wash plates',
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        schedule: OneOffSchedule(
          date: const CivilDay(year: 2026, month: 6, day: 1),
        ),
        estimatedDuration: const Duration(minutes: 45),
        isFamily: true,
        cycleId: '2026-W23',
        assignedUserId: userId,
      );
      await taskRepo.addTask(familyTask);

      await tester.pumpWidgetBuilder(
        buildTestWidget(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(400, 800),
      );
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, 'sprint_dashboard_screen_with_tasks');
    });

    testGoldens('SprintDashboardScreen family capacity pool golden', (
      tester,
    ) async {
      // 1. Setup user settings and user profile
      await firestore.collection('users').doc(userId).set({
        'familyId': familyId,
        'familyRole': 'parent',
      });
      await firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('agile')
          .set({'hoursAvailable': 4.0}); // 4 * 7 * 60 = 1680 mins

      // 2. Setup another user profile and settings
      await firestore.collection('users').doc('user-2').set({
        'familyId': familyId,
        'familyRole': 'non-parent',
      });
      await firestore
          .collection('users')
          .doc('user-2')
          .collection('settings')
          .doc('agile')
          .set({'hoursAvailable': 2.0}); // 2 * 7 * 60 = 840 mins

      // 3. Setup family document
      await firestore.collection('families').doc(familyId).set({
        'name': 'The Simpsons',
        'members': {
          userId: {
            'userId': userId,
            'displayName': 'Alice',
            'email': userEmail,
            'role': 'parent',
          },
          'user-2': {
            'userId': 'user-2',
            'displayName': 'Bob',
            'email': 'bob@example.com',
            'role': 'non-parent',
          },
        },
      });

      // 4. Setup some personal tasks for Bob
      final bobTask = Task(
        id: 't-bob-personal',
        title: 'Bob Personal Task',
        description: '',
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        schedule: OneOffSchedule(
          date: const CivilDay(year: 2026, month: 6, day: 1),
        ),
        estimatedDuration: const Duration(minutes: 120),
        isFamily: false,
        cycleId: '2026-W23',
      );
      await firestore
          .collection('users')
          .doc('user-2')
          .collection('tasks')
          .doc('t-bob-personal')
          .set(bobTask.toFirestore());

      // 5. Setup family task assigned to Bob
      final familyTask = Task(
        id: 't-fam-assigned',
        title: 'Shared Task',
        description: '',
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        schedule: OneOffSchedule(
          date: const CivilDay(year: 2026, month: 6, day: 1),
        ),
        estimatedDuration: const Duration(minutes: 180),
        isFamily: true,
        cycleId: '2026-W23',
        assignedUserId: 'user-2',
      );
      await taskRepo.addTask(familyTask);

      await tester.pumpWidgetBuilder(
        buildTestWidget(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(400, 800),
      );
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, 'sprint_dashboard_screen_family_pool');
    });
  });
}
