import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/screens/help_screen.dart';
import 'package:nothing_ever_happens/widgets/basic_task_completion_tab.dart';
import 'package:nothing_ever_happens/widgets/fun_check_button.dart';
import 'package:nothing_ever_happens/widgets/task_widget.dart';
import '../test_helper.dart';

void main() {
  Widget buildTestWidget(Widget child) {
    return buildTestableWidget(child: child);
  }

  group('BasicTaskCompletionTab Standalone Tests', () {
    testWidgets(
      'renders explanatory text and 10 tasks initially without edit buttons',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestWidget(const BasicTaskCompletionTab()),
        );
        await tester.pumpAndSettle();

        // Check for explanatory card contents
        expect(
          find.textContaining('Practice Basic Task Completion'),
          findsOneWidget,
        );
        expect(
          find.textContaining('There are two ways to complete a task:'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Tapping the checkbox on the left'),
          findsOneWidget,
        );

        // Check for 10 initial tasks remaining text
        expect(find.text('Practice Tasks (10 remaining)'), findsOneWidget);

        // Verify task widgets (all 10 are in tree)
        expect(find.byType(TaskWidget), findsNWidgets(10));
        expect(find.text('Water the Houseplants'), findsOneWidget);
        expect(find.text('Take out the Trash'), findsOneWidget);
        expect(find.text('Buy Groceries'), findsOneWidget);

        // Verify no edit pencil buttons are visible
        expect(find.byIcon(Icons.edit), findsNothing);
        expect(find.byKey(const Key('edit_pencil_button')), findsNothing);
      },
    );

    testWidgets('completing a task removes the task card', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(const BasicTaskCompletionTab()));
      await tester.pumpAndSettle();

      // Find first check button
      final checkButton = find.byType(FunCheckButton).first;
      expect(checkButton, findsOneWidget);

      // Tap it
      await tester.tap(checkButton);
      await tester.pump();
      // Wait for confetti animation delay (500ms) + collapse duration (200ms)
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // Verify task is removed
      expect(find.text('Water the Houseplants'), findsNothing);
      expect(find.byType(TaskWidget), findsNWidgets(9));
      expect(find.text('Practice Tasks (9 remaining)'), findsOneWidget);
    });

    testWidgets('dismissing a task removes the task card', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(const BasicTaskCompletionTab()));
      await tester.pumpAndSettle();

      // Find first delete button (trailing)
      final deleteButton = find.byKey(const Key('delete_task_button')).first;
      expect(deleteButton, findsOneWidget);

      // Tap it
      await tester.tap(deleteButton);
      await tester.pump();
      // Wait for delete animation delay (400ms) + collapse duration (200ms)
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // Verify task is removed
      expect(find.text('Water the Houseplants'), findsNothing);
      expect(find.byType(TaskWidget), findsNWidgets(9));
      expect(find.text('Practice Tasks (9 remaining)'), findsOneWidget);
    });

    testWidgets('reset practice button restores all 10 tasks', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(const BasicTaskCompletionTab()));
      await tester.pumpAndSettle();

      // Complete first task
      await tester.tap(find.byType(FunCheckButton).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // Dismiss second task (which is now first in list: "Take out the Trash")
      await tester.tap(find.byKey(const Key('delete_task_button')).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // Verify remaining tasks is 8
      expect(find.text('Practice Tasks (8 remaining)'), findsOneWidget);

      // Tap Reset Practice button
      await tester.tap(find.text('Reset Practice'));
      await tester.pumpAndSettle();

      // Verify reset to initial state
      expect(find.text('Practice Tasks (10 remaining)'), findsOneWidget);
      expect(find.byType(TaskWidget), findsNWidgets(10));
    });

    testGoldens('BasicTaskCompletionTab renders correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidgetBuilder(
        const BasicTaskCompletionTab(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(400, 800),
      );
      await screenMatchesGolden(tester, 'basic_task_completion_tab_golden');
    });
  });

  group('HelpScreen Integration Tests', () {
    testWidgets(
      'renders BasicTaskCompletionTab with tab controller integration',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestWidget(const HelpScreen()));
        await tester.pumpAndSettle();

        // Verify the tab title is "Basic Task Completion"
        expect(find.text('Basic Task Completion'), findsOneWidget);

        // Verify that BasicTaskCompletionTab is in the widget tree
        expect(find.byType(BasicTaskCompletionTab), findsOneWidget);

        // Get HelpScreen state and verify resetCounter starts at 0
        final helpScreenFinder = find.byType(HelpScreen);
        final helpScreenState = tester.state(helpScreenFinder) as dynamic;
        expect(helpScreenState.resetCounter, 0);

        // Simulate a tab controller change to trigger the listener
        (helpScreenState.tabController as dynamic).notifyListeners();
        await tester.pumpAndSettle();

        // Verify that resetCounter is incremented
        expect(helpScreenState.resetCounter, 1);
      },
    );

    testGoldens('HelpScreen renders correctly', (WidgetTester tester) async {
      await tester.pumpWidgetBuilder(
        const HelpScreen(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(400, 800),
      );
      await screenMatchesGolden(tester, 'help_screen_basic_task_completion');
    });
  });
}
