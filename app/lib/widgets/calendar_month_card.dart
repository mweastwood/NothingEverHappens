import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';

import '../logic/calendar_day_task.dart';
import '../logic/civil_day.dart';
import '../logic/l10n_extension.dart';
import '../logic/task_label.dart';
import '../logic/task_priority.dart';
import '../logic/user_settings.dart';
import 'calendar_day_details_sheet.dart';

/// Resolves theme color corresponding to task priority.
Color getPriorityColor(ColorScheme colorScheme, TaskPriority priority) {
  switch (priority) {
    case TaskPriority.high:
      return colorScheme.error;
    case TaskPriority.medium:
      return colorScheme.primary;
    case TaskPriority.low:
      return colorScheme.secondary;
  }
}

final Map<String, DateFormat> _monthDateFormatCache = {};
final Map<(String, FirstDayOfWeek), List<String>> _weekdayHeadersCache = {};

/// Clears cached formatters and weekday headers (for testing).
@visibleForTesting
void clearCalendarMonthCardCaches() {
  _monthDateFormatCache.clear();
  _weekdayHeadersCache.clear();
}

DateFormat _getMonthFormatter(String locale) {
  return _monthDateFormatCache.putIfAbsent(
    locale,
    () => DateFormat.yMMMM(locale),
  );
}

/// Computes localized weekday header initials based on [firstDayOfWeek].
List<String> getWeekdayHeaders(
  String locale, {
  FirstDayOfWeek firstDayOfWeek = FirstDayOfWeek.sunday,
}) {
  final key = (locale, firstDayOfWeek);
  final cached = _weekdayHeadersCache[key];
  if (cached != null) return cached;

  List<String> result;
  try {
    final symbols = DateFormat(null, locale).dateSymbols;
    final narrow = symbols.STANDALONENARROWWEEKDAYS.isNotEmpty
        ? symbols.STANDALONENARROWWEEKDAYS
        : symbols.NARROWWEEKDAYS;
    if (firstDayOfWeek == FirstDayOfWeek.sunday) {
      result = [for (int i = 0; i < 7; i++) narrow[i]];
    } else {
      result = [for (int i = 1; i <= 6; i++) narrow[i], narrow[0]];
    }
  } catch (_) {
    result = firstDayOfWeek == FirstDayOfWeek.sunday
        ? const ['S', 'M', 'T', 'W', 'T', 'F', 'S']
        : const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  }
  _weekdayHeadersCache[key] = result;
  return result;
}

/// Renders a single calm month grid where routine/weekly tasks fold into each
/// day's capacity bar and only one-off or rarer-than-weekly tasks display
/// label-colored indicator dots.
class CalendarMonthCard extends StatelessWidget {
  /// Row height used for narrow (mobile portrait) month grids.
  static const double narrowCellHeight = 46.0;

  /// Row height used for wide (tablet/desktop) month grids.
  static const double wideCellHeight = 52.0;

  final DateTime monthDate;
  final Map<CivilDay, List<CalendarDayTask>> dayTaskMap;
  final CivilDay today;
  final CivilDay? selectedDay;
  final bool isWide;
  final bool showMonthHeader;
  final void Function(CivilDay day)? onDayTap;
  final FirstDayOfWeek firstDayOfWeek;
  final Map<String, TaskLabel> labelsMap;
  final UserSettings? userSettings;

  const CalendarMonthCard({
    super.key,
    required this.monthDate,
    this.dayTaskMap = const {},
    required this.today,
    this.selectedDay,
    this.isWide = false,
    this.showMonthHeader = true,
    this.onDayTap,
    this.firstDayOfWeek = FirstDayOfWeek.sunday,
    this.labelsMap = const {},
    this.userSettings,
  });

  double _computePeakMonthHours() {
    double peakHours = 0.0;
    for (final entry in dayTaskMap.entries) {
      if (entry.key.year != monthDate.year ||
          entry.key.month != monthDate.month) {
        continue;
      }
      int dayMins = 0;
      for (final task in entry.value) {
        dayMins += task.effectiveDurationMinutes;
      }
      final dayHours = dayMins / 60.0;
      if (dayHours > peakHours) {
        peakHours = dayHours;
      }
    }
    return peakHours;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final monthTitle = _getMonthFormatter(locale).format(monthDate);
    final weekdayHeaders = getWeekdayHeaders(
      locale,
      firstDayOfWeek: firstDayOfWeek,
    );
    final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
    final firstWeekday = DateTime(
      monthDate.year,
      monthDate.month,
      1,
    ).weekday; // 1=Mon, 7=Sun
    final leadingEmptyCount = firstDayOfWeek.getLeadingEmptySlots(firstWeekday);

    final totalSlots = leadingEmptyCount + daysInMonth;
    final rowCount = (totalSlots / 7).ceil();

    final isCurrentMonth =
        monthDate.year == today.year && monthDate.month == today.month;
    final peakMonthHours = _computePeakMonthHours();

    return RepaintBoundary(
      child: Container(
        key: Key('month_card_${monthDate.year}_${monthDate.month}'),
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showMonthHeader)
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        monthTitle,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isCurrentMonth
                              ? theme.colorScheme.primary
                              : null,
                        ),
                      ),
                    ),
                    if (isCurrentMonth)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          context.l10n.calendarCurrentMonth,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            // Weekday Headers
            Row(
              children: [
                for (final dayLabel in weekdayHeaders)
                  Expanded(
                    child: Center(
                      child: Text(
                        dayLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.7,
                          ),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 2),
            // Calendar Day Grid
            LayoutBuilder(
              builder: (context, constraints) {
                final cellWidth = constraints.maxWidth / 7;
                final cellHeight = isWide ? wideCellHeight : narrowCellHeight;
                final bool compact = cellWidth < 40;

                final bool hasTodayInMonth =
                    isCurrentMonth &&
                    today.day >= 1 &&
                    today.day <= daysInMonth;
                final int todaySlotIndex = leadingEmptyCount + today.day - 1;
                final int todayRow = todaySlotIndex ~/ 7;
                final int todayCol = todaySlotIndex % 7;

                final dayGridColumn = Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int r = 0; r < rowCount; r++) ...[
                      SizedBox(
                        height: cellHeight,
                        child: Row(
                          children: [
                            for (int c = 0; c < 7; c++) ...[
                              Expanded(
                                child: CalendarDayCellSlot(
                                  row: r,
                                  col: c,
                                  leadingEmptyCount: leadingEmptyCount,
                                  daysInMonth: daysInMonth,
                                  monthDate: monthDate,
                                  dayTaskMap: dayTaskMap,
                                  today: today,
                                  selectedDay: selectedDay,
                                  compact: compact,
                                  peakMonthHours: peakMonthHours,
                                  onDayTap: onDayTap,
                                  labelsMap: labelsMap,
                                  userSettings: userSettings,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                );

                if (!hasTodayInMonth) {
                  return dayGridColumn;
                }

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: todayCol * cellWidth,
                      top: todayRow * cellHeight,
                      width: cellWidth,
                      height: cellHeight,
                      child: const IgnorePointer(
                        child: CalendarTodayBlobBackground(),
                      ),
                    ),
                    RepaintBoundary(child: dayGridColumn),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders a single calendar day cell slot within the month grid.
class CalendarDayCellSlot extends StatelessWidget {
  final int row;
  final int col;
  final int leadingEmptyCount;
  final int daysInMonth;
  final DateTime monthDate;
  final Map<CivilDay, List<CalendarDayTask>> dayTaskMap;
  final CivilDay today;
  final CivilDay? selectedDay;
  final bool compact;
  final double peakMonthHours;
  final void Function(CivilDay day)? onDayTap;
  final Map<String, TaskLabel> labelsMap;
  final UserSettings? userSettings;

  const CalendarDayCellSlot({
    super.key,
    required this.row,
    required this.col,
    required this.leadingEmptyCount,
    required this.daysInMonth,
    required this.monthDate,
    required this.dayTaskMap,
    required this.today,
    this.selectedDay,
    this.compact = false,
    this.peakMonthHours = 0.0,
    this.onDayTap,
    this.labelsMap = const {},
    this.userSettings,
  });

  @override
  Widget build(BuildContext context) {
    final slotIndex = row * 7 + col;
    final dayNum = slotIndex - leadingEmptyCount + 1;

    if (dayNum < 1 || dayNum > daysInMonth) {
      return const SizedBox.shrink();
    }

    final civilDay = CivilDay(
      year: monthDate.year,
      month: monthDate.month,
      day: dayNum,
    );
    final isToday = civilDay == today;
    final isSelected = selectedDay == civilDay;
    final isPast = civilDay.isBefore(today);
    final tasks = dayTaskMap[civilDay] ?? const [];
    final theme = Theme.of(context);
    final capacityHours =
        userSettings?.getCapacityForDate(civilDay.toDateTime()) ?? 4.0;
    final workload = CalendarDayWorkload.fromTasks(
      tasks,
      capacityHours: capacityHours,
      labelsMap: labelsMap,
      isPastDay: isPast,
    );

    final double scaleCapacityHours = peakMonthHours > capacityHours
        ? peakMonthHours
        : capacityHours;

    final Color dayNumberColor;
    if (isSelected || isToday) {
      dayNumberColor = theme.colorScheme.primary;
    } else if (workload.hasHighlightedTasks) {
      dayNumberColor = theme.colorScheme.onSurface;
    } else {
      dayNumberColor = theme.colorScheme.onSurfaceVariant.withValues(
        alpha: isPast ? 0.65 : 0.85,
      );
    }

    final BoxDecoration? cellDecoration;
    if (isSelected) {
      cellDecoration = BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.primary, width: 1.5),
      );
    } else if (workload.hasHighlightedTasks) {
      cellDecoration = BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.22,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 0.5,
        ),
      );
    } else {
      cellDecoration = null;
    }

    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: InkWell(
        key: Key('calendar_day_${civilDay.year}_${civilDay.month}_$dayNum'),
        onTap: () {
          if (onDayTap != null) {
            onDayTap!(civilDay);
          } else {
            CalendarDayDetailsSheet.show(context, day: civilDay);
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: cellDecoration,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 2.5 : 4.5,
            vertical: 3.0,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Row 1: Day number (with subtle completed check when all done)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$dayNum',
                    style: TextStyle(
                      fontSize: compact ? 10.5 : 12.0,
                      height: 1.1,
                      fontWeight:
                          (isToday ||
                              isSelected ||
                              workload.hasHighlightedTasks)
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: dayNumberColor,
                    ),
                  ),
                  if (workload.allCompleted) ...[
                    const SizedBox(width: 2),
                    Icon(
                      Icons.check_circle,
                      size: compact ? 8.5 : 9.5,
                      color: theme.colorScheme.primary.withValues(alpha: 0.75),
                    ),
                  ],
                ],
              ),
              // Row 2: Label dots for one-off / rarer-than-weekly tasks only
              CalendarHighlightedDotsRow(
                key: Key(
                  'highlighted_dots_${civilDay.year}_${civilDay.month}_$dayNum',
                ),
                dotColorKeys: workload.highlightedDotColorKeys,
                dimmed: workload.allCompleted,
                compact: compact,
              ),
              // Row 3: Folded capacity bar (routine + weekly + highlighted)
              if (workload.isNotEmpty)
                CalendarLabelCapacityBar(
                  workload: workload,
                  scaleCapacityHours: scaleCapacityHours,
                  height: compact ? 3.0 : 3.5,
                )
              else
                SizedBox(height: compact ? 3.0 : 3.5),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders up to [maxDots] label-colored indicator dots for highlighted (one-off
/// or rarer-than-weekly) tasks on a calendar day cell.
class CalendarHighlightedDotsRow extends StatelessWidget {
  static const int maxDots = 3;

  final List<String?> dotColorKeys;
  final bool dimmed;
  final bool compact;

  const CalendarHighlightedDotsRow({
    super.key,
    required this.dotColorKeys,
    this.dimmed = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final dotSize = compact ? 4.5 : 5.5;
    if (dotColorKeys.isEmpty) {
      return SizedBox(height: dotSize + 1.5);
    }

    final theme = Theme.of(context);
    final visibleKeys = dotColorKeys.take(maxDots).toList(growable: false);
    final hasOverflow = dotColorKeys.length > maxDots;

    return SizedBox(
      height: dotSize + 1.5,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < visibleKeys.length; i++) ...[
            if (i > 0) SizedBox(width: compact ? 2.0 : 3.0),
            Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _resolveDotColor(context, theme, visibleKeys[i]),
              ),
            ),
          ],
          if (hasOverflow) ...[
            SizedBox(width: compact ? 1.5 : 2.5),
            Container(
              width: dotSize * 0.65,
              height: dotSize * 0.65,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: dimmed ? 0.35 : 0.65,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _resolveDotColor(
    BuildContext context,
    ThemeData theme,
    String? colorKey,
  ) {
    final base = colorKey != null
        ? LabelPalette.getColor(colorKey, context)
        : theme.colorScheme.primary;
    return dimmed ? base.withValues(alpha: 0.45) : base;
  }
}

/// Slowly undulating organic blob background rendered behind the current day cell.
///
/// Uses a frame-gated 12 FPS timer (~83ms interval) and isolated [RepaintBoundary]
/// layers so the ambient 24-second undulation stays visually smooth while avoiding
/// 60–120 Hz ticker wakeups and never repainting the foreground day cell content.
class CalendarTodayBlobBackground extends StatefulWidget {
  /// Full cycle duration for the blob undulation.
  static const Duration cycleDuration = Duration(seconds: 24);

  /// Target interval between blob repaints (~12 FPS).
  static const Duration frameInterval = Duration(milliseconds: 83);

  /// Allows unit tests to explicitly enable repeating animation under TestWidgetsFlutterBinding.
  @visibleForTesting
  static bool debugForceAnimateInTests = false;

  final Widget? child;

  const CalendarTodayBlobBackground({super.key, this.child});

  @override
  State<CalendarTodayBlobBackground> createState() =>
      _CalendarTodayBlobBackgroundState();
}

class _CalendarTodayBlobBackgroundState
    extends State<CalendarTodayBlobBackground> {
  final ValueNotifier<double> _progressNotifier = ValueNotifier<double>(0.0);
  Timer? _frameTimer;
  DateTime? _lastTickTime;
  bool _shouldAnimate = false;
  bool _waitingForPostFrame = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimationState();
  }

  void _syncAnimationState() {
    final isTestBinding = WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgetsFlutterBinding');
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    final shouldAnimate =
        (CalendarTodayBlobBackground.debugForceAnimateInTests ||
            !isTestBinding) &&
        !disableAnimations &&
        tickerEnabled;

    if (shouldAnimate == _shouldAnimate) return;
    _shouldAnimate = shouldAnimate;

    if (_shouldAnimate) {
      _lastTickTime = DateTime.now();
      _scheduleNextTick();
    } else {
      _frameTimer?.cancel();
      _frameTimer = null;
      _lastTickTime = null;
    }
  }

  void _scheduleNextTick() {
    if (!mounted || !_shouldAnimate || _frameTimer != null) return;
    _frameTimer = Timer(CalendarTodayBlobBackground.frameInterval, _onTick);
  }

  void _onTick() {
    _frameTimer = null;
    if (!mounted || !_shouldAnimate) return;

    final now = DateTime.now();
    final elapsedMs = _lastTickTime != null
        ? now
              .difference(_lastTickTime!)
              .inMilliseconds
              .clamp(
                CalendarTodayBlobBackground.frameInterval.inMilliseconds,
                1000,
              )
        : CalendarTodayBlobBackground.frameInterval.inMilliseconds;
    _lastTickTime = now;

    final delta =
        elapsedMs / CalendarTodayBlobBackground.cycleDuration.inMilliseconds;
    _progressNotifier.value = (_progressNotifier.value + delta) % 1.0;

    // Gate the next timer on actual frame completion so backgrounded tabs do zero work.
    if (!_waitingForPostFrame) {
      _waitingForPostFrame = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _waitingForPostFrame = false;
        _scheduleNextTick();
      });
    }
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _progressNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blobLayer = RepaintBoundary(
      child: ValueListenableBuilder<double>(
        valueListenable: _progressNotifier,
        builder: (context, progress, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: CalendarTodayBlobPainter(
              progress: progress,
              colorScheme: theme.colorScheme,
              brightness: theme.brightness,
            ),
          );
        },
      ),
    );

    if (widget.child == null) {
      return blobLayer;
    }

    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(child: blobLayer),
        RepaintBoundary(child: widget.child!),
      ],
    );
  }
}

class _BlobBasisPoint {
  final double cosT;
  final double sinT;
  final double squircleRadius;
  final double cos2T;
  final double sin2T;
  final double cos3T;
  final double sin3T;
  final double cos4T;
  final double sin4T;

  const _BlobBasisPoint({
    required this.cosT,
    required this.sinT,
    required this.squircleRadius,
    required this.cos2T,
    required this.sin2T,
    required this.cos3T,
    required this.sin3T,
    required this.cos4T,
    required this.sin4T,
  });
}

/// Custom painter that draws a two-layer smoothly undulating organic blob.
class CalendarTodayBlobPainter extends CustomPainter {
  static const int _steps = 48;
  static const double _squircleExponent = 3.8;

  static final List<_BlobBasisPoint> _basisPoints = List.generate(_steps, (i) {
    final double theta = (i / _steps) * 2.0 * math.pi;
    final double cosT = math.cos(theta);
    final double sinT = math.sin(theta);
    final double denom =
        math.pow(cosT.abs(), _squircleExponent).toDouble() +
        math.pow(sinT.abs(), _squircleExponent).toDouble();
    final double squircleRadius = math
        .pow(denom, -1.0 / _squircleExponent)
        .toDouble();

    return _BlobBasisPoint(
      cosT: cosT,
      sinT: sinT,
      squircleRadius: squircleRadius,
      cos2T: math.cos(2.0 * theta),
      sin2T: math.sin(2.0 * theta),
      cos3T: math.cos(3.0 * theta),
      sin3T: math.sin(3.0 * theta),
      cos4T: math.cos(4.0 * theta),
      sin4T: math.sin(4.0 * theta),
    );
  }, growable: false);

  final double progress;
  final ColorScheme colorScheme;
  final Brightness brightness;

  const CalendarTodayBlobPainter({
    required this.progress,
    required this.colorScheme,
    required this.brightness,
  });

  Path _buildBlobPath(
    Size size, {
    required double phase,
    required double scaleX,
    required double scaleY,
    required double lobe2,
    required double lobe3,
    required double lobe4,
  }) {
    final double cx = size.width / 2.0;
    final double cy = size.height / 2.0;
    final double rx = (size.width / 2.0) * scaleX;
    final double ry = (size.height / 2.0) * scaleY;

    // Precompute phase trig terms once per blob (6 trig calls total per frame)
    final double p2 = phase + 0.4;
    final double cosP2 = math.cos(p2);
    final double sinP2 = math.sin(p2);

    final double p3 = -phase + 1.1;
    final double cosP3 = math.cos(p3);
    final double sinP3 = math.sin(p3);

    final double p4 = phase - 0.5;
    final double cosP4 = math.cos(p4);
    final double sinP4 = math.sin(p4);

    final path = Path();
    for (int i = 0; i < _steps; i++) {
      final pt = _basisPoints[i];

      // sin(2θ + p2) = sin(2θ)cos(p2) + cos(2θ)sin(p2)
      final double w2 = pt.sin2T * cosP2 + pt.cos2T * sinP2;
      // sin(3θ + p3) = sin(3θ)cos(p3) + cos(3θ)sin(p3)
      final double w3 = pt.sin3T * cosP3 + pt.cos3T * sinP3;
      // cos(4θ + p4) = cos(4θ)cos(p4) - sin(4θ)sin(p4)
      final double w4 = pt.cos4T * cosP4 - pt.sin4T * sinP4;

      final double wave = 1.0 + lobe2 * w2 + lobe3 * w3 + lobe4 * w4;
      final double r = pt.squircleRadius * wave;
      final double x = cx + rx * r * pt.cosT;
      final double y = cy + ry * r * pt.sinT;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final bool isDark = brightness == Brightness.dark;
    final double phi = progress * 2.0 * math.pi;

    // 1. Outer counter-rotating soft halo blob
    final Path outerBlob = _buildBlobPath(
      size,
      phase: -phi + 1.35,
      scaleX: 1.08,
      scaleY: 1.06,
      lobe2: 0.055,
      lobe3: 0.065,
      lobe4: 0.038,
    );
    final Paint outerFillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = colorScheme.primary.withValues(alpha: isDark ? 0.11 : 0.08);
    canvas.drawPath(outerBlob, outerFillPaint);

    // 2. Inner primary undulating blob with soft gradient fill
    final Path innerBlob = _buildBlobPath(
      size,
      phase: phi,
      scaleX: 1.02,
      scaleY: 1.01,
      lobe2: 0.050,
      lobe3: 0.060,
      lobe4: 0.035,
    );

    final Rect rect = Offset.zero & size;
    final Paint innerFillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colorScheme.primaryContainer.withValues(alpha: isDark ? 0.30 : 0.42),
          colorScheme.tertiaryContainer.withValues(alpha: isDark ? 0.20 : 0.28),
        ],
      ).createShader(rect);
    canvas.drawPath(innerBlob, innerFillPaint);
  }

  @override
  bool shouldRepaint(covariant CalendarTodayBlobPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.brightness != brightness ||
        oldDelegate.colorScheme != colorScheme;
  }
}

/// Bottom capacity bar representing a day's total planned workload (including
/// routine, weekly, and highlighted tasks), segmented proportionally by label
/// colors and scaled cleanly across overloaded months.
class CalendarLabelCapacityBar extends StatelessWidget {
  final CalendarDayWorkload workload;
  final double height;

  /// Optional upper bound in hours used to normalize bar fill width across a
  /// month so days above capacity remain visually distinguishable from each
  /// other instead of clamping identically to 100%.
  final double? scaleCapacityHours;

  const CalendarLabelCapacityBar({
    super.key,
    required this.workload,
    this.height = 4.0,
    this.scaleCapacityHours,
  });

  Color _resolveSegmentColor(
    BuildContext context,
    ThemeData theme,
    String? colorKey,
  ) {
    final baseColor = colorKey != null
        ? LabelPalette.getColor(colorKey, context)
        : theme.colorScheme.primary;
    if (workload.allCompleted) {
      return baseColor.withValues(alpha: 0.55);
    }
    return baseColor;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveCap = workload.effectiveCapacityHours;
    final denom =
        (scaleCapacityHours != null && scaleCapacityHours! > effectiveCap)
        ? scaleCapacityHours!
        : effectiveCap;
    final fillFraction = (workload.totalHours / denom).clamp(0.0, 1.0);
    final showCapMarker =
        denom > effectiveCap + 1e-6 &&
        workload.isOverCapacity &&
        !workload.allCompleted;
    final capFraction = (effectiveCap / denom).clamp(0.05, 0.95);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
          theme.colorScheme.surface,
        ),
        borderRadius: BorderRadius.circular(2.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: fillFraction <= 0 || workload.segments.isEmpty
          ? null
          : LayoutBuilder(
              builder: (context, constraints) {
                final barContent = FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: fillFraction,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < workload.segments.length; i++) ...[
                        if (i > 0) const SizedBox(width: 0.75),
                        Expanded(
                          flex: (workload.segments[i].minutes * 10)
                              .round()
                              .clamp(1, 100000),
                          child: ColoredBox(
                            color: _resolveSegmentColor(
                              context,
                              theme,
                              workload.segments[i].colorKey,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );

                if (!showCapMarker || !constraints.hasBoundedWidth) {
                  return barContent;
                }

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    barContent,
                    Positioned(
                      left: (constraints.maxWidth * capFraction) - 0.75,
                      top: 0,
                      bottom: 0,
                      width: 1.5,
                      child: ColoredBox(color: theme.colorScheme.error),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
