import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_delta.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
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

    test('completeTask removes a task and adds history', () async {
      await repository.addTask(testTask);

      await repository.completeTask(testTask.id);

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

      // 1 from add, 1 from complete
      expect(historySnapshot.docs.length, 2);
      expect(historySnapshot.docs.last.data()['operation'], 'complete');
    });
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

      await repository.completeTask(notifTask.id);
      // Still scheduled because it's recurring and advances to the next occurrence
      expect(
        notificationService.scheduledTasks.containsKey(notifTask.id),
        isTrue,
      );
    });
  });
}
