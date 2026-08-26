import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/create_task_form_notifier.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';

void main() {
  setUp(() {
    AppClock.setMockTime(DateTime(2026, 3, 8, 9, 0));
  });

  tearDown(() {
    AppClock.reset();
  });

  group('CreateTaskFormNotifier initial state tests', () {
    test('initial state for default new task (one-off)', () {
      final notifier = CreateTaskFormNotifier(defaultToRepeating: false);
      final state = notifier.state;

      expect(state.taskScheduleId, isNotEmpty);
      expect(state.schedules.length, 1);
      expect(state.schedules.first, isA<OneOffSchedule>());
      expect(state.expandedScheduleIndex, 0);
      expect(state.isFamily, false);
      expect(state.familyCompletionMode, FamilyCompletionMode.anyone);
      expect(state.priority, TaskPriority.medium);
      expect(state.isMealWorkflow, false);
      expect(state.isSaving, false);
    });

    test('initial state for default repeating task', () {
      final notifier = CreateTaskFormNotifier(defaultToRepeating: true);
      final state = notifier.state;

      expect(state.schedules.length, 1);
      expect(state.schedules.first, isA<DailySchedule>());
      expect(state.expandedScheduleIndex, 0);
    });

    test('initial state when editing an existing task', () {
      final existingTask = TaskSchedule(
        id: 'existing-id-123',
        title: 'Existing Task',
        description: 'Existing Desc',
        schedules: [
          DailySchedule(
            id: 'rule-1',
            scheduleId: 'S-existing-id-123',
            startDate: CivilDay(year: 2026, month: 3, day: 1),
            interval: 1,
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 8, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 12, minute: 0),
            ),
            schedulingPolicy: const FixedCalendarPolicy(),
          ),
        ],
        isFamily: true,
        familyCompletionMode: FamilyCompletionMode.individual,
        priority: TaskPriority.high,
        assignedUserId: 'user-456',
        skipIfNoCapacity: true,
        workflowType: 'mealWorkflow',
        mealWorkflowConfig: const MealWorkflowConfig(
          selectTime: RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          shopTime: RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 15, minute: 0),
          ),
          prepTime: RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 30),
          ),
        ),
      );

      final notifier = CreateTaskFormNotifier(taskToEdit: existingTask);
      final state = notifier.state;

      expect(state.taskScheduleId, existingTask.id);
      expect(state.schedules.length, 1);
      expect(state.isFamily, true);
      expect(state.familyCompletionMode, FamilyCompletionMode.individual);
      expect(state.priority, TaskPriority.high);
      expect(state.assignedUserId, 'user-456');
      expect(state.skipIfNoCapacity, true);
      expect(state.isMealWorkflow, true);
      expect(state.selectTime, const TimeOfDay(hour: 9, minute: 0));
      expect(state.shopTime, const TimeOfDay(hour: 15, minute: 0));
      expect(state.prepTime, const TimeOfDay(hour: 17, minute: 30));
    });

    test('initial state when duplicating an existing task', () {
      final existingTask = TaskSchedule(
        id: 'old-id',
        title: 'Duplicate Target',
        description: 'Target Desc',
        schedules: [
          OneOffSchedule(
            id: 'old-rule-id',
            scheduleId: 'S-old-id',
            date: CivilDay(year: 2026, month: 3, day: 10),
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 10, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 18, minute: 0),
            ),
          ),
        ],
        isFamily: true,
        priority: TaskPriority.low,
        workflowType: 'mealWorkflow',
        mealWorkflowConfig: const MealWorkflowConfig(
          selectTime: RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 30),
          ),
          shopTime: RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 14, minute: 0),
          ),
          prepTime: RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 18, minute: 0),
          ),
        ),
      );

      final notifier = CreateTaskFormNotifier(taskToDuplicate: existingTask);
      final state = notifier.state;

      expect(state.taskScheduleId, isNot(equals(existingTask.id)));
      expect(state.schedules.length, 1);
      expect(state.schedules.first.scheduleId, state.taskScheduleId);
      expect(state.schedules.first.id, isNot(equals('old-rule-id')));
      expect(state.isFamily, true);
      expect(state.priority, TaskPriority.low);
      expect(state.isMealWorkflow, true);
      expect(state.selectTime, const TimeOfDay(hour: 9, minute: 30));
      expect(state.shopTime, const TimeOfDay(hour: 14, minute: 0));
      expect(state.prepTime, const TimeOfDay(hour: 18, minute: 0));
    });
  });

  group('CreateTaskFormNotifier state mutations', () {
    test('adding, updating, and removing schedule rules', () {
      final notifier = CreateTaskFormNotifier(defaultToRepeating: false);
      expect(notifier.state.schedules.length, 1);

      // Add schedule
      notifier.addSchedule();
      expect(notifier.state.schedules.length, 2);
      expect(notifier.state.expandedScheduleIndex, 1);

      // Update schedule
      final newRule = DailySchedule(
        id: notifier.state.schedules[0].id,
        scheduleId: notifier.state.taskScheduleId,
        startDate: CivilDay(year: 2026, month: 3, day: 8),
        interval: 2,
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        schedulingPolicy: const FixedCalendarPolicy(),
      );
      notifier.updateSchedule(0, newRule);
      expect(notifier.state.schedules[0], equals(newRule));

      // Remove schedule
      notifier.removeSchedule(1);
      expect(notifier.state.schedules.length, 1);
    });

    test(
      'toggling family assignment and setting completion mode / assigned user',
      () {
        final notifier = CreateTaskFormNotifier();

        notifier.setFamilyToggled(true);
        expect(notifier.state.isFamily, true);

        notifier.setAssignedUserId('user-123');
        expect(notifier.state.assignedUserId, 'user-123');

        notifier.setFamilyCompletionMode(FamilyCompletionMode.individual);
        expect(
          notifier.state.familyCompletionMode,
          FamilyCompletionMode.individual,
        );

        // Disabling family should clear assignedUserId
        notifier.setFamilyToggled(false);
        expect(notifier.state.isFamily, false);
        expect(notifier.state.assignedUserId, isNull);
      },
    );

    test('updating priority and skipIfNoCapacity', () {
      final notifier = CreateTaskFormNotifier();

      notifier.setPriority(TaskPriority.high);
      expect(notifier.state.priority, TaskPriority.high);

      notifier.setSkipIfNoCapacity(true);
      expect(notifier.state.skipIfNoCapacity, true);
    });

    test('updating experimental workflow state and stage times', () {
      final notifier = CreateTaskFormNotifier();

      notifier.toggleExperimentalExpanded();
      expect(notifier.state.isExperimentalExpanded, true);

      notifier.setIsMealWorkflow(true);
      expect(notifier.state.isMealWorkflow, true);

      notifier.setSelectTime(const TimeOfDay(hour: 11, minute: 30));
      expect(notifier.state.selectTime, const TimeOfDay(hour: 11, minute: 30));

      notifier.setShopTime(const TimeOfDay(hour: 14, minute: 15));
      expect(notifier.state.shopTime, const TimeOfDay(hour: 14, minute: 15));

      notifier.setPrepTime(const TimeOfDay(hour: 19, minute: 0));
      expect(notifier.state.prepTime, const TimeOfDay(hour: 19, minute: 0));
    });

    test('updating saving state', () {
      final notifier = CreateTaskFormNotifier();

      notifier.setIsSaving(true);
      expect(notifier.state.isSaving, true);

      notifier.setIsSaving(false);
      expect(notifier.state.isSaving, false);
    });
  });
}
