import 'dart:math';
import 'package:flutter/material.dart';
import '../logic/app_clock.dart';
import '../logic/civil_day.dart';
import '../logic/dashboard_stats.dart';
import 'timeline_chart_components.dart';

class FamilyHistoryStatsCard extends StatefulWidget {
  final FamilyLastWeekStats stats;
  final void Function(DailyStatsData)? onDayActivityTap;

  const FamilyHistoryStatsCard({
    super.key,
    required this.stats,
    this.onDayActivityTap,
  });

  @override
  State<FamilyHistoryStatsCard> createState() => _FamilyHistoryStatsCardState();
}

class _FamilyHistoryStatsCardState extends State<FamilyHistoryStatsCard> {
  static const double _itemWidth = 44.0;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerOnToday());
  }

  @override
  void didUpdateWidget(covariant FamilyHistoryStatsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerOnToday());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _centerOnToday() {
    final today = CivilDay.fromDateTime(AppClock.now);
    final todayIndex = widget.stats.dailyStats.indexWhere(
      (d) => d.day == today,
    );
    centerTimelineOnIndex(_scrollController, todayIndex, itemWidth: _itemWidth);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = widget.stats;
    final today = CivilDay.fromDateTime(AppClock.now);

    double maxActivity = 0.0;
    for (final dayData in stats.dailyStats) {
      final totalHours =
          dayData.completedHours +
          dayData.plannedHours +
          dayData.skippedHours +
          dayData.missedHours;
      if (totalHours > maxActivity) {
        maxActivity = totalHours;
      }
    }
    final scaleMax = max(maxActivity, 1.0);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Title, Date range badge, Family badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.diversity_3_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Family Timeline',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        child: Text(
                          formatTimelineDateRange(
                            startMonth: stats.startDay.month,
                            startDay: stats.startDay.day,
                            endMonth: stats.endDay.month,
                            endDay: stats.endDay.day,
                          ),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    stats.familyName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Shared family chores (rolling 13 days)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            // Timeline Guide (Past / Today / Future)
            const TimelineGuideRow(),
            const SizedBox(height: 12),

            // 13-Day Horizontal Timeline Strip
            if (stats.dailyStats.isNotEmpty) ...[
              TimelineScrollStrip(
                itemCount: stats.dailyStats.length,
                itemWidth: _itemWidth,
                scrollController: _scrollController,
                itemBuilder: (context, index) => _buildDayColumn(
                  context,
                  stats.dailyStats[index],
                  scaleMax,
                  today,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDayColumn(
    BuildContext context,
    DailyStatsData data,
    double scaleMax,
    CivilDay today,
  ) {
    final day = data.day;
    final dateStr =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final isToday = day == today;
    final isPast = day.isBefore(today);
    final dateTime = DateTime(day.year, day.month, day.day);

    return TimelineDayColumnShell(
      gestureKey: Key('family_day_bar_$dateStr'),
      subtreeKey: Key('family_activity_bar_$dateStr'),
      onTap: () {
        if (widget.onDayActivityTap != null) {
          widget.onDayActivityTap!(data);
        }
      },
      isToday: isToday,
      weekday: dateTime.weekday,
      dayOfMonth: day.day,
      stackChildren: [_buildBarFill(context, data, scaleMax, isPast, isToday)],
    );
  }

  Widget _buildBarFill(
    BuildContext context,
    DailyStatsData data,
    double scaleMax,
    bool isPast,
    bool isToday,
  ) {
    final theme = Theme.of(context);

    if (isPast) {
      final resolved = resolvePastDayActivityHours(
        onTimeHours: data.completedOnTimeHours,
        overdueHours: data.completedOverdueHours,
        seriouslyOverdueHours: data.completedSeriouslyOverdueHours,
        skippedHours: data.skippedHours + data.missedHours,
        statsData: data,
      );
      return TimelineStackedActivityBar(
        scaleMax: scaleMax,
        onTimeHours: resolved.onTimeHours,
        overdueHours: resolved.overdueHours,
        seriouslyOverdueHours: resolved.seriouslyOverdueHours,
        skippedHours: resolved.skippedHours,
      );
    }

    if (isToday) {
      double completedHours = data.completedHours;
      double plannedHours = data.plannedHours;

      if (completedHours == 0 && data.completedCount > 0) {
        completedHours = 0.25;
      }
      if (plannedHours == 0 && data.plannedCount > 0) {
        plannedHours = 0.25;
      }

      return TimelineStackedActivityBar(
        scaleMax: scaleMax,
        onTimeHours: completedHours,
        overdueHours: 0.0,
        seriouslyOverdueHours: 0.0,
        skippedHours: 0.0,
        plannedHours: plannedHours,
        plannedColor: theme.colorScheme.primary,
      );
    }

    // Future Day
    double plannedHours = data.plannedHours;
    if (plannedHours == 0 && data.plannedCount > 0) {
      plannedHours = 0.25;
    }
    if (plannedHours <= 0) return const SizedBox.shrink();

    final double fillHeight = (plannedHours / scaleMax * 120.0).clamp(
      8.0,
      120.0,
    );

    return Container(
      height: fillHeight,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
