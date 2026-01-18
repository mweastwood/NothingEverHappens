class CivilDay {
  final int year;
  final int month;
  final int day;

  const CivilDay({required this.year, required this.month, required this.day});

  factory CivilDay.fromDateTime(DateTime dateTime) {
    return CivilDay(
      year: dateTime.year,
      month: dateTime.month,
      day: dateTime.day,
    );
  }

  DateTime toDateTime() {
    return DateTime(year, month, day);
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
