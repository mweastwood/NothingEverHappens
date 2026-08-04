import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/logic/notification_service.dart';
import 'package:nothing_ever_happens/logic/auth_repository.dart';
import 'package:nothing_ever_happens/logic/user_settings.dart';
import 'package:nothing_ever_happens/logic/user_settings_repository.dart';

Future<String> _findInstanceId(
  FakeFirebaseFirestore firestore,
  String userId,
  String taskId,
  CivilDay date,
) async {
  final snap = await firestore
      .collection('users')
      .doc(userId)
      .collection('instances')
      .get();
  final doc = snap.docs.firstWhere(
    (d) {
      final data = d.data();
      final sDate = data['scheduledDate'];
      return data['scheduleId'] == taskId &&
          sDate['year'] == date.year &&
          sDate['month'] == date.month &&
          sDate['day'] == date.day;
    },
    orElse: () =>
        throw StateError('No instance found for task $taskId on $date'),
  );
  return doc.id;
}

void main() {
  group('TaskRepository', () {
    late FakeFirebaseFirestore firestore;
    late TaskRepository repository;
    const userId = 'test-user-id';

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = TaskRepository(firestore: firestore, userId: userId);
    });

    Future<String> findInstanceId(String taskId, CivilDay date) =>
        _findInstanceId(firestore, userId, taskId, date);

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

    test(
      'getTasks returns a stream of tasks including family tasks when in family',
      () async {
        await firestore.collection('users').doc(userId).set({
          'familyId': 'fam-123',
        });

        final familyTask = TaskSchedule(
          id: 'family-task-1',
          title: 'Family Task',
          description: 'Shared Family Task',
          isFamily: true,
          schedules: [
            OneOffSchedule(
              date: const CivilDay(year: 2026, month: 8, day: 3),
              startRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 10, minute: 0),
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 18, minute: 0),
              ),
            ),
          ],
        );

        final stream = repository.getTasks();
        final futureTasks = stream.firstWhere(
          (list) => list.any((t) => t.id == familyTask.id),
        );

        // Add a personal task and a family task so both personal and family streams receive events
        await repository.addTaskSchedule(testTask);
        await repository.addTaskSchedule(familyTask);

        final tasks = await futureTasks;
        expect(tasks.any((t) => t.id == familyTask.id), isTrue);
        expect(tasks.any((t) => t.id == testTask.id), isTrue);
      },
    );

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

        final instanceId = await findInstanceId(
          testTask.id,
          const CivilDay(year: 2024, month: 1, day: 1),
        );

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

      final instanceId = await findInstanceId(
        testTask.id,
        const CivilDay(year: 2024, month: 1, day: 1),
      );
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

      final instanceId = await findInstanceId(
        testTask.id,
        const CivilDay(year: 2024, month: 1, day: 1),
      );
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

        final instanceId = await findInstanceId(
          recurringTask.id,
          const CivilDay(year: 2026, month: 6, day: 1),
        );
        final nextInstanceId = await findInstanceId(
          recurringTask.id,
          const CivilDay(year: 2026, month: 6, day: 2),
        );

        // 1. Complete the June 1 instance on June 1
        await repository.completeTaskInstance(instanceId);

        // Verify next spawned exists under N=1 spawning
        final nextSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(nextInstanceId)
            .get();
        expect(nextSnapshot.exists, isTrue);

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

        // Verify next spawned still exists under new Daily spawning rules
        final nextSnapshotPost = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(nextInstanceId)
            .get();
        expect(nextSnapshotPost.exists, isTrue);

        // Verify June 12 was deleted as part of the undo (since June 1 to 11 are within the 10 lookahead limit, June 12 is pruned)
        final instsPostUndo = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .get();
        final hasJune12 = instsPostUndo.docs.any(
          (d) => d.data()['scheduledDate']['day'] == 12,
        );
        expect(hasJune12, isFalse);

        AppClock.reset();
      },
    );

    test(
      'undoResolveTaskInstance reverts dismissed instance to pending',
      () async {
        await repository.addTaskSchedule(testTask);
        await Future.delayed(Duration.zero);

        final instanceId = await findInstanceId(
          testTask.id,
          const CivilDay(year: 2024, month: 1, day: 1),
        );

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

        final instanceId = await findInstanceId(
          dailyTask.id,
          const CivilDay(year: 2026, month: 6, day: 1),
        );

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

        final instanceId2 = await findInstanceId(
          dailyTask2.id,
          const CivilDay(year: 2026, month: 6, day: 1),
        );
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
          missedPolicy: MissedPolicy.stack,
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
          newMissedPolicy: MissedPolicy.stack,
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
        expect(tasksSnap.docs.first.id, weeklyTask.id);

        final instancesSnap = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .get();

        expect(instancesSnap.docs.length, 7);

        final weeklyRule = modification.newTask.schedules[0];
        final monthlyRule = modification.newTask.schedules[1];

        expect(
          instancesSnap.docs.any(
            (d) =>
                d.data()['ruleId'] == weeklyRule.id &&
                d.data()['scheduledDate']['day'] == 15,
          ),
          isTrue,
        );
        expect(
          instancesSnap.docs.any(
            (d) =>
                d.data()['ruleId'] == weeklyRule.id &&
                d.data()['scheduledDate']['day'] == 22,
          ),
          isTrue,
        );
        expect(
          instancesSnap.docs.any(
            (d) =>
                d.data()['ruleId'] == monthlyRule.id &&
                d.data()['scheduledDate']['day'] == 15,
          ),
          isTrue,
        );
        expect(
          instancesSnap.docs.any(
            (d) =>
                d.data()['ruleId'] == monthlyRule.id &&
                d.data()['scheduledDate']['month'] == 7 &&
                d.data()['scheduledDate']['day'] == 15,
          ),
          isTrue,
        );
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

    Future<String> findInstanceId(String taskId, CivilDay date) =>
        _findInstanceId(firestore, userId, taskId, date);

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
      AppClock.setMockTime(DateTime(2024, 1, 1, 12, 0));
      addTearDown(AppClock.reset);

      await repository.addTaskSchedule(notifTask);
      await Future.delayed(Duration.zero);
      expect(
        notificationService.scheduledTasks.containsKey(notifTask.id),
        isTrue,
      );

      final instanceId = await findInstanceId(
        notifTask.id,
        const CivilDay(year: 2024, month: 1, day: 1),
      );
      await repository.completeTaskInstance(instanceId);
      // Still scheduled because it's recurring and advances to the next occurrence
      expect(
        notificationService.scheduledTasks.containsKey(notifTask.id),
        isTrue,
      );
    });

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

        // Spawns instance for June 1 (startDate) and June 2 (since N=1)
        final instanceId = await findInstanceId(
          stackTask.id,
          const CivilDay(year: 2026, month: 6, day: 1),
        );
        final initialSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(instanceId)
            .get();
        expect(initialSnapshot.exists, isTrue);

        final nextInstanceId = await findInstanceId(
          stackTask.id,
          const CivilDay(year: 2026, month: 6, day: 2),
        );
        final nextSnapshotBefore = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(nextInstanceId)
            .get();
        expect(nextSnapshotBefore.exists, isTrue);
        expect(nextSnapshotBefore.data()!['status'], 'pending');

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

        // Fast-forward to June 2
        AppClock.setMockTime(DateTime(2026, 6, 2, 12, 0));
        await repository.triggerMissedPolicyProcessing();
        await Future.delayed(const Duration(milliseconds: 100));

        // Under queue model, now that June 1 is completed and June 2 is the next/current, June 3 should be spawned.
        final june3InstanceId = await findInstanceId(
          stackTask.id,
          const CivilDay(year: 2026, month: 6, day: 3),
        );
        final june3Snapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(june3InstanceId)
            .get();
        expect(june3Snapshot.exists, isTrue);
        expect(june3Snapshot.data()!['status'], 'pending');

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
          missedPolicy: MissedPolicy.stack,
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

        // Under N=1 queue, June 3 instance is spawned immediately on June 1 as a future occurrence.
        final instanceId = await findInstanceId(
          task.id,
          const CivilDay(year: 2026, month: 6, day: 3),
        );

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

        // Under N=1 queue model, completing June 3 immediately spawns the next occurrence (June 10)
        final nextInstanceId = await findInstanceId(
          task.id,
          const CivilDay(year: 2026, month: 6, day: 10),
        );
        final nextSnapshotBefore = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(nextInstanceId)
            .get();
        expect(nextSnapshotBefore.exists, isTrue);
        expect(nextSnapshotBefore.data()!['status'], 'pending');

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

        final spawnedInstances = instancesSnapshot.docs
            .map((d) => TaskInstance.fromFirestore(d))
            .toList();

        expect(
          spawnedInstances.any((inst) => inst.scheduleId == taskA.id),
          isTrue,
        );
        expect(
          spawnedInstances.any((inst) => inst.scheduleId == taskB.id),
          isTrue,
        );

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

        final instanceId = await findInstanceId(
          task.id,
          const CivilDay(year: 2026, month: 6, day: 22),
        );
        final instanceSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(instanceId)
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
        final instanceId = await findInstanceId(
          task.id,
          const CivilDay(year: 2026, month: 6, day: 22),
        );
        var snapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(instanceId)
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

        // Verify if new instance is spawned for today (with new UUID since it was recreated)
        final newInstanceId = await findInstanceId(
          task.id,
          const CivilDay(year: 2026, month: 6, day: 22),
        );
        snapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(newInstanceId)
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

        // Pre-create the June 22 instance in Firestore (which is a manually added occurrence)
        final instanceId = 'I-manual-june22';
        final instance = TaskInstance(
          id: instanceId,
          scheduleId: task.id,
          ruleId: task.schedules.first.id,
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

        // Under queue model, completing June 22 does not change the lastSpawnedDate yet, as June 25 is in the future
        expect(
          updatedTask.lastSpawnedDate,
          equals(const CivilDay(year: 2026, month: 6, day: 22)),
        );

        // Verify the 6/25 instance is already spawned under queue model (N=1)
        final nextInstanceId = await findInstanceId(
          task.id,
          const CivilDay(year: 2026, month: 6, day: 25),
        );
        final nextSnapshotBefore = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(nextInstanceId)
            .get();
        expect(nextSnapshotBefore.exists, isTrue);

        // Fast-forward to Thursday 6/25
        AppClock.setMockTime(DateTime(2026, 6, 25, 10, 0));
        await repository.triggerMissedPolicyProcessing();
        await Future.delayed(const Duration(milliseconds: 100));

        // Now, the task's lastSpawnedDate should be advanced to 6/25 since June 25 is now in the past/today
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
      'regression: undoing a recurring task resolution does not revert lastSpawnedDate under queue model',
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

        final instanceId = 'I-completed-june22';
        final instance = TaskInstance(
          id: instanceId,
          scheduleId: task.id,
          ruleId: task.schedules.first.id,
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

        // Pre-create the June 25 instance
        final nextInstanceId = 'I-pending-june25';
        final nextInstance = TaskInstance(
          id: nextInstanceId,
          scheduleId: task.id,
          ruleId: task.schedules.first.id,
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

        // Under queue model, lastSpawnedDate is not reverted to June 22 because June 25 is still spawned
        expect(
          updatedTask.lastSpawnedDate,
          equals(const CivilDay(year: 2026, month: 6, day: 25)),
        );

        await subscription.cancel();
        AppClock.reset();
      },
    );

    test(
      'unit: queue-based spawning logic maintains N future instances',
      () async {
        AppClock.setMockTime(DateTime(2026, 6, 22, 12, 0)); // Monday June 22

        // Task with daily schedule (every day)
        final dailyTask = TaskSchedule(
          id: 'queue-test-daily',
          title: 'Daily Queue Task',
          description: 'Desc',
          schedules: [
            DailySchedule(
              startDate: const CivilDay(year: 2026, month: 6, day: 22),
              interval: 1,
            ),
          ],
        );

        await repository.addTaskSchedule(dailyTask);
        await Future.delayed(const Duration(milliseconds: 100));

        // Under N=1 model, both June 22 and June 23 are spawned immediately
        final june22Id = await findInstanceId(
          dailyTask.id,
          const CivilDay(year: 2026, month: 6, day: 22),
        );
        final june23Id = await findInstanceId(
          dailyTask.id,
          const CivilDay(year: 2026, month: 6, day: 23),
        );

        final snapJune22 = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(june22Id)
            .get();
        expect(snapJune22.exists, isTrue);
        expect(snapJune22.data()!['status'], 'pending');

        final snapJune23 = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(june23Id)
            .get();
        expect(snapJune23.exists, isTrue);
        expect(snapJune23.data()!['status'], 'pending');

        // Complete June 22
        await repository.completeTaskInstance(june22Id);
        await Future.delayed(const Duration(milliseconds: 100));

        // Completing June 22 advances the latest uncompleted to June 23.
        // The queue (N=1) now needs June 24 to be spawned.
        final june24Id = await findInstanceId(
          dailyTask.id,
          const CivilDay(year: 2026, month: 6, day: 24),
        );
        final snapJune24 = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(june24Id)
            .get();
        expect(snapJune24.exists, isTrue);
        expect(snapJune24.data()!['status'], 'pending');

        AppClock.reset();
      },
    );

    test(
      'unit: editing a schedule deletes old future instances and recreates them',
      () async {
        AppClock.setMockTime(DateTime(2026, 6, 22, 12, 0)); // Monday June 22

        final task = TaskSchedule(
          id: 'edit-cleanup-task',
          title: 'Legacy Task',
          description: 'Weekly task description',
          lastSpawnedDate: const CivilDay(year: 2026, month: 6, day: 22),
          schedules: [
            WeeklySchedule(
              startDate: const CivilDay(year: 2026, month: 6, day: 22),
              interval: 1,
              daysOfWeek: const {4}, // Thursday June 25
            ),
          ],
        );

        await repository.addTaskSchedule(task);
        await Future.delayed(const Duration(milliseconds: 100));

        // The June 25 instance is spawned immediately (since N=1 and Thursday June 25 is the next occurrence)
        final oldFutureId = await findInstanceId(
          task.id,
          const CivilDay(year: 2026, month: 6, day: 25),
        );
        final snapOldFuture = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(oldFutureId)
            .get();
        expect(snapOldFuture.exists, isTrue);

        // Fetch task from Firestore to get updated lastSpawnedDate
        final updatedDoc = await firestore
            .collection('users')
            .doc(userId)
            .collection('tasks')
            .doc(task.id)
            .get();
        final updatedTask = TaskSchedule.fromFirestore(updatedDoc);

        // Edit schedule to occur on Wednesdays (June 24) instead of Thursdays
        final modification = updatedTask.edit(
          newTitle: 'Legacy Task',
          newDescription: 'Weekly task description',
          newSchedules: [
            WeeklySchedule(
              startDate: const CivilDay(year: 2026, month: 6, day: 22),
              interval: 1,
              daysOfWeek: const {3}, // Wednesday June 24
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

        // Verify the old June 25 instance is deleted
        final snapOldDeleted = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(oldFutureId)
            .get();
        expect(snapOldDeleted.exists, isFalse);

        // Verify the new June 24 instance is spawned
        final newFutureId = await findInstanceId(
          task.id,
          const CivilDay(year: 2026, month: 6, day: 24),
        );
        final snapNewFuture = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(newFutureId)
            .get();
        expect(snapNewFuture.exists, isTrue);
        expect(snapNewFuture.data()!['status'], 'pending');

        AppClock.reset();
      },
    );

    test(
      'regression: late completion of yesterday\'s instance does not skip spawning today\'s instance',
      () async {
        final mockTime = DateTime(2026, 6, 23, 10, 0, 0); // Today is June 23
        AppClock.setMockTime(mockTime);

        final task = TaskSchedule(
          id: 'late-completion-bug',
          title: 'Daily Task',
          description: 'Desc',
          lastSpawnedDate: const CivilDay(
            year: 2026,
            month: 6,
            day: 21,
          ), // spawned up to June 21
          schedules: [
            DailySchedule(
              startDate: const CivilDay(
                year: 2026,
                month: 6,
                day: 22,
              ), // started June 22
              interval: 1,
            ),
          ],
        );

        await firestore
            .collection('users')
            .doc(userId)
            .collection('tasks')
            .doc(task.id)
            .set(task.toFirestore());

        // Add the June 22 instance manually as pending (since it was spawned for June 22)
        final instanceId22 = '${task.id}_2026-06-22';
        final instance22 = TaskInstance(
          id: instanceId22,
          scheduleId: task.id,
          ruleId: task.schedules.first.id,
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
            .doc(instanceId22)
            .set(instance22.toFirestore());

        // Complete the June 22 instance on June 23 (today)
        // June 23's instance has not been spawned yet, and the stream listener is not active yet.
        await repository.completeTaskInstance(instanceId22);
        await Future.delayed(const Duration(milliseconds: 100));

        final subscription = repository.getTasks().listen((_) {});
        await Future.delayed(const Duration(milliseconds: 100));

        // Now run missed policy processing to see if June 23's instance spawns
        await repository.triggerMissedPolicyProcessing();
        await Future.delayed(const Duration(milliseconds: 100));

        // Verify that today's instance (June 23) was spawned
        final instsAfter = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .get();
        final hasJune23 = instsAfter.docs.any(
          (d) =>
              d.data()['ruleId'] == task.schedules.first.id &&
              d.data()['scheduledDate']['year'] == 2026 &&
              d.data()['scheduledDate']['month'] == 6 &&
              d.data()['scheduledDate']['day'] == 23,
        );

        expect(
          hasJune23,
          isTrue,
          reason:
              'Today\'s instance (June 23) should be spawned even after completing yesterday\'s instance today',
        );

        await subscription.cancel();
        AppClock.reset();
      },
    );

    test(
      'updateTaskSchedule reacts to schedule change and triggers missed policy processing',
      () async {
        final mockTime = DateTime(2026, 6, 23, 10, 0, 0);
        AppClock.setMockTime(mockTime);

        final firestore = FakeFirebaseFirestore();

        // Add a weekly task schedule to firestore (should spawn 5 instances under Weekly rule)
        final task = TaskSchedule(
          id: 'settings-reactive-task',
          title: 'Weekly Task',
          description: 'Desc',
          lastSpawnedDate: null,
          schedules: [
            WeeklySchedule(
              startDate: const CivilDay(year: 2026, month: 6, day: 24),
              interval: 1,
              daysOfWeek: {3},
            ),
          ],
        );

        await firestore
            .collection('users')
            .doc(userId)
            .collection('tasks')
            .doc(task.id)
            .set(task.toFirestore());

        final container = ProviderContainer(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(FakeUser())),
            firestoreProvider.overrideWithValue(firestore),
            userSettingsProvider.overrideWith(
              (ref) => Stream.value(const UserSettings(hoursAvailable: 8.0)),
            ),
            notificationServiceProvider.overrideWithValue(
              LoggingNotificationService(),
            ),
          ],
        );
        addTearDown(container.dispose);

        // Await the auth state stream to emit the fake user
        await container.read(authStateProvider.future);

        // Read taskRepositoryProvider to initialize the repository
        final repository = container.read(taskRepositoryProvider);
        expect(repository, isNotNull);

        // Listen to tasks stream to trigger the initial missed policies processing
        final subscription = repository!.getTasks().listen((_) {});
        addTearDown(subscription.cancel);

        // Let the stream listener trigger the initial pass
        await Future.delayed(const Duration(milliseconds: 100));

        // Verify that 5 future instances have been created (for June 24, July 1, 8, 15, 22)
        final instsAfter5 = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .get();

        expect(instsAfter5.docs.length, 5);

        // Now, update task to a Monthly schedule (which pre-creates 3 instances, but only 2 fit within the 30-day engine window)
        final modification = task.edit(
          newTitle: task.title,
          newDescription: task.description,
          newSchedules: [
            MonthlySchedule(
              startDate: const CivilDay(year: 2026, month: 6, day: 24),
              interval: 1,
              dayOfMonth: 24,
            ),
          ],
          newEstimatedDuration: task.estimatedDuration,
          newMissedPolicy: task.missedPolicy,
          newIsMaster: task.isMaster,
          newLastSpawnedDate: task.lastSpawnedDate,
          newIsFamily: task.isFamily,
          newPriority: task.priority,
        );

        await repository.updateTaskSchedule(modification);

        // Let the repository process and spawn
        await Future.delayed(const Duration(milliseconds: 100));

        // Verify that 2 future instances have been created (for June 24 and July 24; August 24 is outside the 30-day window)
        final instsAfter3 = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .get();

        final hasJune24 = instsAfter3.docs.any(
          (d) =>
              d.data()['scheduleId'] == task.id &&
              d.data()['scheduledDate']['year'] == 2026 &&
              d.data()['scheduledDate']['month'] == 6 &&
              d.data()['scheduledDate']['day'] == 24,
        );
        final hasJuly24 = instsAfter3.docs.any(
          (d) =>
              d.data()['scheduleId'] == task.id &&
              d.data()['scheduledDate']['year'] == 2026 &&
              d.data()['scheduledDate']['month'] == 7 &&
              d.data()['scheduledDate']['day'] == 24,
        );

        expect(hasJune24, isTrue);
        expect(hasJuly24, isTrue);
        expect(instsAfter3.docs.length, 2);

        AppClock.reset();
      },
    );

    group('Thorough Caching & Spawning Tests', () {
      test(
        'in-memory write tracker prevents duplicate spawning under database latency',
        () async {
          final mockTime = DateTime(2026, 6, 23, 10, 0, 0);
          AppClock.setMockTime(mockTime);
          addTearDown(AppClock.reset);

          final dailyTask = TaskSchedule(
            id: 'tracker-duplicate-test',
            title: 'Daily Task',
            description: 'desc',
            schedules: [
              DailySchedule(
                startDate: const CivilDay(year: 2026, month: 6, day: 23),
                interval: 1,
              ),
            ],
          );

          final firestore = FakeFirebaseFirestore();
          final container = ProviderContainer(
            overrides: [
              authStateProvider.overrideWith((ref) => Stream.value(FakeUser())),
              firestoreProvider.overrideWithValue(firestore),
              notificationServiceProvider.overrideWithValue(
                LoggingNotificationService(),
              ),
            ],
          );
          addTearDown(container.dispose);

          await container.read(authStateProvider.future);
          final repository = container.read(taskRepositoryProvider)!;

          // Perform two operations rapidly without waiting for Firestore propagation
          final tasksFuture1 = repository.addTaskSchedule(dailyTask);
          final tasksFuture2 = repository.addTaskSchedule(dailyTask);

          await Future.wait([tasksFuture1, tasksFuture2]);
          await Future.delayed(const Duration(milliseconds: 200));

          final insts = await firestore
              .collection('users')
              .doc(userId)
              .collection('instances')
              .get();

          // Should spawn exactly 11 instances (today + 10 lookahead), no duplicates!
          expect(insts.docs.length, 11);
        },
      );

      test(
        'write tracker TTL expires and allows re-spawning after 2 seconds when database is deleted directly',
        () async {
          final mockTime = DateTime(2026, 6, 23, 10, 0, 0);
          AppClock.setMockTime(mockTime);
          addTearDown(AppClock.reset);

          final dailyTask = TaskSchedule(
            id: 'ttl-test-task',
            title: 'Daily Task',
            description: 'desc',
            schedules: [
              DailySchedule(
                startDate: const CivilDay(year: 2026, month: 6, day: 23),
                interval: 1,
              ),
            ],
          );

          final firestore = FakeFirebaseFirestore();
          final container = ProviderContainer(
            overrides: [
              authStateProvider.overrideWith((ref) => Stream.value(FakeUser())),
              firestoreProvider.overrideWithValue(firestore),
              notificationServiceProvider.overrideWithValue(
                LoggingNotificationService(),
              ),
            ],
          );
          addTearDown(container.dispose);

          await container.read(authStateProvider.future);
          final repository = container.read(taskRepositoryProvider)!;

          // Trigger evaluation
          await repository.addTaskSchedule(dailyTask);
          await Future.delayed(const Duration(milliseconds: 100));

          // Get the spawned instances
          final userDocRef = firestore.collection('users').doc(userId);
          final instsSnap1 = await userDocRef.collection('instances').get();
          expect(instsSnap1.docs.length, 11);

          // Delete one of the instances directly from firestore to simulate a missing/deleted instance
          final deletedInst = instsSnap1.docs.firstWhere(
            (d) => d.data()['scheduledDate']['day'] == 24,
          );
          final deletedInstId = deletedInst.id;
          await userDocRef.collection('instances').doc(deletedInstId).delete();

          // 1. If we evaluate immediately (under 2 seconds), write tracker cache is still fresh.
          // It injects a virtual instance, so the evaluator thinks it still exists and does NOT re-spawn it.
          await repository.triggerMissedPolicyProcessing();
          await Future.delayed(const Duration(milliseconds: 100));

          final instsSnap2 = await userDocRef.collection('instances').get();
          expect(instsSnap2.docs.length, 10); // Still 10 (not re-spawned)

          // 2. Advance the clock past 2 seconds (e.g. 3 seconds)
          AppClock.setMockTime(mockTime.add(const Duration(seconds: 3)));

          // Evaluate again. The tracker entry has expired, so it is ignored.
          // The evaluator sees the database is missing the instance, and re-spawns it!
          await repository.triggerMissedPolicyProcessing();
          await Future.delayed(const Duration(milliseconds: 100));

          final instsSnap3 = await userDocRef.collection('instances').get();
          expect(instsSnap3.docs.length, 11); // Re-spawned successfully!
        },
      );

      test(
        'OneOff to Repeating Conversion shifts start date to today if defaulting to tomorrow',
        () {
          final now = DateTime(2026, 6, 23, 10, 0, 0);
          AppClock.setMockTime(now);
          addTearDown(AppClock.reset);

          final tomorrow = CivilDay.fromDateTime(
            now.add(const Duration(days: 1)),
          );

          // Default one-off rule starts tomorrow with offset -1
          final oneOffRule = OneOffSchedule(
            id: 'rule-1',
            scheduleId: 'task-1',
            date: tomorrow,
            startRelativeTime: const RelativeTime(
              dayOffset: -1,
              time: TimeOfDay(hour: 10, minute: 0),
            ),
          );

          // Convert to daily repeating rule
          final dailyRule =
              convertRuleToKind(
                    oneOffRule,
                    HierarchicalRecurrenceKind.dailyFixed,
                  )
                  as DailySchedule;

          // Should shift scheduledDate to today, and dayOffset to 0
          expect(dailyRule.startDate, CivilDay.fromDateTime(now));
          expect(dailyRule.startRelativeTime.dayOffset, 0);
        },
      );

      test(
        'completeTaskInstance on a recurring family task spawns next occurrence in family collection',
        () async {
          final now = DateTime(2026, 6, 23, 10, 0, 0);
          AppClock.setMockTime(now);
          addTearDown(AppClock.reset);

          const familyId = 'family-123';
          await firestore.collection('users').doc('test-user-id').set({
            'familyId': familyId,
            'familyRole': 'parent',
          });

          final repository = TaskRepository(
            firestore: firestore,
            userId: 'test-user-id',
          );

          final task = TaskSchedule(
            id: 'family-task-1',
            title: 'Family Trash Chores',
            description: 'Take out the trash',
            assignedUserId: 'test-user-id',
            isFamily: true,
            schedules: [
              DailySchedule(
                id: 'rule-daily-family',
                scheduleId: 'family-task-1',
                startDate: const CivilDay(year: 2026, month: 6, day: 23),
                interval: 1,
              ),
            ],
            missedPolicy: MissedPolicy.stack,
          );

          await repository.addTaskSchedule(task);
          await Future.delayed(const Duration(milliseconds: 100));

          // Fetch the spawned family instances
          final familyInsts = await firestore
              .collection('families')
              .doc(familyId)
              .collection('instances')
              .get();
          final initialCount = familyInsts.docs.length;
          expect(initialCount, greaterThan(0));

          final instId = familyInsts.docs.first.id;

          // Complete the family instance
          final completed = await repository.completeTaskInstance(instId);
          expect(completed, isNotNull);
          expect(completed?.status, 'completed');

          // Should have spawned next occurrence in families collection
          final familyInstsAfter = await firestore
              .collection('families')
              .doc(familyId)
              .collection('instances')
              .get();
          expect(familyInstsAfter.docs.length, greaterThan(initialCount));
        },
      );

      test(
        'completing or dismissing orphan task instance commits status update even if task schedule is deleted',
        () async {
          final now = DateTime(2026, 6, 23, 10, 0, 0);
          AppClock.setMockTime(now);
          addTearDown(AppClock.reset);

          final repository = TaskRepository(
            firestore: firestore,
            userId: 'test-user-id',
          );

          // Create an orphan instance directly in Firestore without a task schedule
          final orphanInst = TaskInstance(
            id: 'orphan-inst-1',
            scheduleId: 'deleted-schedule-id',
            ruleId: 'deleted-rule-id',
            title: 'Orphan Chore',
            description: '',
            scheduledDate: const CivilDay(year: 2026, month: 6, day: 23),
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
              .doc('test-user-id')
              .collection('instances')
              .doc(orphanInst.id)
              .set(orphanInst.toFirestore());

          // Complete the orphan instance
          final completed = await repository.completeTaskInstance(
            'orphan-inst-1',
          );
          expect(completed, isNotNull);
          expect(completed?.status, 'completed');

          // Verify updated status in Firestore
          final docSnap = await firestore
              .collection('users')
              .doc('test-user-id')
              .collection('instances')
              .doc('orphan-inst-1')
              .get();
          expect(docSnap.data()?['status'], 'completed');

          // Dismiss another orphan instance
          final orphanInst2 = TaskInstance(
            id: 'orphan-inst-2',
            scheduleId: 'deleted-schedule-id',
            ruleId: 'deleted-rule-id',
            title: 'Orphan Chore 2',
            description: '',
            scheduledDate: const CivilDay(year: 2026, month: 6, day: 23),
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
              .doc('test-user-id')
              .collection('instances')
              .doc(orphanInst2.id)
              .set(orphanInst2.toFirestore());

          final dismissed = await repository.dismissTaskInstance(
            'orphan-inst-2',
          );
          expect(dismissed, isNotNull);
          expect(dismissed?.status, 'dismissed');

          final docSnap2 = await firestore
              .collection('users')
              .doc('test-user-id')
              .collection('instances')
              .doc('orphan-inst-2')
              .get();
          expect(docSnap2.data()?['status'], 'dismissed');
        },
      );
    });
  });
}

class FakeUser extends Fake implements User {
  @override
  String get uid => 'test-user-id';
}
