import 'package:flutter/material.dart';
import 'civil_day.dart';

/// Represents a time relative to a reference day.
///
/// It consists of a day offset (e.g., 0 for "day of", 1 for "day after")
/// and a specific time of day.
class RelativeTime {
  /// The offset in days relative to the reference day.
  /// 0 means the same day, 1 means the next day, -1 means the previous day, etc.
  final int dayOffset;

  /// The time of day.
  final TimeOfDay time;

  const RelativeTime({required this.dayOffset, required this.time});

  /// Calculates the [DateTime] relative to the given [reference] day.
  DateTime referenceTo(CivilDay reference) {
    // Start at midnight of the reference day
    final referenceMidnight = reference.toDateTime();

    // Add the day offset
    final dateWithOffset = referenceMidnight.add(Duration(days: dayOffset));

    // Add the time of day
    return dateWithOffset.add(Duration(hours: time.hour, minutes: time.minute));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RelativeTime &&
        other.dayOffset == dayOffset &&
        other.time == time;
  }

  @override
  int get hashCode => Object.hash(dayOffset, time);

  @override
  String toString() {
    return 'RelativeTime(offset: $dayOffset, time: $time)';
  }
}
