import 'task_schedule.dart';

class AutoAllocator {
  /// Allocates [familyTasks] to [userIds] based on user weekly capacities,
  /// current personal task efforts, task priority, and user preferences.
  ///
  /// Returns a map of `taskId -> userId` representing the assignments.
  static Map<String, String> allocate({
    required List<String> userIds,
    required Map<String, double> userWeeklyCapacities, // in minutes
    required Map<String, double> userPersonalEfforts, // in minutes
    required List<TaskSchedule> familyTasks,
  }) {
    // Initialize remaining capacities in minutes
    final remainingCapacities = <String, double>{};
    for (final userId in userIds) {
      final capacity = userWeeklyCapacities[userId] ?? 0.0;
      final personalEffort = userPersonalEfforts[userId] ?? 0.0;
      remainingCapacities[userId] = (capacity - personalEffort).clamp(
        0.0,
        double.infinity,
      );
    }

    final assignments = <String, String>{}; // taskId -> userId

    // Sort family tasks by priority: High -> Medium -> Low
    final sortedTasks = List<TaskSchedule>.from(familyTasks)
      ..sort((a, b) => b.priority.index.compareTo(a.priority.index));

    for (final task in sortedTasks) {
      final taskEffort = task.estimatedDuration?.inMinutes.toDouble() ?? 0.0;

      String? bestUser;
      double bestScore = -1.0;

      for (final userId in userIds) {
        final remainingCap = remainingCapacities[userId] ?? 0.0;

        // Skip users with insufficient capacity (only if task requires effort)
        if (taskEffort > 0 && remainingCap < taskEffort) {
          continue;
        }

        // Starring preference: 2.5x weight multiplier if starred
        final isStarred = task.preferredBy[userId] == true;
        final preferenceMultiplier = isStarred ? 2.5 : 1.0;

        // Priority weighting: Low (10), Medium (20), High (30)
        final priorityWeight = (task.priority.index + 1) * 10.0;

        // Combine scoring: priority weight + preference weighting + remaining capacity tiebreaker
        final score =
            (priorityWeight * preferenceMultiplier) + (remainingCap / 60.0);

        if (score > bestScore) {
          bestScore = score;
          bestUser = userId;
        }
      }

      if (bestUser != null) {
        assignments[task.id] = bestUser;
        // Subtract task effort from user's remaining capacity
        remainingCapacities[bestUser] =
            remainingCapacities[bestUser]! - taskEffort;
      }
    }

    return assignments;
  }
}
