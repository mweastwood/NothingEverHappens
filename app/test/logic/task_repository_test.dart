import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/logic/notification_service.dart';

void main() {
  group('TaskRepository', () {
    late FakeFirebaseFirestore firestore;
    late TaskRepository repository;
    const userId = 'test-user-id';

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = TaskRepository(firestore: firestore, userId: userId);
    });

    final testTask = TaskSchedule(
      id: 'task-1',
      title: 'Test TaskSchedule',
      description: 'Test Description',
      schedules: [
        OneOffSchedule(
          date: const CivilDay(year: 2024, month: 1, day: 1),
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

    test('addTask adds a task to Firestore', () async {
      await repository.addTaskSchedule(testTask);

      final taskSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc(testTask.id)
          .get();

      expect(taskSnapshot.exists, isTrue);
      final data = taskSnapshot.data()!;
      expect(data['title'], testTask.title);
    });

    test('getTasks returns a stream of tasks', () async {
      await repository.addTaskSchedule(testTask);

      final stream = repository.getTasks();

      expect(
        stream,
        emits(
          isA<List<TaskSchedule>>().having(
            (list) => list.first.title,
            'title',
            testTask.title,
          ),
        ),
      );
    });

    test('updateTask updates an existing task', () async {
      await repository.addTaskSchedule(testTask);

      final modification = testTask.updateTitle('Updated Title');
      await repository.updateTaskSchedule(modification);

      final taskSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc(testTask.id)
          .get();

      expect(taskSnapshot.data()!['title'], 'Updated Title');
    });

    test(
      'deleteTask removes a task, returns deleted data, and restore restores it',
      () async {
        await repository.addTaskSchedule(testTask);
        await Future.delayed(Duration.zero);

        final instanceId = '${testTask.id}_2024-01-01';

        // Verify task and instance exist
        final initialTask = await firestore
            .collection('users')
            .doc(userId)
            .collection('tasks')
            .doc(testTask.id)
            .get();
        expect(initialTask.exists, isTrue);

        final initialInstance = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(instanceId)
            .get();
        expect(initialInstance.exists, isTrue);

        // 1. Delete Task
        final deletedData = await repository.deleteTaskSchedule(testTask.id);
        expect(deletedData, isNotNull);
        expect(deletedData!.task.id, testTask.id);
        expect(deletedData.pendingInstances.length, 1);
        expect(deletedData.pendingInstances.first.id, instanceId);

        // Verify they are deleted in Firestore
        final taskSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('tasks')
            .doc(testTask.id)
            .get();
        expect(taskSnapshot.exists, isFalse);

        final instanceSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(instanceId)
            .get();
        expect(instanceSnapshot.exists, isFalse);

        // 2. Restore Task
        await repository.restoreTaskSchedule(
          deletedData.task,
          deletedData.pendingInstances,
        );

        // Verify they are restored in Firestore
        final restoredTask = await firestore
            .collection('users')
            .doc(userId)
            .collection('tasks')
            .doc(testTask.id)
            .get();
        expect(restoredTask.exists, isTrue);

        final restoredInstance = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(instanceId)
            .get();
        expect(restoredInstance.exists, isTrue);
        expect(restoredInstance.data()!['status'], 'pending');
      },
    );

    test('completeTask completes the instance', () async {
      await repository.addTaskSchedule(testTask);
      await Future.delayed(Duration.zero);

      final instanceId = '${testTask.id}_2024-01-01';
      await repository.completeTaskInstance(instanceId);

      final instanceSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('instances')
          .doc(instanceId)
          .get();

      expect(instanceSnapshot.exists, isTrue);
      expect(instanceSnapshot.data()!['status'], 'completed');
    });

    test('dismissTaskInstance dismisses the instance', () async {
      await repository.addTaskSchedule(testTask);
      await Future.delayed(Duration.zero);

      final instanceId = '${testTask.id}_2024-01-01';
      await repository.dismissTaskInstance(instanceId);

      final instanceSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('instances')
          .doc(instanceId)
          .get();

      expect(instanceSnapshot.exists, isTrue);
      expect(instanceSnapshot.data()!['status'], 'dismissed');
      expect(instanceSnapshot.data()!['completedByUserId'], userId);
      expect(instanceSnapshot.data()!['completedAt'], isNotNull);
    });

    test(
      'undoResolveTaskInstance reverts completed instance to pending and deletes next spawned',
      () async {
        final recurringTask = TaskSchedule(
          id: 'task-recur',
          title: 'Daily Task',
          description: 'Test description',
          schedules: [
            DailySchedule(
              startDate: const CivilDay(year: 2026, month: 6, day: 1),
              interval: 1,
            ),
          ],
        );

        AppClock.setMockTime(DateTime(2026, 6, 1, 12, 0));
        await repository.addTaskSchedule(recurringTask);
        await Future.delayed(Duration.zero);

        final instanceId = '${recurringTask.id}_2026-06-01';
        final nextInstanceId = '${recurringTask.id}_2026-06-02';

        // 1. Complete the June 1 instance on June 1
        await repository.completeTaskInstance(instanceId);

        // Verify next spawned does not exist under JIT spawning
        final nextSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(nextInstanceId)
            .get();
        expect(nextSnapshot.exists, isFalse);

        // Fetch the completed instance
        final completedSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(instanceId)
            .get();
        final completedInstance = TaskInstance.fromFirestore(completedSnapshot);

        // 2. Undo completion
        await repository.undoResolveTaskInstance(completedInstance);

        // Verify instance is back to pending and completed fields are cleared
        final undoneSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(instanceId)
            .get();
        expect(undoneSnapshot.data()!['status'], 'pending');
        expect(undoneSnapshot.data()!['completedByUserId'], isNull);
        expect(undoneSnapshot.data()!['completedAt'], isNull);

        // Verify next spawned still does not exist
        final nextSnapshotPost = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(nextInstanceId)
            .get();
        expect(nextSnapshotPost.exists, isFalse);

        AppClock.reset();
      },
    );

    test(
      'undoResolveTaskInstance reverts dismissed instance to pending',
      () async {
        await repository.addTaskSchedule(testTask);
        await Future.delayed(Duration.zero);

        final instanceId = '${testTask.id}_2024-01-01';

        // 1. Dismiss it
        await repository.dismissTaskInstance(instanceId);

        // Fetch the dismissed instance
        final dismissedSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(instanceId)
            .get();
        final dismissedInstance = TaskInstance.fromFirestore(dismissedSnapshot);

        // 2. Undo dismissal
        await repository.undoResolveTaskInstance(dismissedInstance);

        // Verify instance is back to pending
        final undoneSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(instanceId)
            .get();
        expect(undoneSnapshot.data()!['status'], 'pending');
        expect(undoneSnapshot.data()!['completedByUserId'], isNull);
        expect(undoneSnapshot.data()!['completedAt'], isNull);
      },
    );

    test(
      'completeTaskInstance returns the resolved instance with completedAt set '
      '(regression: undo for recurring tasks needs the resolved instance)',
      () async {
        // This test guards against regression where completeTaskInstance
        // returned void, forcing callers to pass the pending instance to
        // undoResolveTaskInstance. The pending instance has completedAt==null,
        // so undoResolveTaskInstance would fall back to AppClock.now and could
        // compute the wrong refDate, deleting the wrong next spawned instance.
        final dailyTask = TaskSchedule(
          id: 'task-daily',
          title: 'Daily Task',
          description: 'desc',
          schedules: [
            DailySchedule(
              startDate: const CivilDay(year: 2026, month: 6, day: 1),
              interval: 1,
            ),
          ],
        );

        AppClock.setMockTime(DateTime(2026, 6, 1, 12, 0));
        addTearDown(AppClock.reset);

        await repository.addTaskSchedule(dailyTask);
        await Future.delayed(Duration.zero);

        final instanceId = '${dailyTask.id}_2026-06-01';

        // completeTaskInstance must return the resolved instance
        final resolved = await repository.completeTaskInstance(instanceId);

        expect(resolved, isNotNull);
        expect(resolved!.id, instanceId);
        expect(resolved.status, 'completed');
        expect(resolved.completedAt, isNotNull);
        expect(resolved.completedByUserId, userId);

        // dismissTaskInstance must also return the resolved instance
        // (create a separate task to test the dismiss path)
        final dailyTask2 = TaskSchedule(
          id: 'task-daily-2',
          title: 'Daily Task 2',
          description: 'desc',
          schedules: [
            DailySchedule(
              startDate: const CivilDay(year: 2026, month: 6, day: 1),
              interval: 1,
            ),
          ],
        );
        await repository.addTaskSchedule(dailyTask2);
        await Future.delayed(Duration.zero);

        final instanceId2 = '${dailyTask2.id}_2026-06-01';
        final resolvedDismissed = await repository.dismissTaskInstance(
          instanceId2,
        );

        expect(resolvedDismissed, isNotNull);
        expect(resolvedDismissed!.status, 'dismissed');
        expect(resolvedDismissed.completedAt, isNotNull);
      },
    );

    test(
      'editing weekly schedule to add monthly schedule does not duplicate or timeout',
      () async {
        // Fix the clock to June 15 2026 (the task startDate) so this test is
        // not flaky after that date passes.
        AppClock.setMockTime(DateTime(2026, 6, 15, 9, 0));
        addTearDown(AppClock.reset);

        final weeklyTask = TaskSchedule(
          id: 'task-weekly',
          title: 'Weekly Task',
          description: 'Weekly Description',
          missedPolicy: MissedPolicy.rollover,
          schedules: [
            WeeklySchedule(
              startDate: const CivilDay(
                year: 2026,
                month: 6,
                day: 15,
              ), // a Monday
              interval: 1,
              daysOfWeek: {1}, // Monday
            ),
          ],
        );

        await repository.addTaskSchedule(weeklyTask);
        await Future.delayed(Duration.zero);

        // Now edit it to add a monthly schedule
        final updatedTaskSchedules = [
          WeeklySchedule(
            startDate: const CivilDay(year: 2026, month: 6, day: 15),
            interval: 1,
            daysOfWeek: {1},
          ),
          MonthlySchedule(
            startDate: const CivilDay(year: 2026, month: 6, day: 15),
            interval: 1,
            dayOfMonth: 15,
          ),
        ];

        final modification = weeklyTask.edit(
          newTitle: 'Weekly Task',
          newDescription: 'Weekly Description',
          newSchedules: updatedTaskSchedules,
          newEstimatedDuration: null,
          newMissedPolicy: MissedPolicy.rollover,
          newIsMaster: false,
          newLastSpawnedDate: null,
          newIsFamily: false,
          newPriority: TaskPriority.medium,
        );

        await repository.updateTaskSchedule(modification);
        await Future.delayed(Duration.zero);

        // Check tasks
        final tasksSnap = await firestore
            .collection('users')
            .doc(userId)
            .collection('tasks')
            .get();

        // Expect exactly 1 task
        expect(tasksSnap.docs.length, 1);
        expect(tasksSnap.docs.first.id, 'task-weekly');

        final instancesSnap = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .get();

        expect(instancesSnap.docs.length, 2);
        final instanceIds = instancesSnap.docs.map((doc) => doc.id).toList();
        expect(instanceIds, contains('task-weekly_2026-06-15_0'));
        expect(instanceIds, contains('task-weekly_2026-06-15_1'));
      },
    );
  });

  group('TaskRepository with NotificationService', () {
    late FakeFirebaseFirestore firestore;
    late LoggingNotificationService notificationService;
    late TaskRepository repository;
    const userId = 'test-user-id';

    setUp(() {
      firestore = FakeFirebaseFirestore();
      notificationService = LoggingNotificationService();
      repository = TaskRepository(
        firestore: firestore,
        userId: userId,
        notificationService: notificationService,
      );
    });

    final notifTask = TaskSchedule(
      id: 'notif-task-1',
      title: 'Notify Me',
      description: 'Check notifications',
      schedules: [
        DailySchedule(
          startDate: const CivilDay(year: 2024, month: 1, day: 1),
          interval: 1,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          notificationRelativeTimes: const [
            RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 8, minute: 45)),
          ],
        ),
      ],
    );

    test('addTask schedules notifications', () async {
      await repository.addTaskSchedule(notifTask);
      expect(
        notificationService.scheduledTasks.containsKey(notifTask.id),
        isTrue,
      );
      expect(
        notificationService
            .scheduledTasks[notifTask.id]!
            .schedules
            .first
            .notificationRelativeTimes
            .first
            .time,
        equals(const TimeOfDay(hour: 8, minute: 45)),
      );
    });

    test('updateTask updates scheduled notifications', () async {
      await repository.addTaskSchedule(notifTask);

      final updatedTask = TaskSchedule(
        id: notifTask.id,
        title: 'Notify Me (Updated)',
        description: notifTask.description,
        schedules: [
          DailySchedule(
            startDate: const CivilDay(year: 2024, month: 1, day: 1),
            interval: 1,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            notificationRelativeTimes: const [
              RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 8, minute: 30)),
            ],
          ),
        ],
      );

      final modification = (
        newTask: updatedTask,
        changes: {
          'schedules': updatedTask.schedules.map((s) => s.toJson()).toList(),
        },
      );

      await repository.updateTaskSchedule(modification);
      expect(
        notificationService.scheduledTasks.containsKey(notifTask.id),
        isTrue,
      );
      expect(
        notificationService
            .scheduledTasks[notifTask.id]!
            .schedules
            .first
            .notificationRelativeTimes
            .first
            .time,
        equals(const TimeOfDay(hour: 8, minute: 30)),
      );
    });

    test('deleteTask cancels scheduled notifications', () async {
      await repository.addTaskSchedule(notifTask);
      expect(
        notificationService.scheduledTasks.containsKey(notifTask.id),
        isTrue,
      );

      await repository.deleteTaskSchedule(notifTask.id);
      expect(
        notificationService.scheduledTasks.containsKey(notifTask.id),
        isFalse,
      );
    });

    test('completeTask schedules next occurrence if recurring', () async {
      await repository.addTaskSchedule(notifTask);
      expect(
        notificationService.scheduledTasks.containsKey(notifTask.id),
        isTrue,
      );

      final instanceId = '${notifTask.id}_2024-01-01';
      await repository.completeTaskInstance(instanceId);
      // Still scheduled because it's recurring and advances to the next occurrence
      expect(
        notificationService.scheduledTasks.containsKey(notifTask.id),
        isTrue,
      );
    });

    test(
      'completeTask shift policy: reschedules relative to completion date',
      () async {
        AppClock.setMockTime(DateTime(2026, 6, 1, 12, 0));

        final shiftTask = TaskSchedule(
          id: 'task-shift-id',
          title: 'Shift Task',
          description: 'Test description',
          missedPolicy: MissedPolicy.shift,
          isMaster: true,
          schedules: [
            DailySchedule(
              startDate: const CivilDay(year: 2026, month: 6, day: 1),
              interval: 1,
            ),
          ],
        );

        await repository.addTaskSchedule(shiftTask);
        await Future.delayed(Duration.zero);

        // Spawns instance for June 1 (startDate)
        final instanceId = '${shiftTask.id}_2026-06-01';
        final initialSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(instanceId)
            .get();
        expect(initialSnapshot.exists, isTrue);

        // Fast-forward to June 9
        AppClock.setMockTime(DateTime(2026, 6, 9, 12, 0));

        // Complete June 1 instance on June 9
        await repository.completeTaskInstance(instanceId);

        // Verify June 1 instance is completed
        final completedSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(instanceId)
            .get();
        expect(completedSnapshot.data()!['status'], 'completed');

        // Shift policy reschedules relative to completion date (June 9) -> June 10.
        // Under just-in-time spawning, the June 10 instance is not spawned immediately on June 9.
        final nextInstanceId = '${shiftTask.id}_2026-06-10';
        final nextSnapshotBefore = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(nextInstanceId)
            .get();
        expect(nextSnapshotBefore.exists, isFalse);

        // Fast-forward to June 10
        AppClock.setMockTime(DateTime(2026, 6, 10, 12, 0));
        await repository.triggerMissedPolicyProcessing();
        await Future.delayed(const Duration(milliseconds: 100));

        final nextSnapshotAfter = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(nextInstanceId)
            .get();
        expect(nextSnapshotAfter.exists, isTrue);
        expect(nextSnapshotAfter.data()!['status'], 'pending');

        // Verify June 2 instance does NOT exist
        final skippedSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc('${shiftTask.id}_2026-06-02')
            .get();
        expect(skippedSnapshot.exists, isFalse);

        AppClock.reset();
      },
    );

    test(
      'completeTask stack policy: reschedules relative to scheduledDate',
      () async {
        // Set mock time to June 1, 2026
        AppClock.setMockTime(DateTime(2026, 6, 1, 12, 0));

        final stackTask = TaskSchedule(
          id: 'task-stack-id',
          title: 'Stack Task',
          description: 'Test description',
          missedPolicy: MissedPolicy.stack,
          isMaster: true,
          schedules: [
            DailySchedule(
              startDate: const CivilDay(year: 2026, month: 6, day: 1),
              interval: 1,
            ),
          ],
        );

        await repository.addTaskSchedule(stackTask);
        await Future.delayed(Duration.zero);

        // Spawns instance for June 1
        final instanceId = '${stackTask.id}_2026-06-01';
        final initialSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(instanceId)
            .get();
        expect(initialSnapshot.exists, isTrue);

        // Complete June 1 instance on June 1
        await repository.completeTaskInstance(instanceId);

        // Verify June 1 instance is completed
        final completedSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(instanceId)
            .get();
        expect(completedSnapshot.data()!['status'], 'completed');

        // Stack policy reschedules relative to scheduledDate (June 1) -> June 2.
        // Under just-in-time spawning, the June 2 instance is not spawned immediately on June 1.
        final nextInstanceId = '${stackTask.id}_2026-06-02';
        final nextSnapshotBefore = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(nextInstanceId)
            .get();
        expect(nextSnapshotBefore.exists, isFalse);

        // Fast-forward to June 2
        AppClock.setMockTime(DateTime(2026, 6, 2, 12, 0));
        await repository.triggerMissedPolicyProcessing();
        await Future.delayed(const Duration(milliseconds: 100));

        final nextSnapshotAfter = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(nextInstanceId)
            .get();
        expect(nextSnapshotAfter.exists, isTrue);
        expect(nextSnapshotAfter.data()!['status'], 'pending');

        AppClock.reset();
      },
    );

    test(
      'completeTask rollover policy: reschedules relative to scheduledDate',
      () async {
        // Set mock time to June 1, 2026
        AppClock.setMockTime(DateTime(2026, 6, 1, 12, 0));

        final rolloverTask = TaskSchedule(
          id: 'task-rollover-id',
          title: 'Rollover Task',
          description: 'Test description',
          missedPolicy: MissedPolicy.rollover,
          isMaster: true,
          schedules: [
            DailySchedule(
              startDate: const CivilDay(year: 2026, month: 6, day: 1),
              interval: 1,
            ),
          ],
        );

        await repository.addTaskSchedule(rolloverTask);
        await Future.delayed(Duration.zero);

        // Spawns instance for June 1 (startDate)
        final instanceId = '${rolloverTask.id}_2026-06-01';
        final initialSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(instanceId)
            .get();
        expect(initialSnapshot.exists, isTrue);

        // Fast-forward to June 9
        AppClock.setMockTime(DateTime(2026, 6, 9, 12, 0));

        // Complete June 1 instance on June 9
        await repository.completeTaskInstance(instanceId);

        // Verify June 1 instance is completed
        final completedSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(instanceId)
            .get();
        expect(completedSnapshot.data()!['status'], 'completed');

        // Reschedules relative to completion date/today -> June 10.
        // Under just-in-time spawning, the June 10 instance is not spawned immediately on June 9.
        final nextInstanceId = '${rolloverTask.id}_2026-06-10';
        final nextSnapshotBefore = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(nextInstanceId)
            .get();
        expect(nextSnapshotBefore.exists, isFalse);

        // Fast-forward to June 10
        AppClock.setMockTime(DateTime(2026, 6, 10, 12, 0));
        await repository.triggerMissedPolicyProcessing();
        await Future.delayed(const Duration(milliseconds: 100));

        final nextSnapshotAfter = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(nextInstanceId)
            .get();
        expect(nextSnapshotAfter.exists, isTrue);
        expect(nextSnapshotAfter.data()!['status'], 'pending');

        AppClock.reset();
      },
    );

    test(
      'completeTask early completion: reschedules relative to scheduledDate to prevent duplicate/overwriting instances',
      () async {
        // Set mock time to June 1, 2026
        AppClock.setMockTime(DateTime(2026, 6, 1, 12, 0));

        final task = TaskSchedule(
          id: 'early-comp-task',
          title: 'Early Completion Task',
          description: 'Test description',
          missedPolicy: MissedPolicy.rollover,
          schedules: [
            WeeklySchedule(
              startDate: const CivilDay(
                year: 2026,
                month: 6,
                day: 3,
              ), // Wednesday June 3
              interval: 1,
              daysOfWeek: const {3},
            ),
          ],
        );

        await repository.addTaskSchedule(task);
        await Future.delayed(Duration.zero);

        final instanceId = '${task.id}_2026-06-03';
        final initialInstance = TaskInstance(
          id: instanceId,
          scheduleId: task.id,
          title: task.title,
          description: task.description,
          scheduledDate: const CivilDay(year: 2026, month: 6, day: 3),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          status: 'pending',
        );
        await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(instanceId)
            .set(initialInstance.toFirestore());

        // Verify June 3 instance exists and is pending
        final initialSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(instanceId)
            .get();
        expect(initialSnapshot.exists, isTrue);
        expect(initialSnapshot.data()!['status'], 'pending');

        // Complete the June 3 instance early on June 1
        await repository.completeTaskInstance(instanceId);

        // Verify June 3 instance is completed, NOT pending
        final completedSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(instanceId)
            .get();
        expect(completedSnapshot.data()!['status'], 'completed');

        // Verify the next occurrence (June 10) is not spawned immediately on June 1.
        final nextInstanceId = '${task.id}_2026-06-10';
        final nextSnapshotBefore = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(nextInstanceId)
            .get();
        expect(nextSnapshotBefore.exists, isFalse);

        // Fast-forward to June 10
        AppClock.setMockTime(DateTime(2026, 6, 10, 12, 0));
        await repository.triggerMissedPolicyProcessing();
        await Future.delayed(const Duration(milliseconds: 100));

        final nextSnapshotAfter = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(nextInstanceId)
            .get();
        expect(nextSnapshotAfter.exists, isTrue);
        expect(nextSnapshotAfter.data()!['status'], 'pending');

        AppClock.reset();
      },
    );

    test(
      'regression: concurrent/rapid stream emissions do not skip spawning tasks',
      () async {
        final taskA = TaskSchedule(
          id: 'task-a',
          title: 'Task A',
          description: 'Desc A',
          lastSpawnedDate: null,
          schedules: [
            DailySchedule(
              startDate: CivilDay.fromDateTime(AppClock.now),
              interval: 1,
            ),
          ],
        );

        final taskB = TaskSchedule(
          id: 'task-b',
          title: 'Task B',
          description: 'Desc B',
          lastSpawnedDate: null,
          schedules: [
            DailySchedule(
              startDate: CivilDay.fromDateTime(AppClock.now),
              interval: 1,
            ),
          ],
        );

        // Start listening to the tasks stream to activate the auto missed policy processing.
        final subscription = repository.getTasks().listen((_) {});

        // Add task A to Firestore.
        await firestore
            .collection('users')
            .doc(userId)
            .collection('tasks')
            .doc(taskA.id)
            .set(taskA.toFirestore());

        // Immediately write task B to Firestore, causing two rapid snapshot emissions.
        await firestore
            .collection('users')
            .doc(userId)
            .collection('tasks')
            .doc(taskB.id)
            .set(taskB.toFirestore());

        // Wait a moment for the streams and background futures to complete.
        await Future.delayed(const Duration(milliseconds: 500));

        // Verify if instances for both Task A and Task B were spawned.
        final instancesSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .get();

        final spawnedIds = instancesSnapshot.docs.map((d) => d.id).toList();

        expect(spawnedIds.any((id) => id.contains('task-a')), isTrue);
        expect(spawnedIds.any((id) => id.contains('task-b')), isTrue);

        await subscription.cancel();
      },
    );

    test(
      'regression: new repeating task with start time in future spawns instance immediately',
      () async {
        final mockTime = DateTime(2026, 6, 22, 10, 0, 0);
        AppClock.setMockTime(mockTime);

        final task = TaskSchedule(
          id: 'future-repeating-task',
          title: 'Future Repeating Task',
          description: 'Desc',
          lastSpawnedDate: CivilDay(year: 2026, month: 6, day: 21), // yesterday
          schedules: [
            DailySchedule(
              startDate: CivilDay(year: 2026, month: 6, day: 22), // today
              interval: 1,
              startRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 10, minute: 1), // 1 minute in future
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 11, minute: 0),
              ),
            ),
          ],
        );

        final subscription = repository.getTasks().listen((_) {});

        await repository.addTaskSchedule(task);

        // Wait a moment for background processing
        await Future.delayed(const Duration(milliseconds: 200));

        final instanceSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc('${task.id}_2026-06-22')
            .get();

        expect(instanceSnapshot.exists, isTrue);
        expect(instanceSnapshot.data()!['status'], equals('pending'));

        await subscription.cancel();
        AppClock.reset();
      },
    );

    test(
      'regression: editing a repeating task schedule deletes and spawns the instance for today',
      () async {
        final mockTime = DateTime(2026, 6, 22, 10, 0, 0);
        AppClock.setMockTime(mockTime);

        final task = TaskSchedule(
          id: 'edit-repeating-task',
          title: 'Edit Repeating Task',
          description: 'Desc',
          lastSpawnedDate: CivilDay(year: 2026, month: 6, day: 21), // yesterday
          schedules: [
            DailySchedule(
              startDate: CivilDay(year: 2026, month: 6, day: 22), // today
              interval: 1,
              startRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 10, minute: 1),
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 11, minute: 0),
              ),
            ),
          ],
        );

        final subscription = repository.getTasks().listen((_) {});

        await repository.addTaskSchedule(task);
        await Future.delayed(const Duration(milliseconds: 200));

        // Verify instance is spawned for today
        var snapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc('${task.id}_2026-06-22')
            .get();
        expect(snapshot.exists, isTrue);

        // Fetch task from Firestore to get updated lastSpawnedDate
        final updatedTaskDoc = await firestore
            .collection('users')
            .doc(userId)
            .collection('tasks')
            .doc(task.id)
            .get();
        final updatedTask = TaskSchedule.fromFirestore(updatedTaskDoc);
        expect(
          updatedTask.lastSpawnedDate,
          equals(CivilDay(year: 2026, month: 6, day: 22)),
        );

        // Edit schedule
        final modification = updatedTask.edit(
          newTitle: 'Edit Repeating Task',
          newDescription: 'Desc',
          newSchedules: [
            DailySchedule(
              startDate: CivilDay(year: 2026, month: 6, day: 22),
              interval: 1,
              startRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 10, minute: 5), // Changed start time
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 11, minute: 0),
              ),
            ),
          ],
          newEstimatedDuration: null,
          newMissedPolicy: MissedPolicy.stack,
          newIsMaster: true,
          newLastSpawnedDate: updatedTask.lastSpawnedDate,
          newIsFamily: false,
          newPriority: TaskPriority.medium,
        );

        await repository.updateTaskSchedule(modification);
        await Future.delayed(const Duration(milliseconds: 200));

        // Verify if instance is spawned for today
        snapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc('${task.id}_2026-06-22')
            .get();

        expect(
          snapshot.exists,
          isTrue,
          reason: 'Today\'s instance should be re-spawned after editing',
        );

        await subscription.cancel();
        AppClock.reset();
      },
    );

    test(
      'regression: completing a recurring task advances lastSpawnedDate to the newly spawned instance date',
      () async {
        AppClock.setMockTime(DateTime(2026, 6, 22, 10, 0));

        final task = TaskSchedule(
          id: 'complete-last-spawned-advance',
          title: 'Weekly Task',
          description: 'Weekly task description',
          lastSpawnedDate: const CivilDay(year: 2026, month: 6, day: 22),
          schedules: [
            WeeklySchedule(
              startDate: const CivilDay(year: 2026, month: 6, day: 22),
              interval: 1,
              daysOfWeek: const {4}, // Thursday
            ),
          ],
        );

        await repository.addTaskSchedule(task);

        final instanceId = '${task.id}_2026-06-22';
        final instance = TaskInstance(
          id: instanceId,
          scheduleId: task.id,
          title: task.title,
          description: task.description,
          scheduledDate: const CivilDay(year: 2026, month: 6, day: 22),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          status: 'pending',
        );
        await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(instanceId)
            .set(instance.toFirestore());

        final subscription = repository.getTasks().listen((_) {});

        await repository.completeTaskInstance(instanceId);
        await Future.delayed(const Duration(milliseconds: 100));

        final updatedDoc = await firestore
            .collection('users')
            .doc(userId)
            .collection('tasks')
            .doc(task.id)
            .get();
        final updatedTask = TaskSchedule.fromFirestore(updatedDoc);

        // Under just-in-time spawning, lastSpawnedDate is advanced to the day before the next occurrence (June 24)
        expect(
          updatedTask.lastSpawnedDate,
          equals(const CivilDay(year: 2026, month: 6, day: 24)),
        );

        // Verify the 6/25 instance does not exist yet
        final nextInstanceId = '${task.id}_2026-06-25';
        final nextSnapshotBefore = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(nextInstanceId)
            .get();
        expect(nextSnapshotBefore.exists, isFalse);

        // Fast-forward to Thursday 6/25
        AppClock.setMockTime(DateTime(2026, 6, 25, 10, 0));
        await repository.triggerMissedPolicyProcessing();
        await Future.delayed(const Duration(milliseconds: 100));

        // Now, the 6/25 instance should be spawned
        final nextSnapshotAfter = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(nextInstanceId)
            .get();
        expect(nextSnapshotAfter.exists, isTrue);
        expect(nextSnapshotAfter.data()!['status'], 'pending');

        // And the task's lastSpawnedDate should be advanced to 6/25
        final finalDoc = await firestore
            .collection('users')
            .doc(userId)
            .collection('tasks')
            .doc(task.id)
            .get();
        final finalTask = TaskSchedule.fromFirestore(finalDoc);
        expect(
          finalTask.lastSpawnedDate,
          equals(const CivilDay(year: 2026, month: 6, day: 25)),
        );

        await subscription.cancel();
        AppClock.reset();
      },
    );

    test(
      'regression: undoing a recurring task resolution reverts lastSpawnedDate to the completed instance date',
      () async {
        AppClock.setMockTime(DateTime(2026, 6, 22, 10, 0));

        final task = TaskSchedule(
          id: 'undo-last-spawned-revert',
          title: 'Weekly Task Revert',
          description: 'Weekly task description',
          lastSpawnedDate: const CivilDay(year: 2026, month: 6, day: 25),
          schedules: [
            WeeklySchedule(
              startDate: const CivilDay(year: 2026, month: 6, day: 22),
              interval: 1,
              daysOfWeek: const {4}, // Thursday
            ),
          ],
        );

        await repository.addTaskSchedule(task);

        final instanceId = '${task.id}_2026-06-22';
        final instance = TaskInstance(
          id: instanceId,
          scheduleId: task.id,
          title: task.title,
          description: task.description,
          scheduledDate: const CivilDay(year: 2026, month: 6, day: 22),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          status: 'completed',
          completedAt: DateTime(2026, 6, 22, 10, 0),
          completedByUserId: userId,
        );
        await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(instanceId)
            .set(instance.toFirestore());

        final nextInstanceId = '${task.id}_2026-06-25';
        final nextInstance = TaskInstance(
          id: nextInstanceId,
          scheduleId: task.id,
          title: task.title,
          description: task.description,
          scheduledDate: const CivilDay(year: 2026, month: 6, day: 25),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          status: 'pending',
        );
        await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(nextInstanceId)
            .set(nextInstance.toFirestore());

        final subscription = repository.getTasks().listen((_) {});

        await repository.undoResolveTaskInstance(instance);
        await Future.delayed(const Duration(milliseconds: 100));

        final updatedDoc = await firestore
            .collection('users')
            .doc(userId)
            .collection('tasks')
            .doc(task.id)
            .get();
        final updatedTask = TaskSchedule.fromFirestore(updatedDoc);

        expect(
          updatedTask.lastSpawnedDate,
          equals(const CivilDay(year: 2026, month: 6, day: 22)),
        );

        await subscription.cancel();
        AppClock.reset();
      },
    );

    test(
      'unit: JIT spawning logic correctly separates future and current occurrences',
      () async {
        AppClock.setMockTime(DateTime(2026, 6, 22, 12, 0)); // Monday

        // Task with daily schedule (every day)
        final dailyTask = TaskSchedule(
          id: 'jit-test-daily',
          title: 'Daily JIT Task',
          description: 'Desc',
          lastSpawnedDate: const CivilDay(year: 2026, month: 6, day: 22),
          schedules: [
            DailySchedule(
              startDate: const CivilDay(year: 2026, month: 6, day: 22),
              interval: 1,
            ),
          ],
        );

        await repository.addTaskSchedule(dailyTask);

        final instanceId = '${dailyTask.id}_2026-06-22';
        final instance = TaskInstance(
          id: instanceId,
          scheduleId: dailyTask.id,
          title: dailyTask.title,
          description: dailyTask.description,
          scheduledDate: const CivilDay(year: 2026, month: 6, day: 22),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          status: 'pending',
        );
        await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(instanceId)
            .set(instance.toFirestore());

        final subscription = repository.getTasks().listen((_) {});

        // 1. Complete June 22 on June 22.
        // The next occurrence is June 23 (future). It should NOT be spawned.
        await repository.completeTaskInstance(instanceId);
        await Future.delayed(const Duration(milliseconds: 100));

        final nextSnapshotFuture = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc('${dailyTask.id}_2026-06-23')
            .get();
        expect(nextSnapshotFuture.exists, isFalse);

        // 2. Now let's test that the JIT scheduler spawns the June 23 (missed) and June 24 (due) instances when the clock reaches June 24, while June 25 is still not spawned.
        // We set the clock to June 24.
        AppClock.setMockTime(DateTime(2026, 6, 24, 12, 0));
        await repository.triggerMissedPolicyProcessing();
        await Future.delayed(const Duration(milliseconds: 100));

        // The June 23 instance is spawned (by JIT processing as missed from June 23)
        final snapJune23 = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc('${dailyTask.id}_2026-06-23')
            .get();
        expect(snapJune23.exists, isTrue);
        expect(snapJune23.data()!['status'], 'pending');

        // The June 24 instance is spawned (due today)
        final snapJune24 = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc('${dailyTask.id}_2026-06-24')
            .get();
        expect(snapJune24.exists, isTrue);
        expect(snapJune24.data()!['status'], 'pending');

        // The June 25 instance is not spawned (future)
        final snapJune25 = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc('${dailyTask.id}_2026-06-25')
            .get();
        expect(snapJune25.exists, isFalse);

        await subscription.cancel();
        AppClock.reset();
      },
    );

    test(
      'unit: legacy future pending tasks cleanup correctly deletes future pending instances and reverts lastSpawnedDate',
      () async {
        AppClock.setMockTime(DateTime(2026, 6, 22, 12, 0)); // Monday June 22

        final task = TaskSchedule(
          id: 'legacy-cleanup-task',
          title: 'Legacy Task',
          description: 'Weekly task description',
          // Set to a future date as if it was pre-spawned
          lastSpawnedDate: const CivilDay(year: 2026, month: 6, day: 25),
          schedules: [
            WeeklySchedule(
              startDate: const CivilDay(year: 2026, month: 6, day: 22),
              interval: 1,
              daysOfWeek: const {4}, // Thursday June 25
            ),
          ],
        );

        await repository.addTaskSchedule(task);

        // Pre-create the future pending instance in Firestore
        final futureInstanceId = '${task.id}_2026-06-25';
        final futureInstance = TaskInstance(
          id: futureInstanceId,
          scheduleId: task.id,
          title: task.title,
          description: task.description,
          scheduledDate: const CivilDay(year: 2026, month: 6, day: 25),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          status: 'pending',
        );
        await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(futureInstanceId)
            .set(futureInstance.toFirestore());

        final subscription = repository.getTasks().listen((_) {});

        // Trigger missed policy processing on June 22.
        // It should detect the future pending instance on June 25, delete it, and revert lastSpawnedDate.
        await repository.triggerMissedPolicyProcessing();
        await Future.delayed(const Duration(milliseconds: 100));

        // Verify the June 25 instance is deleted
        final snapJune25Before = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(futureInstanceId)
            .get();
        expect(snapJune25Before.exists, isFalse);

        // Verify the schedule's lastSpawnedDate is reverted to June 24 (the day before the deleted future instance)
        final updatedDoc = await firestore
            .collection('users')
            .doc(userId)
            .collection('tasks')
            .doc(task.id)
            .get();
        final updatedTask = TaskSchedule.fromFirestore(updatedDoc);
        expect(
          updatedTask.lastSpawnedDate,
          equals(const CivilDay(year: 2026, month: 6, day: 24)),
        );

        // Fast-forward to Thursday June 25
        AppClock.setMockTime(DateTime(2026, 6, 25, 12, 0));
        await repository.triggerMissedPolicyProcessing();
        await Future.delayed(const Duration(milliseconds: 100));

        // Verify the June 25 instance is now spawned just-in-time
        final snapJune25After = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(futureInstanceId)
            .get();
        expect(snapJune25After.exists, isTrue);
        expect(snapJune25After.data()!['status'], 'pending');

        await subscription.cancel();
        AppClock.reset();
      },
    );
  });
}
