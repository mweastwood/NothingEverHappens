import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'package:nothing_ever_happens/logic/auth_repository.dart';
import 'package:nothing_ever_happens/screens/task_list_screen.dart';

import 'login_screen_test.mocks.dart';

void main() {
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    // Default stubbing
    when(mockAuthRepository.signOut()).thenAnswer((_) async {});
  });

  // Helper to wrap the screen in a MaterialApp (needed for Scaffold, Theme, etc)
  Widget createScreen() {
    return MaterialApp(
      home: Provider<AuthRepository>.value(
        value: mockAuthRepository,
        child: const TaskListScreen(),
      ),
    );
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

  testWidgets('Task list desktop layout', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createScreen());

    expect(find.byType(ListView), findsOneWidget);
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
    expect(find.text('New Task Description'), findsOneWidget);
  });

  testWidgets('Task list has drawer with logout button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createScreen());

    // Find the hamburger menu (Scaffold drawer)
    // Initially the drawer is closed, so we don't see 'Logout' yet.
    expect(find.text('Logout'), findsNothing);

    // Open the drawer
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    // Verify drawer content
    expect(find.text('Menu'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);

    // Tap logout
    await tester.tap(find.text('Logout'));
    await tester.pump();

    // Verify signOut was called
    verify(mockAuthRepository.signOut()).called(1);
  });

  testGoldens('TaskListScreen renders correctly', (tester) async {
    final mockAuthRepository = MockAuthRepository();
    // Default stubbing for goldens if needed, though they mostly test UI
    when(mockAuthRepository.signOut()).thenAnswer((_) async {});

    await tester.pumpWidgetBuilder(
      Provider<AuthRepository>.value(
        value: mockAuthRepository,
        child: const TaskListScreen(),
      ),
      wrapper: materialAppWrapper(),
      surfaceSize: const Size(400, 800),
    );
    await screenMatchesGolden(tester, 'task_list_screen');
  });
}
