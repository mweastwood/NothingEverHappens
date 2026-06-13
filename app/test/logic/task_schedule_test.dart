import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_list.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  group('TaskSchedule Properties', () {
    test('isOverdue checks dueFromMidnight correctly', () {
      const todayCivil = CivilDay(year: 2024, month: 1, day: 1);
      final task = TaskSchedule(
        id: '1',
        title: 'Test',
        description: 'Test',
        schedules: [
          OneOffSchedule(
            date: todayCivil,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 0, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 12, minute: 0),
            ),
          ),
        ],
      );

      // 10:00 AM
      expect(task.isOverdue(DateTime(2024, 1, 1, 10, 0)), isFalse);
      // 13:00 PM
      expect(task.isOverdue(DateTime(2024, 1, 1, 13, 0)), isTrue);
    });

    test(
      'toFirestore and fromFirestore serialize multiple schedules correctly',
      () {
        final task = TaskSchedule(
          id: 'task-test',
          title: 'Multi TaskSchedule',
          description: 'Desc',
          schedules: [
            DailySchedule(
              startDate: const CivilDay(year: 2026, month: 3, day: 8),
              interval: 1,
              startRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 8, minute: 0),
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 9, minute: 0),
              ),
            ),
            DailySchedule(
              startDate: const CivilDay(year: 2026, month: 3, day: 8),
              interval: 1,
              startRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 20, minute: 0),
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 21, minute: 0),
              ),
            ),
          ],
          activeOccurrenceIndex: 1,
        );

        final map = task.toFirestore();
        expect(map['schedules'], isA<List>());
        expect(map['schedules'].length, 2);
        expect(map['schedules'][0]['type'], 'daily');
        expect(map['activeOccurrenceIndex'], 1);
      },
    );

    test('serializes and deserializes estimatedDuration correctly', () async {
      final task = TaskSchedule(
        id: 'task-duration-test',
        title: 'TaskSchedule with duration',
        description: 'Desc',
        schedules: [
          OneOffSchedule(
            date: const CivilDay(year: 2026, month: 3, day: 8),
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
        estimatedDuration: const Duration(minutes: 45),
      );

      final map = task.toFirestore();
      expect(map['estimatedDuration'], 45);

      final firestore = FakeFirebaseFirestore();
      await firestore.collection('tasks').doc('task-duration-test').set(map);
      final snapshot = await firestore
          .collection('tasks')
          .doc('task-duration-test')
          .get();
      final deserialized = TaskSchedule.fromFirestore(snapshot);

      expect(deserialized.id, 'task-duration-test');
      expect(deserialized.estimatedDuration, const Duration(minutes: 45));
    });

    test('deserializes null estimatedDuration correctly', () async {
      final task = TaskSchedule(
        id: 'task-no-duration',
        title: 'TaskSchedule without duration',
        description: 'Desc',
        schedules: [
          OneOffSchedule(
            date: const CivilDay(year: 2026, month: 3, day: 8),
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

      final map = task.toFirestore();
      expect(map.containsKey('estimatedDuration'), true);
      expect(map['estimatedDuration'], isNull);

      final firestore = FakeFirebaseFirestore();
      await firestore.collection('tasks').doc('task-no-duration').set(map);
      final snapshot = await firestore
          .collection('tasks')
          .doc('task-no-duration')
          .get();
      final deserialized = TaskSchedule.fromFirestore(snapshot);

      expect(deserialized.estimatedDuration, isNull);
    });

    test('serializes and deserializes new Agile fields correctly', () async {
      final task = TaskSchedule(
        id: 'task-agile-test',
        title: 'Agile TaskSchedule',
        description: 'Desc',
        schedules: [
          OneOffSchedule(
            date: const CivilDay(year: 2026, month: 3, day: 8),
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
        priority: TaskPriority.high,
        cycleId: '2026-W23',
        preferredBy: const {'user-1': true, 'user-2': false},
        assignedUserId: 'user-1',
      );

      final map = task.toFirestore();
      expect(map['isFamily'], true);
      expect(map['priority'], 'high');
      expect(map['cycleId'], '2026-W23');
      expect(map['preferredBy']['user-1'], true);
      expect(map['preferredBy']['user-2'], false);
      expect(map['assignedUserId'], 'user-1');

      final firestore = FakeFirebaseFirestore();
      await firestore.collection('tasks').doc('task-agile-test').set(map);
      final snapshot = await firestore
          .collection('tasks')
          .doc('task-agile-test')
          .get();
      final deserialized = TaskSchedule.fromFirestore(snapshot);

      expect(deserialized.id, 'task-agile-test');
      expect(deserialized.isFamily, true);
      expect(deserialized.priority, TaskPriority.high);
      expect(deserialized.cycleId, '2026-W23');
      expect(deserialized.preferredBy['user-1'], true);
      expect(deserialized.preferredBy['user-2'], false);
      expect(deserialized.assignedUserId, 'user-1');
    });
  });

  group('TaskSchedule Editing and Delta Aggregation', () {
    test(
      'TaskSchedule.edit() returns correctly updated task and delta with only changes',
      () {
        final task = TaskSchedule(
          id: 'edit-test-task',
          title: 'Initial Title',
          description: 'Initial Desc',
          schedules: [
            OneOffSchedule(
              date: const CivilDay(year: 2026, month: 3, day: 8),
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
          estimatedDuration: const Duration(minutes: 30),
        );

        final result = task.edit(
          newTitle: 'Updated Title',
          newDescription: 'Initial Desc', // unchanged
          newSchedules: [
            OneOffSchedule(
              date: const CivilDay(year: 2026, month: 3, day: 9),
              startRelativeTime: const RelativeTime(
                dayOffset: -1,
                time: TimeOfDay(hour: 10, minute: 0),
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 18, minute: 0),
              ),
            ),
          ],
          newEstimatedDuration: null, // cleared
          userId: 'test-user-id',
          newMissedPolicy: MissedPolicy.rollover,
          newIsMaster: false,
          newLastSpawnedDate: null,
          newIsFamily: true,
          newPriority: TaskPriority.high,
        );

        final newTask = result.newTask;
        final delta = result.delta;

        // 1. Verify updated TaskSchedule properties
        expect(newTask.id, 'edit-test-task');
        expect(newTask.title, 'Updated Title');
        expect(newTask.description, 'Initial Desc');
        expect(newTask.schedules.first.startRelativeTime.dayOffset, -1);
        expect(newTask.schedules.first.startRelativeTime.time.hour, 10);
        expect(newTask.schedules.first.dueRelativeTime.time.hour, 18);
        expect(newTask.schedules.first, isA<OneOffSchedule>());
        expect((newTask.schedules.first as OneOffSchedule).date.day, 9);
        expect(newTask.estimatedDuration, isNull);
        expect(newTask.isFamily, isTrue);
        expect(newTask.priority, TaskPriority.high);

        // 2. Verify Delta properties and changedFields
        expect(delta.taskId, 'edit-test-task');
        expect(delta.operation, 'update');
        expect(delta.userId, 'test-user-id');

        final changes = delta.changedFields;
        expect(changes['title'], 'Updated Title');
        expect(
          changes.containsKey('description'),
          isFalse,
        ); // description didn't change
        expect(changes['schedules'][0]['startRelativeTime']['dayOffset'], -1);
        expect(changes['schedules'][0]['startRelativeTime']['hour'], 10);
        expect(changes['schedules'][0]['dueRelativeTime']['hour'], 18);
        expect(changes['schedules'][0]['date']['day'], 9);
        expect(changes['estimatedDuration'], isNull);
        expect(changes['isFamily'], isTrue);
        expect(changes['priority'], 'high');
      },
    );

    test(
      'updateCycleId modifies cycleId and generates correct update delta',
      () {
        final task = TaskSchedule(
          id: 't1',
          title: 'TaskSchedule 1',
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
        );

        final result = task.updateCycleId('2026-W23', 'user1');
        expect(result.newTask.cycleId, '2026-W23');
        expect(result.delta.taskId, 't1');
        expect(result.delta.operation, 'update');
        expect(result.delta.changedFields['cycleId'], '2026-W23');

        // Test clearing cycleId
        final resultClear = result.newTask.updateCycleId(null, 'user1');
        expect(resultClear.newTask.cycleId, isNull);
        expect(resultClear.delta.changedFields['cycleId'], isNull);
      },
    );

    test(
      'updateAssignedUserId modifies assignedUserId and generates correct update delta',
      () {
        final task = TaskSchedule(
          id: 't1',
          title: 'TaskSchedule 1',
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
        );

        final result = task.updateAssignedUserId('user2', 'user1');
        expect(result.newTask.assignedUserId, 'user2');
        expect(result.delta.taskId, 't1');
        expect(result.delta.operation, 'update');
        expect(result.delta.changedFields['assignedUserId'], 'user2');

        // Test clearing assignedUserId
        final resultClear = result.newTask.updateAssignedUserId(null, 'user1');
        expect(resultClear.newTask.assignedUserId, isNull);
        expect(resultClear.delta.changedFields['assignedUserId'], isNull);
      },
    );

    test(
      'updatePreferredBy modifies preferredBy map and generates correct update delta',
      () {
        final task = TaskSchedule(
          id: 't1',
          title: 'TaskSchedule 1',
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
        );

        final result = task.updatePreferredBy(const {'user2': true}, 'user1');
        expect(result.newTask.preferredBy['user2'], isTrue);
        expect(result.delta.taskId, 't1');
        expect(result.delta.operation, 'update');
        expect(result.delta.changedFields['preferredBy']['user2'], isTrue);
      },
    );
  });

  group('Missed Occurrence Policies Strategy Unit Tests', () {
    test(
      '1. Rollover (Push to Next Day): Overdue Monday task completed on Tuesday reschedules to Tuesday (original path)',
      () {
        // Create a daily task scheduled for Monday
        final monday = const CivilDay(year: 2026, month: 5, day: 25);
        final task = TaskSchedule(
          id: 'rollover-task',
          title: 'Water Plants',
          description: 'Every day',
          schedules: [
            DailySchedule(
              startDate: monday,
              interval: 1,
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
          missedPolicy: MissedPolicy.rollover,
        );

        // Verify that on Tuesday, it is overdue
        final tuesdayDateTime = DateTime(2026, 5, 26, 10, 0);
        expect(task.isOverdue(tuesdayDateTime), isTrue);

        // Simulate completion on Tuesday
        final state = TaskList([task]).complete('rollover-task', 'user-1');

        // The next occurrence should continue from its original path (strictly after Monday -> Tuesday)
        final completedTask = state.activeTasks.firstWhere(
          (t) => t.id == 'rollover-task',
        );
        expect(
          completedTask.schedules.first.scheduledDate,
          const CivilDay(year: 2026, month: 5, day: 26),
        );
      },
    );

    test(
      '2. Shift Schedule (Push Out Future Dates): Bi-daily Monday task completed late on Wednesday shifts next date to Friday (Wednesday + 2 days)',
      () {
        // Create a bi-daily task scheduled for Monday
        final monday = const CivilDay(year: 2026, month: 5, day: 25);
        final task = TaskSchedule(
          id: 'shift-task',
          title: 'Mow the Lawn',
          description: 'Every 2 days',
          schedules: [
            DailySchedule(
              startDate: monday,
              interval: 2,
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
          missedPolicy: MissedPolicy.shift,
        );

        // Verify that on Wednesday, it is overdue
        final wednesdayDateTime = DateTime(2026, 5, 27, 10, 0);
        expect(task.isOverdue(wednesdayDateTime), isTrue);

        // Simulate completion on Wednesday
        AppClock.setMockTime(wednesdayDateTime);
        final state = TaskList([task]).complete('shift-task', 'user-1');
        AppClock.reset();

        // The next occurrence should shift relative to completion date (strictly after Wednesday -> Friday)
        final completedTask = state.activeTasks.firstWhere(
          (t) => t.id == 'shift-task',
        );
        expect(
          completedTask.schedules.first.scheduledDate,
          const CivilDay(year: 2026, month: 5, day: 29),
        );
      },
    );

    test(
      '3. Skip (Drop Occurrence): Overdue Monday task is automatically skipped/expired and rescheduled to next calendar occurrence',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repository = TaskRepository(
          firestore: firestore,
          userId: 'user-1',
        );

        // Create a daily task scheduled for Monday
        final monday = const CivilDay(year: 2026, month: 5, day: 25);
        final task = TaskSchedule(
          id: 'skip-task',
          title: 'Take out trash',
          description: 'Every day',
          schedules: [
            DailySchedule(
              startDate: monday,
              interval: 1,
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
          missedPolicy: MissedPolicy.skip,
        );

        // Set mock clock to Monday
        final mondayDateTime = DateTime(2026, 5, 25, 10, 0);
        AppClock.setMockTime(mondayDateTime);

        // Save to database
        await repository.addTask(task);
        await Future.delayed(Duration.zero);

        // Set AppClock to Tuesday 10:00 AM - past due time of Monday (17:00), but before Tuesday (17:00)
        final tuesdayDateTime = DateTime(2026, 5, 26, 10, 0);
        AppClock.setMockTime(tuesdayDateTime);

        // Get tasks stream and wait for auto-process check to trigger
        await repository.getTasks().first;

        // Let's yield to background tasks so Firestore batch completes
        await Future.delayed(Duration.zero);

        // Fetch the Monday instance
        final mondayInstSnap = await firestore
            .collection('users')
            .doc('user-1')
            .collection('instances')
            .doc('skip-task_2026-05-25')
            .get();
        expect(mondayInstSnap.exists, isTrue);
        expect(mondayInstSnap.data()!['status'], 'skipped');

        // Fetch the Tuesday instance
        final tuesdayInstSnap = await firestore
            .collection('users')
            .doc('user-1')
            .collection('instances')
            .doc('skip-task_2026-05-26')
            .get();
        expect(tuesdayInstSnap.exists, isTrue);
        expect(tuesdayInstSnap.data()!['status'], 'pending');

        // Verify that skipped was logged in history
        final historySnap = await firestore
            .collection('users')
            .doc('user-1')
            .collection('history')
            .get();
        expect(historySnap.docs.length, 2); // 1 create + 1 skipped
        expect(
          historySnap.docs.any((doc) => doc.data()['operation'] == 'skipped'),
          isTrue,
        );

        AppClock.reset();
      },
    );

    test('Skip policy on mixed task drops passed one-off schedules', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = TaskRepository(firestore: firestore, userId: 'user-1');

      final monday = const CivilDay(year: 2026, month: 5, day: 25);

      final mixedTask = TaskSchedule(
        id: 'mixed-skip-task',
        title: 'Mixed skip task',
        description: 'Testing skip policy on mixed task',
        schedules: [
          OneOffSchedule(
            date: monday,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
          ),
          DailySchedule(
            startDate: monday,
            interval: 1,
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
        missedPolicy: MissedPolicy.skip,
      );

      // Set mock clock to Monday
      final mondayDateTime = DateTime(2026, 5, 25, 10, 0);
      AppClock.setMockTime(mondayDateTime);

      await repository.addTask(mixedTask);
      await Future.delayed(Duration.zero);

      final tuesdayDateTime = DateTime(2026, 5, 26, 10, 0);
      AppClock.setMockTime(tuesdayDateTime);

      await repository.getTasks().first;
      await Future.delayed(Duration.zero);

      final mondayOneOffSnap = await firestore
          .collection('users')
          .doc('user-1')
          .collection('instances')
          .doc('mixed-skip-task_2026-05-25_0')
          .get();
      expect(mondayOneOffSnap.exists, isTrue);
      expect(mondayOneOffSnap.data()!['status'], 'skipped');

      final mondayDailySnap = await firestore
          .collection('users')
          .doc('user-1')
          .collection('instances')
          .doc('mixed-skip-task_2026-05-25_1')
          .get();
      expect(mondayDailySnap.exists, isTrue);
      expect(mondayDailySnap.data()!['status'], 'skipped');

      final tuesdayDailySnap = await firestore
          .collection('users')
          .doc('user-1')
          .collection('instances')
          .doc('mixed-skip-task_2026-05-26_1')
          .get();
      expect(tuesdayDailySnap.exists, isTrue);
      expect(tuesdayDailySnap.data()!['status'], 'pending');

      AppClock.reset();
    });

    test(
      '4. Stack/Overlap (Allow Concurrency): Master task missed for Monday and Tuesday spawns separate cards on Wednesday',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repository = TaskRepository(
          firestore: firestore,
          userId: 'user-1',
        );

        // Create a daily master task scheduled for Monday
        final monday = const CivilDay(year: 2026, month: 5, day: 25);
        final task = TaskSchedule(
          id: 'stack-task',
          title: 'Read a book',
          description: 'Every day',
          schedules: [
            DailySchedule(
              startDate: monday,
              interval: 1,
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
          missedPolicy: MissedPolicy.stack,
          isMaster: true,
        );

        // Set mock clock to Monday
        final mondayDateTime = DateTime(2026, 5, 25, 10, 0);
        AppClock.setMockTime(mondayDateTime);

        // Save master task to database
        await repository.addTask(task);
        await Future.delayed(Duration.zero);

        // Set AppClock to Wednesday (May 27)
        final wednesdayDateTime = DateTime(2026, 5, 27, 10, 0);
        AppClock.setMockTime(wednesdayDateTime);

        // Fetch tasks list (triggers spawning check in getTasks stream)
        await repository.getTasks().first;
        await Future.delayed(Duration.zero);

        // Query active instances in Firestore
        final instancesSnap = await firestore
            .collection('users')
            .doc('user-1')
            .collection('instances')
            .get();
        final allInstances = instancesSnap.docs
            .map((doc) => TaskInstance.fromFirestore(doc))
            .toList();

        // We should have 3 spawned active instances (Monday, Tuesday, Wednesday)
        expect(allInstances.length, 3);

        expect(
          allInstances.any((t) => t.id == 'stack-task_2026-05-25'),
          isTrue,
        );
        expect(
          allInstances.any((t) => t.id == 'stack-task_2026-05-26'),
          isTrue,
        );
        expect(
          allInstances.any((t) => t.id == 'stack-task_2026-05-27'),
          isTrue,
        );

        // Verify master task lastSpawnedDate is updated to Wednesday
        final masterTaskDoc = await firestore
            .collection('users')
            .doc('user-1')
            .collection('tasks')
            .doc('stack-task')
            .get();
        final updatedMaster = TaskSchedule.fromFirestore(masterTaskDoc);
        expect(
          updatedMaster.lastSpawnedDate,
          const CivilDay(year: 2026, month: 5, day: 27),
        );

        AppClock.reset();
      },
    );
  });
}
