import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_attribution_calculator.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';

const _dummyStart = RelativeTime(dayOffset: 0, hour: 9, minute: 0);
const _dummyDue = RelativeTime(dayOffset: 0, hour: 17, minute: 0);
const _today = CivilDay(year: 2026, month: 9, day: 16);
const _yesterday = CivilDay(year: 2026, month: 9, day: 15);
const _tomorrow = CivilDay(year: 2026, month: 9, day: 17);

TaskInstance _buildInstance({
  String id = 'inst-1',
  String scheduleId = 'sched-1',
  CivilDay scheduledDate = _today,
  TaskStatus status = TaskStatus.pending,
  bool isFamily = false,
  FamilyCompletionMode familyCompletionMode = FamilyCompletionMode.anyone,
  String? assignedUserId,
  String? completedByUserId,
  List<String> completedByUserIds = const [],
}) {
  return TaskInstance(
    id: id,
    scheduleId: scheduleId,
    ruleId: 'rule-1',
    title: 'Task',
    description: 'Description',
    scheduledDate: scheduledDate,
    startRelativeTime: _dummyStart,
    dueRelativeTime: _dummyDue,
    status: status,
    isFamily: isFamily,
    familyCompletionMode: familyCompletionMode,
    assignedUserId: assignedUserId,
    completedByUserId: completedByUserId,
    completedByUserIds: completedByUserIds,
  );
}

TaskSchedule _buildSchedule({
  String id = 'sched-1',
  bool isFamily = false,
  FamilyCompletionMode familyCompletionMode = FamilyCompletionMode.anyone,
  String? assignedUserId,
  Duration? estimatedDuration = const Duration(minutes: 60),
}) {
  return TaskSchedule(
    id: id,
    title: 'Task Schedule',
    description: 'Description',
    isFamily: isFamily,
    familyCompletionMode: familyCompletionMode,
    assignedUserId: assignedUserId,
    estimatedDuration: estimatedDuration,
    schedules: const [],
  );
}

void main() {
  group('TaskAttributionCalculator.evaluatePersonalTimelineAttribution', () {
    test(
      'personal tasks attribute completed/skipped by completedByUserId or fallback assignedUserId',
      () {
        final completedByAlice = _buildInstance(
          status: TaskStatus.completed,
          completedByUserId: 'alice',
          assignedUserId: 'bob',
        );
        expect(
          TaskAttributionCalculator.evaluatePersonalTimelineAttribution(
            instance: completedByAlice,
            currentUserId: 'alice',
            familyMemberCount: 1,
            today: _today,
            baseDuration: 1.5,
          ),
          (
            isUserTask: true,
            effectiveStatus: TaskStatus.completed,
            effectiveDuration: 1.5,
          ),
        );

        final completedNoActorAssignedToAlice = _buildInstance(
          status: TaskStatus.skipped,
          completedByUserId: null,
          assignedUserId: 'alice',
        );
        expect(
          TaskAttributionCalculator.evaluatePersonalTimelineAttribution(
            instance: completedNoActorAssignedToAlice,
            currentUserId: 'alice',
            familyMemberCount: 1,
            today: _today,
            baseDuration: 1.0,
          ),
          (
            isUserTask: true,
            effectiveStatus: TaskStatus.skipped,
            effectiveDuration: 1.0,
          ),
        );

        final pendingAssignedToBob = _buildInstance(
          status: TaskStatus.pending,
          assignedUserId: 'bob',
        );
        expect(
          TaskAttributionCalculator.evaluatePersonalTimelineAttribution(
            instance: pendingAssignedToBob,
            currentUserId: 'alice',
            familyMemberCount: 1,
            today: _today,
            baseDuration: 1.0,
          ).isUserTask,
          isFalse,
        );
      },
    );

    test(
      'assigned family tasks attribute completed/skipped to actor and pending/failed to assignee',
      () {
        final completedByBobAssignedAlice = _buildInstance(
          isFamily: true,
          assignedUserId: 'alice',
          completedByUserId: 'bob',
          status: TaskStatus.completed,
        );
        expect(
          TaskAttributionCalculator.evaluatePersonalTimelineAttribution(
            instance: completedByBobAssignedAlice,
            currentUserId: 'alice',
            familyMemberCount: 3,
            today: _today,
            baseDuration: 2.0,
          ).isUserTask,
          isFalse,
        );
        expect(
          TaskAttributionCalculator.evaluatePersonalTimelineAttribution(
            instance: completedByBobAssignedAlice,
            currentUserId: 'bob',
            familyMemberCount: 3,
            today: _today,
            baseDuration: 2.0,
          ),
          (
            isUserTask: true,
            effectiveStatus: TaskStatus.completed,
            effectiveDuration: 2.0,
          ),
        );

        final pendingAssignedAlice = _buildInstance(
          isFamily: true,
          assignedUserId: 'alice',
          status: TaskStatus.pending,
        );
        expect(
          TaskAttributionCalculator.evaluatePersonalTimelineAttribution(
            instance: pendingAssignedAlice,
            currentUserId: 'alice',
            familyMemberCount: 3,
            today: _today,
            baseDuration: 2.0,
          ),
          (
            isUserTask: true,
            effectiveStatus: TaskStatus.pending,
            effectiveDuration: 2.0,
          ),
        );
      },
    );

    test(
      'unassigned individual-mode family tasks attribute per member completion or overdue failure',
      () {
        final completedByAliceOnly = _buildInstance(
          isFamily: true,
          familyCompletionMode: FamilyCompletionMode.individual,
          status: TaskStatus.pending,
          scheduledDate: _yesterday,
          completedByUserIds: const ['alice'],
        );

        expect(
          TaskAttributionCalculator.evaluatePersonalTimelineAttribution(
            instance: completedByAliceOnly,
            currentUserId: 'alice',
            familyMemberCount: 2,
            today: _today,
            baseDuration: 1.25,
          ),
          (
            isUserTask: true,
            effectiveStatus: TaskStatus.completed,
            effectiveDuration: 1.25,
          ),
        );

        expect(
          TaskAttributionCalculator.evaluatePersonalTimelineAttribution(
            instance: completedByAliceOnly,
            currentUserId: 'bob',
            familyMemberCount: 2,
            today: _today,
            baseDuration: 1.25,
          ),
          (
            isUserTask: true,
            effectiveStatus: TaskStatus.failed,
            effectiveDuration: 1.25,
          ),
        );

        final futurePending = _buildInstance(
          isFamily: true,
          familyCompletionMode: FamilyCompletionMode.individual,
          status: TaskStatus.pending,
          scheduledDate: _tomorrow,
        );
        expect(
          TaskAttributionCalculator.evaluatePersonalTimelineAttribution(
            instance: futurePending,
            currentUserId: 'bob',
            familyMemberCount: 2,
            today: _today,
            baseDuration: 1.25,
          ),
          (
            isUserTask: true,
            effectiveStatus: TaskStatus.pending,
            effectiveDuration: 1.25,
          ),
        );
      },
    );

    test(
      'unassigned anyone-mode family tasks split future pending duration and exclude overdue/failed',
      () {
        final todayPending = _buildInstance(
          isFamily: true,
          familyCompletionMode: FamilyCompletionMode.anyone,
          status: TaskStatus.pending,
          scheduledDate: _today,
        );
        expect(
          TaskAttributionCalculator.evaluatePersonalTimelineAttribution(
            instance: todayPending,
            currentUserId: 'alice',
            familyMemberCount: 4,
            today: _today,
            baseDuration: 2.0,
          ),
          (
            isUserTask: true,
            effectiveStatus: TaskStatus.pending,
            effectiveDuration: 0.5,
          ),
        );

        final overduePending = _buildInstance(
          isFamily: true,
          familyCompletionMode: FamilyCompletionMode.anyone,
          status: TaskStatus.pending,
          scheduledDate: _yesterday,
        );
        expect(
          TaskAttributionCalculator.evaluatePersonalTimelineAttribution(
            instance: overduePending,
            currentUserId: 'alice',
            familyMemberCount: 4,
            today: _today,
            baseDuration: 2.0,
          ),
          (
            isUserTask: false,
            effectiveStatus: TaskStatus.pending,
            effectiveDuration: 0.0,
          ),
        );

        final failedAnyone = _buildInstance(
          isFamily: true,
          familyCompletionMode: FamilyCompletionMode.anyone,
          status: TaskStatus.failed,
          scheduledDate: _yesterday,
        );
        expect(
          TaskAttributionCalculator.evaluatePersonalTimelineAttribution(
            instance: failedAnyone,
            currentUserId: 'alice',
            familyMemberCount: 4,
            today: _today,
            baseDuration: 2.0,
          ).isUserTask,
          isFalse,
        );
      },
    );
  });

  group('TaskAttributionCalculator.calculateUserPendingPlannedMinutes', () {
    test('returns 0 for non-pending or non-positive durations', () {
      final completed = _buildInstance(status: TaskStatus.completed);
      expect(
        TaskAttributionCalculator.calculateUserPendingPlannedMinutes(
          instance: completed,
          currentUserId: 'alice',
          familyMemberCount: 2,
          durationMinutes: 60,
        ),
        0.0,
      );

      final zeroDuration = _buildInstance(status: TaskStatus.pending);
      expect(
        TaskAttributionCalculator.calculateUserPendingPlannedMinutes(
          instance: zeroDuration,
          currentUserId: 'alice',
          familyMemberCount: 2,
          durationMinutes: 0,
        ),
        0.0,
      );
    });

    test(
      'handles assigned family, individual family, anyone family, and personal tasks',
      () {
        final assignedFamily = _buildInstance(
          isFamily: true,
          assignedUserId: 'alice',
          status: TaskStatus.pending,
        );
        expect(
          TaskAttributionCalculator.calculateUserPendingPlannedMinutes(
            instance: assignedFamily,
            currentUserId: 'alice',
            familyMemberCount: 3,
            durationMinutes: 45,
          ),
          45.0,
        );
        expect(
          TaskAttributionCalculator.calculateUserPendingPlannedMinutes(
            instance: assignedFamily,
            currentUserId: 'bob',
            familyMemberCount: 3,
            durationMinutes: 45,
          ),
          0.0,
        );

        final individualFamily = _buildInstance(
          isFamily: true,
          familyCompletionMode: FamilyCompletionMode.individual,
          completedByUserIds: const ['alice'],
          status: TaskStatus.pending,
        );
        expect(
          TaskAttributionCalculator.calculateUserPendingPlannedMinutes(
            instance: individualFamily,
            currentUserId: 'alice',
            familyMemberCount: 3,
            durationMinutes: 30,
          ),
          0.0,
        );
        expect(
          TaskAttributionCalculator.calculateUserPendingPlannedMinutes(
            instance: individualFamily,
            currentUserId: 'bob',
            familyMemberCount: 3,
            durationMinutes: 30,
          ),
          30.0,
        );

        final anyoneFamily = _buildInstance(
          isFamily: true,
          familyCompletionMode: FamilyCompletionMode.anyone,
          status: TaskStatus.pending,
        );
        expect(
          TaskAttributionCalculator.calculateUserPendingPlannedMinutes(
            instance: anyoneFamily,
            currentUserId: 'alice',
            familyMemberCount: 3,
            durationMinutes: 60,
          ),
          20.0,
        );

        final personalUnassigned = _buildInstance(
          isFamily: false,
          status: TaskStatus.pending,
        );
        expect(
          TaskAttributionCalculator.calculateUserPendingPlannedMinutes(
            instance: personalUnassigned,
            currentUserId: 'alice',
            familyMemberCount: 3,
            durationMinutes: 50,
          ),
          50.0,
        );
      },
    );
  });

  group('TaskAttributionCalculator.isInstanceAttributableToUserForCapacity', () {
    test('excludes skipped and failed instances', () {
      final task = _buildSchedule();
      expect(
        TaskAttributionCalculator.isInstanceAttributableToUserForCapacity(
          instance: _buildInstance(status: TaskStatus.skipped),
          task: task,
          userId: 'alice',
        ),
        isFalse,
      );
      expect(
        TaskAttributionCalculator.isInstanceAttributableToUserForCapacity(
          instance: _buildInstance(status: TaskStatus.failed),
          task: task,
          userId: 'alice',
        ),
        isFalse,
      );
    });

    test(
      'attributes family and personal tasks using instance or schedule assignedUserId and completion actor',
      () {
        final familyTask = _buildSchedule(isFamily: true);

        // Assigned family instance only counts for assignee
        final assignedFamilyInst = _buildInstance(
          isFamily: true,
          assignedUserId: 'alice',
          status: TaskStatus.pending,
        );
        expect(
          TaskAttributionCalculator.isInstanceAttributableToUserForCapacity(
            instance: assignedFamilyInst,
            task: familyTask,
            userId: 'alice',
          ),
          isTrue,
        );
        expect(
          TaskAttributionCalculator.isInstanceAttributableToUserForCapacity(
            instance: assignedFamilyInst,
            task: familyTask,
            userId: 'bob',
          ),
          isFalse,
        );

        // Completed unassigned anyone-mode family instance counts only for completer
        final completedAnyoneInst = _buildInstance(
          isFamily: true,
          familyCompletionMode: FamilyCompletionMode.anyone,
          status: TaskStatus.completed,
          completedByUserId: 'alice',
        );
        expect(
          TaskAttributionCalculator.isInstanceAttributableToUserForCapacity(
            instance: completedAnyoneInst,
            task: familyTask,
            userId: 'alice',
          ),
          isTrue,
        );
        expect(
          TaskAttributionCalculator.isInstanceAttributableToUserForCapacity(
            instance: completedAnyoneInst,
            task: familyTask,
            userId: 'bob',
          ),
          isFalse,
        );

        // Personal task inherits assignedUserId from schedule when instance assignedUserId is null
        final personalAssignedTask = _buildSchedule(
          isFamily: false,
          assignedUserId: 'bob',
        );
        final personalInst = _buildInstance(
          isFamily: false,
          status: TaskStatus.pending,
        );
        expect(
          TaskAttributionCalculator.isInstanceAttributableToUserForCapacity(
            instance: personalInst,
            task: personalAssignedTask,
            userId: 'alice',
          ),
          isFalse,
        );
        expect(
          TaskAttributionCalculator.isInstanceAttributableToUserForCapacity(
            instance: personalInst,
            task: personalAssignedTask,
            userId: 'bob',
          ),
          isTrue,
        );
      },
    );
  });
}
