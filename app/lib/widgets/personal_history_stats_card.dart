import 'package:flutter/material.dart';
import '../logic/civil_day.dart';
import '../logic/dashboard_stats.dart';
import '../logic/utils/format_utils.dart';
import 'daily_activity_breakdown_sheet.dart';

class PersonalHistoryStatsCard extends StatelessWidget {
  final PersonalLastWeekStats stats;
  final void Function(DailyStatsData)? onDayActivityTap;

  const PersonalHistoryStatsCard({
    super.key,
    required this.stats,
    this.onDayActivityTap,
  });

  String _formatDayLabel(CivilDay day) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dt = day.toDateTime();
    return weekdays[dt.weekday - 1];
  }

  String _formatDayCountLabel(DailyStatsData dayData) {
    final total =
        dayData.completedCount + dayData.skippedCount + dayData.missedCount;
    if (total == 0) return '-';
    if (dayData.skippedCount + dayData.missedCount > 0) {
      return '${dayData.completedCount}/$total';
    }
    return '${dayData.completedCount}';
  }

  String _formatDateRange(CivilDay start, CivilDay end) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final startMonth = months[start.month - 1];
    final endMonth = months[end.month - 1];
    if (start.month == end.month) {
      return '$startMonth ${start.day} – ${end.day}';
    }
    return '$startMonth ${start.day} – $endMonth ${end.day}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratePercent = (stats.completionRate * 100).round();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Your Past Week',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  _formatDateRange(stats.startDay, stats.endDay),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Past 7 days activity & follow-through',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            // KPI Metric Tiles
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    context,
                    key: const Key('personal_stats_completed_tile'),
                    title: '${stats.completedCount}',
                    subtitle: 'Completed',
                    icon: Icons.check_circle_outline,
                    iconColor: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    context,
                    key: const Key('personal_stats_time_tile'),
                    title: formatDurationHours(stats.completedHours),
                    subtitle: 'Time Spent',
                    icon: Icons.schedule,
                    iconColor: theme.colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    context,
                    key: const Key('personal_stats_rate_tile'),
                    title: '$ratePercent%',
                    subtitle: 'Completion',
                    icon: Icons.track_changes,
                    iconColor: ratePercent >= 80
                        ? Colors.green
                        : theme.colorScheme.primary,
                  ),
                ),
              ],
            ),

            // Callout for skipped or missed tasks
            if (stats.skippedCount > 0 || stats.missedCount > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.6,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _buildCalloutText(
                          stats.skippedCount,
                          stats.missedCount,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Daily 7-Day Activity Strip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daily Activity',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  'Tap bar for details',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildDailyStrip(context),
          ],
        ),
      ),
    );
  }

  String _buildCalloutText(int skipped, int missed) {
    final parts = <String>[];
    if (skipped > 0) {
      parts.add('$skipped skipped');
    }
    if (missed > 0) {
      parts.add('$missed missed/overdue');
    }
    return parts.join(' · ');
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required Key key,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    final theme = Theme.of(context);
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDailyStrip(BuildContext context) {
    final theme = Theme.of(context);
    int maxCount = 0;
    for (final d in stats.dailyStats) {
      final total = d.completedCount + d.skippedCount + d.missedCount;
      if (total > maxCount) maxCount = total;
    }
    final double scaleMax = maxCount > 0 ? maxCount.toDouble() : 1.0;

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: stats.dailyStats.map((dayData) {
              final day = dayData.day;
              final isToday = day == stats.endDay;
              final dayLabel = _formatDayLabel(day);
              final totalDay =
                  dayData.completedCount +
                  dayData.skippedCount +
                  dayData.missedCount;
              final completed = dayData.completedCount;
              final missed = dayData.skippedCount + dayData.missedCount;

              final double totalBarHeight = totalDay > 0
                  ? (totalDay / scaleMax * 120.0).clamp(8.0, 120.0)
                  : 0.0;

              return Expanded(
                child: InkWell(
                  key: Key('daily_activity_bar_${day.toIso8601String()}'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    if (onDayActivityTap != null) {
                      onDayActivityTap!(dayData);
                    } else {
                      DailyActivityBreakdownSheet.show(
                        context,
                        dayData,
                        isFamilyTimeline: false,
                      );
                    }
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: 14,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _formatDayCountLabel(dayData),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 9,
                              fontWeight: isToday
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 120,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Container(
                              width: double.infinity,
                              height: 120,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(6),
                                border: isToday
                                    ? Border.all(
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.5),
                                        width: 1,
                                      )
                                    : null,
                              ),
                            ),
                            if (totalBarHeight > 0)
                              Container(
                                height: totalBarHeight,
                                width: double.infinity,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (missed > 0)
                                        Flexible(
                                          flex: missed,
                                          child: Container(
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  theme.colorScheme.error,
                                                  theme.colorScheme.error
                                                      .withValues(alpha: 0.7),
                                                ],
                                                begin: Alignment.bottomCenter,
                                                end: Alignment.topCenter,
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (completed > 0)
                                        Flexible(
                                          flex: completed,
                                          child: Container(
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  theme.colorScheme.primary,
                                                  theme.colorScheme.primary
                                                      .withValues(alpha: 0.7),
                                                ],
                                                begin: Alignment.bottomCenter,
                                                end: Alignment.topCenter,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dayLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: isToday
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isToday
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '${day.day}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          fontWeight: isToday
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 16,
              height: 12,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Completed',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 24),
            Container(
              width: 16,
              height: 12,
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Skipped / Missed',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
