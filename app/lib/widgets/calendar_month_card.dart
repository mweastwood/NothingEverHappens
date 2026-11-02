import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../logic/civil_day.dart';
import '../logic/calendar_day_task.dart';
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

/// Renders a single month section with weekday headers and interactive day cells.
class CalendarMonthCard extends StatelessWidget {
  /// Row height used for narrow (single-column mobile) month grids.
  static const double narrowCellHeight = 64.0;

  /// Row height used for wide (two-column tablet/desktop) month grids.
  static const double wideCellHeight = 70.0;

  final DateTime monthDate;
  final Map<CivilDay, List<CalendarDayTask>> dayTaskMap;
  final CivilDay today;
  final bool isWide;
  final void Function(CivilDay day)? onDayTap;
  final FirstDayOfWeek firstDayOfWeek;
  final Map<String, TaskLabel> labelsMap;
  final UserSettings? userSettings;

  const CalendarMonthCard({
    super.key,
    required this.monthDate,
    this.dayTaskMap = const {},
    required this.today,
    this.isWide = false,
    this.onDayTap,
    this.firstDayOfWeek = FirstDayOfWeek.sunday,
    this.labelsMap = const {},
    this.userSettings,
  });

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

    return RepaintBoundary(
      child: Container(
        key: Key('month_card_${monthDate.year}_${monthDate.month}'),
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Month Header
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
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
                final bool isTier1 = cellWidth >= 60 && cellHeight >= 48;
                final bool isTier2 =
                    !isTier1 && cellWidth >= 42 && cellHeight >= 42;
                final bool showChipIcon = cellWidth >= 72;

                return Column(
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
                                  isTier1: isTier1,
                                  isTier2: isTier2,
                                  showChipIcon: showChipIcon,
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
  final bool isTier1;
  final bool isTier2;
  final bool showChipIcon;
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
    required this.isTier1,
    required this.isTier2,
    this.showChipIcon = false,
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

    final bool showOverloadAlert =
        workload.isOverCapacity && !isPast && !workload.allCompleted;
    final bool showHighLoadTint =
        workload.isHighLoad && !isPast && !workload.allCompleted;

    final Color? cellBgColor;
    final Border cellBorder;
    if (isToday) {
      cellBgColor = theme.colorScheme.primaryContainer.withValues(alpha: 0.22);
      cellBorder = Border.all(color: theme.colorScheme.primary, width: 1.0);
    } else if (showOverloadAlert) {
      cellBgColor = theme.colorScheme.errorContainer.withValues(alpha: 0.18);
      cellBorder = Border.all(
        color: theme.colorScheme.error.withValues(alpha: 0.55),
        width: 0.75,
      );
    } else if (showHighLoadTint) {
      cellBgColor = theme.colorScheme.tertiaryContainer.withValues(alpha: 0.14);
      cellBorder = Border.all(
        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.28),
        width: 0.5,
      );
    } else {
      cellBgColor = null;
      cellBorder = Border.all(
        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.24),
        width: 0.5,
      );
    }

    return InkWell(
      onTap: () {
        if (onDayTap != null) {
          onDayTap!(civilDay);
        } else {
          CalendarDayDetailsSheet.show(context, day: civilDay);
        }
      },
      child: Container(
        decoration: BoxDecoration(color: cellBgColor, border: cellBorder),
        child: _buildResponsiveDayContent(
          context,
          dayNum,
          isToday,
          workload,
          theme,
          isTier1: isTier1,
          isTier2: isTier2,
        ),
      ),
    );
  }

  Widget _buildResponsiveDayContent(
    BuildContext context,
    int dayNum,
    bool isToday,
    CalendarDayWorkload workload,
    ThemeData theme, {
    required bool isTier1,
    required bool isTier2,
  }) {
    if (isTier1) {
      return _buildTier1Day(context, dayNum, isToday, workload, theme);
    } else if (isTier2) {
      return _buildTier2Day(context, dayNum, isToday, workload, theme);
    } else {
      return _buildTier3Day(dayNum, isToday, workload, theme);
    }
  }

  /// Tier 1: Wide space -> Day number row + standout task chip + (+N & hours row) + capacity bar
  Widget _buildTier1Day(
    BuildContext context,
    int dayNum,
    bool isToday,
    CalendarDayWorkload workload,
    ThemeData theme,
  ) {
    final standout = workload.standoutTask;

    return Padding(
      padding: const EdgeInsets.fromLTRB(3.5, 3, 3.5, 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: Day number (and completed check icon if all done)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$dayNum',
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.0,
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                  color: isToday
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
              if (workload.allCompleted)
                Icon(
                  Icons.check_circle,
                  size: 9.5,
                  color: theme.colorScheme.primary.withValues(alpha: 0.75),
                ),
            ],
          ),
          const SizedBox(height: 2.5),
          // Row 2: Standout Hero Task Chip
          Expanded(
            child: standout == null
                ? const SizedBox.shrink()
                : CalendarTaskChip(
                    task: standout,
                    labelsMap: labelsMap,
                    showText: true,
                    maxLines: 2,
                    compact: !showChipIcon,
                  ),
          ),
          if (workload.isNotEmpty) ...[
            const SizedBox(height: 2.5),
            // Row 3: +N overflow count on left, total planned hours on right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (workload.additionalTasksCount > 0)
                  Text(
                    '+${workload.additionalTasksCount}',
                    style: TextStyle(
                      fontSize: 8.5,
                      height: 1.0,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary.withValues(alpha: 0.85),
                    ),
                  )
                else
                  const SizedBox.shrink(),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      workload.formattedPlannedHours,
                      style: TextStyle(
                        fontSize: 8.5,
                        height: 1.0,
                        color: workload.isOverCapacity && !workload.allCompleted
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.8,
                              ),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            // Row 4: Label-segmented capacity bar
            CalendarLabelCapacityBar(workload: workload, height: 4.0),
          ],
        ],
      ),
    );
  }

  /// Tier 2: Mobile portrait space -> Day number row + 2-line standout chip + (+N & hours row) + capacity bar
  Widget _buildTier2Day(
    BuildContext context,
    int dayNum,
    bool isToday,
    CalendarDayWorkload workload,
    ThemeData theme,
  ) {
    final standout = workload.standoutTask;

    return Padding(
      padding: const EdgeInsets.fromLTRB(3, 2.5, 3, 2.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: Day number (and completed check icon if all done)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$dayNum',
                style: TextStyle(
                  fontSize: 10,
                  height: 1.0,
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                  color: isToday
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
              if (workload.allCompleted)
                Icon(
                  Icons.check_circle,
                  size: 9,
                  color: theme.colorScheme.primary.withValues(alpha: 0.75),
                ),
            ],
          ),
          const SizedBox(height: 2),
          // Row 2: Standout Hero Task Chip
          Expanded(
            child: standout == null
                ? const SizedBox.shrink()
                : CalendarTaskChip(
                    task: standout,
                    labelsMap: labelsMap,
                    showText: true,
                    maxLines: 2,
                    compact: true,
                  ),
          ),
          if (workload.isNotEmpty) ...[
            const SizedBox(height: 2),
            // Row 3: +N overflow count on left, total planned hours on right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (workload.additionalTasksCount > 0)
                  Text(
                    '+${workload.additionalTasksCount}',
                    style: TextStyle(
                      fontSize: 7.5,
                      height: 1.0,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: theme.colorScheme.primary.withValues(alpha: 0.85),
                    ),
                  )
                else
                  const SizedBox.shrink(),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      workload.formattedPlannedHours,
                      style: TextStyle(
                        fontSize: 7.5,
                        height: 1.0,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: workload.isOverCapacity && !workload.allCompleted
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.85,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            // Row 4: Label-segmented capacity bar
            CalendarLabelCapacityBar(workload: workload, height: 3.5),
          ],
        ],
      ),
    );
  }

  /// Tier 3: Compact space -> Day number + label-segmented capacity bar
  Widget _buildTier3Day(
    int dayNum,
    bool isToday,
    CalendarDayWorkload workload,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$dayNum',
            style: TextStyle(
              fontSize: 10,
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              color: isToday ? theme.colorScheme.primary : null,
            ),
          ),
          if (workload.isNotEmpty) ...[
            const SizedBox(height: 3),
            CalendarLabelCapacityBar(workload: workload, height: 4.0),
          ],
        ],
      ),
    );
  }
}

/// Bottom capacity bar segmented proportionally by task label colors.
class CalendarLabelCapacityBar extends StatelessWidget {
  final CalendarDayWorkload workload;
  final double height;

  const CalendarLabelCapacityBar({
    super.key,
    required this.workload,
    this.height = 5.0,
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
    final fillFraction = workload.loadRatio.clamp(0.0, 1.0);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.65,
        ),
        borderRadius: BorderRadius.circular(1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: fillFraction <= 0 || workload.segments.isEmpty
          ? null
          : FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: fillFraction,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < workload.segments.length; i++) ...[
                    if (i > 0) const SizedBox(width: 1),
                    Expanded(
                      flex: (workload.segments[i].minutes * 10).round().clamp(
                        1,
                        100000,
                      ),
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
            ),
    );
  }
}

/// Compact chip displaying a standout task styled with its primary label color (or priority fallback).
class CalendarTaskChip extends StatelessWidget {
  final CalendarDayTask task;
  final bool showText;
  final Map<String, TaskLabel> labelsMap;
  final int maxLines;
  final bool compact;

  const CalendarTaskChip({
    super.key,
    required this.task,
    this.showText = true,
    this.labelsMap = const {},
    this.maxLines = 1,
    this.compact = false,
  });

  TaskLabel? _resolvePrimaryLabel() {
    for (final id in task.labelIds) {
      final label = labelsMap[id];
      if (label != null) return label;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryLabel = _resolvePrimaryLabel();
    final accentColor = primaryLabel != null
        ? LabelPalette.getColor(primaryLabel.colorKey, context)
        : getPriorityColor(theme.colorScheme, task.priority);

    final isRoutine = task.isRoutineDaily;
    final bgAlpha = task.isCompleted ? 0.07 : (isRoutine ? 0.12 : 0.20);
    final stripeColor = task.isCompleted
        ? theme.colorScheme.outline.withValues(alpha: 0.6)
        : accentColor;

    return Container(
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 2.5 : 3.5,
        vertical: 1.5,
      ),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: bgAlpha),
        borderRadius: BorderRadius.circular(2.0),
        border: Border(
          left: BorderSide(color: stripeColor, width: compact ? 2.0 : 2.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!compact && primaryLabel != null) ...[
            Icon(
              LabelIcons.getIcon(primaryLabel.iconKey),
              size: 9.5,
              color: stripeColor,
            ),
            const SizedBox(width: 2.5),
          ] else if (!compact) ...[
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: stripeColor,
              ),
            ),
            const SizedBox(width: 2.5),
          ],
          if (showText)
            Expanded(
              child: Text(
                task.title,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 8.5 : 9.0,
                  height: 1.1,
                  letterSpacing: compact ? -0.2 : -0.1,
                  decoration: task.isCompleted
                      ? TextDecoration.lineThrough
                      : null,
                  color: task.isCompleted
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
                      : theme.colorScheme.onSurface,
                  fontWeight: isRoutine ? FontWeight.w500 : FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
