import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
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
    addTearDown(AppClock.reset);
    firestore = FakeFirebaseFirestore();
    repository = TaskRepository(firestore: firestore, userId: userId);
  });

  tearDown(() {});

  test(
    'getTasks merges personal and family collections when in a family',
    () async {
      // 1. Setup user familyId
      await firestore.collection('users').doc(userId).set({
        'familyId': familyId,
      });

      // 2. Add personal task
      final personalTask = TaskSchedule(
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
      await repository.addTaskSchedule(personalTask);

      // 3. Add family task
      final familyTask = TaskSchedule(
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
      await repository.addTaskSchedule(familyTask);

      // 4. Verify streams contain both tasks
      final tasksList = await repository.getTasks().first;
      expect(tasksList.length, 2);
      expect(tasksList.any((t) => t.id == 'S-t-personal'), isTrue);
      expect(tasksList.any((t) => t.id == 'S-t-family'), isTrue);
    },
  );

  test('atomic scope migration: Personal -> Family', () async {
    await firestore.collection('users').doc(userId).set({'familyId': familyId});

    // 1. Add personal task
    final task = TaskSchedule(
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
    await repository.addTaskSchedule(task);
    await Future.delayed(Duration.zero);

    // Verify it exists in personal tasks collection
    final personalDoc = await firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc(task.id)
        .get();
    expect(personalDoc.exists, isTrue);

    // Verify it exists in personal instances
    final personalInstances = await firestore
        .collection('users')
        .doc(userId)
        .collection('instances')
        .get();
    expect(
      personalInstances.docs.any((d) => d.data()['scheduleId'] == task.id),
      isTrue,
    );

    // 2. Toggle to Family and save
    final familyTask = TaskSchedule(
      id: task.id,
      title: task.title,
      description: task.description,
      schedules: task.schedules,
      isFamily: true,
    );
    await repository.updateTaskSchedule((
      newTask: familyTask,
      changes: const {'isFamily': true},
    ));

    // Verify it was DELETED from personal tasks
    final personalDocPost = await firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc(task.id)
        .get();
    expect(personalDocPost.exists, isFalse);

    // Verify it was DELETED from personal instances
    final personalInstancesPost = await firestore
        .collection('users')
        .doc(userId)
        .collection('instances')
        .get();
    expect(
      personalInstancesPost.docs.any((d) => d.data()['scheduleId'] == task.id),
      isFalse,
    );

    // Verify it was CREATED in family tasks
    final familyDocPost = await firestore
        .collection('families')
        .doc(familyId)
        .collection('tasks')
        .doc(task.id)
        .get();
    expect(familyDocPost.exists, isTrue);

    // Verify it was CREATED in family instances
    final familyInstancesPost = await firestore
        .collection('families')
        .doc(familyId)
        .collection('instances')
        .get();
    expect(
      familyInstancesPost.docs.any((d) => d.data()['scheduleId'] == task.id),
      isTrue,
    );
  });

  test('atomic scope migration: Family -> Personal', () async {
    await firestore.collection('users').doc(userId).set({'familyId': familyId});

    // 1. Add family task
    final task = TaskSchedule(
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
    await repository.addTaskSchedule(task);
    await Future.delayed(Duration.zero);

    // Verify it exists in family tasks
    final familyDoc = await firestore
        .collection('families')
        .doc(familyId)
        .collection('tasks')
        .doc(task.id)
        .get();
    expect(familyDoc.exists, isTrue);

    // Verify it exists in family instances
    final familyInstances = await firestore
        .collection('families')
        .doc(familyId)
        .collection('instances')
        .get();
    expect(
      familyInstances.docs.any((d) => d.data()['scheduleId'] == task.id),
      isTrue,
    );

    // 2. Toggle to Personal and save
    final personalTask = TaskSchedule(
      id: task.id,
      title: task.title,
      description: task.description,
      schedules: task.schedules,
      isFamily: false,
    );
    await repository.updateTaskSchedule((
      newTask: personalTask,
      changes: const {'isFamily': false},
    ));

    // Verify it was DELETED from family tasks
    final familyDocPost = await firestore
        .collection('families')
        .doc(familyId)
        .collection('tasks')
        .doc(task.id)
        .get();
    expect(familyDocPost.exists, isFalse);

    // Verify it was DELETED from family instances
    final familyInstancesPost = await firestore
        .collection('families')
        .doc(familyId)
        .collection('instances')
        .get();
    expect(
      familyInstancesPost.docs.any((d) => d.data()['scheduleId'] == task.id),
      isFalse,
    );

    // Verify it was CREATED in personal tasks
    final personalDocPost = await firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc(task.id)
        .get();
    expect(personalDocPost.exists, isTrue);

    // Verify it was CREATED in personal instances
    final personalInstancesPost = await firestore
        .collection('users')
        .doc(userId)
        .collection('instances')
        .get();
    expect(
      personalInstancesPost.docs.any((d) => d.data()['scheduleId'] == task.id),
      isTrue,
    );
  });
}
