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

  group('Exhaustive Task Scheduling Combinations & Missed Policies Thorough Tests', () {
    const userId = 'user-1';

    test(
      '1. TaskList.complete on mixed Daily (interval 2) and Weekly (Mon, Wed) schedules',
      () {
        final start = const CivilDay(year: 2026, month: 6, day: 1); // Monday
        final schedules = [
          DailySchedule(
            startDate: start,
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
          WeeklySchedule(
            startDate: start,
            interval: 1,
            daysOfWeek: const {1, 3}, // Mon, Wed
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 10, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 18, minute: 0),
            ),
          ),
        ];

        final task = TaskSchedule(
          id: 'mixed-daily-weekly',
          title: 'Daily + Weekly Task',
          description: 'Test',
          schedules: schedules,
          missedPolicy: MissedPolicy.rollover,
        );

        final taskList = TaskList([task]);

        // Complete on Monday, June 1 (Both Daily and Weekly occur)
        AppClock.setMockTime(DateTime(2026, 6, 1, 12, 0));
        var state = taskList.complete('mixed-daily-weekly', userId);
        var updated = state.activeTasks.first;

        // Daily advances to Wednesday, June 3
        expect(
          (updated.schedules[0] as DailySchedule).startDate,
          const CivilDay(year: 2026, month: 6, day: 3),
        );
        // Weekly advances to Wednesday, June 3
        expect(
          (updated.schedules[1] as WeeklySchedule).startDate,
          const CivilDay(year: 2026, month: 6, day: 3),
        );

        // Complete on Tuesday, June 2 (Neither occurs)
        AppClock.setMockTime(DateTime(2026, 6, 2, 12, 0));
        state = state.complete('mixed-daily-weekly', userId);
        updated = state.activeTasks.first;

        // No changes since neither was scheduled for June 2 (or before)
        expect(
          (updated.schedules[0] as DailySchedule).startDate,
          const CivilDay(year: 2026, month: 6, day: 3),
        );
        expect(
          (updated.schedules[1] as WeeklySchedule).startDate,
          const CivilDay(year: 2026, month: 6, day: 3),
        );

        // Complete on Wednesday, June 3 (Both occur)
        AppClock.setMockTime(DateTime(2026, 6, 3, 12, 0));
        state = state.complete('mixed-daily-weekly', userId);
        updated = state.activeTasks.first;

        // Daily advances to Friday, June 5
        expect(
          (updated.schedules[0] as DailySchedule).startDate,
          const CivilDay(year: 2026, month: 6, day: 5),
        );
        // Weekly advances to Monday, June 8 (since weekdays = {1, 3}, Wed -> Mon)
        expect(
          (updated.schedules[1] as WeeklySchedule).startDate,
          const CivilDay(year: 2026, month: 6, day: 8),
        );

        AppClock.reset();
      },
    );

    test(
      '2. TaskList.complete on mixed Daily (interval 3) and Monthly (dayOfMonth 15) under Shift policy',
      () {
        final start = const CivilDay(year: 2026, month: 6, day: 1); // Monday
        final schedules = [
          DailySchedule(
            startDate: start,
            interval: 3,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
          ),
          MonthlySchedule(
            startDate: start,
            interval: 1,
            dayOfMonth: 15,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 10, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 18, minute: 0),
            ),
          ),
        ];

        final task = TaskSchedule(
          id: 'mixed-daily-monthly-shift',
          title: 'Daily + Monthly Shift',
          description: 'Test',
          schedules: schedules,
          missedPolicy: MissedPolicy.shift,
        );

        final taskList = TaskList([task]);

        // Overdue complete on Tuesday, June 9 (Daily was due June 1, 4, 7. Monthly is due June 15)
        AppClock.setMockTime(DateTime(2026, 6, 9, 12, 0));
        final state = taskList.complete('mixed-daily-monthly-shift', userId);
        final updated = state.activeTasks.first;

        // Daily should shift to next occurrence after June 9: June 10 (since 1 + 3*3 = 10)
        expect(
          (updated.schedules[0] as DailySchedule).startDate,
          const CivilDay(year: 2026, month: 6, day: 10),
        );
        // Monthly should remain on June 15 (future)
        expect(
          (updated.schedules[1] as MonthlySchedule).startDate,
          const CivilDay(year: 2026, month: 6, day: 15),
        );

        AppClock.reset();
      },
    );

    test(
      '3. TaskList.complete on mixed Weekly (Fri) and Yearly (Dec 25) under Rollover policy',
      () {
        final start = const CivilDay(year: 2026, month: 6, day: 1);
        final schedules = [
          WeeklySchedule(
            startDate: start,
            interval: 1,
            daysOfWeek: const {5}, // Friday
          ),
          YearlySchedule(startDate: start, interval: 1, month: 12, day: 25),
        ];

        final task = TaskSchedule(
          id: 'mixed-weekly-yearly-rollover',
          title: 'Weekly + Yearly Rollover',
          description: 'Test',
          schedules: schedules,
          missedPolicy: MissedPolicy.rollover,
        );

        final taskList = TaskList([task]);

        // Complete on Friday, Dec 25, 2026 (Both Weekly and Yearly occur!)
        // Dec 25, 2026 is indeed a Friday.
        AppClock.setMockTime(DateTime(2026, 12, 25, 12, 0));
        final state = taskList.complete('mixed-weekly-yearly-rollover', userId);
        final updated = state.activeTasks.first;

        // Weekly advances to June 5, 2026 (first Friday after June 1)
        expect(
          (updated.schedules[0] as WeeklySchedule).startDate,
          const CivilDay(year: 2026, month: 6, day: 5),
        );
        // Yearly advances to Dec 25, 2026 (first Dec 25 after June 1)
        expect(
          (updated.schedules[1] as YearlySchedule).startDate,
          const CivilDay(year: 2026, month: 12, day: 25),
        );

        AppClock.reset();
      },
    );

    test(
      '4. TaskList.complete on all 5 schedule types mixed under Rollover policy',
      () {
        final start = const CivilDay(year: 2026, month: 6, day: 1); // Monday
        final schedules = [
          OneOffSchedule(date: start),
          DailySchedule(startDate: start, interval: 1),
          WeeklySchedule(
            startDate: start,
            interval: 1,
            daysOfWeek: const {3},
          ), // Wed
          MonthlySchedule(startDate: start, interval: 1, dayOfMonth: 15),
          YearlySchedule(startDate: start, interval: 1, month: 12, day: 25),
        ];

        final task = TaskSchedule(
          id: 'mixed-five-rules',
          title: 'Five Rules mixed',
          description: 'Test',
          schedules: schedules,
          missedPolicy: MissedPolicy.rollover,
        );

        final taskList = TaskList([task]);

        // Complete on June 1, 2026
        AppClock.setMockTime(DateTime(2026, 6, 1, 12, 0));
        final state = taskList.complete('mixed-five-rules', userId);
        final updated = state.activeTasks.first;

        // OneOff should be removed, leaving 4 schedules
        expect(updated.schedules.length, 4);
        expect(updated.schedules[0], isA<DailySchedule>());
        expect(
          (updated.schedules[0] as DailySchedule).startDate,
          const CivilDay(year: 2026, month: 6, day: 2),
        ); // Daily advanced
        expect(updated.schedules[1], isA<WeeklySchedule>());
        expect(
          (updated.schedules[1] as WeeklySchedule).startDate,
          const CivilDay(year: 2026, month: 6, day: 3),
        ); // Weekly advanced (Mon -> Wed June 3)
        expect(updated.schedules[2], isA<MonthlySchedule>());
        expect(
          (updated.schedules[2] as MonthlySchedule).startDate,
          const CivilDay(year: 2026, month: 6, day: 15),
        ); // Monthly advanced (Mon -> June 15)
        expect(updated.schedules[3], isA<YearlySchedule>());
        expect(
          (updated.schedules[3] as YearlySchedule).startDate,
          const CivilDay(year: 2026, month: 12, day: 25),
        ); // Yearly advanced (Mon -> Dec 25)

        AppClock.reset();
      },
    );

    test(
      '5. TaskList.complete on slot-based identical Weekly schedules (2 slots on Mon, Wed)',
      () {
        final start = const CivilDay(year: 2026, month: 6, day: 1); // Monday
        final schedules = [
          WeeklySchedule(
            startDate: start,
            interval: 1,
            daysOfWeek: const {1, 3},
          ),
          WeeklySchedule(
            startDate: start,
            interval: 1,
            daysOfWeek: const {1, 3},
          ),
        ];

        final task = TaskSchedule(
          id: 'slot-weekly',
          title: 'Slot Weekly',
          description: 'Test',
          schedules: schedules,
          activeOccurrenceIndex: 0,
        );

        final taskList = TaskList([task]);

        // Complete first slot on Monday, June 1
        AppClock.setMockTime(DateTime(2026, 6, 1, 12, 0));
        var state = taskList.complete('slot-weekly', userId);
        var updated = state.activeTasks.first;

        // Active index should advance to 1, scheduled dates unchanged
        expect(updated.activeOccurrenceIndex, 1);
        expect(
          (updated.schedules[0] as WeeklySchedule).startDate,
          const CivilDay(year: 2026, month: 6, day: 1),
        );
        expect(
          (updated.schedules[1] as WeeklySchedule).startDate,
          const CivilDay(year: 2026, month: 6, day: 1),
        );

        // Complete second slot on Monday, June 1
        state = state.complete('slot-weekly', userId);
        updated = state.activeTasks.first;

        // Active index resets to 0, scheduled dates advance to next occurrence (Wed June 3)
        expect(updated.activeOccurrenceIndex, 0);
        expect(
          (updated.schedules[0] as WeeklySchedule).startDate,
          const CivilDay(year: 2026, month: 6, day: 3),
        );
        expect(
          (updated.schedules[1] as WeeklySchedule).startDate,
          const CivilDay(year: 2026, month: 6, day: 3),
        );

        AppClock.reset();
      },
    );

    test(
      '6. TaskRepository missed policies: Rollover policy on mixed Daily (interval 2) and Weekly (Wed, Fri) schedules',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repository = TaskRepository(firestore: firestore, userId: userId);

        final start = const CivilDay(year: 2026, month: 6, day: 1); // Monday
        final task = TaskSchedule(
          id: 'repo-rollover-mixed',
          title: 'Mixed Rollover Repo',
          description: 'Test',
          schedules: [
            DailySchedule(startDate: start, interval: 2),
            WeeklySchedule(
              startDate: start,
              interval: 1,
              daysOfWeek: const {3, 5},
            ),
          ],
          missedPolicy: MissedPolicy.rollover,
        );

        // Add task on Mon June 1
        AppClock.setMockTime(DateTime(2026, 6, 1, 10, 0));
        await repository.addTask(task);
        await Future.delayed(Duration.zero);

        // Verify Monday instances spawned
        final instsBefore = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .get();
        // Daily schedule should have instance for June 1 (since it starts June 1).
        // Weekly schedule should have instance for June 3 (its next occurrence after June 1).
        expect(instsBefore.docs.length, 2);
        expect(
          instsBefore.docs.any(
            (d) => d.id == 'repo-rollover-mixed_2026-06-01_0',
          ),
          isTrue,
        );
        expect(
          instsBefore.docs.any(
            (d) => d.id == 'repo-rollover-mixed_2026-06-03_1',
          ),
          isTrue,
        );

        AppClock.reset();
      },
    );

    test(
      '7. TaskRepository missed policies: Skip policy on mixed Weekly (Mon) and Monthly (dayOfMonth 1) schedules',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repository = TaskRepository(firestore: firestore, userId: userId);

        final start = const CivilDay(year: 2026, month: 6, day: 1); // Monday
        final task = TaskSchedule(
          id: 'repo-skip-mixed',
          title: 'Mixed Skip Repo',
          description: 'Test',
          schedules: [
            WeeklySchedule(
              startDate: start,
              interval: 1,
              daysOfWeek: const {1},
            ),
            MonthlySchedule(startDate: start, interval: 1, dayOfMonth: 1),
          ],
          missedPolicy: MissedPolicy.skip,
        );

        // Add task on Mon June 1
        AppClock.setMockTime(DateTime(2026, 6, 1, 10, 0));
        await repository.addTask(task);
        await Future.delayed(Duration.zero);

        // Mock time to Tue June 9. Mon June 8 Weekly is missed, and June 1 Weekly & Monthly are missed.
        AppClock.setMockTime(DateTime(2026, 6, 9, 10, 0));
        await repository.getTasks().first;
        await Future.delayed(Duration.zero);

        // Verify missed instances are marked skipped
        final weeklyJune1 = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc('repo-skip-mixed_2026-06-01_0')
            .get();
        final monthlyJune1 = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc('repo-skip-mixed_2026-06-01_1')
            .get();

        expect(weeklyJune1.data()?['status'], 'skipped');
        expect(monthlyJune1.data()?['status'], 'skipped');

        // Weekly June 8 is backfilled and marked skipped
        final weeklyJune8 = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc('repo-skip-mixed_2026-06-08_0')
            .get();
        expect(weeklyJune8.exists, isTrue);
        expect(weeklyJune8.data()?['status'], 'skipped');

        // Next instances should be spawned:
        // Weekly next after June 9: Mon June 15
        // Monthly next after June 9: July 1
        final weeklyJune15 = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc('repo-skip-mixed_2026-06-15_0')
            .get();
        final monthlyJuly1 = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .doc('repo-skip-mixed_2026-07-01_1')
            .get();

        expect(weeklyJune15.exists, isTrue);
        expect(weeklyJune15.data()?['status'], 'pending');
        expect(monthlyJuly1.exists, isTrue);
        expect(monthlyJuly1.data()?['status'], 'pending');

        AppClock.reset();
      },
    );

    test(
      '8. TaskRepository missed policies: Stack policy on mixed Daily (interval 1) and Weekly (Wed) schedules',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repository = TaskRepository(firestore: firestore, userId: userId);

        final start = const CivilDay(year: 2026, month: 6, day: 1); // Monday
        final task = TaskSchedule(
          id: 'repo-stack-mixed',
          title: 'Mixed Stack Repo',
          description: 'Test',
          schedules: [
            DailySchedule(startDate: start, interval: 1),
            WeeklySchedule(
              startDate: start,
              interval: 1,
              daysOfWeek: const {3},
            ), // Wednesday
          ],
          missedPolicy: MissedPolicy.stack,
        );

        // Add task on Mon June 1
        AppClock.setMockTime(DateTime(2026, 6, 1, 10, 0));
        await repository.addTask(task);
        await Future.delayed(Duration.zero);

        // Mock time to Wed June 3. Daily should have instances for June 1, 2, 3. Weekly should have instance for June 3.
        AppClock.setMockTime(DateTime(2026, 6, 3, 10, 0));
        await repository.getTasks().first;
        await Future.delayed(Duration.zero);

        final insts = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .get();
        // Expect 4 instances: Daily (June 1, 2, 3) + Weekly (June 3)
        expect(insts.docs.length, 4);
        expect(
          insts.docs.any((d) => d.id == 'repo-stack-mixed_2026-06-01_0'),
          isTrue,
        );
        expect(
          insts.docs.any((d) => d.id == 'repo-stack-mixed_2026-06-02_0'),
          isTrue,
        );
        expect(
          insts.docs.any((d) => d.id == 'repo-stack-mixed_2026-06-03_0'),
          isTrue,
        );
        expect(
          insts.docs.any((d) => d.id == 'repo-stack-mixed_2026-06-03_1'),
          isTrue,
        );

        AppClock.reset();
      },
    );

    test(
      '9. TaskRepository missed policies: Shift policy behavior on Daily (interval 2) and Weekly (Mon) schedules',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repository = TaskRepository(firestore: firestore, userId: userId);

        final start = const CivilDay(year: 2026, month: 6, day: 1); // Monday
        final task = TaskSchedule(
          id: 'repo-shift-mixed',
          title: 'Mixed Shift Repo',
          description: 'Test',
          schedules: [
            DailySchedule(startDate: start, interval: 2),
            WeeklySchedule(
              startDate: start,
              interval: 1,
              daysOfWeek: const {1},
            ),
          ],
          missedPolicy: MissedPolicy.shift,
        );

        // Add task on Mon June 1.
        AppClock.setMockTime(DateTime(2026, 6, 1, 10, 0));
        await repository.addTask(task);
        await Future.delayed(Duration.zero);

        // Verify that under shift policy, _checkAndProcessMissedPolicies does NOT spawn instances
        final insts = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .get();
        expect(insts.docs.isEmpty, isTrue);

        AppClock.reset();
      },
    );

    test(
      '10. TaskRepository missed policies: OneOff + Daily + Weekly + Monthly + Yearly under Stack policy',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repository = TaskRepository(firestore: firestore, userId: userId);

        final start = const CivilDay(year: 2026, month: 6, day: 1); // Monday
        final task = TaskSchedule(
          id: 'repo-five-stack',
          title: 'Five Stack',
          description: 'Test',
          schedules: [
            OneOffSchedule(date: start),
            DailySchedule(startDate: start, interval: 1),
            WeeklySchedule(
              startDate: start,
              interval: 1,
              daysOfWeek: const {3},
            ), // Wed
            MonthlySchedule(startDate: start, interval: 1, dayOfMonth: 15),
            YearlySchedule(startDate: start, interval: 1, month: 12, day: 25),
          ],
          missedPolicy: MissedPolicy.stack,
        );

        // Add task on Mon June 1
        AppClock.setMockTime(DateTime(2026, 6, 1, 10, 0));
        await repository.addTask(task);
        await Future.delayed(Duration.zero);

        // Mock time to Wed June 3.
        // OneOff occurrences: June 1.
        // Daily occurrences: June 1, 2, 3.
        // Weekly occurrences: June 3.
        AppClock.setMockTime(DateTime(2026, 6, 3, 10, 0));
        await repository.getTasks().first;
        await Future.delayed(Duration.zero);

        final insts = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .get();
        // Total: 1 (OneOff) + 3 (Daily) + 1 (Weekly) = 5 instances.
        expect(insts.docs.length, 5);

        expect(
          insts.docs.any((d) => d.id == 'repo-five-stack_2026-06-01_0'),
          isTrue,
        ); // OneOff
        expect(
          insts.docs.any((d) => d.id == 'repo-five-stack_2026-06-01_1'),
          isTrue,
        ); // Daily June 1
        expect(
          insts.docs.any((d) => d.id == 'repo-five-stack_2026-06-02_1'),
          isTrue,
        ); // Daily June 2
        expect(
          insts.docs.any((d) => d.id == 'repo-five-stack_2026-06-03_1'),
          isTrue,
        ); // Daily June 3
        expect(
          insts.docs.any((d) => d.id == 'repo-five-stack_2026-06-03_2'),
          isTrue,
        ); // Weekly June 3

        AppClock.reset();
      },
    );

    test(
      '11. TaskRepository completion: Rollover policy completion spawns correct next occurrences in mixed schedules',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repository = TaskRepository(firestore: firestore, userId: userId);

        final start = const CivilDay(year: 2026, month: 6, day: 1); // Monday
        final task = TaskSchedule(
          id: 'repo-rollover-complete',
          title: 'Mixed Rollover Complete',
          description: 'Test',
          schedules: [
            DailySchedule(startDate: start, interval: 2),
            WeeklySchedule(
              startDate: start,
              interval: 1,
              daysOfWeek: const {1, 3},
            ),
          ],
          missedPolicy: MissedPolicy.rollover,
        );

        // Add task on Mon June 1
        AppClock.setMockTime(DateTime(2026, 6, 1, 10, 0));
        await repository.addTask(task);
        await Future.delayed(Duration.zero);

        // Complete Daily instance on June 1
        await repository.completeTask('repo-rollover-complete_2026-06-01_0');
        await Future.delayed(Duration.zero);

        final insts = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .get();

        // Completing the Daily instance (June 1) should spawn the next occurrence after June 1.
        // Daily next after June 1 is June 3.
        // Weekly next after June 1 is June 3.
        // Let's verify that a new pending Daily instance for June 3 is created (ends in _0).
        expect(
          insts.docs.any(
            (d) =>
                d.id == 'repo-rollover-complete_2026-06-03_0' &&
                d.data()['status'] == 'pending',
          ),
          isTrue,
        );

        AppClock.reset();
      },
    );
  });
}
