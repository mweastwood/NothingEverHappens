import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
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
        final task = TaskSchedule(
          id: 'task-completion-relative-test',
          title: 'Completion Relative Task',
          description: 'Chore',
          schedules: [
            OneOffSchedule(date: const CivilDay(year: 2026, month: 6, day: 1)),
          ],
          schedulingPolicy: CompletionRelativePolicy(
            interval: const Duration(days: 7),
            targetTime: const TimeOfDay(hour: 9, minute: 30),
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
      await firestore.collection('tasks').doc(task.id).set(map);
      final snapshot = await firestore.collection('tasks').doc(task.id).get();
      final deserialized = TaskSchedule.fromFirestore(snapshot);

      expect(deserialized.id, task.id);
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
  });

  group('TaskSchedule Editing and Changes Aggregation', () {
    test(
      'TaskSchedule.edit() returns correctly updated task and changes map',
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
      final task = TaskSchedule(
        id: 't-family',
        title: 'Family Task',
        description: '',
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

    test(
      'updateCycleId modifies cycleId and generates correct changes map',
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

        final result = task.updateCycleId('2026-W23');
        expect(result.newTask.cycleId, '2026-W23');
        expect(result.changes['cycleId'], '2026-W23');

        // Test clearing cycleId
        final resultClear = result.newTask.updateCycleId(null);
        expect(resultClear.newTask.cycleId, isNull);
        expect(resultClear.changes['cycleId'], isNull);
      },
    );

    test(
      'updateAssignedUserId modifies assignedUserId and generates correct changes map',
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

        final result = task.updateAssignedUserId('user2');
        expect(result.newTask.assignedUserId, 'user2');
        expect(result.changes['assignedUserId'], 'user2');

        // Test clearing assignedUserId
        final resultClear = result.newTask.updateAssignedUserId(null);
        expect(resultClear.newTask.assignedUserId, isNull);
        expect(resultClear.changes['assignedUserId'], isNull);
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

        final result = task.updatePreferredBy(const {'user2': true});
        expect(result.newTask.preferredBy['user2'], isTrue);
        expect(result.changes['preferredBy']['user2'], isTrue);
      },
    );
  });

  group('Exhaustive Task Scheduling Combinations & Missed Policies Thorough Tests', () {
    const userId = 'user-1';

    bool matchInst(dynamic doc, String ruleId, CivilDay date) {
      final data = doc.data();
      if (data == null) return false;
      final dDate = data['scheduledDate'];
      return data['ruleId'] == ruleId &&
          dDate['year'] == date.year &&
          dDate['month'] == date.month &&
          dDate['day'] == date.day;
    }

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
          missedPolicy: MissedPolicy.stack,
        );

        final taskList = TaskList([task]);

        // Complete on Monday, June 1 (Both Daily and Weekly occur)
        AppClock.setMockTime(DateTime(2026, 6, 1, 12, 0));
        addTearDown(AppClock.reset);
        var state = taskList.complete(task.id);
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
        addTearDown(AppClock.reset);
        state = state.complete(task.id);
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
        addTearDown(AppClock.reset);
        state = state.complete(task.id);
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
      },
    );

    test(
      '2. TaskList.complete on mixed Daily (interval 3) and Monthly (dayOfMonth 15) under Stack policy',
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
          id: 'mixed-daily-monthly-stack',
          title: 'Daily + Monthly Stack',
          description: 'Test',
          schedules: schedules,
          missedPolicy: MissedPolicy.stack,
        );

        final taskList = TaskList([task]);

        // Overdue complete on Tuesday, June 9 (Daily was due June 1, 4, 7. Monthly is due June 15)
        AppClock.setMockTime(DateTime(2026, 6, 9, 12, 0));
        addTearDown(AppClock.reset);
        final state = taskList.complete(task.id);
        final updated = state.activeTasks.first;

        // Daily should shift to next occurrence after June 9: June 10 (since 1 + 3*3 = 10)
        expect(
          (updated.schedules[0] as DailySchedule).startDate,
          const CivilDay(year: 2026, month: 6, day: 10),
        );
        // Monthly should remain on June 1 (since it hasn't occurred yet, first occurrence is June 15)
        expect(
          (updated.schedules[1] as MonthlySchedule).startDate,
          const CivilDay(year: 2026, month: 6, day: 1),
        );
      },
    );

    test(
      '3. TaskList.complete on mixed Weekly (Fri) and Yearly (Dec 25) under Stack policy',
      () {
        final start = const CivilDay(year: 2026, month: 12, day: 21);
        final schedules = [
          WeeklySchedule(
            startDate: start,
            interval: 1,
            daysOfWeek: const {5}, // Friday
          ),
          YearlySchedule(startDate: start, interval: 1, month: 12, day: 25),
        ];

        final task = TaskSchedule(
          id: 'mixed-weekly-yearly-stack',
          title: 'Weekly + Yearly Stack',
          description: 'Test',
          schedules: schedules,
          missedPolicy: MissedPolicy.stack,
        );

        final taskList = TaskList([task]);

        // Complete on Friday, Dec 25, 2026 (Both Weekly and Yearly occur!)
        // Dec 25, 2026 is indeed a Friday.
        AppClock.setMockTime(DateTime(2026, 12, 25, 12, 0));
        addTearDown(AppClock.reset);
        final state = taskList.complete(task.id);
        final updated = state.activeTasks.first;

        // Weekly advances to Jan 1, 2027 (Next Friday after completion date Dec 25)
        expect(
          (updated.schedules[0] as WeeklySchedule).startDate,
          const CivilDay(year: 2027, month: 1, day: 1),
        );
        // Yearly advances to Dec 25, 2027 (Next Dec 25 after completion date Dec 25)
        expect(
          (updated.schedules[1] as YearlySchedule).startDate,
          const CivilDay(year: 2027, month: 12, day: 25),
        );
      },
    );

    test(
      '4. TaskList.complete on all 5 schedule types mixed under Stack policy',
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
          missedPolicy: MissedPolicy.stack,
        );

        final taskList = TaskList([task]);

        // Complete on June 1, 2026
        AppClock.setMockTime(DateTime(2026, 6, 1, 12, 0));
        addTearDown(AppClock.reset);
        final state = taskList.complete(task.id);
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
          const CivilDay(year: 2026, month: 6, day: 1),
        ); // Weekly NOT advanced (first occurrence June 3 is in future)
        expect(updated.schedules[2], isA<MonthlySchedule>());
        expect(
          (updated.schedules[2] as MonthlySchedule).startDate,
          const CivilDay(year: 2026, month: 6, day: 1),
        ); // Monthly NOT advanced (first occurrence June 15 is in future)
        expect(updated.schedules[3], isA<YearlySchedule>());
        expect(
          (updated.schedules[3] as YearlySchedule).startDate,
          const CivilDay(year: 2026, month: 6, day: 1),
        ); // Yearly NOT advanced (first occurrence Dec 25 is in future)
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
        addTearDown(AppClock.reset);
        var state = taskList.complete(task.id);
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
        state = state.complete(task.id);
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
      },
    );

    test(
      '6. TaskRepository missed policies: Stack policy on mixed Daily (interval 2) and Weekly (Wed, Fri) schedules',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repository = TaskRepository(firestore: firestore, userId: userId);

        final start = const CivilDay(year: 2026, month: 6, day: 1); // Monday
        final task = TaskSchedule(
          id: 'repo-stack-mixed',
          title: 'Mixed Stack Repo',
          description: 'Test',
          schedules: [
            DailySchedule(startDate: start, interval: 2),
            WeeklySchedule(
              startDate: start,
              interval: 1,
              daysOfWeek: const {3, 5},
            ),
          ],
          missedPolicy: MissedPolicy.stack,
        );

        // Add task on Mon June 1
        AppClock.setMockTime(DateTime(2026, 6, 1, 10, 0));
        addTearDown(AppClock.reset);
        await repository.addTaskSchedule(task);
        await Future.delayed(Duration.zero);

        // Verify Monday instances spawned
        final instsBefore = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .get();

        final dailyRule = task.schedules[0];
        final weeklyRule = task.schedules[1];

        expect(instsBefore.docs.length, 16);
        expect(
          instsBefore.docs.any(
            (d) => matchInst(
              d,
              dailyRule.id,
              const CivilDay(year: 2026, month: 6, day: 1),
            ),
          ),
          isTrue,
        );
        expect(
          instsBefore.docs.any(
            (d) => matchInst(
              d,
              dailyRule.id,
              const CivilDay(year: 2026, month: 6, day: 3),
            ),
          ),
          isTrue,
        );
        expect(
          instsBefore.docs.any(
            (d) => matchInst(
              d,
              weeklyRule.id,
              const CivilDay(year: 2026, month: 6, day: 3),
            ),
          ),
          isTrue,
        );
      },
    );

    test(
      '7. TaskRepository missed policies: Auto-dismiss with zero grace period on mixed Weekly (Mon) and Monthly (dayOfMonth 1) schedules',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repository = TaskRepository(firestore: firestore, userId: userId);

        final start = const CivilDay(year: 2026, month: 6, day: 1); // Monday
        final task = TaskSchedule(
          id: 'repo-autodismiss-mixed',
          title: 'Mixed Auto-dismiss Repo',
          description: 'Test',
          schedules: [
            WeeklySchedule(
              startDate: start,
              interval: 1,
              daysOfWeek: const {1},
              missedOccurrencePolicy: const MissedOccurrencePolicy.autoDismiss(
                gracePeriod: Duration.zero,
              ),
            ),
            MonthlySchedule(
              startDate: start,
              interval: 1,
              dayOfMonth: 1,
              missedOccurrencePolicy: const MissedOccurrencePolicy.autoDismiss(
                gracePeriod: Duration.zero,
              ),
            ),
          ],
        );

        // Add task on Mon June 1
        AppClock.setMockTime(DateTime(2026, 6, 1, 10, 0));
        addTearDown(AppClock.reset);
        await repository.addTaskSchedule(task);
        await Future.delayed(Duration.zero);

        // Mock time to Tue June 9. Mon June 8 Weekly is missed, and June 1 Weekly & Monthly are missed.
        AppClock.setMockTime(DateTime(2026, 6, 9, 10, 0));
        addTearDown(AppClock.reset);
        await repository.getTasks().first;
        await Future.delayed(Duration.zero);

        final weeklyRule = task.schedules[0];
        final monthlyRule = task.schedules[1];

        final insts = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .get();

        // Verify missed instances are marked skipped
        final weeklyJune1 = insts.docs.firstWhere(
          (d) => matchInst(
            d,
            weeklyRule.id,
            const CivilDay(year: 2026, month: 6, day: 1),
          ),
        );
        final monthlyJune1 = insts.docs.firstWhere(
          (d) => matchInst(
            d,
            monthlyRule.id,
            const CivilDay(year: 2026, month: 6, day: 1),
          ),
        );

        expect(weeklyJune1.data()['status'], 'skipped');
        expect(monthlyJune1.data()['status'], 'skipped');

        // Weekly June 8 is backfilled and marked skipped
        final weeklyJune8 = insts.docs.firstWhere(
          (d) => matchInst(
            d,
            weeklyRule.id,
            const CivilDay(year: 2026, month: 6, day: 8),
          ),
        );
        expect(weeklyJune8.data()['status'], 'skipped');

        // Next instances should be spawned:
        // Weekly next after June 9: Mon June 15
        // Monthly next after June 9: July 1
        final weeklyJune15 = insts.docs.firstWhere(
          (d) => matchInst(
            d,
            weeklyRule.id,
            const CivilDay(year: 2026, month: 6, day: 15),
          ),
        );
        final monthlyJuly1 = insts.docs.firstWhere(
          (d) => matchInst(
            d,
            monthlyRule.id,
            const CivilDay(year: 2026, month: 7, day: 1),
          ),
        );
        expect(weeklyJune15.data()['status'], 'pending');
        expect(monthlyJuly1.data()['status'], 'pending');
      },
    );

    test(
      '7b. TaskRepository missed policies: Auto-dismiss backfill cap at 30 days',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repository = TaskRepository(firestore: firestore, userId: userId);

        final start = const CivilDay(year: 2026, month: 6, day: 1);
        final task = TaskSchedule(
          id: 'repo-autodismiss-cap',
          title: 'Auto-dismiss Cap Repo',
          description: 'Test',
          schedules: [
            DailySchedule(
              startDate: start,
              interval: 1,
              missedOccurrencePolicy: const MissedOccurrencePolicy.autoDismiss(
                gracePeriod: Duration.zero,
              ),
            ),
          ],
        );

        // Add task on June 1
        AppClock.setMockTime(DateTime(2026, 6, 1, 10, 0));
        addTearDown(AppClock.reset);
        await repository.addTaskSchedule(task);
        await Future.delayed(Duration.zero);

        // Mock time to July 16 (45 days later)
        AppClock.setMockTime(DateTime(2026, 7, 16, 10, 0));
        addTearDown(AppClock.reset);
        await repository.getTasks().first;
        await Future.delayed(Duration.zero);

        // Get all instances
        final insts = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .get();

        // 1 instance existed for June 1 (transitioned to skipped)
        // 30 additional instances backfilled (June 2 through July 1)
        // 1 new pending instance spawned (for July 16)
        // Total instances should be 32 (1 + 30 + 1)
        final skippedCount = insts.docs
            .where((d) => d.data()['status'] == 'skipped')
            .length;
        final pendingCount = insts.docs
            .where((d) => d.data()['status'] == 'pending')
            .length;

        expect(skippedCount, 31); // June 1 + 30 backfilled (June 2 to July 1)
        expect(
          pendingCount,
          0,
        ); // July 16 is not spawned yet due to the 30-day backfill cap
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
        addTearDown(AppClock.reset);
        await repository.addTaskSchedule(task);
        await Future.delayed(Duration.zero);

        // Mock time to Wed June 3. Daily should have instances for June 1, 2, 3. Weekly should have instance for June 3.
        AppClock.setMockTime(DateTime(2026, 6, 3, 10, 0));
        addTearDown(AppClock.reset);
        await repository.getTasks().first;
        await Future.delayed(Duration.zero);

        final insts = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .get();

        final dailyRule = task.schedules[0];
        final weeklyRule = task.schedules[1];

        // Expect 18 instances: Daily (June 1-11) + Weekly (June 3, 10, 17, 24, July 1)
        expect(insts.docs.length, 18);
        expect(
          insts.docs.any(
            (d) => matchInst(
              d,
              dailyRule.id,
              const CivilDay(year: 2026, month: 6, day: 1),
            ),
          ),
          isTrue,
        );
        expect(
          insts.docs.any(
            (d) => matchInst(
              d,
              dailyRule.id,
              const CivilDay(year: 2026, month: 6, day: 2),
            ),
          ),
          isTrue,
        );
        expect(
          insts.docs.any(
            (d) => matchInst(
              d,
              dailyRule.id,
              const CivilDay(year: 2026, month: 6, day: 3),
            ),
          ),
          isTrue,
        );
        expect(
          insts.docs.any(
            (d) => matchInst(
              d,
              dailyRule.id,
              const CivilDay(year: 2026, month: 6, day: 4),
            ),
          ),
          isTrue,
        );
        expect(
          insts.docs.any(
            (d) => matchInst(
              d,
              weeklyRule.id,
              const CivilDay(year: 2026, month: 6, day: 3),
            ),
          ),
          isTrue,
        );
        expect(
          insts.docs.any(
            (d) => matchInst(
              d,
              weeklyRule.id,
              const CivilDay(year: 2026, month: 6, day: 10),
            ),
          ),
          isTrue,
        );
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
        addTearDown(AppClock.reset);
        await repository.addTaskSchedule(task);
        await Future.delayed(Duration.zero);

        // Mock time to Wed June 3.
        // OneOff occurrences: June 1.
        // Daily occurrences: June 1, 2, 3.
        // Weekly occurrences: June 3.
        AppClock.setMockTime(DateTime(2026, 6, 3, 10, 0));
        addTearDown(AppClock.reset);
        await repository.getTasks().first;
        await Future.delayed(Duration.zero);

        final insts = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .get();

        final oneOffRule = task.schedules[0];
        final dailyRule = task.schedules[1];
        final weeklyRule = task.schedules[2];
        final monthlyRule = task.schedules[3];
        final yearlyRule = task.schedules[4];

        // Total: 1 (OneOff) + 13 (Daily) + 5 (Weekly) + 2 (Monthly) + 1 (Yearly) = 22 instances.
        expect(insts.docs.length, 22);

        expect(
          insts.docs.any(
            (d) => matchInst(
              d,
              oneOffRule.id,
              const CivilDay(year: 2026, month: 6, day: 1),
            ),
          ),
          isTrue,
        );
        expect(
          insts.docs.any(
            (d) => matchInst(
              d,
              dailyRule.id,
              const CivilDay(year: 2026, month: 6, day: 1),
            ),
          ),
          isTrue,
        );
        expect(
          insts.docs.any(
            (d) => matchInst(
              d,
              dailyRule.id,
              const CivilDay(year: 2026, month: 6, day: 2),
            ),
          ),
          isTrue,
        );
        expect(
          insts.docs.any(
            (d) => matchInst(
              d,
              dailyRule.id,
              const CivilDay(year: 2026, month: 6, day: 3),
            ),
          ),
          isTrue,
        );
        expect(
          insts.docs.any(
            (d) => matchInst(
              d,
              dailyRule.id,
              const CivilDay(year: 2026, month: 6, day: 4),
            ),
          ),
          isTrue,
        );
        expect(
          insts.docs.any(
            (d) => matchInst(
              d,
              weeklyRule.id,
              const CivilDay(year: 2026, month: 6, day: 3),
            ),
          ),
          isTrue,
        );
        expect(
          insts.docs.any(
            (d) => matchInst(
              d,
              weeklyRule.id,
              const CivilDay(year: 2026, month: 6, day: 10),
            ),
          ),
          isTrue,
        );
        expect(
          insts.docs.any(
            (d) => matchInst(
              d,
              monthlyRule.id,
              const CivilDay(year: 2026, month: 6, day: 15),
            ),
          ),
          isTrue,
        );
        expect(
          insts.docs.any(
            (d) => matchInst(
              d,
              yearlyRule.id,
              const CivilDay(year: 2026, month: 12, day: 25),
            ),
          ),
          isTrue,
        );
      },
    );

    test(
      '11. TaskRepository completion: Stack policy completion spawns correct next occurrences in mixed schedules',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repository = TaskRepository(firestore: firestore, userId: userId);

        final start = const CivilDay(year: 2026, month: 6, day: 1); // Monday
        final task = TaskSchedule(
          id: 'repo-stack-complete',
          title: 'Mixed Stack Complete',
          description: 'Test',
          schedules: [
            DailySchedule(startDate: start, interval: 2),
            WeeklySchedule(
              startDate: start,
              interval: 1,
              daysOfWeek: const {1, 3},
            ),
          ],
          missedPolicy: MissedPolicy.stack,
        );

        // Add task on Mon June 1
        AppClock.setMockTime(DateTime(2026, 6, 1, 10, 0));
        addTearDown(AppClock.reset);
        await repository.addTaskSchedule(task);
        await Future.delayed(Duration.zero);

        final dailyRule = task.schedules[0];

        final instsBefore = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .get();

        final dailyJune1 = instsBefore.docs.firstWhere(
          (d) => matchInst(
            d,
            dailyRule.id,
            const CivilDay(year: 2026, month: 6, day: 1),
          ),
        );

        // Complete Daily instance on June 1
        await repository.completeTaskInstance(dailyJune1.id);
        await Future.delayed(Duration.zero);

        // Fast-forward to June 3
        AppClock.setMockTime(DateTime(2026, 6, 3, 10, 0));
        addTearDown(AppClock.reset);
        await repository.triggerMissedPolicyProcessing();
        await Future.delayed(Duration.zero);

        final insts = await firestore
            .collection('users')
            .doc(userId)
            .collection('instances')
            .get();

        // Completing the Daily instance (June 1) should spawn the next occurrence after June 1.
        // Daily next after June 1 is June 3.
        // Weekly next after June 1 is June 3.
        // Let's verify that a new pending Daily instance for June 3 is created.
        expect(
          insts.docs.any(
            (d) =>
                matchInst(
                  d,
                  dailyRule.id,
                  const CivilDay(year: 2026, month: 6, day: 3),
                ) &&
                d.data()['status'] == 'pending',
          ),
          isTrue,
        );
      },
    );

    group('Multiple Rules & Nested Policies Tests', () {
      test(
        'supports different policies on different rules in the same TaskSchedule',
        () async {
          final task = TaskSchedule(
            id: 'multi-rule-policies-task',
            title: 'Mixed Policies Task',
            description: 'Testing independent rule policies',
            schedules: [
              DailySchedule(
                startDate: const CivilDay(year: 2026, month: 6, day: 1),
                interval: 1,
                schedulingPolicy: const FixedCalendarPolicy(),
                missedOccurrencePolicy: const MissedOccurrencePolicy.stack(),
              ),
              WeeklySchedule(
                startDate: const CivilDay(year: 2026, month: 6, day: 1),
                interval: 1,
                daysOfWeek: const {1, 3, 5},
                schedulingPolicy: const CompletionRelativePolicy(
                  interval: Duration(days: 3),
                  targetTime: TimeOfDay(hour: 15, minute: 0),
                ),
                missedOccurrencePolicy:
                    const MissedOccurrencePolicy.autoDismiss(
                      gracePeriod: Duration(hours: 12),
                    ),
              ),
            ],
          );

          // Verify model representation
          expect(task.schedules.length, 2);
          expect(
            task.schedules[0].schedulingPolicy,
            isA<FixedCalendarPolicy>(),
          );
          expect(task.schedules[0].missedOccurrencePolicy.isKeepAround, isTrue);

          expect(
            task.schedules[1].schedulingPolicy,
            isA<CompletionRelativePolicy>(),
          );
          final relPolicy =
              task.schedules[1].schedulingPolicy as CompletionRelativePolicy;
          expect(relPolicy.interval, const Duration(days: 3));
          expect(relPolicy.targetTime, const TimeOfDay(hour: 15, minute: 0));
          expect(
            task.schedules[1].missedOccurrencePolicy.isAutoDismiss,
            isTrue,
          );
          expect(
            task.schedules[1].missedOccurrencePolicy.gracePeriod,
            const Duration(hours: 12),
          );

          // Test toFirestore serialization
          final map = task.toFirestore();
          final rulesList = map['schedules'] as List<dynamic>;
          expect(rulesList.length, 2);

          // Rule 0 checks
          expect(rulesList[0]['type'], 'daily');
          expect(rulesList[0]['schedulingPolicy']['type'], 'fixedCalendar');
          expect(rulesList[0]['missedOccurrencePolicy']['type'], 'keepAround');

          // Rule 1 checks
          expect(rulesList[1]['type'], 'weekly');
          expect(
            rulesList[1]['schedulingPolicy']['type'],
            'completionRelative',
          );
          expect(
            rulesList[1]['schedulingPolicy']['intervalMinutes'],
            3 * 24 * 60,
          );
          expect(rulesList[1]['schedulingPolicy']['targetHour'], 15);
          expect(rulesList[1]['schedulingPolicy']['targetMinute'], 0);
          expect(rulesList[1]['missedOccurrencePolicy']['type'], 'autoDismiss');
          expect(
            rulesList[1]['missedOccurrencePolicy']['graceMinutes'],
            12 * 60,
          );

          // Test fromFirestore deserialization
          final firestore = FakeFirebaseFirestore();
          await firestore
              .collection('tasks')
              .doc('multi-rule-policies-task')
              .set(map);
          final snapshot = await firestore
              .collection('tasks')
              .doc('multi-rule-policies-task')
              .get();
          final deserialized = TaskSchedule.fromFirestore(snapshot);

          expect(deserialized.schedules.length, 2);
          expect(
            deserialized.schedules[0].schedulingPolicy,
            isA<FixedCalendarPolicy>(),
          );
          expect(
            deserialized.schedules[0].missedOccurrencePolicy.isKeepAround,
            isTrue,
          );

          expect(
            deserialized.schedules[1].schedulingPolicy,
            isA<CompletionRelativePolicy>(),
          );
          final desRelPolicy =
              deserialized.schedules[1].schedulingPolicy
                  as CompletionRelativePolicy;
          expect(desRelPolicy.interval, const Duration(days: 3));
          expect(
            deserialized.schedules[1].missedOccurrencePolicy.isAutoDismiss,
            isTrue,
          );
          expect(
            deserialized.schedules[1].missedOccurrencePolicy.gracePeriod,
            const Duration(hours: 12),
          );
        },
      );

      test(
        'edit updates independent rules and correctly computes changes map',
        () {
          final task = TaskSchedule(
            id: 'edit-multi-task',
            title: 'Task Title',
            description: 'Desc',
            schedules: [
              DailySchedule(
                startDate: const CivilDay(year: 2026, month: 6, day: 1),
                interval: 1,
                schedulingPolicy: const FixedCalendarPolicy(),
                missedOccurrencePolicy: const MissedOccurrencePolicy.stack(),
              ),
            ],
          );

          // Edit the rule to have autoDismiss missedOccurrencePolicy and completionRelative schedulingPolicy
          final editResult = task.edit(
            newTitle: 'Task Title',
            newDescription: 'Desc',
            newSchedules: [
              DailySchedule(
                startDate: const CivilDay(year: 2026, month: 6, day: 1),
                interval: 1,
                schedulingPolicy: const CompletionRelativePolicy(
                  interval: Duration(days: 1),
                  targetTime: TimeOfDay(hour: 9, minute: 0),
                ),
                missedOccurrencePolicy:
                    const MissedOccurrencePolicy.autoDismiss(
                      gracePeriod: Duration(hours: 2),
                    ),
              ),
            ],
            newEstimatedDuration: null,
            newMissedPolicy: MissedPolicy.autoDismiss,
            newIsMaster: false,
            newLastSpawnedDate: null,
            newIsFamily: false,
            newPriority: TaskPriority.medium,
          );

          final updatedTask = editResult.newTask;
          final changes = editResult.changes;

          // Verify new values on the rule
          expect(
            updatedTask.schedules.first.schedulingPolicy,
            isA<CompletionRelativePolicy>(),
          );
          expect(
            updatedTask.schedules.first.missedOccurrencePolicy.isAutoDismiss,
            isTrue,
          );

          // Verify updates are recorded in changes map
          expect(changes.containsKey('schedules'), isTrue);
          expect(
            changes['schedules'][0]['schedulingPolicy']['type'],
            'completionRelative',
          );
          expect(
            changes['schedules'][0]['missedOccurrencePolicy']['type'],
            'autoDismiss',
          );
          expect(
            changes['schedules'][0]['missedOccurrencePolicy']['graceMinutes'],
            120,
          );
        },
      );
    });

    group('Completion-Relative Scheduling Policy Tests', () {
      test('Initial Spawning spawns on scheduledDate', () async {
        final firestore = FakeFirebaseFirestore();
        final repository = TaskRepository(
          firestore: firestore,
          userId: 'user-1',
        );
        final monday = const CivilDay(year: 2026, month: 5, day: 25);

        final task = TaskSchedule(
          id: 'comp-relative-spawn',
          title: 'Comp Relative Spawn',
          description: 'Testing initial spawn',
          schedules: [
            DailySchedule(
              startDate: monday,
              interval: 1,
              schedulingPolicy: const CompletionRelativePolicy(
                interval: Duration(days: 3),
                targetTime: TimeOfDay(hour: 10, minute: 0),
              ),
              missedOccurrencePolicy: const MissedOccurrencePolicy.stack(),
            ),
          ],
        );

        AppClock.setMockTime(DateTime(2026, 5, 25, 9, 0));
        addTearDown(AppClock.reset);
        await repository.addTaskSchedule(task);
        await Future.delayed(Duration.zero);

        final insts = await firestore
            .collection('users')
            .doc('user-1')
            .collection('instances')
            .get();
        expect(insts.docs.length, 1);
        final instSnap = insts.docs.first;
        expect(instSnap.data()['status'], 'pending');
        expect(instSnap.data()['scheduledDate']['year'], 2026);
        expect(instSnap.data()['scheduledDate']['month'], 5);
        expect(instSnap.data()['scheduledDate']['day'], 25);
      });

      test(
        'Completion spawns next instance exactly interval after completion time',
        () async {
          final firestore = FakeFirebaseFirestore();
          final repository = TaskRepository(
            firestore: firestore,
            userId: 'user-1',
          );
          final monday = const CivilDay(year: 2026, month: 5, day: 25);

          final task = TaskSchedule(
            id: 'comp-relative-complete',
            title: 'Comp Relative Complete',
            description: 'Testing completion spawn',
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
                schedulingPolicy: const CompletionRelativePolicy(
                  interval: Duration(days: 3),
                  targetTime: TimeOfDay(hour: 10, minute: 0),
                ),
              ),
            ],
          );

          // Monday May 25, 9:00 AM - initial spawned
          AppClock.setMockTime(DateTime(2026, 5, 25, 9, 0));
          addTearDown(AppClock.reset);
          await repository.addTaskSchedule(task);
          await Future.delayed(Duration.zero);

          final insts = await firestore
              .collection('users')
              .doc('user-1')
              .collection('instances')
              .get();
          final firstInst = insts.docs.firstWhere(
            (d) => d.data()['scheduledDate']['day'] == 25,
          );

          // User completes it on Wednesday May 27 at 2:00 PM
          final completionTime = DateTime(2026, 5, 27, 14, 0);
          AppClock.setMockTime(completionTime);
          addTearDown(AppClock.reset);

          await repository.completeTaskInstance(firstInst.id);
          await Future.delayed(Duration.zero);

          // Next scheduledDate is completionTime + 3 days = Saturday May 30
          final nextInstsBefore = await firestore
              .collection('users')
              .doc('user-1')
              .collection('instances')
              .get();
          final nextExistsBefore = nextInstsBefore.docs.any(
            (d) => d.data()['scheduledDate']['day'] == 30,
          );
          expect(nextExistsBefore, isTrue);

          // Fast forward to Saturday May 30 at 2:00 PM (14:00) when it is due
          AppClock.setMockTime(DateTime(2026, 5, 30, 14, 0));
          addTearDown(AppClock.reset);
          await repository.triggerMissedPolicyProcessing();
          await Future.delayed(Duration.zero);

          final nextInstsAfter = await firestore
              .collection('users')
              .doc('user-1')
              .collection('instances')
              .get();
          final nextSnap = nextInstsAfter.docs.firstWhere(
            (d) => d.data()['scheduledDate']['day'] == 30,
          );
          expect(nextSnap.data()['status'], 'pending');
          expect(nextSnap.data()['scheduledDate']['year'], 2026);
          expect(nextSnap.data()['scheduledDate']['month'], 5);
          expect(nextSnap.data()['scheduledDate']['day'], 30);

          // Verify startRelativeTime is targetTime (10:00 AM)
          expect(nextSnap.data()['startRelativeTime']['hour'], 10);
          expect(nextSnap.data()['startRelativeTime']['minute'], 0);

          // Verify dueRelativeTime maintains original duration of 8 hours (10:00 AM -> 6:00 PM)
          expect(nextSnap.data()['dueRelativeTime']['hour'], 18);
          expect(nextSnap.data()['dueRelativeTime']['minute'], 0);
        },
      );

      test('Completion-Relative tasks ignore Auto-Dismiss policy', () async {
        final firestore = FakeFirebaseFirestore();
        final repository = TaskRepository(
          firestore: firestore,
          userId: 'user-1',
        );
        final monday = const CivilDay(year: 2026, month: 5, day: 25);

        final task = TaskSchedule(
          id: 'comp-relative-ignore-dismiss',
          title: 'Comp Relative Ignore Dismiss',
          description: 'Testing ignore dismiss',
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
              schedulingPolicy: const CompletionRelativePolicy(
                interval: Duration(days: 3),
                targetTime: TimeOfDay(hour: 10, minute: 0),
              ),
              missedOccurrencePolicy: const MissedOccurrencePolicy.autoDismiss(
                gracePeriod: Duration(hours: 1),
              ),
            ),
          ],
        );

        AppClock.setMockTime(DateTime(2026, 5, 25, 9, 0));
        addTearDown(AppClock.reset);
        await repository.addTaskSchedule(task);
        await Future.delayed(Duration.zero);

        final insts = await firestore
            .collection('users')
            .doc('user-1')
            .collection('instances')
            .get();
        final firstInst = insts.docs.first;

        // Fast forward past due time (5:00 PM) and grace period (1 hour) to 7:00 PM
        AppClock.setMockTime(DateTime(2026, 5, 25, 19, 0));
        addTearDown(AppClock.reset);
        await repository.getTasks().first; // trigger evaluation
        await Future.delayed(Duration.zero);

        // Verify task instance is STILL pending (not skipped/dismissed)
        final instSnap = await firestore
            .collection('users')
            .doc('user-1')
            .collection('instances')
            .doc(firstInst.id)
            .get();
        expect(instSnap.data()!['status'], 'pending');
      });

      test(
        'Spawning triggers on interval expiration if pending instance is deleted',
        () async {
          final firestore = FakeFirebaseFirestore();
          final repository = TaskRepository(
            firestore: firestore,
            userId: 'user-1',
          );
          final monday = const CivilDay(year: 2026, month: 5, day: 25);

          final task = TaskSchedule(
            id: 'comp-relative-bg-spawn',
            title: 'Comp Relative BG Spawn',
            description: 'Testing bg spawn',
            schedules: [
              DailySchedule(
                startDate: monday,
                interval: 1,
                schedulingPolicy: const CompletionRelativePolicy(
                  interval: Duration(days: 3),
                  targetTime: TimeOfDay(hour: 10, minute: 0),
                ),
              ),
            ],
          );

          AppClock.setMockTime(DateTime(2026, 5, 25, 9, 0));
          addTearDown(AppClock.reset);
          await repository.addTaskSchedule(task);
          await Future.delayed(Duration.zero);

          final insts = await firestore
              .collection('users')
              .doc('user-1')
              .collection('instances')
              .get();
          final firstInst = insts.docs.firstWhere(
            (d) => d.data()['scheduledDate']['day'] == 25,
          );

          // Complete the first instance
          final completionTime = DateTime(2026, 5, 25, 11, 0);
          AppClock.setMockTime(completionTime);
          addTearDown(AppClock.reset);
          await repository.completeTaskInstance(firstInst.id);
          await Future.delayed(Duration.zero);

          // Fast forward to May 28 at 12:00 PM (noon) when it is due
          AppClock.setMockTime(DateTime(2026, 5, 28, 12, 0));
          addTearDown(AppClock.reset);
          await repository.triggerMissedPolicyProcessing();
          await Future.delayed(Duration.zero);

          // A new pending instance for May 28 should now be spawned
          final nextInsts = await firestore
              .collection('users')
              .doc('user-1')
              .collection('instances')
              .get();
          final nextInst = nextInsts.docs.firstWhere(
            (d) =>
                d.data()['scheduledDate']['day'] == 28 &&
                d.data()['status'] == 'pending',
          );

          // Delete that pending instance to simulate it missing
          await firestore
              .collection('users')
              .doc('user-1')
              .collection('instances')
              .doc(nextInst.id)
              .delete();

          // 1. Time is before completionTime + 3 days (e.g. May 27)
          AppClock.setMockTime(DateTime(2026, 5, 27, 12, 0));
          addTearDown(AppClock.reset);
          await repository.getTasks().first; // trigger evaluation
          await Future.delayed(Duration.zero);

          // Verify still no pending instance exists
          final instsAfterDelete1 = await firestore
              .collection('users')
              .doc('user-1')
              .collection('instances')
              .get();
          final existsOn28Day27 = instsAfterDelete1.docs.any(
            (d) =>
                d.data()['scheduledDate']['day'] == 28 &&
                d.data()['status'] == 'pending',
          );
          expect(existsOn28Day27, isFalse);

          // 2. Time is on or after completionTime + 3 days (e.g. May 28, 12:00 PM)
          AppClock.setMockTime(DateTime(2026, 5, 28, 12, 0));
          addTearDown(AppClock.reset);
          await repository.getTasks().first; // trigger evaluation
          await Future.delayed(Duration.zero);

          // Verify that the background scheduler has spawned the next instance
          final instsAfterDelete2 = await firestore
              .collection('users')
              .doc('user-1')
              .collection('instances')
              .get();
          final existsOn28Day28 = instsAfterDelete2.docs.any(
            (d) =>
                d.data()['scheduledDate']['day'] == 28 &&
                d.data()['status'] == 'pending',
          );
          expect(existsOn28Day28, isTrue);
        },
      );
    });
  });
}
