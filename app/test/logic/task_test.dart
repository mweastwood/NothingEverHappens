import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task.dart';
import 'package:nothing_ever_happens/logic/task_list.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  group('Recurrence Logic with CivilDay', () {
    test('OneOffSchedule occurs only on the specific date', () {
      const date = CivilDay(year: 2024, month: 1, day: 1);
      final schedule = OneOffSchedule(date: date);

      expect(schedule.occursOn(date), isTrue);
      expect(
        schedule.occursOn(const CivilDay(year: 2024, month: 1, day: 2)),
        isFalse,
      );
    });

    test('DailySchedule checks intervals correctly', () {
      const start = CivilDay(year: 2024, month: 1, day: 1);
      final schedule = DailySchedule(startDate: start, interval: 2);

      expect(schedule.occursOn(start), isTrue);
      expect(
        schedule.occursOn(const CivilDay(year: 2024, month: 1, day: 2)),
        isFalse,
      );
      expect(
        schedule.occursOn(const CivilDay(year: 2024, month: 1, day: 3)),
        isTrue,
      );
    });

    test('WeeklySchedule checks weeks and days correctly', () {
      // Jan 1 2024 is a Monday
      const start = CivilDay(year: 2024, month: 1, day: 1);
      final schedule = WeeklySchedule(
        startDate: start,
        interval: 1,
        daysOfWeek: {1, 3}, // Mon, Wed
      );

      expect(schedule.occursOn(start), isTrue); // Mon
      expect(
        schedule.occursOn(const CivilDay(year: 2024, month: 1, day: 2)),
        isFalse,
      ); // Tue
      expect(
        schedule.occursOn(const CivilDay(year: 2024, month: 1, day: 3)),
        isTrue,
      ); // Wed
    });

    test(
      'DailySchedule occursOn works across Spring forward DST boundary (March 9, 2026)',
      () {
        // US Spring forward transition is March 8, 2026.
        const start = CivilDay(year: 2026, month: 3, day: 8);
        final schedule = DailySchedule(startDate: start, interval: 2);

        // On March 8: difference in days = 0. Modulo 2 = 0 -> true
        expect(schedule.occursOn(start), isTrue);

        // On March 9: difference in days = 1. Modulo 2 = 1 -> false
        expect(
          schedule.occursOn(const CivilDay(year: 2026, month: 3, day: 9)),
          isFalse,
        );

        // On March 10 (across DST): difference in days = 2. Modulo 2 = 0 -> true
        expect(
          schedule.occursOn(const CivilDay(year: 2026, month: 3, day: 10)),
          isTrue,
        );
      },
    );

    test(
      'WeeklySchedule occursOn works across Spring forward DST boundary (March 9, 2026)',
      () {
        // US Spring forward transition is March 8, 2026.
        // March 2, 2026 is Monday.
        const start = CivilDay(year: 2026, month: 3, day: 2);
        final schedule = WeeklySchedule(
          startDate: start,
          interval: 2, // Repeats every 2 weeks
          daysOfWeek: {1}, // Mondays
        );

        expect(schedule.occursOn(start), isTrue); // Mon March 2

        // Mon March 9 (1 week later, across DST on March 8) -> false (interval is 2 weeks)
        expect(
          schedule.occursOn(const CivilDay(year: 2026, month: 3, day: 9)),
          isFalse,
        );

        // Mon March 16 (2 weeks later, across DST) -> true
        expect(
          schedule.occursOn(const CivilDay(year: 2026, month: 3, day: 16)),
          isTrue,
        );
      },
    );

    test(
      'DailySchedule nextOccurrenceAfter calculates next occurrence correctly',
      () {
        const start = CivilDay(year: 2026, month: 3, day: 8);
        final schedule = DailySchedule(startDate: start, interval: 2);

        expect(
          schedule.nextOccurrenceAfter(
            const CivilDay(year: 2026, month: 3, day: 8),
          ),
          const CivilDay(year: 2026, month: 3, day: 10),
        );

        expect(
          schedule.nextOccurrenceAfter(
            const CivilDay(year: 2026, month: 3, day: 9),
          ),
          const CivilDay(year: 2026, month: 3, day: 10),
        );

        expect(
          schedule.nextOccurrenceAfter(
            const CivilDay(year: 2026, month: 3, day: 10),
          ),
          const CivilDay(year: 2026, month: 3, day: 12),
        );
      },
    );

    test(
      'WeeklySchedule nextOccurrenceAfter calculates next occurrence correctly',
      () {
        const start = CivilDay(year: 2026, month: 3, day: 2);
        final schedule = WeeklySchedule(
          startDate: start,
          interval: 1,
          daysOfWeek: {1, 3}, // Mon, Wed
        );

        // March 2 is Monday. Next is March 4 Wednesday
        expect(
          schedule.nextOccurrenceAfter(
            const CivilDay(year: 2026, month: 3, day: 2),
          ),
          const CivilDay(year: 2026, month: 3, day: 4),
        );

        // Next after March 3 is March 4 Wednesday
        expect(
          schedule.nextOccurrenceAfter(
            const CivilDay(year: 2026, month: 3, day: 3),
          ),
          const CivilDay(year: 2026, month: 3, day: 4),
        );

        // Next after March 4 Wednesday is March 9 Monday
        expect(
          schedule.nextOccurrenceAfter(
            const CivilDay(year: 2026, month: 3, day: 4),
          ),
          const CivilDay(year: 2026, month: 3, day: 9),
        );
      },
    );

    test(
      'MonthlySchedule checks intervals and dayOfMonth (positive) correctly',
      () {
        const start = CivilDay(year: 2024, month: 1, day: 10);
        final schedule = MonthlySchedule(
          startDate: start,
          interval: 2,
          dayOfMonth: 15,
        );

        expect(
          schedule.occursOn(const CivilDay(year: 2024, month: 1, day: 15)),
          isTrue,
        );
        expect(
          schedule.occursOn(const CivilDay(year: 2024, month: 2, day: 15)),
          isFalse,
        );
        expect(
          schedule.occursOn(const CivilDay(year: 2024, month: 3, day: 15)),
          isTrue,
        );
        expect(
          schedule.occursOn(const CivilDay(year: 2024, month: 3, day: 16)),
          isFalse,
        );
      },
    );

    test(
      'MonthlySchedule checks intervals and dayOfMonth (negative) correctly',
      () {
        const start = CivilDay(year: 2024, month: 1, day: 10);
        final schedule = MonthlySchedule(
          startDate: start,
          interval: 1,
          dayOfMonth: -1,
        );

        expect(
          schedule.occursOn(const CivilDay(year: 2024, month: 1, day: 31)),
          isTrue,
        );
        expect(
          schedule.occursOn(const CivilDay(year: 2024, month: 2, day: 29)),
          isTrue,
        ); // Leap year
        expect(
          schedule.occursOn(const CivilDay(year: 2024, month: 2, day: 28)),
          isFalse,
        );
      },
    );

    test('MonthlySchedule checks nthDayOfWeek correctly', () {
      const start = CivilDay(year: 2024, month: 1, day: 1);
      final schedule = MonthlySchedule(
        startDate: start,
        interval: 1,
        dayOfWeek: 2,
        occurrence: 2,
      );

      expect(
        schedule.occursOn(const CivilDay(year: 2024, month: 1, day: 9)),
        isTrue,
      );
      expect(
        schedule.occursOn(const CivilDay(year: 2024, month: 1, day: 2)),
        isFalse,
      );
      expect(
        schedule.occursOn(const CivilDay(year: 2024, month: 2, day: 13)),
        isTrue,
      );
    });

    test('MonthlySchedule nextOccurrenceAfter works correctly', () {
      const start = CivilDay(year: 2024, month: 1, day: 1);
      final schedule = MonthlySchedule(
        startDate: start,
        interval: 1,
        dayOfMonth: 15,
      );

      expect(
        schedule.nextOccurrenceAfter(
          const CivilDay(year: 2024, month: 1, day: 10),
        ),
        const CivilDay(year: 2024, month: 1, day: 15),
      );
      expect(
        schedule.nextOccurrenceAfter(
          const CivilDay(year: 2024, month: 1, day: 15),
        ),
        const CivilDay(year: 2024, month: 2, day: 15),
      );
    });

    test('MonthlySchedule asserts dayOfMonth ranges correctly', () {
      const start = CivilDay(year: 2024, month: 1, day: 1);

      expect(
        () => MonthlySchedule(startDate: start, interval: 1, dayOfMonth: 1),
        returnsNormally,
      );
      expect(
        () => MonthlySchedule(startDate: start, interval: 1, dayOfMonth: 28),
        returnsNormally,
      );
      expect(
        () => MonthlySchedule(startDate: start, interval: 1, dayOfMonth: -1),
        returnsNormally,
      );
      expect(
        () => MonthlySchedule(startDate: start, interval: 1, dayOfMonth: -28),
        returnsNormally,
      );

      expect(
        () => MonthlySchedule(startDate: start, interval: 1, dayOfMonth: 0),
        throwsAssertionError,
      );
      expect(
        () => MonthlySchedule(startDate: start, interval: 1, dayOfMonth: 29),
        throwsAssertionError,
      );
      expect(
        () => MonthlySchedule(startDate: start, interval: 1, dayOfMonth: -29),
        throwsAssertionError,
      );
    });

    test('YearlySchedule checks intervals, month, and day correctly', () {
      const start = CivilDay(year: 2024, month: 10, day: 24);
      final schedule = YearlySchedule(
        startDate: start,
        interval: 2,
        month: 10,
        day: 24,
      );

      expect(
        schedule.occursOn(const CivilDay(year: 2024, month: 10, day: 24)),
        isTrue,
      );
      expect(
        schedule.occursOn(const CivilDay(year: 2025, month: 10, day: 24)),
        isFalse,
      );
      expect(
        schedule.occursOn(const CivilDay(year: 2026, month: 10, day: 24)),
        isTrue,
      );
      expect(
        schedule.occursOn(const CivilDay(year: 2026, month: 10, day: 25)),
        isFalse,
      );
    });

    test('YearlySchedule nextOccurrenceAfter works correctly', () {
      const start = CivilDay(year: 2024, month: 10, day: 24);
      final schedule = YearlySchedule(
        startDate: start,
        interval: 1,
        month: 10,
        day: 24,
      );

      expect(
        schedule.nextOccurrenceAfter(
          const CivilDay(year: 2024, month: 10, day: 20),
        ),
        const CivilDay(year: 2024, month: 10, day: 24),
      );
      expect(
        schedule.nextOccurrenceAfter(
          const CivilDay(year: 2024, month: 10, day: 24),
        ),
        const CivilDay(year: 2025, month: 10, day: 24),
      );
    });

    test('MonthlySchedule checks last occurrence of dayOfWeek correctly', () {
      const start = CivilDay(year: 2024, month: 1, day: 1);
      final schedule = MonthlySchedule(
        startDate: start,
        interval: 1,
        dayOfWeek: 5, // Friday
        occurrence: -1, // Last
      );

      // January 26, 2024 is the last Friday of January
      expect(
        schedule.occursOn(const CivilDay(year: 2024, month: 1, day: 26)),
        isTrue,
      );
      // January 19, 2024 is NOT the last Friday
      expect(
        schedule.occursOn(const CivilDay(year: 2024, month: 1, day: 19)),
        isFalse,
      );
      // February 23, 2024 is the last Friday of February
      expect(
        schedule.occursOn(const CivilDay(year: 2024, month: 2, day: 23)),
        isTrue,
      );
    });

    test('YearlySchedule nextOccurrenceAfter handles leap years correctly', () {
      const start = CivilDay(year: 2024, month: 2, day: 29);
      final schedule = YearlySchedule(
        startDate: start,
        interval: 1,
        month: 2,
        day: 29,
      );

      // The next leap year after 2024 is 2028
      expect(
        schedule.nextOccurrenceAfter(
          const CivilDay(year: 2024, month: 2, day: 29),
        ),
        const CivilDay(year: 2028, month: 2, day: 29),
      );
    });
  });

  group('Task Properties', () {
    test('isOverdue checks dueFromMidnight correctly', () {
      const todayCivil = CivilDay(year: 2024, month: 1, day: 1);
      final task = Task(
        id: '1',
        title: 'Test',
        description: 'Test',
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 0, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 12, minute: 0),
        ),
        schedule: OneOffSchedule(date: todayCivil),
      );

      // 10:00 AM
      expect(task.isOverdue(DateTime(2024, 1, 1, 10, 0)), isFalse);
      // 13:00 PM
      expect(task.isOverdue(DateTime(2024, 1, 1, 13, 0)), isTrue);
    });

    test(
      'toFirestore and fromFirestore serialize multiple daily times correctly',
      () {
        final task = Task(
          id: 'task-test',
          title: 'Multi Task',
          description: 'Desc',
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          schedule: DailySchedule(
            startDate: const CivilDay(year: 2026, month: 3, day: 8),
            interval: 1,
          ),
          dailyTimes: const [
            DailyOccurrenceTime(
              startTime: TimeOfDay(hour: 8, minute: 0),
              dueTime: TimeOfDay(hour: 9, minute: 0),
            ),
            DailyOccurrenceTime(
              startTime: TimeOfDay(hour: 20, minute: 0),
              dueTime: TimeOfDay(hour: 21, minute: 0),
            ),
          ],
          activeOccurrenceIndex: 1,
        );

        final map = task.toFirestore();
        expect(map['dailyTimes'], isA<List>());
        expect(map['dailyTimes'].length, 2);
        expect(map['dailyTimes'][0]['startHour'], 8);
        expect(map['dailyTimes'][1]['dueHour'], 21);
        expect(map['activeOccurrenceIndex'], 1);
      },
    );

    test('serializes and deserializes estimatedDuration correctly', () async {
      final task = Task(
        id: 'task-duration-test',
        title: 'Task with duration',
        description: 'Desc',
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        schedule: OneOffSchedule(
          date: const CivilDay(year: 2026, month: 3, day: 8),
        ),
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
      final deserialized = Task.fromFirestore(snapshot);

      expect(deserialized.id, 'task-duration-test');
      expect(deserialized.estimatedDuration, const Duration(minutes: 45));
    });

    test('deserializes null estimatedDuration correctly', () async {
      final task = Task(
        id: 'task-no-duration',
        title: 'Task without duration',
        description: 'Desc',
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        schedule: OneOffSchedule(
          date: const CivilDay(year: 2026, month: 3, day: 8),
        ),
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
      final deserialized = Task.fromFirestore(snapshot);

      expect(deserialized.estimatedDuration, isNull);
    });

    test('serializes and deserializes new Agile fields correctly', () async {
      final task = Task(
        id: 'task-agile-test',
        title: 'Agile Task',
        description: 'Desc',
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        schedule: OneOffSchedule(
          date: const CivilDay(year: 2026, month: 3, day: 8),
        ),
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
      final deserialized = Task.fromFirestore(snapshot);

      expect(deserialized.id, 'task-agile-test');
      expect(deserialized.isFamily, true);
      expect(deserialized.priority, TaskPriority.high);
      expect(deserialized.cycleId, '2026-W23');
      expect(deserialized.preferredBy['user-1'], true);
      expect(deserialized.preferredBy['user-2'], false);
      expect(deserialized.assignedUserId, 'user-1');
    });
  });

  group('Task Editing and Delta Aggregation', () {
    test(
      'Task.edit() returns correctly updated task and delta with only changes',
      () {
        final task = Task(
          id: 'edit-test-task',
          title: 'Initial Title',
          description: 'Initial Desc',
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          schedule: OneOffSchedule(
            date: const CivilDay(year: 2026, month: 3, day: 8),
          ),
          estimatedDuration: const Duration(minutes: 30),
        );

        final result = task.edit(
          newTitle: 'Updated Title',
          newDescription: 'Initial Desc', // unchanged
          newStartRelativeTime: const RelativeTime(
            dayOffset: -1,
            time: TimeOfDay(hour: 10, minute: 0),
          ),
          newDueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 18, minute: 0),
          ),
          newSchedule: OneOffSchedule(
            date: const CivilDay(year: 2026, month: 3, day: 9),
          ),
          newDailyTimes: const [
            DailyOccurrenceTime(
              startTime: TimeOfDay(hour: 10, minute: 0),
              dueTime: TimeOfDay(hour: 18, minute: 0),
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

        // 1. Verify updated Task properties
        expect(newTask.id, 'edit-test-task');
        expect(newTask.title, 'Updated Title');
        expect(newTask.description, 'Initial Desc');
        expect(newTask.startRelativeTime.dayOffset, -1);
        expect(newTask.startRelativeTime.time.hour, 10);
        expect(newTask.dueRelativeTime.time.hour, 18);
        expect(newTask.schedule, isA<OneOffSchedule>());
        expect((newTask.schedule as OneOffSchedule).date.day, 9);
        expect(newTask.dailyTimes.length, 1);
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
        expect(changes['startRelativeTime']['dayOffset'], -1);
        expect(changes['startRelativeTime']['hour'], 10);
        expect(changes['dueRelativeTime']['hour'], 18);
        expect(changes['schedule']['date']['day'], 9);
        expect(changes['dailyTimes'][0]['startHour'], 10);
        expect(changes['estimatedDuration'], isNull);
        expect(changes['isFamily'], isTrue);
        expect(changes['priority'], 'high');
      },
    );

    test(
      'updateCycleId modifies cycleId and generates correct update delta',
      () {
        final task = Task(
          id: 't1',
          title: 'Task 1',
          description: '',
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          schedule: OneOffSchedule(
            date: const CivilDay(year: 2026, month: 6, day: 1),
          ),
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
        final task = Task(
          id: 't1',
          title: 'Task 1',
          description: '',
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          schedule: OneOffSchedule(
            date: const CivilDay(year: 2026, month: 6, day: 1),
          ),
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
        final task = Task(
          id: 't1',
          title: 'Task 1',
          description: '',
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          schedule: OneOffSchedule(
            date: const CivilDay(year: 2026, month: 6, day: 1),
          ),
        );

        final result = task.updatePreferredBy(const {'user2': true}, 'user1');
        expect(result.newTask.preferredBy['user2'], isTrue);
        expect(result.delta.taskId, 't1');
        expect(result.delta.operation, 'update');
        expect(result.delta.changedFields['preferredBy']['user2'], isTrue);
      },
    );
  });

  group('DailyOccurrenceTime Custom Notifications', () {
    test('serialization and deserialization with notificationTime', () {
      const slot = DailyOccurrenceTime(
        startTime: TimeOfDay(hour: 8, minute: 30),
        dueTime: TimeOfDay(hour: 16, minute: 45),
        notificationTime: TimeOfDay(hour: 8, minute: 15),
      );

      final json = slot.toJson();
      expect(json['startHour'], 8);
      expect(json['startMinute'], 30);
      expect(json['dueHour'], 16);
      expect(json['dueMinute'], 45);
      expect(json['notificationHour'], 8);
      expect(json['notificationMinute'], 15);

      final decoded = DailyOccurrenceTime.fromJson(json);
      expect(decoded.startTime, const TimeOfDay(hour: 8, minute: 30));
      expect(decoded.dueTime, const TimeOfDay(hour: 16, minute: 45));
      expect(decoded.notificationTime, const TimeOfDay(hour: 8, minute: 15));
    });

    test(
      'backward-compatible deserialization when notificationTime is absent',
      () {
        final oldJson = {
          'startHour': 9,
          'startMinute': 0,
          'dueHour': 17,
          'dueMinute': 0,
        };

        final decoded = DailyOccurrenceTime.fromJson(oldJson);
        expect(decoded.startTime, const TimeOfDay(hour: 9, minute: 0));
        expect(decoded.dueTime, const TimeOfDay(hour: 17, minute: 0));
        expect(decoded.notificationTime, isNull);
      },
    );

    test('equality and hashCode checks', () {
      const slot1 = DailyOccurrenceTime(
        startTime: TimeOfDay(hour: 10, minute: 0),
        dueTime: TimeOfDay(hour: 11, minute: 0),
        notificationTime: TimeOfDay(hour: 9, minute: 45),
      );
      const slot2 = DailyOccurrenceTime(
        startTime: TimeOfDay(hour: 10, minute: 0),
        dueTime: TimeOfDay(hour: 11, minute: 0),
        notificationTime: TimeOfDay(hour: 9, minute: 45),
      );
      const slot3 = DailyOccurrenceTime(
        startTime: TimeOfDay(hour: 10, minute: 0),
        dueTime: TimeOfDay(hour: 11, minute: 0),
        notificationTime: null,
      );

      expect(slot1, equals(slot2));
      expect(slot1.hashCode, equals(slot2.hashCode));
      expect(slot1, isNot(equals(slot3)));
    });

    test('toString representation', () {
      const slot = DailyOccurrenceTime(
        startTime: TimeOfDay(hour: 13, minute: 5),
        dueTime: TimeOfDay(hour: 14, minute: 20),
        notificationTime: TimeOfDay(hour: 12, minute: 50),
      );
      expect(
        slot.toString(),
        contains('start: 13:05, due: 14:20, notification: 12:50'),
      );
    });
  });

  group('Missed Occurrence Policies Strategy Unit Tests', () {
    test(
      '1. Rollover (Push to Next Day): Overdue Monday task completed on Tuesday reschedules to Tuesday (original path)',
      () {
        // Create a daily task scheduled for Monday
        final monday = const CivilDay(year: 2026, month: 5, day: 25);
        final task = Task(
          id: 'rollover-task',
          title: 'Water Plants',
          description: 'Every day',
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          schedule: DailySchedule(startDate: monday, interval: 1),
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
          completedTask.schedule.scheduledDate,
          const CivilDay(year: 2026, month: 5, day: 26),
        );
      },
    );

    test(
      '2. Shift Schedule (Push Out Future Dates): Bi-daily Monday task completed late on Wednesday shifts next date to Friday (Wednesday + 2 days)',
      () {
        // Create a bi-daily task scheduled for Monday
        final monday = const CivilDay(year: 2026, month: 5, day: 25);
        final task = Task(
          id: 'shift-task',
          title: 'Mow the Lawn',
          description: 'Every 2 days',
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          schedule: DailySchedule(startDate: monday, interval: 2),
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
          completedTask.schedule.scheduledDate,
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
        final task = Task(
          id: 'skip-task',
          title: 'Take out trash',
          description: 'Every day',
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          schedule: DailySchedule(startDate: monday, interval: 1),
          missedPolicy: MissedPolicy.skip,
        );

        // Save to database
        await repository.addTask(task);

        // Set AppClock to Tuesday 10:00 AM - past due time of Monday (17:00), but before Tuesday (17:00)
        final tuesdayDateTime = DateTime(2026, 5, 26, 10, 0);
        AppClock.setMockTime(tuesdayDateTime);

        // Get tasks stream and wait for auto-process check to trigger
        await repository.getTasks().first;

        // Let's yield to background tasks so Firestore batch completes
        await Future.delayed(Duration.zero);

        // Fetch the updated task from database
        final updatedTaskSnap = await firestore
            .collection('users')
            .doc('user-1')
            .collection('tasks')
            .doc('skip-task')
            .get();
        final updatedTask = Task.fromFirestore(updatedTaskSnap);

        // It should be rescheduled to Tuesday (today + 1 -> Tuesday nextOccurrenceAfter since today is Tuesday)
        expect(
          updatedTask.schedule.scheduledDate,
          const CivilDay(year: 2026, month: 5, day: 26),
        );

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
        final task = Task(
          id: 'stack-task',
          title: 'Read a book',
          description: 'Every day',
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          schedule: DailySchedule(startDate: monday, interval: 1),
          missedPolicy: MissedPolicy.stack,
          isMaster: true,
        );

        // Save master task to database
        await repository.addTask(task);

        // Set AppClock to Wednesday (May 27)
        final wednesdayDateTime = DateTime(2026, 5, 27, 10, 0);
        AppClock.setMockTime(wednesdayDateTime);

        // Fetch tasks list (triggers spawning check in getTasks stream)
        await repository.getTasks().first;
        await Future.delayed(Duration.zero);

        // Query active tasks in Firestore
        final tasksSnap = await firestore
            .collection('users')
            .doc('user-1')
            .collection('tasks')
            .get();
        final allTasks = tasksSnap.docs
            .map((doc) => Task.fromFirestore(doc))
            .toList();

        // We should have 1 master task + 3 spawned active cards (Monday, Tuesday, Wednesday)
        expect(allTasks.length, 4);

        final spawnedCards = allTasks.where((t) => !t.isMaster).toList();
        expect(spawnedCards.length, 3);

        // Assert that spawned cards have deterministic IDs and correct occurrence dates
        expect(
          spawnedCards.any((t) => t.id == 'stack-task_2026-05-25'),
          isTrue,
        );
        expect(
          spawnedCards.any((t) => t.id == 'stack-task_2026-05-26'),
          isTrue,
        );
        expect(
          spawnedCards.any((t) => t.id == 'stack-task_2026-05-27'),
          isTrue,
        );

        // Verify master task lastSpawnedDate is updated to Wednesday
        final masterTaskDoc = await firestore
            .collection('users')
            .doc('user-1')
            .collection('tasks')
            .doc('stack-task')
            .get();
        final updatedMaster = Task.fromFirestore(masterTaskDoc);
        expect(
          updatedMaster.lastSpawnedDate,
          const CivilDay(year: 2026, month: 5, day: 27),
        );

        AppClock.reset();
      },
    );
  });
}
