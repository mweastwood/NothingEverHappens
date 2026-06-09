import 'package:flutter/material.dart';
import '../logic/civil_day.dart';
import '../logic/l10n_extension.dart';

class MonthGrid extends StatelessWidget {
  final int year;
  final int month;
  final Set<CivilDay> highlightedDays;
  final Set<CivilDay> startDays;
  final Set<CivilDay> dueDays;
  final Set<CivilDay> rangeDays;
  final CivilDay startDate;

  const MonthGrid({
    super.key,
    required this.year,
    required this.month,
    required this.highlightedDays,
    required this.startDays,
    required this.dueDays,
    required this.rangeDays,
    required this.startDate,
  });

  List<String> _getMonthNames(BuildContext context) {
    final l10n = context.l10n;
    return [
      l10n.monthJanuary,
      l10n.monthFebruary,
      l10n.monthMarch,
      l10n.monthApril,
      l10n.monthMay,
      l10n.monthJune,
      l10n.monthJuly,
      l10n.monthAugust,
      l10n.monthSeptember,
      l10n.monthOctober,
      l10n.monthNovember,
      l10n.monthDecember,
    ];
  }

  List<String> _getWeekdayHeaders(BuildContext context) {
    final l10n = context.l10n;
    return [
      l10n.weekdayHeaderMonday,
      l10n.weekdayHeaderTuesday,
      l10n.weekdayHeaderWednesday,
      l10n.weekdayHeaderThursday,
      l10n.weekdayHeaderFriday,
      l10n.weekdayHeaderSaturday,
      l10n.weekdayHeaderSunday,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstDay = DateTime.utc(year, month, 1);
    final totalDays = DateTime.utc(year, month + 1, 0).day;
    final firstWeekday = firstDay.weekday; // 1 = Mon, 7 = Sun

    final monthName = _getMonthNames(context)[month - 1];
    final weekdayLabels = _getWeekdayHeaders(context);

    return Container(
      width: 250,
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$monthName $year',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // Weekday headers
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: 7,
            itemBuilder: (context, index) {
              return Center(
                child: Text(
                  weekdayLabels[index],
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            },
          ),
          const Divider(height: 8),
          // Days grid
          GridView.builder(
            key: Key('month_${year}_$month'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: (firstWeekday - 1) + totalDays,
            itemBuilder: (context, index) {
              if (index < firstWeekday - 1) {
                return const SizedBox.shrink();
              }
              final day = index - (firstWeekday - 1) + 1;
              final currentDay = CivilDay(year: year, month: month, day: day);

              final isRangeDay = rangeDays.contains(currentDay);
              final isStartDay = startDays.contains(currentDay);
              final isDueDay = dueDays.contains(currentDay);
              final isOccurrenceDay = highlightedDays.contains(currentDay);

              Widget? rangeBackground;
              TextStyle? textStyle = theme.textTheme.bodyMedium;

              if (isRangeDay) {
                if (isStartDay && isDueDay) {
                  // Single day range / overlap -> perfect circle
                  rangeBackground = Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  );
                  textStyle = TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  );
                } else if (isStartDay) {
                  // Left-rounded cap
                  rangeBackground = Stack(
                    children: [
                      Positioned(
                        left: 14,
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.15,
                          ),
                        ),
                      ),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(14),
                            bottomLeft: Radius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  );
                  textStyle = TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  );
                } else if (isDueDay) {
                  // Right-rounded cap
                  rangeBackground = Stack(
                    children: [
                      Positioned(
                        left: 0,
                        right: 14,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.15,
                          ),
                        ),
                      ),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(14),
                            bottomRight: Radius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  );
                  textStyle = TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  );
                } else {
                  // Shaded middle day
                  rangeBackground = Container(
                    width: double.infinity,
                    height: 28,
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  );
                }
              }

              // Non-color occurrence indicator inside the day cell
              Widget? occurrenceIndicator;
              if (isOccurrenceDay) {
                final indicatorColor = (isStartDay || isDueDay)
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.primary;
                occurrenceIndicator = Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border.all(color: indicatorColor, width: 1),
                    shape: BoxShape.circle,
                  ),
                );
              }

              return Center(
                child: SizedBox(
                  key: Key('day_${year}_${month}_$day'),
                  width: 28,
                  height: 28,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (rangeBackground != null) rangeBackground,
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$day', style: textStyle),
                          if (occurrenceIndicator != null) occurrenceIndicator,
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
