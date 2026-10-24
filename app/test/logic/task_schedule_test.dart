import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test_factories.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  group('TaskSchedule Properties', () {
    test('isOverdue checks dueFromMidnight correctly', () {
      const todayCivil = CivilDay(year: 2024, month: 1, day: 1);
      final task = TestTaskFactory.createOneOff(
        id: '1',
        title: 'Test',
        description: 'Test',
        date: todayCivil,
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 0, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 12, minute: 0),
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
                hour: 8,
                minute: 0,
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 0,
                hour: 9,
                minute: 0,
              ),
            ),
            DailySchedule(
              startDate: const CivilDay(year: 2026, month: 3, day: 8),
              interval: 1,
              startRelativeTime: const RelativeTime(
                dayOffset: 0,
                hour: 20,
                minute: 0,
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 0,
                hour: 21,
                minute: 0,
              ),
            ),
          ],
          activeOccurrenceIndex: 1,
        );

        final map = task.toFirestore();
        expect(map['schedules'], isA<List>());
        expect(map['schedules'].length, 2);
        expect(map['schedules'][0]['type'], 'daily');
        expect(
          map['schedules'][0]['schedulingPolicy']['type'],
          'fixedCalendar',
        );
        expect(map['activeOccurrenceIndex'], 1);
      },
    );

    test(
      'serializes and deserializes CompletionRelativePolicy and autoDismiss missed policy correctly',
      () async {
        final task = TestTaskFactory.createOneOff(
          id: 'task-completion-relative-test',
          title: 'Completion Relative Task',
          description: 'Chore',
          date: const CivilDay(year: 2026, month: 6, day: 1),
          schedulingPolicy: const CompletionRelativePolicy(
            interval: Duration(days: 7),
            targetHour: 9,
            targetMinute: 30,
          ),
          missedOccurrencePolicy: const MissedOccurrencePolicy.autoDismiss(
            gracePeriod: Duration(hours: 4),
          ),
        );

        final map = task.toFirestore();
        expect(
          map['schedules'][0]['schedulingPolicy']['type'],
          'completionRelative',
        );
        expect(
          map['schedules'][0]['schedulingPolicy']['intervalMinutes'],
          7 * 24 * 60,
        );
        expect(map['schedules'][0]['schedulingPolicy']['targetHour'], 9);
        expect(map['schedules'][0]['schedulingPolicy']['targetMinute'], 30);
        expect(
          map['schedules'][0]['missedOccurrencePolicy']['type'],
          'autoDismiss',
        );
        expect(
          map['schedules'][0]['missedOccurrencePolicy']['graceMinutes'],
          4 * 60,
        );

        final firestore = FakeFirebaseFirestore();
        await firestore.collection('tasks').doc(task.id).set(map);
        final snapshot = await firestore.collection('tasks').doc(task.id).get();
        final deserialized = TaskSchedule.fromFirestore(snapshot);

        expect(deserialized.id, task.id);
        expect(deserialized.schedulingPolicy, isA<CompletionRelativePolicy>());
        final policy =
            deserialized.schedulingPolicy as CompletionRelativePolicy;
        expect(policy.interval, const Duration(days: 7));
        expect(policy.targetTime, const TimeOfDay(hour: 9, minute: 30));
        expect(deserialized.missedOccurrencePolicy.isAutoDismiss, isTrue);
        expect(
          deserialized.missedOccurrencePolicy.gracePeriod,
          const Duration(hours: 4),
        );
      },
    );

    test('serializes and deserializes estimatedDuration correctly', () async {
      final task = TestTaskFactory.createOneOff(
        id: 'task-duration-test',
        title: 'TaskSchedule with duration',
        description: 'Desc',
        date: const CivilDay(year: 2026, month: 3, day: 8),
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
        estimatedDuration: const Duration(minutes: 45),
      );

      final map = task.toFirestore();
      expect(map['estimatedDuration'], 45);

      final firestore = FakeFirebaseFirestore();
      await firestore.collection('tasks').doc(task.id).set(map);
      final snapshot = await firestore.collection('tasks').doc(task.id).get();
      final deserialized = TaskSchedule.fromFirestore(snapshot);

      expect(deserialized.id, task.id);
      expect(deserialized.estimatedDuration, const Duration(minutes: 45));
    });

    test('deserializes null estimatedDuration correctly', () async {
      final task = TestTaskFactory.createOneOff(
        id: 'task-no-duration',
        title: 'TaskSchedule without duration',
        description: 'Desc',
        date: const CivilDay(year: 2026, month: 3, day: 8),
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
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
      final task = TestTaskFactory.createOneOff(
        id: 'task-agile-test',
        title: 'Agile TaskSchedule',
        description: 'Desc',
        isFamily: true,
        priority: TaskPriority.high,
        cycleId: '2026-W23',
        assignedUserId: 'user-1',
        preferredBy: const {'user-1': true, 'user-2': false},
        date: const CivilDay(year: 2026, month: 3, day: 8),
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
      );

      final map = task.toFirestore();
      expect(map['isFamily'], true);
      expect(map['priority'], 'high');
      expect(map['cycleId'], '2026-W23');
      expect(map['preferredBy']['user-1'], true);
      expect(map['preferredBy']['user-2'], false);
      expect(map['assignedUserId'], 'user-1');

      final firestore = FakeFirebaseFirestore();
      await firestore.collection('tasks').doc(task.id).set(map);
      final snapshot = await firestore.collection('tasks').doc(task.id).get();
      final deserialized = TaskSchedule.fromFirestore(snapshot);

      expect(deserialized.id, task.id);
      expect(deserialized.isFamily, true);
      expect(deserialized.priority, TaskPriority.high);
      expect(deserialized.cycleId, '2026-W23');
      expect(deserialized.preferredBy['user-1'], true);
      expect(deserialized.preferredBy['user-2'], false);
      expect(deserialized.assignedUserId, 'user-1');
    });

    test('serializes and deserializes appLaunchUrl correctly', () async {
      final task = TaskSchedule(
        id: 'task-launch-url-test',
        title: 'Launch URL Task',
        description: 'Desc',
        schedules: [
          OneOffSchedule(
            date: const CivilDay(year: 2026, month: 3, day: 8),
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              hour: 9,
              minute: 0,
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              hour: 17,
              minute: 0,
            ),
          ),
        ],
        appLaunchUrl: 'https://example.com/app',
      );

      final map = task.toFirestore();
      expect(map['appLaunchUrl'], 'https://example.com/app');

      final firestore = FakeFirebaseFirestore();
      await firestore.collection('tasks').doc(task.id).set(map);
      final snapshot = await firestore.collection('tasks').doc(task.id).get();
      final deserialized = TaskSchedule.fromFirestore(snapshot);

      expect(deserialized.id, task.id);
      expect(deserialized.appLaunchUrl, 'https://example.com/app');
    });
  });

  group('TaskSchedule Editing and Changes Aggregation', () {
    test(
      'TaskSchedule.edit() returns correctly updated task and changes map',
      () {
        final task = TestTaskFactory.createOneOff(
          id: 'edit-test-task',
          title: 'Initial Title',
          description: 'Initial Desc',
          date: const CivilDay(year: 2026, month: 3, day: 8),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 9,
            minute: 0,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 17,
            minute: 0,
          ),
        );

        final result = task.edit(
          newTitle: 'Updated Title',
          newDescription: 'Initial Desc', // unchanged
          newSchedules: [
            OneOffSchedule(
              date: const CivilDay(year: 2026, month: 3, day: 9),
              startRelativeTime: const RelativeTime(
                dayOffset: -1,
                hour: 10,
                minute: 0,
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 0,
                hour: 18,
                minute: 0,
              ),
            ),
          ],
          newEstimatedDuration: null, // cleared
          newMissedPolicy: MissedPolicy.stack,
          newIsMaster: false,
          newLastSpawnedDate: null,
          newIsFamily: true,
          newPriority: TaskPriority.high,
        );

        final newTask = result.newTask;
        final changes = result.changes;

        // 1. Verify updated TaskSchedule properties
        expect(newTask.id, task.id);
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

        // 2. Verify changes map
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

    test('edit converts family task to individual task correctly', () {
      final task = TestTaskFactory.createOneOff(
        id: 't-family',
        title: 'Family Task',
        description: '',
        isFamily: true,
        date: const CivilDay(year: 2026, month: 3, day: 8),
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
      );

      final result = task.edit(
        newTitle: task.title,
        newDescription: task.description,
        newSchedules: task.schedules,
        newEstimatedDuration: task.estimatedDuration,
        newMissedPolicy: MissedPolicy.stack,
        newIsMaster: false,
        newLastSpawnedDate: null,
        newIsFamily: false, // converting family task to individual
        newPriority: task.priority,
      );

      expect(result.newTask.isFamily, isFalse);
      expect(result.changes['isFamily'], isFalse);
    });
  });

  group('TaskSchedule Whitespace Trimming', () {
    test(
      'Constructor trims leading and trailing spaces from title and description',
      () {
        final task = TaskSchedule(
          id: '123',
          title: '   Trimmed Title   ',
          description: '   Trimmed Description   \n\t',
        );

        expect(task.title, 'Trimmed Title');
        expect(task.description, 'Trimmed Description');
      },
    );

    test(
      'edit trims leading and trailing spaces from title and description',
      () {
        final task = TaskSchedule(
          id: '123',
          title: 'Initial Title',
          description: 'Initial Description',
        );

        final modification = task.edit(
          newTitle: '   Updated Title   ',
          newDescription: '   Updated Description   ',
          newSchedules: [],
          newEstimatedDuration: null,
          newMissedPolicy: MissedPolicy.stack,
          newIsMaster: false,
          newLastSpawnedDate: null,
          newIsFamily: false,
          newPriority: TaskPriority.medium,
        );

        expect(modification.newTask.title, 'Updated Title');
        expect(modification.newTask.description, 'Updated Description');
        expect(modification.changes['title'], 'Updated Title');
        expect(modification.changes['description'], 'Updated Description');
      },
    );

    test(
      'familyCompletionMode serializes, deserializes, edits, and copies correctly',
      () async {
        final firestore = FakeFirebaseFirestore();
        final docRef = firestore.collection('tasks').doc('S-schedule-indiv');

        final task = TaskSchedule(
          id: 'S-schedule-indiv',
          title: 'Individual Task',
          description: 'Desc',
          isFamily: true,
          familyCompletionMode: FamilyCompletionMode.individual,
        );

        final firestoreMap = task.toFirestore();
        expect(firestoreMap['familyCompletionMode'], 'individual');

        await docRef.set(firestoreMap);
        final snapshot = await docRef.get();
        final loaded = TaskSchedule.fromFirestore(snapshot);

        expect(loaded.id, 'S-schedule-indiv');
        expect(loaded.isFamily, isTrue);
        expect(loaded.familyCompletionMode, FamilyCompletionMode.individual);
        final modification = loaded.edit(
          newTitle: loaded.title,
          newDescription: loaded.description,
          newSchedules: loaded.schedules,
          newEstimatedDuration: loaded.estimatedDuration,
          newMissedPolicy: MissedPolicy.stack,
          newIsMaster: loaded.isMaster,
          newLastSpawnedDate: loaded.lastSpawnedDate,
          newIsFamily: loaded.isFamily,
          newFamilyCompletionMode: FamilyCompletionMode.anyone,
          newPriority: loaded.priority,
        );
        expect(
          modification.newTask.familyCompletionMode,
          FamilyCompletionMode.anyone,
        );
        expect(modification.changes['familyCompletionMode'], 'anyone');

        final copied = loaded.copyWith(
          familyCompletionMode: FamilyCompletionMode.anyone,
          skipIfNoCapacity: true,
        );
        expect(copied.familyCompletionMode, FamilyCompletionMode.anyone);
        expect(copied.skipIfNoCapacity, true);
      },
    );
  });
}
