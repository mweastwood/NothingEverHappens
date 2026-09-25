import 'dart:math';

import 'calendar_day_task.dart';

/// Placement metadata for a task positioned on the daily timeline.
class TaskTimePlacement {
  final CalendarDayTask task;
  final int startMinute;
  final int dueMinute;
  final int duration;
  final int placedStart;
  final int placedEnd;

  const TaskTimePlacement({
    required this.task,
    required this.startMinute,
    required this.dueMinute,
    required this.duration,
    required this.placedStart,
    required this.placedEnd,
  });
}

/// Computational engine for task placement and interval collision avoidance on the daily timeline.
class TimelinePlacementCalculator {
  /// Computes optimal start and end minutes for each task on the timeline:
  /// - Each task initially appears at its scheduled start time and extends for its estimated duration.
  /// - To prevent/minimize overlaps, tasks are pushed further down as long as they do not extend past their due dates.
  /// - Tasks with tighter deadlines are prioritized to stay earlier.
  static List<TaskTimePlacement> computePlacements(
    List<CalendarDayTask> tasks, {
    required int Function(CalendarDayTask) getStartMinute,
    required int Function(CalendarDayTask) getDueMinute,
    required int Function(CalendarDayTask) getDurationMinutes,
  }) {
    if (tasks.isEmpty) return const [];

    final List<({CalendarDayTask task, int startMin, int dueMin, int duration})>
    rawItems = [];
    for (final task in tasks) {
      final startMin = getStartMinute(task);
      int dueMin = getDueMinute(task);
      if (dueMin <= startMin) {
        dueMin = (startMin + 30).clamp(0, 1440);
      }
      final duration = getDurationMinutes(task).clamp(1, 1440);
      rawItems.add((
        task: task,
        startMin: startMin,
        dueMin: dueMin,
        duration: duration,
      ));
    }

    // Sort: earlier start first, earlier due date first (less wiggle room), higher priority first
    rawItems.sort((a, b) {
      final startCmp = a.startMin.compareTo(b.startMin);
      if (startCmp != 0) return startCmp;
      final dueCmp = a.dueMin.compareTo(b.dueMin);
      if (dueCmp != 0) return dueCmp;
      return b.task.priority.index.compareTo(a.task.priority.index);
    });

    final List<TaskTimePlacement> placed = [];

    int countOverlaps(int start, int end) {
      int count = 0;
      for (final p in placed) {
        if (max(p.placedStart, start) < min(p.placedEnd, end)) {
          count++;
        }
      }
      return count;
    }

    for (final item in rawItems) {
      final startMin = item.startMin;
      final dueMin = item.dueMin;
      final duration = item.duration;

      int bestTime = startMin;
      int minOverlaps = countOverlaps(startMin, startMin + duration);

      // If placing at startMin causes overlap, try to push further down
      // as long as it doesn't extend past its due date (t + duration <= dueMin).
      if (minOverlaps > 0) {
        final candidateTimes =
            placed
                .map((p) => p.placedEnd)
                .where((end) => end >= startMin && end + duration <= dueMin)
                .toSet()
                .toList()
              ..sort();

        for (final t in candidateTimes) {
          final overlaps = countOverlaps(t, t + duration);
          if (overlaps == 0) {
            bestTime = t;
            minOverlaps = 0;
            break;
          } else if (overlaps < minOverlaps) {
            minOverlaps = overlaps;
            bestTime = t;
          }
        }
      }

      final placedStart = bestTime.clamp(0, 1440);
      final placedEnd = (placedStart + duration).clamp(placedStart, 1440);

      placed.add(
        TaskTimePlacement(
          task: item.task,
          startMinute: startMin,
          dueMinute: dueMin,
          duration: duration,
          placedStart: placedStart,
          placedEnd: placedEnd,
        ),
      );
    }

    return placed;
  }
}
