import 'package:meta/meta.dart';
import 'civil_day.dart';

/// Represents a time relative to a reference day.
///
/// Consists of a day offset (0 for day of, 1 for next day, -1 for previous)
/// and a specific hour (0-23) and minute (0-59).
@immutable
class RelativeTime {
  /// Day offset relative to reference day (0 = same day, 1 = next day).
  final int dayOffset;

  /// Hour of the day (0-23).
  final int hour;

  /// Minute of the hour (0-59).
  final int minute;

  const RelativeTime({
    this.dayOffset = 0,
    required this.hour,
    required this.minute,
  });

  /// Constructs a [RelativeTime] from total minutes in the day.
  factory RelativeTime.fromMinutes({int dayOffset = 0, required int minutes}) {
    final clamped = minutes < 0 ? 0 : minutes;
    final h = (clamped ~/ 60) % 24;
    final m = clamped % 60;
    return RelativeTime(dayOffset: dayOffset, hour: h, minute: m);
  }

  /// Constructs a [RelativeTime] from a [DateTime].
  factory RelativeTime.fromDateTime(DateTime dateTime, {int dayOffset = 0}) {
    return RelativeTime(
      dayOffset: dayOffset,
      hour: dateTime.hour,
      minute: dateTime.minute,
    );
  }

  factory RelativeTime.fromJson(Map<String, dynamic> json) {
    final dayOffset = (json['dayOffset'] as num?)?.toInt() ?? 0;
    if (json.containsKey('hour') && json.containsKey('minute')) {
      return RelativeTime(
        dayOffset: dayOffset,
        hour: (json['hour'] as num).toInt(),
        minute: (json['minute'] as num).toInt(),
      );
    } else if (json.containsKey('minutes')) {
      final totalMins = (json['minutes'] as num).toInt();
      return RelativeTime.fromMinutes(dayOffset: dayOffset, minutes: totalMins);
    }
    return RelativeTime(dayOffset: dayOffset, hour: 0, minute: 0);
  }

  /// Total minutes from midnight within the current day offset.
  int get minutes => hour * 60 + minute;

  Map<String, dynamic> toJson() {
    return {
      'dayOffset': dayOffset,
      'hour': hour,
      'minute': minute,
    };
  }

  /// Calculates the [DateTime] relative to the given [reference] day.
  DateTime referenceTo(CivilDay reference) {
    final referenceUtc = DateTime.utc(
      reference.year,
      reference.month,
      reference.day,
    );
    final targetUtc = referenceUtc.add(Duration(days: dayOffset));
    return DateTime(
      targetUtc.year,
      targetUtc.month,
      targetUtc.day,
      hour,
      minute,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RelativeTime &&
        other.dayOffset == dayOffset &&
        other.hour == hour &&
        other.minute == minute;
  }

  @override
  int get hashCode => Object.hash(dayOffset, hour, minute);

  @override
  String toString() {
    return 'RelativeTime(offset: $dayOffset, ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')})';
  }
}
