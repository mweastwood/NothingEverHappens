import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('SchedulingPolicy Tests', () {
    group('SchedulingType Enum', () {
      test('contains expected values', () {
        expect(
          SchedulingType.values,
          containsAll([
            SchedulingType.fixedCalendar,
            SchedulingType.completionRelative,
          ]),
        );
        expect(SchedulingType.values.length, equals(2));
      });

      test('enum name strings match json type values', () {
        expect(SchedulingType.fixedCalendar.name, equals('fixedCalendar'));
        expect(
          SchedulingType.completionRelative.name,
          equals('completionRelative'),
        );
      });
    });

    group('FixedCalendarPolicy', () {
      test('construction and type property', () {
        const policy = FixedCalendarPolicy();
        expect(policy.type, equals(SchedulingType.fixedCalendar));
      });

      test('toJson returns correct map', () {
        const policy = FixedCalendarPolicy();
        final json = policy.toJson();
        expect(json, equals({'type': 'fixedCalendar'}));
      });

      test('SchedulingPolicy.fromJson reconstructs FixedCalendarPolicy', () {
        final policy = SchedulingPolicy.fromJson({'type': 'fixedCalendar'});
        expect(policy, isA<FixedCalendarPolicy>());
        expect(policy.type, equals(SchedulingType.fixedCalendar));
      });

      test('value equality, symmetry, and hashCode', () {
        const policy1 = FixedCalendarPolicy();
        const policy2 = FixedCalendarPolicy();

        // Reflexive and symmetric
        expect(policy1, equals(policy1));
        expect(policy1, equals(policy2));
        expect(policy2, equals(policy1));
        expect(policy1.hashCode, equals(policy2.hashCode));

        // Inequality against different types
        expect(policy1, isNot(equals(Object())));
        expect(
          policy1,
          isNot(
            equals(
              const CompletionRelativePolicy(
                interval: Duration(hours: 12),
                targetHour: 8,
                targetMinute: 0,
              ),
            ),
          ),
        );
      });

      test('toString output', () {
        const policy = FixedCalendarPolicy();
        expect(policy.toString(), equals('FixedCalendarPolicy()'));
      });
    });

    group('CompletionRelativePolicy', () {
      const sampleInterval = Duration(days: 3); // 4320 minutes
      const sampleHour = 14;
      const sampleMinute = 30;

      test('construction and field initialization', () {
        const policy = CompletionRelativePolicy(
          interval: sampleInterval,
          targetHour: sampleHour,
          targetMinute: sampleMinute,
        );

        expect(policy.interval, equals(sampleInterval));
        expect(policy.targetHour, equals(sampleHour));
        expect(policy.targetMinute, equals(sampleMinute));
        expect(policy.type, equals(SchedulingType.completionRelative));
      });

      test('toJson serialization format', () {
        const policy = CompletionRelativePolicy(
          interval: sampleInterval,
          targetHour: sampleHour,
          targetMinute: sampleMinute,
        );
        final json = policy.toJson();

        expect(
          json,
          equals({
            'type': 'completionRelative',
            'intervalMinutes': 4320,
            'targetHour': 14,
            'targetMinute': 30,
          }),
        );
      });

      test('SchedulingPolicy.fromJson deserialization', () {
        final json = {
          'type': 'completionRelative',
          'intervalMinutes': 4320,
          'targetHour': 14,
          'targetMinute': 30,
        };
        final policy = SchedulingPolicy.fromJson(json);

        expect(policy, isA<CompletionRelativePolicy>());
        final crPolicy = policy as CompletionRelativePolicy;
        expect(crPolicy.interval, equals(const Duration(minutes: 4320)));
        expect(crPolicy.targetHour, equals(14));
        expect(crPolicy.targetMinute, equals(30));
        expect(crPolicy.type, equals(SchedulingType.completionRelative));
      });

      test('round-trip serialization integrity', () {
        const original = CompletionRelativePolicy(
          interval: Duration(hours: 36),
          targetHour: 9,
          targetMinute: 15,
        );
        final restored = SchedulingPolicy.fromJson(original.toJson());
        expect(restored, equals(original));
        expect(restored.hashCode, equals(original.hashCode));
      });

      test('value equality, inequality, and hashCode consistency', () {
        const policy1 = CompletionRelativePolicy(
          interval: Duration(days: 2),
          targetHour: 10,
          targetMinute: 0,
        );
        const policy2 = CompletionRelativePolicy(
          interval: Duration(days: 2),
          targetHour: 10,
          targetMinute: 0,
        );
        const diffInterval = CompletionRelativePolicy(
          interval: Duration(days: 3),
          targetHour: 10,
          targetMinute: 0,
        );
        const diffHour = CompletionRelativePolicy(
          interval: Duration(days: 2),
          targetHour: 11,
          targetMinute: 0,
        );
        const diffMinute = CompletionRelativePolicy(
          interval: Duration(days: 2),
          targetHour: 10,
          targetMinute: 1,
        );

        // Identical instance equality
        expect(policy1 == policy1, isTrue);

        // Symmetric equality
        expect(policy1, equals(policy2));
        expect(policy2, equals(policy1));
        expect(policy1.hashCode, equals(policy2.hashCode));

        // Inequality for distinct properties
        expect(policy1, isNot(equals(diffInterval)));
        expect(policy1, isNot(equals(diffHour)));
        expect(policy1, isNot(equals(diffMinute)));

        // Inequality against different types
        expect(policy1, isNot(equals(const FixedCalendarPolicy())));
        expect(policy1, isNot(equals(Object())));
      });

      test('toString output', () {
        const policy = CompletionRelativePolicy(
          interval: Duration(days: 1),
          targetHour: 12,
          targetMinute: 45,
        );
        expect(
          policy.toString(),
          equals(
            'CompletionRelativePolicy(interval: 24:00:00.000000, targetHour: 12, targetMinute: 45)',
          ),
        );
      });
    });

    group('Deserialization Error Handling & Edge Cases', () {
      test('unsupported or unknown policy type throws StateError', () {
        expect(
          () => SchedulingPolicy.fromJson({'type': 'unknownType'}),
          throwsStateError,
        );
        expect(
          () => SchedulingPolicy.fromJson({'type': 'invalid'}),
          throwsStateError,
        );
      });

      test('missing or invalid type key throws TypeError', () {
        expect(
          () => SchedulingPolicy.fromJson({}),
          throwsA(isA<TypeError>()),
        );
        expect(
          () => SchedulingPolicy.fromJson({'type': 123}),
          throwsA(isA<TypeError>()),
        );
        expect(
          () => SchedulingPolicy.fromJson({'type': null}),
          throwsA(isA<TypeError>()),
        );
      });

      test('malformed completionRelative payload throws TypeError', () {
        expect(
          () => SchedulingPolicy.fromJson({
            'type': 'completionRelative',
            // missing intervalMinutes
            'targetHour': 10,
            'targetMinute': 0,
          }),
          throwsA(isA<TypeError>()),
        );
        expect(
          () => SchedulingPolicy.fromJson({
            'type': 'completionRelative',
            'intervalMinutes': 60,
            // missing targetHour
            'targetMinute': 0,
          }),
          throwsA(isA<TypeError>()),
        );
        expect(
          () => SchedulingPolicy.fromJson({
            'type': 'completionRelative',
            'intervalMinutes': 60,
            'targetHour': 10,
            // missing targetMinute
          }),
          throwsA(isA<TypeError>()),
        );
        expect(
          () => SchedulingPolicy.fromJson({
            'type': 'completionRelative',
            'intervalMinutes': 'invalid',
            'targetHour': 10,
            'targetMinute': 0,
          }),
          throwsA(isA<TypeError>()),
        );
      });
    });
  });
}
