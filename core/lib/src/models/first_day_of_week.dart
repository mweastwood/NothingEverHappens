enum FirstDayOfWeek {
  sunday,
  monday;

  String toJson() => name;

  /// Returns the number of empty slots preceding the 1st of the month
  /// when [firstWeekdayOfMonth] is Dart's DateTime weekday (1=Monday, 7=Sunday).
  int getLeadingEmptySlots(int firstWeekdayOfMonth) {
    if (this == FirstDayOfWeek.sunday) {
      return firstWeekdayOfMonth % 7;
    } else {
      return firstWeekdayOfMonth - 1;
    }
  }

  static FirstDayOfWeek fromString(dynamic value) {
    if (value == null) return FirstDayOfWeek.sunday;
    if (value is FirstDayOfWeek) return value;
    if (value is int) {
      if (value == 1) return FirstDayOfWeek.monday;
      if (value == 7 || value == 0) return FirstDayOfWeek.sunday;
    }
    final normalized = value.toString().toLowerCase().trim();
    switch (normalized) {
      case 'monday':
      case 'mon':
      case '1':
        return FirstDayOfWeek.monday;
      case 'sunday':
      case 'sun':
      case '7':
      case '0':
      default:
        return FirstDayOfWeek.sunday;
    }
  }
}
