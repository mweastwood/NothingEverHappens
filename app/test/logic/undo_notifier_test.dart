import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:nothing_ever_happens/logic/undo_notifier.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:flutter/material.dart';

@GenerateNiceMocks([MockSpec<TaskRepository>()])
import 'undo_notifier_test.mocks.dart';

void main() {
  group('UndoNotifier & UndoableAction Unit Tests', () {
    late MockTaskRepository mockRepository;
    late UndoNotifier notifier;

    setUp(() {
      mockRepository = MockTaskRepository();
      notifier = UndoNotifier();
    });

    test('initial state is null', () {
      expect(notifier.state, isNull);
    });

    test('register sets the active action', () {
      final action = UndoResolveTaskInstanceAction(
        message: 'Completed task',
        instance: TaskInstance(
          id: 'inst-1',
          scheduleId: 'task-1',
          ruleId: 'rule-1',
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
        ),
      );

      notifier.register(action);
      expect(notifier.state, action);
    });

    test('clear resets state to null', () {
      final action = UndoResolveTaskInstanceAction(
        message: 'Completed task',
        instance: TaskInstance(
          id: 'inst-1',
          scheduleId: 'task-1',
          ruleId: 'rule-1',
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
        ),
      );

      notifier.register(action);
      notifier.clear();
      expect(notifier.state, isNull);
    });

    test('undo executes action and clears state on success', () async {
      final instance = TaskInstance(
        id: 'inst-1',
        scheduleId: 'task-1',
        ruleId: 'rule-1',
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

      notifier.register(action);

      when(
        mockRepository.undoResolveTaskInstance(instance),
      ).thenAnswer((_) async {});

      final success = await notifier.undo(mockRepository);

      expect(success, isTrue);
      expect(notifier.state, isNull);
      verify(mockRepository.undoResolveTaskInstance(instance)).called(1);
    });

    test('undo returns false if no action registered', () async {
      final success = await notifier.undo(mockRepository);
      expect(success, isFalse);
    });

    test(
      'UndoResolveTaskInstanceAction calls undoResolveTaskInstance',
      () async {
        final instance = TaskInstance(
          id: 'inst-1',
          scheduleId: 'task-1',
          ruleId: 'rule-1',
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

        await action.undo(mockRepository);
        verify(mockRepository.undoResolveTaskInstance(instance)).called(1);
      },
    );

    test('UndoDeleteTaskScheduleAction calls restoreTaskSchedule', () async {
      final schedule = TaskSchedule(
        id: 'task-1',
        title: 'Test Schedule',
        description: 'Desc',
        schedules: [
          OneOffSchedule(
            date: const CivilDay(year: 2026, month: 6, day: 15),
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
      final pendingInstances = <TaskInstance>[];

      final action = UndoDeleteTaskScheduleAction(
        message: 'Deleted schedule',
        schedule: schedule,
        pendingInstances: pendingInstances,
      );

      await action.undo(mockRepository);
      verify(
        mockRepository.restoreTaskSchedule(schedule, pendingInstances),
      ).called(1);
    });

    test(
      'UndoEditTaskScheduleAction calls updateTaskSchedule with correct reverse modification',
      () async {
        final prevSchedule = TaskSchedule(
          id: 'task-1',
          title: 'Old Title',
          description: 'Old Desc',
          isFamily: false,
          schedules: [],
        );
        final currSchedule = TaskSchedule(
          id: 'task-1',
          title: 'New Title',
          description: 'New Desc',
          isFamily: true,
          schedules: [],
        );

        final action = UndoEditTaskScheduleAction(
          message: 'Edited schedule',
          previousSchedule: prevSchedule,
          currentSchedule: currSchedule,
        );

        await action.undo(mockRepository);

        final verification = verify(
          mockRepository.updateTaskSchedule(captureAny),
        );
        verification.called(1);

        final captured = verification.captured.single as TaskModification;
        expect(captured.newTask, prevSchedule);
        expect(captured.changes, {'isFamily': false});
      },
    );
  });
}
