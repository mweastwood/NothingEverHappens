import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test_factories.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_spawner_engine.dart';

void main() {
  group('TaskSpawnerEngine', () {
    const defaultRuleId = 'R-rule-daily-1';
    const defaultTaskId = 'S-task-1';

    TaskSchedule createSampleTask({
      String id = defaultTaskId,
      String title = 'Daily Exercise',
      String description = 'Do 30 mins workout',
      List<TaskScheduleRule>? schedules,
      TaskPriority priority = TaskPriority.medium,
      bool isFamily = false,
      FamilyCompletionMode familyCompletionMode =
          FamilyCompletionMode.individual,
      String? assignedUserId = 'user-1',
      Duration? estimatedDuration = const Duration(minutes: 30),
      bool skipIfNoCapacity = false,
    }) {
      return TaskSchedule(
        id: id,
        title: title,
        description: description,
        schedules:
            schedules ??
            [
              DailySchedule(
                id: defaultRuleId,
                startDate: const CivilDay(year: 2026, month: 6, day: 1),
                interval: 1,
                startRelativeTime: const RelativeTime(
                  dayOffset: 0,
                  time: TimeOfDay(hour: 9, minute: 0),
                ),
                dueRelativeTime: const RelativeTime(
                  dayOffset: 0,
                  time: TimeOfDay(hour: 10, minute: 0),
                ),
                missedOccurrencePolicy: const MissedOccurrencePolicy.stack(),
              ),
            ],
        priority: priority,
        isFamily: isFamily,
        familyCompletionMode: familyCompletionMode,
        assignedUserId: assignedUserId,
        estimatedDuration: estimatedDuration,
        skipIfNoCapacity: skipIfNoCapacity,
      );
    }

    group('computeScheduleSignature', () {
      test(
        'produces deterministic signature for identical task configurations',
        () {
          final task1 = createSampleTask();
          final task2 = createSampleTask();

          final signature1 = TaskSpawnerEngine.computeScheduleSignature(task1);
          final signature2 = TaskSpawnerEngine.computeScheduleSignature(task2);

          expect(signature1, equals(signature2));
          expect(
            signature1,
            equals(TaskSpawnerEngine.computeScheduleSignature(task1)),
          );
        },
      );

      test('correctly serializes all schedule configuration fields', () {
        final task = createSampleTask();
        final signature = TaskSpawnerEngine.computeScheduleSignature(task);
        final decoded = jsonDecode(signature) as Map<String, dynamic>;

        expect(decoded['rules'], hasLength(1));
        expect(decoded['futureInstancesCount'], equals(10));
        expect(decoded['estimatedDuration'], equals(30));
        expect(decoded['priority'], equals('medium'));
        expect(decoded['skipIfNoCapacity'], isFalse);
        expect(decoded['missedPolicy'], equals('stack'));
        expect(decoded['assignedUserId'], equals('user-1'));
        expect(decoded['isFamily'], isFalse);
        expect(decoded['familyCompletionMode'], equals('individual'));
      });

      test('alters signature when rules are modified', () {
        final base = createSampleTask();
        final baseSig = TaskSpawnerEngine.computeScheduleSignature(base);

        final modifiedRule = TaskSchedule(
          id: base.id,
          title: base.title,
          description: base.description,
          schedules: [
            DailySchedule(
              id: defaultRuleId,
              startDate: const CivilDay(
                year: 2026,
                month: 6,
                day: 2,
              ), // Changed date
              interval: 2, // Changed interval
              startRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 9, minute: 0),
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 10, minute: 0),
              ),
            ),
          ],
          priority: base.priority,
          isFamily: base.isFamily,
          familyCompletionMode: base.familyCompletionMode,
          assignedUserId: base.assignedUserId,
          estimatedDuration: base.estimatedDuration,
          skipIfNoCapacity: base.skipIfNoCapacity,
        );

        final modSig = TaskSpawnerEngine.computeScheduleSignature(modifiedRule);
        expect(modSig, isNot(equals(baseSig)));
      });

      test('alters signature when futureInstancesCount changes', () {
        final base =
            createSampleTask(); // DailySchedule -> futureInstancesCount = 10
        final baseSig = TaskSpawnerEngine.computeScheduleSignature(base);

        final weeklyTask = createSampleTask(
          schedules: [
            WeeklySchedule(
              id: 'R-rule-weekly-1',
              startDate: const CivilDay(year: 2026, month: 6, day: 1),
              interval: 1,
              daysOfWeek: {DateTime.monday},
              startRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 9, minute: 0),
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 10, minute: 0),
              ),
            ),
          ],
        ); // WeeklySchedule -> futureInstancesCount = 5

        final weeklySig = TaskSpawnerEngine.computeScheduleSignature(
          weeklyTask,
        );
        expect(weeklySig, isNot(equals(baseSig)));
        final decoded = jsonDecode(weeklySig) as Map<String, dynamic>;
        expect(decoded['futureInstancesCount'], equals(5));
      });

      test('alters signature when estimatedDuration changes', () {
        final base = createSampleTask(
          estimatedDuration: const Duration(minutes: 30),
        );
        final baseSig = TaskSpawnerEngine.computeScheduleSignature(base);

        final modified = createSampleTask(
          estimatedDuration: const Duration(minutes: 45),
        );
        final modSig = TaskSpawnerEngine.computeScheduleSignature(modified);
        expect(modSig, isNot(equals(baseSig)));

        final nullDurationTask = createSampleTask(estimatedDuration: null);
        final nullSig = TaskSpawnerEngine.computeScheduleSignature(
          nullDurationTask,
        );
        expect(nullSig, isNot(equals(baseSig)));
        final decodedNull = jsonDecode(nullSig) as Map<String, dynamic>;
        expect(decodedNull['estimatedDuration'], isNull);
      });

      test('alters signature when priority changes', () {
        final base = createSampleTask(priority: TaskPriority.medium);
        final baseSig = TaskSpawnerEngine.computeScheduleSignature(base);

        final highPriority = createSampleTask(priority: TaskPriority.high);
        final highSig = TaskSpawnerEngine.computeScheduleSignature(
          highPriority,
        );
        expect(highSig, isNot(equals(baseSig)));

        final lowPriority = createSampleTask(priority: TaskPriority.low);
        final lowSig = TaskSpawnerEngine.computeScheduleSignature(lowPriority);
        expect(lowSig, isNot(equals(baseSig)));
        expect(lowSig, isNot(equals(highSig)));
      });

      test('alters signature when skipIfNoCapacity changes', () {
        final base = createSampleTask(skipIfNoCapacity: false);
        final baseSig = TaskSpawnerEngine.computeScheduleSignature(base);

        final modified = createSampleTask(skipIfNoCapacity: true);
        final modSig = TaskSpawnerEngine.computeScheduleSignature(modified);
        expect(modSig, isNot(equals(baseSig)));
      });

      test('alters signature when missedPolicy changes', () {
        final base = createSampleTask(
          schedules: [
            DailySchedule(
              id: defaultRuleId,
              startDate: const CivilDay(year: 2026, month: 6, day: 1),
              interval: 1,
              missedOccurrencePolicy: const MissedOccurrencePolicy.stack(),
            ),
          ],
        );
        final baseSig = TaskSpawnerEngine.computeScheduleSignature(base);

        final autoDismissTask = createSampleTask(
          schedules: [
            DailySchedule(
              id: defaultRuleId,
              startDate: const CivilDay(year: 2026, month: 6, day: 1),
              interval: 1,
              missedOccurrencePolicy: const MissedOccurrencePolicy.autoDismiss(
                gracePeriod: Duration.zero,
              ),
            ),
          ],
        );
        final autoDismissSig = TaskSpawnerEngine.computeScheduleSignature(
          autoDismissTask,
        );
        expect(autoDismissSig, isNot(equals(baseSig)));
      });

      test('alters signature when assignedUserId changes', () {
        final base = createSampleTask(assignedUserId: 'user-1');
        final baseSig = TaskSpawnerEngine.computeScheduleSignature(base);

        final user2Task = createSampleTask(assignedUserId: 'user-2');
        final user2Sig = TaskSpawnerEngine.computeScheduleSignature(user2Task);
        expect(user2Sig, isNot(equals(baseSig)));

        final unassignedTask = createSampleTask(assignedUserId: null);
        final unassignedSig = TaskSpawnerEngine.computeScheduleSignature(
          unassignedTask,
        );
        expect(unassignedSig, isNot(equals(baseSig)));
      });

      test('alters signature when isFamily changes', () {
        final base = createSampleTask(isFamily: false);
        final baseSig = TaskSpawnerEngine.computeScheduleSignature(base);

        final familyTask = createSampleTask(isFamily: true);
        final familySig = TaskSpawnerEngine.computeScheduleSignature(
          familyTask,
        );
        expect(familySig, isNot(equals(baseSig)));
      });

      test('alters signature when familyCompletionMode changes', () {
        final base = createSampleTask(
          familyCompletionMode: FamilyCompletionMode.individual,
        );
        final baseSig = TaskSpawnerEngine.computeScheduleSignature(base);

        final anyoneTask = createSampleTask(
          familyCompletionMode: FamilyCompletionMode.anyone,
        );
        final anyoneSig = TaskSpawnerEngine.computeScheduleSignature(
          anyoneTask,
        );
        expect(anyoneSig, isNot(equals(baseSig)));
      });

      test('handles empty schedules safely', () {
        final emptyTask = createSampleTask(schedules: []);
        final signature = TaskSpawnerEngine.computeScheduleSignature(emptyTask);
        final decoded = jsonDecode(signature) as Map<String, dynamic>;

        expect(decoded['rules'], isEmpty);
        expect(decoded['futureInstancesCount'], equals(1));
        expect(decoded['missedPolicy'], equals('stack'));
      });
    });

    group('calculateNextOccurrence', () {
      final completionTime = DateTime(2026, 6, 1, 10, 30);

      test(
        'delegates to SchedulerEngine and spawns next instance for fixed calendar daily schedule',
        () {
          final task = createSampleTask();
          final completedInstance = TestTaskFactory.createInstance(
            id: 'I-inst-1',
            scheduleId: task.id,
            ruleId: defaultRuleId,
            title: task.title,
            description: task.description,
            scheduledDate: const CivilDay(year: 2026, month: 6, day: 1),
            status: TaskStatus.completed,
          );

          final nextInstance = TaskSpawnerEngine.calculateNextOccurrence(
            task: task,
            completedInstance: completedInstance,
            completionTime: completionTime,
            existingInstances: [completedInstance],
          );

          expect(nextInstance, isNotNull);
          expect(
            nextInstance!.scheduledDate,
            equals(const CivilDay(year: 2026, month: 6, day: 2)),
          );
          expect(nextInstance.scheduleId, equals(task.id));
          expect(nextInstance.ruleId, equals(defaultRuleId));
          expect(nextInstance.status, equals(TaskStatus.pending));
          expect(nextInstance.isFamily, equals(task.isFamily));
          expect(nextInstance.priority, equals(task.priority));
        },
      );

      test(
        'spawns after the latest pending instance when pending instances already exist',
        () {
          final task = createSampleTask();
          final completedInstance = TestTaskFactory.createInstance(
            id: 'I-inst-1',
            scheduleId: task.id,
            ruleId: defaultRuleId,
            title: task.title,
            description: task.description,
            scheduledDate: const CivilDay(year: 2026, month: 6, day: 1),
            status: TaskStatus.completed,
          );
          final existingPending = TestTaskFactory.createInstance(
            id: 'I-inst-2',
            scheduleId: task.id,
            ruleId: defaultRuleId,
            title: task.title,
            description: task.description,
            scheduledDate: const CivilDay(year: 2026, month: 6, day: 2),
            status: TaskStatus.pending,
          );

          final nextInstance = TaskSpawnerEngine.calculateNextOccurrence(
            task: task,
            completedInstance: completedInstance,
            completionTime: completionTime,
            existingInstances: [completedInstance, existingPending],
          );

          expect(nextInstance, isNotNull);
          expect(
            nextInstance!.scheduledDate,
            equals(const CivilDay(year: 2026, month: 6, day: 3)),
          );
        },
      );

      test(
        'spawns instance relative to completion time for completion-relative policy',
        () {
          const relativeRuleId = 'R-rule-completion-relative';
          final task = createSampleTask(
            schedules: [
              DailySchedule(
                id: relativeRuleId,
                startDate: const CivilDay(year: 2026, month: 6, day: 1),
                interval: 1,
                schedulingPolicy: const CompletionRelativePolicy(
                  interval: Duration(days: 3),
                  targetTime: TimeOfDay(hour: 14, minute: 0),
                ),
              ),
            ],
          );

          final completedInstance = TestTaskFactory.createInstance(
            id: 'I-inst-1',
            scheduleId: task.id,
            ruleId: relativeRuleId,
            title: task.title,
            description: task.description,
            scheduledDate: const CivilDay(year: 2026, month: 6, day: 1),
            status: TaskStatus.completed,
          );

          final nextInstance = TaskSpawnerEngine.calculateNextOccurrence(
            task: task,
            completedInstance: completedInstance,
            completionTime: DateTime(2026, 6, 1, 10, 0),
            existingInstances: [completedInstance],
          );

          expect(nextInstance, isNotNull);
          // 2026-06-01 + 3 days = 2026-06-04
          expect(
            nextInstance!.scheduledDate,
            equals(const CivilDay(year: 2026, month: 6, day: 4)),
          );
          expect(
            nextInstance.startRelativeTime.time,
            equals(const TimeOfDay(hour: 14, minute: 0)),
          );
        },
      );

      test('returns null for non-recurring one-off task', () {
        const oneOffRuleId = 'R-rule-one-off';
        final task = createSampleTask(
          schedules: [
            OneOffSchedule(
              id: oneOffRuleId,
              date: const CivilDay(year: 2026, month: 6, day: 1),
            ),
          ],
        );

        final completedInstance = TestTaskFactory.createInstance(
          id: 'I-inst-1',
          scheduleId: task.id,
          ruleId: oneOffRuleId,
          title: task.title,
          description: task.description,
          scheduledDate: const CivilDay(year: 2026, month: 6, day: 1),
          status: TaskStatus.completed,
        );

        final nextInstance = TaskSpawnerEngine.calculateNextOccurrence(
          task: task,
          completedInstance: completedInstance,
          completionTime: completionTime,
          existingInstances: [completedInstance],
        );

        expect(nextInstance, isNull);
      });

      test('returns null when completed instance has invalid rule ID', () {
        final task = createSampleTask(schedules: []);
        final completedInstance = TestTaskFactory.createInstance(
          id: 'I-inst-1',
          scheduleId: task.id,
          ruleId: 'R-non-existent-rule',
          title: task.title,
          description: task.description,
          scheduledDate: const CivilDay(year: 2026, month: 6, day: 1),
          status: TaskStatus.completed,
        );

        final nextInstance = TaskSpawnerEngine.calculateNextOccurrence(
          task: task,
          completedInstance: completedInstance,
          completionTime: completionTime,
          existingInstances: [completedInstance],
        );

        expect(nextInstance, isNull);
      });
    });

    group('calculateOccurrenceIdToUndo', () {
      final completionTime = DateTime(2026, 6, 1, 10, 30);

      test(
        'delegates to SchedulerEngine and returns the latest pending occurrence ID to delete',
        () {
          final task = createSampleTask();
          final completedInstance = TestTaskFactory.createInstance(
            id: 'I-inst-1',
            scheduleId: task.id,
            ruleId: defaultRuleId,
            title: task.title,
            description: task.description,
            scheduledDate: const CivilDay(year: 2026, month: 6, day: 1),
            status: TaskStatus.completed,
          );
          final pendingInstance1 = TestTaskFactory.createInstance(
            id: 'I-inst-2',
            scheduleId: task.id,
            ruleId: defaultRuleId,
            title: task.title,
            description: task.description,
            scheduledDate: const CivilDay(year: 2026, month: 6, day: 2),
            status: TaskStatus.pending,
          );
          final pendingInstance2 = TestTaskFactory.createInstance(
            id: 'I-inst-3',
            scheduleId: task.id,
            ruleId: defaultRuleId,
            title: task.title,
            description: task.description,
            scheduledDate: const CivilDay(year: 2026, month: 6, day: 3),
            status: TaskStatus.pending,
          );

          final idToUndo = TaskSpawnerEngine.calculateOccurrenceIdToUndo(
            task: task,
            completedInstance: completedInstance,
            completionTime: completionTime,
            existingInstances: [
              completedInstance,
              pendingInstance1,
              pendingInstance2,
            ],
          );

          // Expect the latest pending instance (I-inst-3 on day 3) to be selected for deletion
          expect(idToUndo, equals('I-inst-3'));
        },
      );

      test('returns null when no pending instances exist for the rule', () {
        final task = createSampleTask();
        final completedInstance = TestTaskFactory.createInstance(
          id: 'I-inst-1',
          scheduleId: task.id,
          ruleId: defaultRuleId,
          title: task.title,
          description: task.description,
          scheduledDate: const CivilDay(year: 2026, month: 6, day: 1),
          status: TaskStatus.completed,
        );

        final idToUndo = TaskSpawnerEngine.calculateOccurrenceIdToUndo(
          task: task,
          completedInstance: completedInstance,
          completionTime: completionTime,
          existingInstances: [completedInstance],
        );

        expect(idToUndo, isNull);
      });

      test('ignores pending instances belonging to other rules', () {
        const ruleA = 'R-rule-a';
        const ruleB = 'R-rule-b';

        final task = createSampleTask(
          schedules: [
            DailySchedule(
              id: ruleA,
              startDate: const CivilDay(year: 2026, month: 6, day: 1),
              interval: 1,
            ),
            DailySchedule(
              id: ruleB,
              startDate: const CivilDay(year: 2026, month: 6, day: 1),
              interval: 1,
            ),
          ],
        );

        final completedInstanceRuleA = TestTaskFactory.createInstance(
          id: 'I-inst-a-1',
          scheduleId: task.id,
          ruleId: ruleA,
          title: task.title,
          description: task.description,
          scheduledDate: const CivilDay(year: 2026, month: 6, day: 1),
          status: TaskStatus.completed,
        );
        final pendingInstanceRuleB = TestTaskFactory.createInstance(
          id: 'I-inst-b-1',
          scheduleId: task.id,
          ruleId: ruleB,
          title: task.title,
          description: task.description,
          scheduledDate: const CivilDay(year: 2026, month: 6, day: 2),
          status: TaskStatus.pending,
        );

        final idToUndo = TaskSpawnerEngine.calculateOccurrenceIdToUndo(
          task: task,
          completedInstance: completedInstanceRuleA,
          completionTime: completionTime,
          existingInstances: [completedInstanceRuleA, pendingInstanceRuleB],
        );

        expect(idToUndo, isNull);
      });
    });
  });
}
