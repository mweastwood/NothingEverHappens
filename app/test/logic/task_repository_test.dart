import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/task.dart';
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

    test('addTask adds a task to Firestore', () async {
      await repository.addTask(testTask);

      final snapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc(testTask.id)
          .get();

      expect(snapshot.exists, isTrue);
      final data = snapshot.data()!;
      expect(data['title'], testTask.title);
      expect(data['description'], testTask.description);
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

    test('updateTask updates an existing task', () async {
      await repository.addTask(testTask);

      final updatedTask = Task(
        id: testTask.id,
        title: 'Updated Title',
        description: testTask.description,
        startRelativeTime: testTask.startRelativeTime,
        dueRelativeTime: testTask.dueRelativeTime,
        schedule: testTask.schedule,
      );

      await repository.updateTask(updatedTask);

      final snapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc(testTask.id)
          .get();

      expect(snapshot.data()!['title'], 'Updated Title');
    });

    test('deleteTask removes a task', () async {
      await repository.addTask(testTask);

      await repository.deleteTask(testTask.id);

      final snapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc(testTask.id)
          .get();

      expect(snapshot.exists, isFalse);
    });
  });
}
