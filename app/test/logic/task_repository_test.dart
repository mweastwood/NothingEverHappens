import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/task.dart';
import 'package:nothing_ever_happens/logic/task_delta.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';

void main() {
  group('TaskRepository', () {
    late FakeFirebaseFirestore firestore;
    late TaskRepository repository;
    const userId = 'test-user-id';

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = TaskRepository(firestore: firestore, userId: userId);
    });

    final testTask = Task(
      id: 'task-1',
      title: 'Test Task',
      description: 'Test Description',
      startRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 9, minute: 0),
      ),
      dueRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 17, minute: 0),
      ),
      schedule: OneOffSchedule(
        date: const CivilDay(year: 2024, month: 1, day: 1),
      ),
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
          isA<List<Task>>().having(
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
}
