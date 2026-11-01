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

        // Active workflow progress on a still-valid date preserves instance when still mealWorkflow
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
            newTask: task.copyWith(
              workflowType: 'mealWorkflow',
              schedules: [incompatibleRule],
            ),
            oldRule: oldRule,
            newRule: incompatibleRule,
            changes: {'schedules': []},
          ),
          isTrue,
        );

        // Converting mealWorkflow to standard while editing schedules does not preserve based on old workflow stage
        expect(
          TaskScheduleReconciler.shouldPreservePendingInstanceOnScheduleEdit(
            inst: shoppingInst,
            newTask: task.copyWith(schedules: [incompatibleRule]),
            oldRule: oldRule,
            newRule: incompatibleRule,
            changes: {'schedules': [], 'workflowType': null},
          ),
          isFalse,
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
          task: updatedTask.copyWith(workflowType: 'mealWorkflow'),
          rule: rule,
        );
        expect(rebuiltStage.title, equals('Buy Groceries for Pasta'));
        expect(rebuiltStage.description, equals('Stage-specific description'));
        expect(
          rebuiltStage.workflowPayload?.stage,
          equals(WorkflowStage.shoppingList),
        );

        // Converting from mealWorkflow to standard clears workflowPayload and resets title/description
        final convertedToStandard =
            TaskScheduleReconciler.buildUpdatedPendingInstance(
              inst: stageInst,
              task: updatedTask,
              rule: rule,
            );
        expect(convertedToStandard.workflowPayload, isNull);
        expect(convertedToStandard.title, equals('New Schedule Title'));
        expect(convertedToStandard.description, equals('New Description'));

        // Converting from standard to mealWorkflow initializes selectMeal workflowPayload
        final convertedToMealWorkflow =
            TaskScheduleReconciler.buildUpdatedPendingInstance(
              inst: regularInst,
              task: updatedTask.copyWith(workflowType: 'mealWorkflow'),
              rule: rule,
            );
        expect(convertedToMealWorkflow.workflowPayload, isNotNull);
        expect(
          convertedToMealWorkflow.workflowPayload!.workflowType,
          equals('mealWorkflow'),
        );
        expect(
          convertedToMealWorkflow.workflowPayload!.stage,
          equals(WorkflowStage.selectMeal),
        );
        expect(
          convertedToMealWorkflow.workflowPayload!.workflowGroupId,
          equals('${updatedTask.id}_2026-9-16'),
        );
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

    test(
      'converts pending instances between standard and mealWorkflow and deduplicates sibling stages',
      () async {
        const date = CivilDay(year: 2026, month: 9, day: 16);
        final rule = DailySchedule(
          id: 'R-1',
          scheduleId: 'S-meal',
          startDate: date,
          interval: 1,
        );
        final standardTask = TaskSchedule(
          id: 'S-meal',
          title: 'Dinner',
          description: 'Plan and cook dinner',
          schedules: [rule],
        );
        final mealTask = standardTask.copyWith(workflowType: 'mealWorkflow');

        final pendingStandard = TaskInstance(
          id: 'I-1',
          scheduleId: 'S-meal',
          ruleId: 'R-1',
          title: 'Dinner',
          description: 'Plan and cook dinner',
          scheduledDate: date,
          startRelativeTime: rule.startRelativeTime,
          dueRelativeTime: rule.dueRelativeTime,
          status: TaskStatus.pending,
        );
        await localDataSource.saveInstance(pendingStandard);

        // 1. Convert standard -> mealWorkflow: initializes WorkflowInstancePayload
        await reconciler.reconcileInstancesOnUpdate(
          oldTask: standardTask,
          updatedTask: mealTask,
          changes: {'workflowType': 'mealWorkflow'},
        );

        final afterToMeal = localDataSource.getInstances();
        expect(afterToMeal, hasLength(1));
        expect(afterToMeal.first.workflowPayload, isNotNull);
        expect(
          afterToMeal.first.workflowPayload!.stage,
          equals(WorkflowStage.selectMeal),
        );

        // 2. Simulate spawned sibling stages on the same date (shoppingList + prepDinner)
        final shopStage = TaskInstance(
          id: 'I-shop',
          scheduleId: 'S-meal',
          ruleId: 'R-1',
          title: 'Shop: Pasta',
          description: 'Buy ingredients',
          scheduledDate: date,
          startRelativeTime: rule.startRelativeTime,
          dueRelativeTime: rule.dueRelativeTime,
          status: TaskStatus.pending,
          workflowPayload: const WorkflowInstancePayload(
            workflowType: 'mealWorkflow',
            workflowGroupId: 'S-meal_2026-9-16',
            stage: WorkflowStage.shoppingList,
          ),
        );
        final prepStage = TaskInstance(
          id: 'I-prep',
          scheduleId: 'S-meal',
          ruleId: 'R-1',
          title: 'Cook: Pasta',
          description: 'Prep dinner',
          scheduledDate: date,
          startRelativeTime: rule.startRelativeTime,
          dueRelativeTime: rule.dueRelativeTime,
          status: TaskStatus.pending,
          workflowPayload: const WorkflowInstancePayload(
            workflowType: 'mealWorkflow',
            workflowGroupId: 'S-meal_2026-9-16',
            stage: WorkflowStage.prepDinner,
          ),
        );
        await localDataSource.deleteInstance('I-1');
        await localDataSource.saveInstances([shopStage, prepStage]);

        // Convert mealWorkflow -> standard while also editing schedule timings
        final updatedRule = rule.copyWithTiming(
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 18,
            minute: 0,
          ),
        );
        final revertedStandardTask = standardTask.copyWith(
          schedules: [updatedRule],
        );
        await reconciler.reconcileInstancesOnUpdate(
          oldTask: mealTask,
          updatedTask: revertedStandardTask,
          changes: {
            'workflowType': null,
            'schedules': revertedStandardTask.schedules,
          },
        );

        final afterToStandard = localDataSource.getInstances();
        expect(afterToStandard, hasLength(1));
        expect(afterToStandard.first.workflowPayload, isNull);
        expect(afterToStandard.first.title, equals('Dinner'));
        expect(
          afterToStandard.first.description,
          equals('Plan and cook dinner'),
        );
      },
    );

    test(
      'persists reconciled saves, deletes, and dirty IDs in single batch calls and prunes duplicate workflow siblings without schedule edit',
      () async {
        final trackingDs = _BatchTrackingHiveLocalDataSource();
        await trackingDs.init();
        final batchReconciler = TaskScheduleReconciler(
          localDataSource: trackingDs,
          userId: 'user-1',
        );

        const date = CivilDay(year: 2026, month: 9, day: 16);
        final rule = DailySchedule(
          id: 'R-1',
          scheduleId: 'S-batch',
          startDate: date,
          interval: 1,
        );
        final mealTask = TaskSchedule(
          id: 'S-batch',
          title: 'Dinner',
          description: 'Cook dinner',
          workflowType: 'mealWorkflow',
          isFamily: false,
          schedules: [rule],
        );
        final revertedStandardFamilyTask = mealTask.copyWith(
          clearWorkflowType: true,
          isFamily: true,
          familyCompletionMode: FamilyCompletionMode.individual,
        );

        final shopStage = TaskInstance(
          id: 'I-shop',
          scheduleId: 'S-batch',
          ruleId: 'R-1',
          title: 'Shop: Soup',
          description: 'Buy veggies',
          scheduledDate: date,
          startRelativeTime: rule.startRelativeTime,
          dueRelativeTime: rule.dueRelativeTime,
          status: TaskStatus.pending,
          workflowPayload: const WorkflowInstancePayload(
            workflowType: 'mealWorkflow',
            workflowGroupId: 'S-batch_2026-9-16',
            stage: WorkflowStage.shoppingList,
          ),
        );
        final prepStage = TaskInstance(
          id: 'I-prep',
          scheduleId: 'S-batch',
          ruleId: 'R-1',
          title: 'Cook: Soup',
          description: 'Simmer soup',
          scheduledDate: date,
          startRelativeTime: rule.startRelativeTime,
          dueRelativeTime: rule.dueRelativeTime,
          status: TaskStatus.pending,
          workflowPayload: const WorkflowInstancePayload(
            workflowType: 'mealWorkflow',
            workflowGroupId: 'S-batch_2026-9-16',
            stage: WorkflowStage.prepDinner,
          ),
        );
        final completedYesterday = TaskInstance(
          id: 'I-completed',
          scheduleId: 'S-batch',
          ruleId: 'R-1',
          title: 'Dinner',
          description: 'Cook dinner',
          scheduledDate: date.addDays(-1),
          startRelativeTime: rule.startRelativeTime,
          dueRelativeTime: rule.dueRelativeTime,
          status: TaskStatus.completed,
          isFamily: false,
        );

        await trackingDs.saveInstances([
          shopStage,
          prepStage,
          completedYesterday,
        ]);
        trackingDs.resetCounts();

        await batchReconciler.reconcileInstancesOnUpdate(
          oldTask: mealTask,
          updatedTask: revertedStandardFamilyTask,
          changes: {'workflowType': null, 'isFamily': true},
        );

        expect(trackingDs.deleteInstancesCallCount, 1);
        expect(trackingDs.saveInstancesCallCount, 1);
        expect(trackingDs.markDirtyBatchCallCount, 1);

        final remainingPending = trackingDs
            .getInstances()
            .where((i) => i.status == TaskStatus.pending)
            .toList();
        expect(remainingPending, hasLength(1));
        expect(remainingPending.single.workflowPayload, isNull);
        expect(remainingPending.single.isFamily, isTrue);

        final dirtyIds = trackingDs.getDirtyTaskIds();
        expect(dirtyIds, containsAll(['I-shop', 'I-prep', 'I-completed']));
      },
    );
  });
}

class _BatchTrackingHiveLocalDataSource extends HiveLocalDataSource {
  int saveInstancesCallCount = 0;
  int deleteInstancesCallCount = 0;
  int markDirtyBatchCallCount = 0;

  void resetCounts() {
    saveInstancesCallCount = 0;
    deleteInstancesCallCount = 0;
    markDirtyBatchCallCount = 0;
  }

  @override
  Future<void> saveInstances(List<TaskInstance> instances) async {
    saveInstancesCallCount++;
    await super.saveInstances(instances);
  }

  @override
  Future<void> deleteInstances(List<String> ids) async {
    deleteInstancesCallCount++;
    await super.deleteInstances(ids);
  }

  @override
  Future<void> markDirtyBatch(List<String> ids) async {
    markDirtyBatchCallCount++;
    await super.markDirtyBatch(ids);
  }
}
