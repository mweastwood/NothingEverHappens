import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_sync_conflict_resolver.dart';

TaskInstance _buildInstance({
  String id = 'inst-1',
  String title = 'Test Task',
  String description = 'Desc',
  TaskStatus status = TaskStatus.pending,
  String? statusReason,
  DateTime? updatedAt,
  List<String> completedByUserIds = const [],
  WorkflowInstancePayload? workflowPayload,
}) {
  return TaskInstance(
    id: id,
    scheduleId: 'sched-1',
    ruleId: 'rule-1',
    title: title,
    description: description,
    scheduledDate: const CivilDay(year: 2026, month: 9, day: 16),
    startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
    dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
    status: status,
    statusReason: statusReason,
    updatedAt: updatedAt ?? DateTime.utc(2026, 9, 16, 12, 0),
    completedByUserIds: completedByUserIds,
    workflowPayload: workflowPayload,
  );
}

void main() {
  group('TaskSyncConflictResolver', () {
    test('isStrictlyNewer compares timestamps at millisecond resolution', () {
      final t1 = DateTime.utc(2026, 9, 16, 12, 0, 0, 100, 100);
      final t1SubMs = DateTime.utc(2026, 9, 16, 12, 0, 0, 100, 900);
      final t2 = DateTime.utc(2026, 9, 16, 12, 0, 0, 101, 0);

      expect(TaskSyncConflictResolver.isStrictlyNewer(t1SubMs, t1), isFalse);
      expect(TaskSyncConflictResolver.isStrictlyNewer(t2, t1), isTrue);
      expect(TaskSyncConflictResolver.isStrictlyNewer(t1, t2), isFalse);
    });

    test(
      'hasSlotUserActionOrProgress distinguishes user progress from scheduler skips',
      () {
        expect(
          TaskSyncConflictResolver.hasSlotUserActionOrProgress(
            _buildInstance(status: TaskStatus.pending),
          ),
          isFalse,
        );
        expect(
          TaskSyncConflictResolver.hasSlotUserActionOrProgress(
            _buildInstance(
              status: TaskStatus.skipped,
              statusReason: InstanceStatusReason.schedulerAutoDismiss.value,
            ),
          ),
          isFalse,
        );
        expect(
          TaskSyncConflictResolver.hasSlotUserActionOrProgress(
            _buildInstance(
              status: TaskStatus.completed,
              statusReason: InstanceStatusReason.userCompleted.value,
            ),
          ),
          isTrue,
        );
        expect(
          TaskSyncConflictResolver.hasSlotUserActionOrProgress(
            _buildInstance(completedByUserIds: const ['u-1']),
          ),
          isTrue,
        );
        expect(
          TaskSyncConflictResolver.hasSlotUserActionOrProgress(
            _buildInstance(
              workflowPayload: const WorkflowInstancePayload(
                workflowType: 'mealWorkflow',
                workflowGroupId: 'g-1',
                stage: WorkflowStage.shoppingList,
              ),
            ),
          ),
          isTrue,
        );
        expect(
          TaskSyncConflictResolver.hasSlotUserActionOrProgress(
            _buildInstance(
              workflowPayload: const WorkflowInstancePayload(
                workflowType: 'mealWorkflow',
                workflowGroupId: 'g-1',
                stage: WorkflowStage.selectMeal,
              ),
            ),
          ),
          isFalse,
        );
      },
    );

    test(
      'isEquivalentPendingSlotInstance checks pending status and slot fields',
      () {
        final a = _buildInstance(id: 'inst-a');
        final b = _buildInstance(id: 'inst-b');
        final completed = _buildInstance(
          id: 'inst-c',
          status: TaskStatus.completed,
        );
        final renamed = _buildInstance(id: 'inst-d', title: 'Renamed');

        expect(
          TaskSyncConflictResolver.isEquivalentPendingSlotInstance(a, b),
          isTrue,
        );
        expect(
          TaskSyncConflictResolver.isEquivalentPendingSlotInstance(
            a,
            completed,
          ),
          isFalse,
        );
        expect(
          TaskSyncConflictResolver.isEquivalentPendingSlotInstance(a, renamed),
          isFalse,
        );
      },
    );

    test(
      'doesLocalWin prioritizes user actions over scheduler actions regardless of timestamp',
      () {
        final olderUser = _buildInstance(
          status: TaskStatus.completed,
          statusReason: InstanceStatusReason.userCompleted.value,
          updatedAt: DateTime.utc(2026, 9, 16, 10, 0),
        );
        final newerScheduler = _buildInstance(
          status: TaskStatus.skipped,
          statusReason: InstanceStatusReason.schedulerAutoDismiss.value,
          updatedAt: DateTime.utc(2026, 9, 16, 12, 0),
        );

        expect(
          TaskSyncConflictResolver.doesLocalWin(olderUser, newerScheduler),
          isTrue,
        );
        expect(
          TaskSyncConflictResolver.doesLocalWin(newerScheduler, olderUser),
          isFalse,
        );

        final newerUser = _buildInstance(
          status: TaskStatus.skipped,
          statusReason: InstanceStatusReason.userDismissed.value,
          updatedAt: DateTime.utc(2026, 9, 16, 14, 0),
        );
        expect(
          TaskSyncConflictResolver.doesLocalWin(newerUser, olderUser),
          isTrue,
        );
        expect(
          TaskSyncConflictResolver.doesLocalWin(olderUser, newerUser),
          isFalse,
        );
      },
    );

    test(
      'doesSlotCandidateWin prefers user progress, then earlier canonical pending spawn, then lexical ID tiebreaker',
      () {
        final earlierPending = _buildInstance(
          id: 'inst-z',
          updatedAt: DateTime.utc(2026, 9, 16, 10, 0),
        );
        final laterPending = _buildInstance(
          id: 'inst-a',
          updatedAt: DateTime.utc(2026, 9, 16, 11, 0),
        );

        // Earlier-spawned canonical pending instance wins over later duplicate lookahead spawn
        expect(
          TaskSyncConflictResolver.doesSlotCandidateWin(
            earlierPending,
            laterPending,
          ),
          isTrue,
        );
        expect(
          TaskSyncConflictResolver.doesSlotCandidateWin(
            laterPending,
            earlierPending,
          ),
          isFalse,
        );

        // Same timestamp uses deterministic lexical ID tiebreaker
        final tieA = _buildInstance(
          id: 'inst-a',
          updatedAt: DateTime.utc(2026, 9, 16, 10, 0),
        );
        final tieB = _buildInstance(
          id: 'inst-b',
          updatedAt: DateTime.utc(2026, 9, 16, 10, 0),
        );
        expect(
          TaskSyncConflictResolver.doesSlotCandidateWin(tieA, tieB),
          isTrue,
        );
        expect(
          TaskSyncConflictResolver.doesSlotCandidateWin(tieB, tieA),
          isFalse,
        );

        // User progress beats plain pending regardless of spawn order
        final withProgress = _buildInstance(
          id: 'inst-progress',
          status: TaskStatus.completed,
          statusReason: InstanceStatusReason.userCompleted.value,
          updatedAt: DateTime.utc(2026, 9, 16, 9, 0),
        );
        expect(
          TaskSyncConflictResolver.doesSlotCandidateWin(
            withProgress,
            earlierPending,
          ),
          isTrue,
        );
        expect(
          TaskSyncConflictResolver.doesSlotCandidateWin(
            earlierPending,
            withProgress,
          ),
          isFalse,
        );
      },
    );
  });
}
