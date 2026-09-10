import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('RelativeTime Tests', () {
    test('constructs and computes minutes', () {
      const rt = RelativeTime(dayOffset: 0, hour: 14, minute: 30);
      expect(rt.dayOffset, equals(0));
      expect(rt.hour, equals(14));
      expect(rt.minute, equals(30));
      expect(rt.minutes, equals(14 * 60 + 30));
    });

    test('constructs from minutes', () {
      final rt = RelativeTime.fromMinutes(dayOffset: 1, minutes: 90);
      expect(rt.dayOffset, equals(1));
      expect(rt.hour, equals(1));
      expect(rt.minute, equals(30));
      expect(rt.minutes, equals(90));
    });

    test('constructs from DateTime', () {
      final dt = DateTime(2026, 9, 8, 11, 45);
      final rt = RelativeTime.fromDateTime(dt, dayOffset: 2);
      expect(rt.dayOffset, equals(2));
      expect(rt.hour, equals(11));
      expect(rt.minute, equals(45));
    });

    test('serializes to/from JSON', () {
      const rt = RelativeTime(dayOffset: 0, hour: 9, minute: 15);
      final json = rt.toJson();
      expect(json['dayOffset'], equals(0));
      expect(json['hour'], equals(9));
      expect(json['minute'], equals(15));

      final fromJson = RelativeTime.fromJson(json);
      expect(fromJson, equals(rt));

      final fromMinutesJson =
          RelativeTime.fromJson({'dayOffset': 1, 'minutes': 1439});
      expect(fromMinutesJson.hour, equals(23));
      expect(fromMinutesJson.minute, equals(59));
    });

    test('calculates referenceTo CivilDay', () {
      const reference = CivilDay(year: 2026, month: 8, day: 30);
      const rt = RelativeTime(dayOffset: 1, hour: 10, minute: 0);

      final dt = rt.referenceTo(reference);
      expect(dt.year, equals(2026));
      expect(dt.month, equals(8));
      expect(dt.day, equals(31));
      expect(dt.hour, equals(10));
      expect(dt.minute, equals(0));
    });
  });
}
