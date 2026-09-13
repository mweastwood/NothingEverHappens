import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../logic/civil_day.dart';
import '../logic/calendar_day_task.dart';
import '../logic/l10n_extension.dart';
import '../logic/task_priority.dart';
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

/// Computes localized weekday header initials starting with Monday.
List<String> getWeekdayHeaders(String locale) {
  try {
    final symbols = DateFormat(null, locale).dateSymbols;
    final narrow = symbols.STANDALONENARROWWEEKDAYS.isNotEmpty
        ? symbols.STANDALONENARROWWEEKDAYS
        : symbols.NARROWWEEKDAYS;
    return [for (int i = 1; i <= 6; i++) narrow[i], narrow[0]];
  } catch (_) {
    return const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  }
}

/// Renders a single month card with weekday headers and interactive day cells.
class CalendarMonthCard extends StatelessWidget {
  final DateTime monthDate;
  final Map<CivilDay, List<CalendarDayTask>> dayTaskMap;
  final CivilDay today;
  final bool isWide;
  final void Function(CivilDay day)? onDayTap;

  const CalendarMonthCard({
    super.key,
    required this.monthDate,
    this.dayTaskMap = const {},
    required this.today,
    this.isWide = false,
    this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final monthTitle = DateFormat.yMMMM(locale).format(monthDate);
    final weekdayHeaders = getWeekdayHeaders(locale);
    final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
    final firstWeekday = DateTime(
      monthDate.year,
      monthDate.month,
      1,
    ).weekday; // 1=Mon, 7=Sun
    final leadingEmptyCount = firstWeekday - 1;

    final totalSlots = leadingEmptyCount + daysInMonth;
    final rowCount = (totalSlots / 7).ceil();

    final isCurrentMonth =
        monthDate.year == today.year && monthDate.month == today.month;

    return RepaintBoundary(
      child: Card(
        key: Key('month_card_${monthDate.year}_${monthDate.month}'),
        elevation: isCurrentMonth ? 2.5 : 1.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isCurrentMonth
              ? BorderSide(
                  color: theme.colorScheme.primary.withValues(alpha: 0.6),
                  width: 1.5,
                )
              : BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.4,
                  ),
                  width: 0.5,
                ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Month Header
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
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
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.7),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              const Divider(height: 1, thickness: 0.5),
              const SizedBox(height: 4),
              // Calendar Day Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  final cellWidth = constraints.maxWidth / 7;
                  final cellHeight = isWide ? 62.0 : 54.0;
                  final bool isTier1 = cellWidth >= 60 && cellHeight >= 50;
                  final bool isTier2 =
                      !isTier1 && cellWidth >= 42 && cellHeight >= 42;

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
                                    onDayTap: onDayTap,
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
  final void Function(CivilDay day)? onDayTap;

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
    this.onDayTap,
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
    final tasks = dayTaskMap[civilDay] ?? const [];
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        if (onDayTap != null) {
          onDayTap!(civilDay);
        } else {
          CalendarDayDetailsSheet.show(context, day: civilDay);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isToday
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
              : (tasks.isNotEmpty
                    ? theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.25,
                      )
                    : null),
          border: isToday
              ? Border.all(color: theme.colorScheme.primary, width: 1.5)
              : (tasks.isNotEmpty
                    ? Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                        width: 0.5,
                      )
                    : null),
        ),
        child: _buildResponsiveDayContent(
          context,
          dayNum,
          isToday,
          tasks,
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
    List<CalendarDayTask> tasks,
    ThemeData theme, {
    required bool isTier1,
    required bool isTier2,
  }) {
    if (isTier1) {
      return _buildTier1Day(context, dayNum, isToday, tasks, theme);
    } else if (isTier2) {
      return _buildTier2Day(dayNum, isToday, tasks, theme);
    } else {
      return _buildTier3Day(dayNum, isToday, tasks, theme);
    }
  }

  /// Tier 1: Wide space -> Day number + task count + truncated title chips
  Widget _buildTier1Day(
    BuildContext context,
    int dayNum,
    bool isToday,
    List<CalendarDayTask> tasks,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$dayNum',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                  color: isToday
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
              if (tasks.isNotEmpty)
                Text(
                  '${tasks.length}',
                  style: TextStyle(
                    fontSize: 9,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.7,
                    ),
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 1),
          if (tasks.isNotEmpty) ...[
            for (int i = 0; i < (tasks.length > 2 ? 1 : tasks.length); i++) ...[
              CalendarTaskChip(task: tasks[i], showText: true),
              const SizedBox(height: 1),
            ],
            if (tasks.length > 2)
              Text(
                context.l10n.moreTasksCount(tasks.length - 1),
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Tier 2: Medium space -> Day number + compact task pills
  Widget _buildTier2Day(
    int dayNum,
    bool isToday,
    List<CalendarDayTask> tasks,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              '$dayNum',
              style: TextStyle(
                fontSize: 10,
                fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                color: isToday
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
          const Spacer(),
          if (tasks.isNotEmpty) ...[
            CalendarTaskChip(task: tasks[0], showText: true),
            if (tasks.length > 1)
              Center(
                child: Text(
                  '+${tasks.length - 1}',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
          ],
          const Spacer(),
        ],
      ),
    );
  }

  /// Tier 3: Compact space -> Day number + colored priority dots
  Widget _buildTier3Day(
    int dayNum,
    bool isToday,
    List<CalendarDayTask> tasks,
    ThemeData theme,
  ) {
    return Column(
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
        if (tasks.isNotEmpty) ...[
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (
                int i = 0;
                i < (tasks.length > 3 ? 3 : tasks.length);
                i++
              ) ...[
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 0.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tasks[i].isCompleted
                        ? theme.colorScheme.outline
                        : getPriorityColor(
                            theme.colorScheme,
                            tasks[i].priority,
                          ),
                  ),
                ),
              ],
              if (tasks.length > 3)
                Container(
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Compact chip displaying a task's priority and completion state.
class CalendarTaskChip extends StatelessWidget {
  final CalendarDayTask task;
  final bool showText;

  const CalendarTaskChip({super.key, required this.task, this.showText = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = getPriorityColor(theme.colorScheme, task.priority);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 1.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: task.isCompleted ? 0.08 : 0.18),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: task.isCompleted ? theme.colorScheme.outline : color,
            ),
          ),
          if (showText) ...[
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 8.5,
                  decoration: task.isCompleted
                      ? TextDecoration.lineThrough
                      : null,
                  color: task.isCompleted
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                      : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
