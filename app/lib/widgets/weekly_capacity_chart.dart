import 'dart:ui';
import 'package:flutter/material.dart';
import '../logic/app_clock.dart';
import '../logic/utils/format_utils.dart';

class DailyCapacityData {
  final DateTime date;
  final double capacityHours;
  final double plannedMinutes;
  final bool isOverridden;

  const DailyCapacityData({
    required this.date,
    required this.capacityHours,
    required this.plannedMinutes,
    required this.isOverridden,
  });
}

class WeeklyCapacityChart extends StatelessWidget {
  final List<DailyCapacityData> daysData;
  final void Function(DateTime) onDayTap;
  final VoidCallback onEditDefaultCapacity;

  const WeeklyCapacityChart({
    super.key,
    required this.daysData,
    required this.onDayTap,
    required this.onEditDefaultCapacity,
  });

  String _formatForecastLabel(double plannedHours, double capacityHours) {
    if (plannedHours == 0) {
      return formatDurationHours(capacityHours);
    }
    return '${formatDurationHours(plannedHours)}/${formatDurationHours(capacityHours)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = AppClock.now;

    double peakValue = 0.0;
    for (final data in daysData) {
      final plannedHours = data.plannedMinutes / 60.0;
      if (data.capacityHours > peakValue) peakValue = data.capacityHours;
      if (plannedHours > peakValue) peakValue = plannedHours;
    }
    final double scaleMax = peakValue > 0 ? peakValue : 8.0;

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly Capacity Forecast',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap a bar to override capacity for that specific calendar day.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('edit_default_capacity_button'),
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEditDefaultCapacity,
                  tooltip: 'Edit Default Capacity Template',
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 180,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: daysData.map((data) {
                  final date = data.date;
                  final capacity = data.capacityHours;
                  final plannedMinutes = data.plannedMinutes;
                  final isOverridden = data.isOverridden;
                  final capacityMinutes = capacity * 60.0;

                  final dateStr =
                      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                  final isToday =
                      date.day == today.day &&
                      date.month == today.month &&
                      date.year == today.year;

                  final double barHeight = capacity > 0
                      ? (capacity / scaleMax * 120.0).clamp(8.0, 120.0)
                      : 0.0;
                  final double fillHeight = plannedMinutes > 0
                      ? (plannedMinutes / 60.0 / scaleMax * 120.0).clamp(
                          8.0,
                          120.0,
                        )
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

                  return Expanded(
                    child: GestureDetector(
                      key: Key('capacity_bar_$dateStr'),
                      onTap: () => onDayTap(date),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            height: 14,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _formatForecastLabel(
                                  plannedMinutes / 60.0,
                                  capacity,
                                ),
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
                                if (fillHeight > 0)
                                  Container(
                                    height: fillHeight,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: plannedMinutes > capacityMinutes
                                            ? [
                                                theme.colorScheme.error,
                                                theme.colorScheme.error
                                                    .withValues(alpha: 0.7),
                                              ]
                                            : isOverridden
                                            ? [
                                                theme.colorScheme.tertiary,
                                                theme.colorScheme.tertiary
                                                    .withValues(alpha: 0.7),
                                              ]
                                            : [
                                                theme.colorScheme.primary,
                                                theme.colorScheme.primary
                                                    .withValues(alpha: 0.7),
                                              ],
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                if (barHeight > 0)
                                  Container(
                                    height: barHeight,
                                    width: double.infinity,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: CustomPaint(
                                      painter: DashedRectPainter(
                                        color: isToday
                                            ? theme.colorScheme.onSurface
                                            : isOverridden
                                            ? theme.colorScheme.tertiary
                                            : theme.colorScheme.primary,
                                        strokeWidth: 2.0,
                                        borderRadius: 6.0,
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
                            '${date.day}',
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
                SizedBox(
                  width: 16,
                  height: 12,
                  child: CustomPaint(
                    painter: DashedRectPainter(
                      color: theme.colorScheme.outlineVariant,
                      strokeWidth: 1.5,
                      borderRadius: 3.0,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Capacity',
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
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Planned Work',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
