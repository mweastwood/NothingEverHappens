import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/hive_local_data_source.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_schedule_reconciler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('TaskScheduleReconciler static helpers', () {
    const startDate = CivilDay(year: 2026, month: 9, day: 16);

    test(
      'onlyRuleTimingsChanged detects pure timing edits vs recurrence edits',
      () {
        final r1 = DailySchedule(
          id: 'r-1',
          scheduleId: 's-1',
          startDate: startDate,
          interval: 1,
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
        final r2TimingOnly = r1.copyWithTiming(
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 11,
            minute: 0,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 18,
            minute: 0,
          ),
        );
        final r3IntervalChanged = DailySchedule(
          id: 'r-1',
          scheduleId: 's-1',
          startDate: startDate,
          interval: 2,
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

        expect(
          TaskScheduleReconciler.onlyRuleTimingsChanged(r1, r2TimingOnly),
          isTrue,
        );
        expect(
          TaskScheduleReconciler.onlyRuleTimingsChanged(r1, r3IntervalChanged),
          isFalse,
        );
      },
    );

    test(
      'shouldPreservePendingInstanceOnScheduleEdit preserves valid timing edits, completion-relative rules, and active workflow progress',
      () {
        final oldRule = DailySchedule(
          id: 'r-1',
          scheduleId: 's-1',
          startDate: startDate,
          interval: 1,
        );
        final timingEditedRule = oldRule.copyWithTiming(
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 10,
            minute: 30,
          ),
        );
        final incompatibleRule = DailySchedule(
          id: 'r-1',
          scheduleId: 's-1',
          startDate: startDate,
          interval: 3,
        );
        final task = TaskSchedule(
          id: 's-1',
          title: 'Task',
          description: 'Desc',
          schedules: [timingEditedRule],
        );
        final pendingToday = TaskInstance(
          id: 'i-1',
          scheduleId: 's-1',
          ruleId: 'r-1',
          title: 'Task',
          description: 'Desc',
          scheduledDate: startDate,
          startRelativeTime: oldRule.startRelativeTime,
          dueRelativeTime: oldRule.dueRelativeTime,
        );
        final pendingTomorrow = pendingToday.copyWith(
          scheduledDate: startDate.addDays(1),
        );

        // Timing-only edit on valid date preserves instance
        expect(
          TaskScheduleReconciler.shouldPreservePendingInstanceOnScheduleEdit(
            inst: pendingToday,
            newTask: task,
            oldRule: oldRule,
            newRule: timingEditedRule,
            changes: {'schedules': []},
          ),
          isTrue,
        );

        // Date no longer occurs on new rule -> false
        expect(
          TaskScheduleReconciler.shouldPreservePendingInstanceOnScheduleEdit(
            inst: pendingTomorrow,
            newTask: task.copyWith(schedules: [incompatibleRule]),
            oldRule: oldRule,
            newRule: incompatibleRule,
            changes: {'schedules': []},
          ),
          isFalse,
        );

        // Active workflow progress on a still-valid date preserves instance
        final shoppingInst = pendingToday.copyWith(
          workflowPayload: const WorkflowInstancePayload(
            workflowType: 'mealWorkflow',
            workflowGroupId: 'g-1',
            stage: WorkflowStage.shoppingList,
          ),
        );
        expect(
          TaskScheduleReconciler.shouldPreservePendingInstanceOnScheduleEdit(
            inst: shoppingInst,
            newTask: task.copyWith(schedules: [incompatibleRule]),
            oldRule: oldRule,
            newRule: incompatibleRule,
            changes: {'schedules': []},
          ),
          isTrue,
        );
      },
    );

    test(
      'buildUpdatedPendingInstance updates metadata and preserves stage-specific workflow titles',
      () {
        final rule = DailySchedule(
          id: 'r-1',
          scheduleId: 's-1',
          startDate: startDate,
          interval: 1,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 10,
            minute: 0,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 18,
            minute: 0,
          ),
        );
        final updatedTask = TaskSchedule(
          id: 's-1',
          title: 'New Schedule Title',
          description: 'New Description',
          priority: TaskPriority.high,
          isFamily: true,
          familyCompletionMode: FamilyCompletionMode.individual,
          labelIds: const ['L-1'],
          schedules: [rule],
        );
        final regularInst = TaskInstance(
          id: 'i-1',
          scheduleId: 's-1',
          ruleId: 'r-1',
          title: 'Old Title',
          description: 'Old Desc',
          scheduledDate: startDate,
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

        final rebuiltRegular =
            TaskScheduleReconciler.buildUpdatedPendingInstance(
              inst: regularInst,
              task: updatedTask,
              rule: rule,
            );
        expect(rebuiltRegular.title, equals('New Schedule Title'));
        expect(rebuiltRegular.description, equals('New Description'));
        expect(rebuiltRegular.priority, equals(TaskPriority.high));
        expect(rebuiltRegular.isFamily, isTrue);
        expect(
          rebuiltRegular.familyCompletionMode,
          equals(FamilyCompletionMode.individual),
        );
        expect(rebuiltRegular.labelIds, equals(['L-1']));
        expect(
          rebuiltRegular.startRelativeTime,
          equals(const RelativeTime(dayOffset: 0, hour: 10, minute: 0)),
        );

        final stageInst = regularInst.copyWith(
          title: 'Buy Groceries for Pasta',
          description: 'Stage-specific description',
          workflowPayload: const WorkflowInstancePayload(
            workflowType: 'mealWorkflow',
            workflowGroupId: 'g-1',
            stage: WorkflowStage.shoppingList,
          ),
        );
        final rebuiltStage = TaskScheduleReconciler.buildUpdatedPendingInstance(
          inst: stageInst,
          task: updatedTask,
          rule: rule,
        );
        expect(rebuiltStage.title, equals('Buy Groceries for Pasta'));
        expect(rebuiltStage.description, equals('Stage-specific description'));
      },
    );
  });

  group('TaskScheduleReconciler.reconcileInstancesOnUpdate', () {
    late Directory tempDir;
    late HiveLocalDataSource localDataSource;
    late TaskScheduleReconciler reconciler;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('reconciler_test_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall methodCall) async {
              if (methodCall.method == 'getApplicationDocumentsDirectory') {
                return tempDir.path;
              }
              return null;
            },
          );
      localDataSource = HiveLocalDataSource();
      await localDataSource.init();
      reconciler = TaskScheduleReconciler(
        localDataSource: localDataSource,
        userId: 'user-1',
      );
    });

    tearDown(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'updates pending and non-pending instances when task scope and timings change',
      () async {
        const date = CivilDay(year: 2026, month: 9, day: 16);
        final oldRule = DailySchedule(
          id: 'R-1',
          scheduleId: 'S-1',
          startDate: date,
          interval: 1,
        );
        final oldTask = TaskSchedule(
          id: 'S-1',
          title: 'Old Title',
          description: 'Old Desc',
          isFamily: false,
          schedules: [oldRule],
        );
        final newRule = oldRule.copyWithTiming(
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 11,
            minute: 0,
          ),
        );
        final updatedTask = oldTask.copyWith(
          title: 'New Title',
          isFamily: true,
          familyCompletionMode: FamilyCompletionMode.individual,
          schedules: [newRule],
        );

        final pendingInst = TaskInstance(
          id: 'I-pending',
          scheduleId: 'S-1',
          ruleId: 'R-1',
          title: 'Old Title',
          description: 'Old Desc',
          scheduledDate: date,
          startRelativeTime: oldRule.startRelativeTime,
          dueRelativeTime: oldRule.dueRelativeTime,
          status: TaskStatus.pending,
        );
        final completedInst = TaskInstance(
          id: 'I-completed',
          scheduleId: 'S-1',
          ruleId: 'R-1',
          title: 'Old Title',
          description: 'Old Desc',
          scheduledDate: date.addDays(-1),
          startRelativeTime: oldRule.startRelativeTime,
          dueRelativeTime: oldRule.dueRelativeTime,
          status: TaskStatus.completed,
          isFamily: false,
        );

        await localDataSource.saveInstances([pendingInst, completedInst]);

        await reconciler.reconcileInstancesOnUpdate(
          oldTask: oldTask,
          updatedTask: updatedTask,
          changes: {
            'title': 'New Title',
            'isFamily': true,
            'schedules': updatedTask.schedules,
          },
        );

        final savedPending = localDataSource.getInstances().firstWhere(
          (i) => i.id == 'I-pending',
        );
        expect(savedPending.title, equals('New Title'));
        expect(savedPending.isFamily, isTrue);
        expect(
          savedPending.startRelativeTime,
          equals(const RelativeTime(dayOffset: 0, hour: 11, minute: 0)),
        );

        final savedCompleted = localDataSource.getInstances().firstWhere(
          (i) => i.id == 'I-completed',
        );
        expect(savedCompleted.isFamily, isTrue);
        expect(
          savedCompleted.familyCompletionMode,
          equals(FamilyCompletionMode.individual),
        );
      },
    );
  });
}
