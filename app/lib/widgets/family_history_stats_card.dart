import 'dart:math';
import 'package:flutter/material.dart';
import '../logic/app_clock.dart';
import '../logic/civil_day.dart';
import '../logic/dashboard_stats.dart';
import '../logic/family.dart';
import '../logic/utils/format_utils.dart';
import 'weekly_capacity_chart.dart';

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
  final ScrollController _scrollController = ScrollController();

  static const List<Color> _memberColors = [
    Color(0xFF2E7D32), // Forest green
    Color(0xFF1976D2), // Blue
    Color(0xFFE65100), // Orange
    Color(0xFF6A1B9A), // Purple
    Color(0xFF00838F), // Teal
    Color(0xFFC2185B), // Pink
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Color _getColorForIndex(int index) {
    return _memberColors[index % _memberColors.length];
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    }
    return '${parts[0].substring(0, 1)}${parts[1].substring(0, 1)}'
        .toUpperCase();
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
    final stats = widget.stats;
    final ratePercent = (stats.completionRate * 100).round();
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
                          _formatDateRange(stats.startDay, stats.endDay),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Past',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Today',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          'Future',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.trending_up,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 13-Day Horizontal Timeline Strip
            if (stats.dailyStats.isNotEmpty) ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = stats.dailyStats.length * _itemWidth;
                  final bool canFit = constraints.maxWidth >= totalWidth;

                  final children = stats.dailyStats.map((dayData) {
                    final dayColumn = _buildDayColumn(
                      context,
                      dayData,
                      scaleMax,
                      today,
                    );
                    if (canFit) {
                      return Expanded(child: dayColumn);
                    } else {
                      return SizedBox(width: _itemWidth, child: dayColumn);
                    }
                  }).toList();

                  final chartContent = SizedBox(
                    height: 180,
                    width: canFit ? constraints.maxWidth : totalWidth,
                    child: Row(
                      mainAxisAlignment: canFit
                          ? MainAxisAlignment.spaceEvenly
                          : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: children,
                    ),
                  );

                  if (canFit) {
                    return chartContent;
                  }

                  return SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: chartContent,
                  );
                },
              ),
              const SizedBox(height: 16),
            ],

            // Summary Stats Row
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    context,
                    key: const Key('family_stats_completed_tile'),
                    title: '${stats.totalCompletedCount}',
                    subtitle: 'Completed',
                    icon: Icons.task_alt,
                    iconColor: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    context,
                    key: const Key('family_stats_time_tile'),
                    title: formatDurationHours(stats.totalCompletedHours),
                    subtitle: 'Team Time',
                    icon: Icons.schedule,
                    iconColor: theme.colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    context,
                    key: const Key('family_stats_rate_tile'),
                    title: '$ratePercent%',
                    subtitle: 'Team Rate',
                    icon: Icons.handshake_outlined,
                    iconColor: ratePercent >= 80
                        ? Colors.green
                        : theme.colorScheme.primary,
                  ),
                ),
              ],
            ),

            // Skipped or missed callout for family tasks
            if (stats.totalSkippedCount > 0 || stats.totalMissedCount > 0) ...[
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
                          stats.totalSkippedCount,
                          stats.totalMissedCount,
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

            // Member breakdown list
            Text(
              'Member Contributions',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stats.memberStats.length,
              separatorBuilder: (context, index) => const Divider(height: 12),
              itemBuilder: (context, index) {
                final member = stats.memberStats[index];
                final memberColor = _getColorForIndex(index);
                final percentage = (member.contributionPercentage * 100)
                    .round();

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: memberColor.withValues(alpha: 0.15),
                        child: Text(
                          _getInitials(member.displayName),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: memberColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    member.displayName,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (member.role == FamilyRole.parent) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Parent',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            fontSize: 10,
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _buildMemberSubtitle(member),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (stats.totalCompletedCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            '$percentage%',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: memberColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
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
    final theme = Theme.of(context);
    final day = data.day;
    final dateStr =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final isToday = day == today;
    final isPast = day.isBefore(today);

    final List<String> weekdays = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    final dateTime = DateTime(day.year, day.month, day.day);
    final dayLabel = weekdays[dateTime.weekday - 1];

    return GestureDetector(
      key: Key('family_day_bar_$dateStr'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (widget.onDayActivityTap != null) {
          widget.onDayActivityTap!(data);
        }
      },
      child: KeyedSubtree(
        key: Key('family_activity_bar_$dateStr'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          decoration: isToday
              ? BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.4),
                    width: 1,
                  ),
                )
              : null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                height: 120,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    _buildBarFill(context, data, scaleMax, isPast, isToday),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dayLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  color: isToday
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
              Text(
                '${day.day}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  color: isToday
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
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
      double onTimeHours = data.completedOnTimeHours;
      double overdueHours = data.completedOverdueHours;
      double seriouslyOverdueHours = data.completedSeriouslyOverdueHours;
      double skippedHours = data.skippedHours + data.missedHours;

      if (onTimeHours == 0 &&
          overdueHours == 0 &&
          seriouslyOverdueHours == 0 &&
          skippedHours == 0) {
        if (data.completedCount > 0) {
          if (data.completedSeriouslyOverdueCount > 0) {
            seriouslyOverdueHours = 0.25;
          } else if (data.completedOverdueCount > 0) {
            overdueHours = 0.25;
          } else {
            onTimeHours = 0.25;
          }
        }
        if (data.skippedCount > 0 || data.missedCount > 0) {
          skippedHours = 0.25;
        }
      }

      final totalActivity =
          onTimeHours + overdueHours + seriouslyOverdueHours + skippedHours;
      if (totalActivity <= 0) return const SizedBox.shrink();

      final double fillHeight = (totalActivity / scaleMax * 120.0).clamp(
        8.0,
        120.0,
      );

      return Container(
        height: fillHeight,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Column(
            children: [
              if (skippedHours > 0)
                Expanded(
                  flex: (skippedHours * 1000).round().clamp(1, 1000000),
                  child: CustomPaint(
                    painter: HatchedPatternPainter(
                      backgroundColor: theme.colorScheme.error.withValues(
                        alpha: 0.15,
                      ),
                      stripeColor: theme.colorScheme.error,
                      stripeWidth: 2.0,
                      gap: 3.0,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              if (seriouslyOverdueHours > 0)
                Expanded(
                  flex: (seriouslyOverdueHours * 1000).round().clamp(
                    1,
                    1000000,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red.shade700, Colors.red.shade600],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                ),
              if (overdueHours > 0)
                Expanded(
                  flex: (overdueHours * 1000).round().clamp(1, 1000000),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber.shade700, Colors.amber.shade600],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                ),
              if (onTimeHours > 0)
                Expanded(
                  flex: (onTimeHours * 1000).round().clamp(1, 1000000),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade600, Colors.green.shade500],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
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

      final totalToday = completedHours + plannedHours;
      if (totalToday <= 0) return const SizedBox.shrink();

      final double fillHeight = (totalToday / scaleMax * 120.0).clamp(
        8.0,
        120.0,
      );

      return Container(
        height: fillHeight,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Column(
            children: [
              if (plannedHours > 0)
                Expanded(
                  flex: (plannedHours * 1000).round().clamp(1, 1000000),
                  child: Container(
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                  ),
                ),
              if (completedHours > 0)
                Expanded(
                  flex: (completedHours * 1000).round().clamp(1, 1000000),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade600, Colors.green.shade500],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
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

  String _buildCalloutText(int skipped, int missed) {
    final parts = <String>[];
    if (skipped > 0) {
      parts.add('$skipped family tasks skipped');
    }
    if (missed > 0) {
      parts.add('$missed missed');
    }
    return parts.join(' · ');
  }

  String _buildMemberSubtitle(FamilyMemberStats member) {
    final parts = <String>[];
    parts.add(
      '${member.completedCount} done (${formatDurationHours(member.completedHours)})',
    );
    if (member.skippedCount > 0) {
      parts.add('${member.skippedCount} skipped');
    }
    if (member.missedCount > 0) {
      parts.add('${member.missedCount} missed');
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
}
