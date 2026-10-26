import 'dart:ui';
import 'package:flutter/material.dart';
import '../logic/dashboard_stats.dart';

void centerTimelineOnIndex(
  ScrollController scrollController,
  int todayIndex, {
  double itemWidth = 44.0,
}) {
  if (!scrollController.hasClients) return;
  if (todayIndex >= 0) {
    final viewportWidth = scrollController.position.viewportDimension;
    final targetOffset =
        (todayIndex * itemWidth + itemWidth / 2) - (viewportWidth / 2);
    final maxScroll = scrollController.position.maxScrollExtent;
    if (maxScroll > 0) {
      scrollController.jumpTo(targetOffset.clamp(0.0, maxScroll));
    }
  }
}

String formatTimelineDateRange({
  required int startMonth,
  required int startDay,
  required int endMonth,
  required int endDay,
}) {
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
  final startMonthStr = months[startMonth - 1];
  final endMonthStr = months[endMonth - 1];
  if (startMonth == endMonth) {
    return '$startMonthStr $startDay – $endDay';
  }
  return '$startMonthStr $startDay – $endMonthStr $endDay';
}

({
  double onTimeHours,
  double overdueHours,
  double seriouslyOverdueHours,
  double skippedHours,
})
resolvePastDayActivityHours({
  required double onTimeHours,
  required double overdueHours,
  required double seriouslyOverdueHours,
  required double skippedHours,
  required DailyStatsData? statsData,
}) {
  if (onTimeHours == 0 &&
      overdueHours == 0 &&
      seriouslyOverdueHours == 0 &&
      skippedHours == 0 &&
      statsData != null) {
    if (statsData.completedCount > 0) {
      if (statsData.completedSeriouslyOverdueCount > 0) {
        seriouslyOverdueHours = 0.25;
      } else if (statsData.completedOverdueCount > 0) {
        overdueHours = 0.25;
      } else {
        onTimeHours = 0.25;
      }
    }
    if (statsData.skippedCount > 0 || statsData.missedCount > 0) {
      skippedHours = 0.25;
    }
  }
  return (
    onTimeHours: onTimeHours,
    overdueHours: overdueHours,
    seriouslyOverdueHours: seriouslyOverdueHours,
    skippedHours: skippedHours,
  );
}

class TimelineGuideRow extends StatelessWidget {
  const TimelineGuideRow({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
    );
  }
}

class TimelineScrollStrip extends StatelessWidget {
  final int itemCount;
  final double itemWidth;
  final ScrollController scrollController;
  final IndexedWidgetBuilder itemBuilder;

  const TimelineScrollStrip({
    super.key,
    required this.itemCount,
    this.itemWidth = 44.0,
    required this.scrollController,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = itemCount * itemWidth;
        final bool canFit = constraints.maxWidth >= totalWidth;

        final children = List.generate(itemCount, (index) {
          final dayColumn = itemBuilder(context, index);
          if (canFit) {
            return Expanded(child: dayColumn);
          } else {
            return SizedBox(width: itemWidth, child: dayColumn);
          }
        });

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
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: chartContent,
        );
      },
    );
  }
}

class TimelineDayColumnShell extends StatelessWidget {
  final Key gestureKey;
  final Key subtreeKey;
  final VoidCallback onTap;
  final bool isToday;
  final int weekday;
  final int dayOfMonth;
  final List<Widget> stackChildren;

  const TimelineDayColumnShell({
    super.key,
    required this.gestureKey,
    required this.subtreeKey,
    required this.onTap,
    required this.isToday,
    required this.weekday,
    required this.dayOfMonth,
    required this.stackChildren,
  });

  static const List<String> _weekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayLabel = _weekdays[weekday - 1];

    return GestureDetector(
      key: gestureKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: KeyedSubtree(
        key: subtreeKey,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          decoration: isToday
              ? BoxDecoration(
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
                  children: stackChildren,
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
                '$dayOfMonth',
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
}

class TimelineStackedActivityBar extends StatelessWidget {
  final double scaleMax;
  final double onTimeHours;
  final double overdueHours;
  final double seriouslyOverdueHours;
  final double skippedHours;
  final double plannedHours;
  final Color? plannedColor;

  const TimelineStackedActivityBar({
    super.key,
    required this.scaleMax,
    required this.onTimeHours,
    required this.overdueHours,
    required this.seriouslyOverdueHours,
    required this.skippedHours,
    this.plannedHours = 0.0,
    this.plannedColor,
  });

  int _flexFor(double hours) => (hours * 1000).round().clamp(1, 1000000);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalActivity =
        onTimeHours +
        overdueHours +
        seriouslyOverdueHours +
        skippedHours +
        plannedHours;
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
            if (plannedHours > 0 && plannedColor != null)
              Expanded(
                flex: _flexFor(plannedHours),
                child: Container(color: plannedColor!.withValues(alpha: 0.5)),
              ),
            if (skippedHours > 0)
              Expanded(
                flex: _flexFor(skippedHours),
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
                flex: _flexFor(seriouslyOverdueHours),
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
                flex: _flexFor(overdueHours),
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
                flex: _flexFor(onTimeHours),
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
