import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_filter.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';

void main() {
  group('TaskFilterState unit tests', () {
    final now = DateTime(2026, 6, 15, 12, 0); // Monday noon
    final scheduledDate = DateTime(2026, 6, 15);

    TaskInstance createInstance({
      required String id,
      required RelativeTime dueRelativeTime,
      TaskPriority priority = TaskPriority.medium,
      List<String> labelIds = const [],
      DateTime? schedDate,
    }) {
      return TaskInstance(
        id: id,
        scheduleId: 'sched-1',
        ruleId: 'rule-1',
        scheduledDate: CivilDay.fromDateTime(schedDate ?? scheduledDate),
        title: 'Task $id',
        description: '',
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 8, minute: 0),
        dueRelativeTime: dueRelativeTime,
        priority: priority,
        labelIds: labelIds,
      );
    }

    test('Initial filter state is empty with 0 count', () {
      const state = TaskFilterState();
      expect(state.isEmpty, isTrue);
      expect(state.isNotEmpty, isFalse);
      expect(state.activeFilterCount, 0);
    });

    test('Toggling updates activeFilterCount and sets correctly', () {
      var state = const TaskFilterState();
      state = state.toggleLabel('lbl-1');
      expect(state.activeFilterCount, 1);
      expect(state.selectedLabelIds, contains('lbl-1'));

      state = state.togglePriority(TaskPriority.high);
      expect(state.activeFilterCount, 2);
      expect(state.selectedPriorities, contains(TaskPriority.high));

      state = state.toggleUrgency(TaskUrgencyFilter.overdue);
      expect(state.activeFilterCount, 3);
      expect(state.selectedUrgencies, contains(TaskUrgencyFilter.overdue));

      // Untoggle label
      state = state.toggleLabel('lbl-1');
      expect(state.activeFilterCount, 2);
      expect(state.selectedLabelIds, isNot(contains('lbl-1')));

      // Clear
      state = state.clear();
      expect(state.isEmpty, isTrue);
      expect(state.activeFilterCount, 0);
    });

    test('Filter matches all tasks when state is empty', () {
      const state = TaskFilterState();
      final inst = createInstance(
        id: '1',
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 10, minute: 0),
      );
      expect(state.matches(instance: inst, now: now), isTrue);
    });

    group('Urgency matching', () {
      test('Overdue matches tasks with due time before now', () {
        const state = TaskFilterState(
          selectedUrgencies: {TaskUrgencyFilter.overdue},
        );

        // Due at 10 AM (now is 12 PM) -> Overdue
        final overdueInst = createInstance(
          id: 'overdue',
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 10,
            minute: 0,
          ),
        );
        expect(state.matches(instance: overdueInst, now: now), isTrue);

        // Due tomorrow -> Not overdue
        final upcomingInst = createInstance(
          id: 'upcoming',
          dueRelativeTime: const RelativeTime(
            dayOffset: 1,
            hour: 10,
            minute: 0,
          ),
        );
        expect(state.matches(instance: upcomingInst, now: now), isFalse);
      });

      test('DueToday matches tasks scheduled for today', () {
        const state = TaskFilterState(
          selectedUrgencies: {TaskUrgencyFilter.dueToday},
        );

        final todayInst = createInstance(
          id: 'today',
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 15,
            minute: 0,
          ),
        );
        expect(state.matches(instance: todayInst, now: now), isTrue);

        final tomorrowInst = createInstance(
          id: 'tomorrow',
          dueRelativeTime: const RelativeTime(
            dayOffset: 1,
            hour: 15,
            minute: 0,
          ),
        );
        expect(state.matches(instance: tomorrowInst, now: now), isFalse);
      });

      test('Upcoming matches tasks scheduled after today', () {
        const state = TaskFilterState(
          selectedUrgencies: {TaskUrgencyFilter.upcoming},
        );

        final tomorrowInst = createInstance(
          id: 'tomorrow',
          dueRelativeTime: const RelativeTime(dayOffset: 1, hour: 9, minute: 0),
        );
        expect(state.matches(instance: tomorrowInst, now: now), isTrue);

        final todayInst = createInstance(
          id: 'today',
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 15,
            minute: 0,
          ),
        );
        expect(state.matches(instance: todayInst, now: now), isFalse);
      });

      test('Multi-select urgency uses OR logic', () {
        const state = TaskFilterState(
          selectedUrgencies: {
            TaskUrgencyFilter.overdue,
            TaskUrgencyFilter.upcoming,
          },
        );

        final overdueInst = createInstance(
          id: 'overdue',
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 10,
            minute: 0,
          ),
        );
        final upcomingInst = createInstance(
          id: 'upcoming',
          dueRelativeTime: const RelativeTime(
            dayOffset: 1,
            hour: 10,
            minute: 0,
          ),
        );
        // Due today at 3 PM (not overdue, not upcoming)
        final laterTodayInst = createInstance(
          id: 'today',
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 15,
            minute: 0,
          ),
        );

        expect(state.matches(instance: overdueInst, now: now), isTrue);
        expect(state.matches(instance: upcomingInst, now: now), isTrue);
        expect(state.matches(instance: laterTodayInst, now: now), isFalse);
      });
    });

    group('Priority matching', () {
      test('Matches exact selected priority', () {
        const state = TaskFilterState(selectedPriorities: {TaskPriority.high});

        final highInst = createInstance(
          id: 'high',
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 14,
            minute: 0,
          ),
          priority: TaskPriority.high,
        );
        final medInst = createInstance(
          id: 'med',
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 14,
            minute: 0,
          ),
          priority: TaskPriority.medium,
        );

        expect(state.matches(instance: highInst, now: now), isTrue);
        expect(state.matches(instance: medInst, now: now), isFalse);
      });

      test('Multi-select priority uses OR logic', () {
        const state = TaskFilterState(
          selectedPriorities: {TaskPriority.high, TaskPriority.low},
        );

        final highInst = createInstance(
          id: 'high',
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 14,
            minute: 0,
          ),
          priority: TaskPriority.high,
        );
        final lowInst = createInstance(
          id: 'low',
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 14,
            minute: 0,
          ),
          priority: TaskPriority.low,
        );
        final medInst = createInstance(
          id: 'med',
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 14,
            minute: 0,
          ),
          priority: TaskPriority.medium,
        );

        expect(state.matches(instance: highInst, now: now), isTrue);
        expect(state.matches(instance: lowInst, now: now), isTrue);
        expect(state.matches(instance: medInst, now: now), isFalse);
      });
    });

    group('Label matching', () {
      test('Matches when instance has one of selected labels', () {
        const state = TaskFilterState(
          selectedLabelIds: {'label-work', 'label-chores'},
        );

        final workInst = createInstance(
          id: 'work',
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 14,
            minute: 0,
          ),
          labelIds: ['label-work'],
        );
        final unrelatedInst = createInstance(
          id: 'other',
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 14,
            minute: 0,
          ),
          labelIds: ['label-finance'],
        );

        expect(state.matches(instance: workInst, now: now), isTrue);
        expect(state.matches(instance: unrelatedInst, now: now), isFalse);
      });

      test('Falls back to schedule labelIds if instance labelIds is empty', () {
        const state = TaskFilterState(selectedLabelIds: {'label-home'});

        final instWithoutLabels = createInstance(
          id: 'sched-fallback',
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 14,
            minute: 0,
          ),
          labelIds: [],
        );

        final matchingSchedule = TaskSchedule(
          id: 'sched-1',
          title: 'Schedule',
          description: '',
          labelIds: const ['label-home'],
        );

        final nonMatchingSchedule = TaskSchedule(
          id: 'sched-1',
          title: 'Schedule',
          description: '',
          labelIds: const ['label-finance'],
        );

        expect(
          state.matches(
            instance: instWithoutLabels,
            schedule: matchingSchedule,
            now: now,
          ),
          isTrue,
        );
        expect(
          state.matches(
            instance: instWithoutLabels,
            schedule: nonMatchingSchedule,
            now: now,
          ),
          isFalse,
        );
      });
    });

    group('Combined multi-dimensional filtering', () {
      test('Requires matching all active filter categories (AND logic)', () {
        const state = TaskFilterState(
          selectedLabelIds: {'label-work'},
          selectedPriorities: {TaskPriority.high},
          selectedUrgencies: {TaskUrgencyFilter.overdue},
        );

        // Matches all 3: work, high priority, overdue (10 AM when now is 12 PM)
        final matchingInst = createInstance(
          id: 'match',
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 10,
            minute: 0,
          ),
          priority: TaskPriority.high,
          labelIds: ['label-work'],
        );

        // Matches work and high, but is NOT overdue (due at 3 PM)
        final notOverdueInst = createInstance(
          id: 'not-overdue',
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 15,
            minute: 0,
          ),
          priority: TaskPriority.high,
          labelIds: ['label-work'],
        );

        // Matches overdue and work, but is medium priority
        final medPriorityInst = createInstance(
          id: 'med',
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 10,
            minute: 0,
          ),
          priority: TaskPriority.medium,
          labelIds: ['label-work'],
        );

        expect(state.matches(instance: matchingInst, now: now), isTrue);
        expect(state.matches(instance: notOverdueInst, now: now), isFalse);
        expect(state.matches(instance: medPriorityInst, now: now), isFalse);
      });
    });
  });
}
