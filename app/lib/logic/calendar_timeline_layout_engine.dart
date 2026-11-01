import 'dart:math';

import 'calendar_day_task.dart';
import 'timeline_placement_calculator.dart';

/// Positioned layout geometry for a task rendered on the daily timeline.
class TimelineLayoutItem {
  final CalendarDayTask task;
  final double left;
  final double width;
  final double top;
  final double height;
  final int columnIndex;
  final int totalColumns;

  const TimelineLayoutItem({
    required this.task,
    required this.left,
    required this.width,
    required this.top,
    required this.height,
    required this.columnIndex,
    required this.totalColumns,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimelineLayoutItem &&
          runtimeType == other.runtimeType &&
          task == other.task &&
          left == other.left &&
          width == other.width &&
          top == other.top &&
          height == other.height &&
          columnIndex == other.columnIndex &&
          totalColumns == other.totalColumns;

  @override
  int get hashCode =>
      Object.hash(task, left, width, top, height, columnIndex, totalColumns);
}

/// Engine for interval-clustering and greedy column-packing of tasks on a daily timeline.
abstract final class CalendarTimelineLayoutEngine {
  static int getStartMinute(CalendarDayTask task) {
    if (task.instance != null) {
      final start = task.instance!.startRelativeTime;
      if (start.dayOffset < 0) return 0;
      if (start.dayOffset > 0) return 1440;
      return (start.hour * 60 + start.minute).clamp(0, 1440);
    } else if (task.matchingRule != null) {
      final start = task.matchingRule!.startRelativeTime;
      if (start.dayOffset < 0) return 0;
      if (start.dayOffset > 0) return 1440;
      return (start.hour * 60 + start.minute).clamp(0, 1440);
    }
    return 9 * 60;
  }

  static int getDueMinute(CalendarDayTask task) {
    if (task.instance != null) {
      final due = task.instance!.dueRelativeTime;
      if (due.dayOffset > 0) return 1440;
      if (due.dayOffset < 0) return 0;
      return (due.hour * 60 + due.minute).clamp(0, 1440);
    } else if (task.matchingRule != null) {
      final due = task.matchingRule!.dueRelativeTime;
      if (due.dayOffset > 0) return 1440;
      if (due.dayOffset < 0) return 0;
      return (due.hour * 60 + due.minute).clamp(0, 1440);
    }
    return 10 * 60;
  }

  static int getEstimatedDurationMinutes(CalendarDayTask task) {
    final est = task.estimatedDuration ?? task.schedule?.estimatedDuration;
    if (est != null && est.inMinutes > 0) {
      return est.inMinutes;
    }
    final startMin = getStartMinute(task);
    final dueMin = getDueMinute(task);
    final window = dueMin - startMin;
    if (window > 0) {
      return min(window, 30);
    }
    return 30;
  }

  static List<TimelineLayoutItem> layoutTasks(
    List<CalendarDayTask> tasks,
    double availableWidth,
  ) {
    if (tasks.isEmpty) return const [];

    final placements = TimelinePlacementCalculator.computePlacements(
      tasks,
      getStartMinute: getStartMinute,
      getDueMinute: getDueMinute,
      getDurationMinutes: getEstimatedDurationMinutes,
    );

    // Sort by placed start minute, then placed duration descending
    final sortedPlacements = List<TaskTimePlacement>.from(placements)
      ..sort((a, b) {
        final cmp = a.placedStart.compareTo(b.placedStart);
        if (cmp != 0) return cmp;
        return (b.placedEnd - b.placedStart).compareTo(
          a.placedEnd - a.placedStart,
        );
      });

    // Group into clusters of overlapping tasks
    final List<List<TaskTimePlacement>> clusters = [];
    List<TaskTimePlacement> currentCluster = [];
    int clusterEnd = -1;

    for (final b in sortedPlacements) {
      if (currentCluster.isEmpty || b.placedStart < clusterEnd) {
        currentCluster.add(b);
        clusterEnd = max(clusterEnd, b.placedEnd);
      } else {
        clusters.add(currentCluster);
        currentCluster = [b];
        clusterEnd = b.placedEnd;
      }
    }
    if (currentCluster.isNotEmpty) {
      clusters.add(currentCluster);
    }

    final List<TimelineLayoutItem> items = [];
    for (final cluster in clusters) {
      items.addAll(_layoutCluster(cluster, availableWidth));
    }
    return items;
  }

  static List<TimelineLayoutItem> _layoutCluster(
    List<TaskTimePlacement> cluster,
    double availableWidth,
  ) {
    final List<int> columnEndTimes = [];
    final Map<TaskTimePlacement, int> columnAssignments = {};

    for (final b in cluster) {
      int assignedCol = -1;
      for (int c = 0; c < columnEndTimes.length; c++) {
        if (columnEndTimes[c] <= b.placedStart) {
          assignedCol = c;
          columnEndTimes[c] = b.placedEnd;
          break;
        }
      }
      if (assignedCol == -1) {
        assignedCol = columnEndTimes.length;
        columnEndTimes.add(b.placedEnd);
      }
      columnAssignments[b] = assignedCol;
    }

    final totalCols = max(1, columnEndTimes.length);
    final colWidth = (availableWidth - 4.0) / totalCols;

    final List<TimelineLayoutItem> clusterItems = [];
    for (final b in cluster) {
      final colIndex = columnAssignments[b] ?? 0;
      final left = 2.0 + colIndex * colWidth;
      final width = max(30.0, colWidth - 2.0);

      final rawHeight = (b.placedEnd - b.placedStart) * 1.0;
      final height = max(24.0, rawHeight);
      final top = (b.placedStart * 1.0)
          .clamp(0.0, max(0.0, 1440.0 - height))
          .toDouble();

      clusterItems.add(
        TimelineLayoutItem(
          task: b.task,
          left: left,
          width: width,
          top: top,
          height: height,
          columnIndex: colIndex,
          totalColumns: totalCols,
        ),
      );
    }

    return clusterItems;
  }
}
