import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_delta.dart';
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

    test('addTask adds a task and history to Firestore', () async {
      await repository.addTask(testTask);

      final taskSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc(testTask.id)
          .get();

      expect(taskSnapshot.exists, isTrue);
      final data = taskSnapshot.data()!;
      expect(data['title'], testTask.title);

      final historySnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('history')
          .get();

      expect(historySnapshot.docs.length, 1);
      expect(historySnapshot.docs.first.data()['operation'], 'create');
    });

    test('getTasks returns a stream of tasks', () async {
      await repository.addTask(testTask);

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

    test('getHistory returns a stream of history', () async {
      await repository.addTask(testTask);

      final stream = repository.getHistory();

      expect(
        stream,
        emits(
          isA<List<TaskDelta>>().having(
            (list) => list.first.operation,
            'operation',
            'create',
          ),
        ),
      );
    });

    test('updateTask updates an existing task and adds history', () async {
      await repository.addTask(testTask);

      final modification = testTask.updateTitle('Updated Title', userId);
      await repository.updateTask(modification);

      final taskSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc(testTask.id)
          .get();

      expect(taskSnapshot.data()!['title'], 'Updated Title');

      final historySnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('history')
          .get();

      // 1 from add, 1 from update
      expect(historySnapshot.docs.length, 2);
      expect(historySnapshot.docs.last.data()['operation'], 'update');
      expect(
        historySnapshot.docs.last.data()['changedFields']['title'],
        'Updated Title',
      );
    });

    test('deleteTask removes a task and adds history', () async {
      await repository.addTask(testTask);

      await repository.deleteTask(testTask.id);

      final taskSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc(testTask.id)
          .get();

      expect(taskSnapshot.exists, isFalse);

      final historySnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('history')
          .get();

      // 1 from add, 1 from delete
      expect(historySnapshot.docs.length, 2);
      expect(historySnapshot.docs.last.data()['operation'], 'delete');
    });

    test('completeTask completes the instance and adds history', () async {
      await repository.addTask(testTask);
      await Future.delayed(Duration.zero);

      final instanceId = '${testTask.id}_2024-01-01';
      await repository.completeTask(instanceId);

      final instanceSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('instances')
          .doc(instanceId)
          .get();

      expect(instanceSnapshot.exists, isTrue);
      expect(instanceSnapshot.data()!['status'], 'completed');

      final historySnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('history')
          .get();

      // 1 from add, 1 from complete
      expect(historySnapshot.docs.length, 2);
      expect(historySnapshot.docs.last.data()['operation'], 'completed');
    });

    test(
      'editing weekly schedule to add monthly schedule does not duplicate or timeout',
      () async {
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

        await repository.addTask(weeklyTask);
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
          userId: userId,
          newMissedPolicy: MissedPolicy.rollover,
          newIsMaster: false,
          newLastSpawnedDate: null,
          newIsFamily: false,
          newPriority: TaskPriority.medium,
        );

        await repository.updateTask(modification);
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
          notificationRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 8, minute: 45),
          ),
        ),
      ],
    );

    test('addTask schedules notifications', () async {
      await repository.addTask(notifTask);
      expect(
        notificationService.scheduledTasks.containsKey(notifTask.id),
        isTrue,
      );
      expect(
        notificationService
            .scheduledTasks[notifTask.id]!
            .schedules
            .first
            .notificationRelativeTime
            ?.time,
        equals(const TimeOfDay(hour: 8, minute: 45)),
      );
    });

    test('updateTask updates scheduled notifications', () async {
      await repository.addTask(notifTask);

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
            notificationRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 8, minute: 30),
            ),
          ),
        ],
      );

      final modification = (
        newTask: updatedTask,
        delta: TaskDelta(
          id: 'delta-1',
          taskId: notifTask.id,
          timestamp: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 90)),
          operation: 'update',
          changedFields: {
            'schedules': updatedTask.schedules.map((s) => s.toJson()).toList(),
          },
          userId: userId,
        ),
      );

      await repository.updateTask(modification);
      expect(
        notificationService.scheduledTasks.containsKey(notifTask.id),
        isTrue,
      );
      expect(
        notificationService
            .scheduledTasks[notifTask.id]!
            .schedules
            .first
            .notificationRelativeTime
            ?.time,
        equals(const TimeOfDay(hour: 8, minute: 30)),
      );
    });

    test('deleteTask cancels scheduled notifications', () async {
      await repository.addTask(notifTask);
      expect(
        notificationService.scheduledTasks.containsKey(notifTask.id),
        isTrue,
      );

      await repository.deleteTask(notifTask.id);
      expect(
        notificationService.scheduledTasks.containsKey(notifTask.id),
        isFalse,
      );
    });

    test('completeTask schedules next occurrence if recurring', () async {
      await repository.addTask(notifTask);
      expect(
        notificationService.scheduledTasks.containsKey(notifTask.id),
        isTrue,
      );

      final instanceId = '${notifTask.id}_2024-01-01';
      await repository.completeTask(instanceId);
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

        await repository.addTask(shiftTask);
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
        await repository.completeTask(instanceId);

        // Verify June 1 instance is completed
        final completedSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(instanceId)
            .get();
        expect(completedSnapshot.data()!['status'], 'completed');

        // Shift policy reschedules relative to completion date (June 9) -> June 10
        final nextInstanceId = '${shiftTask.id}_2026-06-10';
        final nextSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(nextInstanceId)
            .get();
        expect(nextSnapshot.exists, isTrue);
        expect(nextSnapshot.data()!['status'], 'pending');

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

        await repository.addTask(stackTask);
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
        await repository.completeTask(instanceId);

        // Verify June 1 instance is completed
        final completedSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(instanceId)
            .get();
        expect(completedSnapshot.data()!['status'], 'completed');

        // Stack policy reschedules relative to scheduledDate (June 1) -> June 2
        final nextInstanceId = '${stackTask.id}_2026-06-02';
        final nextSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc(nextInstanceId)
            .get();
        expect(nextSnapshot.exists, isTrue);
        expect(nextSnapshot.data()!['status'], 'pending');

        AppClock.reset();
      },
    );
  });
}
