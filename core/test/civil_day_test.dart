import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('CivilDay Tests', () {
    test('constructs and converts to/from DateTime', () {
      const day = CivilDay(year: 2026, month: 8, day: 30);
      expect(day.year, equals(2026));
      expect(day.month, equals(8));
      expect(day.day, equals(30));
      expect(day.toString(), equals('2026-08-30'));
      expect(day.toIso8601String(), equals('2026-08-30'));

      final dt = DateTime(2026, 8, 30, 15, 30);
      final fromDt = CivilDay.fromDateTime(dt);
      expect(fromDt, equals(day));
    });

    test('parses and validates YYYY-MM-DD', () {
      expect(CivilDay.isValid('2026-08-30'), isTrue);
      expect(CivilDay.isValid('2026-02-28'), isTrue);
      expect(CivilDay.isValid('2026-13-01'), isFalse);
      expect(CivilDay.isValid('2026-00-01'), isFalse);
      expect(CivilDay.isValid('2026-08-32'), isFalse);
      expect(CivilDay.isValid('invalid'), isFalse);
      expect(CivilDay.isValid(null), isFalse);

      final parsed = CivilDay.parse('2026-08-30');
      expect(parsed, equals(const CivilDay(year: 2026, month: 8, day: 30)));
      expect(() => CivilDay.parse('invalid'), throwsFormatException);
    });

    test('serializes to/from JSON', () {
      const day = CivilDay(year: 2026, month: 8, day: 30);
      final json = day.toJson();
      expect(json, equals({'year': 2026, 'month': 8, 'day': 30}));
      expect(CivilDay.fromJson(json), equals(day));
    });

    test('compares and offsets correctly', () {
      const day1 = CivilDay(year: 2026, month: 8, day: 30);
      const day2 = CivilDay(year: 2026, month: 8, day: 31);
      const day3 = CivilDay(year: 2026, month: 9, day: 1);

      expect(day1.isBefore(day2), isTrue);
      expect(day2.isAfter(day1), isTrue);
      expect(day1.compareTo(day2), lessThan(0));
      expect(day1.addDays(1), equals(day2));
      expect(day1.addDays(2), equals(day3));
    });
  });
}
