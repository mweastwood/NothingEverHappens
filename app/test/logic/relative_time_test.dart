import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';

void main() {
  group('RelativeTime', () {
    test('referenceTo calculates correct DateTime for same day', () {
      const relative = RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 9, minute: 30),
      );
      const reference = CivilDay(year: 2023, month: 10, day: 25);

      final result = relative.referenceTo(reference);

      expect(result, DateTime(2023, 10, 25, 9, 30));
    });

    test('referenceTo calculates correct DateTime for next day', () {
      const relative = RelativeTime(
        dayOffset: 1,
        time: TimeOfDay(hour: 14, minute: 0),
      );
      const reference = CivilDay(year: 2023, month: 10, day: 25);

      final result = relative.referenceTo(reference);

      expect(result, DateTime(2023, 10, 26, 14, 0));
    });

    test('referenceTo calculates correct DateTime for previous day', () {
      const relative = RelativeTime(
        dayOffset: -1,
        time: TimeOfDay(hour: 23, minute: 59),
      );
      const reference = CivilDay(year: 2023, month: 10, day: 25);

      final result = relative.referenceTo(reference);

      expect(result, DateTime(2023, 10, 24, 23, 59));
    });

    test('referenceTo handles month crossover', () {
      const relative = RelativeTime(
        dayOffset: 1,
        time: TimeOfDay(hour: 10, minute: 0),
      );
      const reference = CivilDay(year: 2023, month: 10, day: 31);

      final result = relative.referenceTo(reference);

      expect(result, DateTime(2023, 11, 1, 10, 0));
    });

    test('equality works', () {
      const t1 = RelativeTime(
        dayOffset: 1,
        time: TimeOfDay(hour: 10, minute: 0),
      );
      const t2 = RelativeTime(
        dayOffset: 1,
        time: TimeOfDay(hour: 10, minute: 0),
      );
      const t3 = RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 10, minute: 0),
      );

      expect(t1, equals(t2));
      expect(t1, isNot(equals(t3)));
    });
  });
}
