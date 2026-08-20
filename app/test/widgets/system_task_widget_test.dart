import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/system_tasks/system_task.dart';
import 'package:nothing_ever_happens/widgets/system_task_widget.dart';

void main() {
  Widget wrapWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('SystemTaskWidget - Card Variant', () {
    testWidgets(
      'renders card layout with title, description, icon, and action button',
      (WidgetTester tester) async {
        var actionCalled = false;
        final task = SystemTask(
          id: 'test_card_task',
          title: 'Confirm capacity for this week',
          description:
              'Review and confirm your available chore hours to clear this task.',
          icon: Icons.assignment_turned_in,
          priority: SystemTaskPriority.high,
          category: SystemTaskCategory.capacity,
          actionLabel: 'Confirm Capacity',
          onAction: () {
            actionCalled = true;
          },
        );

        await tester.pumpWidget(
          wrapWidget(
            SystemTaskWidget(
              task: task,
              variant: SystemTaskWidgetVariant.card,
              actionButtonKey: const Key('test_action_btn'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Confirm capacity for this week'), findsOneWidget);
        expect(
          find.text(
            'Review and confirm your available chore hours to clear this task.',
          ),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.assignment_turned_in), findsOneWidget);
        expect(find.byKey(const Key('test_action_btn')), findsOneWidget);
        expect(find.text('Confirm Capacity'), findsOneWidget);

        // Tap action button
        await tester.tap(find.byKey(const Key('test_action_btn')));
        await tester.pumpAndSettle();
        expect(actionCalled, isTrue);
      },
    );

    testWidgets(
      'renders secondary action button and dismiss button when configured',
      (WidgetTester tester) async {
        var secondaryActionCalled = false;
        var dismissCalled = false;

        final task = SystemTask(
          id: 'test_dismissible_task',
          title: 'Dismissible Task',
          description: 'With secondary and dismiss',
          icon: Icons.info,
          actionLabel: 'Primary',
          secondaryActionLabel: 'Later',
          onSecondaryAction: () {
            secondaryActionCalled = true;
          },
          isDismissible: true,
          onDismiss: () {
            dismissCalled = true;
          },
        );

        await tester.pumpWidget(wrapWidget(SystemTaskCard(task: task)));
        await tester.pumpAndSettle();

        expect(find.text('Primary'), findsOneWidget);
        expect(find.text('Later'), findsOneWidget);
        expect(find.byIcon(Icons.close), findsOneWidget);

        await tester.tap(find.text('Later'));
        await tester.pumpAndSettle();
        expect(secondaryActionCalled, isTrue);

        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect(dismissCalled, isTrue);
      },
    );
  });

  group('SystemTaskWidget - Banner Variant', () {
    testWidgets(
      'renders compact banner layout with leading icon, title, subtitle, chevron and responds to tap',
      (WidgetTester tester) async {
        var tapped = false;
        final task = SystemTask(
          id: 'test_banner_task',
          title: 'Adjust your weekly capacity',
          description: 'Verify your available hours',
          icon: Icons.assignment_late,
          onTap: () {
            tapped = true;
          },
        );

        await tester.pumpWidget(
          wrapWidget(
            SystemTaskWidget(
              key: const Key('test_banner_widget'),
              task: task,
              variant: SystemTaskWidgetVariant.banner,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('test_banner_widget')), findsOneWidget);
        expect(find.text('Adjust your weekly capacity'), findsOneWidget);
        expect(find.text('Verify your available hours'), findsOneWidget);
        expect(find.byIcon(Icons.assignment_late), findsOneWidget);
        expect(find.byIcon(Icons.chevron_right), findsOneWidget);

        // Tap banner
        await tester.tap(find.text('Adjust your weekly capacity'));
        await tester.pumpAndSettle();
        expect(tapped, isTrue);
      },
    );
  });
}
