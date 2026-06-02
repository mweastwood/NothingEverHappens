import 'package:flutter/material.dart';

class CycleHelper {
  /// Calculates the ISO week number for a given [date].
  /// Monday is considered the first day of the week.
  static int getIsoWeekNumber(DateTime date) {
    // Thursday of this week is always in the same week numbering year.
    // date.weekday: 1 = Monday, ..., 7 = Sunday.
    final thursday = date.add(Duration(days: 4 - date.weekday));
    final jan4 = DateTime(thursday.year, 1, 4);
    // Find the Monday of the week containing Jan 4.
    final jan4Monday = jan4.subtract(Duration(days: jan4.weekday - 1));
    return thursday.difference(jan4Monday).inDays ~/ 7 + 1;
  }

  /// Calculates the cycle ID for a given [date].
  /// Format: "yyyy-Www" where yyyy is the week-numbering year and ww is the ISO week number (1-53).
  /// E.g., "2026-W23".
  static String getCycleId(DateTime date) {
    final thursday = date.add(Duration(days: 4 - date.weekday));
    final week = getIsoWeekNumber(date);
    final weekStr = week.toString().padLeft(2, '0');
    return '${thursday.year}-W$weekStr';
  }

  /// Calculates the start and end dates of the cycle containing [date].
  /// [startWeekday] defaults to [DateTime.monday] (1).
  /// The start date is at 00:00:00, and the end date is at 23:59:59.999.
  static DateTimeRange getCycleRange(DateTime date, {int startWeekday = DateTime.monday}) {
    final diff = (date.weekday - startWeekday + 7) % 7;
    final start = DateTime(date.year, date.month, date.day).subtract(Duration(days: diff));
    final end = start.add(const Duration(days: 6));
    return DateTimeRange(
      start: start,
      end: DateTime(end.year, end.month, end.day, 23, 59, 59, 999),
    );
  }
}
