import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/logic/hive_local_data_source.dart';
import 'package:nothing_ever_happens/logic/task_sync_service.dart';
import 'package:nothing_ever_happens/logic/undo_notifier.dart';
import 'package:nothing_ever_happens/logic/unified_task_repository.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';

@GenerateNiceMocks([MockSpec<TaskRepository>()])
import 'undo_notifier_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
            hour: 9,
            minute: 0,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 17,
            minute: 0,
          ),
          status: TaskStatus.completed,
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
            hour: 9,
            minute: 0,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 17,
            minute: 0,
          ),
          status: TaskStatus.completed,
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
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
        status: TaskStatus.completed,
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
              hour: 9,
              minute: 0,
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              hour: 17,
              minute: 0,
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
        expect(captured.changes, {
          'title': 'Old Title',
          'description': 'Old Desc',
          'isFamily': false,
        });
      },
    );

    test(
      'UndoEditTaskScheduleAction includes schedules in changes when schedule rules differ',
      () async {
        final prevRule = OneOffSchedule(
          id: 'R-1',
          date: const CivilDay(year: 2026, month: 6, day: 15),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 9,
            minute: 0,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 17,
            minute: 0,
          ),
        );
        final currRule = OneOffSchedule(
          id: 'R-1',
          date: const CivilDay(year: 2026, month: 6, day: 20),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 9,
            minute: 0,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 17,
            minute: 0,
          ),
        );
        final prevSchedule = TaskSchedule(
          id: 'task-1',
          title: 'Task',
          description: 'Desc',
          schedules: [prevRule],
        );
        final currSchedule = TaskSchedule(
          id: 'task-1',
          title: 'Task',
          description: 'Desc',
          schedules: [currRule],
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
        expect(captured.changes.containsKey('schedules'), isTrue);
        expect(
          captured.changes['schedules'],
          prevSchedule.schedules.map((s) => s.toJson()).toList(),
        );
      },
    );

    test(
      'UndoEditTaskScheduleAction reconciles pending instances back to previousSchedule rules',
      () async {
        AppClock.setMockTime(DateTime(2026, 6, 15, 10, 0));
        final tempDir = await Directory.systemTemp.createTemp('hive_undo_test');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              (MethodCall methodCall) async {
                if (methodCall.method == 'getApplicationDocumentsDirectory') {
                  return tempDir.path;
                }
                return null;
              },
            );

        final localDataSource = HiveLocalDataSource();
        await localDataSource.init();
        await localDataSource.setMigrationCompleted(true);
        final firestore = FakeFirebaseFirestore();
        final syncService = TaskSyncService(
          firestore: firestore,
          localDataSource: localDataSource,
          userId: 'user1',
          isActivePremium: false,
        );
        final repository = UnifiedTaskRepository(
          localDataSource: localDataSource,
          syncService: syncService,
          firestore: firestore,
          userId: 'user1',
        );

        try {
          final originalTask = TaskSchedule(
            id: 'S-undo-1',
            title: 'Schedule Undo Task',
            description: 'Desc',
            schedules: [
              OneOffSchedule(
                id: 'R-undo-1',
                date: const CivilDay(year: 2026, month: 6, day: 15),
                startRelativeTime: const RelativeTime(
                  dayOffset: 0,
                  hour: 9,
                  minute: 0,
                ),
                dueRelativeTime: const RelativeTime(
                  dayOffset: 0,
                  hour: 17,
                  minute: 0,
                ),
              ),
            ],
          );

          await repository.addTaskSchedule(originalTask);
          final storedBeforeEdit = localDataSource.getTasks().firstWhere(
            (t) => t.id == 'S-undo-1',
          );

          var pendingInstances = localDataSource
              .getInstances()
              .where(
                (i) =>
                    i.scheduleId == 'S-undo-1' &&
                    i.status == TaskStatus.pending,
              )
              .toList();
          expect(pendingInstances, hasLength(1));
          expect(
            pendingInstances.single.scheduledDate,
            const CivilDay(year: 2026, month: 6, day: 15),
          );

          // Edit the schedule rule to a future date (2026-06-20)
          final editMod = storedBeforeEdit.edit(
            newTitle: storedBeforeEdit.title,
            newDescription: storedBeforeEdit.description,
            newSchedules: [
              OneOffSchedule(
                id: 'R-undo-1',
                date: const CivilDay(year: 2026, month: 6, day: 20),
                startRelativeTime: const RelativeTime(
                  dayOffset: 0,
                  hour: 9,
                  minute: 0,
                ),
                dueRelativeTime: const RelativeTime(
                  dayOffset: 0,
                  hour: 17,
                  minute: 0,
                ),
              ),
            ],
            newEstimatedDuration: storedBeforeEdit.estimatedDuration,
            newMissedPolicy: storedBeforeEdit.missedPolicy,
            newIsMaster: storedBeforeEdit.isMaster,
            newLastSpawnedDate: storedBeforeEdit.lastSpawnedDate,
            newIsFamily: storedBeforeEdit.isFamily,
            newPriority: storedBeforeEdit.priority,
          );
          await repository.updateTaskSchedule(editMod);

          // The 2026-06-15 pending instance should be replaced with 2026-06-20 after editing
          pendingInstances = localDataSource
              .getInstances()
              .where(
                (i) =>
                    i.scheduleId == 'S-undo-1' &&
                    i.status == TaskStatus.pending,
              )
              .toList();
          expect(pendingInstances, hasLength(1));
          expect(
            pendingInstances.single.scheduledDate,
            const CivilDay(year: 2026, month: 6, day: 20),
          );

          // Now undo the schedule edit
          final undoAction = UndoEditTaskScheduleAction(
            message: 'Edited schedule',
            previousSchedule: storedBeforeEdit,
            currentSchedule: editMod.newTask,
          );
          await undoAction.undo(repository);

          // Pending instance for 2026-06-15 should be re-spawned
          pendingInstances = localDataSource
              .getInstances()
              .where(
                (i) =>
                    i.scheduleId == 'S-undo-1' &&
                    i.status == TaskStatus.pending,
              )
              .toList();
          expect(pendingInstances, hasLength(1));
          expect(
            pendingInstances.single.scheduledDate,
            const CivilDay(year: 2026, month: 6, day: 15),
          );
        } finally {
          AppClock.reset();
          repository.dispose();
          syncService.dispose();
          await Hive.close();
          await tempDir.delete(recursive: true);
        }
      },
    );
  });
}
