import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../logic/app_clock.dart';
import '../logic/civil_day.dart';
import '../logic/dashboard_stats.dart';
import '../logic/family.dart';
import '../logic/task_instance.dart';
import '../logic/task_schedule.dart';
import '../logic/utils/format_utils.dart';

const List<Color> _defaultMemberColors = [
  Color(0xFF2E7D32), // Forest green
  Color(0xFF1976D2), // Blue
  Color(0xFFE65100), // Orange
  Color(0xFF6A1B9A), // Purple
  Color(0xFF00838F), // Teal
  Color(0xFFC2185B), // Pink
  Color(0xFFF57F17), // Amber
  Color(0xFF004D40), // Dark teal
];

Color getMemberColor(int index) {
  return _defaultMemberColors[index % _defaultMemberColors.length];
}

String getInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts[0].isEmpty) return '?';
  if (parts.length == 1) {
    return parts[0].substring(0, 1).toUpperCase();
  }
  return '${parts[0].substring(0, 1)}${parts[1].substring(0, 1)}'.toUpperCase();
}

class FamilyContributionsCard extends StatelessWidget {
  final FamilyLastWeekStats stats;
  final Map<String, TaskSchedule>? scheduleMap;

  const FamilyContributionsCard({
    super.key,
    required this.stats,
    this.scheduleMap,
  });

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
    final today = CivilDay.fromDateTime(AppClock.now);
    final past6Days = today.addDays(-6);
    final dateRangeStr = _formatDateRange(past6Days, today);

    // Calculate total time-weighted sum
    final totalHours = stats.memberStats.fold<double>(
      0.0,
      (sum, m) => sum + m.completedHours,
    );
    final totalCompleted = stats.memberStats.fold<int>(
      0,
      (sum, m) => sum + m.completedCount,
    );

    final hasContributions = totalHours > 0 || totalCompleted > 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Title and date range badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.pie_chart_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Family Contributions',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
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
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                  child: Text(
                    dateRangeStr,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Time-weighted chore distribution (today + past 6 days)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            // Pie Chart Area
            Center(
              child: SizedBox(
                width: 180,
                height: 180,
                child: _InteractivePieChart(
                  stats: stats,
                  totalHours: totalHours,
                  totalCompleted: totalCompleted,
                  onSliceTap: (member, color) {
                    FamilyMemberContributionsSheet.show(
                      context,
                      member: member,
                      color: color,
                      scheduleMap: scheduleMap,
                      dateRangeStr: dateRangeStr,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Member list / legend
            if (stats.memberStats.isNotEmpty) ...[
              Text(
                'Members',
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
                  final memberColor = getMemberColor(index);
                  final percentage = (member.contributionPercentage * 100)
                      .round();

                  return InkWell(
                    key: Key('family_contribution_tile_${member.userId}'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      FamilyMemberContributionsSheet.show(
                        context,
                        member: member,
                        color: memberColor,
                        scheduleMap: scheduleMap,
                        dateRangeStr: dateRangeStr,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6.0,
                        horizontal: 4.0,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: memberColor.withValues(
                              alpha: 0.15,
                            ),
                            child: Text(
                              getInitials(member.displayName),
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
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
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
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
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
                                  '${member.completedCount} done (${formatDurationHours(member.completedHours)})',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (hasContributions) ...[
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
                            const SizedBox(width: 4),
                          ],
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InteractivePieChart extends StatelessWidget {
  final FamilyLastWeekStats stats;
  final double totalHours;
  final int totalCompleted;
  final void Function(FamilyMemberStats member, Color color) onSliceTap;

  const _InteractivePieChart({
    required this.stats,
    required this.totalHours,
    required this.totalCompleted,
    required this.onSliceTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final members = stats.memberStats;
    final hasContributions = totalHours > 0 || totalCompleted > 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final center = Offset(size.width / 2, size.height / 2);
        final radius = min(size.width, size.height) / 2;

        return GestureDetector(
          key: const Key('family_contributions_pie_chart'),
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            if (!hasContributions) return;

            final touchPoint = details.localPosition;
            final dx = touchPoint.dx - center.dx;
            final dy = touchPoint.dy - center.dy;
            final distance = sqrt(dx * dx + dy * dy);

            // Check if touch is within the chart circle
            if (distance > radius) return;

            // Angle in radians from top (-pi/2)
            double touchAngle = atan2(dy, dx) + pi / 2;
            if (touchAngle < 0) touchAngle += 2 * pi;

            double cumulativeAngle = 0.0;
            for (int i = 0; i < members.length; i++) {
              final member = members[i];
              final weight = member.contributionPercentage;
              if (weight <= 0) continue;

              final sweepAngle = weight * 2 * pi;
              if (touchAngle >= cumulativeAngle &&
                  touchAngle <= cumulativeAngle + sweepAngle) {
                onSliceTap(member, getMemberColor(i));
                return;
              }
              cumulativeAngle += sweepAngle;
            }

            // Fallback for floating point boundary at end of circle
            if (members.isNotEmpty) {
              final firstActiveIdx = members.indexWhere(
                (m) => m.contributionPercentage > 0,
              );
              if (firstActiveIdx >= 0) {
                onSliceTap(
                  members[firstActiveIdx],
                  getMemberColor(firstActiveIdx),
                );
              }
            }
          },
          child: CustomPaint(
            size: size,
            painter: _PieChartPainter(
              members: members,
              hasContributions: hasContributions,
              emptyColor: theme.colorScheme.outlineVariant.withValues(
                alpha: 0.3,
              ),
              borderColor: theme.colorScheme.surfaceContainerLow,
            ),
          ),
        );
      },
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final List<FamilyMemberStats> members;
  final bool hasContributions;
  final Color emptyColor;
  final Color borderColor;

  const _PieChartPainter({
    required this.members,
    required this.hasContributions,
    required this.emptyColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    if (!hasContributions) {
      final paint = Paint()
        ..color = emptyColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, paint);

      // Draw center hole for donut style
      final holePaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius * 0.55, holePaint);
      return;
    }

    double startAngle = -pi / 2; // Start from top

    for (int i = 0; i < members.length; i++) {
      final member = members[i];
      final percentage = member.contributionPercentage;
      if (percentage <= 0) continue;

      final sweepAngle = percentage * 2 * pi;
      final slicePaint = Paint()
        ..color = getMemberColor(i)
        ..style = PaintingStyle.fill;

      canvas.drawArc(rect, startAngle, sweepAngle, true, slicePaint);
      startAngle += sweepAngle;
    }

    // Draw slice borders
    if (members.where((m) => m.contributionPercentage > 0).length > 1) {
      startAngle = -pi / 2;
      final linePaint = Paint()
        ..color = borderColor
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      for (int i = 0; i < members.length; i++) {
        final percentage = members[i].contributionPercentage;
        if (percentage <= 0) continue;

        final sweepAngle = percentage * 2 * pi;
        final x = center.dx + radius * cos(startAngle);
        final y = center.dy + radius * sin(startAngle);
        canvas.drawLine(center, Offset(x, y), linePaint);
        startAngle += sweepAngle;
      }
    }

    // Center hole for clean modern donut chart
    final holePaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.55, holePaint);
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.members != members ||
        oldDelegate.hasContributions != hasContributions ||
        oldDelegate.emptyColor != emptyColor ||
        oldDelegate.borderColor != borderColor;
  }
}

class FamilyMemberContributionsSheet extends StatelessWidget {
  final FamilyMemberStats member;
  final Color color;
  final Map<String, TaskSchedule>? scheduleMap;
  final String dateRangeStr;

  const FamilyMemberContributionsSheet({
    super.key,
    required this.member,
    required this.color,
    this.scheduleMap,
    required this.dateRangeStr,
  });

  static Future<void> show(
    BuildContext context, {
    required FamilyMemberStats member,
    required Color color,
    Map<String, TaskSchedule>? scheduleMap,
    required String dateRangeStr,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => FamilyMemberContributionsSheet(
        member: member,
        color: color,
        scheduleMap: scheduleMap,
        dateRangeStr: dateRangeStr,
      ),
    );
  }

  String _formatTaskTime(BuildContext context, TaskInstance task) {
    final dt =
        task.completedAt ??
        task.dueRelativeTime.referenceTo(task.scheduledDate);
    final locale = Localizations.localeOf(context).languageCode;
    final dateStr = (dt.year != AppClock.now.year)
        ? DateFormat.yMMMd(locale).format(dt)
        : DateFormat.MMMd(locale).format(dt);
    final timeStr = DateFormat('h:mm a', locale).format(dt);
    return '$dateStr, $timeStr';
  }

  String? _getAllocatedTimeString(TaskInstance task) {
    final schedule = scheduleMap?[task.scheduleId];
    if (schedule?.estimatedDuration == null) return null;
    final duration = schedule!.estimatedDuration!;
    if (duration == Duration.zero) return null;

    final h = duration.inHours;
    final m = duration.inMinutes % 60;
    if (h > 0 && m > 0) {
      return '${h}h ${m}m';
    } else if (h > 0) {
      return '${h}h';
    } else {
      return '${m}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final percentage = (member.contributionPercentage * 100).round();

    final tasks = [...member.completedTasks]
      ..sort((a, b) {
        final aTime = a.completedAt ?? a.updatedAt;
        final bTime = b.completedAt ?? b.updatedAt;
        return bTime.compareTo(aTime); // Most recent first
      });

    return SafeArea(
      child: Container(
        key: const Key('family_member_contributions_sheet'),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Sheet Header
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Text(
                    getInitials(member.displayName),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              member.displayName,
                              style: theme.textTheme.titleMedium?.copyWith(
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
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Parent',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 10,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateRangeStr,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Metric chips
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 14,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${member.completedCount} completed',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(
                      alpha: isDark ? 0.2 : 0.1,
                    ),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formatDurationHours(member.completedHours),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pie_chart_outline, size: 14, color: color),
                      const SizedBox(width: 4),
                      Text(
                        '$percentage% of total',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Tasks List
            Flexible(
              child: tasks.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.task_alt,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.4),
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No contributions recorded in this period',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        final timeStr = _formatTaskTime(context, task);
                        final durationStr = _getAllocatedTimeString(task);

                        final isOverdue = task.isCompletedOverdue;
                        final isSeriouslyOverdue =
                            task.isCompletedOverdueByMoreThan24Hours;

                        final Color statusColor = isSeriouslyOverdue
                            ? theme.colorScheme.error
                            : (isOverdue
                                  ? (isDark
                                        ? Colors.amber.shade300
                                        : Colors.amber.shade800)
                                  : (isDark
                                        ? Colors.green.shade300
                                        : Colors.green.shade700));

                        final String tagLabel = isSeriouslyOverdue
                            ? 'Seriously Overdue'
                            : (isOverdue ? 'Overdue' : 'Completed');

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? theme.colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.5)
                                : theme.colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 20,
                                color: statusColor,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      task.title.isEmpty
                                          ? 'Untitled Task'
                                          : task.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      durationStr != null
                                          ? '$timeStr · $durationStr'
                                          : timeStr,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontSize: 11,
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  tagLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
