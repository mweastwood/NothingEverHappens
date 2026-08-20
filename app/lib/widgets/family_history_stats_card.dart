import 'package:flutter/material.dart';
import '../logic/dashboard_stats.dart';
import '../logic/family.dart';
import '../logic/utils/format_utils.dart';

class FamilyHistoryStatsCard extends StatelessWidget {
  final FamilyLastWeekStats stats;

  const FamilyHistoryStatsCard({super.key, required this.stats});

  static const List<Color> _memberColors = [
    Color(0xFF2E7D32), // Forest green
    Color(0xFF1976D2), // Blue
    Color(0xFFE65100), // Orange
    Color(0xFF6A1B9A), // Purple
    Color(0xFF00838F), // Teal
    Color(0xFFC2185B), // Pink
  ];

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
                      Icons.diversity_3_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Family Team Activity',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
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
              'Shared family chores in the last 7 days',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

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

            // Segmented Contribution Bar (if any completed family tasks)
            if (stats.totalCompletedCount > 0) ...[
              Text(
                'Chore Distribution',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 14,
                  child: Row(
                    children: () {
                      final activeEntries = stats.memberStats
                          .asMap()
                          .entries
                          .where((entry) => entry.value.completedCount > 0)
                          .toList();
                      final List<Widget> segments = [];
                      for (int i = 0; i < activeEntries.length; i++) {
                        if (i > 0) {
                          segments.add(
                            Container(
                              width: 2,
                              color: theme.colorScheme.surfaceContainerLow,
                            ),
                          );
                        }
                        final entry = activeEntries[i];
                        segments.add(
                          Expanded(
                            flex: entry.value.completedCount,
                            child: Container(
                              color: _getColorForIndex(entry.key),
                            ),
                          ),
                        );
                      }
                      return segments;
                    }(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

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
