import 'package:flutter/material.dart';
import '../logic/app_clock.dart';
import '../logic/dashboard_stats.dart';
import 'timeline_chart_components.dart';

export 'timeline_chart_components.dart'
    show HatchedPatternPainter, DashedRectPainter;

class DailyCapacityData {
  final DateTime date;
  final double capacityHours;
  final double plannedMinutes;
  final double completedMinutes;
  final bool isOverridden;
  final DailyStatsData? statsData;

  const DailyCapacityData({
    required this.date,
    required this.capacityHours,
    required this.plannedMinutes,
    this.completedMinutes = 0.0,
    required this.isOverridden,
    this.statsData,
  });

  double get completedHours => completedMinutes / 60.0;
  double get plannedHours => plannedMinutes / 60.0;

  double get completedOnTimeHours {
    if (statsData != null &&
        (statsData!.completedOnTimeHours > 0 ||
            statsData!.completedOverdueHours > 0 ||
            statsData!.completedSeriouslyOverdueHours > 0)) {
      return statsData!.completedOnTimeHours;
    }
    return completedHours;
  }

  double get completedOverdueHours =>
      statsData?.completedModeratelyOverdueHours ?? 0.0;
  double get completedSeriouslyOverdueHours =>
      statsData?.completedSeriouslyOverdueHours ?? 0.0;
  double get skippedHours => statsData?.skippedHours ?? 0.0;
  double get missedHours => statsData?.missedHours ?? 0.0;
}

class WeeklyCapacityChart extends StatefulWidget {
  final List<DailyCapacityData> daysData;
  final void Function(DateTime) onDayTap;
  final void Function(DailyStatsData)? onDayActivityTap;
  final VoidCallback onEditDefaultCapacity;
  final PersonalLastWeekStats? stats;

  const WeeklyCapacityChart({
    super.key,
    required this.daysData,
    required this.onDayTap,
    this.onDayActivityTap,
    required this.onEditDefaultCapacity,
    this.stats,
  });

  @override
  State<WeeklyCapacityChart> createState() => _WeeklyCapacityChartState();
}

class _WeeklyCapacityChartState extends State<WeeklyCapacityChart> {
  static const double _itemWidth = 44.0;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerOnToday());
  }

  @override
  void didUpdateWidget(covariant WeeklyCapacityChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerOnToday());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _centerOnToday() {
    final today = AppClock.now;
    final todayIndex = widget.daysData.indexWhere(
      (d) =>
          d.date.year == today.year &&
          d.date.month == today.month &&
          d.date.day == today.day,
    );
    centerTimelineOnIndex(_scrollController, todayIndex, itemWidth: _itemWidth);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = AppClock.now;

    double peakValue = 0.0;
    for (final data in widget.daysData) {
      final capacityHours = data.capacityHours;
      final plannedHours = data.plannedHours;
      final completedHours = data.completedHours;
      final isPast = DateTime(
        data.date.year,
        data.date.month,
        data.date.day,
      ).isBefore(DateTime(today.year, today.month, today.day));
      final isToday =
          data.date.day == today.day &&
          data.date.month == today.month &&
          data.date.year == today.year;

      final historyWork = completedHours + data.skippedHours;
      final totalWork = isToday
          ? (completedHours + plannedHours + data.skippedHours)
          : (isPast ? historyWork : plannedHours);

      if (capacityHours > peakValue) peakValue = capacityHours;
      if (totalWork > peakValue) peakValue = totalWork;
    }
    final double scaleMax = peakValue > 0 ? peakValue : 8.0;

    final dateRangeStr = widget.daysData.isNotEmpty
        ? formatTimelineDateRange(
            startMonth: widget.daysData.first.date.month,
            startDay: widget.daysData.first.date.day,
            endMonth: widget.daysData.last.date.month,
            endDay: widget.daysData.last.date.day,
          )
        : '';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.insights_rounded,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Personal Timeline',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (dateRangeStr.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          dateRangeStr,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                TextButton.icon(
                  key: const Key('edit_default_capacity_button'),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit Capacity'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                  onPressed: widget.onEditDefaultCapacity,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Timeline Guide (Past 6 Days / Today / Future 6 Days)
            const TimelineGuideRow(),
            const SizedBox(height: 12),

            // 13-Day Horizontal Timeline Strip
            TimelineScrollStrip(
              itemCount: widget.daysData.length,
              itemWidth: _itemWidth,
              scrollController: _scrollController,
              itemBuilder: (context, index) => _buildDayColumn(
                context,
                widget.daysData[index],
                scaleMax,
                today,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayColumn(
    BuildContext context,
    DailyCapacityData data,
    double scaleMax,
    DateTime today,
  ) {
    final theme = Theme.of(context);
    final date = data.date;
    final capacity = data.capacityHours;
    final isOverridden = data.isOverridden;

    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final isToday =
        date.day == today.day &&
        date.month == today.month &&
        date.year == today.year;
    final isPast = DateTime(
      date.year,
      date.month,
      date.day,
    ).isBefore(DateTime(today.year, today.month, today.day));

    // Workload for past, today, and future
    final double workHours = isToday
        ? (data.completedHours + data.plannedHours)
        : (isPast ? data.completedHours : data.plannedHours);

    final double barHeight = capacity > 0
        ? (capacity / scaleMax * 120.0).clamp(8.0, 120.0)
        : 0.0;

    final isOverCapacity = workHours > capacity;

    return TimelineDayColumnShell(
      gestureKey: Key('capacity_bar_$dateStr'),
      subtreeKey: Key('daily_activity_bar_$dateStr'),
      onTap: () {
        if (widget.onDayActivityTap != null && data.statsData != null) {
          widget.onDayActivityTap!(data.statsData!);
        } else {
          widget.onDayTap(date);
        }
      },
      isToday: isToday,
      weekday: date.weekday,
      dayOfMonth: date.day,
      stackChildren: [
        _buildBarFill(
          context,
          data,
          scaleMax,
          isPast,
          isToday,
          isOverCapacity,
          isOverridden,
        ),
        if (barHeight > 0 && !isPast)
          IgnorePointer(
            child: Container(
              height: barHeight,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              child: CustomPaint(
                painter: DashedRectPainter(
                  color: isToday
                      ? theme.colorScheme.primary
                      : isOverridden
                      ? theme.colorScheme.tertiary
                      : theme.colorScheme.outlineVariant,
                  strokeWidth: isToday ? 2.0 : 1.5,
                  borderRadius: 6.0,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBarFill(
    BuildContext context,
    DailyCapacityData data,
    double scaleMax,
    bool isPast,
    bool isToday,
    bool isOverCapacity,
    bool isOverridden,
  ) {
    final theme = Theme.of(context);
    final Color plannedColor = isOverCapacity
        ? theme.colorScheme.error
        : isOverridden
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;

    if (isPast) {
      final resolved = resolvePastDayActivityHours(
        onTimeHours: data.completedOnTimeHours,
        overdueHours: data.completedOverdueHours,
        seriouslyOverdueHours: data.completedSeriouslyOverdueHours,
        skippedHours: data.skippedHours + data.missedHours,
        statsData: data.statsData,
      );
      return TimelineStackedActivityBar(
        scaleMax: scaleMax,
        onTimeHours: resolved.onTimeHours,
        overdueHours: resolved.overdueHours,
        seriouslyOverdueHours: resolved.seriouslyOverdueHours,
        skippedHours: resolved.skippedHours,
      );
    }

    if (isToday &&
        data.statsData != null &&
        (data.completedHours > 0 ||
            data.skippedHours > 0 ||
            data.missedHours > 0)) {
      return TimelineStackedActivityBar(
        scaleMax: scaleMax,
        onTimeHours: data.completedOnTimeHours,
        overdueHours: data.completedOverdueHours,
        seriouslyOverdueHours: data.completedSeriouslyOverdueHours,
        skippedHours: data.skippedHours + data.missedHours,
        plannedHours: data.plannedHours,
        plannedColor: plannedColor,
      );
    }

    // Future / standard planned workload
    final double workHours = isToday
        ? (data.completedHours + data.plannedHours)
        : data.plannedHours;

    final double fillHeight = workHours > 0
        ? (workHours / scaleMax * 120.0).clamp(8.0, 120.0)
        : 0.0;

    if (fillHeight <= 0) return const SizedBox.shrink();

    return Container(
      height: fillHeight,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: isToday ? plannedColor.withValues(alpha: 0.5) : plannedColor,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
