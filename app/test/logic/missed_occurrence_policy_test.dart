import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/missed_occurrence_policy.dart';
import 'package:nothing_ever_happens/logic/missed_policy.dart';

void main() {
  group('MissedOccurrencePolicy Tests', () {
    group('keepAround', () {
      test('constructors and legacyPolicy defaults', () {
        const policy1 = MissedOccurrencePolicy.keepAround();
        const policy2 = MissedOccurrencePolicy.keepAround(
          legacyPolicy: MissedPolicy.shift,
        );

        expect(policy1.type, MissedOccurrenceType.keepAround);
        expect(policy1.legacyPolicy, MissedPolicy.rollover);
        expect(policy1.gracePeriod, isNull);

        expect(policy2.type, MissedOccurrenceType.keepAround);
        expect(policy2.legacyPolicy, MissedPolicy.shift);
        expect(policy2.gracePeriod, isNull);
      });

      test('equality and hashCode', () {
        const policy1 = MissedOccurrencePolicy.keepAround(
          legacyPolicy: MissedPolicy.shift,
        );
        const policy2 = MissedOccurrencePolicy.keepAround(
          legacyPolicy: MissedPolicy.shift,
        );
        const policy3 = MissedOccurrencePolicy.keepAround(
          legacyPolicy: MissedPolicy.stack,
        );

        expect(policy1, equals(policy2));
        expect(policy1.hashCode, equals(policy2.hashCode));
        expect(policy1, isNot(equals(policy3)));
      });

      test('toJson and fromJson serialization', () {
        const policy = MissedOccurrencePolicy.keepAround(
          legacyPolicy: MissedPolicy.stack,
        );
        final json = policy.toJson();

        expect(json['type'], 'keepAround');
        expect(json['legacyPolicy'], 'stack');
        expect(json['graceMinutes'], isNull);

        final deserialized = MissedOccurrencePolicy.fromJson(json);
        expect(deserialized.type, MissedOccurrenceType.keepAround);
        expect(deserialized.legacyPolicy, MissedPolicy.stack);
      });

      test('toString matches expected output', () {
        const policy = MissedOccurrencePolicy.keepAround(
          legacyPolicy: MissedPolicy.rollover,
        );
        expect(
          policy.toString(),
          'MissedOccurrencePolicy(type: MissedOccurrenceType.keepAround, gracePeriod: null, legacyPolicy: MissedPolicy.rollover)',
        );
      });
    });

    group('autoDismiss', () {
      test('constructors and properties', () {
        const policy = MissedOccurrencePolicy.autoDismiss(
          gracePeriod: Duration(hours: 3),
        );

        expect(policy.type, MissedOccurrenceType.autoDismiss);
        expect(policy.legacyPolicy, MissedPolicy.skip);
        expect(policy.gracePeriod, const Duration(hours: 3));
      });

      test('equality and hashCode', () {
        const policy1 = MissedOccurrencePolicy.autoDismiss(
          gracePeriod: Duration(minutes: 30),
        );
        const policy2 = MissedOccurrencePolicy.autoDismiss(
          gracePeriod: Duration(minutes: 30),
        );
        const policy3 = MissedOccurrencePolicy.autoDismiss(
          gracePeriod: Duration(minutes: 60),
        );

        expect(policy1, equals(policy2));
        expect(policy1.hashCode, equals(policy2.hashCode));
        expect(policy1, isNot(equals(policy3)));
      });

      test('toJson and fromJson serialization', () {
        const policy = MissedOccurrencePolicy.autoDismiss(
          gracePeriod: Duration(hours: 5),
        );
        final json = policy.toJson();

        expect(json['type'], 'autoDismiss');
        expect(json['legacyPolicy'], 'skip');
        expect(json['graceMinutes'], 300);

        final deserialized = MissedOccurrencePolicy.fromJson(json);
        expect(deserialized.type, MissedOccurrenceType.autoDismiss);
        expect(deserialized.legacyPolicy, MissedPolicy.skip);
        expect(deserialized.gracePeriod, const Duration(hours: 5));
      });

      test('toString matches expected output', () {
        const policy = MissedOccurrencePolicy.autoDismiss(
          gracePeriod: Duration(minutes: 45),
        );
        expect(
          policy.toString(),
          'MissedOccurrencePolicy(type: MissedOccurrenceType.autoDismiss, gracePeriod: 0:45:00.000000, legacyPolicy: MissedPolicy.skip)',
        );
      });
    });
  });
}
