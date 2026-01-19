import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';

void main() {
  group('CivilDay', () {
    test('Stores date components correctly', () {
      const day = CivilDay(year: 2024, month: 1, day: 31);
      expect(day.year, 2024);
      expect(day.month, 1);
      expect(day.day, 31);
    });

    test('Equality works correctly', () {
      const day1 = CivilDay(year: 2024, month: 1, day: 1);
      const day2 = CivilDay(year: 2024, month: 1, day: 1);
      const day3 = CivilDay(year: 2024, month: 1, day: 2);

      expect(day1, equals(day2));
      expect(day1, isNot(equals(day3)));
      expect(day1.hashCode, equals(day2.hashCode));
    });

    test('Converts from DateTime correctly', () {
      final dt = DateTime(2024, 12, 25, 14, 30);
      final cd = CivilDay.fromDateTime(dt);

      expect(cd.year, 2024);
      expect(cd.month, 12);
      expect(cd.day, 25);
    });

    test('Converts to DateTime correctly (Midnight)', () {
      const cd = CivilDay(year: 2024, month: 12, day: 25);
      final dt = cd.toDateTime();

      expect(dt.year, 2024);
      expect(dt.month, 12);
      expect(dt.day, 25);
      expect(dt.hour, 0);
      expect(dt.minute, 0);
    });
  });
}
