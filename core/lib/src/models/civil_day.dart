import 'package:meta/meta.dart';

/// Represents a single date in the civil calendar (Year, Month, Day),
/// independent of any time zone or time of day. It is immutable.
@immutable
class CivilDay implements Comparable<CivilDay> {
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

  /// Parses a string in YYYY-MM-DD format into a [CivilDay].
  factory CivilDay.parse(String isoDate) {
    final parsed = tryParse(isoDate);
    if (parsed == null) {
      throw FormatException("Invalid CivilDay string: '$isoDate'");
    }
    return parsed;
  }

  /// Attempts to parse a string in YYYY-MM-DD format into a [CivilDay].
  static CivilDay? tryParse(String? isoDate) {
    if (isoDate == null || !isValid(isoDate)) return null;
    final parts = isoDate.split('-');
    return CivilDay(
      year: int.parse(parts[0]),
      month: int.parse(parts[1]),
      day: int.parse(parts[2]),
    );
  }

  /// Validates whether the given string is in valid YYYY-MM-DD format.
  static bool isValid(String? date) {
    if (date == null) return false;
    final regex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!regex.hasMatch(date)) return false;
    final parts = date.split('-');
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return false;
    if (y < 1 || m < 1 || m > 12 || d < 1 || d > 31) return false;
    const daysInMonths = [0, 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (d > daysInMonths[m]) return false;
    return true;
  }

  Map<String, dynamic> toJson() {
    return {'year': year, 'month': month, 'day': day};
  }

  /// Converts this [CivilDay] to a [DateTime] at midnight (00:00:00) local time.
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

  bool isBefore(CivilDay other) => compareTo(other) < 0;

  bool isAfter(CivilDay other) => compareTo(other) > 0;

  @override
  int compareTo(CivilDay other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  CivilDay addDays(int days) {
    final utc = toUtcDateTime().add(Duration(days: days));
    return CivilDay(year: utc.year, month: utc.month, day: utc.day);
  }

  String toIso8601String() => toString();

  @override
  String toString() {
    return '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  }
}
