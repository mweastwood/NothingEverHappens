import 'package:flutter/material.dart';
import '../logic/civil_day.dart';
import '../logic/dashboard_stats.dart';
import '../logic/utils/format_utils.dart';

class PersonalHistoryStatsCard extends StatelessWidget {
  final PersonalLastWeekStats stats;

  const PersonalHistoryStatsCard({super.key, required this.stats});

  String _formatDayLabel(CivilDay day) {
    const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final dt = day.toDateTime();
    return weekdays[dt.weekday - 1];
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
            Text(
              'Daily Activity',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
    int maxCount = 1;
    for (final d in stats.dailyStats) {
      final total = d.completedCount + d.skippedCount + d.missedCount;
      if (total > maxCount) maxCount = total;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: stats.dailyStats.map((dayData) {
        final totalDay =
            dayData.completedCount + dayData.skippedCount + dayData.missedCount;
        final isToday = dayData.day == stats.endDay;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mini bar container
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(4),
                    border: isToday
                        ? Border.all(color: theme.colorScheme.primary, width: 1)
                        : null,
                  ),
                  alignment: Alignment.bottomCenter,
                  child: totalDay == 0
                      ? Container(
                          height: 3,
                          width: 8,
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (dayData.skippedCount + dayData.missedCount > 0)
                              Container(
                                height:
                                    ((dayData.skippedCount +
                                                dayData.missedCount) /
                                            maxCount *
                                            44)
                                        .clamp(4.0, 44.0),
                                width: double.infinity,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.error.withValues(
                                    alpha: 0.6,
                                  ),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(2),
                                  ),
                                ),
                              ),
                            if (dayData.completedCount > 0)
                              Container(
                                height: (dayData.completedCount / maxCount * 44)
                                    .clamp(4.0, 44.0),
                                width: double.infinity,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.vertical(
                                    top:
                                        dayData.skippedCount +
                                                dayData.missedCount >
                                            0
                                        ? Radius.zero
                                        : const Radius.circular(2),
                                    bottom: const Radius.circular(2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDayLabel(dayData.day),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    color: isToday
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '${dayData.day.day}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
