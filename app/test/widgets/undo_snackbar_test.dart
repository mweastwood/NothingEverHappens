import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/undo_notifier.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/widgets/undo_snackbar.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/l10n_extension.dart';
import '../test_helper.dart';

@GenerateNiceMocks([MockSpec<TaskRepository>()])
import 'undo_snackbar_test.mocks.dart';

void main() {
  group('UndoSnackBar Widget Tests', () {
    late MockTaskRepository mockRepository;

    setUp(() {
      mockRepository = MockTaskRepository();
    });

    Widget buildTestWidget({
      required WidgetRef ref,
      required UndoableAction action,
      String? undoneLabel,
    }) {
      return Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: () {
              UndoSnackBar.show(
                context: context,
                ref: ref,
                action: action,
                repository: mockRepository,
                undoneLabel: undoneLabel,
              );
            },
            child: const Text('Show SnackBar'),
          );
        },
      );
    }

    testWidgets(
      'UndoSnackBar shows with premium style and action triggers undo',
      (WidgetTester tester) async {
        final instance = TaskInstance(
          id: 'I-inst-1',
          scheduleId: 'S-task-1',
          ruleId: 'R-rule-1',
          title: 'Test Instance',
          description: 'Desc',
          scheduledDate: const CivilDay(year: 2026, month: 6, day: 15),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          status: 'completed',
        );

        final action = UndoResolveTaskInstanceAction(
          message: 'Completed task',
          instance: instance,
        );

        when(
          mockRepository.undoResolveTaskInstance(instance),
        ).thenAnswer((_) async {});

        await tester.pumpWidget(
          ProviderScope(
            child: buildTestableWidget(
              child: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) {
                    return buildTestWidget(
                      ref: ref,
                      action: action,
                      undoneLabel: 'Restored "Test Instance"',
                    );
                  },
                ),
              ),
            ),
          ),
        );

        // Tap to trigger SnackBar
        await tester.tap(find.text('Show SnackBar'));
        await tester.pumpAndSettle();

        // Check that SnackBar is visible with message
        expect(find.text('Completed task'), findsOneWidget);
        expect(find.text('Undo'), findsOneWidget);

        // Verify the styling parameters:
        final snackBarFinder = find.byType(SnackBar);
        expect(snackBarFinder, findsOneWidget);
        final SnackBar snackBar = tester.widget<SnackBar>(snackBarFinder);
        expect(snackBar.behavior, SnackBarBehavior.fixed);
        expect(snackBar.duration, const Duration(seconds: 4));

        final materialFinder = find.descendant(
          of: snackBarFinder,
          matching: find.byWidgetPredicate(
            (widget) => widget is Material && widget.elevation == 6.0,
          ),
        );
        expect(materialFinder, findsOneWidget);
        final Material material = tester.widget<Material>(materialFinder);
        expect(material.shape, isA<RoundedRectangleBorder>());
        final shape = material.shape as RoundedRectangleBorder;
        expect(shape.borderRadius, BorderRadius.circular(12));

        // Tap the Undo button
        await tester.tap(find.text('Undo'));
        await tester.pump();
        await tester.pumpAndSettle();

        // Verify repository method was called
        verify(mockRepository.undoResolveTaskInstance(instance)).called(1);

        // Verify a brief confirmation SnackBar ("Action undone") is shown with matching style
        final undoneSnackBarFinder = find.byType(SnackBar);
        expect(undoneSnackBarFinder, findsOneWidget);
        final SnackBar undoneSnackBar = tester.widget<SnackBar>(
          undoneSnackBarFinder,
        );
        expect(undoneSnackBar.behavior, SnackBarBehavior.fixed);
        expect(undoneSnackBar.duration, const Duration(seconds: 2));
        expect(find.text('Restored "Test Instance"'), findsOneWidget);

        final undoneMaterialFinder = find.descendant(
          of: undoneSnackBarFinder,
          matching: find.byWidgetPredicate(
            (widget) => widget is Material && widget.elevation == 6.0,
          ),
        );
        expect(undoneMaterialFinder, findsOneWidget);
        final Material undoneMaterial = tester.widget<Material>(
          undoneMaterialFinder,
        );
        expect(undoneMaterial.shape, isA<RoundedRectangleBorder>());
        final undoneShape = undoneMaterial.shape as RoundedRectangleBorder;
        expect(undoneShape.borderRadius, BorderRadius.circular(12));
      },
    );

    testGoldens('UndoSnackBar renders correctly', (tester) async {
      final instance = TaskInstance(
        id: 'I-inst-1',
        scheduleId: 'S-task-1',
        ruleId: 'R-rule-1',
        title: 'Test Instance',
        description: 'Desc',
        scheduledDate: const CivilDay(year: 2026, month: 6, day: 15),
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        status: 'completed',
      );

      final action = UndoResolveTaskInstanceAction(
        message: 'Completed "Test Instance"',
        instance: instance,
      );

      await tester.pumpWidgetBuilder(
        ProviderScope(
          child: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                return buildTestWidget(ref: ref, action: action);
              },
            ),
          ),
        ),
        wrapper: l10nMaterialAppWrapper(),
      );

      // Tap to trigger SnackBar
      await tester.tap(find.text('Show SnackBar'));
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, 'undo_snackbar');
    });

    testGoldens('UndoSnackBar shows undone message correctly', (tester) async {
      final instance = TaskInstance(
        id: 'I-inst-1',
        scheduleId: 'S-task-1',
        ruleId: 'R-rule-1',
        title: 'Test Instance',
        description: 'Desc',
        scheduledDate: const CivilDay(year: 2026, month: 6, day: 15),
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        status: 'completed',
      );

      final action = UndoResolveTaskInstanceAction(
        message: 'Completed "Test Instance"',
        instance: instance,
      );

      when(
        mockRepository.undoResolveTaskInstance(instance),
      ).thenAnswer((_) async {});

      await tester.pumpWidgetBuilder(
        ProviderScope(
          child: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                return buildTestWidget(
                  ref: ref,
                  action: action,
                  undoneLabel: context.l10n.taskRestored(instance.title),
                );
              },
            ),
          ),
        ),
        wrapper: l10nMaterialAppWrapper(),
      );

      // Tap to trigger SnackBar
      await tester.tap(find.text('Show SnackBar'));
      await tester.pumpAndSettle();

      // Tap the Undo button to trigger the undone snackbar
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, 'undone_snackbar');
    });
  });
}
