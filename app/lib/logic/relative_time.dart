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

  factory RelativeTime.fromJson(Map<String, dynamic> json) {
    return RelativeTime(
      dayOffset: json['dayOffset'] as int,
      time: TimeOfDay(hour: json['hour'] as int, minute: json['minute'] as int),
    );
  }

  Map<String, dynamic> toJson() {
    return {'dayOffset': dayOffset, 'hour': time.hour, 'minute': time.minute};
  }

  /// Calculates the [DateTime] relative to the given [reference] day.
  DateTime referenceTo(CivilDay reference) {
    // Calculate the target day in UTC first to avoid DST shifts
    final referenceUtc = DateTime.utc(reference.year, reference.month, reference.day);
    final targetUtc = referenceUtc.add(Duration(days: dayOffset));

    // Construct the local DateTime using the target day's components and relative time components
    return DateTime(
      targetUtc.year,
      targetUtc.month,
      targetUtc.day,
      time.hour,
      time.minute,
    );
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
