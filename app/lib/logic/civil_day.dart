/// Represents a single date.
///
/// This class represents a specific date (Year, Month, Day) in the civil calendar,
/// independent of any time zone or time of day. It is immutable.
class CivilDay {
  final int year;
  final int month;
  final int day;

  /// Creates a [CivilDay].
  const CivilDay({required this.year, required this.month, required this.day});

  /// Creates a [CivilDay] from a [DateTime].
  ///
  /// The time components of the [dateTime] are ignored.
  factory CivilDay.fromDateTime(DateTime dateTime) {
    return CivilDay(
      year: dateTime.year,
      month: dateTime.month,
      day: dateTime.day,
    );
  }

  factory CivilDay.fromJson(Map<String, dynamic> json) {
    return CivilDay(
      year: json['year'] as int,
      month: json['month'] as int,
      day: json['day'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {'year': year, 'month': month, 'day': day};
  }

  /// Converts this [CivilDay] to a [DateTime] at midnight (00:00:00).
  DateTime toDateTime() {
    return DateTime(year, month, day);
  }

  /// Converts this [CivilDay] to a UTC [DateTime] at midnight (00:00:00) UTC.
  DateTime toUtcDateTime() {
    return DateTime.utc(year, month, day);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CivilDay &&
        other.year == year &&
        other.month == month &&
        other.day == day;
  }

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() {
    return '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  }
}
