import 'dart:ui';
import 'package:flutter/material.dart';
import '../logic/app_clock.dart';
import '../logic/dashboard_stats.dart';
import '../logic/utils/format_utils.dart';

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
            statsData!.completedOverdueHours > 0)) {
      return statsData!.completedOnTimeHours;
    }
    return completedHours;
  }

  double get completedOverdueHours => statsData?.completedOverdueHours ?? 0.0;
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
  late final ScrollController _scrollController;
  final double _itemWidth = 52.0;

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
    if (!_scrollController.hasClients) return;
    final today = AppClock.now;
    final todayIndex = widget.daysData.indexWhere(
      (d) =>
          d.date.year == today.year &&
          d.date.month == today.month &&
          d.date.day == today.day,
    );

    if (todayIndex >= 0) {
      final viewportWidth = _scrollController.position.viewportDimension;
      final targetOffset =
          (todayIndex * _itemWidth + _itemWidth / 2) - (viewportWidth / 2);
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll > 0) {
        _scrollController.jumpTo(targetOffset.clamp(0.0, maxScroll));
      }
    }
  }

  String _formatForecastLabel({
    required double workHours,
    required double capacityHours,
  }) {
    if (workHours == 0) {
      return formatDurationHours(capacityHours);
    }
    return '${formatDurationHours(workHours)}/${formatDurationHours(capacityHours)}';
  }

  String _formatDateRange(DateTime start, DateTime end) {
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
        ? _formatDateRange(
            widget.daysData.first.date,
            widget.daysData.last.date,
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
                IconButton(
                  key: const Key('edit_default_capacity_button'),
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: widget.onEditDefaultCapacity,
                  tooltip: 'Edit Default Capacity Template',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Timeline Guide (Past 6 Days / Today / Next 6 Days)
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
                          'Next',
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
            LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = widget.daysData.length * _itemWidth;
                final bool canFit = constraints.maxWidth >= totalWidth;

                final children = widget.daysData.map((data) {
                  final dayColumn = _buildDayColumn(
                    context,
                    data,
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

            // Legend
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14,
                    height: 10,
                    child: CustomPaint(
                      painter: DashedRectPainter(
                        color: theme.colorScheme.outlineVariant,
                        strokeWidth: 1.5,
                        borderRadius: 2.0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Capacity',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 14,
                    height: 10,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Completed / Workload',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 14,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.amber.shade700,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Overdue',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: SizedBox(
                      width: 14,
                      height: 10,
                      child: CustomPaint(
                        painter: HatchedPatternPainter(
                          backgroundColor: theme.colorScheme.error.withValues(
                            alpha: 0.15,
                          ),
                          stripeColor: theme.colorScheme.error,
                          stripeWidth: 1.5,
                          gap: 2.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Skipped',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 14,
                    height: 10,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Over Capacity',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
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

    final List<String> weekdays = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    final dayLabel = weekdays[date.weekday - 1];
    final isOverCapacity = workHours > capacity;

    final hasRecordedTasks =
        data.statsData != null &&
        (data.statsData!.completedTasks.isNotEmpty ||
            data.statsData!.skippedTasks.isNotEmpty ||
            data.statsData!.missedTasks.isNotEmpty);

    final shouldOpenBreakdown =
        widget.onDayActivityTap != null &&
        data.statsData != null &&
        (isPast || hasRecordedTasks);

    // History is labeled with time spent only, without capacity label
    final String topLabel = isPast
        ? formatDurationHours(data.completedHours)
        : _formatForecastLabel(workHours: workHours, capacityHours: capacity);

    return GestureDetector(
      key: Key('capacity_bar_$dateStr'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (shouldOpenBreakdown) {
          widget.onDayActivityTap!(data.statsData!);
        } else {
          widget.onDayTap(date);
        }
      },
      child: KeyedSubtree(
        key: Key('daily_activity_bar_$dateStr'),
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
                height: 14,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    topLabel,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 9,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      color: isToday
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
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
                '${date.day}',
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
    DailyCapacityData data,
    double scaleMax,
    bool isPast,
    bool isToday,
    bool isOverCapacity,
    bool isOverridden,
  ) {
    final theme = Theme.of(context);

    if (isPast) {
      double onTimeHours = data.completedOnTimeHours;
      double overdueHours = data.completedOverdueHours;
      double skippedHours = data.skippedHours;

      if (onTimeHours == 0 &&
          overdueHours == 0 &&
          skippedHours == 0 &&
          data.statsData != null) {
        if (data.statsData!.completedCount > 0) {
          onTimeHours = 0.25;
        }
        if (data.statsData!.skippedCount > 0) {
          skippedHours = 0.25;
        }
      }

      final totalActivity = onTimeHours + overdueHours + skippedHours;
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
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.primary.withValues(alpha: 0.7),
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
      );
    }

    if (isToday &&
        data.statsData != null &&
        (data.completedHours > 0 || data.skippedHours > 0)) {
      double onTimeHours = data.completedOnTimeHours;
      double overdueHours = data.completedOverdueHours;
      double skippedHours = data.skippedHours;
      double plannedHours = data.plannedHours;

      final totalActivity =
          onTimeHours + overdueHours + skippedHours + plannedHours;
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
              if (plannedHours > 0)
                Expanded(
                  flex: (plannedHours * 1000).round().clamp(1, 1000000),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isOverCapacity
                            ? [
                                theme.colorScheme.error,
                                theme.colorScheme.error.withValues(alpha: 0.7),
                              ]
                            : isOverridden
                            ? [
                                theme.colorScheme.tertiary,
                                theme.colorScheme.tertiary.withValues(
                                  alpha: 0.7,
                                ),
                              ]
                            : [
                                theme.colorScheme.primary,
                                theme.colorScheme.primary.withValues(
                                  alpha: 0.7,
                                ),
                              ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                ),
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
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.primary.withValues(alpha: 0.7),
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
        gradient: LinearGradient(
          colors: isOverCapacity
              ? [
                  theme.colorScheme.error,
                  theme.colorScheme.error.withValues(alpha: 0.7),
                ]
              : isOverridden
              ? [
                  theme.colorScheme.tertiary,
                  theme.colorScheme.tertiary.withValues(alpha: 0.7),
                ]
              : [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.7),
                ],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

class HatchedPatternPainter extends CustomPainter {
  final Color backgroundColor;
  final Color stripeColor;
  final double stripeWidth;
  final double gap;

  const HatchedPatternPainter({
    required this.backgroundColor,
    required this.stripeColor,
    this.stripeWidth = 2.0,
    this.gap = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final stripePaint = Paint()
      ..color = stripeColor
      ..strokeWidth = stripeWidth
      ..style = PaintingStyle.stroke;

    final step = stripeWidth + gap;
    final total = size.width + size.height;
    for (double offset = -size.height; offset < total; offset += step) {
      canvas.drawLine(
        Offset(offset, size.height),
        Offset(offset + size.height, 0),
        stripePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant HatchedPatternPainter oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.stripeColor != stripeColor ||
        oldDelegate.stripeWidth != stripeWidth ||
        oldDelegate.gap != gap;
  }
}

class DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dashLength;
  final double borderRadius;

  DashedRectPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.gap = 4.0,
    this.dashLength = 4.0,
    this.borderRadius = 6.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(borderRadius),
        ),
      );

    final dashPath = Path();
    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double length = dashLength;
        dashPath.addPath(
          metric.extractPath(
            distance,
            (distance + length).clamp(0.0, metric.length),
          ),
          Offset.zero,
        );
        distance += length + gap;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant DashedRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gap != gap ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.borderRadius != borderRadius;
  }
}
