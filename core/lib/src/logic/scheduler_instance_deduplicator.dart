import '../models/civil_day.dart';
import '../models/task_instance.dart';

class SchedulerInstanceDeduplicator {
  const SchedulerInstanceDeduplicator();

  static TaskInstance selectCanonicalInstance(List<TaskInstance> instances) {
    assert(instances.isNotEmpty);
    if (instances.length == 1) return instances.first;

    final sorted = List<TaskInstance>.from(instances);
    sorted.sort((a, b) {
      int score(TaskInstance inst) {
        if (inst.status == TaskStatus.completed || inst.completedAt != null) {
          return 2;
        }
        if (inst.status != TaskStatus.pending) {
          return 1;
        }
        return 0;
      }

      final scoreA = score(a);
      final scoreB = score(b);
      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA);
      }
      final timeComp = b.updatedAt.compareTo(a.updatedAt);
      if (timeComp != 0) return timeComp;
      return b.id.compareTo(a.id);
    });

    return sorted.first;
  }

  static Map<CivilDay, TaskInstance> deduplicateRuleInstancesByDate(
    List<TaskInstance> ruleInstances,
    List<String> toDelete,
  ) {
    final Map<CivilDay, List<TaskInstance>> instancesByDate = {};
    for (final inst in ruleInstances) {
      instancesByDate.putIfAbsent(inst.scheduledDate, () => []).add(inst);
    }

    final Map<CivilDay, TaskInstance> canonicalByDate = {};
    for (final entry in instancesByDate.entries) {
      final insts = entry.value;
      if (insts.length > 1) {
        final Map<WorkflowStage?, List<TaskInstance>> instancesByStage = {};
        for (final inst in insts) {
          instancesByStage
              .putIfAbsent(inst.workflowPayload?.stage, () => [])
              .add(inst);
        }

        final List<TaskInstance> stageCanonicals = [];
        for (final stageInsts in instancesByStage.values) {
          if (stageInsts.length > 1) {
            final stageCanonical = selectCanonicalInstance(stageInsts);
            stageCanonicals.add(stageCanonical);
            for (final inst in stageInsts) {
              if (inst.id != stageCanonical.id && !toDelete.contains(inst.id)) {
                toDelete.add(inst.id);
              }
            }
          } else {
            stageCanonicals.add(stageInsts.first);
          }
        }
        if (stageCanonicals.length > 1) {
          final pendingStages = stageCanonicals
              .where((inst) => inst.status == TaskStatus.pending)
              .toList();
          if (pendingStages.isNotEmpty) {
            pendingStages.sort((a, b) {
              final stageA = a.workflowPayload?.stage.index ?? 0;
              final stageB = b.workflowPayload?.stage.index ?? 0;
              return stageA.compareTo(stageB);
            });
            canonicalByDate[entry.key] = pendingStages.first;
          } else {
            canonicalByDate[entry.key] = selectCanonicalInstance(
              stageCanonicals,
            );
          }
        } else {
          canonicalByDate[entry.key] = selectCanonicalInstance(stageCanonicals);
        }
      } else {
        canonicalByDate[entry.key] = insts.first;
      }
    }
    return canonicalByDate;
  }
}
