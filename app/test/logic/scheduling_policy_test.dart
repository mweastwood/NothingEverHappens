import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/scheduling_policy.dart';

void main() {
  group('SchedulingPolicy Tests', () {
    group('FixedCalendarPolicy', () {
      test('equality and hashCode', () {
        const policy1 = FixedCalendarPolicy();
        const policy2 = FixedCalendarPolicy();

        expect(policy1, equals(policy2));
        expect(policy1.hashCode, equals(policy2.hashCode));
      });

      test('toJson and fromJson serialization', () {
        const policy = FixedCalendarPolicy();
        final json = policy.toJson();

        expect(json['type'], 'fixedCalendar');

        final deserialized = SchedulingPolicy.fromJson(json);
        expect(deserialized, isA<FixedCalendarPolicy>());
      });

      test('toString matches expected output', () {
        const policy = FixedCalendarPolicy();
        expect(policy.toString(), 'FixedCalendarPolicy()');
      });
    });

    group('CompletionRelativePolicy', () {
      test('equality and hashCode', () {
        const policy1 = CompletionRelativePolicy(
          interval: Duration(days: 7),
          targetTime: TimeOfDay(hour: 9, minute: 0),
        );
        const policy2 = CompletionRelativePolicy(
          interval: Duration(days: 7),
          targetTime: TimeOfDay(hour: 9, minute: 0),
        );
        const policy3 = CompletionRelativePolicy(
          interval: Duration(days: 5),
          targetTime: TimeOfDay(hour: 9, minute: 0),
        );

        expect(policy1, equals(policy2));
        expect(policy1.hashCode, equals(policy2.hashCode));
        expect(policy1, isNot(equals(policy3)));
      });

      test('toJson and fromJson serialization', () {
        const policy = CompletionRelativePolicy(
          interval: Duration(days: 7),
          targetTime: TimeOfDay(hour: 9, minute: 30),
        );
        final json = policy.toJson();

        expect(json['type'], 'completionRelative');
        expect(json['intervalMinutes'], 7 * 24 * 60);
        expect(json['targetHour'], 9);
        expect(json['targetMinute'], 30);

        final deserialized = SchedulingPolicy.fromJson(json);
        expect(deserialized, isA<CompletionRelativePolicy>());
        final casted = deserialized as CompletionRelativePolicy;
        expect(casted.interval, const Duration(days: 7));
        expect(casted.targetTime, const TimeOfDay(hour: 9, minute: 30));
      });

      test('toString matches expected output', () {
        const policy = CompletionRelativePolicy(
          interval: Duration(days: 1),
          targetTime: TimeOfDay(hour: 12, minute: 0),
        );
        expect(
          policy.toString(),
          'CompletionRelativePolicy(interval: 24:00:00.000000, targetTime: TimeOfDay(12:00))',
        );
      });
    });
  });
}
