import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/logic/task.dart';
import 'package:nothing_ever_happens/logic/task_delta.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late TaskRepository repository;
  const userId = 'user-1';
  const familyId = 'fam-123';

  setUp(() {
    AppClock.setMockTime(DateTime(2026, 6, 3, 12, 0));
    firestore = FakeFirebaseFirestore();
    repository = TaskRepository(firestore: firestore, userId: userId);
  });

  tearDown(() {
    AppClock.reset();
  });

  test(
    'getTasks merges personal and family collections when in a family',
    () async {
      // 1. Setup user familyId
      await firestore.collection('users').doc(userId).set({
        'familyId': familyId,
      });

      // 2. Add personal task
      final personalTask = Task(
        id: 't-personal',
        title: 'Personal task',
        description: '',
        schedules: [
          OneOffSchedule(
            date: const CivilDay(year: 2026, month: 6, day: 1),
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
        isFamily: false,
      );
      await repository.addTask(personalTask);

      // 3. Add family task
      final familyTask = Task(
        id: 't-family',
        title: 'Family task',
        description: '',
        schedules: [
          OneOffSchedule(
            date: const CivilDay(year: 2026, month: 6, day: 1),
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
        isFamily: true,
      );
      await repository.addTask(familyTask);

      // 4. Verify streams contain both tasks
      final tasksList = await repository.getTasks().first;
      expect(tasksList.length, 2);
      expect(tasksList.any((t) => t.id == 't-personal'), isTrue);
      expect(tasksList.any((t) => t.id == 't-family'), isTrue);
    },
  );

  test('atomic scope migration: Personal -> Family', () async {
    await firestore.collection('users').doc(userId).set({'familyId': familyId});

    // 1. Add personal task
    final task = Task(
      id: 't-migrate',
      title: 'Migrating task',
      description: '',
      schedules: [
        OneOffSchedule(
          date: const CivilDay(year: 2026, month: 6, day: 1),
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
      isFamily: false,
    );
    await repository.addTask(task);

    // Verify it exists in personal tasks collection
    final personalDoc = await firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc('t-migrate')
        .get();
    expect(personalDoc.exists, isTrue);

    // 2. Toggle to Family and save
    final familyTask = Task(
      id: task.id,
      title: task.title,
      description: task.description,
      schedules: task.schedules,
      isFamily: true,
    );
    final delta = TaskDelta(
      id: 'd-1',
      taskId: task.id,
      timestamp: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 90)),
      operation: 'update',
      changedFields: const {'isFamily': true},
      userId: userId,
    );
    await repository.updateTask((newTask: familyTask, delta: delta));

    // Verify it was DELETED from personal tasks
    final personalDocPost = await firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc('t-migrate')
        .get();
    expect(personalDocPost.exists, isFalse);

    // Verify it was CREATED in family tasks
    final familyDocPost = await firestore
        .collection('families')
        .doc(familyId)
        .collection('tasks')
        .doc('t-migrate')
        .get();
    expect(familyDocPost.exists, isTrue);
  });

  test('atomic scope migration: Family -> Personal', () async {
    await firestore.collection('users').doc(userId).set({'familyId': familyId});

    // 1. Add family task
    final task = Task(
      id: 't-migrate',
      title: 'Migrating task',
      description: '',
      schedules: [
        OneOffSchedule(
          date: const CivilDay(year: 2026, month: 6, day: 1),
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
      isFamily: true,
    );
    await repository.addTask(task);

    // Verify it exists in family tasks
    final familyDoc = await firestore
        .collection('families')
        .doc(familyId)
        .collection('tasks')
        .doc('t-migrate')
        .get();
    expect(familyDoc.exists, isTrue);

    // 2. Toggle to Personal and save
    final personalTask = Task(
      id: task.id,
      title: task.title,
      description: task.description,
      schedules: task.schedules,
      isFamily: false,
    );
    final delta = TaskDelta(
      id: 'd-2',
      taskId: task.id,
      timestamp: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 90)),
      operation: 'update',
      changedFields: const {'isFamily': false},
      userId: userId,
    );
    await repository.updateTask((newTask: personalTask, delta: delta));

    // Verify it was DELETED from family tasks
    final familyDocPost = await firestore
        .collection('families')
        .doc(familyId)
        .collection('tasks')
        .doc('t-migrate')
        .get();
    expect(familyDocPost.exists, isFalse);

    // Verify it was CREATED in personal tasks
    final personalDocPost = await firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc('t-migrate')
        .get();
    expect(personalDocPost.exists, isTrue);
  });

  test('getHistory merges personal and family delta history streams', () async {
    // 1. Setup user familyId
    await firestore.collection('users').doc(userId).set({'familyId': familyId});

    // 2. Add personal history
    final personalDelta = TaskDelta(
      id: 'pd-1',
      taskId: 't-1',
      timestamp: DateTime(2026, 6, 1, 10, 0),
      expiresAt: DateTime(2026, 9, 1, 10, 0),
      operation: 'create',
      changedFields: const {},
      userId: userId,
    );
    await firestore
        .collection('users')
        .doc(userId)
        .collection('history')
        .doc('pd-1')
        .set(personalDelta.toJson());

    // 3. Add family history
    final familyDelta = TaskDelta(
      id: 'fd-1',
      taskId: 't-2',
      timestamp: DateTime(2026, 6, 2, 10, 0),
      expiresAt: DateTime(2026, 9, 2, 10, 0),
      operation: 'create',
      changedFields: const {},
      userId: userId,
    );
    await firestore
        .collection('families')
        .doc(familyId)
        .collection('history')
        .doc('fd-1')
        .set(familyDelta.toJson());

    // 4. Verify streams contain both deltas sorted descending
    final historyList = await repository.getHistory().first;
    expect(historyList.length, 2);
    expect(historyList[0].id, 'fd-1'); // newer timestamp
    expect(historyList[1].id, 'pd-1');
  });
}
