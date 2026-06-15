import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:nothing_ever_happens/logic/undo_notifier.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/widgets/undo_snackbar.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
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
          id: 'inst-1',
          scheduleId: 'task-1',
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
                    return buildTestWidget(ref: ref, action: action);
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
        expect(snackBar.behavior, SnackBarBehavior.floating);
        expect(snackBar.duration, const Duration(seconds: 4));
        expect(snackBar.shape, isA<RoundedRectangleBorder>());

        final shape = snackBar.shape as RoundedRectangleBorder;
        expect(shape.borderRadius, BorderRadius.circular(12));

        // Tap the Undo button
        await tester.tap(find.text('Undo'));
        await tester.pump();
        await tester.pumpAndSettle();

        // Verify repository method was called
        verify(mockRepository.undoResolveTaskInstance(instance)).called(1);

        // Verify a brief plain-text confirmation SnackBar ("Action undone") is shown
        expect(find.text('Action undone'), findsOneWidget);
      },
    );
  });
}
